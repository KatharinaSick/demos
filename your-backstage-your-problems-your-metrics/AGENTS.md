# your-backstage-your-problems-your-metrics — Agent Context

## What this demo does

Traces the full developer golden path as a single distributed OTel trace: from a developer clicking "Create" in Backstage, through CI (Argo Workflows), GitOps sync (ArgoCD), to a running pod in the cluster. The trace is carried across system boundaries by embedding the W3C `traceparent` in git commit messages.

## Architecture

```
Backstage (port 30200)
  └─ gitea:repo:create  →  Gitea (port 30110)
       └─ webhook        →  Argo Events
                              └─ Workflow  →  registry:5000  →  -deployment repo
                                                                      └─ ArgoCD (port 30100)  →  pod
                                              OTel Collector  →  Jaeger (port 30103)
```

### Components

| Component | Version / Notes |
|-----------|-----------------|
| Kind cluster | in-cluster Docker registry at `registry:5000` (host port 5001) |
| Gitea | Helm 12.5.3, port 30110, user `admin` / `a-super-secure-password` |
| Backstage | custom image, port 30200 |
| Argo Events | Helm 2.4.21 |
| Argo Workflows | Helm 1.0.13, port 30111 |
| ArgoCD | Helm v3.3.8, port 30100 |
| Jaeger | Helm 4.7.0, port 30103 |
| OTel Collector | Helm 0.148.0 |

## Trace propagation flow

1. **Backstage** — `gitea:repo:create` action injects the active OTel span context into the initial commit message as `Trace-Parent: <traceparent>`.
2. **Argo Events** — Gitea push webhook triggers a Workflow.
3. **Argo Workflows** — `extract` step parses `traceparent` from the commit message. `close-trace` step sends a child span to the OTel Collector via OTLP/HTTP.
4. **OTel Collector** — forwards to Jaeger.

## Backstage custom scaffolder actions

Located in `backstage/packages/backend/src/modules/scaffolder/`.

### `gitea:repo:create`
Creates a Gitea repo, initializes it with the workspace skeleton, and pushes. Extracts the active OTel span context and embeds `traceparent` in the initial commit message so Argo Workflows can continue the trace.

### `gitea:file:create`
Creates or updates a single file in an existing Gitea repo via the Gitea contents API (`PUT /api/v1/repos/{owner}/{repo}/contents/{path}`). Fetches the file's current SHA first so it can handle updates idempotently. Used by the template to push the ArgoCD Application manifest into `argocd-apps`.

Both actions read `gitea.baseUrl`, `gitea.username`, and `gitea.password` from Backstage config (configured in `cluster/backstage/configmap.yaml`).

## Template flow (`backstage/templates/create-service/template.yaml`)

1. `fetch-app` — render Go service skeleton into workspace
2. `create-app-repo` — create `<service>-app` in Gitea with traceparent in commit
3. `fetch-deployment` — render deployment skeleton into workspace
4. `create-deployment-repo` — create `<service>-deployment` in Gitea
5. `register-argocd-app` — push `<service>.yaml` ArgoCD Application manifest to `argocd-apps` repo
6. `register` — register `catalog-info.yaml` in Backstage catalog

## Argo Workflow pipeline (`cluster/argo-workflows/workflow-template.yaml`)

Triggered when a push to any `*-app` repo fires the Gitea webhook.

1. `extract` — parses `serviceName` (strips `-app` suffix) and `traceparent` from commit message; skips all later steps if the repo name doesn't end in `-app`
2. `clone` — clones `<service>-app` repo into shared workspace volume
3. `build-and-push` — builds with Kaniko, pushes to `registry:5000/<service>:<sha>`
4. `update-deployment` — clones `<service>-deployment`, patches image tag in `deployment.yaml`, pushes
5. `wait-for-deploy` — polls until the Deployment exists, then waits for rollout
6. `close-trace` — sends a child OTel span to the collector to close the trace

## ArgoCD setup (app-of-apps pattern)

`cluster/argocd/app-of-apps.yaml` creates a root ArgoCD `Application` watching the `argocd-apps` Gitea repo. When the Backstage template runs, `gitea:file:create` pushes `<service>.yaml` into that repo. ArgoCD auto-syncs and creates the child Application, which then watches the `<service>-deployment` repo.

**Do not use the ArgoCD Gitea SCM provider** — it is broken for user-owned repos (hardcodes `ListOrgRepos` with no fallback to `ListUserRepos`, [ArgoCD bug #24932](https://github.com/argoproj/argo-cd/issues/24932), unfixed in all released versions as of v3.3.8).

All Gitea repos are public so ArgoCD can clone them without credentials.

## Argo Events setup (`cluster/argo-events/`)

- **EventSource** — listens for Gitea push webhooks on port 12000
- **Sensor** — triggers the `build-service` WorkflowTemplate when the push is to a repo matching `.*-app$`
- **DataFilter** — uses `type: string` (values are always treated as Go regexes); do not use `comparator: =~` (not supported) or `exprFilter` with `endsWith`/`matches` (govaluate token errors)

RBAC note: the Sensor pod runs as the `default` ServiceAccount in `argo-events` despite the spec specifying `sensor-workflow-creator`. Both SAs are bound to the ClusterRole.

## Known gotchas

- **Kaniko in kind**: needs `--ignore-path=/product_uuid` arg or it fails with a permissions error.
- **Gitea tokens don't persist across restarts**: `post-start.sh` deletes and recreates the ArgoCD Gitea token on every devcontainer start and restarts `argocd-applicationset-controller` to pick it up.
- **devcontainer-lib v0.3.0**: all tool installs use `--no-wait`; `wait.sh --timeout 10m` waits for all in parallel. ArgoCD (`argocd/init.sh`) doesn't support `--no-wait` and runs blocking before `wait.sh`.
- **Argo Workflows Emissary executor RBAC**: needs `workflowtaskresults` (create, patch) and `pods` (get, watch, patch) permissions on the `build-service` ClusterRole.
- **OTel in Backstage**: the `propagation.inject` call in `gitea:repo:create` only produces a `traceparent` if there is an active span in context when the scaffolder action runs. If the Backstage OTel SDK isn't configured to start a root span for scaffolder task execution, `traceparent` will be empty and the trace won't be linked.

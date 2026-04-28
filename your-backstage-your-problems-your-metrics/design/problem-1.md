# Problem 1 — Service Creation

## Problem Statement

When a developer wants to create a new service, they don't know where to start — they ask
different people, get inconsistent answers, struggle to set up CI/CD themselves, and wait days
for the ops team to unblock them. All before they've written a single line of business logic.

**Backstage feature:** Software Templates  
**DevEx pillar:** Flow State

---

## Demo Flow

Two repos are created per service — this is intentional and part of the demo story:
`<service-name>` (app code) and `<service-name>-deployment` (k8s manifests). One template,
one click, full golden path wired up automatically.

```
Developer opens Backstage template
  → fills in: service name, team, language
  → clicks Create

Backstage scaffolder:
  → creates Gitea repo "<service-name>" with service scaffold
  → initial commit message includes "Trace-Parent: <traceparent>"
  → creates Gitea repo "<service-name>-deployment" with k8s manifests
  → registers service in Backstage catalog (catalog-info.yaml)

Argo Events:
  → detects push to "<service-name>" repo (webhook)
  → extracts Trace-Parent from commit message via JSONPath
  → triggers Argo Workflow with traceparent as parameter

Argo Workflow:
  → step 1: init trace (use traceparent from parameter as parent span, or start fresh if absent)
  → step 2: build Docker image
  → step 3: push image to in-cluster registry
  → step 4: update image tag in "<service-name>-deployment" (commit to Gitea)

ArgoCD:
  → detects manifest change in "<service-name>-deployment"
  → syncs → service is running in cluster
```

---

## Stack

| Component | Purpose | How |
|-----------|---------|-----|
| Backstage | Template UI + scaffolder | Deployed in kind via Helm, custom image from ghcr.io |
| Gitea | Git provider | Deployed in kind via Helm |
| Argo Events | Gitea webhook → workflow trigger | Deployed in kind via Helm |
| Argo Workflows | CI pipeline (build + push) | Deployed in kind via Helm |
| ArgoCD | GitOps deployment | Deployed in kind via Helm |
| In-cluster registry | Docker image storage | Simple registry in kind |
| OTel Collector | Trace collection | Deployed in kind via Helm, sends to Dynatrace |

---

## Trace Design

**Goal:** one continuous trace from "user opens template" to "service deployed", spanning all systems.

**Approach:** carry W3C `traceparent` via the initial commit message (Option A).

### Why commit message?
- Backstage already has Gitea API access (creates the repo) — no new permissions needed
- Gitea push webhook payload includes commit messages → Argo Events reads it via JSONPath
- Subsequent developer commits won't have the header → fresh trace automatically
- Pure GitOps: state lives in git history, nothing to clean up

### Trace context flow

```
Backstage backend (OTel enabled via env vars)
  → scaffolder starts span: "create-service"
    → custom scaffolder action "create:gitea-repo":
        - creates Gitea repo
        - writes initial commit with message:
          "feat: initialize service from Backstage template\n\nTrace-Parent: 00-<traceid>-<spanid>-01"
        - registers entity in catalog

Argo Events EventSource (Gitea push webhook)
  → triggers Sensor with commit message extracted via JSONPath: $.commits[0].message
  → Sensor passes Trace-Parent as workflow parameter

Argo Workflow (OTel enabled via env vars)
  → step 1: parse Trace-Parent from parameter, set as TRACEPARENT env var
  → subsequent steps run as child spans of the Backstage scaffolder span
```

### OTel configuration

All components export to the in-cluster OTel Collector, which forwards to Dynatrace.

**Backstage** — env vars in k8s Deployment:
```yaml
OTEL_EXPORTER_OTLP_ENDPOINT: http://otel-collector:4318
OTEL_SERVICE_NAME: backstage
```

**Argo Workflows** — env vars on workflow controller:
```yaml
OTEL_EXPORTER_OTLP_ENDPOINT: http://otel-collector:4318
OTEL_SERVICE_NAME: argo-workflows
```

---

## What Needs to Be Built

### Backstage

- [ ] Configure OTel exporter (env vars in Helm values)
- [ ] Alfi corp catalog entities: `Group`, `User`, `System` for the platform
- [ ] Custom scaffolder action `create:gitea-repo` that:
  - creates repo via Gitea API
  - writes initial commit with `Trace-Parent` in message
- [ ] Software Template (`template.yaml`) with steps:
  1. Collect input (service name, team, language)
  2. Fetch skeleton (cookiecutter-style template files)
  3. `create:gitea-repo` for `<service-name>` (custom action)
  4. `create:gitea-repo` for `<service-name>-deployment` (custom action)
  5. `catalog:register` (built-in action)
- [ ] App skeleton (`skeleton/app/`) containing:
  - `catalog-info.yaml` (with owner, system, type)
  - Simple hello-world service (Go or Python — keep it minimal)
  - `Dockerfile`
  - Basic TechDocs stub (`mkdocs.yml` + `docs/index.md`)
- [ ] Deployment skeleton (`skeleton/deployment/`) containing:
  - `deployment.yaml` + `service.yaml` (image tag as template variable)

### Argo Events

- [ ] `EventSource` — Gitea webhook, listens for push events on repos matching a pattern
- [ ] `Sensor` — extracts `Trace-Parent` from commit message via JSONPath, triggers workflow

### Argo Workflows

- [ ] `WorkflowTemplate` with steps: init-trace → build → push → update-manifests
- [ ] OTel configured on the workflow controller
- [ ] RBAC for image push to in-cluster registry

### ArgoCD

- [ ] ApplicationSet watching Gitea org for repos matching `*-deployment`
- [ ] Auto-sync enabled

### Cluster / Devcontainer

- [ ] kind config with port mappings for: Backstage, Gitea, ArgoCD UI, Argo Workflows UI, Jaeger/Dynatrace
- [ ] In-cluster Docker registry
- [ ] `lib/` init scripts for each component (following open-ecosystem-challenges pattern)
- [ ] `.devcontainer/devcontainer.json` wiring it all together

---

## Metrics to Show in the Demo

| Metric | Where to show |
|--------|--------------|
| % of new services created via templates | Backstage catalog: filter components by `backstage.io/created-by` |
| Template completion rate / error rate | Argo Workflows UI: successful vs failed workflow runs |
| Time from template trigger to first deployment | The OTel trace — start span to final ArgoCD sync |
| % of template runs completing the full pipeline | Argo Workflows: completed workflow count vs triggered |

---

## Open Questions

- Language for the service skeleton? Go is minimal and fast to build; Python avoids compilation.
- Does Dynatrace need to be in-cluster or can OTel collector forward externally? (External is simpler for the devcontainer — just needs a DT endpoint + token as env vars)
- Do we want ArgoCD UI exposed for the demo or just show it's running?

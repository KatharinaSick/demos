#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_DIR="$(cd "$SCRIPT_DIR/../../your-backstage-your-problems-your-metrics" && pwd)"

LIB_DIR=$(mktemp -d)
curl -fsSL "https://github.com/KatharinaSick/devcontainer-lib/archive/refs/tags/v0.3.1.tar.gz" \
  | tar -xz --strip-components=2 -C "$LIB_DIR"

# Registry for demo service images built by Argo Workflows
# Must start before cluster creation so containerd on kind nodes can reach it as registry:5000
# via the Docker network. TODO: move to devcontainer-lib as registry/init.sh or as option of kubernetes/init.sh.
docker run -d --restart=always -p "127.0.0.1:5001:5000" --name registry registry:2

# Create cluster + install CLI tools
"$LIB_DIR/kubernetes/init.sh" \
  --kind-version v0.31.0 \
  --kubectl-version v1.35.0 \
  --kubens-version v0.11.0 \
  --k9s-version v0.50.18 \
  --helm-version v4.1.4

# Connect registry to kind network so nodes can reach registry:5000
docker network connect kind registry

# Deploy tools — submit manifests without waiting, then wait for all in parallel
"$LIB_DIR/gitea/init.sh"          --version 12.5.3  --no-wait
"$LIB_DIR/argo-events/init.sh"    --version 2.4.21  --no-wait
"$LIB_DIR/argo-workflows/init.sh" --version 1.0.13  --no-wait
"$LIB_DIR/jaeger/init.sh"         --version 4.7.0   --no-wait
"$LIB_DIR/otel-collector/init.sh" --version 0.148.0 --no-wait
"$LIB_DIR/argocd/init.sh"         --version v3.3.8

"$LIB_DIR/wait.sh" --timeout 10m gitea argo-events argo-workflows jaeger otel-collector

rm -rf "$LIB_DIR"

# Override OTel Collector config to add Dynatrace exporter
# Requires DT_ENDPOINT and DT_API_TOKEN to be set as Codespaces secrets
kubectl create secret generic dynatrace-credentials \
  --from-literal=DT_ENDPOINT="$DT_ENDPOINT" \
  --from-literal=DT_API_TOKEN="$DT_API_TOKEN" \
  -n otel
kubectl apply -f "$DEMO_DIR/cluster/otel-collector/"
kubectl set env deployment/collector -n otel --from=secret/dynatrace-credentials
kubectl rollout restart deployment/collector -n otel
kubectl rollout status deployment/collector -n otel --timeout=120s

# Backstage
kubectl create namespace backstage
kubectl apply -f "$DEMO_DIR/cluster/backstage/"
kubectl rollout status deployment/backstage -n backstage

# Argo Workflows WorkflowTemplate + RBAC
kubectl apply -f "$DEMO_DIR/cluster/argo-workflows/"

# Argo Events resources
kubectl apply -f "$DEMO_DIR/cluster/argo-events/"
until kubectl get deployment -n argo-events -l eventsource-name=gitea --no-headers 2>/dev/null | grep -q .; do sleep 2; done
kubectl wait deployment -n argo-events -l eventsource-name=gitea --for=condition=available --timeout=120s

# Create argocd-apps repo — ArgoCD watches this for Application manifests
curl -s -X POST http://localhost:30110/api/v1/user/repos \
  -u admin:a-super-secure-password \
  -H "Content-Type: application/json" \
  -d '{"name": "argocd-apps", "private": false, "auto_init": true, "default_branch": "main"}'

# ArgoCD
GITEA_TOKEN=$(curl -s -X POST http://localhost:30110/api/v1/users/admin/tokens \
  -u admin:a-super-secure-password \
  -H "Content-Type: application/json" \
  -d '{"name": "argocd", "scopes": ["read:repository", "read:user", "read:organization"]}' | jq -r '.sha1')
kubectl create secret generic gitea-token \
  --from-literal=token="$GITEA_TOKEN" \
  -n argocd
kubectl apply -f "$DEMO_DIR/cluster/argocd/"

# Configure Gitea user webhook to forward push events to Argo Events
curl -s -X POST http://localhost:30110/api/v1/user/hooks \
  -u admin:a-super-secure-password \
  -H "Content-Type: application/json" \
  -d '{
    "type": "gitea",
    "config": {
      "url": "http://gitea-eventsource-svc.argo-events.svc.cluster.local:12000/push",
      "content_type": "json"
    },
    "events": ["push"],
    "active": true
  }'

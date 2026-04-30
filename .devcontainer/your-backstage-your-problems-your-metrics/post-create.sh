#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_DIR="$(cd "$SCRIPT_DIR/../../your-backstage-your-problems-your-metrics" && pwd)"

LIB_DIR="$HOME/.devcontainer-lib"

mkdir -p "$LIB_DIR"
curl -fsSL "https://github.com/KatharinaSick/devcontainer-lib/archive/refs/tags/v0.2.2.tar.gz" \
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

# Deploy tools
"$LIB_DIR/gitea/init.sh"          --version 12.5.3 --timeout 10m
"$LIB_DIR/argo-events/init.sh"    --version 2.4.21
"$LIB_DIR/argo-workflows/init.sh" --version 1.0.13
"$LIB_DIR/argocd/init.sh"         --version v3.3.8
"$LIB_DIR/jaeger/init.sh"          --version 4.7.0
"$LIB_DIR/otel-collector/init.sh"  --version 0.148.0

# Backstage
kubectl create namespace backstage
kubectl apply -f "$DEMO_DIR/cluster/backstage/"
kubectl rollout status deployment/backstage -n backstage

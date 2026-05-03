#!/usr/bin/env bash
set -e

curl -s -X DELETE http://localhost:30110/api/v1/users/admin/tokens/argocd \
  -u admin:a-super-secure-password || true
GITEA_TOKEN=$(curl -s -X POST http://localhost:30110/api/v1/users/admin/tokens \
  -u admin:a-super-secure-password \
  -H "Content-Type: application/json" \
  -d '{"name": "argocd", "scopes": ["read:repository", "read:user", "read:organization"]}' \
  | jq -r '.sha1')
kubectl delete secret gitea-token -n argocd --ignore-not-found
kubectl create secret generic gitea-token --from-literal=token="$GITEA_TOKEN" -n argocd
kubectl rollout restart deployment/argocd-applicationset-controller -n argocd

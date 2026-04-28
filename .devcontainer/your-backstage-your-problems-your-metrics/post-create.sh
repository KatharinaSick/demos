#!/usr/bin/env bash
set -e

LIB_VERSION="v0.1.0"

LIB_DIR=$(mktemp -d)
curl -fsSL "https://github.com/KatharinaSick/devcontainer-lib/archive/refs/tags/${LIB_VERSION}.tar.gz" \
  | tar -xz --strip-components=2 -C "$LIB_DIR"

"$LIB_DIR/kubernetes/init.sh" \
  --kind-version v0.31.0 \
  --kubectl-version v1.35.0 \
  --kubens-version v0.11.0 \
  --k9s-version v0.50.18 \
  --helm-version v4.1.4

rm -rf "$LIB_DIR"

#!/usr/bin/env bash
# Phase A5/A6 - TaskBoard on minikube.
#   ./up.sh          deploy with `helm upgrade --install`, then `helm test`
#   ./up.sh argocd   load the image, install Argo CD and let it deploy the chart from Git (GitOps)
set -euo pipefail

MODE="${1:-helm}"
PROFILE=taskboard
NAMESPACE=taskboard
IMAGE=taskboard-backend:local
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
CHART="$ROOT/deploy/helm/taskboard"

# 1. cluster with its OWN profile: other minikube clusters on this laptop are untouched
if ! minikube status -p "$PROFILE" >/dev/null 2>&1; then
  minikube start -p "$PROFILE" --cpus 2 --memory 4096
fi
kubectl config use-context "$PROFILE" >/dev/null

# 2. image: built locally, copied into minikube (no registry), pullPolicy: Never in values-local.yaml
docker build --pull -t "$IMAGE" --build-arg APP_VERSION=local "$ROOT/app/backend"
minikube -p "$PROFILE" image load "$IMAGE"

case "$MODE" in
  helm)
    helm upgrade --install taskboard "$CHART" \
      -n "$NAMESPACE" --create-namespace \
      -f "$CHART/values-local.yaml" --wait --timeout 5m
    helm test taskboard -n "$NAMESPACE" --logs
    ;;
  argocd)
    # REPO_URL (optional) overrides the repoURL written in the Application file
    "$ROOT/gitops/install-argocd.sh" "$ROOT/gitops/applications/taskboard-local.yaml"
    echo "Waiting for Argo CD to sync the application (it checks Git every ~3 minutes)..."
    for _ in $(seq 1 60); do
      sync=$(kubectl -n argocd get application taskboard -o jsonpath='{.status.sync.status}' 2>/dev/null || true)
      health=$(kubectl -n argocd get application taskboard -o jsonpath='{.status.health.status}' 2>/dev/null || true)
      echo "  sync=${sync:-?} health=${health:-?}"
      [ "$sync" = "Synced" ] && [ "$health" = "Healthy" ] && break
      sleep 10
    done
    kubectl -n "$NAMESPACE" get pods
    cat <<MSG

Argo CD UI:
  kubectl -n argocd port-forward svc/argocd-server 8080:443      # https://localhost:8080
  user: admin   password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d)
MSG
    ;;
  *)
    echo "usage: $0 [helm|argocd]" >&2; exit 2 ;;
esac

cat <<MSG

Try the API:   kubectl -n $NAMESPACE port-forward svc/taskboard-backend 8000:8000   # http://localhost:8000/api/docs
Run the proofs: $HERE/verify.sh
MSG

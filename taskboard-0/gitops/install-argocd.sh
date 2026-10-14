#!/usr/bin/env bash
# Installs Argo CD (Helm chart argo/argo-cd) and applies one Application. Same script on minikube and on EKS.
#   gitops/install-argocd.sh gitops/applications/taskboard-local.yaml
#   REPO_URL=https://github.com/<you>/taskboard.git gitops/install-argocd.sh <application-file>   # override repoURL
#   ARGOCD_CHART_VERSION=<x.y.z> to pin the chart (recommended once it works for you)
set -euo pipefail

APP_FILE="${1:?usage: $0 <application-file>}"
[ -f "$APP_FILE" ] || { echo "no such file: $APP_FILE" >&2; exit 1; }

helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update argo >/dev/null

VERSION_ARGS=()
[ -n "${ARGOCD_CHART_VERSION:-}" ] && VERSION_ARGS=(--version "$ARGOCD_CHART_VERSION")

helm upgrade --install argocd argo/argo-cd \
  -n argocd --create-namespace --wait --timeout 10m ${VERSION_ARGS[@]+"${VERSION_ARGS[@]}"}

TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
if [ -n "${REPO_URL:-}" ]; then
  sed -E "s|repoURL: .*|repoURL: ${REPO_URL}|" "$APP_FILE" > "$TMP"
else
  cp "$APP_FILE" "$TMP"
fi
if grep -q 'YOUR_GITHUB_USER' "$TMP"; then
  echo "Edit repoURL in $APP_FILE (YOUR_GITHUB_USER) or run with REPO_URL=https://github.com/<you>/taskboard.git" >&2
  exit 1
fi

kubectl apply -f "$TMP"
echo "Application applied. UI: kubectl -n argocd port-forward svc/argocd-server 8080:443  (user: admin)"
echo "Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"

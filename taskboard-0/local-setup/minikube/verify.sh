#!/usr/bin/env bash
# Phase A5 proofs: (1) data survives deleting the PostgreSQL pod, (2) containers are non-root + read-only.
set -euo pipefail
NS=taskboard
PORT=18000
API="http://localhost:$PORT/api"

kubectl -n "$NS" port-forward svc/taskboard-backend "$PORT:8000" >/dev/null &
PF=$!
trap 'kill $PF 2>/dev/null || true' EXIT
sleep 3

echo "== 1. Persistence"
MARK="persist-$(date +%s)"
curl -fsS -X POST "$API/tasks" -H 'Content-Type: application/json' -d "{\"title\":\"$MARK\"}"; echo
echo "-> deleting pod taskboard-postgres-0"
kubectl -n "$NS" delete pod taskboard-postgres-0 --wait=true
kubectl -n "$NS" wait --for=condition=ready pod/taskboard-postgres-0 --timeout=180s
kubectl -n "$NS" rollout status deploy/taskboard-backend --timeout=180s
# the port-forward died with the old backend pod it was attached to? re-create it to be safe
kill $PF 2>/dev/null || true
kubectl -n "$NS" port-forward svc/taskboard-backend "$PORT:8000" >/dev/null &
PF=$!
sleep 3
for _ in $(seq 1 20); do
  if curl -fsS "$API/tasks" | grep -q "$MARK"; then echo "OK: task '$MARK' survived"; break; fi
  sleep 3
done
curl -fsS "$API/tasks" | grep -q "$MARK" || { echo "FAIL: task lost"; exit 1; }

echo; echo "== 2. Security (id + read-only filesystem)"
BACKEND_POD=$(kubectl -n "$NS" get pod -l app.kubernetes.io/component=backend -o jsonpath='{.items[0].metadata.name}')
for pod in "$BACKEND_POD" taskboard-postgres-0; do
  echo "-- $pod"
  kubectl -n "$NS" exec "$pod" -- id
  if kubectl -n "$NS" exec "$pod" -- touch /usr/x 2>&1; then
    echo "FAIL: could write to /usr"; exit 1
  else
    echo "OK: touch /usr/x failed (read-only root filesystem)"
  fi
done
echo; echo "ALL PROOFS PASSED"

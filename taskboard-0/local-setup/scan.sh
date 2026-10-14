#!/usr/bin/env bash
# Phase A3 - run every scanner of the future pipelines locally, with the SAME pinned images.
# Usage:  local-setup/scan.sh [secrets|trivy-fs|trivy-image|sonar|all]   (default: all, without sonar)
# Run from anywhere; the script moves to the repository root.
set -uo pipefail
cd "$(dirname "$0")/.."

GITLEAKS=ghcr.io/gitleaks/gitleaks:v8.30.1
TRUFFLEHOG=trufflesecurity/trufflehog:3.99.2
TRIVY=aquasec/trivy:0.75.0
SONAR_CLI=sonarsource/sonar-scanner-cli
BACKEND_IMAGE=${BACKEND_IMAGE:-taskboard-backend:local}
SONAR_URL=${SONAR_URL:-http://host.docker.internal:9000}

fail=0
run() { echo; echo "=== $1"; shift; "$@" || { echo "!!! FINDINGS / FAILURE in: $*"; fail=1; }; }

secrets() {
  run gitleaks   docker run --rm -v "$PWD:/src" "$GITLEAKS" dir /src --redact
  run trufflehog docker run --rm -v "$PWD:/src" "$TRUFFLEHOG" filesystem /src --fail
}

trivy_fs() {
  run trivy-fs docker run --rm -v "$PWD:/src" "$TRIVY" fs /src \
      --scanners vuln,secret,misconfig --severity HIGH,CRITICAL --exit-code 1
}

trivy_image() {
  # --pull: an old cached base image is the #1 cause of "surprise" CRITICAL findings
  docker build --pull -t "$BACKEND_IMAGE" app/backend
  run trivy-image docker run --rm -v /var/run/docker.sock:/var/run/docker.sock "$TRIVY" image \
      "$BACKEND_IMAGE" --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1
}

sonar() {
  : "${SONAR_TOKEN:?export SONAR_TOKEN (create a project + token at http://localhost:9000 first)}"
  # coverage.xml must exist: python -m pytest --cov=taskboard --cov-report=xml (in app/backend)
  run sonar docker run --rm -e SONAR_HOST_URL="$SONAR_URL" -e SONAR_TOKEN \
      -v "$PWD/app/backend:/usr/src" "$SONAR_CLI" -Dsonar.qualitygate.wait=true
}

case "${1:-all}" in
  secrets) secrets ;;
  trivy-fs) trivy_fs ;;
  trivy-image) trivy_image ;;
  sonar) sonar ;;
  all) secrets; trivy_fs; trivy_image ;;
  *) echo "unknown target: $1"; exit 2 ;;
esac

echo; [ "$fail" -eq 0 ] && echo "ALL CLEAN" || echo "SOME SCANS REPORTED FINDINGS"
exit "$fail"

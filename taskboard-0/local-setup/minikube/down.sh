#!/usr/bin/env bash
# Deletes ONLY the "taskboard" minikube profile.
set -euo pipefail
minikube delete -p taskboard

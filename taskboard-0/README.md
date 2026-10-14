# TaskBoard - Part A (local setup)

Next.js frontend + FastAPI backend + PostgreSQL, containerised, scanned, packaged as a Helm chart and run on minikube
(with Argo CD GitOps). Part B (AWS EKS, Terraform, GitHub Actions) is delivered as a second archive that is unzipped
**on top of this repository**.

```
app/                         provided source (Dockerfiles + nginx template included)
local-setup/
  docker-compose.yml         db + backend + frontend (+ sonarqube profile)
  scan.sh                    gitleaks, trufflehog, trivy fs/image, sonar (pinned images)
  README.md                  how to start / use / stop
  minikube/up.sh down.sh verify.sh
deploy/helm/taskboard/       the chart (values.yaml, values-local.yaml, values-prod.yaml)
gitops/
  install-argocd.sh          same script on minikube and EKS
  applications/taskboard-local.yaml
docs/PART-A-CHECKLIST.md     commands + evidence to capture for each "Done when"
```

## Quick start

```bash
# 0. create a PUBLIC GitHub repo "taskboard", push this folder (work with branches + PRs)
# 1. Compose
cd local-setup && docker compose up --build        # http://localhost:3000
# 2. scans (Phase A3)
local-setup/scan.sh
# 3. chart
helm lint deploy/helm/taskboard -f deploy/helm/taskboard/values-local.yaml
helm template t deploy/helm/taskboard -f deploy/helm/taskboard/values-local.yaml
# 4. minikube
local-setup/minikube/up.sh && local-setup/minikube/verify.sh
# 5. GitOps (edit repoURL in gitops/applications/taskboard-local.yaml, push, then:)
local-setup/minikube/down.sh && local-setup/minikube/up.sh argocd
local-setup/minikube/down.sh
```

## Design notes

* **One chart, two environments.** Only values change: image location + pull policy, StorageClass, where the DB
  password comes from (`credentials.mode: plain | external`), and whether the `TargetGroupBinding` is rendered.
* **Security context everywhere**: non-root numeric UIDs (backend 10001, postgres 70), read-only root filesystem
  (`emptyDir` for `/tmp`, `/var/run/postgresql`), all capabilities dropped, `RuntimeDefault` seccomp, no service
  account token mounted.
* **Init container** waits with `pg_isready -U <user>` (a UID without a user name would otherwise never connect).
* **APP_VERSION** defaults to the image tag, so a promoted tag (`v1.0.0`) is what `/api/health` reports.
* The PostgreSQL password is read by `initdb` only when the volume is first created. Changing it later needs
  `ALTER USER` or a new volume.

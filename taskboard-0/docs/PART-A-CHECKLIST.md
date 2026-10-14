# Part A - checklist and evidence

Capture a screenshot / terminal output for each "Done when".

| Phase | Done when | Command | Evidence |
|---|---|---|---|
| A1 | images build, backend answers `/api/health` | `docker build --pull -t taskboard-backend:local app/backend` then `docker run --rm -p 8000:8000 -e DATABASE_URL=sqlite+pysqlite:///:memory: taskboard-backend:local` and `curl localhost:8000/api/health` | build log + JSON |
| A2 | compose healthy, tasks survive restart/down+up | `cd local-setup && docker compose up --build -d && docker compose ps` ; add tasks ; `docker compose restart backend` ; `docker compose down && docker compose up -d` | `docker compose ps` + UI screenshots |
| A3 | no HIGH/CRITICAL, sonar gate passes | `local-setup/scan.sh` ; `docker compose --profile sonar up -d` ; `SONAR_TOKEN=... local-setup/scan.sh sonar` | scanner output + Sonar quality gate page |
| A4 | lint + template clean | `helm lint deploy/helm/taskboard -f .../values-local.yaml` ; same with `values-prod.yaml` ; `helm template ...` | output |
| A5 | `up.sh` ends with passing helm test, proofs work | `local-setup/minikube/up.sh` ; `local-setup/minikube/verify.sh` | helm test log + verify output |
| A6 | push of a values change deployed by Argo CD | `up.sh argocd` ; change `replicas: 2` in `values-local.yaml`, push ; `kubectl -n taskboard scale deploy taskboard-backend --replicas=5` -> back to 2 | Argo UI screenshots (OutOfSync -> Synced, self-heal) |

## Likely scan findings and how to fix them

* Image CRITICAL/HIGH from an old cache: always `docker build --pull`.
* Python/npm dependency CVEs: bump the pinned version in `requirements.txt` / `package.json` + lock file, rebuild, rescan.
* Misconfig on Dockerfiles / chart: the chart already sets non-root, read-only FS, dropped capabilities, requests/limits.
  Anything left that is a deliberate choice goes into `.trivyignore` (Part B) **with a written reason**.

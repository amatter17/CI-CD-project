# TaskBoard - local setup (Docker Compose)

`nginx` plays the role of CloudFront: it serves the static frontend and forwards `/api/*` to the backend.

```
browser -> frontend (nginx :3000->8080) --/api/*--> backend :8000 -> postgres (named volume)
```

## Start

```bash
cd local-setup
cp .env.example .env          # optional: change the DB password / app version
docker compose up --build     # first run builds both images; add -d to run in the background
docker compose ps             # db, backend and frontend should be "healthy"
```

Open <http://localhost:3000> and add / complete / delete tasks.
API docs: <http://localhost:8000/api/docs> - metrics: <http://localhost:8000/metrics>

## Prove persistence

```bash
docker compose restart backend      # tasks are still there
docker compose down && docker compose up -d   # still there (the volume is kept)
```

## SonarQube (optional)

```bash
docker compose --profile sonar up -d     # http://localhost:9000  (admin / admin, then change it)
# create a project "taskboard-backend" + a token, then:
cd ../app/backend && pip install -r requirements-dev.txt && python -m pytest --cov=taskboard --cov-report=xml
cd ../.. && SONAR_TOKEN=<token> local-setup/scan.sh sonar
```

## Scan everything (Phase A3)

```bash
local-setup/scan.sh            # gitleaks + trufflehog + trivy fs + trivy image
local-setup/scan.sh secrets     # or one scanner at a time: secrets | trivy-fs | trivy-image | sonar
```

## Stop

```bash
docker compose down        # keeps the data
docker compose down -v     # also deletes the database volume (and SonarQube data)
```

## Troubleshooting

| Symptom | Check |
|---|---|
| backend keeps restarting | `docker compose logs backend`; is `db` healthy? are the `DB_*` values right? |
| UI shows errors but `:8000/api/docs` works | nginx `/api/` proxy and `BACKEND_URL` (`docker compose exec frontend env \| grep BACKEND`) |
| changed the DB password and the backend can't log in | Postgres only reads the password when the volume is first created: `docker compose down -v` |
| SonarQube exits at start (Linux) | `sudo sysctl -w vm.max_map_count=524288` |

# Part B - checklist and demo scenarios (record screenshots / video for each)

| Phase | Done when |
|---|---|
| B1 | `terraform apply` in infra/bootstrap OK; `terraform output` gives state bucket + infra role |
| B2 | `terraform fmt -check -recursive infra`, `terraform validate`, `terraform plan` shows the full architecture |
| B3 | `kubectl get nodes` = 2 nodes; `kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-load-balancer-controller`; `kubectl -n external-secrets get pods` |
| B4 | a PR with a fake token is blocked; scan reports are downloadable from the run |
| B5 | Argo CD app Synced/Healthy; `kubectl -n taskboard get pvc` Bound (gp3); target group healthy |
| B6 | publishing v1.0.0 ends with the app showing `frontend v1.0.0 - backend v1.0.0` |

## B7 demo scenarios

1. **Secret blocked** - branch `demo/secret`, add `app/backend/demo.txt` containing `ghp_` + 36 random letters/digits, open a PR:
   Gitleaks/TruffleHog/Trivy fail; the report shows file and line, not the secret (gitleaks runs with redaction).
2. **Vulnerability blocked** - PR pinning an old library (e.g. `pyyaml==5.3` or `jinja2==2.11.0`) in `app/backend/requirements.txt`: the Trivy fs scan fails.
3. **Release v1.1.0** - change the page title in `app/frontend/app/layout.tsx`, merge, publish `v1.1.0`:
   image promotion -> GitOps PR -> merge -> Argo CD -> approve `production` -> new version live.
4. **Rollback** - `git revert <deployment commit>` via PR; Argo CD returns to v1.0.0.
5. **Self-healing** - `kubectl -n taskboard scale deploy taskboard-backend --replicas=0` -> Argo CD restores 2 replicas.
6. **Persistence** - `kubectl -n taskboard delete pod taskboard-postgres-0`; tasks still there (EBS).
7. **Security** - `curl -i http://<alb_dns_name>/api/health` from your laptop: 403 / refused; `curl https://<cloudfront>/api/health` works.

## Troubleshooting quick map

| Symptom | Look at |
|---|---|
| first apply fails on Helm releases | re-run apply (cluster not ready yet) or `terraform apply -target=module.eks` first |
| ExternalSecret not ready | `kubectl describe externalsecret -n taskboard`; Pod Identity association of SA `external-secrets`; secret name/region in values-prod |
| target group has no targets | logs of `aws-load-balancer-controller` (kube-system); TargetGroupBinding events |
| CloudFront /api/* 403 | X-Origin-Verify must match in CloudFront and the ALB rule (both come from the same `random_password`) |
| CloudFront /api/* 502/504 | SG rule ALB -> cluster SG on 8000; pod readiness |
| PVC Pending | EBS CSI add-on + Pod Identity role; `kubectl get sc` - the name must match `postgres.storage.storageClass` in values-prod.yaml |
| Argo CD "repository not found" | repo must be public; check every `repoURL` |
| release PR not created | enable "Allow GitHub Actions to create and approve pull requests" |

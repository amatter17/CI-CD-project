# infra/bootstrap

Applied **once from your laptop** (local state, committed nowhere). Creates what the pipelines need before they can run Terraform:
the state bucket, the GitHub OIDC provider and the role `taskboard-github-infra`.

```bash
cp terraform.tfvars.example terraform.tfvars   # fill in github_repository
terraform init && terraform apply
terraform output                                # -> GitHub variables TF_STATE_BUCKET and AWS_INFRA_ROLE_ARN
```

If the account already has the GitHub OIDC provider, import it first:
`terraform import aws_iam_openid_connect_provider.github arn:aws:iam::<account>:oidc-provider/token.actions.githubusercontent.com`

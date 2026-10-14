output "state_bucket" {
  description = "-> GitHub variable TF_STATE_BUCKET"
  value       = aws_s3_bucket.state.bucket
}

output "infra_role_arn" {
  description = "-> GitHub variable AWS_INFRA_ROLE_ARN"
  value       = aws_iam_role.infra.arn
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}

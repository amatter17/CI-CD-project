output "github_deploy_role_arn" {
  description = "-> GitHub variable AWS_DEPLOY_ROLE_ARN"
  value       = module.github_deploy_role.role_arn
}

output "ecr_repository_url" {
  description = "-> GitHub variable ECR_REPOSITORY_URL and values-prod.yaml backend.image.repository"
  value       = module.ecr.repository_url
}

output "frontend_bucket" {
  description = "-> GitHub variable FRONTEND_BUCKET"
  value       = module.static_site.bucket_name
}

output "cloudfront_distribution_id" {
  description = "-> GitHub variable CLOUDFRONT_DISTRIBUTION_ID"
  value       = module.static_site.distribution_id
}

output "app_url" {
  description = "-> GitHub variable APP_URL"
  value       = "https://${module.static_site.domain_name}"
}

output "backend_target_group_arn" {
  description = "-> values-prod.yaml targetGroupBinding.targetGroupArn"
  value       = module.backend_alb.target_group_arn
}

output "alb_dns_name" {
  description = "Direct ALB name: must be REFUSED from the internet (demo scenario 7)"
  value       = module.backend_alb.alb_dns_name
}

output "db_secret_name" {
  description = "-> values-prod.yaml credentials.external.remoteKey"
  value       = aws_secretsmanager_secret.db.name
}

output "cluster_name" {
  value = module.eks.cluster_name
}

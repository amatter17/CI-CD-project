locals {
  name         = "taskboard-prod"
  cluster_name = "taskboard-prod"
  db_secret    = "taskboard/prod/db-password"
  backend_port = 8000
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# ------------------------------------------------------------------ secrets (never in Git: generated here, kept in Secrets Manager / state)
resource "random_password" "db" {
  length  = 32
  special = false
}

resource "random_password" "origin_verify" {
  length  = 40
  special = false
}

resource "aws_secretsmanager_secret" "db" {
  name        = local.db_secret
  description = "TaskBoard PostgreSQL password (copied into the cluster by the External Secrets Operator)"
  # lab setting: lets you destroy and re-apply the same day without "secret scheduled for deletion" errors
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id     = aws_secretsmanager_secret.db.id
  secret_string = random_password.db.result
}

# ------------------------------------------------------------------ network + cluster
module "network" {
  source = "../../modules/network"

  name         = local.name
  cluster_name = local.cluster_name
}

module "eks" {
  source = "../../modules/eks"

  cluster_name         = local.cluster_name
  kubernetes_version   = var.kubernetes_version
  vpc_id               = module.network.vpc_id
  private_subnet_ids   = module.network.private_subnet_ids
  admin_principal_arns = distinct(concat(var.eks_admin_principal_arns, [var.infra_role_arn]))
}

# ------------------------------------------------------------------ images
module "ecr" {
  source = "../../modules/ecr"

  name = "taskboard-backend"
}

# ------------------------------------------------------------------ backend entry point + frontend
module "backend_alb" {
  source = "../../modules/backendalb"

  name                 = local.name
  vpc_id               = module.network.vpc_id
  vpc_cidr             = module.network.vpc_cidr
  public_subnet_ids    = module.network.public_subnet_ids
  origin_verify_secret = random_password.origin_verify.result
  target_port          = local.backend_port
}

module "static_site" {
  source = "../../modules/staticsite"

  name                 = local.name
  alb_dns_name         = module.backend_alb.alb_dns_name
  origin_verify_secret = random_password.origin_verify.result
}

# ALB -> pods on 8000 (pods use the cluster security group)
resource "aws_vpc_security_group_ingress_rule" "alb_to_pods" {
  security_group_id            = module.eks.cluster_security_group_id
  description                  = "ALB to TaskBoard backend pods"
  referenced_security_group_id = module.backend_alb.alb_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = local.backend_port
  to_port                      = local.backend_port
}

# ------------------------------------------------------------------ in-cluster add-ons the chart needs
module "platform" {
  source = "../../modules/platform"

  cluster_name         = module.eks.cluster_name
  region               = var.region
  vpc_id               = module.network.vpc_id
  cluster_ready        = module.eks.ready
  external_secret_arns = [aws_secretsmanager_secret.db.arn]
}

# ------------------------------------------------------------------ GitHub Actions deploy role (least privilege)
data "aws_iam_policy_document" "deploy" {
  statement {
    sid       = "EcrLogin"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"] # this API cannot be scoped to a repository
  }

  statement {
    sid    = "EcrPushAndPromote"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:DescribeImages",
    ]
    resources = [module.ecr.repository_arn]
  }

  statement {
    sid       = "FrontendBucketObjects"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:DeleteObject", "s3:GetObject"]
    resources = ["${module.static_site.bucket_arn}/*"]
  }

  statement {
    sid       = "FrontendBucketList"
    effect    = "Allow"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [module.static_site.bucket_arn]
  }

  statement {
    sid       = "InvalidateDistribution"
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"]
    resources = [module.static_site.distribution_arn]
  }
}

module "github_deploy_role" {
  source = "../../modules/githuboidc-role"

  name              = "taskboard-prod-github-deploy"
  oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn
  policy_json       = data.aws_iam_policy_document.deploy.json

  subjects = [
    "repo:${var.github_repository}:ref:refs/heads/main",                      # backend workflow pushes sha-<commit>
    "repo:${var.github_repository}:ref:refs/tags/v*",                         # release workflow: image promotion
    "repo:${var.github_repository}:environment:${var.production_environment}", # release workflow: frontend deploy
  ]
}

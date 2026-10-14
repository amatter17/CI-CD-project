data "aws_caller_identity" "current" {}

locals {
  state_bucket = coalesce(var.state_bucket_name, "taskboard-tfstate-${data.aws_caller_identity.current.account_id}")
  repo         = var.github_repository
}

# ---------------------------------------------------------------- Terraform state bucket
resource "aws_s3_bucket" "state" {
  bucket = local.state_bucket

  # state of the whole platform lives here: never destroy it by accident
  lifecycle {
    prevent_destroy = false # set to true once you are done experimenting
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "state_tls_only" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state_tls_only.json

  depends_on = [aws_s3_bucket_public_access_block.state]
}

# ---------------------------------------------------------------- GitHub OIDC provider
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # AWS validates GitHub's certificate chain itself; the value is kept for older provider/API combinations
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# ---------------------------------------------------------------- role assumed by the infra workflow
data "aws_iam_policy_document" "infra_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # only THIS repository: pull requests, the main branch, and the "infrastructure" environment (approved apply)
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${local.repo}:pull_request",
        "repo:${local.repo}:ref:refs/heads/main",
        "repo:${local.repo}:environment:${var.infra_environment}",
      ]
    }
  }
}

resource "aws_iam_role" "infra" {
  name                 = "taskboard-github-infra"
  assume_role_policy   = data.aws_iam_policy_document.infra_trust.json
  max_session_duration = 3600
}

# Terraform creates VPC, EKS, IAM roles, CloudFront, ... so this role needs broad rights.
# Trade-off (see README "Decisions & trade-offs"): in a real company scope this down with a permissions boundary.
resource "aws_iam_role_policy_attachment" "infra_admin" {
  role       = aws_iam_role.infra.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

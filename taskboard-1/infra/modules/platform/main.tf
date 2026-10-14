terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
  }
}

variable "cluster_name" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "cluster_ready" {
  description = "Any value that only exists once the cluster, nodes and add-ons are ready (forces the right order)."
  type        = string
}

variable "external_secret_arns" {
  description = "Secrets Manager secrets the External Secrets Operator may read."
  type        = list(string)
}

variable "alb_controller_chart_version" {
  description = "aws-load-balancer-controller chart version (repo https://aws.github.io/eks-charts). Check: helm search repo eks/aws-load-balancer-controller"
  type        = string
  default     = "1.13.4"
}

variable "external_secrets_chart_version" {
  description = "external-secrets chart version (repo https://charts.external-secrets.io). Check: helm search repo external-secrets/external-secrets. Must be >= 0.17 (API external-secrets.io/v1)."
  type        = string
  default     = "1.0.0"
}

data "aws_iam_policy_document" "pod_identity_trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

# =============================================================== AWS Load Balancer Controller (TargetGroupBinding only)
# Least privilege for the way we use it: it never creates load balancers (Terraform owns the ALB),
# it only reads them and registers/deregisters pod IPs in the existing target group.
data "aws_iam_policy_document" "alb_controller" {
  statement {
    sid    = "Describe"
    effect = "Allow"
    actions = [
      "ec2:Describe*",
      "elasticloadbalancing:Describe*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "RegisterTargets"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
    ]
    resources = ["arn:aws:elasticloadbalancing:${var.region}:*:targetgroup/*/*"]
  }
}

resource "aws_iam_role" "alb_controller" {
  name               = "${var.cluster_name}-alb-controller"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
}

resource "aws_iam_role_policy" "alb_controller" {
  name   = "target-group-binding"
  role   = aws_iam_role.alb_controller.id
  policy = data.aws_iam_policy_document.alb_controller.json
}

resource "aws_eks_pod_identity_association" "alb_controller" {
  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.alb_controller.arn
}

resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.alb_controller_chart_version

  wait    = true
  timeout = 600

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  # we only use TargetGroupBinding: no WAF / Shield calls, no managed backend security group
  set {
    name  = "enableShield"
    value = "false"
  }

  set {
    name  = "enableWaf"
    value = "false"
  }

  set {
    name  = "enableWafv2"
    value = "false"
  }

  set {
    name  = "enableBackendSecurityGroup"
    value = "false"
  }

  depends_on = [
    aws_eks_pod_identity_association.alb_controller,
    aws_iam_role_policy.alb_controller,
    terraform_data.cluster_ready,
  ]
}

# =============================================================== External Secrets Operator
data "aws_iam_policy_document" "external_secrets" {
  statement {
    sid    = "ReadSecrets"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = var.external_secret_arns
  }
}

resource "aws_iam_role" "external_secrets" {
  name               = "${var.cluster_name}-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
}

resource "aws_iam_role_policy" "external_secrets" {
  name   = "read-db-secret"
  role   = aws_iam_role.external_secrets.id
  policy = data.aws_iam_policy_document.external_secrets.json
}

resource "aws_eks_pod_identity_association" "external_secrets" {
  cluster_name    = var.cluster_name
  namespace       = "external-secrets"
  service_account = "external-secrets"
  role_arn        = aws_iam_role.external_secrets.arn
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.external_secrets_chart_version

  wait    = true
  timeout = 600

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "external-secrets"
  }

  depends_on = [
    aws_eks_pod_identity_association.external_secrets,
    aws_iam_role_policy.external_secrets,
    terraform_data.cluster_ready,
  ]
}

# carries the "cluster is ready" value into the dependency graph
resource "terraform_data" "cluster_ready" {
  input = var.cluster_ready
}

output "alb_controller_role_arn" {
  value = aws_iam_role.alb_controller.arn
}

output "external_secrets_role_arn" {
  value = aws_iam_role.external_secrets.arn
}

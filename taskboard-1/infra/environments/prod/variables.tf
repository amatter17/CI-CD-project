variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "github_repository" {
  description = "owner/name of the GitHub repository (OIDC trust of the deploy role)."
  type        = string
}

variable "infra_role_arn" {
  description = "Role used by the infra workflow (bootstrap output). It becomes cluster-admin so the Helm provider can work."
  type        = string
}

variable "eks_admin_principal_arns" {
  description = "Your IAM user/role ARNs: cluster-admin on the cluster."
  type        = list(string)
}

variable "kubernetes_version" {
  type    = string
  default = "1.34"
}

variable "production_environment" {
  description = "GitHub environment of the frontend deploy job."
  type        = string
  default     = "production"
}

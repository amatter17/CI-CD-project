variable "region" {
  description = "AWS region."
  type        = string
  default     = "eu-west-1"
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the infra role, as owner/name (e.g. jane/taskboard)."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", var.github_repository))
    error_message = "Use the form owner/repository."
  }
}

variable "state_bucket_name" {
  description = "Name of the Terraform state bucket. Null = taskboard-tfstate-<account id> (globally unique)."
  type        = string
  default     = null
}

variable "infra_environment" {
  description = "GitHub environment used by the apply job."
  type        = string
  default     = "infrastructure"
}

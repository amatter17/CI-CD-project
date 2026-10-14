variable "cluster_name" {
  type = string
}

variable "kubernetes_version" {
  type    = string
  default = "1.34"
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  description = "Subnets for the nodes and the control-plane ENIs."
  type        = list(string)
}

variable "admin_principal_arns" {
  description = "IAM users/roles that get cluster-admin (EKS access entries). Include the role that runs Terraform."
  type        = list(string)
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 3
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to reach the PUBLIC Kubernetes API endpoint (GitHub runners + your laptop need it)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "addon_versions" {
  description = "Optional pinned add-on versions by add-on name; missing = the default version for the cluster version."
  type        = map(string)
  default     = {}
}

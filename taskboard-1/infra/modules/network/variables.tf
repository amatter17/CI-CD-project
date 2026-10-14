variable "name" {
  type = string
}

variable "cluster_name" {
  description = "EKS cluster name, used for the subnet discovery tags."
  type        = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "az_count" {
  type    = number
  default = 2
}

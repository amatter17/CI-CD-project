provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "taskboard"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}

# Helm talks to the cluster Terraform just created (token from the AWS CLI, same identity as Terraform)
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region]
    }
  }
}

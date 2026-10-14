# Remote state in S3 with native locking (use_lockfile, Terraform >= 1.10: no DynamoDB table needed).
# The bucket name is NOT written here; pass it at init time:
#   terraform init -backend-config="bucket=<TF_STATE_BUCKET>"
terraform {
  backend "s3" {
    key          = "prod/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}

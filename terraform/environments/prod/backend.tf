# ---------------------------------------------------------------------------
# Remote state backend – S3 with native state locking (Terraform >= 1.10).
# Native locking writes a .tflock file to the same S3 bucket – no DynamoDB
# table required.
#
# Replace bucket name and region to match your AWS account.
# ---------------------------------------------------------------------------
terraform {
  backend "s3" {
    bucket       = "my-tfstate-bucket"
    key          = "helloworld/prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

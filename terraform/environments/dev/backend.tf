# ---------------------------------------------------------------------------
# Remote state backend – S3 with native state locking (Terraform >= 1.10).
# Each environment has its own key, giving fully isolated blast radius.
# Native locking writes a .tflock file to the same S3 bucket – no DynamoDB
# table required.
#
# Prerequisites (one-time, manual):
#   aws s3 mb s3://my-tfstate-bucket --region us-east-1
#   aws s3api put-bucket-versioning --bucket my-tfstate-bucket \
#       --versioning-configuration Status=Enabled
#
# Replace bucket name and region to match your AWS account.
# ---------------------------------------------------------------------------
terraform {
  backend "s3" {
    bucket       = "my-tfstate-bucket"
    key          = "helloworld/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

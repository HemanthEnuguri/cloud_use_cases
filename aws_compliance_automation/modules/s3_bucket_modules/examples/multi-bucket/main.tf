provider "aws" {
  region = "us-east-1"
}

locals {
  bucket_names = [
    for i in range(3) : "replace-me-team-${format("%02d", i + 1)}"
  ]
}

module "team_buckets" {
  source   = "../../"
  for_each = toset(local.bucket_names)

  bucket_name = each.value

  tags = {
    Team        = "platform"
    Environment = "dev"
  }

  enable_versioning          = true
  enable_public_access_block = true
  enable_ssl_only_policy     = true
}

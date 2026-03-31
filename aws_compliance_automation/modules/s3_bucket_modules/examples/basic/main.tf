provider "aws" {
  region = "us-east-1"
}

module "app_bucket" {
  source = "../../"

  bucket_name = "replace-me-example-bucket"

  tags = {
    Application = "demo"
    Environment = "dev"
  }

  enable_versioning           = true
  enable_public_access_block  = true
  enable_ssl_only_policy      = true
  enable_server_access_logging = true
  logging_target_bucket       = "replace-me-log-bucket"
  logging_target_prefix       = "s3-access/"

  sse_algorithm      = "AES256"
  bucket_key_enabled = true

  lifecycle_rules = [
    {
      id     = "expire-old-logs"
      status = "Enabled"
      filter = {
        prefix = "logs/"
      }
      expiration = {
        days = 90
      }
    }
  ]
}

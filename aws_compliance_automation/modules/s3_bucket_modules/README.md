# S3 bucket module

This module creates **one S3 bucket per module instance** and manages the common standalone S3 configuration resources that AWS provider versions 4+ split out from `aws_s3_bucket`.

## Why this shape

Your pasted code mixes:
- a counted multi-bucket implementation
- a single-bucket feature extension pattern
- inconsistent references such as `aws_s3_bucket.bucket`, `aws_s3_bucket.this[0]`, and `aws_s3_bucket.this[count.index]`

This module normalizes that into a single-bucket module. If you need many buckets, instantiate it with `for_each` from the caller.

## Files

- `versions.tf`
- `variables.tf`
- `locals.tf`
- `data.tf`
- `main.tf`
- `outputs.tf`

## Basic usage

```hcl
module "app_bucket" {
  source = "../../"

  bucket_name = "my-app-prod-bucket"

  tags = {
    Application = "my-app"
    Environment = "prod"
  }

  enable_versioning = true

  sse_algorithm     = "aws:kms"
  kms_key_id        = "arn:aws:kms:us-east-1:111122223333:key/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  bucket_key_enabled = true

  enable_server_access_logging = true
  logging_target_bucket        = "my-log-archive-bucket"
  logging_target_prefix        = "s3/"
}
```

## Multi-bucket usage

```hcl
locals {
  bucket_names = [
    for i in range(2) : "my-team-${format("%02d", i + 1)}"
  ]
}

module "buckets" {
  source   = "../../"
  for_each = toset(local.bucket_names)

  bucket_name = each.value

  tags = {
    Team = "platform"
  }
}
```

## Notes

- If you enable Lambda notifications and set `create_permission = true`, the module creates `aws_lambda_permission`.
- If you enable SQS or SNS notifications and set `create_policy = true`, the module creates the target queue/topic policy.
- For SQS target policy creation, `queue_url` must be provided.

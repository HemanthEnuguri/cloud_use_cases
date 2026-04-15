locals {
  # Generate computed bucket names with zero-padded numbers (01-99)
  bucket_names = var.bucket_name != null ? [var.bucket_name] : [
    for i in range(var.bucket_count) : "${var.name_prefix}${format("%02d", i + 1)}"
  ]
  
  # Support both new count approach and legacy single bucket
  actual_bucket_count = var.bucket_name != null ? 1 : var.bucket_count
}

resource "aws_s3_bucket" "this" {
  count = local.actual_bucket_count
  
  bucket = local.bucket_names[count.index]
  tags   = var.tags
  
  # Drift detection and lifecycle management
  lifecycle {
    # Prevent accidental deletion
    prevent_destroy = false  # Set to true in production
    
    # Ignore changes to tags if managed by external systems
    ignore_changes = [
      # Uncomment if tags are managed externally
      # tags,
      # Ignore lifecycle configuration if managed separately
      # lifecycle_rule
    ]
  }
}

# Public Access Block (CID61, CID65, CID60, CID64, CID59, CID63)
resource "aws_s3_bucket_public_access_block" "this" {
  count = var.enable_public_access_block ? local.actual_bucket_count : 0

  bucket                  = aws_s3_bucket.this[count.index].id
  block_public_acls       = true  # CID61, CID65
  block_public_policy     = true  # CID60, CID64
  ignore_public_acls      = true  # CID65
  restrict_public_buckets = true  # CID59, CID63
}

# Server-side encryption configuration
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  count = local.actual_bucket_count
  
  bucket = aws_s3_bucket.this[count.index].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.sse_algorithm
      kms_master_key_id = var.kms_key_id
    }
    bucket_key_enabled = var.bucket_key_enabled
  }
}

# Server Access Logging (CID47)
resource "aws_s3_bucket_logging" "this" {
  count = var.enable_server_access_logging ? local.actual_bucket_count : 0

  bucket        = aws_s3_bucket.this[count.index].id
  target_bucket = var.logging_target_bucket
  target_prefix = "${var.logging_target_prefix}${local.bucket_names[count.index]}/"
}

# Versioning (CID-48)
resource "aws_s3_bucket_versioning" "this" {
  count = var.enable_versioning ? local.actual_bucket_count : 0

  bucket = aws_s3_bucket.this[count.index].id
  versioning_configuration {
    status     = "Enabled"
    mfa_delete = var.enable_mfa_delete ? "Enabled" : "Disabled"
  }
}

# SSL-only Traffic Policy (CID-57)
data "aws_iam_policy_document" "ssl_only_policy" {
  count = var.enable_ssl_only_policy ? local.actual_bucket_count : 0

  statement {
    sid    = "AllowSSLRequestOnly"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.this[count.index].arn,
      "${aws_s3_bucket.this[count.index].arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # CID-379 - Ensure logging buckets do not allow WRITE from everyone
  # This control shall be applied in the Log Bucket policy in Log Archive account
}

resource "aws_s3_bucket_policy" "this" {
  count = var.enable_ssl_only_policy ? local.actual_bucket_count : 0

  bucket = aws_s3_bucket.this[count.index].id
  policy = data.aws_iam_policy_document.ssl_only_policy[count.index].json
  
  lifecycle {
    # Prevent policy from being destroyed if it has dependencies
    create_before_destroy = true
  }
}

# Drift detection - Data sources for validation
data "aws_s3_bucket" "drift_check" {
  count = var.enable_drift_detection ? local.actual_bucket_count : 0
  
  bucket = aws_s3_bucket.this[count.index].id
  
  depends_on = [aws_s3_bucket.this]
}

data "aws_s3_bucket_policy" "drift_check" {
  count = var.enable_drift_detection && var.enable_ssl_only_policy ? local.actual_bucket_count : 0
  
  bucket = aws_s3_bucket.this[count.index].id
  
  depends_on = [aws_s3_bucket_policy.this]
}

data "aws_s3_bucket_encryption" "drift_check" {
  count = var.enable_drift_detection ? local.actual_bucket_count : 0
  
  bucket = aws_s3_bucket.this[count.index].id
  
  depends_on = [aws_s3_bucket_server_side_encryption_configuration.this]
}

data "aws_s3_bucket_versioning" "drift_check" {
  count = var.enable_drift_detection && var.enable_versioning ? local.actual_bucket_count : 0
  
  bucket = aws_s3_bucket.this[count.index].id
  
  depends_on = [aws_s3_bucket_versioning.this]
}

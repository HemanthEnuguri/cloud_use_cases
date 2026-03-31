resource "aws_s3_bucket" "bucket" {
 // count = local.create_bucket && !var.is_directory_bucket ? 1 : 0

  region = var.region

  bucket           = var.bucket
  bucket_prefix    = var.bucket_prefix
  bucket_namespace = var.bucket_namespace

  force_destroy       = var.force_destroy
  object_lock_enabled = var.object_lock_enabled
  tags                = var.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  count = local.create_bucket && length(keys(var.server_side_encryption_configuration)) > 0 ? 1 : 0

  region = var.region

  bucket                = aws_s3_bucket.bucket.id
  expected_bucket_owner = var.expected_bucket_owner

  dynamic "rule" {
    for_each = try(flatten([var.server_side_encryption_configuration["rule"]]), [])

    content {
      bucket_key_enabled = try(rule.value.bucket_key_enabled, null)

      dynamic "apply_server_side_encryption_by_default" {
        for_each = try([rule.value.apply_server_side_encryption_by_default], [])

        content {
          sse_algorithm     = apply_server_side_encryption_by_default.value.sse_algorithm
          kms_master_key_id = try(apply_server_side_encryption_by_default.value.kms_master_key_id, null)
        }
      }
      blocked_encryption_types = try(rule.value.blocked_encryption_types, null)
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count = local.create_bucket && length(local.lifecycle_rules) > 0 ? 1 : 0

  region = var.region

  bucket                                 = aws_s3_bucket.bucket.id
 // expected_bucket_owner                  = var.expected_bucket_owner
 // transition_default_minimum_object_size = var.transition_default_minimum_object_size

  dynamic "rule" {
    for_each = local.lifecycle_rules

    content {
      id     = try(rule.value.id, null)
      status = try(rule.value.enabled ? "Enabled" : "Disabled", tobool(rule.value.status) ? "Enabled" : "Disabled", title(lower(rule.value.status)))

      # Max 1 block - abort_incomplete_multipart_upload
      dynamic "abort_incomplete_multipart_upload" {
        for_each = try([rule.value.abort_incomplete_multipart_upload_days], [])

        content {
          days_after_initiation = try(rule.value.abort_incomplete_multipart_upload_days, null)
        }
      }


      # Max 1 block - expiration
      dynamic "expiration" {
        for_each = try(flatten([rule.value.expiration]), [])

        content {
          date                         = try(expiration.value.date, null)
          days                         = try(expiration.value.days, null)
          expired_object_delete_marker = try(expiration.value.expired_object_delete_marker, null)
        }
      }

      # Several blocks - transition
      dynamic "transition" {
        for_each = try(flatten([rule.value.transition]), [])

        content {
          date          = try(transition.value.date, null)
          days          = try(transition.value.days, null)
          storage_class = transition.value.storage_class
        }
      }

      # Max 1 block - noncurrent_version_expiration
      dynamic "noncurrent_version_expiration" {
        for_each = try(flatten([rule.value.noncurrent_version_expiration]), [])

        content {
          newer_noncurrent_versions = try(noncurrent_version_expiration.value.newer_noncurrent_versions, null)
          noncurrent_days           = try(noncurrent_version_expiration.value.days, noncurrent_version_expiration.value.noncurrent_days, null)
        }
      }

      # Several blocks - noncurrent_version_transition
      dynamic "noncurrent_version_transition" {
        for_each = try(flatten([rule.value.noncurrent_version_transition]), [])

        content {
          newer_noncurrent_versions = try(noncurrent_version_transition.value.newer_noncurrent_versions, null)
          noncurrent_days           = try(noncurrent_version_transition.value.days, noncurrent_version_transition.value.noncurrent_days, null)
          storage_class             = noncurrent_version_transition.value.storage_class
        }
      }

      # Max 1 block - filter - without any key arguments or tags
      dynamic "filter" {
        for_each = length(try(flatten([rule.value.filter]), [])) == 0 ? [true] : []

        content {
          #          prefix = ""
        }
      }

      # Max 1 block - filter - with one key argument or a single tag
      dynamic "filter" {
        for_each = [for v in try(flatten([rule.value.filter]), []) : v if max(length(keys(v)), length(try(rule.value.filter.tags, rule.value.filter.tag, []))) == 1]

        content {
          object_size_greater_than = try(filter.value.object_size_greater_than, null)
          object_size_less_than    = try(filter.value.object_size_less_than, null)
          prefix                   = try(filter.value.prefix, null)

          dynamic "tag" {
            for_each = try(filter.value.tags, filter.value.tag, [])

            content {
              key   = tag.key
              value = tag.value
            }
          }
        }
      }

      # Max 1 block - filter - with more than one key arguments or multiple tags
      dynamic "filter" {
        for_each = [for v in try(flatten([rule.value.filter]), []) : v if max(length(keys(v)), length(try(rule.value.filter.tags, rule.value.filter.tag, []))) > 1]

        content {
          and {
            object_size_greater_than = try(filter.value.object_size_greater_than, null)
            object_size_less_than    = try(filter.value.object_size_less_than, null)
            prefix                   = try(filter.value.prefix, null)
            tags                     = try(filter.value.tags, filter.value.tag, null)
          }
        }
      }
    }
  }

  depends_on = [
    # Must have bucket versioning enabled first
    aws_s3_bucket_versioning.this,
    # Must wait for replication configuration to propagate
    aws_s3_bucket_replication_configuration.this
  ]
}


resource "aws_s3_bucket_policy" "this" {
  count = local.create_bucket && local.attach_policy ? 1 : 0
  region = var.region
  bucket = aws_s3_bucket.bucket.id
  policy = local.policy

  depends_on = [
    aws_s3_bucket_public_access_block.this
  ]
}

resource "aws_s3_bucket_ownership_controls" "this" {
  count = local.create_bucket && var.control_object_ownership && !var.is_directory_bucket ? 1 : 0

  region = var.region

  bucket = aws_s3_bucket.bucket.id

  rule {
    object_ownership = var.object_ownership
  }

  # This `depends_on` is to prevent "A conflicting conditional operation is currently in progress against this resource."
  depends_on = [
    aws_s3_bucket_policy.this,
    aws_s3_bucket_public_access_block.this,
    aws_s3_bucket.this
  ]
}

resource "aws_s3_bucket_logging" "this" {
  count = local.create_bucket && length(keys(var.logging)) > 0 && !var.is_directory_bucket ? 1 : 0

  region = var.region

  bucket = aws_s3_bucket.this[0].id

  target_bucket = var.logging["target_bucket"]
  target_prefix = var.logging["target_prefix"]

  dynamic "target_object_key_format" {
    for_each = try([var.logging["target_object_key_format"]], [])

    content {
      dynamic "partitioned_prefix" {
        for_each = try(target_object_key_format.value["partitioned_prefix"], [])

        content {
          partition_date_source = try(partitioned_prefix.value, null)
        }
      }

      dynamic "simple_prefix" {
        for_each = length(try(target_object_key_format.value["partitioned_prefix"], [])) == 0 || can(target_object_key_format.value["simple_prefix"]) ? [true] : []

        content {}
      }
    }
  }
}

resource "aws_s3_bucket_versioning" "this" {
  count = local.create_bucket && length(keys(var.versioning)) > 0 && !var.is_directory_bucket ? 1 : 0

  region = var.region

  bucket                = aws_s3_bucket.this[0].id
  expected_bucket_owner = var.expected_bucket_owner
  mfa                   = try(var.versioning["mfa"], null)

  versioning_configuration {
    # Valid values: "Enabled" or "Suspended"
    status = try(var.versioning["enabled"] ? "Enabled" : "Suspended", tobool(var.versioning["status"]) ? "Enabled" : "Suspended", title(lower(var.versioning["status"])), "Enabled")

    # Valid values: "Enabled" or "Disabled"
    mfa_delete = try(tobool(var.versioning["mfa_delete"]) ? "Enabled" : "Disabled", title(lower(var.versioning["mfa_delete"])), null)
  }
}


resource "aws_s3_bucket_intelligent_tiering_configuration" "this" {
  for_each = { for k, v in local.intelligent_tiering : k => v if local.create_bucket && !var.is_directory_bucket }

  region = var.region

  name   = each.key
  bucket = aws_s3_bucket.this[0].id
  status = try(tobool(each.value.status) ? "Enabled" : "Disabled", title(lower(each.value.status)), null)

  # Max 1 block - filter
  dynamic "filter" {
    for_each = length(try(flatten([each.value.filter]), [])) == 0 ? [] : [true]

    content {
      prefix = try(each.value.filter.prefix, null)
      tags   = try(each.value.filter.tags, null)
    }
  }

  dynamic "tiering" {
    for_each = each.value.tiering

    content {
      access_tier = tiering.key
      days        = tiering.value.days
    }
  }

}

resource "aws_s3_bucket_notification" "this" {
  count = var.create ? 1 : 0

  bucket = var.bucket

  region = var.region

  eventbridge = var.eventbridge

  dynamic "lambda_function" {
    for_each = var.lambda_notifications

    content {
      id                  = try(lambda_function.value.id, lambda_function.key)
      lambda_function_arn = lambda_function.value.function_arn
      events              = lambda_function.value.events
      filter_prefix       = try(lambda_function.value.filter_prefix, null)
      filter_suffix       = try(lambda_function.value.filter_suffix, null)
    }
  }

  dynamic "queue" {
    for_each = var.sqs_notifications

    content {
      id            = try(queue.value.id, queue.key)
      queue_arn     = queue.value.queue_arn
      events        = queue.value.events
      filter_prefix = try(queue.value.filter_prefix, null)
      filter_suffix = try(queue.value.filter_suffix, null)
    }
  }

  dynamic "topic" {
    for_each = var.sns_notifications

    content {
      id            = try(topic.value.id, topic.key)
      topic_arn     = topic.value.topic_arn
      events        = topic.value.events
      filter_prefix = try(topic.value.filter_prefix, null)
      filter_suffix = try(topic.value.filter_suffix, null)
    }
  }

  depends_on = [
    aws_lambda_permission.allow,
    aws_sqs_queue_policy.allow,
    aws_sns_topic_policy.allow,
  ]
}


//existing code
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
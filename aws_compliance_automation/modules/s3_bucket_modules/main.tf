resource "aws_s3_bucket" "this" {
  bucket              = var.bucket_name
  force_destroy       = var.force_destroy
  object_lock_enabled = var.object_lock_enabled
  tags                = var.tags
}

resource "aws_s3_bucket_public_access_block" "this" {
  count = var.enable_public_access_block ? 1 : 0

  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = var.block_public_acls
  block_public_policy     = var.block_public_policy
  ignore_public_acls      = var.ignore_public_acls
  restrict_public_buckets = var.restrict_public_buckets
}

resource "aws_s3_bucket_ownership_controls" "this" {
  count = var.control_object_ownership ? 1 : 0

  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = var.object_ownership
  }

  depends_on = [
    aws_s3_bucket_public_access_block.this,
  ]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    bucket_key_enabled = var.bucket_key_enabled

    apply_server_side_encryption_by_default {
      sse_algorithm     = var.sse_algorithm
      kms_master_key_id = var.kms_key_id
    }
  }
}

resource "aws_s3_bucket_versioning" "this" {
  count = var.enable_versioning ? 1 : 0

  bucket = aws_s3_bucket.this.id
  mfa    = var.mfa

  versioning_configuration {
    status     = "Enabled"
    mfa_delete = var.enable_mfa_delete ? "Enabled" : "Disabled"
  }
}

resource "aws_s3_bucket_logging" "this" {
  count = local.create_logging ? 1 : 0

  bucket        = aws_s3_bucket.this.id
  target_bucket = var.logging_target_bucket
  target_prefix = "${var.logging_target_prefix}${var.bucket_name}/"

  dynamic "target_object_key_format" {
    for_each = (var.logging_partition_date_source != null || var.logging_use_simple_prefix) ? [1] : []

    content {
      dynamic "partitioned_prefix" {
        for_each = var.logging_partition_date_source != null ? [1] : []

        content {
          partition_date_source = var.logging_partition_date_source
        }
      }

      dynamic "simple_prefix" {
        for_each = var.logging_partition_date_source == null && var.logging_use_simple_prefix ? [1] : []

        content {}
      }
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count = length(var.lifecycle_rules) > 0 ? 1 : 0

  bucket = aws_s3_bucket.this.id

  dynamic "rule" {
    for_each = var.lifecycle_rules

    content {
      id     = try(rule.value.id, null)
      status = try(rule.value.status, "Enabled")

      dynamic "abort_incomplete_multipart_upload" {
        for_each = try(rule.value.abort_incomplete_multipart_upload_days, null) != null ? [1] : []

        content {
          days_after_initiation = rule.value.abort_incomplete_multipart_upload_days
        }
      }

      dynamic "expiration" {
        for_each = try(rule.value.expiration, null) != null ? [rule.value.expiration] : []

        content {
          date                         = try(expiration.value.date, null)
          days                         = try(expiration.value.days, null)
          expired_object_delete_marker = try(expiration.value.expired_object_delete_marker, null)
        }
      }

      dynamic "transition" {
        for_each = try(rule.value.transitions, [])

        content {
          date          = try(transition.value.date, null)
          days          = try(transition.value.days, null)
          storage_class = transition.value.storage_class
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = try(rule.value.noncurrent_version_expiration, null) != null ? [rule.value.noncurrent_version_expiration] : []

        content {
          newer_noncurrent_versions = try(noncurrent_version_expiration.value.newer_noncurrent_versions, null)
          noncurrent_days           = noncurrent_version_expiration.value.noncurrent_days
        }
      }

      dynamic "noncurrent_version_transition" {
        for_each = try(rule.value.noncurrent_version_transitions, [])

        content {
          newer_noncurrent_versions = try(noncurrent_version_transition.value.newer_noncurrent_versions, null)
          noncurrent_days           = noncurrent_version_transition.value.noncurrent_days
          storage_class             = noncurrent_version_transition.value.storage_class
        }
      }

      dynamic "filter" {
        for_each = try(rule.value.filter, null) == null ? [1] : []

        content {}
      }

      dynamic "filter" {
        for_each = (
          try(rule.value.filter, null) != null &&
          (
            (try(rule.value.filter.prefix, null) != null ? 1 : 0) +
            (try(rule.value.filter.object_size_greater_than, null) != null ? 1 : 0) +
            (try(rule.value.filter.object_size_less_than, null) != null ? 1 : 0) +
            (length(try(rule.value.filter.tags, {})) > 0 ? 1 : 0)
          ) == 1 &&
          length(try(rule.value.filter.tags, {})) <= 1
        ) ? [rule.value.filter] : []

        content {
          prefix                   = try(filter.value.prefix, null)
          object_size_greater_than = try(filter.value.object_size_greater_than, null)
          object_size_less_than    = try(filter.value.object_size_less_than, null)

          dynamic "tag" {
            for_each = length(try(filter.value.tags, {})) == 1 ? filter.value.tags : {}

            content {
              key   = tag.key
              value = tag.value
            }
          }
        }
      }

      dynamic "filter" {
        for_each = (
          try(rule.value.filter, null) != null &&
          !(
            (
              (try(rule.value.filter.prefix, null) != null ? 1 : 0) +
              (try(rule.value.filter.object_size_greater_than, null) != null ? 1 : 0) +
              (try(rule.value.filter.object_size_less_than, null) != null ? 1 : 0) +
              (length(try(rule.value.filter.tags, {})) > 0 ? 1 : 0)
            ) == 1 &&
            length(try(rule.value.filter.tags, {})) <= 1
          )
        ) ? [rule.value.filter] : []

        content {
          and {
            prefix                   = try(filter.value.prefix, null)
            object_size_greater_than = try(filter.value.object_size_greater_than, null)
            object_size_less_than    = try(filter.value.object_size_less_than, null)
            tags                     = try(filter.value.tags, null)
          }
        }
      }
    }
  }

  depends_on = [
    aws_s3_bucket_versioning.this,
  ]
}

resource "aws_s3_bucket_intelligent_tiering_configuration" "this" {
  for_each = var.intelligent_tiering_configurations

  bucket = aws_s3_bucket.this.id
  name   = each.key
  status = try(each.value.status, "Enabled")

  dynamic "filter" {
    for_each = try(each.value.filter, null) != null ? [each.value.filter] : []

    content {
      prefix = try(filter.value.prefix, null)
      tags   = try(filter.value.tags, null)
    }
  }

  dynamic "tiering" {
    for_each = each.value.tierings

    content {
      access_tier = tiering.key
      days        = tiering.value.days
    }
  }
}

resource "aws_lambda_permission" "allow" {
  for_each = local.lambda_notifications_with_permission

  statement_id  = try(each.value.statement_id, "AllowExecutionFromS3-${regexreplace(each.key, "[^A-Za-z0-9_-]", "-")}")
  action        = "lambda:InvokeFunction"
  function_name = try(each.value.function_name, each.value.function_arn)
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.this.arn
  source_account = try(each.value.source_account, null)
}

resource "aws_sqs_queue_policy" "allow_s3" {
  for_each = local.sqs_notifications_with_policy

  queue_url = each.value.queue_url
  policy    = data.aws_iam_policy_document.sqs_notification[each.key].json
}

resource "aws_sns_topic_policy" "allow_s3" {
  for_each = local.sns_notifications_with_policy

  arn    = each.value.topic_arn
  policy = data.aws_iam_policy_document.sns_notification[each.key].json
}

resource "aws_s3_bucket_notification" "this" {
  count = var.eventbridge || length(var.lambda_notifications) > 0 || length(var.sqs_notifications) > 0 || length(var.sns_notifications) > 0 ? 1 : 0

  bucket      = aws_s3_bucket.this.id
  eventbridge = var.eventbridge

  dynamic "lambda_function" {
    for_each = var.lambda_notifications

    content {
      id                  = lambda_function.key
      lambda_function_arn = lambda_function.value.function_arn
      events              = lambda_function.value.events
      filter_prefix       = try(lambda_function.value.filter_prefix, null)
      filter_suffix       = try(lambda_function.value.filter_suffix, null)
    }
  }

  dynamic "queue" {
    for_each = var.sqs_notifications

    content {
      id            = queue.key
      queue_arn     = queue.value.queue_arn
      events        = queue.value.events
      filter_prefix = try(queue.value.filter_prefix, null)
      filter_suffix = try(queue.value.filter_suffix, null)
    }
  }

  dynamic "topic" {
    for_each = var.sns_notifications

    content {
      id            = topic.key
      topic_arn     = topic.value.topic_arn
      events        = topic.value.events
      filter_prefix = try(topic.value.filter_prefix, null)
      filter_suffix = try(topic.value.filter_suffix, null)
    }
  }

  depends_on = [
    aws_lambda_permission.allow,
    aws_sqs_queue_policy.allow_s3,
    aws_sns_topic_policy.allow_s3,
  ]
}

resource "aws_s3_bucket_policy" "this" {
  count = local.create_bucket_policy ? 1 : 0

  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.bucket_policy[0].json

  depends_on = [
    aws_s3_bucket_public_access_block.this,
  ]
}

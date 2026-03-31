data "aws_iam_policy_document" "ssl_only" {
  count = var.enable_ssl_only_policy ? 1 : 0

  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

data "aws_iam_policy_document" "bucket_policy" {
  count = local.create_bucket_policy ? 1 : 0

  source_policy_documents = compact([
    var.additional_bucket_policy_json,
    var.enable_ssl_only_policy ? data.aws_iam_policy_document.ssl_only[0].json : null,
  ])
}

data "aws_iam_policy_document" "sqs_notification" {
  for_each = local.sqs_notifications_with_policy

  statement {
    sid    = "AllowS3SendMessage"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions   = ["sqs:SendMessage"]
    resources = [each.value.queue_arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.this.arn]
    }
  }
}

data "aws_iam_policy_document" "sns_notification" {
  for_each = local.sns_notifications_with_policy

  statement {
    sid    = "AllowS3Publish"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions   = ["SNS:Publish"]
    resources = [each.value.topic_arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.this.arn]
    }
  }
}

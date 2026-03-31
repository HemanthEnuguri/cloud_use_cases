variable "bucket_name" {
  description = "Name of the S3 bucket to create."
  type        = string
}

variable "force_destroy" {
  description = "Whether to delete all objects from the bucket so that the bucket can be destroyed without error."
  type        = bool
  default     = false
}

variable "object_lock_enabled" {
  description = "Whether object lock should be enabled for the bucket."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to the bucket and supporting resources."
  type        = map(string)
  default     = {}
}

variable "enable_public_access_block" {
  description = "Whether to create bucket-level public access block configuration."
  type        = bool
  default     = true
}

variable "block_public_acls" {
  description = "Whether Amazon S3 should block public ACLs for this bucket."
  type        = bool
  default     = true
}

variable "block_public_policy" {
  description = "Whether Amazon S3 should block public bucket policies for this bucket."
  type        = bool
  default     = true
}

variable "ignore_public_acls" {
  description = "Whether Amazon S3 should ignore public ACLs for this bucket."
  type        = bool
  default     = true
}

variable "restrict_public_buckets" {
  description = "Whether Amazon S3 should restrict public bucket policies for this bucket."
  type        = bool
  default     = true
}

variable "control_object_ownership" {
  description = "Whether to manage S3 bucket ownership controls."
  type        = bool
  default     = true
}

variable "object_ownership" {
  description = "Object ownership setting for the bucket."
  type        = string
  default     = "BucketOwnerEnforced"

  validation {
    condition     = contains(["BucketOwnerEnforced", "BucketOwnerPreferred", "ObjectWriter"], var.object_ownership)
    error_message = "object_ownership must be one of BucketOwnerEnforced, BucketOwnerPreferred, or ObjectWriter."
  }
}

variable "sse_algorithm" {
  description = "Default server-side encryption algorithm. Valid values commonly used are AES256 or aws:kms."
  type        = string
  default     = "AES256"
}

variable "kms_key_id" {
  description = "KMS key ARN or ID to use when sse_algorithm is aws:kms."
  type        = string
  default     = null
}

variable "bucket_key_enabled" {
  description = "Whether to enable S3 bucket keys for SSE-KMS."
  type        = bool
  default     = true
}

variable "enable_versioning" {
  description = "Whether to enable versioning for the bucket."
  type        = bool
  default     = true
}

variable "enable_mfa_delete" {
  description = "Whether MFA delete should be enabled. This generally requires mfa to be supplied."
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_mfa_delete || var.mfa != null
    error_message = "mfa must be provided when enable_mfa_delete is true."
  }
}

variable "mfa" {
  description = "MFA device and token value in the format SERIAL TOKENCODE, used only when MFA delete is enabled."
  type        = string
  default     = null
}

variable "enable_server_access_logging" {
  description = "Whether to enable server access logging."
  type        = bool
  default     = false
}

variable "logging_target_bucket" {
  description = "Target bucket for server access logs."
  type        = string
  default     = null

  validation {
    condition     = !var.enable_server_access_logging || var.logging_target_bucket != null
    error_message = "logging_target_bucket must be set when enable_server_access_logging is true."
  }
}

variable "logging_target_prefix" {
  description = "Target prefix for server access logs."
  type        = string
  default     = "access-logs/"
}

variable "logging_partition_date_source" {
  description = "Optional partitioned prefix date source for target_object_key_format. Example: EventTime or DeliveryTime."
  type        = string
  default     = null
}

variable "logging_use_simple_prefix" {
  description = "Whether to use the simple_prefix target_object_key_format when logging_partition_date_source is not set."
  type        = bool
  default     = true
}

variable "enable_ssl_only_policy" {
  description = "Whether to attach a policy that denies non-SSL requests."
  type        = bool
  default     = true
}

variable "additional_bucket_policy_json" {
  description = "Additional bucket policy JSON to merge with the module-generated SSL-only policy."
  type        = string
  default     = null
}

variable "lifecycle_rules" {
  description = "Lifecycle rules for the bucket."
  type = list(object({
    id                                    = optional(string)
    status                                = optional(string, "Enabled")
    abort_incomplete_multipart_upload_days = optional(number)

    expiration = optional(object({
      date                         = optional(string)
      days                         = optional(number)
      expired_object_delete_marker = optional(bool)
    }))

    transitions = optional(list(object({
      date          = optional(string)
      days          = optional(number)
      storage_class = string
    })), [])

    noncurrent_version_expiration = optional(object({
      noncurrent_days           = number
      newer_noncurrent_versions = optional(number)
    }))

    noncurrent_version_transitions = optional(list(object({
      noncurrent_days           = number
      newer_noncurrent_versions = optional(number)
      storage_class             = string
    })), [])

    filter = optional(object({
      prefix                   = optional(string)
      tags                     = optional(map(string))
      object_size_greater_than = optional(number)
      object_size_less_than    = optional(number)
    }))
  }))
  default = []
}

variable "intelligent_tiering_configurations" {
  description = "Map of intelligent tiering configurations keyed by configuration name."
  type = map(object({
    status = optional(string, "Enabled")
    filter = optional(object({
      prefix = optional(string)
      tags   = optional(map(string))
    }))
    tierings = map(object({
      days = number
    }))
  }))
  default = {}
}

variable "eventbridge" {
  description = "Whether to enable EventBridge notifications for the bucket."
  type        = bool
  default     = false
}

variable "lambda_notifications" {
  description = "Lambda notifications keyed by logical name."
  type = map(object({
    function_arn      = string
    function_name     = optional(string)
    events            = list(string)
    filter_prefix     = optional(string)
    filter_suffix     = optional(string)
    create_permission = optional(bool, false)
    statement_id      = optional(string)
    source_account    = optional(string)
  }))
  default = {}
}

variable "sqs_notifications" {
  description = "SQS notifications keyed by logical name."
  type = map(object({
    queue_arn     = string
    queue_url     = optional(string)
    events        = list(string)
    filter_prefix = optional(string)
    filter_suffix = optional(string)
    create_policy = optional(bool, false)
  }))
  default = {}

  validation {
    condition = alltrue([
      for _, cfg in var.sqs_notifications :
      !try(cfg.create_policy, false) || try(cfg.queue_url, null) != null
    ])
    error_message = "Each SQS notification with create_policy = true must also provide queue_url."
  }
}

variable "sns_notifications" {
  description = "SNS notifications keyed by logical name."
  type = map(object({
    topic_arn      = string
    events         = list(string)
    filter_prefix  = optional(string)
    filter_suffix  = optional(string)
    create_policy  = optional(bool, false)
  }))
  default = {}
}

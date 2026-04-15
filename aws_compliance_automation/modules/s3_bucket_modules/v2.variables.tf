variable "name_prefix" {
  description = "Name prefix for S3 buckets (will be suffixed with 01-99)"
  type        = string
}

variable "bucket_count" {
  description = "Number of S3 buckets to create (1-99)"
  type        = number
  default     = 1

  validation {
    condition     = var.bucket_count >= 1 && var.bucket_count <= 99
    error_message = "Bucket count must be between 1 and 99."
  }
}

variable "bucket_name" {
  description = "DEPRECATED: Use name_prefix and bucket_count instead. Single bucket name (for backward compatibility)"
  type        = string
  default     = null
}

variable "tags" {
  description = "A map of tags to assign to the S3 bucket"
  type        = map(string)
  default     = {}
}

variable "kms_key_id" {
  description = "KMS key ID/ARN for S3 bucket encryption"
  type        = string
}

variable "enable_public_access_block" {
  description = "Enable S3 bucket public access block (CID59, CID60, CID61, CID63, CID64, CID65)"
  type        = bool
  default     = true
}

variable "enable_versioning" {
  description = "Enable S3 bucket versioning (CID-48)"
  type        = bool
  default     = true
}

variable "enable_mfa_delete" {
  description = "Enable MFA delete on S3 bucket versioning (CID-255) - requires root user provisioning"
  type        = bool
  default     = false
}

variable "enable_server_access_logging" {
  description = "Enable S3 server access logging (CID47)"
  type        = bool
  default     = false
}

variable "logging_target_bucket" {
  description = "Target bucket for server access logs (required if enable_server_access_logging is true)"
  type        = string
  default     = null
}

variable "logging_target_prefix" {
  description = "Target prefix for server access logs"
  type        = string
  default     = "access-logs/"
}

variable "enable_ssl_only_policy" {
  description = "Enable SSL-only bucket policy (CID-57)"
  type        = bool
  default     = true
}

variable "sse_algorithm" {
  description = "Server-side encryption algorithm"
  type        = string
  default     = "aws:kms"
}

variable "bucket_key_enabled" {
  description = "Whether to use S3 Bucket Key for SSE-KMS"
  type        = bool
  default     = true
}

variable "enable_drift_detection" {
  description = "Enable drift detection data sources for monitoring configuration changes"
  type        = bool
  default     = true
}

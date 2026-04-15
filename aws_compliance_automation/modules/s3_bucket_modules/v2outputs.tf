output "bucket_ids" {
  description = "List of S3 bucket IDs"
  value       = aws_s3_bucket.this[*].id
}

output "bucket_arns" {
  description = "List of S3 bucket ARNs"
  value       = aws_s3_bucket.this[*].arn
}

output "bucket_domain_names" {
  description = "List of bucket domain names"
  value       = aws_s3_bucket.this[*].bucket_domain_name
}

output "bucket_regional_domain_names" {
  description = "List of bucket regional domain names"
  value       = aws_s3_bucket.this[*].bucket_regional_domain_name
}

output "bucket_hosted_zone_ids" {
  description = "List of Route 53 Hosted Zone IDs for these buckets' regions"
  value       = aws_s3_bucket.this[*].hosted_zone_id
}

output "bucket_regions" {
  description = "List of AWS regions these buckets reside in"
  value       = aws_s3_bucket.this[*].region
}

output "computed_bucket_names" {
  description = "List of computed bucket names (name_prefix + zero-padded numbers or single bucket_name)"
  value       = local.bucket_names
}

# Legacy outputs (backward compatibility)
output "bucket_id" {
  description = "DEPRECATED: Use bucket_ids instead. The ID of the first S3 bucket"
  value       = length(aws_s3_bucket.this) > 0 ? aws_s3_bucket.this[0].id : null
}

output "bucket_arn" {
  description = "DEPRECATED: Use bucket_arns instead. The ARN of the first S3 bucket"
  value       = length(aws_s3_bucket.this) > 0 ? aws_s3_bucket.this[0].arn : null
}

output "bucket_domain_name" {
  description = "DEPRECATED: Use bucket_domain_names instead. The domain name of the first bucket"
  value       = length(aws_s3_bucket.this) > 0 ? aws_s3_bucket.this[0].bucket_domain_name : null
}

output "bucket_regional_domain_name" {
  description = "DEPRECATED: Use bucket_regional_domain_names instead. The regional domain name of the first bucket"
  value       = length(aws_s3_bucket.this) > 0 ? aws_s3_bucket.this[0].bucket_regional_domain_name : null
}

output "bucket_hosted_zone_id" {
  description = "DEPRECATED: Use bucket_hosted_zone_ids instead. The Route 53 Hosted Zone ID for the first bucket's region"
  value       = length(aws_s3_bucket.this) > 0 ? aws_s3_bucket.this[0].hosted_zone_id : null
}

output "bucket_region" {
  description = "DEPRECATED: Use bucket_regions instead. The AWS region the first bucket resides in"
  value       = length(aws_s3_bucket.this) > 0 ? aws_s3_bucket.this[0].region : null
}

output "public_access_block_ids" {
  description = "List of S3 bucket public access block configuration IDs"
  value       = var.enable_public_access_block ? aws_s3_bucket_public_access_block.this[*].id : []
}

output "versioning_configurations" {
  description = "List of versioning configurations for S3 buckets"
  value = var.enable_versioning ? [
    for idx in range(length(aws_s3_bucket_versioning.this)) : {
      bucket_id  = aws_s3_bucket.this[idx].id
      status     = aws_s3_bucket_versioning.this[idx].versioning_configuration[0].status
      mfa_delete = aws_s3_bucket_versioning.this[idx].versioning_configuration[0].mfa_delete
    }
  ] : []
}

# Legacy outputs (backward compatibility)
output "public_access_block_id" {
  description = "DEPRECATED: Use public_access_block_ids instead. The ID of the first S3 bucket public access block configuration"
  value       = var.enable_public_access_block && length(aws_s3_bucket_public_access_block.this) > 0 ? aws_s3_bucket_public_access_block.this[0].id : null
}

output "versioning_configuration" {
  description = "DEPRECATED: Use versioning_configurations instead. The versioning configuration of the first S3 bucket"
  value = var.enable_versioning && length(aws_s3_bucket_versioning.this) > 0 ? {
    status     = aws_s3_bucket_versioning.this[0].versioning_configuration[0].status
    mfa_delete = aws_s3_bucket_versioning.this[0].versioning_configuration[0].mfa_delete
  } : null
}

# Drift detection outputs
output "drift_detection_data" {
  description = "Drift detection data for monitoring (only available when enable_drift_detection = true)"
  value = var.enable_drift_detection ? {
    current_bucket_policies    = var.enable_ssl_only_policy ? [for idx in range(length(data.aws_s3_bucket_policy.drift_check)) : data.aws_s3_bucket_policy.drift_check[idx].policy] : []
    current_encryptions       = [for idx in range(length(data.aws_s3_bucket_encryption.drift_check)) : data.aws_s3_bucket_encryption.drift_check[idx].rules]
    current_versioning        = var.enable_versioning ? [for idx in range(length(data.aws_s3_bucket_versioning.drift_check)) : data.aws_s3_bucket_versioning.drift_check[idx].versioning_configuration] : []
    bucket_domain_names       = [for idx in range(length(data.aws_s3_bucket.drift_check)) : data.aws_s3_bucket.drift_check[idx].bucket_domain_name]
    bucket_regions           = [for idx in range(length(data.aws_s3_bucket.drift_check)) : data.aws_s3_bucket.drift_check[idx].region]
  } : null
  sensitive = false
}

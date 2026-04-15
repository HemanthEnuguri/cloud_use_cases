# S3 Module (modules-v2/s3)

## Overview

Enhanced S3 module with enterprise-grade compliance, security, and multi-bucket support. Provides CID-compliant S3 buckets with built-in security controls and drift detection.

---

## Features

### ✅ **Security & Compliance (Built-in)**
- **Public Access Block** (CID59, CID60, CID61, CID63, CID64, CID65) - Enabled by default
- **SSL-Only Policy** (CID-57) - Denies non-HTTPS requests
- **Server-Side Encryption** - KMS encryption enforced
- **Versioning** (CID-48) - Enabled by default
- **Server Access Logging** (CID-47) - Optional with configurable target

### ✅ **Multi-Bucket Support** 
- **Scalable Deployment** - Create 1-99 buckets with validation
- **Smart Naming** - `name_prefix + 01-99` format (e.g., `prodapp01`, `prodapp02`)
- **Backward Compatible** - Legacy single `bucket_name` still works

### ✅ **Drift Detection**
- **Configuration Monitoring** - Tracks bucket policy, encryption, versioning changes
- **Compliance Validation** - Ensures configurations remain compliant
- **Automated Alerts** - Integration ready for monitoring systems

---

## Quick Start

### **Multiple Buckets (Recommended)**
```hcl
module "application_buckets" {
  source = "git::https://github.com/your-org/fhs-aws-iac.git//modules-v2/s3?ref=v2.1.0"
  
  name_prefix  = "prodapp"
  bucket_count = 3
  kms_key_id   = "arn:aws:kms:us-east-2:123456789012:key/12345678-1234-1234-1234-123456789012"
  
  # Optional configurations
  enable_server_access_logging = true
  logging_target_bucket       = "central-access-logs"
  logging_target_prefix       = "application-buckets/"
  
  tags = {
    Environment = "production"
    Team        = "platform"
    DataClass   = "sensitive"
  }
}
```

**Creates**: `prodapp01`, `prodapp02`, `prodapp03`

### **Single Bucket (Legacy Compatible)**
```hcl
module "single_bucket" {
  source = "git::https://github.com/your-org/fhs-aws-iac.git//modules-v2/s3?ref=v2.1.0"
  
  bucket_name = "my-specific-bucket-name"
  kms_key_id  = "arn:aws:kms:us-east-2:123456789012:key/12345678-1234-1234-1234-123456789012"
  
  tags = {
    Environment = "production"
    Application = "legacy-app"
  }
}
```

---

## Input Variables

### **Required Variables**
| Variable | Type | Description |
|----------|------|-------------|
| `kms_key_id` | `string` | KMS key ID/ARN for bucket encryption |

### **Multi-Bucket Variables**
| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `name_prefix` | `string` | - | Name prefix for buckets (suffixed with 01-99) |
| `bucket_count` | `number` | `1` | Number of buckets to create (1-99) |

### **Legacy Variable**
| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `bucket_name` | `string` | `null` | Single bucket name (for backward compatibility) |

### **Security & Compliance**
| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_public_access_block` | `bool` | `true` | Enable public access block (CID compliance) |
| `enable_ssl_only_policy` | `bool` | `true` | Enable SSL-only bucket policy (CID-57) |
| `enable_versioning` | `bool` | `true` | Enable bucket versioning (CID-48) |
| `enable_mfa_delete` | `bool` | `false` | Enable MFA delete (requires root user) |

### **Logging & Monitoring**
| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_server_access_logging` | `bool` | `false` | Enable S3 server access logging (CID-47) |
| `logging_target_bucket` | `string` | `null` | Target bucket for access logs |
| `logging_target_prefix` | `string` | `"access-logs/"` | Prefix for log objects |
| `enable_drift_detection` | `bool` | `true` | Enable drift detection monitoring |

### **Encryption**
| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `sse_algorithm` | `string` | `"aws:kms"` | Server-side encryption algorithm |
| `bucket_key_enabled` | `bool` | `true` | Use S3 Bucket Key for cost optimization |

---

## Outputs

### **Multi-Bucket Outputs (Recommended)**
```hcl
# Lists of all bucket information
output "bucket_ids" { value = module.buckets.bucket_ids }
output "bucket_arns" { value = module.buckets.bucket_arns }
output "computed_bucket_names" { value = module.buckets.computed_bucket_names }
output "drift_detection_data" { value = module.buckets.drift_detection_data }
```

### **Legacy Outputs (Backward Compatible)**
```hcl
# First bucket only (for existing code compatibility)  
output "bucket_id" { value = module.buckets.bucket_id }
output "bucket_arn" { value = module.buckets.bucket_arn }
```

---

## Security Policies Applied

### **SSL-Only Policy (CID-57)**
Automatically applied to all buckets:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowSSLRequestOnly",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::bucketname",
        "arn:aws:s3:::bucketname/*"
      ],
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    }
  ]
}
```

### **Public Access Block (CID Compliance)**
Applied to all buckets by default:
- `block_public_acls = true` (CID61, CID65)
- `block_public_policy = true` (CID60, CID64)  
- `ignore_public_acls = true` (CID65)
- `restrict_public_buckets = true` (CID59, CID63)

---

## Current Limitations

### ❌ **Not Currently Supported**

#### **Lifecycle Policies**
The module does **NOT** currently include lifecycle configuration for:
- Transition rules (Standard → IA → Glacier → Deep Archive)
- Object expiration policies  
- Non-current version expiration
- Incomplete multipart upload cleanup

#### **Workaround for Lifecycle Policies**
If you need lifecycle policies on existing buckets created by this module, add them separately:

```hcl
# Create buckets with the module
module "buckets" {
  source = "modules-v2/s3"
  
  name_prefix  = "prodapp"
  bucket_count = 2
  kms_key_id   = "arn:aws:kms:..."
}

# Add lifecycle policies separately  
resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  count = length(module.buckets.bucket_ids)
  
  bucket = module.buckets.bucket_ids[count.index]
  
  rule {
    id     = "transition_rule"
    status = "Enabled"
    
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    
    transition {
      days          = 90  
      storage_class = "GLACIER"
    }
    
    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }
    
    expiration {
      days = 2555  # 7 years retention
    }
    
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
    
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
```

#### **Future Enhancements**
Planned for future module versions:
- Native lifecycle configuration support
- Cross-region replication configuration
- Event notification setup
- Inventory configuration
- Analytics configuration

---

## Advanced Usage

### **Environment-Specific Configuration**
```hcl
# Production - Maximum security
module "prod_buckets" {
  source = "modules-v2/s3"
  
  name_prefix  = "prod-data"
  bucket_count = 5
  kms_key_id   = var.prod_kms_key
  
  enable_versioning            = true
  enable_mfa_delete           = true  # Requires root user
  enable_server_access_logging = true
  logging_target_bucket       = "prod-audit-logs"
  
  tags = {
    Environment     = "production"
    DataClass      = "highly-sensitive"
    Compliance     = "sox-pci"
  }
}

# Development - Flexible configuration  
module "dev_buckets" {
  source = "modules-v2/s3"
  
  name_prefix  = "dev-sandbox"
  bucket_count = 2
  kms_key_id   = var.dev_kms_key
  
  enable_versioning            = false  # Save costs in dev
  enable_server_access_logging = false
  
  tags = {
    Environment = "development"
    DataClass  = "non-sensitive"
  }
}
```

### **Cross-Account Logging**
```hcl
module "application_buckets" {
  source = "modules-v2/s3"
  
  name_prefix  = "crossacct"
  bucket_count = 3
  kms_key_id   = "arn:aws:kms:us-east-2:123456789012:key/..."
  
  # Log to central logging account
  enable_server_access_logging = true
  logging_target_bucket       = "central-s3-logs"  # In logging account
  logging_target_prefix       = "application-logs/"
  
  # Each bucket gets unique log prefix:
  # crossacct01 → application-logs/crossacct01/
  # crossacct02 → application-logs/crossacct02/  
  # crossacct03 → application-logs/crossacct03/
}
```

### **Drift Detection Integration**
```hcl
# Monitor configuration changes
module "monitored_buckets" {
  source = "modules-v2/s3"
  
  name_prefix            = "monitored"
  bucket_count          = 2
  kms_key_id            = var.kms_key
  enable_drift_detection = true
}

# Set up alerting on drift detection
resource "aws_cloudwatch_log_group" "s3_drift_monitoring" {
  name = "/aws/lambda/s3-drift-detector"
}

# Lambda function to process drift detection data
resource "aws_lambda_function" "drift_detector" {
  function_name = "s3-drift-detector"
  
  environment {
    variables = {
      DRIFT_DATA = jsonencode(module.monitored_buckets.drift_detection_data)
    }
  }
}
```

---

## Migration from modules/s3

### **If Migrating from Legacy Module**

#### **Step 1: Review Current Configuration**
```bash
# Check existing bucket configuration
terraform state show module.old_s3.aws_s3_bucket.this
```

#### **Step 2: Update Module Source**
```hcl
# Old configuration
module "s3" {
  source = "../../../../modules/s3"  # Legacy module
  
  bucket_name = "existing-bucket"
  # ... other config
}

# New configuration (backward compatible)
module "s3" {
  source = "git::https://github.com/your-org/fhs-aws-iac.git//modules-v2/s3?ref=v2.1.0"
  
  bucket_name = "existing-bucket"  # Same bucket name
  kms_key_id  = "arn:aws:kms:..."  # Now required
  # ... other config (most variables same)
}
```

#### **Step 3: Plan and Validate**
```bash
terraform plan  # Should show minimal changes
terraform apply  # Apply new compliance features
```

---

## Troubleshooting

### **Common Issues**

#### **Error: "bucket_name or name_prefix required"**
**Solution**: Provide either `bucket_name` (single bucket) OR `name_prefix` (multiple buckets):
```hcl
# Choose ONE approach:

# Option 1: Single bucket
bucket_name = "my-bucket"

# Option 2: Multiple buckets  
name_prefix  = "myapp"
bucket_count = 3
```

#### **Error: "KMS key access denied"**
**Solution**: Ensure KMS key policy allows S3 service:
```json
{
  "Sid": "Allow S3 Service",
  "Effect": "Allow",
  "Principal": {"Service": "s3.amazonaws.com"},
  "Action": ["kms:Decrypt", "kms:GenerateDataKey"]
}
```

#### **Error: "Cannot enable MFA delete"**
**Solution**: MFA delete can only be enabled by root user account:
```hcl
enable_mfa_delete = false  # Use false unless deploying as root
```

#### **Bucket Names Not Globally Unique**
**Solution**: Use unique prefixes with account/region identifiers:
```hcl
name_prefix = "myorg-prod-us-east-2-app"  # More unique
```

---

## Best Practices

### **✅ Recommended Patterns**

#### **Use Multi-Bucket Approach**
```hcl
# Recommended: Scalable and consistent
name_prefix  = "prodapp"
bucket_count = 3

# Avoid: Hard to scale
bucket_name = "specific-name"
```

#### **Always Enable Key Features**
```hcl
enable_public_access_block = true   # Security
enable_ssl_only_policy    = true   # Compliance  
enable_versioning         = true   # Data protection
enable_drift_detection    = true   # Monitoring
```

#### **Use Descriptive Prefixes**
```hcl
# Good: Clear purpose and environment
name_prefix = "prod-web-logs"
name_prefix = "dev-data-lake"  
name_prefix = "backup-archives"

# Avoid: Unclear purpose
name_prefix = "bucket"
name_prefix = "data"
```

#### **Environment-Specific KMS Keys**
```hcl
# Production
kms_key_id = "arn:aws:kms:us-east-2:123456789012:key/prod-s3-key"

# Development  
kms_key_id = "arn:aws:kms:us-east-2:123456789012:key/dev-s3-key"
```

### **❌ Anti-Patterns**

#### **Don't Mix Single and Multi-Bucket**
```hcl
# Wrong: Confusing configuration
bucket_name  = "single-bucket"  # This takes precedence
name_prefix  = "multi"          # This gets ignored
bucket_count = 3

# Right: Choose one approach consistently
name_prefix  = "multi" 
bucket_count = 3
```

#### **Don't Disable Security Features in Production**
```hcl
# Wrong: Reduces security posture
enable_public_access_block = false  # Never in production
enable_ssl_only_policy    = false  # Violates CID-57

# Right: Keep security enabled
enable_public_access_block = true
enable_ssl_only_policy    = true
```

---

## Version Compatibility

### **Current Version: v2.1.0**
- ✅ Multi-bucket support
- ✅ Enhanced drift detection  
- ✅ Backward compatibility
- ✅ Comprehensive CID compliance

### **Upgrade Path**
```hcl
# From v2.0.0 to v2.1.0 - Non-breaking
source = "git::https://github.com/your-org/fhs-aws-iac.git//modules-v2/s3?ref=v2.1.0"

# New features available:
bucket_count = 5  # Multi-bucket support
```

### **Planned Features (Future Versions)**
- **v2.2.0**: Native lifecycle configuration support
- **v2.3.0**: Cross-region replication configuration
- **v2.4.0**: Event notification integration
- **v3.0.0**: Multi-cloud support (AWS + Azure)

---

**📋 Note**: This module focuses on security, compliance, and operational excellence. For advanced features like lifecycle policies, use separate resources alongside the module until native support is added.

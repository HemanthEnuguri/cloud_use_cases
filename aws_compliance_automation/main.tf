# S3 bucket
resource "aws_s3_bucket" "compliance_reports" {
  bucket = "org-tagcompliance-reports-${var.audit_account_id}"
}
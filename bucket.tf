resource "aws_s3_bucket" "phi" {
  bucket = "phi-redaction ${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "phi" {
  bucket = aws_s3_bucket.phi.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_logging" "phi" {
  bucket        = aws_s3_bucket.phi.id
  target_bucket = aws_s3_bucket.audit_logs.id
  target_prefix = "s3-access-logs/phi/"
}

resource "aws_s3_bucket_public_access_block" "phi" {
  bucket                  = aws_s3_bucket.phi.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "phi" {
  bucket = aws_s3_bucket.phi.id
  rule {
    bucket_key_enabled = true
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.phi_key.arn
    }
  }
}





resource "aws_s3_bucket" "audit_logs" {
  bucket = "gauze-audit-logs ${data.aws_caller_identity.current.account_id}"
}


resource "aws_kms_key" "phi_key" {
  description = "Key for encrypting phi bucket"
  deletion_window_in_days = 30
  enable_key_rotation = true
}
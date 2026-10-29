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

resource "aws_s3_bucket_policy" "phi" {
  bucket = aws_s3_bucket.phi.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DelegateAccessControlToAccessPoints"
        Effect    = "Allow"
        Principal = { AWS = "*" }
        Action    = "*"
        Resource = [
          aws_s3_bucket.phi.arn,
          "${aws_s3_bucket.phi.arn}/*",
        ]
        Condition = {
          StringEquals = {
            "s3:DataAccessPointAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid       = "DenyIncorrectKMSHeader"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.phi.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption-aws-kms-key-id" = aws_kms_key.phi_key.arn
          }
          Null = {
            "s3:x-amz-server-side-encryption-aws-kms-key-id" = "false"
          }
        }
      },
      {
        Sid       = "ForceReadsThroughAccessPoints"
        Effect    = "Deny"
        Principal = "*"
        Action    = ["s3:GetObjects", "s3:GetObjectVersion"]
        Resource  = "${aws_s3_bucket.phi.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:DataAccessPointAccount" = data.aws_caller_identity.current.account_id
          }
          ArnNotLike = {
            "aws:PrincipalArn" = var.break_glass_principal_arn
          }
        }
      },
      {
        Sid      = "DenyNonKMSHeader"
        Effect   = "Deny"
        Principal = "*"
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.phi.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
          Null = {
            "s3:x-amz-server-side-encryption" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket" "audit_logs" {
  bucket = "gauze-audit-logs ${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "audit-logs" {
    bucket = aws_s3_bucket.audit_logs.id
    versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_public_access_block" "audit-logs" {
  bucket = aws_s3_bucket.audit_logs.id
  block_public_acls       = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "audit-logs" {
  bucket = aws_s3_bucket.audit_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "EnforceTLSRequestsOnly"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.audit_logs.arn,
          "${aws_s3_bucket.audit_logs.arn}/*"
        ],
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.audit_logs.arn
        Condition = {
          StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
          ArnLike = { "aws:SourceArn" = "arn:aws:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/*" }
        }
      },
      {
        Sid = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.audit_logs.arn}/cloudtrail/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/*"
          }
        }
      },
      {
        Sid = "S3ServerAccessLogsPolicy"
        Effect = "Allow"
        Principal = {Service = "logging.s3.amazonaws.com" }
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.audit_logs.arn}/s3-access-logs/*"
        Condition = {
          StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
          ArnLike = { "aws:SourceArn" = aws_s3_bucket.phi.arn }
        }
      }
    ]
  })
}

resource "aws_kms_key" "phi_key" {
  description             = "Key for encrypting phi bucket"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}
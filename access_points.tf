resource "aws_s3_access_point" "phi-origin" {
  bucket = aws_s3_bucket.phi.id
  name   = "phi-origin-access"

  public_access_block_configuration {
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
  }
}



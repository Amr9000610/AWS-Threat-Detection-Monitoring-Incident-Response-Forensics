resource "aws_s3_bucket" "s3_access_logs" {
  force_destroy = true
  bucket        = local.s3_access_bucket_name

}

resource "aws_s3_bucket_public_access_block" "s3_access_logs" {
  bucket = aws_s3_bucket.s3_access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 server access log delivery requires ACLs on the destination bucket.
resource "aws_s3_bucket_ownership_controls" "s3_access_logs" {
  bucket = aws_s3_bucket.s3_access_logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "s3_access_logs" {
  bucket = aws_s3_bucket.s3_access_logs.id
  acl    = "log-delivery-write"

  depends_on = [
    aws_s3_bucket_ownership_controls.s3_access_logs,
    aws_s3_bucket_public_access_block.s3_access_logs
  ]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_access_logs" {
  bucket = aws_s3_bucket.s3_access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket" "application_data" {
  bucket        = local.application_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "application_data" {
  bucket = aws_s3_bucket.application_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "application_data" {
  count         = var.enable_s3_server_access_logging ? 1 : 0
  bucket        = aws_s3_bucket.application_data.id
  target_bucket = aws_s3_bucket.s3_access_logs.id
  target_prefix = "s3-access/"

  depends_on = [
    aws_s3_bucket_acl.s3_access_logs
  ]
}

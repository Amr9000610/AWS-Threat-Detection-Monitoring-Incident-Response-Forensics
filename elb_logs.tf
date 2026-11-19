
resource "aws_s3_bucket" "elb_logs" {
  bucket        = local.elb_logs_bucket_name
  force_destroy = false
}

resource "aws_s3_bucket_public_access_block" "elb_logs" {
  bucket = aws_s3_bucket.elb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "elb_logs" {
  bucket = aws_s3_bucket.elb_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "elb_logs" {
  bucket = aws_s3_bucket.elb_logs.id

  # Apply the policy after the public access block to avoid OperationAborted conflicts.
  depends_on = [aws_s3_bucket_public_access_block.elb_logs]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowELBLogDelivery"
      Effect = "Allow"
      Principal = {
        # Regional ELB service account (required for us-east-1).
        AWS = data.aws_elb_service_account.main.arn
      }
      Action   = "s3:PutObject"
      Resource = "${aws_s3_bucket.elb_logs.arn}/${local.elb_logs_prefix_path}AWSLogs/${local.account_id}/*"
    }]
  })
}

# This bucket is ready for ALB access logs.
# To enable delivery, add this to the aws_lb resource:
#
#   access_logs {
#     bucket  = aws_s3_bucket.elb_logs.id
#     prefix  = var.elb_logs_prefix
#     enabled = true
#   }
#
#   depends_on = [aws_s3_bucket_policy.elb_logs]
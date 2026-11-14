resource "aws_s3_bucket" "elb_logs" {
  bucket        = local.elb_logs_bucket_name
  force_destroy = true
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

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowELBLogDelivery"
      Effect = "Allow"
      Principal = {
        Service = "logdelivery.elasticloadbalancing.amazonaws.com"
      }
      Action   = "s3:PutObject"
      Resource = "${aws_s3_bucket.elb_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    }]
  })
}

# This bucket is ready for ALB/NLB access logs.
# To actually enable delivery, add an access_logs block to your aws_lb resource.

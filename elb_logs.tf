
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

  depends_on = [
    aws_s3_bucket_public_access_block.elb_logs
  ]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowALBLogDelivery"
        Effect = "Allow"

        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
        }

        Action = "s3:PutObject"

        Resource = "${aws_s3_bucket.elb_logs.arn}/${local.elb_logs_prefix_path}AWSLogs/${local.account_id}/*"

        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.account_id
          }

          ArnLike = {
            "aws:SourceArn" = "arn:${local.partition}:elasticloadbalancing:${var.aws_region}:${local.account_id}:loadbalancer/*"
          }
        }
      }
    ]
  })
}

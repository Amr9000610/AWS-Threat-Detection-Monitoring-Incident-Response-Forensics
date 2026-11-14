
# ============================================================
# AWS Threat Detection Project - Data Infrastructure
# Owner: Abdallah Mohamed
# Environment: depi-team-5
# AWS Account ID: 450505040291
# ============================================================

# 1. Main S3 Bucket - Project Logs
resource "aws_s3_bucket" "project_logs_bucket" {
  bucket        = "depi-team5-project-logs-450505040291"
  force_destroy = false

  tags = {
    Name        = "Project Logs Bucket"
    Environment = "depi-team-5"
    Owner       = "Abdallah Mohamed"
  }
}

# 2. Block Public Access - Main Logs Bucket
resource "aws_s3_bucket_public_access_block" "logs_bucket_public_access" {
  bucket = aws_s3_bucket.project_logs_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 3. Enable S3 Server-Side Encryption - Main Bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "logs_encryption" {
  bucket = aws_s3_bucket.project_logs_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 4. S3 Access Logs Destination Bucket
resource "aws_s3_bucket" "access_logs_bucket" {
  bucket        = "depi-team5-s3-access-logs-450505040291"
  force_destroy = false

  tags = {
    Name        = "S3 Server Access Logs"
    Environment = "depi-team-5"
    Owner       = "Abdallah Mohamed"
  }
}

# 5. Block Public Access - Access Logs Bucket
resource "aws_s3_bucket_public_access_block" "access_logs_public_access" {
  bucket = aws_s3_bucket.access_logs_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 6. Enable SSE-S3 Encryption on Access Logs Bucket
# SSE-S3 is required for reliable S3 Server Access Log delivery.
resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs_encryption" {
  bucket = aws_s3_bucket.access_logs_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 7. S3 Server Access Logging Bucket Policy
# Allow only the S3 logging service to write logs
# from the project's main bucket and AWS account.

data "aws_iam_policy_document" "s3_log_delivery" {
  statement {
    sid    = "AllowS3ServerAccessLogDelivery"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.access_logs_bucket.arn}/s3-access-logs/*"
    ]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.project_logs_bucket.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = ["450505040291"]
    }
  }
}

resource "aws_s3_bucket_policy" "access_logs_bucket_policy" {
  bucket = aws_s3_bucket.access_logs_bucket.id
  policy = data.aws_iam_policy_document.s3_log_delivery.json
}

# 8. Enable Server Access Logging on Main Bucket
resource "aws_s3_bucket_logging" "project_logs_logging" {
  bucket        = aws_s3_bucket.project_logs_bucket.id
  target_bucket = aws_s3_bucket.access_logs_bucket.id
  target_prefix = "s3-access-logs/"

  depends_on = [
    aws_s3_bucket_policy.access_logs_bucket_policy
  ]
}

# 9. Main Project Logs Lifecycle Policy
# Move logs to Standard-IA after 30 days.
# Delete logs after 90 days.

resource "aws_s3_bucket_lifecycle_configuration" "logs_retention" {
  bucket = aws_s3_bucket.project_logs_bucket.id

  rule {
    id     = "project-logs-retention-policy"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = 90
    }
  }
}

# 10. Access Logs Lifecycle Policy
# Apply retention to the actual S3 access log objects.

resource "aws_s3_bucket_lifecycle_configuration" "access_logs_retention" {
  bucket = aws_s3_bucket.access_logs_bucket.id

  rule {
    id     = "s3-access-logs-retention-policy"
    status = "Enabled"

    filter {
      prefix = "s3-access-logs/"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = 90
    }
  }
}

# 11. Amazon Athena Security Logs Database
resource "aws_athena_database" "security_logs_db" {
  name   = "depi_team5_security_logs"
  bucket = aws_s3_bucket.project_logs_bucket.id
}

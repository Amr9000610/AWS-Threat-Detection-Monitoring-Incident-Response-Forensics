resource "aws_iam_role" "cloudtrail_to_cloudwatch" {
  name = "${var.project_name}-cloudtrail-cw-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "cloudtrail.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "cloudtrail_to_cloudwatch" {
  name = "${var.project_name}-cloudtrail-cw-policy"
  role = aws_iam_role.cloudtrail_to_cloudwatch.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
    }]
  })
}

resource "aws_cloudtrail" "account_trail" {
  name                          = "${var.project_name}-account-trail"
  s3_bucket_name                = aws_s3_bucket.central_logs.id
  s3_key_prefix                 = "cloudtrail"
  include_global_service_events = true
  is_multi_region_trail         = true

  # This project uses one AWS account with IAM users, not AWS Organizations.
  is_organization_trail      = false
  enable_logging             = true
  enable_log_file_validation = true

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_to_cloudwatch.arn

  depends_on = [
    aws_s3_bucket_policy.central_logs,
    aws_iam_role_policy.cloudtrail_to_cloudwatch
  ]
}

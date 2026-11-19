
# ============================================================
# WEEK 2 - Threat Detection, Monitoring & Security
# Project: DEPI Team 5
# AWS Provider: ~> 6.0
# Region: us-east-1
# ============================================================

data "aws_caller_identity" "week2" {}

data "aws_partition" "week2" {}

data "aws_region" "week2" {}

# ------------------------------------------------------------
# 1. Amazon GuardDuty
# ------------------------------------------------------------

resource "aws_guardduty_detector" "week2" {
  enable = true

  finding_publishing_frequency = "FIFTEEN_MINUTES"
}

# ------------------------------------------------------------
# 2. AWS Security Hub
# ------------------------------------------------------------

resource "aws_securityhub_account" "week2" {}

resource "aws_securityhub_standards_subscription" "foundational" {
  standards_arn = "arn:${data.aws_partition.week2.partition}:securityhub:${data.aws_region.week2.region}::standards/aws-foundational-security-best-practices/v/1.0.0"

  depends_on = [
    aws_securityhub_account.week2
  ]
}

resource "aws_securityhub_standards_subscription" "cis" {
  standards_arn = "arn:${data.aws_partition.week2.partition}:securityhub:${data.aws_region.week2.region}::standards/cis-aws-foundations-benchmark/v/1.4.0"

  depends_on = [
    aws_securityhub_account.week2
  ]
}

# ------------------------------------------------------------
# 3. Amazon Detective
# ------------------------------------------------------------

resource "aws_detective_graph" "week2" {}

# ------------------------------------------------------------
# 4. Amazon Inspector
# ------------------------------------------------------------

resource "aws_inspector2_enabler" "week2" {
  account_ids = [
    data.aws_caller_identity.week2.account_id
  ]

  resource_types = [
    "EC2",
    "ECR",
    "LAMBDA"
  ]
}

# ------------------------------------------------------------
# 5. Amazon Macie
# ------------------------------------------------------------

resource "aws_macie2_account" "week2" {
  finding_publishing_frequency = "FIFTEEN_MINUTES"
}

# ------------------------------------------------------------
# 6. AWS Config IAM Role
# ------------------------------------------------------------

resource "aws_iam_role" "config_role" {
  name = "depi-team5-aws-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "config.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config_policy" {
  role = aws_iam_role.config_role.name

  policy_arn = "arn:${data.aws_partition.week2.partition}:iam::aws:policy/service-role/AWS_ConfigRole"
}

# ------------------------------------------------------------
# 7. AWS Config S3 Bucket Policy
# Uses existing project_logs_bucket from data.tf
# ------------------------------------------------------------

data "aws_iam_policy_document" "config_bucket_policy" {
  statement {
    sid    = "AWSConfigBucketPermissionsCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    actions = [
      "s3:GetBucketAcl"
    ]

    resources = [
      aws_s3_bucket.project_logs_bucket.arn
    ]
  }

  statement {
    sid    = "AWSConfigBucketDelivery"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.project_logs_bucket.arn}/AWSLogs/${data.aws_caller_identity.week2.account_id}/Config/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "config_bucket_policy" {
  bucket = aws_s3_bucket.project_logs_bucket.id
  policy = data.aws_iam_policy_document.config_bucket_policy.json
}

# ------------------------------------------------------------
# 8. AWS Config Recorder
# ------------------------------------------------------------

resource "aws_config_configuration_recorder" "week2" {
  name     = "depi-team5-config-recorder"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.config_policy
  ]
}

resource "aws_config_delivery_channel" "week2" {
  name           = "depi-team5-config-delivery"
  s3_bucket_name = aws_s3_bucket.project_logs_bucket.id
  s3_key_prefix  = "AWSLogs/${data.aws_caller_identity.week2.account_id}/Config"

  depends_on = [
    aws_s3_bucket_policy.config_bucket_policy
  ]
}

resource "aws_config_configuration_recorder_status" "week2" {
  name       = aws_config_configuration_recorder.week2.name
  is_enabled = true

  depends_on = [
    aws_config_delivery_channel.week2
  ]
}

# ------------------------------------------------------------
# 9. AWS Config Managed Security Rules
# ------------------------------------------------------------

locals {
  week2_config_rules = {
    s3_public_read          = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
    s3_public_write         = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
    s3_encryption           = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
    encrypted_volumes       = "ENCRYPTED_VOLUMES"
    root_mfa                = "ROOT_ACCOUNT_MFA_ENABLED"
    iam_user_mfa            = "IAM_USER_MFA_ENABLED"
    cloudtrail_enabled      = "CLOUD_TRAIL_ENABLED"
    multi_region_cloudtrail = "MULTI_REGION_CLOUD_TRAIL_ENABLED"
    guardduty_enabled       = "GUARDDUTY_ENABLED"
    default_sg_closed       = "VPC_DEFAULT_SECURITY_GROUP_CLOSED"
    restricted_ssh          = "INCOMING_SSH_DISABLED"
  }
}

resource "aws_config_config_rule" "week2" {
  for_each = local.week2_config_rules

  name = each.key

  source {
    owner             = "AWS"
    source_identifier = each.value
  }

  depends_on = [
    aws_config_configuration_recorder_status.week2
  ]
}

# ------------------------------------------------------------
# 10. Outputs
# ------------------------------------------------------------

output "week2_guardduty_detector_id" {
  value = aws_guardduty_detector.week2.id
}

output "week2_detective_graph_arn" {
  value = aws_detective_graph.week2.graph_arn
}

output "week2_macie_account_id" {
  value = aws_macie2_account.week2.id
}

output "week2_config_rule_names" {
  value = [
    for rule in aws_config_config_rule.week2 : rule.name
  ]
}

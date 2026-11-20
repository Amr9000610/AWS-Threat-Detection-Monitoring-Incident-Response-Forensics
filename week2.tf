# ============================================================
# WEEK 2 - Threat Detection, Monitoring & Security
# Reuses the shared infrastructure created in Week 1.
# ============================================================

resource "aws_guardduty_detector" "week2" {
  enable                        = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
}

# Declare standards explicitly; disable automatic defaults to avoid duplicates.
resource "aws_securityhub_account" "week2" {
  enable_default_standards = false
}

resource "aws_securityhub_standards_subscription" "foundational" {
  standards_arn = "arn:${local.partition}:securityhub:${var.aws_region}::standards/aws-foundational-security-best-practices/v/1.0.0"
  depends_on    = [aws_securityhub_account.week2]
}

resource "aws_securityhub_standards_subscription" "cis" {
  standards_arn = "arn:${local.partition}:securityhub:${var.aws_region}::standards/cis-aws-foundations-benchmark/v/1.4.0"
  depends_on    = [aws_securityhub_account.week2]
}

resource "aws_detective_graph" "week2" {}

resource "aws_inspector2_enabler" "week2" {
  account_ids    = [local.account_id]
  resource_types = ["EC2", "ECR", "LAMBDA"]
}

resource "aws_macie2_account" "week2" {
  finding_publishing_frequency = "FIFTEEN_MINUTES"
}

# Week 1 owns the Config recorder, delivery channel, IAM role and S3 bucket policy.
# Week 2 only adds managed security rules to the existing recorder.
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
  name     = "${var.project_name}-${each.key}"

  source {
    owner             = "AWS"
    source_identifier = each.value
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}

output "week2_guardduty_detector_id" {
  description = "GuardDuty detector ID for this account and Region."
  value       = aws_guardduty_detector.week2.id
}

output "week2_detective_graph_arn" {
  description = "Amazon Detective behavior graph ARN."
  value       = aws_detective_graph.week2.graph_arn
}

output "week2_macie_account_id" {
  description = "Amazon Macie account ID."
  value       = aws_macie2_account.week2.id
}

output "week2_config_rule_names" {
  description = "Names of the AWS Config managed security rules."
  value       = [for rule in aws_config_config_rule.week2 : rule.name]
}

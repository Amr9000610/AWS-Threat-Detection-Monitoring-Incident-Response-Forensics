
# ============================================================
# WEEK 2 - THREAT DETECTION SERVICES
# Amazon GuardDuty, Security Hub, Detective, Inspector, Macie
# AWS Config managed rules
#
# Reuses Week 1 resources:
# - data.aws_caller_identity.current
# - data.aws_partition.current
# - aws_config_configuration_recorder_status.main
# - aws_s3_bucket.application_data
# ============================================================

# Current AWS region (used in Security Hub standard ARNs).
data "aws_region" "week2" {}

# ------------------------------------------------------------
# 1. AMAZON GUARDDUTY
# ------------------------------------------------------------

resource "aws_guardduty_detector" "week2" {
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"

  tags = {
    Name        = "${var.project_name}-guardduty"
    Environment = var.environment
    Week        = "2"
  }
}

# ------------------------------------------------------------
# 2. AWS SECURITY HUB
# ------------------------------------------------------------

resource "aws_securityhub_account" "week2" {
  enable_default_standards = false
  auto_enable_controls     = true

  control_finding_generator = "SECURITY_CONTROL"
}

# AWS Foundational Security Best Practices.
resource "aws_securityhub_standards_subscription" "aws_foundational" {
  standards_arn = "arn:${data.aws_partition.current.partition}:securityhub:${data.aws_region.week2.region}::standards/aws-foundational-security-best-practices/v/1.0.0"

  depends_on = [
    aws_securityhub_account.week2
  ]
}

# CIS AWS Foundations Benchmark v1.4.0.
resource "aws_securityhub_standards_subscription" "cis_1_4" {
  standards_arn = "arn:${data.aws_partition.current.partition}:securityhub:${data.aws_region.week2.region}::standards/cis-aws-foundations-benchmark/v/1.4.0"

  depends_on = [
    aws_securityhub_account.week2
  ]
}

# ------------------------------------------------------------
# 3. AMAZON DETECTIVE
# ------------------------------------------------------------

resource "aws_detective_graph" "week2" {
  tags = {
    Name        = "${var.project_name}-detective"
    Environment = var.environment
    Week        = "2"
  }
}

# ------------------------------------------------------------
# 4. AMAZON INSPECTOR
# ------------------------------------------------------------

resource "aws_inspector2_enabler" "week2" {
  account_ids = [
    data.aws_caller_identity.current.account_id
  ]

  resource_types = [
    "EC2",
    "ECR",
    "LAMBDA"
  ]
}

# ------------------------------------------------------------
# 5. AMAZON MACIE
# ------------------------------------------------------------

resource "aws_macie2_account" "week2" {
  finding_publishing_frequency = "FIFTEEN_MINUTES"
  status                       = "ENABLED"
}

# One-time sensitive-data discovery job for the application bucket.
# The bucket is created by the Week 1 configuration.
resource "aws_macie2_classification_job" "application_bucket_scan" {
  name     = "${var.project_name}-application-data-scan"
  job_type = "ONE_TIME"

  s3_job_definition {
    bucket_definitions {
      account_id = data.aws_caller_identity.current.account_id
      buckets = [
        aws_s3_bucket.application_data.id
      ]
    }
  }

  depends_on = [
    aws_macie2_account.week2,
    aws_s3_bucket.application_data
  ]
}

# ------------------------------------------------------------
# 6. AWS CONFIG - WEEK 2 SECURITY RULES
# ------------------------------------------------------------

# The Config recorder and delivery channel are already created
# in config.tf (Week 1). These rules depend on the recorder
# being enabled before AWS Config evaluates them.

locals {
  week2_config_rules = {
    root_account_mfa = {
      name              = "root-account-mfa-enabled"
      source_identifier = "ROOT_ACCOUNT_MFA_ENABLED"
      description       = "Checks whether MFA is enabled for the AWS root account."
    }

    iam_user_mfa = {
      name              = "iam-user-mfa-enabled"
      source_identifier = "IAM_USER_MFA_ENABLED"
      description       = "Checks whether IAM users have MFA enabled."
    }

    iam_password_policy = {
      name              = "iam-password-policy"
      source_identifier = "IAM_PASSWORD_POLICY"
      description       = "Checks whether the account password policy follows security requirements."
    }

    encrypted_volumes = {
      name              = "encrypted-volumes"
      source_identifier = "ENCRYPTED_VOLUMES"
      description       = "Checks whether attached EBS volumes are encrypted."
    }

    restricted_ssh = {
      name              = "restricted-ssh"
      source_identifier = "INCOMING_SSH_DISABLED"
      description       = "Checks whether security groups allow unrestricted SSH access."
    }

    cloudtrail_enabled = {
      name              = "cloudtrail-enabled"
      source_identifier = "CLOUD_TRAIL_ENABLED"
      description       = "Checks whether CloudTrail is enabled."
    }

    s3_public_read_prohibited = {
      name              = "s3-public-read-prohibited"
      source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
      description       = "Checks whether S3 buckets allow public read access."
    }

    s3_public_write_prohibited = {
      name              = "s3-public-write-prohibited"
      source_identifier = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
      description       = "Checks whether S3 buckets allow public write access."
    }

    access_keys_rotated = {
      name              = "iam-access-keys-rotated"
      source_identifier = "ACCESS_KEYS_ROTATED"
      description       = "Checks whether IAM access keys are rotated within the required period."
    }

    default_security_group_closed = {
      name              = "vpc-default-security-group-closed"
      source_identifier = "VPC_DEFAULT_SECURITY_GROUP_CLOSED"
      description       = "Checks whether the default VPC security group restricts inbound and outbound traffic."
    }

    rds_storage_encrypted = {
      name              = "rds-storage-encrypted"
      source_identifier = "RDS_STORAGE_ENCRYPTED"
      description       = "Checks whether RDS DB instances have storage encryption enabled."
    }

    cloudtrail_log_validation = {
      name              = "cloudtrail-log-file-validation-enabled"
      source_identifier = "CLOUD_TRAIL_LOG_FILE_VALIDATION_ENABLED"
      description       = "Checks whether CloudTrail log file validation is enabled."
    }
  }
}

resource "aws_config_config_rule" "week2" {
  for_each = local.week2_config_rules

  name        = "${var.project_name}-${each.value.name}"
  description = each.value.description

  source {
    owner             = "AWS"
    source_identifier = each.value.source_identifier
  }

  depends_on = [
    aws_config_configuration_recorder_status.main
  ]
}

# ------------------------------------------------------------
# 7. WEEK 2 OUTPUTS
# ------------------------------------------------------------

output "week2_guardduty_detector_id" {
  description = "GuardDuty detector ID."
  value       = aws_guardduty_detector.week2.id
}

output "week2_security_hub_arn" {
  description = "Security Hub account ARN."
  value       = aws_securityhub_account.week2.arn
}

output "week2_security_hub_standards" {
  description = "Enabled Security Hub standards."
  value = [
    aws_securityhub_standards_subscription.aws_foundational.standards_arn,
    aws_securityhub_standards_subscription.cis_1_4.standards_arn
  ]
}

output "week2_detective_graph_arn" {
  description = "Amazon Detective graph ARN."
  value       = aws_detective_graph.week2.graph_arn
}

output "week2_inspector_account_id" {
  description = "Account ID enabled in Amazon Inspector."
  value       = aws_inspector2_enabler.week2.account_ids
}

output "week2_macie_classification_job_id" {
  description = "Macie one-time classification job ID."
  value       = aws_macie2_classification_job.application_bucket_scan.id
}

output "week2_config_rule_names" {
  description = "AWS Config rules created for Week 2."
  value       = [for rule in aws_config_config_rule.week2 : rule.name]
}

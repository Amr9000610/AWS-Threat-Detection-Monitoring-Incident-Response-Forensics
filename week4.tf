# ============================================================
# WEEK 4 - SOAR AUTOMATION & EXECUTIVE REPORTING
# Security Hub -> EventBridge -> Lambda -> SNS
# SSM Automation Approval Workflow
#
# Reuses existing Week 1, Week 2 and Week 3 resources.
# No automatic destructive containment actions are performed.
# ============================================================

# ------------------------------------------------------------
# 1. Lambda packaging
# ------------------------------------------------------------

data "archive_file" "week4_lambda" {
  type        = "zip"
  output_path = "${path.module}/week4_incident_handler.zip"

  source {
    content  = <<-PYTHON
import json
import os
import boto3
from datetime import datetime, timezone

sns = boto3.client("sns")

TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]
PROJECT = os.environ["PROJECT_NAME"]


def handler(event, context):
    if not isinstance(event, dict):
        event = {}

    detail = event.get("detail", {})
    if not isinstance(detail, dict):
        detail = {}

    findings = detail.get("findings", [])
    if not isinstance(findings, list):
        findings = []

    processed = []
    for finding in findings[:10]:
        if not isinstance(finding, dict):
            continue

        severity = finding.get("Severity")
        if not isinstance(severity, dict):
            severity = {}

        resources = finding.get("Resources")
        if not isinstance(resources, list):
            resources = []

        first_resource = resources[0] if resources and isinstance(resources[0], dict) else {}

        processed.append({
            "title": finding.get("Title") or "Unknown finding",
            "severity": severity.get("Label") or "UNKNOWN",
            "id": finding.get("Id") or "N/A",
            "account": finding.get("AwsAccountId") or "N/A",
            "region": finding.get("Region") or "N/A",
            "resource": first_resource.get("Id") or "N/A"
        })

    message = {
        "project": PROJECT,
        "event_type": event.get("detail-type") or "Unknown Security Event",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "finding_count": len(findings),
        "findings": processed,
        "status": "REQUIRES_SECURITY_TEAM_REVIEW",
        "note": "No automatic containment action was executed."
    }

    sns.publish(
        TopicArn=TOPIC_ARN,
        Subject=("Security Incident Alert - " + PROJECT)[:100],
        Message=json.dumps(message, indent=2, default=str)
    )

    print(json.dumps(message, default=str))
    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Security event processed",
            "findings": len(processed)
        })
    }
PYTHON
    filename = "index.py"
  }
}

# ------------------------------------------------------------
# 2. CloudWatch Log Group
# ------------------------------------------------------------

resource "aws_cloudwatch_log_group" "week4_lambda" {
  name              = "/aws/lambda/${var.project_name}-incident-handler"
  retention_in_days = var.cloudwatch_retention_days
}

# ------------------------------------------------------------
# 3. Lambda IAM Role
# ------------------------------------------------------------

resource "aws_iam_role" "week4_lambda" {
  name = "${var.project_name}-week4-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "week4_lambda" {
  name = "${var.project_name}-week4-lambda-policy"
  role = aws_iam_role.week4_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.week4_lambda.arn}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.security_alerts.arn
      }
    ]
  })
}

# ------------------------------------------------------------
# 4. Lambda Function
# ------------------------------------------------------------

resource "aws_lambda_function" "week4_incident_handler" {
  function_name = "${var.project_name}-incident-handler"
  role          = aws_iam_role.week4_lambda.arn

  filename         = data.archive_file.week4_lambda.output_path
  source_code_hash = data.archive_file.week4_lambda.output_base64sha256

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 30
  memory_size = 128

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.security_alerts.arn
      PROJECT_NAME  = var.project_name
    }
  }

  depends_on = [
    aws_iam_role_policy.week4_lambda,
    aws_cloudwatch_log_group.week4_lambda
  ]
}

# ------------------------------------------------------------
# 5. EventBridge Rule - High/Critical Findings
# ------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "week4_findings" {
  count = var.enable_week2_securityhub ? 1 : 0

  name        = "${var.project_name}-security-findings"
  description = "Detect active High and Critical Security Hub findings"

  event_pattern = jsonencode({
    source        = ["aws.securityhub"]
    "detail-type" = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity = {
          Label = ["HIGH", "CRITICAL"]
        }
        RecordState = ["ACTIVE"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "week4_findings" {
  count = var.enable_week2_securityhub ? 1 : 0

  rule = aws_cloudwatch_event_rule.week4_findings[0].name
  arn  = aws_lambda_function.week4_incident_handler.arn
}

resource "aws_lambda_permission" "week4_findings" {
  count = var.enable_week2_securityhub ? 1 : 0

  statement_id  = "AllowEventBridgeSecurityFindings"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.week4_incident_handler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.week4_findings[0].arn
}

# ------------------------------------------------------------
# 6. Security Hub Custom Action
# ------------------------------------------------------------

resource "aws_securityhub_action_target" "week4_review" {
  count = var.enable_week2_securityhub ? 1 : 0

  name        = "StartIncidentReview"
  description = "Send a finding to the incident review workflow"
  identifier  = "StartIncidentReview"
}

resource "aws_cloudwatch_event_rule" "week4_custom_action" {
  count = var.enable_week2_securityhub ? 1 : 0

  name        = "${var.project_name}-incident-review-action"
  description = "Detect Security Hub custom incident review actions"

  event_pattern = jsonencode({
    source        = ["aws.securityhub"]
    "detail-type" = ["Security Hub Findings - Custom Action"]
    detail = {
      actionName = ["StartIncidentReview"]
    }
  })
}

resource "aws_cloudwatch_event_target" "week4_custom_action" {
  count = var.enable_week2_securityhub ? 1 : 0

  rule = aws_cloudwatch_event_rule.week4_custom_action[0].name
  arn  = aws_lambda_function.week4_incident_handler.arn
}

resource "aws_lambda_permission" "week4_custom_action" {
  count = var.enable_week2_securityhub ? 1 : 0

  statement_id  = "AllowEventBridgeCustomAction"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.week4_incident_handler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.week4_custom_action[0].arn
}

# ------------------------------------------------------------
# 7. SSM Automation - Human Approval Runbook
# The approver ARNs are supplied when the Automation is started.
# ------------------------------------------------------------

resource "aws_sns_topic" "week4_approval" {
  name = "Automation-${var.project_name}-incident-approval"
}

data "aws_iam_policy_document" "week4_approval_sns" {
  statement {
    sid    = "AllowSSMAutomationToPublishApprovalNotifications"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ssm.amazonaws.com"]
    }

    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.week4_approval.arn]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_sns_topic_policy" "week4_approval" {
  arn    = aws_sns_topic.week4_approval.arn
  policy = data.aws_iam_policy_document.week4_approval_sns.json
}

resource "aws_sns_topic_subscription" "week4_approval_email" {
  count     = var.alert_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.week4_approval.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_ssm_document" "week4_approval" {
  name            = "${var.project_name}-incident-approval"
  document_type   = "Automation"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "0.3"
    description   = "Human approval workflow for security incident response"

    parameters = {
      IncidentDescription = {
        type        = "String"
        description = "Description of the incident requiring approval"
      }
      Approvers = {
        type        = "StringList"
        description = "IAM user or role ARNs authorized to approve this incident"
      }
    }

    mainSteps = [
      {
        name   = "RequestHumanApproval"
        action = "aws:approve"
        inputs = {
          Approvers            = "{{ Approvers }}"
          NotificationArn      = aws_sns_topic.week4_approval.arn
          Message              = "Security incident approval required: {{ IncidentDescription }}"
          MinRequiredApprovals = "1"
        }
        isEnd = true
      }
    ]
  })

  depends_on = [aws_sns_topic_policy.week4_approval]
}

# ------------------------------------------------------------
# 8. Outputs
# ------------------------------------------------------------

output "week4_lambda_function_name" {
  description = "Week 4 incident handler Lambda function"
  value       = aws_lambda_function.week4_incident_handler.function_name
}

output "week4_lambda_arn" {
  description = "Week 4 Lambda ARN"
  value       = aws_lambda_function.week4_incident_handler.arn
}

output "week4_eventbridge_findings_rule" {
  description = "Security findings EventBridge rule"
  value       = try(aws_cloudwatch_event_rule.week4_findings[0].name, null)
}

output "week4_custom_action_id" {
  description = "Security Hub custom action identifier"
  value       = try(aws_securityhub_action_target.week4_review[0].id, null)
}

output "week4_ssm_approval_document" {
  description = "SSM incident approval runbook"
  value       = aws_ssm_document.week4_approval.name
}

output "week4_approval_topic_arn" {
  description = "SNS topic used exclusively for SSM approval notifications"
  value       = aws_sns_topic.week4_approval.arn
}

output "week4_lambda_log_group" {
  description = "Lambda CloudWatch log group"
  value       = aws_cloudwatch_log_group.week4_lambda.name
}

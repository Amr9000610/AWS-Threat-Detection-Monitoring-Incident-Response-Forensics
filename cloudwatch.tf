resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${var.project_name}"
  retention_in_days = var.cloudwatch_retention_days
}

resource "aws_cloudwatch_log_group" "vpc_flow" {
  count             = var.enable_vpc_flow_logs ? 1 : 0
  name              = "/aws/vpc/flowlogs/${var.project_name}"
  retention_in_days = var.cloudwatch_retention_days
}


# Detect failed console sign-in attempts recorded by CloudTrail.
resource "aws_cloudwatch_log_metric_filter" "console_login_failures" {
  name           = "${var.project_name}-console-login-failures"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ ($.eventName = ConsoleLogin) && ($.errorMessage = \"Failed authentication\") }"

  metric_transformation {
    name      = "ConsoleLoginFailures"
    namespace = "${var.project_name}/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "console_login_failures" {
  alarm_name          = "${var.project_name}-console-login-failures"
  alarm_description   = "One or more failed AWS Management Console sign-in attempts."
  namespace           = "${var.project_name}/Security"
  metric_name         = "ConsoleLoginFailures"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}

# Detect API calls rejected due to authorization failures.
resource "aws_cloudwatch_log_metric_filter" "unauthorized_api_calls" {
  name           = "${var.project_name}-unauthorized-api-calls"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ ($.errorCode = *UnauthorizedOperation) || ($.errorCode = AccessDenied*) }"

  metric_transformation {
    name      = "UnauthorizedApiCalls"
    namespace = "${var.project_name}/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls" {
  alarm_name          = "${var.project_name}-unauthorized-api-calls"
  alarm_description   = "One or more AWS API calls were denied."
  namespace           = "${var.project_name}/Security"
  metric_name         = "UnauthorizedApiCalls"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}

# Detect changes to IAM users, roles, policies, and credentials.
resource "aws_cloudwatch_log_metric_filter" "iam_changes" {
  name           = "${var.project_name}-iam-changes"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ ($.eventSource = iam.amazonaws.com) && (($.eventName = CreateAccessKey) || ($.eventName = CreateLoginProfile) || ($.eventName = CreatePolicy) || ($.eventName = CreateRole) || ($.eventName = AttachRolePolicy) || ($.eventName = PutRolePolicy) || ($.eventName = AddUserToGroup) || ($.eventName = UpdateAssumeRolePolicy) || ($.eventName = DeleteAccessKey)) }"

  metric_transformation {
    name      = "IamSecurityChanges"
    namespace = "${var.project_name}/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "iam_changes" {
  alarm_name          = "${var.project_name}-iam-security-changes"
  alarm_description   = "A monitored IAM security configuration change occurred."
  namespace           = "${var.project_name}/Security"
  metric_name         = "IamSecurityChanges"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}


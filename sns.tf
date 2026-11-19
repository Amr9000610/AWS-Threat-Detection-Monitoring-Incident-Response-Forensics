resource "aws_sns_topic" "security_alerts" {
  name = "${var.project_name}-security-alerts"
}
data "aws_iam_policy_document" "sns_cloudwatch_publish" {
  statement {
    sid = "AllowCloudWatchAlarmsToPublish"
    effect = "Allow"
    principals { type = "Service" identifiers = ["cloudwatch.amazonaws.com"] }
    actions = ["sns:Publish"]
    resources = [aws_sns_topic.security_alerts.arn]
    condition {
      test = "StringEquals"
      variable = "AWS:SourceAccount"
      values = [data.aws_caller_identity.current.account_id]
    }
  }
}
resource "aws_sns_topic_policy" "security_alerts" {
  arn = aws_sns_topic.security_alerts.arn
  policy = data.aws_iam_policy_document.sns_cloudwatch_publish.json
}
resource "aws_sns_topic_subscription" "security_alerts_email" {
  count = var.alert_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol = "email"
  endpoint = var.alert_email
}

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${var.project_name}"
  retention_in_days = var.cloudwatch_retention_days
}

resource "aws_cloudwatch_log_group" "vpc_flow" {
  count             = var.enable_vpc_flow_logs ? 1 : 0
  name              = "/aws/vpc/flowlogs/${var.project_name}"
  retention_in_days = var.cloudwatch_retention_days
}

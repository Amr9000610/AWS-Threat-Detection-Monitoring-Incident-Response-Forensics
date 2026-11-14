resource "aws_iam_role" "vpc_flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0
  name  = "${var.project_name}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0
  name  = "${var.project_name}-vpc-flow-logs-policy"
  role  = aws_iam_role.vpc_flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "${aws_cloudwatch_log_group.vpc_flow[0].arn}:*"
    }]
  })
}

resource "aws_flow_log" "vpc" {
  count                = var.enable_vpc_flow_logs ? 1 : 0
  vpc_id               = var.vpc_id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.vpc_flow[0].arn
  iam_role_arn         = aws_iam_role.vpc_flow_logs[0].arn

  depends_on = [
    aws_iam_role_policy.vpc_flow_logs
  ]
}

output "aws_account_id" {
  description = "AWS account where resources were created."
  value       = data.aws_caller_identity.current.account_id
}

output "central_logs_bucket_name" {
  description = "Central bucket for CloudTrail and AWS Config logs."
  value       = aws_s3_bucket.central_logs.bucket
}

output "cloudtrail_name" {
  value = aws_cloudtrail.account_trail.name
}

output "cloudtrail_cloudwatch_log_group" {
  value = aws_cloudwatch_log_group.cloudtrail.name
}

output "vpc_flow_log_id" {
  value = try(aws_flow_log.vpc[0].id, null)
}

output "vpc_flow_cloudwatch_log_group" {
  value = try(aws_cloudwatch_log_group.vpc_flow[0].name, null)
}

output "config_recorder_name" {
  value = aws_config_configuration_recorder.main.name
}

output "s3_access_logs_bucket_name" {
  value = aws_s3_bucket.s3_access_logs.bucket
}

output "sample_application_bucket_name" {
  value = aws_s3_bucket.application_data.bucket
}

output "elb_logs_bucket_name" {
  value = aws_s3_bucket.elb_logs.bucket
}

output "athena_database_name" {
  value = aws_athena_database.logs.name
}

output "athena_workgroup_name" {
  value = aws_athena_workgroup.security.name
}

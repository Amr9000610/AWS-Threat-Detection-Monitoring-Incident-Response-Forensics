aws_region = "us-east-1"

project_name = "aws-threat-detection"
environment  = "lab"

# Replace with a real VPC ID in the same AWS region.
vpc_id = "vpc-0123456789abcdef0"

log_retention_days        = 365
cloudwatch_retention_days = 90

enable_vpc_flow_logs            = true
enable_s3_server_access_logging = true

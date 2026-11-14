variable "aws_region" {
  description = "AWS Region where the Week 1 resources will be created."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Lowercase project prefix. Use letters, numbers, and hyphens."
  type        = string
  default     = "aws-threat-detection"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment tag."
  type        = string
  default     = "lab"
}

variable "vpc_id" {
  description = "Existing VPC ID for VPC Flow Logs."
  type        = string
}

variable "log_retention_days" {
  description = "Number of days to retain central S3 log objects before expiration."
  type        = number
  default     = 365
}

variable "cloudwatch_retention_days" {
  description = "Number of days to retain CloudWatch log events."
  type        = number
  default     = 90
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs for the VPC specified in vpc_id."
  type        = bool
  default     = true
}

variable "enable_s3_server_access_logging" {
  description = "Enable server access logging on the sample application bucket."
  type        = bool
  default     = true
}

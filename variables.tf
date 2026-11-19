
variable "aws_region" {
  description = "AWS Region for Week 1 resources."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Lowercase project prefix."
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
  description = "VPC ID for VPC Flow Logs."
  type        = string
  default     = ""

  validation {
    condition     = !var.enable_vpc_flow_logs || can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "A valid VPC ID is required when VPC Flow Logs are enabled."
  }
}

variable "alert_email" {
  description = "Optional notification email. Empty disables email subscription."
  type        = string
  default     = ""

  validation {
    condition     = var.alert_email == "" || can(regex("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$", var.alert_email))
    error_message = "alert_email must be a valid email address or empty."
  }
}

variable "log_retention_days" {
  description = "S3 log retention days."
  type        = number
  default     = 365
}

variable "cloudwatch_retention_days" {
  description = "CloudWatch retention days."
  type        = number
  default     = 90
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs for vpc_id."
  type        = bool
  default     = false
}

variable "enable_s3_server_access_logging" {
  description = "Enable S3 server access logging."
  type        = bool
  default     = true
}

variable "elb_logs_prefix" {
  description = "ELB log prefix."
  type        = string
  default     = "alb"
}

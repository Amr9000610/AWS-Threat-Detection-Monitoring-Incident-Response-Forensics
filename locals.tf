resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  suffix     = random_id.suffix.hex

  elb_logs_prefix_path     = var.elb_logs_prefix == "" ? "" : "${var.elb_logs_prefix}/"
  central_logs_bucket_name = "${var.project_name}-central-${local.suffix}"
  s3_access_bucket_name    = "${var.project_name}-s3-access-${local.suffix}"
  application_bucket_name  = "${var.project_name}-data-${local.suffix}"
  elb_logs_bucket_name     = "${var.project_name}-elb-${local.suffix}"
}

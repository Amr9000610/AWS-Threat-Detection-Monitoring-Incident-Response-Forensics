data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

# Regional ELB service account, used in the ELB logs bucket policy.
data "aws_elb_service_account" "main" {}
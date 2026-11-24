# ============================================================
# WEEK 3 - Cloud Incident Response & Forensics
# Owner: Mostafa
# Reuses shared infrastructure, variables, and locals from Week 1 & Week 2.
# ============================================================

# ------------------------------------------------------------
# Data Sources & Locals
# ------------------------------------------------------------

# Use var.vpc_id if provided in terraform.tfvars; otherwise fall back to the default VPC.
data "aws_vpc" "week3_default" {
  count   = var.vpc_id == "" ? 1 : 0
  default = true
}

data "aws_subnets" "week3_target" {
  filter {
    name   = "vpc-id"
    values = [local.week3_vpc_id]
  }
}

data "aws_ami" "week3_al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  week3_vpc_id               = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.week3_default[0].id
  week3_subnet_id            = sort(data.aws_subnets.week3_target.ids)[0]
  week3_evidence_bucket_name = "${var.project_name}-ir-evidence-${local.suffix}"
  week3_sim_s3_bucket_name   = "${var.project_name}-ir-sim-public-${local.suffix}"
}

# ------------------------------------------------------------
# 1. Network Containment Resources (EC2 Isolation & Quarantine)
# ------------------------------------------------------------

# Normal Lab SG for the test EC2 instance (HTTPS outbound only for SSM - no SSH exposed).
resource "aws_security_group" "week3_lab_ec2" {
  name                   = "${var.project_name}-ir-lab-ec2-sg"
  description            = "Lab SG for simulated compromised EC2 instance (SSM outbound only)"
  vpc_id                 = local.week3_vpc_id
  revoke_rules_on_delete = true

  tags = {
    Name        = "${var.project_name}-ir-lab-ec2-sg"
    Environment = var.environment
    Week        = "week-3"
    Owner       = "mostafa"
    Purpose     = "ir-simulation"
  }
}

resource "aws_vpc_security_group_egress_rule" "week3_lab_ec2_https" {
  security_group_id = aws_security_group.week3_lab_ec2.id
  description       = "Allow outbound HTTPS for AWS SSM Agent"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# Forensic Isolation SG: Intentionally NO ingress and NO egress rules.
# Swapping a compromised EC2 instance to this SG isolates it without losing volatile memory.
resource "aws_security_group" "week3_ir_isolation" {
  name                   = "${var.project_name}-ir-isolation-sg"
  description            = "Quarantine SG for compromised EC2 instances - blocks all inbound and outbound traffic"
  vpc_id                 = local.week3_vpc_id
  revoke_rules_on_delete = true

  tags = {
    Name        = "${var.project_name}-ir-isolation-sg"
    Environment = var.environment
    Week        = "week-3"
    Owner       = "mostafa"
    Purpose     = "incident-response-containment"
  }
}

# Forensic Workstation SG: Outbound HTTPS only for SSM and S3 evidence upload.
resource "aws_security_group" "week3_forensic_workstation" {
  name                   = "${var.project_name}-ir-forensic-workstation-sg"
  description            = "Restricted SG for forensic workstation - outbound HTTPS only for SSM and S3"
  vpc_id                 = local.week3_vpc_id
  revoke_rules_on_delete = true

  tags = {
    Name        = "${var.project_name}-ir-forensic-workstation-sg"
    Environment = var.environment
    Week        = "week-3"
    Owner       = "mostafa"
    Purpose     = "forensic-investigation"
  }
}

resource "aws_vpc_security_group_egress_rule" "week3_forensic_workstation_https" {
  security_group_id = aws_security_group.week3_forensic_workstation.id
  description       = "Allow outbound HTTPS for AWS SSM Session Manager and S3 evidence preservation"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# Emergency Quarantine Network ACL (Stateless Subnet-Level Containment).
# Intentionally NOT associated with a subnet: associate it manually during an incident
# only after confirming the affected subnet, because an association impacts every resource in it.
resource "aws_network_acl" "week3_quarantine" {
  vpc_id = local.week3_vpc_id

  tags = {
    Name        = "${var.project_name}-ir-quarantine-nacl"
    Environment = var.environment
    Week        = "week-3"
    Owner       = "mostafa"
    Purpose     = "emergency-subnet-isolation"
  }
}

resource "aws_network_acl_rule" "week3_quarantine_deny_ingress" {
  network_acl_id = aws_network_acl.week3_quarantine.id
  rule_number    = 100
  egress         = false
  protocol       = "-1"
  rule_action    = "deny"
  cidr_block     = "0.0.0.0/0"
}

resource "aws_network_acl_rule" "week3_quarantine_deny_egress" {
  network_acl_id = aws_network_acl.week3_quarantine.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "deny"
  cidr_block     = "0.0.0.0/0"
}

# ------------------------------------------------------------
# 2. Scenario 1: Compromised EC2 Simulation Lab Instance
# ------------------------------------------------------------

variable "enable_week3_lab_ec2" {
  description = "Opt in to creating the billable Week 3 EC2 lab instance. Keep false for cost-controlled review."
  type        = bool
  default     = false
}

resource "aws_iam_role" "week3_lab_ec2" {
  count = var.enable_week3_lab_ec2 ? 1 : 0
  name = "${var.project_name}-ir-lab-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "week3_lab_ec2_ssm" {
  count      = var.enable_week3_lab_ec2 ? 1 : 0
  role       = aws_iam_role.week3_lab_ec2[0].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "week3_lab_ec2" {
  count = var.enable_week3_lab_ec2 ? 1 : 0
  name  = "${var.project_name}-ir-lab-ec2-profile"
  role  = aws_iam_role.week3_lab_ec2[0].name
}

resource "aws_instance" "week3_lab_target" {
  count                  = var.enable_week3_lab_ec2 ? 1 : 0
  ami                    = data.aws_ami.week3_al2023.id
  instance_type          = "t3.micro"
  subnet_id              = local.week3_subnet_id
  vpc_security_group_ids = [aws_security_group.week3_lab_ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.week3_lab_ec2[0].name
  associate_public_ip_address = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name        = "${var.project_name}-ir-lab-ec2"
    Environment = var.environment
    Week        = "week-3"
    Owner       = "mostafa"
    Purpose     = "compromised-ec2-simulation"
  }
}

# ------------------------------------------------------------
# 3. Scenario 2: Exposed Access Keys Simulation & IAM Containment
# ------------------------------------------------------------

# Dedicated lab IAM user for simulating key exposure, revocation, and rotation.
# Access keys are intentionally NOT created in Terraform to avoid storing secrets in state.
resource "aws_iam_user" "week3_sim_user" {
  name = "${var.project_name}-ir-lab-user"
  path = "/ir-lab/"

  tags = {
    Name        = "${var.project_name}-ir-lab-user"
    Environment = var.environment
    Week        = "week-3"
    Owner       = "mostafa"
    Purpose     = "exposed-keys-simulation"
  }
}

resource "aws_iam_user_policy" "week3_sim_user_minimal" {
  name = "${var.project_name}-ir-lab-user-minimal"
  user = aws_iam_user.week3_sim_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowMinimalLabReadOnly"
        Effect   = "Allow"
        Action   = ["sts:GetCallerIdentity", "s3:ListAllMyBuckets"]
        Resource = "*"
      }
    ]
  })
}

# Explicit Deny-All policy to attach immediately to compromised IAM identities.
resource "aws_iam_policy" "week3_ir_quarantine_deny" {
  name        = "${var.project_name}-ir-quarantine-deny-all"
  description = "Explicit Deny-All policy for immediate containment of compromised IAM identities"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "IncidentResponseDenyAll"
        Effect   = "Deny"
        Action   = "*"
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-ir-quarantine-deny-all"
    Environment = var.environment
    Week        = "week-3"
    Owner       = "mostafa"
    Purpose     = "iam-containment"
  }
}

# ------------------------------------------------------------
# 4. Scenario 3: Public S3 Bucket Simulation (Safe Baseline + Logging)
# ------------------------------------------------------------

resource "aws_s3_bucket" "week3_sim_public" {
  bucket        = local.week3_sim_s3_bucket_name
  force_destroy = false

  tags = {
    Name        = local.week3_sim_s3_bucket_name
    Environment = var.environment
    Week        = "week-3"
    Owner       = "mostafa"
    Purpose     = "public-s3-simulation"
  }
}

resource "aws_s3_bucket_public_access_block" "week3_sim_public" {
  bucket = aws_s3_bucket.week3_sim_public.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "week3_sim_public" {
  bucket = aws_s3_bucket.week3_sim_public.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Reuse Week 1 S3 access log bucket to capture access evidence for the lab bucket.
resource "aws_s3_bucket_logging" "week3_sim_public" {
  count         = var.enable_s3_server_access_logging ? 1 : 0
  bucket        = aws_s3_bucket.week3_sim_public.id
  target_bucket = aws_s3_bucket.s3_access_logs.id
  target_prefix = "s3-access-ir-sim/"

  depends_on = [
    aws_s3_bucket_acl.s3_access_logs
  ]
}

# ------------------------------------------------------------
# 5. Forensics & Chain of Custody (Evidence Bucket & Role)
# ------------------------------------------------------------

resource "aws_s3_bucket" "week3_forensic_evidence" {
  bucket        = local.week3_evidence_bucket_name
  force_destroy = false

  tags = {
    Name        = local.week3_evidence_bucket_name
    Environment = var.environment
    Week        = "week-3"
    Owner       = "mostafa"
    Purpose     = "forensic-evidence-preservation"
  }
}

resource "aws_s3_bucket_public_access_block" "week3_forensic_evidence" {
  bucket = aws_s3_bucket.week3_forensic_evidence.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "week3_forensic_evidence" {
  bucket = aws_s3_bucket.week3_forensic_evidence.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "week3_forensic_evidence" {
  bucket = aws_s3_bucket.week3_forensic_evidence.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Forensic Investigator IAM Role (Least Privilege for EBS Snapshots & Evidence Upload).
resource "aws_iam_role" "week3_forensic_investigator" {
  name = "${var.project_name}-ir-forensic-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_instance_profile" "week3_forensic_investigator" {
  name = "${var.project_name}-ir-forensic-profile"
  role = aws_iam_role.week3_forensic_investigator.name
}

resource "aws_iam_role_policy" "week3_forensic_investigator" {
  name = "${var.project_name}-ir-forensic-policy"
  role = aws_iam_role.week3_forensic_investigator.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PreserveEvidenceToS3"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.week3_forensic_evidence.arn,
          "${aws_s3_bucket.week3_forensic_evidence.arn}/*"
        ]
      },
      {
        Sid    = "CreateForensicSnapshots"
        Effect = "Allow"
        Action = [
          "ec2:CreateSnapshot",
          "ec2:CreateTags",
          "ec2:DescribeInstances",
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots"
        ]
        Resource = "*"
      }
    ]
  })
}

# ------------------------------------------------------------
# Outputs (For Week 3 Playbooks & Week 4 SOAR Automation)
# ------------------------------------------------------------

output "week3_target_vpc_id" {
  description = "VPC ID where Week 3 incident response resources are deployed."
  value       = local.week3_vpc_id
}

output "week3_lab_ec2_instance_id" {
  description = "Lab EC2 instance ID; null unless enable_week3_lab_ec2 is true."
  value       = var.enable_week3_lab_ec2 ? aws_instance.week3_lab_target[0].id : null
}

output "week3_ir_isolation_sg_id" {
  description = "Security Group ID used to isolate compromised EC2 instances."
  value       = aws_security_group.week3_ir_isolation.id
}

output "week3_forensic_workstation_sg_id" {
  description = "Security Group ID for the forensic investigation workstation."
  value       = aws_security_group.week3_forensic_workstation.id
}

output "week3_quarantine_nacl_id" {
  description = "Quarantine Network ACL ID for emergency subnet-level isolation."
  value       = aws_network_acl.week3_quarantine.id
}

output "week3_sim_iam_user_name" {
  description = "Lab IAM user name used for Exposed Access Keys simulation."
  value       = aws_iam_user.week3_sim_user.name
}

output "week3_ir_quarantine_iam_policy_arn" {
  description = "ARN of the explicit Deny-All IAM policy for compromised credential containment."
  value       = aws_iam_policy.week3_ir_quarantine_deny.arn
}

output "week3_sim_public_s3_bucket_name" {
  description = "Lab S3 bucket name used for Public S3 simulation."
  value       = aws_s3_bucket.week3_sim_public.bucket
}

output "week3_forensic_evidence_bucket_name" {
  description = "S3 bucket name for preserving forensic evidence and incident logs."
  value       = aws_s3_bucket.week3_forensic_evidence.bucket
}

output "week3_forensic_investigator_instance_profile" {
  description = "Instance profile to attach to an approved forensic workstation EC2 instance."
  value       = aws_iam_instance_profile.week3_forensic_investigator.name
}

output "week3_forensic_investigator_role_arn" {
  description = "IAM Role ARN for forensic evidence collection and EBS snapshotting."
  value       = aws_iam_role.week3_forensic_investigator.arn
}
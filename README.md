# AWS Threat Detection, Monitoring, Incident Response & Forensics

Terraform configuration for a single AWS account in `us-east-1`.

## Deployment model

The repository is organized as one Terraform root module. Terraform loads all root-level `.tf` files together; the `week1.tf` through `week4.tf` files are organizational placeholders, not isolated modules.

The default configuration is **cost-controlled and non-production**:
- CloudTrail account-level multi-region management events are enabled; AWS Organizations trails are not used.
- S3 object-level CloudTrail data events are disabled by default because they are billable.
- AWS Config and its managed rules are disabled by default.
- Week 2 GuardDuty, Security Hub, Detective, Inspector, and Macie are individually opt-in because their usage can incur charges.
- VPC Flow Logs, S3 server-access logging, and the Week 3 EC2 lab instance are disabled by default.
- S3 log retention defaults to 30 days; CloudWatch log retention defaults to 7 days.
- No EC2 instance is launched by default. Week 3 containment SGs/NACL and IAM/S3 lab resources are prepared, but the quarantine NACL is deliberately not associated with a subnet.

**Free Tier warning:** AWS Free Tier eligibility and allowances depend on account age, plan, Region, service, and usage. These defaults reduce avoidable usage but do not guarantee a zero bill. S3 storage/requests, CloudTrail-to-CloudWatch delivery, CloudWatch Logs/alarms, and other enabled services can still incur charges. Review the AWS Pricing pages and Billing console before any apply.

## Optional feature flags

Set only the features you intend to test in your local, uncommitted `terraform.tfvars`:
- `enable_cloudtrail_s3_data_events = true`
- `enable_aws_config = true` (also creates Week 2 Config managed rules)
- `enable_week2_guardduty = true`
- `enable_week2_securityhub = true`
- `enable_week2_detective = true`
- `enable_week2_inspector = true`
- `enable_week2_macie = true`
- `enable_vpc_flow_logs = true` only with a valid `vpc_id`
- `enable_s3_server_access_logging = true`
- `enable_week3_lab_ec2 = true` only after verifying subnet routing and SSM connectivity

Do not enable every flag at once on a Free Tier account.

## Validate and plan

```bash
terraform fmt -recursive
terraform init
terraform validate
terraform plan
```

Do not run `terraform apply` unless the team leader explicitly approves the reviewed plan. Before the first apply, inventory existing AWS resources to avoid Terraform attempting to recreate resources that already exist outside the state.

## Operational limitations

- The CloudTrail trail is account-level, not an AWS Organizations trail.
- The quarantine NACL is not associated automatically; association affects every resource in a subnet and must be an incident-approved action.
- The Week 3 isolation security group must be attached to a target instance manually or by a separately reviewed response automation.
- The Week 3 forensic investigator role is prepared for an approved workstation; it is not attached to an instance automatically.
- SSM requires network access to the regional Systems Manager endpoints (via NAT/Internet or suitable VPC endpoints); HTTPS egress alone does not guarantee connectivity.
- The Week 3 public-S3 scenario remains safely private by default. Do not disable Public Access Block on a real bucket to demonstrate exposure.
- Athena queries incur charges based on data scanned. The ELB bucket is only a destination and receives no logs until an ALB is configured.

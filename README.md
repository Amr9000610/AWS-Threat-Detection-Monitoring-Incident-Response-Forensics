# AWS Threat Detection, Monitoring, Incident Response & Forensics

Terraform configuration for **Week 1**, targeting one AWS account in `us-east-1`.

## Week 1 resources
- CloudTrail multi-region account trail: management read/write events, S3 object-level data events for the application bucket, log validation, and CloudWatch Logs integration.
- S3 central log storage, versioning, encryption, lifecycle retention, public-access blocking, server-access-log bucket, and sample application bucket.
- AWS Config recorder and delivery channel.
- CloudWatch log group, metric filters, and alarms for failed console sign-ins, denied API calls, and monitored IAM changes.
- SNS topic for alarm notifications; email subscription is optional and configured locally.
- Athena/Glue database, workgroup, and CloudTrail table.
- Optional VPC Flow Logs for an existing VPC.
- ELB access-log bucket and delivery policy only; no load balancer is created or connected.

GuardDuty and later-week detection/response services are out of scope for Week 1.

## Configuration
The shared `backend.tf`, `provider.tf`, `versions.tf`, and lock file remain at repository root. Terraform loads all `.tf` files in this directory as one module; service-specific files remain separate for readability.

Copy `terraform.tfvars.example` to the ignored local file `terraform.tfvars`. VPC Flow Logs are disabled by default; enable them only after supplying a real VPC ID in the configured region. Optionally set `alert_email` to an address you control and confirm the SNS subscription email.

Review AWS charges for CloudTrail data events, Config, CloudWatch Logs, Athena, and related services.

## Validate and plan
```bash
terraform fmt -recursive
terraform init
terraform validate
terraform plan
```
Do not run `terraform apply` until the team leader approves the plan.

CloudTrail delivery is not instantaneous. Validate the Glue table schema and S3 location against delivered records before relying on Athena for investigations. The ELB bucket will not receive logs until a load balancer is configured to use it. The trail is account-level, not an AWS Organizations trail. No automatic remediation is configured.

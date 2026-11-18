# AWS Threat Detection, Monitoring, Incident Response & Forensics

Terraform project for a single AWS account in `us-east-1` (configurable through `aws_region`).

## Included services

- **CloudTrail**: multi-region management-event trail, log-file validation, CloudWatch Logs integration, and S3 object-level data events for the sample application bucket.
- **S3**: central log storage, versioning, encryption, lifecycle retention, public-access blocking, and a separate server-access-log bucket.
- **AWS Config**: configuration recorder and delivery channel.
- **CloudWatch**: CloudTrail and VPC Flow Logs groups, metric filters, and alarms for failed console sign-ins, denied API calls, and monitored IAM changes.
- **GuardDuty**: detector enabled with findings routed through EventBridge to a dedicated CloudWatch Logs group.
- **Athena / Glue**: Athena database and workgroup plus a Glue catalog database/table for querying CloudTrail JSON records.
- **VPC Flow Logs**: optional; uses the VPC ID supplied through `vpc_id`.
- **ALB log bucket**: prepared for ALB access logs; an ALB itself is not created in this project yet.

## Before deployment

1. Confirm the AWS CLI profile `depi-team-5` exists and has permissions for all resources in this project.
2. Confirm the S3 backend bucket `depi-team-555-tfstate` already exists in `us-east-1` and that the profile can access it.
3. Set `vpc_id` in `terraform.tfvars` to a real VPC ID in `aws_region`. The placeholder currently in the sample file must be replaced.
4. Review estimated AWS charges. GuardDuty, CloudTrail data events, CloudWatch Logs/alarms, AWS Config, and Athena can incur charges.
5. The CloudTrail data-event selector monitors object-level activity only in the Terraform-managed `application_data` bucket.

## Validate and deploy

```bash
terraform fmt -recursive
terraform init
terraform validate
terraform plan
terraform apply
```

Do not run `terraform apply` until the plan has been reviewed. The S3 backend is configured with native state locking (`use_lockfile`).

## Querying CloudTrail

After deployment and after CloudTrail has delivered log files, use Athena in the `aws-threat-detection-cloudtrail` Glue database and the `cloudtrail_events` table. The first delivery can take several minutes. Review the table's S3 location and schema against the delivered CloudTrail records before relying on production investigations.

## Important notes

- CloudWatch alarms are created without notification actions. Add an SNS topic/subscription or another approved notification destination to receive email/SMS notifications.
- GuardDuty findings are written to CloudWatch Logs; this configuration does not automatically remediate findings.
- The Athena table is a basic external JSON table. For large log volumes, add partition projection or partition registration to reduce query cost.
- The VPC and ALB resources are intentionally left for a later implementation.


## CloudWatch email alerts (SNS)

The three CloudWatch security alarms publish state-change notifications to an SNS topic.
The configured email subscription is `lotfyzeyad350@gmail.com`. After applying Terraform,
open the AWS SNS confirmation email and choose **Confirm subscription**. Until confirmed,
AWS will not deliver alarm notifications to this address.

GuardDuty resources have intentionally been excluded from this project.

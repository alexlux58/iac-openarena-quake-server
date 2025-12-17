# ============================================================================
# Cost Module Main Configuration
# ============================================================================
# This is the root file of the cost management and security logging module.
# It orchestrates all subcomponents:
#
# - S3 Buckets: Secure storage for logs and reports (s3_buckets.tf)
# - CloudTrail: AWS API activity logging (cloudtrail.tf)
# - GuardDuty: Intelligent threat detection (guardduty.tf)
# - VPC Flow Logs: Network traffic metadata (vpc_flow_logs.tf)
# - SNS Topics: Email notifications for alerts (sns.tf)
# - AWS Budgets: Threshold-based cost monitoring (budgets.tf)
# - Cost Anomaly Detection: ML-based spend spike detection (anomaly_detection.tf)
# - CloudWatch Billing Alarm: Estimated charges failsafe (billing_alarm.tf)
# - Cost and Usage Reports: Detailed billing data export (cur.tf)
# - CloudWatch Logs: EC2 instance log collection (cloudwatch_logs.tf)
#
# DESIGN PHILOSOPHY:
# - Comprehensive security logging with minimal manual configuration
# - Multiple layers of cost monitoring (budgets, anomalies, alarms)
# - Secure by default (encryption, versioning, public access blocked)
# - Extensively documented for learning and operations
# - Feature toggles for granular control and cost optimization
#
# DEPLOYMENT APPROACH:
# 1. Start with all features enabled to experience full capability
# 2. Review costs after first month in Cost Explorer
# 3. Disable expensive features if not needed (GuardDuty, Flow Logs)
# 4. Keep budget monitoring and CloudTrail enabled (minimal cost, high value)
#
# MODULE USAGE:
# This module is instantiated from the root Terraform configuration (terraform/main.tf):
#
# module "cost" {
#   source = "./modules/cost"
#
#   # Required variables
#   log_bucket_name      = "alexflux-audit-logs-${data.aws_caller_identity.current.account_id}"
#   flowlog_bucket_name  = "alexflux-flowlogs-${data.aws_caller_identity.current.account_id}"
#   cur_bucket_name      = "alexflux-cur-${data.aws_caller_identity.current.account_id}"
#   billing_alert_email  = "alex@example.com"
#
#   # Optional: Override defaults
#   monthly_budget_usd   = 20
#   enable_guardduty     = false  # Disable to save ~$5-10/month
#
#   # Optional: Cost module inherits these automatically
#   common_tags = local.common_tags
# }
#
# COST BREAKDOWN (TYPICAL OPENARENA DEPLOYMENT):
# - S3 storage (logs/reports): $1-3/month
# - CloudTrail: FREE (first trail with management events)
# - GuardDuty: $5-15/month (NO FREE TIER - disable if cost-conscious)
# - VPC Flow Logs: $1-5/month (data processing + S3 storage)
# - AWS Budgets: FREE (first 2 budgets)
# - Cost Anomaly Detection: FREE
# - CloudWatch Billing Alarm: FREE (first 10 alarms)
# - CUR: FREE (only S3 storage costs)
# - CloudWatch Logs: $0.15-1/month (if enabled)
#
# Total typical cost: $7-25/month (mostly GuardDuty + VPC Flow Logs)
# Cost-optimized configuration: $1-3/month (disable GuardDuty + Flow Logs)
#
# OPERATIONAL RESPONSIBILITIES:
# 1. Confirm SNS email subscriptions (check inbox after apply)
# 2. Enable "Receive Billing Alerts" in AWS Console (one-time, required for CloudWatch billing alarms)
# 3. Activate cost allocation tags in Billing console (for tag-filtered budgets)
# 4. Review budget/anomaly alerts when received
# 5. Periodically review logs in S3/CloudWatch for security incidents
# 6. Run Cost Explorer queries monthly to understand spending patterns
#
# SECURITY BEST PRACTICES IMPLEMENTED:
# ✓ All S3 buckets have public access blocked
# ✓ All S3 buckets have versioning enabled
# ✓ All S3 buckets have encryption at rest (AES256 or KMS)
# ✓ All IAM policies follow least privilege principle
# ✓ All service principals use SourceAccount conditions (prevent confused deputy)
# ✓ CloudTrail log file validation enabled (detect tampering)
# ✓ GuardDuty findings encrypted with KMS
# ✓ Multi-region CloudTrail (captures all API calls)
# ✓ Comprehensive tagging for cost allocation and governance
#
# COMPLIANCE ALIGNMENT:
# - SOC 2: CloudTrail + VPC Flow Logs + GuardDuty
# - PCI-DSS: CloudTrail + VPC Flow Logs (requirement 10: tracking and monitoring)
# - HIPAA: CloudTrail + GuardDuty + CloudWatch Logs (encryption required)
# - GDPR: Audit trail for data access (CloudTrail + CloudWatch Logs)
# - ISO 27001: Logging and monitoring controls
#
# FURTHER ENHANCEMENTS (NOT IMPLEMENTED HERE, FOR FUTURE CONSIDERATION):
# - AWS Security Hub: Centralized security findings aggregation
# - AWS Config: Resource configuration compliance tracking
# - EventBridge rules: Automated responses to GuardDuty findings
# - Lambda functions: Auto-remediation (isolate compromised instances)
# - Kinesis Firehose: Stream CloudWatch Logs to S3
# - Athena queries: Automated cost analysis reports
# - QuickSight dashboards: Cost and security visualization
# - AWS Organizations: Multi-account governance
# - Service Control Policies: Preventive guardrails
# - CloudWatch Metric Filters: Custom metrics from logs
# - CloudWatch Alarms: Alert on specific log patterns (failed SSH logins, etc.)
# ============================================================================

# This file intentionally minimal - all resources are defined in component files.
# Purpose: Centralized documentation and architectural overview.
#
# Resource files are included automatically by Terraform (*.tf in module directory).
# Terraform loads files in lexicographical order, but resources can reference each
# other regardless of file order (Terraform builds dependency graph automatically).
#
# FILE ORGANIZATION RATIONALE:
# - providers_cost.tf: Provider configuration (must be separate for clarity)
# - variables.tf: All input variables (centralized for easy review)
# - s3_buckets.tf: S3 resources (foundation for all logging)
# - cloudtrail.tf: CloudTrail resources (API logging)
# - guardduty.tf: GuardDuty resources (threat detection)
# - vpc_flow_logs.tf: VPC Flow Logs resources (network logging)
# - sns.tf: SNS resources (notification infrastructure)
# - budgets.tf: AWS Budgets resources (cost threshold monitoring)
# - anomaly_detection.tf: Cost Anomaly Detection resources (ML-based alerts)
# - billing_alarm.tf: CloudWatch billing alarm resources (failsafe)
# - cur.tf: Cost and Usage Reports resources (detailed billing data)
# - cloudwatch_logs.tf: CloudWatch Logs resources (EC2 log collection)
# - outputs.tf: Output values (exposes module results to root config)
# - main.tf (this file): Documentation and overview
#
# This organization improves:
# - Readability: Easy to find specific resource types
# - Maintainability: Changes isolated to relevant files
# - Modularity: Can comment out entire features (e.g., disable guardduty.tf)
# - Documentation: Each file self-documents its purpose
# - Team collaboration: Reduces merge conflicts (different people edit different files)

# ============================================================================
# Cost Module Variables
# ============================================================================
# This file defines all input variables for the cost management and security
# logging module, including budgets, anomaly detection, billing alarms, and
# various log delivery configurations.
#
# VARIABLE NAMING CONVENTIONS:
# - Use snake_case for all variables (consistent with existing infrastructure)
# - Group related variables with common prefixes (e.g., "log_", "budget_", "guardduty_")
# - Use descriptive suffixes: _enabled, _threshold, _prefix, _name, _arn
# - Boolean flags use "enable_" prefix for consistency
#
# SECURITY BEST PRACTICES:
# - All S3 buckets will have public access blocked by default
# - Versioning will be enabled on all log buckets
# - Encryption at rest using AES256 (or KMS for GuardDuty)
# - Principle of least privilege for all IAM policies
# ============================================================================

# ============================================================================
# S3 BUCKET CONFIGURATION
# ============================================================================
# S3 buckets for storing audit logs, security findings, and cost reports.
# Best practice: Use separate buckets for different log types to avoid policy
# conflicts and simplify access management.

variable "log_bucket_name" {
  description = "S3 bucket name for general audit logs (CloudTrail, GuardDuty findings export, CloudWatch Logs archives). Must be globally unique. Recommended format: <org>-<project>-audit-logs-<account-id>"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.log_bucket_name))
    error_message = "Bucket name must be 3-63 characters, start/end with lowercase letter or number, and contain only lowercase letters, numbers, hyphens, and dots."
  }
}

variable "flowlog_bucket_name" {
  description = "S3 bucket name dedicated to VPC Flow Logs. Separate bucket prevents policy conflicts between CloudTrail and VPC Flow Logs. Must be globally unique."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.flowlog_bucket_name))
    error_message = "Bucket name must be 3-63 characters, start/end with lowercase letter or number, and contain only lowercase letters, numbers, hyphens, and dots."
  }
}

variable "cur_bucket_name" {
  description = "S3 bucket name for Cost and Usage Reports (CUR). CUR provides detailed billing data for analysis with Athena/QuickSight. Must be globally unique."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.cur_bucket_name))
    error_message = "Bucket name must be 3-63 characters, start/end with lowercase letter or number, and contain only lowercase letters, numbers, hyphens, and dots."
  }
}

# ============================================================================
# S3 PREFIX CONFIGURATION
# ============================================================================
# Prefixes (folders) within S3 buckets for organizing different log types.
# AWS services automatically create subdirectory structures under these prefixes.

variable "cloudtrail_prefix" {
  description = "S3 key prefix for CloudTrail logs within log_bucket. CloudTrail will create subdirectories: <prefix>/AWSLogs/<account-id>/CloudTrail/<region>/<year>/<month>/<day>/"
  type        = string
  default     = "cloudtrail/"
}

variable "guardduty_export_prefix" {
  description = "S3 key prefix for GuardDuty findings export within log_bucket. GuardDuty creates: <prefix>/<detector-id>/<year>/<month>/<day>/<hour>/"
  type        = string
  default     = "guardduty/"
}

variable "vpc_flowlogs_prefix" {
  description = "S3 key prefix for VPC Flow Logs within flowlog_bucket. Flow logs create: <prefix>/AWSLogs/<account-id>/vpcflowlogs/<region>/<year>/<month>/<day>/"
  type        = string
  default     = "vpcflow/"
}

variable "cw_archive_prefix" {
  description = "S3 key prefix for CloudWatch Logs archives (via Kinesis Firehose) within log_bucket. Used if EC2 OS logs are streamed to S3."
  type        = string
  default     = "cwlogs/"
}

variable "cur_prefix" {
  description = "S3 key prefix for Cost and Usage Reports within cur_bucket. CUR creates: <prefix>/<report-name>/<date-range>/"
  type        = string
  default     = "cur/"
}

# ============================================================================
# FEATURE TOGGLES
# ============================================================================
# Boolean flags to enable/disable specific security logging and cost monitoring
# features. Useful for phased rollout or cost optimization.

variable "enable_cloudtrail" {
  description = "Enable CloudTrail for AWS API activity audit logging. CloudTrail records all API calls made to AWS services, essential for security auditing and compliance. Note: CloudTrail incurs costs after free tier (90 days of management events)."
  type        = bool
  default     = true
}

variable "enable_guardduty" {
  description = "Enable GuardDuty for intelligent threat detection. GuardDuty analyzes CloudTrail, VPC Flow Logs, and DNS logs to identify malicious activity. IMPORTANT: GuardDuty has per-GB analyzed costs (no free tier)."
  type        = bool
  default     = true
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs for network traffic metadata capture. Records accepted/rejected traffic, source/dest IPs, ports, protocols. Useful for security analysis and troubleshooting. Cost: CloudWatch/S3 storage + data processing."
  type        = bool
  default     = true
}

variable "enable_cost_budgets" {
  description = "Enable AWS Budgets for proactive cost threshold monitoring. First 2 budgets are free, then $0.02/day per budget."
  type        = bool
  default     = true
}

variable "enable_cost_anomaly_detection" {
  description = "Enable AWS Cost Anomaly Detection for ML-based spend spike identification. Detects unusual spending patterns automatically. No additional charge for anomaly detection itself."
  type        = bool
  default     = true
}

variable "enable_billing_alarm" {
  description = "Enable CloudWatch Billing Alarm as failsafe for estimated charges monitoring. First 10 alarms are free. PREREQUISITE: Must enable 'Receive Billing Alerts' in AWS Billing console."
  type        = bool
  default     = true
}

variable "enable_cur" {
  description = "Enable Cost and Usage Report (CUR) delivery to S3. CUR provides granular billing data for detailed analysis with Athena/QuickSight. No additional charge for CUR itself (only S3 storage)."
  type        = bool
  default     = true
}

variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch Logs collection from EC2 instances (auth logs, syslog, application logs). Requires CloudWatch Agent installation via Ansible. Cost: $0.50/GB ingested + $0.03/GB stored."
  type        = bool
  default     = false
}

# ============================================================================
# BUDGETING CONFIGURATION
# ============================================================================
# AWS Budgets configuration for proactive cost monitoring with threshold alerts.

variable "monthly_budget_usd" {
  description = "Monthly budget limit in USD for the OpenArena project. Alerts will be sent at 50%, 80%, and 100% of this amount. Set based on expected EC2 (t2.micro ~$8-10/month), storage, and data transfer costs."
  type        = number
  default     = 15

  validation {
    condition     = var.monthly_budget_usd > 0
    error_message = "Monthly budget must be greater than 0."
  }
}

variable "billing_alert_email" {
  description = "Email address for receiving budget alerts, billing alarms, and cost anomaly notifications. You will receive an SNS subscription confirmation email after deployment - YOU MUST CONFIRM IT for alerts to work."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.billing_alert_email))
    error_message = "Must be a valid email address format."
  }
}

variable "budget_alert_thresholds" {
  description = "List of percentage thresholds (0-100) for budget alerts. Default: 50%, 80%, 100% (actual), and 100% (forecasted). Each threshold generates a separate notification."
  type        = list(number)
  default     = [50, 80, 100]

  validation {
    condition     = alltrue([for t in var.budget_alert_thresholds : t > 0 && t <= 100])
    error_message = "All thresholds must be between 1 and 100 (inclusive)."
  }
}

variable "enable_forecasted_alert" {
  description = "Enable forecasted budget alert at 100% threshold. AWS predicts if you'll exceed budget by month-end based on current spend trends. Useful for early warning."
  type        = bool
  default     = true
}

# ============================================================================
# COST ANOMALY DETECTION CONFIGURATION
# ============================================================================
# AWS Cost Anomaly Detection uses ML to identify unusual spending patterns.

variable "anomaly_threshold_usd" {
  description = "Minimum dollar amount (USD) for anomaly detection alerts. Anomalies with total impact below this threshold will not trigger notifications. Helps reduce noise from small fluctuations."
  type        = number
  default     = 5

  validation {
    condition     = var.anomaly_threshold_usd >= 0
    error_message = "Anomaly threshold must be greater than or equal to 0."
  }
}

variable "anomaly_frequency" {
  description = "Frequency for anomaly detection reports. 'DAILY' sends consolidated daily reports. 'IMMEDIATE' sends notifications as soon as anomalies are detected (can be noisy)."
  type        = string
  default     = "DAILY"

  validation {
    condition     = contains(["DAILY", "IMMEDIATE"], var.anomaly_frequency)
    error_message = "Anomaly frequency must be either 'DAILY' or 'IMMEDIATE'."
  }
}

# ============================================================================
# CLOUDWATCH BILLING ALARM CONFIGURATION
# ============================================================================
# CloudWatch Billing Alarm acts as a secondary failsafe for cost monitoring.

variable "billing_alarm_usd" {
  description = "Dollar threshold (USD) for CloudWatch Billing Alarm. Alert triggers when estimated monthly charges exceed this amount. Should be set higher than monthly_budget_usd as a failsafe."
  type        = number
  default     = 20

  validation {
    condition     = var.billing_alarm_usd > 0
    error_message = "Billing alarm threshold must be greater than 0."
  }
}

variable "billing_alarm_evaluation_periods" {
  description = "Number of evaluation periods (each 6 hours) before alarm triggers. Default 1 means alarm triggers immediately when threshold exceeded. Increase to reduce false positives."
  type        = number
  default     = 1

  validation {
    condition     = var.billing_alarm_evaluation_periods >= 1 && var.billing_alarm_evaluation_periods <= 5
    error_message = "Evaluation periods must be between 1 and 5."
  }
}

# ============================================================================
# COST AND USAGE REPORT (CUR) CONFIGURATION
# ============================================================================
# CUR provides the most detailed billing data available for historical analysis.

variable "cur_report_name" {
  description = "Name for the Cost and Usage Report. This will be the folder name under the CUR S3 prefix. Use lowercase alphanumeric and hyphens only."
  type        = string
  default     = "openarena-cur"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.cur_report_name))
    error_message = "CUR report name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "cur_time_unit" {
  description = "Time granularity for CUR data. 'HOURLY' provides the most detailed view (recommended for analysis). 'DAILY' reduces file size but loses intraday granularity. 'MONTHLY' is the least detailed."
  type        = string
  default     = "HOURLY"

  validation {
    condition     = contains(["HOURLY", "DAILY", "MONTHLY"], var.cur_time_unit)
    error_message = "CUR time unit must be HOURLY, DAILY, or MONTHLY."
  }
}

variable "cur_compression" {
  description = "Compression format for CUR files. 'GZIP' is standard and widely supported. 'Parquet' is optimized for Athena queries but requires additional configuration."
  type        = string
  default     = "GZIP"

  validation {
    condition     = contains(["GZIP", "Parquet"], var.cur_compression)
    error_message = "CUR compression must be either GZIP or Parquet."
  }
}

variable "cur_format" {
  description = "CUR file format. 'textORcsv' is CSV format (human-readable, compatible with most tools). 'Parquet' is columnar format optimized for analytics."
  type        = string
  default     = "textORcsv"

  validation {
    condition     = contains(["textORcsv", "Parquet"], var.cur_format)
    error_message = "CUR format must be either textORcsv or Parquet."
  }
}

variable "cur_additional_artifacts" {
  description = "Additional CUR artifacts to include. 'REDSHIFT' adds manifest files for Redshift COPY. 'QUICKSIGHT' adds manifest for QuickSight. 'ATHENA' adds Athena integration files (Parquet format only)."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for artifact in var.cur_additional_artifacts : contains(["REDSHIFT", "QUICKSIGHT", "ATHENA"], artifact)])
    error_message = "CUR artifacts must be REDSHIFT, QUICKSIGHT, or ATHENA."
  }
}

# ============================================================================
# CLOUDTRAIL CONFIGURATION
# ============================================================================
# CloudTrail configuration for comprehensive API activity logging.

variable "cloudtrail_multi_region" {
  description = "Enable multi-region trail. 'true' (recommended) captures API calls from ALL regions in a single trail. 'false' only captures calls in the current region."
  type        = bool
  default     = true
}

variable "cloudtrail_include_global_service_events" {
  description = "Include global service events (IAM, STS, CloudFront, Route53). Should be 'true' for at least one trail in the account. Required for full security auditing."
  type        = bool
  default     = true
}

variable "cloudtrail_enable_log_file_validation" {
  description = "Enable CloudTrail log file validation using digital signatures. Ensures log files haven't been tampered with after delivery. Strongly recommended for compliance and security."
  type        = bool
  default     = true
}

variable "cloudtrail_enable_logging" {
  description = "Start logging immediately after trail creation. Should typically be 'true'. Set to 'false' only if you want to configure the trail but not start logging yet."
  type        = bool
  default     = true
}

# ============================================================================
# GUARDDUTY CONFIGURATION
# ============================================================================
# GuardDuty threat detection and findings export configuration.

variable "guardduty_finding_publishing_frequency" {
  description = "How often GuardDuty exports findings to S3. 'FIFTEEN_MINUTES' for near real-time (highest cost), 'ONE_HOUR' for balanced approach, 'SIX_HOURS' for reduced costs."
  type        = string
  default     = "SIX_HOURS"

  validation {
    condition     = contains(["FIFTEEN_MINUTES", "ONE_HOUR", "SIX_HOURS"], var.guardduty_finding_publishing_frequency)
    error_message = "Publishing frequency must be FIFTEEN_MINUTES, ONE_HOUR, or SIX_HOURS."
  }
}

variable "guardduty_enable_s3_protection" {
  description = "Enable GuardDuty S3 Protection to monitor S3 data events for suspicious access patterns. Additional cost: $0.80 per 1M S3 events analyzed."
  type        = bool
  default     = false
}

variable "guardduty_enable_kubernetes_protection" {
  description = "Enable GuardDuty Kubernetes Protection (EKS audit log monitoring). Not needed for OpenArena EC2-only deployment. Only enable if using EKS."
  type        = bool
  default     = false
}

variable "guardduty_enable_malware_protection" {
  description = "Enable GuardDuty Malware Protection for EBS volumes. Scans volumes for malware when suspicious activity detected. Additional cost: $1.00 per GB scanned."
  type        = bool
  default     = false
}

# ============================================================================
# VPC FLOW LOGS CONFIGURATION
# ============================================================================
# VPC Flow Logs configuration for network traffic analysis.

variable "vpc_flow_logs_traffic_type" {
  description = "Type of traffic to capture. 'ALL' captures both accepted and rejected traffic (recommended for security). 'ACCEPT' only captures allowed traffic. 'REJECT' only captures blocked traffic."
  type        = string
  default     = "ALL"

  validation {
    condition     = contains(["ALL", "ACCEPT", "REJECT"], var.vpc_flow_logs_traffic_type)
    error_message = "Traffic type must be ALL, ACCEPT, or REJECT."
  }
}

variable "vpc_flow_logs_log_format" {
  description = "Custom log format for VPC Flow Logs. Use AWS default format or specify custom fields. Default format includes: srcaddr, dstaddr, srcport, dstport, protocol, packets, bytes, start, end, action, log-status."
  type        = string
  default     = null # null uses AWS default format
}

variable "vpc_flow_logs_max_aggregation_interval" {
  description = "Maximum aggregation interval for flow log records in seconds. '60' provides more granular data (more records, higher cost). '600' (10 minutes) reduces cost but less granular."
  type        = number
  default     = 600

  validation {
    condition     = contains([60, 600], var.vpc_flow_logs_max_aggregation_interval)
    error_message = "Max aggregation interval must be either 60 or 600 seconds."
  }
}

# ============================================================================
# CLOUDWATCH LOGS CONFIGURATION
# ============================================================================
# CloudWatch Logs configuration for EC2 instance log collection.

variable "cw_log_group_retention_days" {
  description = "Number of days to retain CloudWatch Logs. Options: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653, or 0 (never expire). Longer retention = higher cost."
  type        = number
  default     = 30

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.cw_log_group_retention_days)
    error_message = "Retention days must be a valid CloudWatch Logs retention period."
  }
}

variable "cw_log_groups" {
  description = "Map of CloudWatch Log Group names for different log types. These log groups will be created if enable_cloudwatch_logs is true. Keys are log types, values are log group names."
  type        = map(string)
  default = {
    auth   = "/openarena/ec2/auth"
    syslog = "/openarena/ec2/syslog"
    app    = "/openarena/ec2/app"
  }
}

# ============================================================================
# TAGGING CONFIGURATION
# ============================================================================
# Common tags applied to all resources created by this module for cost
# allocation and resource management.

variable "common_tags" {
  description = "Common tags to apply to all resources created by this module. Used for cost allocation, resource management, and compliance tracking. Activate these tags in Cost Allocation Tags console for budget filtering."
  type        = map(string)
  default = {
    Project     = "openarena"
    ManagedBy   = "terraform"
    Module      = "cost"
    Environment = "production"
  }
}

# ============================================================================
# ADVANCED CONFIGURATION
# ============================================================================
# Advanced settings for power users and specific use cases.

variable "kms_key_deletion_window" {
  description = "Number of days before KMS key is permanently deleted after destruction (7-30 days). Longer window allows key recovery if accidental deletion. Cannot be 0."
  type        = number
  default     = 30

  validation {
    condition     = var.kms_key_deletion_window >= 7 && var.kms_key_deletion_window <= 30
    error_message = "KMS key deletion window must be between 7 and 30 days."
  }
}

variable "s3_bucket_force_destroy" {
  description = "DANGER: Allow Terraform to delete S3 buckets even if they contain objects. 'false' (recommended) prevents accidental data loss. Only set to 'true' in dev/test environments."
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID for which to enable VPC Flow Logs. If not specified, will use the default VPC. Override this if you're using a custom VPC."
  type        = string
  default     = null # null will auto-detect default VPC
}

# ============================================================================
# Cost Module Outputs
# ============================================================================
# This file consolidates all outputs from the cost management and security
# logging module. These outputs can be referenced by the root configuration
# or other modules.
#
# OUTPUT ORGANIZATION:
# Outputs are grouped by feature area for easy navigation:
# 1. S3 Buckets
# 2. CloudTrail
# 3. GuardDuty
# 4. VPC Flow Logs
# 5. SNS Topics
# 6. AWS Budgets
# 7. Cost Anomaly Detection
# 8. CloudWatch Billing Alarm
# 9. Cost and Usage Reports
# 10. CloudWatch Logs
# 11. Summary Information
#
# USAGE IN ROOT MODULE:
# module "cost" {
#   source = "./modules/cost"
#   # ... variables ...
# }
#
# output "cost_monitoring_urls" {
#   value = module.cost.summary_information
# }
# ============================================================================

# ============================================================================
# 1. S3 BUCKETS
# ============================================================================

output "log_bucket_id" {
  description = "ID of the S3 bucket for audit logs (CloudTrail, GuardDuty, CloudWatch Logs archives)"
  value       = aws_s3_bucket.log_bucket.id
}

output "log_bucket_arn" {
  description = "ARN of the audit logs S3 bucket"
  value       = aws_s3_bucket.log_bucket.arn
}

output "flowlog_bucket_id" {
  description = "ID of the S3 bucket for VPC Flow Logs"
  value       = aws_s3_bucket.flowlog_bucket.id
}

output "flowlog_bucket_arn" {
  description = "ARN of the VPC Flow Logs S3 bucket"
  value       = aws_s3_bucket.flowlog_bucket.arn
}

output "cur_bucket_id" {
  description = "ID of the S3 bucket for Cost and Usage Reports"
  value       = aws_s3_bucket.cur_bucket.id
}

output "cur_bucket_arn" {
  description = "ARN of the Cost and Usage Reports S3 bucket"
  value       = aws_s3_bucket.cur_bucket.arn
}

# ============================================================================
# 2. CLOUDTRAIL (outputs defined in cloudtrail.tf)
# ============================================================================
# Outputs are already defined in cloudtrail.tf and will be automatically
# available when this module is instantiated.

# ============================================================================
# 3. GUARDDUTY (outputs defined in guardduty.tf)
# ============================================================================
# Outputs are already defined in guardduty.tf

# ============================================================================
# 4. VPC FLOW LOGS (outputs defined in vpc_flow_logs.tf)
# ============================================================================
# Outputs are already defined in vpc_flow_logs.tf

# ============================================================================
# 5. SNS TOPICS (outputs defined in sns.tf)
# ============================================================================
# Outputs are already defined in sns.tf

# ============================================================================
# 6. AWS BUDGETS (outputs defined in budgets.tf)
# ============================================================================
# Outputs are already defined in budgets.tf

# ============================================================================
# 7. COST ANOMALY DETECTION (outputs defined in anomaly_detection.tf)
# ============================================================================
# Outputs are already defined in anomaly_detection.tf

# ============================================================================
# 8. CLOUDWATCH BILLING ALARM (outputs defined in billing_alarm.tf)
# ============================================================================
# Outputs are already defined in billing_alarm.tf

# ============================================================================
# 9. COST AND USAGE REPORTS (outputs defined in cur.tf)
# ============================================================================
# Outputs are already defined in cur.tf

# ============================================================================
# 10. CLOUDWATCH LOGS (outputs defined in cloudwatch_logs.tf)
# ============================================================================
# Outputs are already defined in cloudwatch_logs.tf

# ============================================================================
# 11. SUMMARY INFORMATION
# ============================================================================
# High-level summary of enabled features and important URLs/ARNs for operators.

output "summary_information" {
  description = "Summary of cost management and security logging infrastructure"
  value = {
    # Feature enablement status
    features_enabled = {
      cloudtrail        = var.enable_cloudtrail
      guardduty         = var.enable_guardduty
      vpc_flow_logs     = var.enable_vpc_flow_logs
      budgets           = var.enable_cost_budgets
      anomaly_detection = var.enable_cost_anomaly_detection
      billing_alarm     = var.enable_billing_alarm
      cur               = var.enable_cur
      cloudwatch_logs   = var.enable_cloudwatch_logs
    }

    # S3 locations for accessing logs
    log_locations = {
      cloudtrail_logs    = var.enable_cloudtrail ? "s3://${aws_s3_bucket.log_bucket.id}/${var.cloudtrail_prefix}" : null
      guardduty_findings = var.enable_guardduty ? "s3://${aws_s3_bucket.log_bucket.id}/${var.guardduty_export_prefix}" : null
      vpc_flow_logs      = var.enable_vpc_flow_logs ? "s3://${aws_s3_bucket.flowlog_bucket.id}/${var.vpc_flowlogs_prefix}" : null
      cur_reports        = var.enable_cur ? "s3://${aws_s3_bucket.cur_bucket.id}/${var.cur_prefix}/${var.cur_report_name}/" : null
    }

    # Cost monitoring thresholds
    cost_thresholds = {
      monthly_budget_usd    = var.enable_cost_budgets ? var.monthly_budget_usd : null
      billing_alarm_usd     = var.enable_billing_alarm ? var.billing_alarm_usd : null
      anomaly_threshold_usd = var.enable_cost_anomaly_detection ? var.anomaly_threshold_usd : null
    }

    # Notification configuration
    notifications = {
      email_address        = var.billing_alert_email
      budget_alerts_topic  = var.enable_cost_budgets ? aws_sns_topic.budget_alerts[0].arn : null
      anomaly_alerts_topic = var.enable_cost_anomaly_detection ? aws_sns_topic.anomaly_alerts[0].arn : null
    }

    # Next steps for operators
    next_steps = [
      "1. Check email inbox for SNS subscription confirmation emails",
      "2. Confirm all SNS subscriptions by clicking links in emails",
      "3. Enable 'Receive Billing Alerts' in AWS Billing console (required for CloudWatch billing alarms)",
      "4. (Optional) Activate cost allocation tags in Billing console for tag-filtered budgets",
      "5. Wait 24 hours for first CloudTrail logs to appear in S3",
      "6. Wait 24 hours for first Cost and Usage Report to be generated",
      "7. Review AWS Budgets console to verify budget configuration",
      "8. Check GuardDuty console for detector status (if enabled)",
      "9. Verify VPC Flow Logs are being delivered to S3 (if enabled)",
      "10. Monitor costs in Cost Explorer after first full month"
    ]
  }
}

output "console_urls" {
  description = "AWS Console URLs for accessing cost management and security logging resources"
  value = {
    # Cost Management Consoles
    budgets_console     = "https://console.aws.amazon.com/billing/home#/budgets"
    cost_explorer       = "https://console.aws.amazon.com/cost-management/home#/cost-explorer"
    anomaly_detection   = "https://console.aws.amazon.com/cost-management/home#/anomaly-detection"
    billing_preferences = "https://console.aws.amazon.com/billing/home#/preferences"

    # Security Logging Consoles
    cloudtrail_console      = var.enable_cloudtrail ? "https://console.aws.amazon.com/cloudtrail/home?region=${data.aws_region.current.name}#/trails" : null
    guardduty_console       = var.enable_guardduty ? "https://console.aws.amazon.com/guardduty/home?region=${data.aws_region.current.name}#/findings" : null
    vpc_flow_logs_console   = var.enable_vpc_flow_logs ? "https://console.aws.amazon.com/vpc/home?region=${data.aws_region.current.name}#FlowLogs:" : null
    cloudwatch_logs_console = var.enable_cloudwatch_logs ? "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#logsV2:log-groups" : null

    # S3 Buckets
    log_bucket_console     = "https://s3.console.aws.amazon.com/s3/buckets/${aws_s3_bucket.log_bucket.id}"
    flowlog_bucket_console = "https://s3.console.aws.amazon.com/s3/buckets/${aws_s3_bucket.flowlog_bucket.id}"
    cur_bucket_console     = "https://s3.console.aws.amazon.com/s3/buckets/${aws_s3_bucket.cur_bucket.id}"

    # SNS Topics
    sns_topics_console = "https://console.aws.amazon.com/sns/v3/home?region=${data.aws_region.current.name}#/topics"
  }
}

output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown for cost management and security logging infrastructure (USD)"
  value = {
    s3_storage = {
      description  = "S3 storage for logs and reports"
      estimate_usd = "$1-3/month (depends on log volume)"
    }
    cloudtrail = {
      description  = "AWS CloudTrail API activity logging"
      estimate_usd = var.enable_cloudtrail ? "FREE (first trail with management events)" : "Disabled"
    }
    guardduty = {
      description  = "GuardDuty intelligent threat detection (NO FREE TIER)"
      estimate_usd = var.enable_guardduty ? "$5-15/month (main cost driver)" : "Disabled"
    }
    vpc_flow_logs = {
      description  = "VPC Flow Logs network traffic analysis"
      estimate_usd = var.enable_vpc_flow_logs ? "$1-5/month (data processing + S3 storage)" : "Disabled"
    }
    budgets = {
      description  = "AWS Budgets cost threshold monitoring"
      estimate_usd = var.enable_cost_budgets ? "FREE (first 2 budgets)" : "Disabled"
    }
    anomaly_detection = {
      description  = "Cost Anomaly Detection ML-based spend spike detection"
      estimate_usd = var.enable_cost_anomaly_detection ? "FREE" : "Disabled"
    }
    billing_alarm = {
      description  = "CloudWatch Billing Alarm estimated charges failsafe"
      estimate_usd = var.enable_billing_alarm ? "FREE (first 10 alarms)" : "Disabled"
    }
    cur = {
      description  = "Cost and Usage Reports detailed billing data"
      estimate_usd = var.enable_cur ? "FREE (only S3 storage costs)" : "Disabled"
    }
    cloudwatch_logs = {
      description  = "CloudWatch Logs EC2 instance log collection"
      estimate_usd = var.enable_cloudwatch_logs ? "$0.15-1/month (if logs are minimal)" : "Disabled"
    }
    total_estimated = {
      description    = "Total estimated monthly cost"
      all_features   = "$7-25/month (typical with all features enabled)"
      cost_optimized = "$1-3/month (GuardDuty and VPC Flow Logs disabled)"
      note           = "Actual costs vary based on AWS usage volume. Monitor in Cost Explorer."
    }
  }
}

# ============================================================================
# OPERATIONAL NOTES FOR OUTPUTS
# ============================================================================
# ACCESSING OUTPUTS IN ROOT MODULE:
#
# After applying Terraform, view outputs with:
#   terraform output
#   terraform output -json | jq '.summary_information.value'
#
# Use outputs in other modules:
#   module "monitoring" {
#     source = "./modules/monitoring"
#     cloudtrail_arn = module.cost.cloudtrail_arn
#   }
#
# DISPLAYING OUTPUTS TO USER:
# The deploy.sh script can display important outputs:
#   echo "Budget monitoring enabled: $(terraform output -json | jq -r '.summary_information.value.features_enabled.budgets')"
#   echo "CloudTrail logs location: $(terraform output -json | jq -r '.summary_information.value.log_locations.cloudtrail_logs')"
#
# USING OUTPUTS FOR VALIDATION:
# Write automated tests that verify outputs:
#   #!/bin/bash
#   CLOUDTRAIL_ENABLED=$(terraform output -json | jq -r '.summary_information.value.features_enabled.cloudtrail')
#   if [ "$CLOUDTRAIL_ENABLED" = "true" ]; then
#     echo "✓ CloudTrail is enabled"
#   else
#     echo "✗ CloudTrail is not enabled"
#     exit 1
#   fi
# ============================================================================

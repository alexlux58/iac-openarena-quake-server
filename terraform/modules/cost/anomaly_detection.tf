# ============================================================================
# AWS Cost Anomaly Detection Configuration
# ============================================================================
# Cost Anomaly Detection uses machine learning to automatically identify
# unusual spending patterns and alert you to unexpected cost spikes.
#
# HOW IT WORKS:
# 1. AWS analyzes your historical spending patterns (needs ~10 days of data)
# 2. ML model learns "normal" spending for each service
# 3. Detects deviations from expected patterns (anomalies)
# 4. Sends notifications when anomalies exceed configured threshold
#
# ANOMALY TYPES DETECTED:
# - Sudden cost spikes (e.g., EC2 instance left running)
# - New service usage (e.g., first-time S3 usage)
# - Regional changes (e.g., accidental resource in wrong region)
# - Usage pattern changes (e.g., 10x increase in API calls)
#
# MONITORS VS SUBSCRIPTIONS:
# - Monitor: Defines WHAT to track (specific services, accounts, tags)
# - Subscription: Defines WHO to notify and WHEN (threshold, frequency)
#
# MONITOR TYPES:
# - AWS_SERVICES: Tracks all AWS services individually
# - LINKED_ACCOUNT: Tracks specific accounts (for AWS Organizations)
# - DIMENSIONAL: Custom dimensions (Service, AZ, Instance Type, etc.)
#
# DETECTION SENSITIVITY:
# - HIGH: Detects smaller anomalies (more alerts, may have false positives)
# - MEDIUM: Balanced detection (recommended)
# - LOW: Only detects significant anomalies (fewer alerts)
#
# COST: FREE (No additional charge for anomaly detection service)
# Only pay for underlying Cost Explorer API usage (minimal)
#
# DOCUMENTATION:
# - Anomaly Detection Guide: https://docs.aws.amazon.com/cost-management/latest/userguide/manage-ad.html
# - Best Practices: https://docs.aws.amazon.com/cost-management/latest/userguide/best-practices.html
# - Terraform Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ce_anomaly_monitor
# ============================================================================

# ============================================================================
# ANOMALY MONITOR: SERVICE-LEVEL TRACKING
# ============================================================================
# Monitors each AWS service independently for unusual spending patterns.
# This is the most common and recommended monitor type.

resource "aws_ce_anomaly_monitor" "service_monitor" {
  count = var.enable_cost_anomaly_detection ? 1 : 0

  # Monitor name (shown in Cost Anomaly Detection console)
  name = "openarena-service-monitor"

  # Monitor type: AWS_SERVICES tracks each service individually
  # This provides granular visibility into which service caused the anomaly
  monitor_type = "DIMENSIONAL"

  # Monitor specification: defines the dimension to track
  # SERVICE dimension means track EC2, S3, RDS, etc. separately
  # Each service's spending is analyzed independently
  monitor_specification = jsonencode({
    Dimensions = {
      Key          = "SERVICE"
      MatchOptions = ["EQUALS"]
      Values       = [] # Empty = all services (or specify: ["Amazon EC2", "Amazon S3"])
    }
  })

  tags = merge(
    var.common_tags,
    {
      Name        = "openarena-service-monitor"
      Description = "Cost anomaly monitor for per-service spending analysis"
      Service     = "cost-anomaly-detection"
      MonitorType = "service"
    }
  )
}

# ============================================================================
# OPTIONAL: ANOMALY MONITOR FOR SPECIFIC COST CATEGORIES
# ============================================================================
# Track anomalies for specific dimensions like region, instance type, etc.
#
# Example 1: Monitor only EC2 costs
# resource "aws_ce_anomaly_monitor" "ec2_monitor" {
#   count        = var.enable_cost_anomaly_detection ? 1 : 0
#   name         = "openarena-ec2-monitor"
#   monitor_type = "DIMENSIONAL"
#
#   monitor_specification = jsonencode({
#     Dimensions = {
#       Key          = "SERVICE"
#       MatchOptions = ["EQUALS"]
#       Values       = ["Amazon Elastic Compute Cloud - Compute"]
#     }
#   })
# }
#
# Example 2: Monitor costs in specific region only
# resource "aws_ce_anomaly_monitor" "region_monitor" {
#   count        = var.enable_cost_anomaly_detection ? 1 : 0
#   name         = "openarena-uswest2-monitor"
#   monitor_type = "DIMENSIONAL"
#
#   monitor_specification = jsonencode({
#     Dimensions = {
#       Key          = "REGION"
#       MatchOptions = ["EQUALS"]
#       Values       = ["us-west-2"]
#     }
#   })
# }
#
# Example 3: Monitor costs with specific tag
# resource "aws_ce_anomaly_monitor" "project_monitor" {
#   count        = var.enable_cost_anomaly_detection ? 1 : 0
#   name         = "openarena-project-monitor"
#   monitor_type = "DIMENSIONAL"
#
#   monitor_specification = jsonencode({
#     Tags = {
#       Key          = "Project"
#       MatchOptions = ["EQUALS"]
#       Values       = ["openarena"]
#     }
#   })
# }

# ============================================================================
# ANOMALY SUBSCRIPTION: NOTIFICATION CONFIGURATION
# ============================================================================
# Defines who gets notified when anomalies are detected and with what frequency.

resource "aws_ce_anomaly_subscription" "daily_alerts" {
  count = var.enable_cost_anomaly_detection ? 1 : 0

  # Subscription name (shown in Cost Anomaly Detection console)
  name = "openarena-anomaly-daily"

  # Notification frequency:
  # - DAILY: Consolidated daily report of all detected anomalies (recommended)
  # - IMMEDIATE: Notification as soon as anomaly is detected (can be noisy)
  # - WEEKLY: Weekly summary (less responsive)
  frequency = var.anomaly_frequency

  # List of monitor ARNs to subscribe to
  # Can include multiple monitors to consolidate notifications
  monitor_arn_list = [
    aws_ce_anomaly_monitor.service_monitor[0].arn
  ]

  # Threshold configuration: only alert if impact >= threshold
  # Filters out minor cost fluctuations that don't warrant attention
  # Uses ANOMALY_TOTAL_IMPACT_ABSOLUTE (dollar amount)
  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = [tostring(var.anomaly_threshold_usd)]
    }
  }

  # SNS notification subscriber
  # Email notification is also supported but SNS is more flexible
  subscriber {
    type    = "SNS"
    address = aws_sns_topic.anomaly_alerts[0].arn
  }

  # OPTIONAL: Additional email subscriber
  # Useful for directly notifying specific individuals
  # subscriber {
  #   type    = "EMAIL"
  #   address = var.billing_alert_email
  # }

  tags = merge(
    var.common_tags,
    {
      Name        = "openarena-anomaly-daily"
      Description = "Daily anomaly detection alerts for OpenArena costs"
      Service     = "cost-anomaly-detection"
      Frequency   = var.anomaly_frequency
    }
  )

  # Ensure monitor and SNS topic exist before creating subscription
  depends_on = [
    aws_ce_anomaly_monitor.service_monitor,
    aws_sns_topic.anomaly_alerts
  ]
}

# ============================================================================
# OPTIONAL: MULTIPLE SUBSCRIPTIONS FOR DIFFERENT SEVERITY LEVELS
# ============================================================================
# Create different subscriptions with different thresholds for tiered alerting.
#
# Example: Critical alerts (>$10) vs warning alerts (>$5)
#
# resource "aws_ce_anomaly_subscription" "critical_alerts" {
#   count     = var.enable_cost_anomaly_detection ? 1 : 0
#   name      = "openarena-anomaly-critical"
#   frequency = "IMMEDIATE"  # Immediate notification for critical anomalies
#
#   monitor_arn_list = [aws_ce_anomaly_monitor.service_monitor[0].arn]
#
#     # Only alert for anomalies >= $10 impact
#   threshold_expression {
#     dimension {
#       key          = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
#       match_options = ["GREATER_THAN_OR_EQUAL"]
#       values       = ["10"]
#     }
#   }
#
#   subscriber {
#     type    = "SNS"
#     address = aws_sns_topic.anomaly_alerts[0].arn
#   }
#
#   # Optional: Send critical alerts to SMS
#   subscriber {
#     type    = "SNS"
#     address = aws_sns_topic.critical_alerts_sms[0].arn
#   }
# }

# ============================================================================
# OUTPUTS FOR COST ANOMALY DETECTION
# ============================================================================

output "anomaly_monitor_arn" {
  description = "ARN of the cost anomaly monitor for service-level tracking"
  value       = var.enable_cost_anomaly_detection ? aws_ce_anomaly_monitor.service_monitor[0].arn : null
}

output "anomaly_subscription_arn" {
  description = "ARN of the anomaly detection subscription for daily alerts"
  value       = var.enable_cost_anomaly_detection ? aws_ce_anomaly_subscription.daily_alerts[0].arn : null
}

output "anomaly_threshold_usd" {
  description = "Threshold in USD for anomaly detection alerts"
  value       = var.enable_cost_anomaly_detection ? var.anomaly_threshold_usd : null
}

# ============================================================================
# OPERATIONAL NOTES
# ============================================================================
# INITIAL SETUP AND LEARNING PERIOD:
#
# 1. Anomaly detection needs ~10 days of cost data to establish baseline
# 2. First 2 weeks may have inaccurate or false-positive detections
# 3. Detection accuracy improves over time as model learns your patterns
# 4. Steady-state services (like always-on EC2) establish reliable baselines quickly
# 5. Variable services (like on-demand batch jobs) take longer to model
#
# UNDERSTANDING ANOMALY SCORES:
#
# Anomaly notifications include an "anomaly score" (0-1):
# - 0.7-1.0: High confidence (definitely anomalous)
# - 0.5-0.7: Medium confidence (likely anomalous)
# - 0.0-0.5: Low confidence (possibly anomalous)
#
# Higher scores = more deviation from expected pattern
#
# NOTIFICATION FORMAT:
#
# Anomaly alerts contain:
# - Service name (e.g., "Amazon EC2")
# - Anomaly date range
# - Expected cost vs actual cost
# - Total impact (dollar amount over expected)
# - Anomaly score (confidence level)
# - Root cause analysis (if available)
# - Link to Cost Anomaly Detection console
#
# Example notification:
# ---
# Cost Anomaly Detected
#
# Service: Amazon Elastic Compute Cloud - Compute
# Anomaly Date: January 15, 2024
# Expected Cost: $8.50
# Actual Cost: $24.75
# Impact: +$16.25 (190% increase)
# Anomaly Score: 0.92 (High Confidence)
#
# Possible Cause: Unusual spike in t2.micro usage hours
#
# View Details: [Link to Console]
# ---
#
# COMMON ANOMALY CAUSES (OPENARENA PROJECT):
#
# 1. EC2 Instance Left Running:
#    - Forgot to stop/terminate test instance
#    - Automatic shutdown script failed
#    - Impact: $8-10 per 24 hours (t2.micro)
#
# 2. Data Transfer Spike:
#    - Unusual amount of players/traffic
#    - DDoS attack or bot traffic
#    - Impact: $0.09 per GB out (first 10TB/month)
#
# 3. S3 Storage Increase:
#    - Log files accumulating without lifecycle policy
#    - Backup files not cleaned up
#    - Impact: $0.023 per GB-month
#
# 4. Wrong Region Deployment:
#    - Accidentally deployed resources in different region
#    - Some regions have higher pricing (e.g., São Paulo)
#    - Impact: Varies (can be 20-50% more expensive)
#
# 5. EBS Volume Attached to Terminated Instance:
#    - Instance terminated but volume remained
#    - Impact: $0.10 per GB-month (gp3)
#
# RESPONDING TO ANOMALIES:
#
# 1. Review the anomaly details in Cost Anomaly Detection console
# 2. Check Cost Explorer for detailed breakdown
# 3. Investigate CloudTrail for related API activity (who created resources?)
# 4. Check AWS Health Dashboard for service issues
# 5. Verify resources in correct region (us-west-2)
# 6. Review EC2 instances (running when they should be stopped?)
# 7. Check S3 bucket sizes (unexpected data growth?)
# 8. Terminate/stop unnecessary resources
# 9. Update IaC (Terraform) to prevent recurrence
#
# TUNING ANOMALY DETECTION:
#
# Adjust threshold_expression if you get too many/few alerts:
#
# Too many alerts (false positives):
# - Increase threshold from $5 to $10
# - Change frequency from IMMEDIATE to DAILY
# - Add more specific monitors (EC2-only instead of all services)
#
# Too few alerts (missing anomalies):
# - Decrease threshold from $5 to $2
# - Create separate monitors for different services
# - Use IMMEDIATE frequency for critical services
#
# INTEGRATION WITH OTHER TOOLS:
#
# 1. AWS Budgets: Complementary (budgets = threshold, anomalies = ML-based)
# 2. CloudWatch Billing Alarms: Backup alerting mechanism
# 3. Cost Explorer: Detailed analysis after anomaly detected
# 4. CloudTrail: Investigate who/what caused the anomaly
# 5. AWS Health Dashboard: Check for service issues causing cost spike
#
# LIMITATIONS:
#
# - Requires 10 days of data before accurate detection
# - Can't detect intentional spending increases (scaling up for event)
# - May miss gradual cost increases (only detects sudden spikes)
# - Not suitable for highly variable workloads (batch jobs, seasonal apps)
# - Cannot predict future costs (use budgets for that)
#
# BEST PRACTICES:
#
# 1. Use anomaly detection + budgets together (complementary approaches)
# 2. Set threshold based on typical daily cost variation ($5 for ~$10-15/month budget)
# 3. Use DAILY frequency for most use cases (IMMEDIATE can be too noisy)
# 4. Create separate monitors for critical vs non-critical services
# 5. Review and tune thresholds monthly based on alert patterns
# 6. Enable cost allocation tags for better root cause analysis
# 7. Document known anomaly causes (deployments, traffic spikes, etc.)
# 8. Set up automated responses with EventBridge + Lambda (advanced)
#
# TERRAFORM CONSIDERATIONS:
#
# - Monitors and subscriptions can be deleted/recreated without losing history
# - Anomaly detection data is not stored in Terraform state
# - Changing monitor type requires destroy/recreate (no in-place update)
# - Can have up to 100 monitors and 100 subscriptions per account
# ============================================================================

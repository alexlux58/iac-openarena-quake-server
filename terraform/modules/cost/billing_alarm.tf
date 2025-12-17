# ============================================================================
# CloudWatch Billing Alarm Configuration
# ============================================================================
# CloudWatch Billing Alarm provides a failsafe backup alert for estimated charges.
# This complements AWS Budgets and Cost Anomaly Detection.
#
# WHY USE BILLING ALARMS:
# - Simplest possible cost monitoring (single threshold alert)
# - Independent from AWS Budgets (different service = redundancy)
# - Free for first 10 alarms (then $0.10/month per alarm)
# - Direct integration with CloudWatch (familiar metrics/alarms)
# - Can trigger automated responses via SNS → Lambda
#
# HOW IT WORKS:
# 1. AWS publishes EstimatedCharges metric to CloudWatch (us-east-1 only)
# 2. Metric updates every 6 hours with current month-to-date charges
# 3. Alarm checks metric against threshold every evaluation period
# 4. Triggers SNS notification when threshold exceeded
#
# BILLING METRICS AVAILABLE:
# - EstimatedCharges: Total estimated charges for current month
# - ServiceCharges: Per-service estimated charges (EC2, S3, etc.)
#
# IMPORTANT PREREQUISITES:
# 1. Must enable "Receive Billing Alerts" in AWS Billing Preferences
# 2. Billing metrics only available in us-east-1 region
# 3. Data appears 6 hours after first AWS usage
# 4. Shows month-to-date charges (resets on 1st of each month)
#
# COST: First 10 CloudWatch alarms are FREE
#
# DOCUMENTATION:
# - Billing Metrics: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/monitor_estimated_charges_with_cloudwatch.html
# - CloudWatch Alarms: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html
# - Best Practices: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Best_Practice_Recommended_Alarms_AWS_Services.html
# ============================================================================

# ============================================================================
# CLOUDWATCH BILLING ALARM: ESTIMATED CHARGES
# ============================================================================
# Alerts when month-to-date estimated charges exceed configured threshold.
# This is a simple failsafe that catches runaway costs.

resource "aws_cloudwatch_metric_alarm" "estimated_charges" {
  count = var.enable_billing_alarm ? 1 : 0

  # IMPORTANT: Must use us-east-1 provider alias
  # Billing metrics are ONLY published to us-east-1 region
  provider = aws.use1

  # Alarm name (shown in CloudWatch console and SNS notifications)
  alarm_name = "openarena-estimated-charges"

  # Human-readable description
  alarm_description = "Alert when estimated monthly charges exceed $${var.billing_alarm_usd}. This is a failsafe backup to AWS Budgets."

  # Comparison operator: how to compare metric value to threshold
  # Options: GreaterThanThreshold, GreaterThanOrEqualToThreshold,
  #          LessThanThreshold, LessThanOrEqualToThreshold
  comparison_operator = "GreaterThanThreshold"

  # Evaluation periods: number of consecutive periods threshold must be breached
  # Each period is defined by 'period' parameter (21600 seconds = 6 hours)
  # evaluation_periods = 1 means alarm triggers immediately on first breach
  # evaluation_periods = 2 means alarm triggers only if breached for 12 hours
  evaluation_periods = var.billing_alarm_evaluation_periods

  # Metric to monitor
  metric_name = "EstimatedCharges"

  # Namespace where metric is published
  # AWS/Billing is the namespace for all billing metrics
  namespace = "AWS/Billing"

  # Period: granularity of data aggregation in seconds
  # 21600 seconds = 6 hours (matches how often AWS updates billing metrics)
  # Using 6-hour period aligns with AWS's billing metric update frequency
  period = 21600 # 6 hours

  # Statistic: how to aggregate metric values over the period
  # Options: Average, Sum, Minimum, Maximum, SampleCount
  # Maximum ensures we catch the highest charge within the period
  statistic = "Maximum"

  # Threshold: dollar amount that triggers the alarm
  # Set higher than monthly_budget_usd as a failsafe
  # Example: Budget = $15, Alarm = $20 (backup in case budget alerts fail)
  threshold = var.billing_alarm_usd

  # Treat missing data as "notBreaching" (alarm doesn't trigger)
  # This prevents false alarms if billing metrics temporarily unavailable
  # Options: notBreaching, breaching, ignore, missing
  treat_missing_data = "notBreaching"

  # Dimensions: filters for the metric
  # Currency dimension ensures we're monitoring USD charges only
  dimensions = {
    Currency = "USD"
  }

  # Actions to take when alarm enters ALARM state (threshold breached)
  alarm_actions = [
    aws_sns_topic.budget_alerts[0].arn
  ]

  # Actions to take when alarm returns to OK state (below threshold)
  # Useful for "all clear" notifications
  # ok_actions = [
  #   aws_sns_topic.budget_alerts[0].arn
  # ]

  # Actions to take when alarm enters INSUFFICIENT_DATA state
  # Happens when metric not available (e.g., first day of month, service outage)
  # insufficient_data_actions = []

  tags = merge(
    var.common_tags,
    {
      Name        = "openarena-estimated-charges"
      Description = "CloudWatch billing alarm for estimated monthly charges failsafe"
      Service     = "cloudwatch"
      AlarmType   = "billing"
      Threshold   = "$${var.billing_alarm_usd}"
    }
  )

  # Ensure SNS topic exists before creating alarm
  depends_on = [
    aws_sns_topic.budget_alerts
  ]
}

# ============================================================================
# OPTIONAL: PER-SERVICE BILLING ALARMS
# ============================================================================
# Monitor individual service costs (EC2, S3, etc.) for granular alerting.
# Useful for catching unexpected costs in specific services.
#
# Example: EC2 Charges Alarm
# resource "aws_cloudwatch_metric_alarm" "ec2_charges" {
#   count    = var.enable_billing_alarm ? 1 : 0
#   provider = aws.use1
#
#   alarm_name          = "openarena-ec2-charges"
#   alarm_description   = "Alert when EC2 estimated charges exceed $12"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 1
#   metric_name         = "EstimatedCharges"
#   namespace           = "AWS/Billing"
#   period              = 21600
#   statistic           = "Maximum"
#   threshold           = 12
#   treat_missing_data  = "notBreaching"
#
#   # Filter to only EC2 charges using ServiceName dimension
#   dimensions = {
#     Currency    = "USD"
#     ServiceName = "AmazonEC2"
#   }
#
#   alarm_actions = [aws_sns_topic.budget_alerts[0].arn]
# }
#
# Example: S3 Charges Alarm
# resource "aws_cloudwatch_metric_alarm" "s3_charges" {
#   count    = var.enable_billing_alarm ? 1 : 0
#   provider = aws.use1
#
#   alarm_name          = "openarena-s3-charges"
#   alarm_description   = "Alert when S3 estimated charges exceed $5"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 1
#   metric_name         = "EstimatedCharges"
#   namespace           = "AWS/Billing"
#   period              = 21600
#   statistic           = "Maximum"
#   threshold           = 5
#   treat_missing_data  = "notBreaching"
#
#   dimensions = {
#     Currency    = "USD"
#     ServiceName = "AmazonS3"
#   }
#
#   alarm_actions = [aws_sns_topic.budget_alerts[0].arn]
# }

# ============================================================================
# OPTIONAL: COMPOSITE ALARMS
# ============================================================================
# Combine multiple alarms with AND/OR logic to reduce alert fatigue.
#
# Example: Alert only if BOTH EC2 AND S3 charges are high
# resource "aws_cloudwatch_composite_alarm" "combined_charges" {
#   count    = var.enable_billing_alarm ? 1 : 0
#   provider = aws.use1
#
#   alarm_name          = "openarena-combined-charges"
#   alarm_description   = "Alert when both EC2 and S3 charges are elevated"
#   actions_enabled     = true
#
#   # Alarm rule: ALARM() function checks if child alarm is in ALARM state
#   alarm_rule = join(" AND ", [
#     "ALARM(${aws_cloudwatch_metric_alarm.ec2_charges[0].alarm_name})",
#     "ALARM(${aws_cloudwatch_metric_alarm.s3_charges[0].alarm_name})"
#   ])
#
#   alarm_actions = [aws_sns_topic.budget_alerts[0].arn]
# }

# ============================================================================
# OUTPUTS FOR BILLING ALARM
# ============================================================================

output "billing_alarm_name" {
  description = "Name of the CloudWatch billing alarm"
  value       = var.enable_billing_alarm ? aws_cloudwatch_metric_alarm.estimated_charges[0].alarm_name : null
}

output "billing_alarm_arn" {
  description = "ARN of the CloudWatch billing alarm"
  value       = var.enable_billing_alarm ? aws_cloudwatch_metric_alarm.estimated_charges[0].arn : null
}

output "billing_alarm_threshold" {
  description = "Dollar threshold for billing alarm"
  value       = var.enable_billing_alarm ? var.billing_alarm_usd : null
}

# ============================================================================
# OPERATIONAL NOTES
# ============================================================================
# PREREQUISITE CONFIGURATION (ONE-TIME MANUAL STEP):
#
# Before billing alarms work, you MUST enable billing alerts in AWS Console:
#
# 1. Sign in to AWS Console as root user or IAM user with billing access
# 2. Navigate to: Billing and Cost Management → Billing Preferences
# 3. Check "Receive CloudWatch Billing Alerts"
# 4. Click "Save preferences"
# 5. Wait 15-30 minutes for billing metrics to appear in CloudWatch
#
# Verification:
# - Go to CloudWatch console (us-east-1 region)
# - Metrics → All metrics → Billing
# - Should see "EstimatedCharges" metric
#
# IMPORTANT: If you don't see the metric after 30 minutes:
# - Verify billing alerts are enabled in Billing Preferences
# - Ensure you're viewing CloudWatch in us-east-1 region
# - Check that you have some AWS usage (metric won't appear for $0.00 spend)
#
# UNDERSTANDING BILLING ALARM BEHAVIOR:
#
# 1. METRIC UPDATE FREQUENCY:
#    - EstimatedCharges updates every 6 hours
#    - Alarm evaluates every 6 hours (period = 21600 seconds)
#    - Don't expect real-time alerting (up to 6-hour delay)
#
# 2. MONTH-TO-DATE CHARGES:
#    - Metric shows cumulative charges since 1st of month
#    - Resets to $0.00 on 1st of each month
#    - Alarm will clear automatically on month rollover
#
# 3. ESTIMATED VS ACTUAL:
#    - Charges are ESTIMATED (not final)
#    - Final charges may differ slightly (within 1-2%)
#    - Credits/refunds applied later won't show in metric
#
# 4. ALARM STATES:
#    - OK: Charges below threshold (green)
#    - ALARM: Charges exceed threshold (red)
#    - INSUFFICIENT_DATA: Metric not available yet (gray)
#
# NOTIFICATION FORMAT:
#
# Email notifications from CloudWatch billing alarms:
# ---
# Subject: ALARM: "openarena-estimated-charges" in US East (N. Virginia)
#
# You are receiving this email because your Amazon CloudWatch Alarm
# "openarena-estimated-charges" in the US East (N. Virginia) region
# has entered the ALARM state, because "Threshold Crossed: 1 datapoint
# [24.50 (15/01/24 18:00:00)] was greater than the threshold (20.0)."
#
# Alarm Details:
# - Name: openarena-estimated-charges
# - Description: Alert when estimated monthly charges exceed $20
# - State Change: OK -> ALARM
# - Reason: Threshold Crossed
# - Timestamp: January 15, 2024 18:00:00 UTC
#
# View this alarm in the AWS Management Console:
# [Link to CloudWatch Console]
# ---
#
# TROUBLESHOOTING:
#
# Issue: Alarm stuck in INSUFFICIENT_DATA state
# Solutions:
# - Enable "Receive Billing Alerts" in Billing Preferences
# - Wait 15-30 minutes after enabling
# - Ensure you're in us-east-1 region (billing metrics only there)
# - Check you have some AWS usage (metric won't appear for $0 spend)
#
# Issue: Alarm not triggering despite high charges
# Solutions:
# - Verify threshold is set correctly (not too high)
# - Check comparison_operator is "GreaterThanThreshold"
# - Ensure treat_missing_data is set correctly
# - Verify SNS email subscription is confirmed
# - Wait for next 6-hour metric update
#
# Issue: Alarm triggers immediately every month
# Solutions:
# - Increase threshold (currently too low for typical monthly spend)
# - Check if there's unusual spending causing immediate breach
# - Consider using forecasted budget alerts instead (more sophisticated)
#
# COMPARISON WITH OTHER COST MONITORING:
#
# CloudWatch Billing Alarm vs AWS Budgets:
# ✓ Simpler (single threshold)
# ✓ Independent service (redundancy)
# ✗ No forecasting
# ✗ No percentage thresholds
# ✗ No tag filtering
# ✗ 6-hour granularity (vs 8-hour for budgets)
#
# CloudWatch Billing Alarm vs Cost Anomaly Detection:
# ✓ Predictable threshold
# ✓ Immediate at threshold (no ML learning period)
# ✗ No context about why costs increased
# ✗ Can't detect gradual increases
# ✗ No service-level root cause
#
# BEST PRACTICES:
#
# 1. Use as BACKUP to AWS Budgets (not primary monitoring)
#    - Budget: $15/month with 50%, 80%, 100% alerts
#    - Billing Alarm: $20 as failsafe backup
#
# 2. Set threshold 25-33% above monthly budget
#    - Catches budget alert failures
#    - Avoids duplicate alerts for normal overspend
#
# 3. Use evaluation_periods = 1 for immediate alert
#    - No reason to delay (charges already 6 hours old)
#
# 4. Don't create too many per-service alarms
#    - Use Cost Anomaly Detection for that (free + more intelligent)
#    - Only create per-service alarms for critical services
#
# 5. Combine with automated remediation
#    - SNS → Lambda → Stop EC2 instances
#    - SNS → Lambda → Send Slack notification
#    - SNS → Lambda → Create Jira ticket
#
# COST OPTIMIZATION:
#
# - First 10 CloudWatch alarms: FREE
# - Additional alarms: $0.10/month each
# - SNS notifications: Free for email
# - Billing metrics: Free (no Cost Explorer charges)
#
# Recommendation: Stick to 1-2 billing alarms (total, EC2) to stay in free tier
#
# AUTOMATED REMEDIATION EXAMPLE:
#
# Create Lambda function triggered by billing alarm SNS:
#
# 1. Parse SNS message to get current charges
# 2. List all running EC2 instances
# 3. Stop non-critical instances (tagged "Environment=dev")
# 4. Send detailed notification to Slack
# 5. Create incident in PagerDuty
#
# This can prevent runaway costs from forgotten resources.
# ============================================================================

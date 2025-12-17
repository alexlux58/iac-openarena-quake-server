# ============================================================================
# SNS Topics for Cost and Budget Notifications
# ============================================================================
# This file creates SNS topics for sending cost-related notifications via email.
# Two separate topics are created because different AWS services publish to them:
# 1. Budget alerts topic: Used by AWS Budgets service
# 2. Anomaly alerts topic: Used by AWS Cost Anomaly Detection service
#
# WHY SEPARATE TOPICS:
# - Different AWS service principals (budgets.amazonaws.com vs costalerts.amazonaws.com)
# - Allows different subscriber lists if needed (budget alerts to finance, anomalies to ops)
# - Simplifies troubleshooting (clear separation of alert sources)
# - Enables different notification formats or destinations in the future
#
# SNS SUBSCRIPTION WORKFLOW:
# 1. Terraform creates SNS topic and email subscription
# 2. AWS sends confirmation email to the specified address
# 3. User MUST click "Confirm subscription" link in email
# 4. Until confirmed, no notifications will be delivered
# 5. Check spam folder if confirmation email doesn't arrive
#
# COST:
# - SNS topics: Free
# - SNS email notifications: Free (first 1,000/month)
# - Additional emails: $0.50 per 1 million notifications (effectively free)
#
# DOCUMENTATION:
# - SNS Overview: https://docs.aws.amazon.com/sns/latest/dg/welcome.html
# - SNS Email Subscriptions: https://docs.aws.amazon.com/sns/latest/dg/sns-email-notifications.html
# - Budgets SNS: https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-sns-policy.html
# ============================================================================

# ============================================================================
# BUDGET ALERTS SNS TOPIC
# ============================================================================
# Topic for AWS Budgets notifications (threshold and forecast alerts)

resource "aws_sns_topic" "budget_alerts" {
  count = var.enable_cost_budgets ? 1 : 0

  name = "openarena-budget-alerts"

  # Display name shown in email "From" field (max 100 characters)
  display_name = "OpenArena Budget Alerts"

  # Delivery status logging for troubleshooting (optional, commented out)
  # Logs successful and failed deliveries to CloudWatch Logs
  # Requires additional IAM role for SNS to write to CloudWatch
  #
  # lambda_success_feedback_role_arn = aws_iam_role.sns_delivery_status[0].arn
  # lambda_failure_feedback_role_arn = aws_iam_role.sns_delivery_status[0].arn
  # lambda_success_feedback_sample_rate = 100

  tags = merge(
    var.common_tags,
    {
      Name        = "openarena-budget-alerts"
      Description = "SNS topic for AWS Budgets threshold and forecast notifications"
      Service     = "sns"
      AlertType   = "budget"
    }
  )
}

# SNS Topic Policy: Allow AWS Budgets service to publish notifications
# This policy grants budgets.amazonaws.com permission to send messages to this topic
# Required for AWS Budgets to deliver notifications
resource "aws_sns_topic_policy" "budget_alerts" {
  count = var.enable_cost_budgets ? 1 : 0

  arn = aws_sns_topic.budget_alerts[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSBudgetsSNSPublishingPermissions"
        Effect = "Allow"

        # AWS Budgets service principal
        Principal = {
          Service = "budgets.amazonaws.com"
        }

        # Allow publishing messages to this topic
        Action = "sns:Publish"

        # This specific topic
        Resource = aws_sns_topic.budget_alerts[0].arn

        # Security: Only allow requests from our AWS account
        # Prevents other accounts' budgets from publishing to our topic
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# Email subscription for budget alerts
# IMPORTANT: Subscriber must confirm subscription via email
resource "aws_sns_topic_subscription" "budget_email" {
  count = var.enable_cost_budgets ? 1 : 0

  topic_arn = aws_sns_topic.budget_alerts[0].arn

  # Protocol: email, email-json, sms, sqs, lambda, https, etc.
  # "email" delivers human-readable plain text (recommended for cost alerts)
  # "email-json" delivers raw JSON (useful for programmatic processing)
  protocol = "email"

  # Email address to receive notifications
  endpoint = var.billing_alert_email

  # Note: Terraform cannot automatically confirm email subscriptions
  # The subscription will be in "PendingConfirmation" state until user confirms
}

# ============================================================================
# ANOMALY DETECTION ALERTS SNS TOPIC
# ============================================================================
# Separate topic for AWS Cost Anomaly Detection notifications

resource "aws_sns_topic" "anomaly_alerts" {
  count = var.enable_cost_anomaly_detection ? 1 : 0

  name         = "openarena-anomaly-alerts"
  display_name = "OpenArena Cost Anomaly Alerts"

  tags = merge(
    var.common_tags,
    {
      Name        = "openarena-anomaly-alerts"
      Description = "SNS topic for AWS Cost Anomaly Detection notifications"
      Service     = "sns"
      AlertType   = "anomaly"
    }
  )
}

# SNS Topic Policy: Allow Cost Anomaly Detection service to publish
# IMPORTANT: Uses different service principal than Budgets
# Cost Anomaly Detection uses: costalerts.amazonaws.com
resource "aws_sns_topic_policy" "anomaly_alerts" {
  count = var.enable_cost_anomaly_detection ? 1 : 0

  arn = aws_sns_topic.anomaly_alerts[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSAnomalyDetectionSNSPublishingPermissions"
        Effect = "Allow"

        # Cost Anomaly Detection service principal
        Principal = {
          Service = "costalerts.amazonaws.com"
        }

        Action   = "sns:Publish"
        Resource = aws_sns_topic.anomaly_alerts[0].arn

        # Security condition to prevent confused deputy attacks
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# Email subscription for anomaly alerts
resource "aws_sns_topic_subscription" "anomaly_email" {
  count = var.enable_cost_anomaly_detection ? 1 : 0

  topic_arn = aws_sns_topic.anomaly_alerts[0].arn
  protocol  = "email"
  endpoint  = var.billing_alert_email
}

# ============================================================================
# OPTIONAL: SMS NOTIFICATIONS
# ============================================================================
# Uncomment to add SMS notifications for critical alerts
# COST: SMS notifications are NOT free
# - US: $0.00645 per SMS
# - International rates vary (check AWS SNS pricing)
#
# resource "aws_sns_topic_subscription" "budget_sms" {
#   count = var.enable_cost_budgets ? 1 : 0
#
#   topic_arn = aws_sns_topic.budget_alerts[0].arn
#   protocol  = "sms"
#   endpoint  = var.sms_phone_number  # Format: +1234567890
# }

# ============================================================================
# OPTIONAL: SLACK INTEGRATION VIA LAMBDA
# ============================================================================
# To send alerts to Slack, create a Lambda function triggered by SNS:
#
# 1. Create Lambda function that posts to Slack webhook
# 2. Subscribe Lambda to SNS topic
# 3. Grant SNS permission to invoke Lambda
#
# Example (simplified, requires Lambda function code):
#
# resource "aws_lambda_permission" "sns_to_slack" {
#   statement_id  = "AllowExecutionFromSNS"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.slack_notifier.function_name
#   principal     = "sns.amazonaws.com"
#   source_arn    = aws_sns_topic.budget_alerts[0].arn
# }
#
# resource "aws_sns_topic_subscription" "budget_slack" {
#   topic_arn = aws_sns_topic.budget_alerts[0].arn
#   protocol  = "lambda"
#   endpoint  = aws_lambda_function.slack_notifier.arn
# }

# ============================================================================
# OPTIONAL: PAGERDUTY INTEGRATION
# ============================================================================
# PagerDuty has native SNS integration:
#
# 1. Get SNS integration endpoint from PagerDuty service
# 2. Subscribe HTTPS endpoint to SNS topic
#
# resource "aws_sns_topic_subscription" "budget_pagerduty" {
#   topic_arn = aws_sns_topic.budget_alerts[0].arn
#   protocol  = "https"
#   endpoint  = "https://events.pagerduty.com/integration/<key>/enqueue"
# }

# ============================================================================
# OUTPUTS FOR SNS TOPICS
# ============================================================================

output "budget_alerts_topic_arn" {
  description = "ARN of the SNS topic for budget alerts"
  value       = var.enable_cost_budgets ? aws_sns_topic.budget_alerts[0].arn : null
}

output "anomaly_alerts_topic_arn" {
  description = "ARN of the SNS topic for cost anomaly alerts"
  value       = var.enable_cost_anomaly_detection ? aws_sns_topic.anomaly_alerts[0].arn : null
}

output "budget_email_subscription_arn" {
  description = "ARN of the email subscription for budget alerts (PendingConfirmation until user confirms)"
  value       = var.enable_cost_budgets ? aws_sns_topic_subscription.budget_email[0].arn : null
}

output "anomaly_email_subscription_arn" {
  description = "ARN of the email subscription for anomaly alerts (PendingConfirmation until user confirms)"
  value       = var.enable_cost_anomaly_detection ? aws_sns_topic_subscription.anomaly_email[0].arn : null
}

# ============================================================================
# OPERATIONAL NOTES
# ============================================================================
# VERIFYING SNS SETUP:
#
# 1. Check email inbox (and spam folder) for confirmation emails from AWS
#    Subject: "AWS Notification - Subscription Confirmation"
#
# 2. Click "Confirm subscription" link in email
#
# 3. Verify subscription in AWS Console:
#    SNS → Topics → <topic-name> → Subscriptions
#    Status should show "Confirmed" (not "PendingConfirmation")
#
# 4. Test notifications (after confirming subscription):
#    aws sns publish \
#      --topic-arn <topic-arn> \
#      --subject "Test Alert" \
#      --message "This is a test notification from OpenArena cost monitoring"
#
# TROUBLESHOOTING:
#
# Issue: Not receiving confirmation email
# Solution:
# - Check spam/junk folder
# - Verify email address in var.billing_alert_email
# - Check SNS topic policy (must allow budgets.amazonaws.com to publish)
# - Manually request confirmation:
#   aws sns subscribe --topic-arn <arn> --protocol email --notification-endpoint <email>
#
# Issue: Subscription shows "PendingConfirmation" for days
# Solution:
# - Resend confirmation:
#   aws sns subscribe --topic-arn <arn> --protocol email --notification-endpoint <email>
# - Or manually confirm in console:
#   SNS → Subscriptions → Select subscription → Request confirmation
#
# Issue: Not receiving budget alerts despite confirmed subscription
# Solution:
# - Verify budget is created and active
# - Check budget threshold has been exceeded
# - Verify SNS topic policy allows budgets.amazonaws.com
# - Check CloudTrail for SNS publish errors
#
# NOTIFICATION FORMAT:
#
# Budget alerts contain:
# - Budget name and amount
# - Current actual spend and forecasted spend
# - Threshold that triggered the alert
# - Link to AWS Cost Explorer
#
# Anomaly alerts contain:
# - Anomaly description and impact
# - Service causing anomaly
# - Anomaly score (confidence level)
# - Link to Cost Anomaly Detection console
#
# SECURITY BEST PRACTICES:
#
# 1. Use SNS topic policies to restrict publishers (implemented above)
# 2. Don't share SNS topic ARNs publicly (they're account-specific)
# 3. Use HTTPS subscriptions with authentication for webhooks
# 4. Enable SNS delivery status logging for audit trail (optional)
# 5. Rotate Slack webhook URLs periodically if using Slack integration
#
# COST OPTIMIZATION:
#
# - Email notifications: Effectively free (first 1,000/month included)
# - SMS notifications: $0.00645 per message (US) - use sparingly
# - Lambda subscriptions: Free tier covers 1M invocations/month
# - HTTPS subscriptions: Free (you pay for your webhook endpoint)
#
# COMPLIANCE NOTES:
#
# - SNS message delivery is best-effort (not guaranteed)
# - For compliance-critical alerts, use multiple notification channels
# - Enable SNS delivery logs for audit trail if required
# - Messages are encrypted in transit but not at rest by default
# - For at-rest encryption, enable SNS topic encryption with KMS
# ============================================================================

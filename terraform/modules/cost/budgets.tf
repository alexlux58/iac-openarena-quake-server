# ============================================================================
# AWS Budgets Configuration
# ============================================================================
# AWS Budgets provides proactive cost monitoring with threshold-based alerts.
# Budgets track actual spend and forecasted spend against defined limits.
#
# BUDGET TYPES:
# - COST: Track spending in dollars (most common, used here)
# - USAGE: Track usage hours/GB (e.g., EC2 instance hours, S3 GB-months)
# - SAVINGS_PLANS_UTILIZATION: Track Savings Plans usage percentage
# - RI_UTILIZATION: Track Reserved Instances usage percentage
#
# NOTIFICATION TYPES:
# - ACTUAL: Alert when actual spend crosses threshold
# - FORECASTED: Alert when AWS predicts you'll exceed budget by month-end
#
# THRESHOLD TYPES:
# - PERCENTAGE: Alert at X% of budget (e.g., 50%, 80%, 100%)
# - ABSOLUTE_VALUE: Alert at specific dollar amount
#
# COST:
# - First 2 budgets: FREE
# - Additional budgets: $0.02/day ($0.60/month) each
# - Budget actions (automated responses): $0.10 per action
#
# DOCUMENTATION:
# - Budgets Guide: https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html
# - Creating Budgets: https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-create.html
# - Best Practices: https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-best-practices.html
# ============================================================================

# ============================================================================
# MONTHLY COST BUDGET WITH MULTIPLE THRESHOLDS
# ============================================================================
# Primary budget that tracks total monthly spend for the OpenArena project.
# Sends alerts at 50%, 80%, and 100% of budget limit.

resource "aws_budgets_budget" "monthly_total" {
  count = var.enable_cost_budgets ? 1 : 0

  # Budget name (shown in AWS Budgets console)
  name = "openarena-monthly-total"

  # Budget type: COST tracks spending in dollars
  budget_type = "COST"

  # Budget limit amount and currency
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"

  # Time period: MONTHLY, QUARTERLY, or ANNUALLY
  # MONTHLY resets on the 1st of each month
  time_unit = "MONTHLY"

  # Optional: Custom time period (start and end dates)
  # Uncomment to set a specific budget period instead of recurring monthly
  # time_period_start = "2024-01-01_00:00"
  # time_period_end   = "2024-12-31_23:59"

  # Optional: Cost filters to scope budget to specific resources
  # Uncomment to track only costs with specific tags, services, or accounts
  # This is useful for multi-project accounts
  #
  # cost_filter {
  #   name   = "TagKeyValue"
  #   values = ["user:Project$openarena"]  # Format: user:TagKey$TagValue
  # }
  #
  # cost_filter {
  #   name   = "Service"
  #   values = ["Amazon Elastic Compute Cloud - Compute", "Amazon Simple Storage Service"]
  # }

  # Cost types configuration: what to include in budget calculations
  cost_types {
    include_credit             = false # Exclude AWS credits (show actual spend)
    include_discount           = true  # Include volume/tiered pricing discounts
    include_other_subscription = false # Exclude marketplace subscriptions
    include_recurring          = true  # Include recurring charges (Reserved Instances, etc.)
    include_refund             = false # Exclude refunds (show gross spend)
    include_subscription       = true  # Include subscription charges
    include_support            = false # Exclude AWS Support charges
    include_tax                = false # Exclude tax (show pre-tax spend)
    include_upfront            = true  # Include upfront RI/Savings Plans payments
    use_blended                = false # Use unblended costs (actual rates, not averaged)
  }

  # ============================================================================
  # NOTIFICATION 1: 50% Threshold (Early Warning)
  # ============================================================================
  # Alerts when actual spend reaches 50% of monthly budget
  # This provides early warning to investigate unexpected costs

  notification {
    comparison_operator = "GREATER_THAN"
    threshold           = 50
    threshold_type      = "PERCENTAGE"
    notification_type   = "ACTUAL"

    # Delivery channels: SNS and/or email
    subscriber_sns_topic_arns  = [aws_sns_topic.budget_alerts[0].arn]
    subscriber_email_addresses = [var.billing_alert_email]
  }

  # ============================================================================
  # NOTIFICATION 2: 80% Threshold (Critical Warning)
  # ============================================================================
  # Alerts when actual spend reaches 80% of monthly budget
  # Time to take action to prevent exceeding budget

  notification {
    comparison_operator = "GREATER_THAN"
    threshold           = 80
    threshold_type      = "PERCENTAGE"
    notification_type   = "ACTUAL"

    subscriber_sns_topic_arns  = [aws_sns_topic.budget_alerts[0].arn]
    subscriber_email_addresses = [var.billing_alert_email]
  }

  # ============================================================================
  # NOTIFICATION 3: 100% Threshold (Budget Exceeded)
  # ============================================================================
  # Alerts when actual spend exceeds monthly budget
  # Immediate attention required

  notification {
    comparison_operator = "GREATER_THAN"
    threshold           = 100
    threshold_type      = "PERCENTAGE"
    notification_type   = "ACTUAL"

    subscriber_sns_topic_arns  = [aws_sns_topic.budget_alerts[0].arn]
    subscriber_email_addresses = [var.billing_alert_email]
  }

  # ============================================================================
  # NOTIFICATION 4: Forecasted 100% (Predictive Alert)
  # ============================================================================
  # Alerts when AWS forecasts you'll exceed budget by month-end
  # Based on current spending trends and historical patterns
  # Only alerts if forecasted spend > threshold

  dynamic "notification" {
    for_each = var.enable_forecasted_alert ? [1] : []

    content {
      comparison_operator = "GREATER_THAN"
      threshold           = 100
      threshold_type      = "PERCENTAGE"
      notification_type   = "FORECASTED"

      subscriber_sns_topic_arns  = [aws_sns_topic.budget_alerts[0].arn]
      subscriber_email_addresses = [var.billing_alert_email]
    }
  }

  # Ensure SNS topic and email subscription exist before creating budget
  depends_on = [
    aws_sns_topic.budget_alerts,
    aws_sns_topic_subscription.budget_email
  ]
}

# ============================================================================
# OPTIONAL: PROJECT-SPECIFIC BUDGET (TAG FILTERED)
# ============================================================================
# Uncomment to create a second budget that only tracks costs for resources
# tagged with Project=openarena. Useful in multi-project AWS accounts.
#
# PREREQUISITE: Activate cost allocation tag in Billing console:
# 1. Billing → Cost allocation tags
# 2. Activate "Project" tag
# 3. Wait 24 hours for tag data to appear
#
# resource "aws_budgets_budget" "project_specific" {
#   count = var.enable_cost_budgets ? 1 : 0
#
#   name         = "openarena-project-only"
#   budget_type  = "COST"
#   limit_amount = tostring(var.monthly_budget_usd)
#   limit_unit   = "USD"
#   time_unit    = "MONTHLY"
#
#   # Filter to only costs with Project=openarena tag
#   cost_filter {
#     name   = "TagKeyValue"
#     values = ["user:Project$openarena"]
#   }
#
#   cost_types {
#     include_credit    = false
#     include_discount  = true
#     include_tax       = false
#     use_blended       = false
#   }
#
#   notification {
#     comparison_operator        = "GREATER_THAN"
#     threshold                  = 80
#     threshold_type             = "PERCENTAGE"
#     notification_type          = "ACTUAL"
#     subscriber_sns_topic_arns  = [aws_sns_topic.budget_alerts[0].arn]
#     subscriber_email_addresses = [var.billing_alert_email]
#   }
# }

# ============================================================================
# OPTIONAL: EC2 USAGE BUDGET
# ============================================================================
# Track EC2 instance usage hours instead of costs
# Useful for ensuring you stay within free tier limits
#
# resource "aws_budgets_budget" "ec2_usage" {
#   name        = "openarena-ec2-hours"
#   budget_type = "USAGE"
#
#   # t2.micro free tier: 750 hours/month (1 instance running 24/7)
#   limit_amount = "750"
#   limit_unit   = "Hrs"
#
#   time_unit   = "MONTHLY"
#
#   # Filter to only EC2 t2.micro usage
#   cost_filter {
#     name   = "Service"
#     values = ["Amazon Elastic Compute Cloud - Compute"]
#   }
#
#   cost_filter {
#     name   = "UsageType"
#     values = ["BoxUsage:t2.micro"]
#   }
#
#   notification {
#     comparison_operator        = "GREATER_THAN"
#     threshold                  = 90
#     threshold_type             = "PERCENTAGE"
#     notification_type          = "ACTUAL"
#     subscriber_email_addresses = [var.billing_alert_email]
#   }
# }

# ============================================================================
# OPTIONAL: BUDGET ACTIONS (AUTOMATED RESPONSES)
# ============================================================================
# Budget actions automatically execute when threshold is exceeded
# Examples: Apply IAM policy to deny new resource creation, stop EC2 instances
#
# COST: $0.10 per action execution
# USE WITH CAUTION: Can disrupt production if misconfigured
#
# resource "aws_budgets_budget_action" "deny_new_resources" {
#   budget_name        = aws_budgets_budget.monthly_total[0].name
#   action_type        = "APPLY_IAM_POLICY"
#   approval_model     = "AUTOMATIC"  # or "MANUAL" for human approval
#   notification_type  = "ACTUAL"
#   execution_role_arn = aws_iam_role.budget_action[0].arn
#
#   action_threshold {
#     action_threshold_type  = "PERCENTAGE"
#     action_threshold_value = 100
#   }
#
#   definition {
#     iam_action_definition {
#       policy_arn = aws_iam_policy.deny_ec2_creation[0].arn
#       users      = []  # Apply to all IAM users
#       groups     = []  # Or specify specific groups
#       roles      = []  # Or specific roles
#     }
#   }
#
#   subscriber {
#     address           = var.billing_alert_email
#     subscription_type = "EMAIL"
#   }
# }

# ============================================================================
# OUTPUTS FOR BUDGETS
# ============================================================================

output "budget_name" {
  description = "Name of the monthly cost budget"
  value       = var.enable_cost_budgets ? aws_budgets_budget.monthly_total[0].name : null
}

output "budget_arn" {
  description = "ARN of the monthly cost budget"
  value       = var.enable_cost_budgets ? aws_budgets_budget.monthly_total[0].arn : null
}

output "budget_limit_amount" {
  description = "Budget limit amount in USD"
  value       = var.enable_cost_budgets ? var.monthly_budget_usd : null
}

# ============================================================================
# OPERATIONAL NOTES
# ============================================================================
# VERIFYING BUDGET SETUP:
#
# 1. Check AWS Budgets console:
#    Billing → Budgets → Should show "openarena-monthly-total"
#
# 2. Verify budget details:
#    - Budget amount: $15 (or your configured amount)
#    - Time period: Monthly
#    - Notifications: 3-4 configured (50%, 80%, 100% actual + 100% forecasted)
#
# 3. Check notification status:
#    - Email subscription must be confirmed
#    - SNS topic should be associated
#
# 4. Wait for first month to accumulate spending data
#    - Budget tracks from 1st of month to last day of month
#    - Historical data won't trigger alerts retroactively
#
# UNDERSTANDING BUDGET ALERTS:
#
# Alert Email Format:
# ---
# Subject: AWS Budget Alert - openarena-monthly-total
#
# Your budget "openarena-monthly-total" has exceeded 50% of your $15.00 budget.
#
# Current actual spend: $7.50
# Forecasted spend: $14.25
# Budget period: January 1 - January 31, 2024
#
# View details: [Link to Cost Explorer]
# ---
#
# FORECASTED ALERTS:
# - AWS uses ML to predict month-end spend based on:
#   * Current spending pattern
#   * Historical spending (if available)
#   * Day of month (more accurate as month progresses)
# - Forecast accuracy improves after first month of data
# - Early-month forecasts may be inaccurate (wait until mid-month)
#
# TROUBLESHOOTING:
#
# Issue: Not receiving budget alerts despite exceeding threshold
# Solutions:
# - Confirm SNS email subscription (check for confirmation email)
# - Verify budget is active (not expired or deleted)
# - Check budget cost filters (may be excluding your costs)
# - Verify costs are in same currency as budget (USD)
# - Wait up to 3 times per day (budget checks every 8 hours)
#
# Issue: Budget shows $0.00 spend but resources are running
# Solutions:
# - Wait 24 hours (budget data updates once per day)
# - Check cost allocation tags are activated (for tag-filtered budgets)
# - Verify cost types configuration includes your charges
# - Check if costs are in different region/account (multi-account org)
#
# Issue: Forecasted spend alert never triggers
# Solutions:
# - Need at least 5 days of spending data for forecast
# - Forecast only alerts if predicted to EXCEED threshold by month-end
# - If spending is steady and under budget, no forecast alert
#
# COST OPTIMIZATION WITH BUDGETS:
#
# 1. Set budget to your target spend (not maximum acceptable)
#    - Example: Target $10/month, set budget to $10
#    - Alerts at $5 (50%), $8 (80%), $10 (100%)
#
# 2. Create multiple budgets for different cost categories:
#    - Total account spend
#    - Project-specific spend (tag-filtered)
#    - Service-specific spend (EC2-only, S3-only)
#
# 3. Use forecasted alerts for proactive cost management:
#    - Get notified early if trending toward overspend
#    - Take action before month-end (scale down, optimize)
#
# 4. Review budget reports monthly:
#    - Identify spending trends
#    - Adjust budget limits as needed
#    - Optimize resources based on patterns
#
# COMPLIANCE AND GOVERNANCE:
#
# - Budgets provide cost visibility for financial governance
# - Use budget actions for automated spending controls (with caution)
# - Export budget data via Cost and Usage Reports (CUR) for audit
# - Set up budgets for each team/project in shared accounts
# - Implement budget approval workflow for new projects
#
# INTEGRATION WITH OTHER TOOLS:
#
# 1. Cost Explorer: Detailed cost analysis and filtering
# 2. Cost Anomaly Detection: ML-based spike detection (complementary)
# 3. CloudWatch Billing Alarms: Backup alerting mechanism
# 4. AWS Organizations: Consolidated billing and multi-account budgets
# 5. Savings Plans/Reserved Instances: Long-term cost reduction
# ============================================================================

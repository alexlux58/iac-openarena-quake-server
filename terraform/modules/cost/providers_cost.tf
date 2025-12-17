# ============================================================================
# Cost Module Provider Configuration
# ============================================================================
# This file configures an AWS provider alias specifically for us-east-1 region,
# which is required for billing-related resources.
#
# WHY US-EAST-1?
# AWS billing metrics (EstimatedCharges) are only published to CloudWatch in
# the us-east-1 region. Additionally, Cost and Usage Reports (CUR) are typically
# created in us-east-1 as a standard practice, though they can technically be
# created in other regions.
#
# USAGE:
# Resources that need to use this provider should reference it with:
#   provider = aws.use1
#
# DOCUMENTATION:
# - CloudWatch Billing Metrics: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/monitor_estimated_charges_with_cloudwatch.html
# - CUR Setup: https://docs.aws.amazon.com/cur/latest/userguide/what-is-cur.html
# ============================================================================

# AWS provider alias for us-east-1 region (required for billing resources)
provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}

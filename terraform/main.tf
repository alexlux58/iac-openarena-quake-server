# Root Module - OpenArena Infrastructure
# This is the main entry point for the Terraform configuration
# It instantiates the openarena module with variables from the root module

# Get current AWS account ID (used for S3 bucket naming)
data "aws_caller_identity" "current" {}

# Get current AWS region
data "aws_region" "current" {}

# ============================================================================
# OPENARENA MODULE - Game Server Infrastructure
# ============================================================================

module "openarena" {
  source = "./modules/openarena"

  # AWS Configuration
  aws_region          = var.aws_region
  instance_type       = var.instance_type
  ssh_key_name        = var.ssh_key_name
  create_key_pair     = var.create_key_pair
  ssh_public_key_file = var.ssh_public_key_file
  ssh_allowed_cidr    = var.ssh_allowed_cidr

  # Cloudflare Configuration
  cloudflare_zone_id   = var.cloudflare_zone_id
  cloudflare_zone_name = var.cloudflare_zone_name
  cloudflare_subdomain = var.cloudflare_subdomain
  cloudflare_ttl       = var.cloudflare_ttl

  # CloudWatch Logs Integration (optional)
  # Uncomment to attach IAM instance profile for CloudWatch Logs
  # iam_instance_profile = var.enable_cloudwatch_logs ? module.cost.cloudwatch_logs_instance_profile_name : null
}

# ============================================================================
# COST MODULE - Security Logging & Budget Monitoring
# ============================================================================

module "cost" {
  source = "./modules/cost"

  # S3 Bucket Names (must be globally unique)
  log_bucket_name     = var.log_bucket_name
  flowlog_bucket_name = var.flowlog_bucket_name
  cur_bucket_name     = var.cur_bucket_name

  # Cost Monitoring Configuration
  billing_alert_email   = var.billing_alert_email
  monthly_budget_usd    = var.monthly_budget_usd
  billing_alarm_usd     = var.billing_alarm_usd
  anomaly_threshold_usd = var.anomaly_threshold_usd

  # Feature Toggles (enable/disable for cost optimization)
  enable_cloudtrail             = var.enable_cloudtrail
  enable_guardduty              = var.enable_guardduty
  enable_vpc_flow_logs          = var.enable_vpc_flow_logs
  enable_cost_budgets           = var.enable_cost_budgets
  enable_cost_anomaly_detection = var.enable_cost_anomaly_detection
  enable_billing_alarm          = var.enable_billing_alarm
  enable_cur                    = var.enable_cur
  enable_cloudwatch_logs        = var.enable_cloudwatch_logs

  # VPC Configuration (uses default VPC)
  vpc_id = null # null = auto-detect default VPC

  # Common Tags
  common_tags = {
    Project     = "openarena"
    Environment = "production"
    ManagedBy   = "terraform"
    Owner       = "alexflux"
  }
}

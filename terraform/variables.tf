# Root Module Variables
# These variables are defined at the root level and passed to the openarena module

variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-west-2"
}

variable "instance_type" {
  description = "EC2 instance type (t2.micro is free tier eligible for accounts created before July 15, 2025)"
  type        = string
  default     = "t2.micro" # Free tier eligible instance type
}

variable "ssh_key_name" {
  description = "Name of the SSH key pair in AWS (must already exist unless create_key_pair is true)"
  type        = string
}

variable "create_key_pair" {
  description = "Whether to create a new SSH key pair in AWS (if true, requires ssh_public_key_file)"
  type        = bool
  default     = false
}

variable "ssh_public_key_file" {
  description = "Path to SSH public key file (required if create_key_pair is true)"
  type        = string
  default     = ""
}

variable "ssh_allowed_cidr" {
  description = "CIDR block allowed for SSH access (e.g., '203.0.113.10/32' for single IP, '0.0.0.0/0' for anywhere - not recommended)"
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token for DNS management. Leave empty to use CLOUDFLARE_API_TOKEN environment variable instead (recommended for security)"
  type        = string
  default     = ""
  sensitive   = true
  # Enterprise best practice: Use environment variable or secret management system
  # Set: export CLOUDFLARE_API_TOKEN="your-token"
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID where the DNS record will be created (optional - leave empty to skip Cloudflare DNS)"
  type        = string
  default     = ""
}

variable "cloudflare_zone_name" {
  description = "Cloudflare zone name (root domain, e.g., alexflux.com) (optional - leave empty to skip Cloudflare DNS)"
  type        = string
  default     = ""
}

variable "cloudflare_subdomain" {
  description = "Subdomain for the DNS record (e.g., 'quake' creates quake.alexflux.com)"
  type        = string
  default     = "quake"
}

variable "cloudflare_ttl" {
  description = "TTL (Time To Live) for the Cloudflare DNS record in seconds"
  type        = number
  default     = 300 # 5 minutes
}

# ============================================================================
# COST MODULE VARIABLES - Security Logging & Budget Monitoring
# ============================================================================

variable "log_bucket_name" {
  description = "S3 bucket name for audit logs (CloudTrail, GuardDuty). Must be globally unique. Recommended: include AWS account ID"
  type        = string
}

variable "flowlog_bucket_name" {
  description = "S3 bucket name for VPC Flow Logs. Must be globally unique."
  type        = string
}

variable "cur_bucket_name" {
  description = "S3 bucket name for Cost and Usage Reports. Must be globally unique."
  type        = string
}

variable "billing_alert_email" {
  description = "Email address for receiving budget alerts and cost notifications. YOU MUST CONFIRM SNS SUBSCRIPTION after deployment!"
  type        = string
}

variable "monthly_budget_usd" {
  description = "Monthly budget limit in USD. Alerts at 50%, 80%, 100% of this amount."
  type        = number
  default     = 15
}

variable "billing_alarm_usd" {
  description = "CloudWatch billing alarm threshold in USD (failsafe backup). Set higher than monthly_budget_usd."
  type        = number
  default     = 20
}

variable "anomaly_threshold_usd" {
  description = "Minimum dollar amount for cost anomaly alerts. Anomalies below this are ignored."
  type        = number
  default     = 5
}

# Feature Toggles - Enable/disable for cost optimization
variable "enable_cloudtrail" {
  description = "Enable CloudTrail for API activity logging. Recommended: true (first trail is FREE)"
  type        = bool
  default     = true
}

variable "enable_guardduty" {
  description = "Enable GuardDuty threat detection. Cost: $8-15/month (NO FREE TIER). Set to false to save money."
  type        = bool
  default     = false # Disabled by default for cost savings
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs for network analysis. Cost: $2-5/month. Set to false to save money."
  type        = bool
  default     = false # Disabled by default for cost savings
}

variable "enable_cost_budgets" {
  description = "Enable AWS Budgets for cost monitoring. Recommended: true (first 2 budgets are FREE)"
  type        = bool
  default     = true
}

variable "enable_cost_anomaly_detection" {
  description = "Enable ML-based cost anomaly detection. Recommended: true (FREE)"
  type        = bool
  default     = true
}

variable "enable_billing_alarm" {
  description = "Enable CloudWatch billing alarm failsafe. Recommended: true (first 10 alarms are FREE)"
  type        = bool
  default     = true
}

variable "enable_cur" {
  description = "Enable Cost and Usage Reports for detailed billing data. Recommended: true (FREE, only S3 storage costs)"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch Logs collection from EC2. Cost: $0.50-2/month. Set to false to save money."
  type        = bool
  default     = false # Disabled by default for cost savings
}

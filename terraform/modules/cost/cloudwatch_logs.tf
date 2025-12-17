# ============================================================================
# CloudWatch Logs Configuration for EC2 Instances
# ============================================================================
# This file configures CloudWatch Logs infrastructure for collecting OS-level
# logs from EC2 instances (auth logs, syslog, application logs).
#
# COMPONENTS:
# 1. CloudWatch Log Groups: Destinations for log streams
# 2. IAM Role: Allows EC2 instances to write to CloudWatch Logs
# 3. IAM Instance Profile: Attaches IAM role to EC2 instances
#
# AGENT INSTALLATION:
# The CloudWatch Agent must be installed on EC2 instances separately.
# This is handled by the Ansible role in ansible/roles/cloudwatch_agent/
#
# WHAT LOGS ARE COLLECTED:
# - /var/log/auth.log: SSH logins, sudo commands, authentication events
# - /var/log/syslog: System messages, kernel logs, service logs
# - Application logs: Game server logs, custom application logs
#
# WHY CLOUDWATCH LOGS:
# - Centralized logging (don't SSH to instances to view logs)
# - Retention policies (automatic cleanup of old logs)
# - Real-time monitoring and alerting
# - Compliance and audit trail
# - Correlation with CloudTrail (API calls) and VPC Flow Logs (network)
#
# COST:
# - Ingestion: $0.50 per GB
# - Storage: $0.03 per GB-month
# - Typical t2.micro: 10-50 MB/day (~$0.15-0.75/month)
#
# DOCUMENTATION:
# - CloudWatch Logs: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/WhatIsCloudWatchLogs.html
# - CloudWatch Agent: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Install-CloudWatch-Agent.html
# ============================================================================

# ============================================================================
# CLOUDWATCH LOG GROUPS
# ============================================================================
# Log groups are containers for log streams. Each EC2 instance creates its
# own log stream within the log group (named by instance ID).

# Auth log group: SSH logins, sudo commands, authentication events
resource "aws_cloudwatch_log_group" "auth" {
  count = var.enable_cloudwatch_logs ? 1 : 0

  name = lookup(var.cw_log_groups, "auth", "/openarena/ec2/auth")

  # Retention: How long to keep logs (days)
  # Options: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653, or 0 (never expire)
  # Shorter retention = lower cost, but less historical data
  retention_in_days = var.cw_log_group_retention_days

  # KMS encryption (optional, commented out for cost savings)
  # Enables encryption at rest for log data
  # kms_key_id = aws_kms_key.cloudwatch_logs[0].arn

  tags = merge(
    var.common_tags,
    {
      Name        = lookup(var.cw_log_groups, "auth", "/openarena/ec2/auth")
      Description = "Auth logs from EC2 instances (SSH, sudo, authentication)"
      LogType     = "auth"
      Service     = "cloudwatch-logs"
    }
  )
}

# Syslog group: System messages, kernel logs, service logs
resource "aws_cloudwatch_log_group" "syslog" {
  count = var.enable_cloudwatch_logs ? 1 : 0

  name              = lookup(var.cw_log_groups, "syslog", "/openarena/ec2/syslog")
  retention_in_days = var.cw_log_group_retention_days

  tags = merge(
    var.common_tags,
    {
      Name        = lookup(var.cw_log_groups, "syslog", "/openarena/ec2/syslog")
      Description = "Syslog from EC2 instances (system messages, service logs)"
      LogType     = "syslog"
      Service     = "cloudwatch-logs"
    }
  )
}

# Application log group: OpenArena game server logs
resource "aws_cloudwatch_log_group" "app" {
  count = var.enable_cloudwatch_logs ? 1 : 0

  name              = lookup(var.cw_log_groups, "app", "/openarena/ec2/app")
  retention_in_days = var.cw_log_group_retention_days

  tags = merge(
    var.common_tags,
    {
      Name        = lookup(var.cw_log_groups, "app", "/openarena/ec2/app")
      Description = "Application logs from OpenArena game server"
      LogType     = "application"
      Service     = "cloudwatch-logs"
    }
  )
}

# ============================================================================
# IAM ROLE FOR CLOUDWATCH LOGS
# ============================================================================
# EC2 instances need IAM permissions to write logs to CloudWatch Logs.
# This role grants the necessary permissions.

# IAM role that EC2 instances will assume
resource "aws_iam_role" "cloudwatch_logs" {
  count = var.enable_cloudwatch_logs ? 1 : 0

  name        = "openarena-cloudwatch-logs-role"
  description = "IAM role for EC2 instances to write logs to CloudWatch Logs"

  # Trust policy: Who can assume this role?
  # ec2.amazonaws.com = EC2 instances
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.common_tags,
    {
      Name        = "openarena-cloudwatch-logs-role"
      Description = "IAM role for EC2 CloudWatch Logs access"
      Service     = "iam"
    }
  )
}

# IAM policy: What permissions does this role have?
# Grants permission to create log streams and write log events
resource "aws_iam_role_policy" "cloudwatch_logs" {
  count = var.enable_cloudwatch_logs ? 1 : 0

  name = "cloudwatch-logs-policy"
  role = aws_iam_role.cloudwatch_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogsWrite"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",    # Create log group if doesn't exist
          "logs:CreateLogStream",   # Create log stream (one per instance)
          "logs:PutLogEvents",      # Write log events
          "logs:DescribeLogGroups", # List log groups
          "logs:DescribeLogStreams" # List log streams
        ]
        Resource = [
          "${aws_cloudwatch_log_group.auth[0].arn}*",
          "${aws_cloudwatch_log_group.syslog[0].arn}*",
          "${aws_cloudwatch_log_group.app[0].arn}*"
        ]
      }
    ]
  })
}

# IAM instance profile: Wrapper for IAM role (required by EC2)
# EC2 instances are launched with an instance profile, not directly with a role
resource "aws_iam_instance_profile" "cloudwatch_logs" {
  count = var.enable_cloudwatch_logs ? 1 : 0

  name = "openarena-cloudwatch-logs-profile"
  role = aws_iam_role.cloudwatch_logs[0].name

  tags = merge(
    var.common_tags,
    {
      Name        = "openarena-cloudwatch-logs-profile"
      Description = "Instance profile for EC2 CloudWatch Logs access"
      Service     = "iam"
    }
  )
}

# ============================================================================
# OUTPUTS FOR CLOUDWATCH LOGS
# ============================================================================

output "cloudwatch_log_group_arns" {
  description = "ARNs of CloudWatch Log Groups for EC2 instances"
  value = var.enable_cloudwatch_logs ? {
    auth   = aws_cloudwatch_log_group.auth[0].arn
    syslog = aws_cloudwatch_log_group.syslog[0].arn
    app    = aws_cloudwatch_log_group.app[0].arn
  } : null
}

output "cloudwatch_logs_iam_role_arn" {
  description = "ARN of IAM role for EC2 CloudWatch Logs access"
  value       = var.enable_cloudwatch_logs ? aws_iam_role.cloudwatch_logs[0].arn : null
}

output "cloudwatch_logs_instance_profile_name" {
  description = "Name of IAM instance profile for EC2 CloudWatch Logs access (attach this to EC2 instances)"
  value       = var.enable_cloudwatch_logs ? aws_iam_instance_profile.cloudwatch_logs[0].name : null
}

output "cloudwatch_logs_instance_profile_arn" {
  description = "ARN of IAM instance profile for EC2 CloudWatch Logs access"
  value       = var.enable_cloudwatch_logs ? aws_iam_instance_profile.cloudwatch_logs[0].arn : null
}

# ============================================================================
# OPERATIONAL NOTES
# ============================================================================
# SETUP STEPS:
#
# 1. Apply this Terraform configuration (creates log groups + IAM role)
# 2. Attach IAM instance profile to EC2 instances (update openarena module)
# 3. Install CloudWatch Agent on EC2 via Ansible (see ansible/roles/cloudwatch_agent/)
# 4. Configure agent to collect desired logs
# 5. Verify logs appear in CloudWatch Logs console
#
# ATTACHING IAM INSTANCE PROFILE TO EC2:
#
# In terraform/modules/openarena/main.tf, add to aws_instance resource:
#
# resource "aws_instance" "this" {
#   # ... existing configuration ...
#   iam_instance_profile = var.cloudwatch_logs_instance_profile_name
# }
#
# Pass the instance profile name from root module to openarena module.
#
# VIEWING LOGS IN AWS CONSOLE:
#
# 1. Go to CloudWatch → Log groups
# 2. Click on log group (e.g., /openarena/ec2/auth)
# 3. Click on log stream (named by instance ID, e.g., i-1234567890abcdef0)
# 4. View log events in chronological order
#
# QUERYING LOGS WITH CLOUDWATCH INSIGHTS:
#
# CloudWatch Logs Insights allows SQL-like queries on logs.
#
# Example 1: Find all SSH login attempts
# ```
# fields @timestamp, @message
# | filter @message like /sshd/
# | filter @message like /Accepted/
# | sort @timestamp desc
# | limit 20
# ```
#
# Example 2: Find sudo commands
# ```
# fields @timestamp, @message
# | filter @message like /sudo/
# | sort @timestamp desc
# ```
#
# Example 3: Count errors in syslog
# ```
# fields @timestamp
# | filter @message like /error|ERROR|Error/
# | stats count() by bin(5m)
# ```
#
# SETTING UP METRIC FILTERS:
#
# Metric filters extract metrics from log data for alerting.
#
# Example: Alert on failed SSH logins
# 1. Create metric filter on /openarena/ec2/auth log group
# 2. Filter pattern: [month, day, timestamp, ip, id, msg1= Invalid, msg2 = user, ...]
# 3. Create CloudWatch alarm on metric (threshold: 5 failed logins in 5 minutes)
# 4. Send notification to SNS topic
#
# COST OPTIMIZATION:
#
# 1. Adjust retention_in_days based on needs (shorter = cheaper)
# 2. Don't collect high-volume logs (e.g., debug logs)
# 3. Use log sampling if appropriate (not for auth/security logs)
# 4. Consider exporting old logs to S3 for cheaper long-term storage
# 5. Filter logs before sending (CloudWatch Agent supports filtering)
#
# COMPLIANCE NOTES:
#
# - Auth logs are critical for PCI-DSS, SOC2, HIPAA compliance
# - Retain auth logs for required period (90 days minimum, often 1 year+)
# - Enable encryption at rest for sensitive logs (use KMS)
# - Restrict CloudWatch Logs access with IAM policies
# - Export logs to immutable storage (S3 with versioning) for audit
# ============================================================================

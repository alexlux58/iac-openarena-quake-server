# ============================================================================
# AWS CloudTrail Configuration
# ============================================================================
# CloudTrail records AWS API calls made in your account, providing audit logs
# for security analysis, compliance, and operational troubleshooting.
#
# WHAT CLOUDTRAIL CAPTURES:
# - All API calls to AWS services (who, what, when, where, source IP)
# - Console sign-in events and failed login attempts
# - IAM credential usage (access keys, temporary credentials)
# - Resource modifications (create, update, delete operations)
# - Read-only operations (optional, requires data events configuration)
#
# WHY CLOUDTRAIL IS CRITICAL:
# - Security incident investigation (identify unauthorized access)
# - Compliance requirements (SOC2, PCI-DSS, HIPAA, etc.)
# - Change tracking (who modified what resource and when)
# - Troubleshooting (track down configuration changes that caused issues)
#
# CLOUDTRAIL CONCEPTS:
# - Management Events: API calls that modify AWS resources (free for 1st trail)
# - Data Events: S3 object-level or Lambda function invocations (paid)
# - Insights Events: Unusual API activity detection (paid, ML-based)
#
# COST CONSIDERATIONS:
# - First trail with management events: FREE
# - Additional trails: $2.00 per 100,000 management events
# - Data events: $0.10 per 100,000 events after free tier
# - S3 storage costs apply for log files
#
# SECURITY BEST PRACTICES:
# - Enable log file validation (detect tampering)
# - Use multi-region trail (capture all regions)
# - Enable MFA delete on S3 bucket (not configured here, manual step)
# - Monitor CloudTrail logs with CloudWatch alarms (separate configuration)
#
# DOCUMENTATION:
# - CloudTrail Overview: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-user-guide.html
# - S3 Bucket Policy: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/create-s3-bucket-policy-for-cloudtrail.html
# - Best Practices: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/best-practices-security.html
# ============================================================================

# ============================================================================
# CLOUDTRAIL S3 BUCKET POLICY
# ============================================================================
# CloudTrail requires specific S3 permissions to deliver logs:
# 1. GetBucketAcl - CloudTrail verifies it can access the bucket
# 2. PutObject - CloudTrail writes log files to the bucket
#
# This policy follows AWS documented requirements and security best practices.

# Policy document for CloudTrail S3 access
data "aws_iam_policy_document" "cloudtrail_s3_policy" {
  count = var.enable_cloudtrail ? 1 : 0

  # Statement 1: Allow CloudTrail to check bucket ACL
  # CloudTrail needs to verify it has permission to write to the bucket
  # This is required before CloudTrail will start delivering logs
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = [
      "s3:GetBucketAcl"
    ]

    resources = [
      aws_s3_bucket.log_bucket.arn
    ]

    # Prevent confused deputy attack: ensure request comes from our account
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  # Statement 2: Allow CloudTrail to write log files
  # CloudTrail writes logs to a specific path structure:
  # <prefix>/AWSLogs/<account-id>/CloudTrail/<region>/<year>/<month>/<day>/
  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = [
      "s3:PutObject"
    ]

    # Path where CloudTrail will write logs (account-specific)
    resources = [
      "${aws_s3_bucket.log_bucket.arn}/${trim(var.cloudtrail_prefix, "/")}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    ]

    # CloudTrail requires bucket-owner-full-control ACL for log files
    # This ensures the bucket owner (you) has full access to log files
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    # Prevent confused deputy attack
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

# ============================================================================
# CLOUDTRAIL TRAIL RESOURCE
# ============================================================================
# Creates the CloudTrail trail that captures API activity and delivers logs to S3.

resource "aws_cloudtrail" "main" {
  count = var.enable_cloudtrail ? 1 : 0

  # Trail name - visible in CloudTrail console
  name = "openarena-cloudtrail"

  # S3 destination configuration
  s3_bucket_name = aws_s3_bucket.log_bucket.id
  s3_key_prefix  = trim(var.cloudtrail_prefix, "/") # Remove leading/trailing slashes

  # MULTI-REGION TRAIL (recommended)
  # When enabled, CloudTrail logs events from ALL AWS regions in one trail
  # This is best practice for comprehensive security monitoring
  # Without this, you'd need separate trails for each region
  is_multi_region_trail = var.cloudtrail_multi_region

  # GLOBAL SERVICE EVENTS (IAM, STS, CloudFront, Route53)
  # Global services log to us-east-1 regardless of where API call originates
  # At least ONE trail in your account should have this enabled
  # Required for: IAM user/role changes, STS token generation, CloudFront access
  include_global_service_events = var.cloudtrail_include_global_service_events

  # LOG FILE VALIDATION (strongly recommended)
  # Creates a digital signature (SHA-256 hash with RSA) for each log file
  # Allows you to verify logs haven't been tampered with after delivery
  # Required for: Compliance (PCI-DSS, HIPAA), forensics, legal evidence
  # Validation: aws cloudtrail validate-logs --trail-arn <arn> --start-time <time>
  enable_log_file_validation = var.cloudtrail_enable_log_file_validation

  # Start logging immediately after trail creation
  # Set to false only if you want to configure the trail but not start logging yet
  enable_logging = var.cloudtrail_enable_logging

  # OPTIONAL: CloudWatch Logs integration (commented out, add if needed)
  # Sends CloudTrail logs to CloudWatch Logs for real-time monitoring/alerting
  # Requires additional IAM role for CloudTrail to write to CloudWatch
  #
  # cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail[0].arn}:*"
  # cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cloudwatch[0].arn

  # OPTIONAL: SNS topic for log file delivery notifications
  # CloudTrail sends SNS notification each time it delivers a log file
  # Useful for triggering Lambda functions or alerting on new logs
  #
  # sns_topic_name = aws_sns_topic.cloudtrail_logs[0].name

  # OPTIONAL: KMS encryption for CloudTrail logs (higher security)
  # By default, CloudTrail uses SSE-S3 (AES256)
  # KMS provides additional benefits: key rotation, audit trails, access control
  #
  # kms_key_id = aws_kms_key.cloudtrail[0].arn

  # OPTIONAL: Event selectors for data events (S3 object-level, Lambda invocations)
  # By default, CloudTrail only logs management events (control plane)
  # Data events capture data plane operations (S3 GetObject, Lambda Invoke)
  # WARNING: Data events can generate VERY high volume and costs
  #
  # event_selector {
  #   read_write_type           = "All"  # ReadOnly, WriteOnly, or All
  #   include_management_events = true
  #
  #   # S3 data events example: log all S3 object operations
  #   data_resource {
  #     type   = "AWS::S3::Object"
  #     values = ["arn:aws:s3:::${aws_s3_bucket.log_bucket.id}/*"]
  #   }
  #
  #   # Lambda data events example: log all Lambda invocations
  #   data_resource {
  #     type   = "AWS::Lambda::Function"
  #     values = ["arn:aws:lambda:*:${data.aws_caller_identity.current.account_id}:function/*"]
  #   }
  # }

  # OPTIONAL: Insights events for anomaly detection
  # Uses ML to detect unusual API activity (spike in DeleteBucket calls, etc.)
  # Cost: $0.35 per 100,000 events analyzed
  #
  # insight_selector {
  #   insight_type = "ApiCallRateInsight"  # Currently only option
  # }

  # Tags for cost allocation and management
  tags = merge(
    var.common_tags,
    {
      Name        = "openarena-cloudtrail"
      Description = "Multi-region CloudTrail for API activity audit logging"
      Service     = "cloudtrail"
    }
  )

  # Ensure S3 bucket and bucket policy exist before creating trail
  # CloudTrail validates S3 permissions during trail creation
  depends_on = [
    aws_s3_bucket_policy.cloudtrail_policy
  ]
}

# ============================================================================
# CLOUDTRAIL S3 BUCKET POLICY ATTACHMENT
# ============================================================================
# Attaches the CloudTrail policy to the audit logs S3 bucket.
# This must be created separately from the GuardDuty policy and then merged.

resource "aws_s3_bucket_policy" "cloudtrail_policy" {
  count = var.enable_cloudtrail ? 1 : 0

  bucket = aws_s3_bucket.log_bucket.id
  policy = data.aws_iam_policy_document.cloudtrail_s3_policy[0].json

  # Ensure public access block is applied before bucket policy
  # This prevents a race condition where policy might temporarily allow public access
  depends_on = [
    aws_s3_bucket_public_access_block.log_bucket
  ]
}

# ============================================================================
# OUTPUTS FOR CLOUDTRAIL
# ============================================================================
# Expose CloudTrail trail ARN and S3 location for use in other modules

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail trail for API activity logging"
  value       = var.enable_cloudtrail ? aws_cloudtrail.main[0].arn : null
}

output "cloudtrail_id" {
  description = "Name/ID of the CloudTrail trail"
  value       = var.enable_cloudtrail ? aws_cloudtrail.main[0].id : null
}

output "cloudtrail_home_region" {
  description = "Region where the CloudTrail trail was created"
  value       = var.enable_cloudtrail ? aws_cloudtrail.main[0].home_region : null
}

output "cloudtrail_s3_location" {
  description = "S3 bucket and prefix where CloudTrail logs are stored"
  value       = var.enable_cloudtrail ? "s3://${aws_s3_bucket.log_bucket.id}/${var.cloudtrail_prefix}" : null
}

# ============================================================================
# OPERATIONAL NOTES
# ============================================================================
# VERIFICATION AFTER DEPLOYMENT:
# 1. Check CloudTrail console: Trail should show "Logging: ON"
# 2. Wait 15 minutes for first log delivery
# 3. Check S3: s3://<bucket>/<prefix>/AWSLogs/<account-id>/CloudTrail/
# 4. Validate logs: aws cloudtrail validate-logs --trail-arn <arn> --start-time <time>
#
# COMMON ISSUES:
# - "Insufficient permissions": Check S3 bucket policy matches CloudTrail requirements
# - "No logs appearing": Wait 15 minutes, check if trail is enabled, verify S3 bucket name
# - "AccessDenied on validation": Ensure log file validation was enabled at trail creation
#
# COST MONITORING:
# - Monitor S3 storage costs in Cost Explorer
# - First trail with management events is free
# - Additional trails: $2.00 per 100,000 management events
#
# SECURITY RECOMMENDATIONS:
# 1. Enable MFA Delete on S3 bucket (manual step, not in Terraform):
#    aws s3api put-bucket-versioning --bucket <bucket> --versioning-configuration \
#      Status=Enabled,MFADelete=Enabled --mfa "arn:aws:iam::123456789012:mfa/root-account-mfa-device 123456"
#
# 2. Set up CloudWatch alarms for critical events:
#    - Root account usage
#    - Failed console login attempts (>5 in 5 minutes)
#    - IAM policy changes
#    - Security group changes
#    - S3 bucket policy changes
#
# 3. Consider enabling CloudTrail Insights for anomaly detection
#
# 4. Regularly review logs with AWS Athena queries or CloudWatch Insights
# ============================================================================

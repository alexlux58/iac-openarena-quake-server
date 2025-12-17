# ============================================================================
# S3 Buckets for Security Logs and Cost Reports
# ============================================================================
# This file creates three S3 buckets with comprehensive security configurations:
# 1. Audit logs bucket (CloudTrail, GuardDuty, CloudWatch Logs archives)
# 2. VPC Flow Logs bucket (separate to avoid policy conflicts)
# 3. Cost and Usage Reports (CUR) bucket
#
# SECURITY BEST PRACTICES IMPLEMENTED:
# - Public access blocked at bucket level (prevents accidental exposure)
# - Versioning enabled (protects against accidental deletion/modification)
# - Server-side encryption at rest (AES256 for most, KMS for GuardDuty)
# - Lifecycle policies for cost optimization (optional, commented out)
# - Bucket ownership controls (BucketOwnerEnforced for simplified ACL management)
#
# WHY SEPARATE BUCKETS?
# - VPC Flow Logs auto-manages bucket policies and can conflict with CloudTrail policies
# - CUR has specific policy requirements from billingreports.amazonaws.com
# - Separation simplifies IAM management and troubleshooting
#
# COST OPTIMIZATION:
# - Enable lifecycle policies (commented below) to transition old logs to cheaper storage
# - Consider S3 Intelligent-Tiering for automatic cost optimization
#
# DOCUMENTATION:
# - S3 Security Best Practices: https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html
# - CloudTrail S3 Requirements: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/create-s3-bucket-policy-for-cloudtrail.html
# - VPC Flow Logs S3: https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs-s3.html
# ============================================================================

# Get current AWS account ID for bucket policies and resource naming
data "aws_caller_identity" "current" {}

# Get current AWS region for regional resource naming
data "aws_region" "current" {}

# ============================================================================
# AUDIT LOGS BUCKET
# ============================================================================
# Primary bucket for CloudTrail logs, GuardDuty findings, and CloudWatch Logs
# archives. This bucket will store critical security audit information.

resource "aws_s3_bucket" "log_bucket" {
  bucket = var.log_bucket_name

  # force_destroy controls whether Terraform can delete a non-empty bucket
  # SECURITY WARNING: Setting this to 'true' in production risks data loss
  # Only enable for dev/test environments where data is not critical
  force_destroy = var.s3_bucket_force_destroy

  tags = merge(
    var.common_tags,
    {
      Name    = var.log_bucket_name
      LogType = "audit"
      Service = "s3"
    }
  )
}

# Block all public access to the audit logs bucket
# This is a critical security control that prevents accidental exposure of logs
# Even if a bucket policy or ACL allows public access, this setting overrides it
resource "aws_s3_bucket_public_access_block" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  # Block public ACLs (prevents granting public access via ACLs)
  block_public_acls = true

  # Block public bucket policies (prevents bucket policies from granting public access)
  block_public_policy = true

  # Ignore existing public ACLs (treats existing public ACLs as private)
  ignore_public_acls = true

  # Restrict public buckets (blocks public and cross-account access to buckets with public policies)
  restrict_public_buckets = true
}

# Enable versioning to protect against accidental deletion or overwrites
# Versioning stores all versions of an object (including delete markers)
# This is important for compliance and allows recovery from accidental changes
# COST NOTE: Versioning increases storage costs as it retains all versions
resource "aws_s3_bucket_versioning" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption at rest using AES256 (SSE-S3)
# All objects stored in this bucket will be automatically encrypted
# AES256 is AWS-managed encryption (no KMS key management overhead)
# For higher security requirements, consider using KMS encryption instead
resource "aws_s3_bucket_server_side_encryption_configuration" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    # Enforce encryption for all objects (rejects unencrypted uploads)
    bucket_key_enabled = true
  }
}

# Enforce bucket owner full control over objects
# This simplifies ACL management by ensuring the bucket owner always has full control
# Recommended by AWS as a best practice for security and management simplicity
resource "aws_s3_bucket_ownership_controls" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# OPTIONAL: Lifecycle policy for cost optimization
# Uncomment and customize this block to automatically transition logs to cheaper storage tiers
# Example: Move logs older than 90 days to Glacier, delete after 1 year
#
# resource "aws_s3_bucket_lifecycle_configuration" "log_bucket" {
#   bucket = aws_s3_bucket.log_bucket.id
#
#   rule {
#     id     = "transition-old-logs"
#     status = "Enabled"
#
#     # Transition current versions to S3 Standard-IA (Infrequent Access) after 30 days
#     transition {
#       days          = 30
#       storage_class = "STANDARD_IA"
#     }
#
#     # Transition current versions to Glacier after 90 days
#     transition {
#       days          = 90
#       storage_class = "GLACIER"
#     }
#
#     # Permanently delete current versions after 365 days (1 year retention)
#     expiration {
#       days = 365
#     }
#
#     # Also apply to previous versions (from versioning)
#     noncurrent_version_transition {
#       noncurrent_days = 30
#       storage_class   = "STANDARD_IA"
#     }
#
#     noncurrent_version_expiration {
#       noncurrent_days = 90
#     }
#   }
# }

# ============================================================================
# VPC FLOW LOGS BUCKET
# ============================================================================
# Dedicated bucket for VPC Flow Logs to avoid policy conflicts with CloudTrail.
# VPC Flow Logs service automatically creates and manages bucket policies.

resource "aws_s3_bucket" "flowlog_bucket" {
  bucket        = var.flowlog_bucket_name
  force_destroy = var.s3_bucket_force_destroy

  tags = merge(
    var.common_tags,
    {
      Name        = var.flowlog_bucket_name
      Description = "VPC Flow Logs storage for network traffic analysis"
      LogType     = "vpc-flow"
    }
  )
}

# Block all public access to VPC Flow Logs bucket
resource "aws_s3_bucket_public_access_block" "flowlog_bucket" {
  bucket = aws_s3_bucket.flowlog_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for VPC Flow Logs bucket
resource "aws_s3_bucket_versioning" "flowlog_bucket" {
  bucket = aws_s3_bucket.flowlog_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption for VPC Flow Logs
resource "aws_s3_bucket_server_side_encryption_configuration" "flowlog_bucket" {
  bucket = aws_s3_bucket.flowlog_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Enforce bucket owner control for VPC Flow Logs
resource "aws_s3_bucket_ownership_controls" "flowlog_bucket" {
  bucket = aws_s3_bucket.flowlog_bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# OPTIONAL: Lifecycle policy for VPC Flow Logs
# Flow logs can generate significant data volume, especially with ALL traffic type
# Consider aggressive lifecycle policies to control costs
#
# resource "aws_s3_bucket_lifecycle_configuration" "flowlog_bucket" {
#   bucket = aws_s3_bucket.flowlog_bucket.id
#
#   rule {
#     id     = "expire-old-flow-logs"
#     status = "Enabled"
#
#     # Flow logs are typically only needed for recent analysis
#     # Transition to cheaper storage quickly
#     transition {
#       days          = 7
#       storage_class = "STANDARD_IA"
#     }
#
#     transition {
#       days          = 30
#       storage_class = "GLACIER"
#     }
#
#     # Delete flow logs after 90 days (adjust based on compliance requirements)
#     expiration {
#       days = 90
#     }
#   }
# }

# ============================================================================
# COST AND USAGE REPORTS (CUR) BUCKET
# ============================================================================
# Dedicated bucket for AWS Cost and Usage Reports. CUR provides the most
# detailed billing data available for analysis with Athena/QuickSight.

resource "aws_s3_bucket" "cur_bucket" {
  bucket        = var.cur_bucket_name
  force_destroy = var.s3_bucket_force_destroy

  tags = merge(
    var.common_tags,
    {
      Name        = var.cur_bucket_name
      Description = "Cost and Usage Reports for detailed billing analysis"
      LogType     = "billing"
    }
  )
}

# Block all public access to CUR bucket
resource "aws_s3_bucket_public_access_block" "cur_bucket" {
  bucket = aws_s3_bucket.cur_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for CUR bucket
resource "aws_s3_bucket_versioning" "cur_bucket" {
  bucket = aws_s3_bucket.cur_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption for CUR data
resource "aws_s3_bucket_server_side_encryption_configuration" "cur_bucket" {
  bucket = aws_s3_bucket.cur_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Enforce bucket owner control for CUR bucket
resource "aws_s3_bucket_ownership_controls" "cur_bucket" {
  bucket = aws_s3_bucket.cur_bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# CUR bucket policy to allow AWS Billing service to write reports
# This policy grants billingreports.amazonaws.com permission to:
# 1. Check bucket ACL and policy (required for validation)
# 2. Write report objects to the bucket
#
# SECURITY NOTES:
# - Uses aws:SourceAccount condition to prevent confused deputy attacks
# - Only allows PutObject, not DeleteObject (reports can't be deleted by service)
# - Scoped to specific account ID for additional security
data "aws_iam_policy_document" "cur_bucket_policy" {
  # Allow AWS Billing service to check bucket permissions
  statement {
    sid    = "AWSBillingReportsAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["billingreports.amazonaws.com"]
    }

    actions = [
      "s3:GetBucketAcl",
      "s3:GetBucketPolicy"
    ]

    resources = [aws_s3_bucket.cur_bucket.arn]

    # Prevent confused deputy attack by validating source account
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    # Additional security: validate the source ARN matches expected format
    condition {
      test     = "StringLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:cur:us-east-1:${data.aws_caller_identity.current.account_id}:definition/*"]
    }
  }

  # Allow AWS Billing service to write report objects
  statement {
    sid    = "AWSBillingReportsWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["billingreports.amazonaws.com"]
    }

    actions = [
      "s3:PutObject"
    ]

    resources = ["${aws_s3_bucket.cur_bucket.arn}/*"]

    # Security conditions to prevent confused deputy attack
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "StringLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:cur:us-east-1:${data.aws_caller_identity.current.account_id}:definition/*"]
    }
  }
}

# Attach the policy to the CUR bucket
resource "aws_s3_bucket_policy" "cur_bucket" {
  bucket = aws_s3_bucket.cur_bucket.id
  policy = data.aws_iam_policy_document.cur_bucket_policy.json

  # Ensure public access block is created before applying policy
  depends_on = [aws_s3_bucket_public_access_block.cur_bucket]
}

# OPTIONAL: Lifecycle policy for CUR data
# CUR generates new reports periodically and can accumulate significant data
# Consider retaining based on your audit/compliance requirements
#
# resource "aws_s3_bucket_lifecycle_configuration" "cur_bucket" {
#   bucket = aws_s3_bucket.cur_bucket.id
#
#   rule {
#     id     = "expire-old-cur-reports"
#     status = "Enabled"
#
#     # Keep detailed hourly reports for 90 days, then transition
#     transition {
#       days          = 90
#       storage_class = "GLACIER"
#     }
#
#     # Delete reports after 1 year (adjust based on compliance requirements)
#     expiration {
#       days = 365
#     }
#   }
# }

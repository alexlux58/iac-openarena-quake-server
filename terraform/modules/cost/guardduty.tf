# ============================================================================
# AWS GuardDuty Configuration
# ============================================================================
# GuardDuty is an intelligent threat detection service that continuously
# monitors for malicious activity and unauthorized behavior in your AWS account.
#
# WHAT GUARDDUTY ANALYZES:
# - CloudTrail management and data events (API calls, unusual patterns)
# - VPC Flow Logs (network traffic, port scanning, crypto mining)
# - DNS query logs (command-and-control communications, DGA domains)
# - S3 data events (suspicious access patterns, data exfiltration)
# - EKS audit logs (Kubernetes API calls, container compromises)
# - RDS login activity (brute force attacks, suspicious database access)
#
# DETECTION CATEGORIES:
# - Reconnaissance: Port scanning, unusual API enumeration
# - Instance compromise: Malware, crypto mining, backdoors
# - Account compromise: Stolen credentials, unusual console logins
# - Bucket compromise: Suspicious S3 access patterns, data exfiltration
# - Malware: Execution detection, command-and-control communication
#
# FINDINGS SEVERITY LEVELS:
# - Low (0.1-3.9): Suspicious but low-impact activity
# - Medium (4.0-6.9): Moderately suspicious, investigate promptly
# - High (7.0-8.9): Highly suspicious, investigate immediately
# - Critical (9.0-10.0): Critical threat, respond immediately
#
# COST STRUCTURE:
# - CloudTrail analysis: $4.80 per million events (first 1M free)
# - VPC Flow Logs analysis: $1.18 per GB (first 500GB free)
# - DNS Logs analysis: $0.40 per million events (first 1M free)
# - S3 Protection: $0.80 per million S3 events (not enabled by default)
# - EKS Protection: $0.012 per pod-hour (not enabled by default)
# - Malware Protection: $1.00 per GB scanned (not enabled by default)
#
# IMPORTANT: GuardDuty has NO FREE TIER (except initial 30-day trial)
# Typical cost for small workload: $5-15/month
#
# DOCUMENTATION:
# - GuardDuty User Guide: https://docs.aws.amazon.com/guardduty/latest/ug/what-is-guardduty.html
# - Findings Types: https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_finding-types-active.html
# - Best Practices: https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_best-practices.html
# - Export Findings: https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_exportfindings.html
# ============================================================================

# ============================================================================
# KMS KEY FOR GUARDDUTY FINDINGS ENCRYPTION
# ============================================================================
# GuardDuty findings exported to S3 must be encrypted with a customer-managed
# KMS key (CMK). SSE-S3 (AES256) encryption is not supported for findings export.
#
# WHY KMS FOR GUARDDUTY:
# - Additional security layer with key rotation
# - Audit trail of all key usage in CloudTrail
# - Granular access control (who can decrypt findings)
# - Required for GuardDuty S3 export (service limitation)

# Create KMS key for GuardDuty findings encryption
resource "aws_kms_key" "guardduty" {
  count = var.enable_guardduty ? 1 : 0

  description = "KMS key for encrypting GuardDuty findings exported to S3"

  # Enable automatic key rotation (recommended security best practice)
  # AWS rotates the key material every year while keeping the same key ID
  # Old key material is retained for decrypting previously encrypted data
  enable_key_rotation = true

  # Key deletion window (7-30 days)
  # Provides time to recover from accidental key deletion
  # Key enters "pending deletion" state and can be canceled during this window
  deletion_window_in_days = var.kms_key_deletion_window

  # Key policy: defines who can use and manage the key
  # This policy grants:
  # 1. Root account full access (required for key management)
  # 2. GuardDuty service permission to decrypt/generate data keys
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow GuardDuty to use the key"
        Effect = "Allow"
        Principal = {
          Service = "guardduty.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

  tags = merge(
    var.common_tags,
    {
      Name        = "guardduty-findings-key"
      Description = "KMS key for GuardDuty findings encryption"
      Service     = "guardduty"
    }
  )
}

# Create a user-friendly alias for the KMS key
# Aliases make it easier to identify and use keys in the console and CLI
# Format: alias/<name>
resource "aws_kms_alias" "guardduty" {
  count = var.enable_guardduty ? 1 : 0

  name          = "alias/guardduty-findings"
  target_key_id = aws_kms_key.guardduty[0].key_id
}

# ============================================================================
# GUARDDUTY DETECTOR
# ============================================================================
# The detector is the primary GuardDuty resource that enables threat monitoring
# in the current region. Each region needs its own detector.

resource "aws_guardduty_detector" "main" {
  count = var.enable_guardduty ? 1 : 0

  # Enable GuardDuty monitoring immediately
  enable = true

  # Findings publishing frequency: how often GuardDuty exports findings to S3
  # Options: FIFTEEN_MINUTES, ONE_HOUR (default), SIX_HOURS
  # More frequent exports = higher S3 costs but faster threat visibility
  finding_publishing_frequency = var.guardduty_finding_publishing_frequency

  # S3 Protection: monitors S3 data events for suspicious access patterns
  # Detects: unusual download patterns, anonymous access, data exfiltration
  # Cost: $0.80 per million S3 events analyzed
  # Only enable if you store sensitive data in S3
  datasources {
    s3_logs {
      enable = var.guardduty_enable_s3_protection
    }

    # Kubernetes Protection: monitors EKS audit logs
    # Only relevant if using EKS (not applicable to OpenArena EC2 deployment)
    kubernetes {
      audit_logs {
        enable = var.guardduty_enable_kubernetes_protection
      }
    }

    # Malware Protection: scans EBS volumes for malware when suspicious activity detected
    # Cost: $1.00 per GB scanned
    # Only enable if you need malware detection on EC2 instances
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = var.guardduty_enable_malware_protection
        }
      }
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "openarena-guardduty-detector"
      Description = "GuardDuty threat detection for OpenArena infrastructure"
      Service     = "guardduty"
    }
  )
}

# ============================================================================
# GUARDDUTY S3 BUCKET POLICY
# ============================================================================
# GuardDuty requires specific S3 permissions to export findings:
# 1. GetBucketLocation - verify bucket accessibility
# 2. PutObject - write findings files

data "aws_iam_policy_document" "guardduty_s3_policy" {
  count = var.enable_guardduty ? 1 : 0

  # Allow GuardDuty to check bucket location
  statement {
    sid    = "AllowGuardDutyGetBucketLocation"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["guardduty.amazonaws.com"]
    }

    actions = [
      "s3:GetBucketLocation"
    ]

    resources = [
      aws_s3_bucket.log_bucket.arn
    ]

    # Prevent confused deputy attack
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  # Allow GuardDuty to write findings objects
  statement {
    sid    = "AllowGuardDutyPutObject"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["guardduty.amazonaws.com"]
    }

    actions = [
      "s3:PutObject"
    ]

    # GuardDuty creates findings in: <prefix>/<detector-id>/<year>/<month>/<day>/<hour>/
    resources = [
      "${aws_s3_bucket.log_bucket.arn}/${trim(var.guardduty_export_prefix, "/")}/*"
    ]

    # Prevent confused deputy attack
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  # Allow GuardDuty to use KMS key for encryption
  # This statement is needed if the S3 bucket uses default encryption
  statement {
    sid    = "AllowGuardDutyGetBucketAcl"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["guardduty.amazonaws.com"]
    }

    actions = [
      "s3:GetBucketAcl"
    ]

    resources = [
      aws_s3_bucket.log_bucket.arn
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

# ============================================================================
# COMBINED BUCKET POLICY (CLOUDTRAIL + GUARDDUTY)
# ============================================================================
# Merge CloudTrail and GuardDuty policies into a single bucket policy
# S3 buckets can only have ONE bucket policy, so we must combine them

data "aws_iam_policy_document" "log_bucket_combined" {
  # Include CloudTrail policy if enabled
  source_policy_documents = compact([
    var.enable_cloudtrail ? data.aws_iam_policy_document.cloudtrail_s3_policy[0].json : null,
    var.enable_guardduty ? data.aws_iam_policy_document.guardduty_s3_policy[0].json : null
  ])
}

# Apply the combined policy to the log bucket
resource "aws_s3_bucket_policy" "log_bucket_combined" {
  bucket = aws_s3_bucket.log_bucket.id
  policy = data.aws_iam_policy_document.log_bucket_combined.json

  depends_on = [
    aws_s3_bucket_public_access_block.log_bucket
  ]
}

# ============================================================================
# GUARDDUTY FINDINGS EXPORT CONFIGURATION
# ============================================================================
# Publishing destination configures GuardDuty to continuously export findings to S3.
# Findings are exported in JSON format, organized by date and time.
#
# EXPORT FORMAT:
# s3://<bucket>/<prefix>/<detector-id>/<year>/<month>/<day>/<hour>/<findings>.jsonl
#
# IMPORTANT NOTES:
# - Findings are exported in JSONL format (one JSON object per line)
# - Export frequency is controlled by finding_publishing_frequency
# - Exported findings include full details (resources, network, actor, etc.)
# - Findings in S3 are KMS-encrypted (required by GuardDuty)

resource "aws_guardduty_publishing_destination" "s3" {
  count = var.enable_guardduty ? 1 : 0

  # Reference to the GuardDuty detector
  detector_id = aws_guardduty_detector.main[0].id

  # S3 destination configuration
  # GuardDuty requires the full ARN including the prefix
  destination_arn = "arn:aws:s3:::${aws_s3_bucket.log_bucket.id}/${trim(var.guardduty_export_prefix, "/")}"

  # KMS key for encrypting exported findings (required)
  kms_key_arn = aws_kms_key.guardduty[0].arn

  # Ensure dependencies are created first
  # GuardDuty validates S3 and KMS permissions during creation
  depends_on = [
    aws_s3_bucket_policy.log_bucket_combined,
    aws_kms_key.guardduty
  ]
}

# ============================================================================
# OUTPUTS FOR GUARDDUTY
# ============================================================================

output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector for threat monitoring"
  value       = var.enable_guardduty ? aws_guardduty_detector.main[0].id : null
}

output "guardduty_detector_arn" {
  description = "ARN of the GuardDuty detector"
  value       = var.enable_guardduty ? aws_guardduty_detector.main[0].arn : null
}

output "guardduty_kms_key_id" {
  description = "ID of the KMS key used for GuardDuty findings encryption"
  value       = var.enable_guardduty ? aws_kms_key.guardduty[0].key_id : null
}

output "guardduty_kms_key_arn" {
  description = "ARN of the KMS key used for GuardDuty findings encryption"
  value       = var.enable_guardduty ? aws_kms_key.guardduty[0].arn : null
}

output "guardduty_s3_location" {
  description = "S3 location where GuardDuty findings are exported"
  value       = var.enable_guardduty ? "s3://${aws_s3_bucket.log_bucket.id}/${var.guardduty_export_prefix}" : null
}

# ============================================================================
# OPERATIONAL NOTES
# ============================================================================
# VERIFICATION AFTER DEPLOYMENT:
# 1. Check GuardDuty console: Detector should show "Enabled"
# 2. Wait for findings (may take 24-48 hours for meaningful detections)
# 3. Check S3 for exported findings (export frequency dependent)
# 4. Test with GuardDuty sample findings:
#    aws guardduty create-sample-findings --detector-id <id> --finding-types <type>
#
# VIEWING FINDINGS:
# - Console: GuardDuty → Findings (real-time view)
# - S3: Download JSONL files and parse (historical view)
# - CloudWatch Events: Set up EventBridge rules for automated response
#
# COMMON FINDINGS TO EXPECT:
# - Reconnaissance:PortProbing: Port scanning detected
# - UnauthorizedAccess:EC2/SSHBruteForce: SSH brute force attempts
# - CryptoCurrency:EC2/BitcoinTool: Crypto mining detection
# - Backdoor:EC2/C&CActivity: Command and control communication
# - Trojan:EC2/DNSDataExfiltration: DNS tunneling for data theft
#
# RESPONDING TO FINDINGS:
# 1. Review finding details in console (severity, resources, actor)
# 2. Investigate CloudTrail logs for related API activity
# 3. Check VPC Flow Logs for network connections
# 4. Isolate compromised instance (change security groups)
# 5. Snapshot EBS volumes for forensics
# 6. Terminate and replace compromised instance
# 7. Rotate credentials if compromise suspected
#
# COST MONITORING:
# - Monitor GuardDuty costs in Cost Explorer (service: "GuardDuty")
# - Typical small workload cost: $5-15/month
# - S3 Protection can increase costs significantly if high S3 activity
#
# INTEGRATION RECOMMENDATIONS:
# 1. Set up EventBridge rules for high-severity findings:
#    - Send to SNS for email alerts
#    - Trigger Lambda for automated response (isolate instance, etc.)
#    - Forward to SIEM (Splunk, Sumo Logic, etc.)
#
# 2. Create CloudWatch dashboard for GuardDuty metrics:
#    - Finding count by severity
#    - Finding count by type
#    - Most targeted resources
#
# 3. Enable GuardDuty in all regions (this only enables current region):
#    - Use AWS Organizations for centralized management
#    - Designate delegated administrator account
#    - Auto-enable for new accounts
# ============================================================================

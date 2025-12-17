# ============================================================================
# AWS Cost and Usage Report (CUR) Configuration
# ============================================================================
# Cost and Usage Reports (CUR) provide the most comprehensive billing data
# available from AWS. CUR is the foundation for detailed cost analysis,
# chargeback/showback, and integration with business intelligence tools.
#
# WHAT CUR PROVIDES:
# - Line-item details for every AWS charge
# - Resource-level cost attribution with tags
# - Pricing, usage quantity, and discount information
# - Reservation and Savings Plans utilization/coverage
# - Amortized and blended cost views
# - Cost allocation tag data
# - Resource IDs and metadata
#
# CUR VS OTHER COST TOOLS:
# - Cost Explorer: GUI for ad-hoc analysis (data from CUR)
# - AWS Budgets: Threshold monitoring (uses Cost Explorer data)
# - Billing Dashboard: Current month summary (uses CUR data)
# - CUR: Raw detailed data export for custom analysis
#
# COMMON USE CASES:
# - Athena queries for cost analysis ("show me all costs by project")
# - QuickSight dashboards for visualizations
# - Data warehouse integration (Redshift, Snowflake)
# - Custom billing applications
# - Chargeback to departments/projects
# - Compliance and audit trail
#
# TIME GRANULARITIES:
# - HOURLY: Most detailed, hourly usage/cost breakdown (recommended)
# - DAILY: Daily aggregation (smaller files, less detail)
# - MONTHLY: Monthly summary (smallest files, least detail)
#
# FILE FORMATS:
# - textORcsv: Standard CSV format (human-readable, widely compatible)
# - Parquet: Columnar format optimized for analytics (Athena/Redshift)
#
# COST: CUR itself is FREE
# - S3 storage costs apply (~$1-5/month for typical usage)
# - Athena query costs if analyzing with Athena (~$5/TB scanned)
#
# DOCUMENTATION:
# - CUR User Guide: https://docs.aws.amazon.com/cur/latest/userguide/what-is-cur.html
# - Data Dictionary: https://docs.aws.amazon.com/cur/latest/userguide/data-dictionary.html
# - Querying with Athena: https://docs.aws.amazon.com/cur/latest/userguide/cur-query-athena.html
# - Best Practices: https://docs.aws.amazon.com/cur/latest/userguide/bp.html
# ============================================================================

# ============================================================================
# COST AND USAGE REPORT DEFINITION
# ============================================================================
# Defines the CUR report configuration and delivery settings.

resource "aws_cur_report_definition" "main" {
  count = var.enable_cur ? 1 : 0

  # IMPORTANT: CUR resources must be created in us-east-1
  # This is an AWS service limitation (CUR service is region-specific)
  provider = aws.use1

  # Report name: becomes the folder name in S3
  # Format: s3://<bucket>/<prefix>/<report-name>/<date-range>/
  report_name = var.cur_report_name

  # Time granularity: HOURLY, DAILY, or MONTHLY
  # HOURLY provides the most detailed view and is recommended for analysis
  # Hourly reports show: exact hour when cost incurred, usage patterns, peak times
  time_unit = var.cur_time_unit

  # File format: textORcsv or Parquet
  # textORcsv: Standard CSV files (human-readable, compatible with Excel/Python)
  # Parquet: Columnar format (faster queries in Athena/Redshift, smaller files)
  format = var.cur_format

  # Compression: GZIP, Parquet, or ZIP
  # GZIP: Standard compression (works with textORcsv format)
  # Parquet: Built-in Parquet compression (only use with format="Parquet")
  # ZIP: Alternative compression (less common)
  compression = var.cur_compression

  # Additional schema elements to include in the report
  # RESOURCES: Include individual resource IDs (EC2 instance IDs, S3 bucket names, etc.)
  # This is CRITICAL for detailed cost attribution and analysis
  # Without RESOURCES, you only get service-level aggregation
  additional_schema_elements = ["RESOURCES"]

  # S3 destination configuration
  s3_bucket = aws_s3_bucket.cur_bucket.id
  s3_prefix = trim(var.cur_prefix, "/")
  s3_region = data.aws_region.current.name

  # Additional artifacts for BI tool integration
  # REDSHIFT: Creates manifest files for Redshift COPY command
  # QUICKSIGHT: Creates manifest files for QuickSight integration
  # ATHENA: Creates Parquet files optimized for Athena (Parquet format only)
  #
  # Example: QuickSight integration
  # additional_artifacts = ["QUICKSIGHT"]
  #
  # Example: Athena integration (requires format="Parquet")
  # additional_artifacts = ["ATHENA"]
  additional_artifacts = var.cur_additional_artifacts

  # Refresh closed reports: Update historical reports if AWS corrects data
  # true (recommended): AWS updates past months if credits/refunds applied
  # false: Historical months never change (faster, but potentially inaccurate)
  refresh_closed_reports = true

  # Report versioning: OVERWRITE_REPORT or CREATE_NEW_REPORT
  # OVERWRITE_REPORT: Replaces existing report files (saves S3 storage)
  # CREATE_NEW_REPORT: Creates new files each time (preserves history)
  # Recommended: OVERWRITE_REPORT (unless you need file-level audit trail)
  report_versioning = "OVERWRITE_REPORT"

  tags = merge(
    var.common_tags,
    {
      Name        = var.cur_report_name
      Description = "Cost and Usage Report for detailed billing analysis"
      Service     = "cur"
      Format      = var.cur_format
      TimeUnit    = var.cur_time_unit
    }
  )

  # Ensure S3 bucket and bucket policy exist before creating CUR
  # CUR validates S3 permissions during report definition creation
  depends_on = [
    aws_s3_bucket_policy.cur_bucket
  ]
}

# ============================================================================
# OPTIONAL: ADDITIONAL CUR REPORTS WITH DIFFERENT CONFIGURATIONS
# ============================================================================
# You can create multiple CUR reports with different settings.
# Common pattern: One Parquet for Athena, one CSV for manual analysis.
#
# Example: Parquet CUR optimized for Athena queries
# resource "aws_cur_report_definition" "parquet" {
#   count    = var.enable_cur ? 1 : 0
#   provider = aws.use1
#
#   report_name                = "${var.cur_report_name}-parquet"
#   time_unit                  = "HOURLY"
#   format                     = "Parquet"
#   compression                = "Parquet"
#   additional_schema_elements = ["RESOURCES"]
#   s3_bucket                  = aws_s3_bucket.cur_bucket.id
#   s3_prefix                  = "cur-parquet"
#   s3_region                  = data.aws_region.current.name
#   additional_artifacts       = ["ATHENA"]
#   refresh_closed_reports     = true
#   report_versioning          = "OVERWRITE_REPORT"
#
#   depends_on = [aws_s3_bucket_policy.cur_bucket]
# }
#
# Example: Daily CSV for lightweight analysis
# resource "aws_cur_report_definition" "daily" {
#   count    = var.enable_cur ? 1 : 0
#   provider = aws.use1
#
#   report_name                = "${var.cur_report_name}-daily"
#   time_unit                  = "DAILY"
#   format                     = "textORcsv"
#   compression                = "GZIP"
#   additional_schema_elements = ["RESOURCES"]
#   s3_bucket                  = aws_s3_bucket.cur_bucket.id
#   s3_prefix                  = "cur-daily"
#   s3_region                  = data.aws_region.current.name
#   refresh_closed_reports     = true
#   report_versioning          = "OVERWRITE_REPORT"
#
#   depends_on = [aws_s3_bucket_policy.cur_bucket]
# }

# ============================================================================
# OUTPUTS FOR CUR
# ============================================================================

output "cur_report_name" {
  description = "Name of the Cost and Usage Report"
  value       = var.enable_cur ? aws_cur_report_definition.main[0].report_name : null
}

output "cur_s3_location" {
  description = "S3 location where CUR reports are delivered"
  value       = var.enable_cur ? "s3://${aws_s3_bucket.cur_bucket.id}/${var.cur_prefix}/${var.cur_report_name}/" : null
}

output "cur_format" {
  description = "Format of CUR reports (textORcsv or Parquet)"
  value       = var.enable_cur ? var.cur_format : null
}

output "cur_time_unit" {
  description = "Time granularity of CUR reports (HOURLY, DAILY, or MONTHLY)"
  value       = var.enable_cur ? var.cur_time_unit : null
}

# ============================================================================
# OPERATIONAL NOTES
# ============================================================================
# INITIAL SETUP AND FIRST REPORT DELIVERY:
#
# 1. After terraform apply, wait 24 hours for first report
#    - CUR generates reports once per day (typically after midnight UTC)
#    - First report covers costs incurred AFTER CUR was enabled
#    - Historical costs (before CUR enabled) are NOT included
#
# 2. First report appears in S3 at:
#    s3://<bucket>/<prefix>/<report-name>/<date-range>/
#    Example: s3://alexflux-cur-123456/cur/openarena-cur/20240101-20240201/
#
# 3. Report structure:
#    - Manifest file: JSON file listing all data files
#    - Data files: One or more compressed CSV/Parquet files
#    - Checksums: MD5 hashes for data integrity verification
#
# UNDERSTANDING CUR FILE ORGANIZATION:
#
# Directory structure:
# s3://bucket/prefix/report-name/
#   ├── YYYYMMDD-YYYYMMDD/              # Date range (e.g., 20240101-20240201)
#   │   ├── manifest.json               # File manifest and metadata
#   │   ├── report-name-1.csv.gz        # Data file 1 (compressed)
#   │   ├── report-name-2.csv.gz        # Data file 2 (if large)
#   │   ├── report-name-1.csv.gz.md5    # Checksum file 1
#   │   └── report-name-2.csv.gz.md5    # Checksum file 2
#
# Manifest file structure:
# {
#   "reportId": "20240115T000000Z",
#   "reportName": "openarena-cur",
#   "billingPeriod": {
#     "start": "2024-01-01T00:00:00Z",
#     "end": "2024-02-01T00:00:00Z"
#   },
#   "dataFiles": [
#     {
#       "key": "cur/openarena-cur/20240101-20240201/openarena-cur-1.csv.gz",
#       "size": 1234567,
#       "md5Checksum": "abc123..."
#     }
#   ],
#   "columns": ["line_item/resource_id", "line_item/usage_amount", ...]
# }
#
# CUR DATA STRUCTURE:
#
# Each row in CUR represents a line item (single charge/usage entry):
#
# Key columns:
# - line_item/usage_start_date: When usage began
# - line_item/usage_account_id: AWS account (for consolidated billing)
# - line_item/product_code: Service (e.g., "AmazonEC2", "AmazonS3")
# - line_item/usage_type: Specific usage type (e.g., "BoxUsage:t2.micro")
# - line_item/operation: Operation (e.g., "RunInstances")
# - line_item/resource_id: Specific resource (e.g., "i-1234567890abcdef0")
# - line_item/usage_amount: Quantity used (e.g., 1 hour, 10 GB)
# - line_item/unblended_cost: Actual cost for this line item
# - line_item/blended_cost: Averaged cost (for consolidated billing)
# - product/region: AWS region
# - resource_tags/*: All resource tags (for cost allocation)
#
# Example CSV row (simplified):
# 2024-01-15T12:00:00Z,123456789012,AmazonEC2,BoxUsage:t2.micro,RunInstances,i-abc123,1.0,0.0116,us-west-2,openarena,production
#
# ANALYZING CUR WITH ATHENA:
#
# Step 1: Create Athena table (run once):
# ```sql
# CREATE EXTERNAL TABLE cur_openarena (
#   line_item_usage_start_date STRING,
#   line_item_product_code STRING,
#   line_item_usage_type STRING,
#   line_item_resource_id STRING,
#   line_item_usage_amount DECIMAL(18,9),
#   line_item_unblended_cost DECIMAL(18,9),
#   product_region STRING,
#   resource_tags_project STRING
# )
# PARTITIONED BY (year STRING, month STRING)
# ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe'
# WITH SERDEPROPERTIES (
#   'field.delim' = ',',
#   'skip.header.line.count' = '1'
# )
# LOCATION 's3://bucket/prefix/report-name/'
# TBLPROPERTIES ('has_encrypted_data'='false');
# ```
#
# Step 2: Load partitions:
# ```sql
# MSCK REPAIR TABLE cur_openarena;
# ```
#
# Step 3: Example queries:
#
# Query 1: Total cost by service this month
# ```sql
# SELECT
#   line_item_product_code AS service,
#   SUM(line_item_unblended_cost) AS total_cost
# FROM cur_openarena
# WHERE year='2024' AND month='01'
# GROUP BY line_item_product_code
# ORDER BY total_cost DESC;
# ```
#
# Query 2: EC2 costs by instance
# ```sql
# SELECT
#   line_item_resource_id AS instance_id,
#   SUM(line_item_unblended_cost) AS total_cost,
#   SUM(line_item_usage_amount) AS hours_used
# FROM cur_openarena
# WHERE line_item_product_code = 'AmazonEC2'
#   AND year='2024' AND month='01'
# GROUP BY line_item_resource_id
# ORDER BY total_cost DESC;
# ```
#
# Query 3: Costs by project tag
# ```sql
# SELECT
#   resource_tags_project AS project,
#   line_item_product_code AS service,
#   SUM(line_item_unblended_cost) AS total_cost
# FROM cur_openarena
# WHERE year='2024' AND month='01'
#   AND resource_tags_project IS NOT NULL
# GROUP BY resource_tags_project, line_item_product_code
# ORDER BY project, total_cost DESC;
# ```
#
# Query 4: Daily spend trend
# ```sql
# SELECT
#   DATE_FORMAT(FROM_ISO8601_TIMESTAMP(line_item_usage_start_date), '%Y-%m-%d') AS date,
#   SUM(line_item_unblended_cost) AS daily_cost
# FROM cur_openarena
# WHERE year='2024' AND month='01'
# GROUP BY DATE_FORMAT(FROM_ISO8601_TIMESTAMP(line_item_usage_start_date), '%Y-%m-%d')
# ORDER BY date;
# ```
#
# Query 5: Identify untagged resources
# ```sql
# SELECT
#   line_item_resource_id,
#   line_item_product_code,
#   SUM(line_item_unblended_cost) AS cost
# FROM cur_openarena
# WHERE year='2024' AND month='01'
#   AND line_item_resource_id != ''
#   AND resource_tags_project IS NULL
# GROUP BY line_item_resource_id, line_item_product_code
# ORDER BY cost DESC
# LIMIT 20;
# ```
#
# COST OPTIMIZATION INSIGHTS FROM CUR:
#
# 1. Identify unused resources:
#    - EBS volumes with $0 I/O but $10+ storage cost
#    - EIPs not attached to instances ($3.60/month each)
#    - Idle load balancers ($16-22/month each)
#
# 2. Right-size instances:
#    - Compare usage_amount (hours) vs actual need
#    - Find instances with high cost but low utilization
#
# 3. Optimize storage:
#    - S3 costs by storage class (Standard vs IA vs Glacier)
#    - Identify old snapshots that can be deleted
#
# 4. Track Reserved Instance utilization:
#    - Compare RI coverage vs on-demand usage
#    - Identify RI opportunities for steady workloads
#
# 5. Chargeback/showback by project:
#    - Aggregate costs by Project tag
#    - Generate invoices for internal teams
#
# TROUBLESHOOTING:
#
# Issue: No CUR files appearing after 24 hours
# Solutions:
# - Verify S3 bucket policy allows billingreports.amazonaws.com
# - Check CUR is created in us-east-1 (provider = aws.use1)
# - Ensure you have some AWS usage (CUR won't generate for $0 spend)
# - Check CloudTrail for CUR API errors
#
# Issue: "Access Denied" when creating CUR
# Solutions:
# - Verify S3 bucket policy includes GetBucketAcl and PutObject
# - Check aws:SourceAccount and aws:SourceArn conditions
# - Ensure bucket is in same account as CUR
#
# Issue: CUR files are huge and expensive to query
# Solutions:
# - Use Parquet format instead of CSV (10x smaller, 10x faster queries)
# - Enable Athena result caching (avoids re-running same queries)
# - Partition tables by year/month for faster scans
# - Use LIMIT in queries during development
# - Consider daily granularity instead of hourly
#
# Issue: Missing cost allocation tags in CUR
# Solutions:
# - Activate tags in Billing → Cost allocation tags console
# - Wait 24 hours after activation for tags to appear
# - Ensure resources are tagged before costs incur
#
# BEST PRACTICES:
#
# 1. Enable RESOURCES in additional_schema_elements (critical for analysis)
# 2. Use HOURLY time_unit for maximum detail
# 3. Set refresh_closed_reports=true to get accurate historical data
# 4. Use Parquet format if querying with Athena (faster + cheaper)
# 5. Partition Athena tables by year/month for performance
# 6. Enable S3 lifecycle policies to archive old CUR files to Glacier
# 7. Activate cost allocation tags BEFORE generating CUR
# 8. Create Athena views for common queries (project costs, etc.)
# 9. Schedule Athena queries with EventBridge for automated reports
# 10. Use CUR for detailed analysis, Cost Explorer for quick checks
#
# COMPLIANCE AND AUDIT:
#
# - CUR provides complete audit trail of all AWS charges
# - Includes resource IDs for traceability
# - Checksums ensure data integrity
# - Immutable historical data (with refresh_closed_reports=true)
# - Required for SOC2 compliance (financial record keeping)
# - Export to data warehouse for long-term retention (7 years+)
# ============================================================================

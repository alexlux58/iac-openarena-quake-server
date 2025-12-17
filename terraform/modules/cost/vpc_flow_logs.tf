# ============================================================================
# VPC Flow Logs Configuration
# ============================================================================
# VPC Flow Logs capture network traffic metadata (not packet contents) for:
# - Security analysis and incident investigation
# - Network troubleshooting (connection failures, dropped packets)
# - Compliance requirements (network activity audit trail)
# - Cost optimization (identify high-bandwidth consumers)
#
# WHAT FLOW LOGS CAPTURE:
# - Source and destination IP addresses
# - Source and destination ports
# - Protocol (TCP, UDP, ICMP, etc.)
# - Number of packets and bytes transferred
# - Action (ACCEPT or REJECT based on security group/NACL)
# - Start and end timestamps
# - Log status (OK, NODATA, SKIPDATA)
#
# WHAT FLOW LOGS DO NOT CAPTURE:
# - Actual packet contents (payload data)
# - ICMP echo responses (ping replies)
# - Instance metadata service requests (169.254.169.254)
# - Amazon DNS server traffic (within VPC)
# - Windows license activation traffic
#
# TRAFFIC TYPES:
# - ALL: Both accepted and rejected traffic (recommended for security)
# - ACCEPT: Only successful connections (troubleshooting connectivity)
# - REJECT: Only blocked traffic (identify attack attempts)
#
# AGGREGATION INTERVALS:
# - 60 seconds: More granular data, higher costs, larger files
# - 600 seconds (10 minutes): Less granular, lower costs (default)
#
# COST CONSIDERATIONS:
# - S3 destination: $0.50 per GB data ingested (cheapest option)
# - CloudWatch Logs destination: $0.50/GB ingested + $0.03/GB stored
# - Data processing charge applies regardless of destination
# - Typical t2.micro workload: 50-200 MB/day (~$0.75-3.00/month)
#
# DOCUMENTATION:
# - VPC Flow Logs Guide: https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html
# - S3 Delivery: https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs-s3.html
# - Custom Format: https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs-records-examples.html
# - Athena Queries: https://docs.aws.amazon.com/athena/latest/ug/vpc-flow-logs.html
# ============================================================================

# ============================================================================
# VPC DATA SOURCE
# ============================================================================
# Determine which VPC to monitor:
# - If vpc_id variable is provided, use that VPC
# - Otherwise, use the default VPC

data "aws_vpc" "selected" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  # If vpc_id is null, use default VPC
  # If vpc_id is provided, use that specific VPC
  default = var.vpc_id == null ? true : null
  id      = var.vpc_id
}

# ============================================================================
# VPC FLOW LOG RESOURCE
# ============================================================================
# Creates VPC Flow Log with S3 as the destination.
# Flow logs are delivered as compressed gzip files every 5-10 minutes.

resource "aws_flow_log" "vpc_to_s3" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  # VPC to monitor (default VPC or custom VPC)
  vpc_id = data.aws_vpc.selected[0].id

  # Traffic type: ALL, ACCEPT, or REJECT
  # ALL is recommended for comprehensive security monitoring
  traffic_type = var.vpc_flow_logs_traffic_type

  # Destination type: s3, cloud-watch-logs, or kinesis-data-firehose
  # S3 is most cost-effective for long-term storage and analysis
  log_destination_type = "s3"

  # S3 bucket and prefix where flow logs will be stored
  # Flow logs create directory structure:
  # <prefix>/AWSLogs/<account-id>/vpcflowlogs/<region>/<year>/<month>/<day>/
  log_destination = "${aws_s3_bucket.flowlog_bucket.arn}/${trim(var.vpc_flowlogs_prefix, "/")}/"

  # Custom log format (optional)
  # If null, AWS uses default format with essential fields
  # Custom format allows including additional fields like:
  # - vpc-id, subnet-id, instance-id (resource identification)
  # - pkt-srcaddr, pkt-dstaddr (for NAT traversal analysis)
  # - tcp-flags (SYN, ACK, FIN for connection analysis)
  # - flow-direction (ingress or egress)
  log_format = var.vpc_flow_logs_log_format

  # Maximum aggregation interval (60 or 600 seconds)
  # 60 seconds: More granular, higher volume, higher costs
  # 600 seconds: Less granular, lower volume, lower costs
  max_aggregation_interval = var.vpc_flow_logs_max_aggregation_interval

  # Tags for cost allocation and management
  tags = merge(
    var.common_tags,
    {
      Name        = "openarena-vpc-flow-logs"
      Description = "VPC Flow Logs for network traffic analysis"
      VPC         = data.aws_vpc.selected[0].id
      Service     = "vpc-flow-logs"
    }
  )

  # Ensure S3 bucket exists before creating flow log
  depends_on = [
    aws_s3_bucket.flowlog_bucket,
    aws_s3_bucket_public_access_block.flowlog_bucket
  ]
}

# ============================================================================
# VPC FLOW LOG FILE FORMAT
# ============================================================================
# Flow log files in S3 are:
# - Compressed with gzip
# - Named: <account-id>_vpcflowlogs_<region>_<flow-log-id>_<end-time>_<hash>.log.gz
# - Delivered every 5-10 minutes (depending on aggregation interval)
# - Organized in directories by date: <year>/<month>/<day>/
#
# EXAMPLE LOG RECORD (default format):
# version account-id interface-id srcaddr dstaddr srcport dstport protocol packets bytes start end action log-status
# 2 123456789012 eni-abc123 192.0.2.1 203.0.113.12 49152 443 6 10 5678 1234567890 1234567950 ACCEPT OK
#
# FIELD DESCRIPTIONS:
# - version: Flow log version (always 2)
# - account-id: AWS account ID
# - interface-id: Elastic network interface ID
# - srcaddr: Source IPv4/IPv6 address
# - dstaddr: Destination IPv4/IPv6 address
# - srcport: Source port
# - dstport: Destination port
# - protocol: IANA protocol number (6=TCP, 17=UDP, 1=ICMP)
# - packets: Number of packets transferred
# - bytes: Number of bytes transferred
# - start: Start time of flow (Unix epoch seconds)
# - end: End time of flow (Unix epoch seconds)
# - action: ACCEPT or REJECT (based on security group/NACL)
# - log-status: OK (normal), NODATA (no traffic), SKIPDATA (error)

# ============================================================================
# OPTIONAL: CUSTOM LOG FORMAT EXAMPLE
# ============================================================================
# To enable custom log format, set var.vpc_flow_logs_log_format to a string
# containing space-separated field names:
#
# Example 1 - Enhanced format with resource identification:
# log_format = "$${version} $${account-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${start} $${end} $${action} $${log-status} $${vpc-id} $${subnet-id} $${instance-id}"
#
# Example 2 - Minimal format for cost optimization:
# log_format = "$${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${action}"
#
# Example 3 - TCP-focused format for connection analysis:
# log_format = "$${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${tcp-flags} $${action} $${flow-direction}"
#
# IMPORTANT: Use $${field} syntax in Terraform (double dollar sign for escaping)

# ============================================================================
# S3 BUCKET POLICY FOR VPC FLOW LOGS
# ============================================================================
# IMPORTANT: VPC Flow Logs service automatically creates and manages the
# bucket policy. DO NOT manually create a bucket policy for flow logs.
#
# AWS will add statements to the bucket policy granting:
# - logs.amazonaws.com permission to check bucket ACL
# - logs.amazonaws.com permission to write flow log files
#
# This automatic policy management is why we use a separate bucket for
# flow logs (to avoid conflicts with CloudTrail/GuardDuty policies).

# ============================================================================
# OUTPUTS FOR VPC FLOW LOGS
# ============================================================================

output "vpc_flow_log_id" {
  description = "ID of the VPC Flow Log resource"
  value       = var.enable_vpc_flow_logs ? aws_flow_log.vpc_to_s3[0].id : null
}

output "vpc_flow_log_arn" {
  description = "ARN of the VPC Flow Log resource"
  value       = var.enable_vpc_flow_logs ? aws_flow_log.vpc_to_s3[0].arn : null
}

output "vpc_flow_log_s3_location" {
  description = "S3 location where VPC Flow Logs are stored"
  value       = var.enable_vpc_flow_logs ? "s3://${aws_s3_bucket.flowlog_bucket.id}/${var.vpc_flowlogs_prefix}" : null
}

output "monitored_vpc_id" {
  description = "ID of the VPC being monitored by Flow Logs"
  value       = var.enable_vpc_flow_logs ? data.aws_vpc.selected[0].id : null
}

# ============================================================================
# OPERATIONAL NOTES
# ============================================================================
# VERIFICATION AFTER DEPLOYMENT:
# 1. Wait 10-15 minutes for first flow log delivery
# 2. Check S3: s3://<bucket>/<prefix>/AWSLogs/<account-id>/vpcflowlogs/
# 3. Download and decompress a log file: gunzip <file>.log.gz
# 4. Verify log records match expected format
#
# ANALYZING FLOW LOGS:
#
# METHOD 1: AWS Athena (recommended for ad-hoc queries)
# 1. Create Athena table from flow logs S3 location
# 2. Run SQL queries to analyze traffic patterns
# 3. Example queries:
#    - Top talkers: SELECT srcaddr, SUM(bytes) FROM logs GROUP BY srcaddr
#    - Rejected traffic: SELECT * FROM logs WHERE action = 'REJECT'
#    - Port scanning: SELECT srcaddr, COUNT(DISTINCT dstport) FROM logs GROUP BY srcaddr
#
# METHOD 2: CloudWatch Insights (if using CloudWatch Logs destination)
# - Real-time querying with CloudWatch Logs Insights
# - Higher cost but faster for recent data
#
# METHOD 3: Download and parse locally
# - Good for one-off analysis or custom tooling
# - Use Python, jq, or awk to parse log files
#
# COMMON ATHENA QUERIES:
#
# Create Athena table (run once):
# CREATE EXTERNAL TABLE vpc_flow_logs (
#   version int,
#   account string,
#   interfaceid string,
#   sourceaddress string,
#   destinationaddress string,
#   sourceport int,
#   destinationport int,
#   protocol int,
#   numpackets int,
#   numbytes bigint,
#   starttime int,
#   endtime int,
#   action string,
#   logstatus string
# )
# PARTITIONED BY (dt string)
# ROW FORMAT DELIMITED
# FIELDS TERMINATED BY ' '
# LOCATION 's3://<bucket>/<prefix>/AWSLogs/<account-id>/vpcflowlogs/<region>/'
# TBLPROPERTIES ("skip.header.line.count"="1");
#
# Query 1: Top 10 destination ports (identify services):
# SELECT destinationport, COUNT(*) as count
# FROM vpc_flow_logs
# WHERE action = 'ACCEPT'
# GROUP BY destinationport
# ORDER BY count DESC
# LIMIT 10;
#
# Query 2: All rejected traffic (security analysis):
# SELECT *
# FROM vpc_flow_logs
# WHERE action = 'REJECT'
# ORDER BY starttime DESC
# LIMIT 100;
#
# Query 3: Top source IPs by bytes transferred:
# SELECT sourceaddress, SUM(numbytes) as totalbytes
# FROM vpc_flow_logs
# GROUP BY sourceaddress
# ORDER BY totalbytes DESC
# LIMIT 20;
#
# Query 4: SSH brute force attempts (multiple connections to port 22):
# SELECT sourceaddress, COUNT(*) as attempts
# FROM vpc_flow_logs
# WHERE destinationport = 22 AND action = 'REJECT'
# GROUP BY sourceaddress
# HAVING COUNT(*) > 10
# ORDER BY attempts DESC;
#
# SECURITY USE CASES:
# 1. Identify port scanning: Source IP connecting to many different ports
# 2. Detect DDoS: High packet count from single source
# 3. Find data exfiltration: Unusual high-bandwidth transfers
# 4. Analyze rejected traffic: Blocked connection attempts
# 5. Verify security groups: Confirm expected traffic is allowed/blocked
#
# TROUBLESHOOTING USE CASES:
# 1. Connection failures: Look for REJECT actions
# 2. Asymmetric routing: Inbound ACCEPT but no outbound response
# 3. Network bandwidth: Sum bytes by source/destination
# 4. Identify chatty applications: High packet count flows
#
# COST OPTIMIZATION:
# 1. Use 600-second aggregation interval (10 minutes) instead of 60 seconds
# 2. Consider ACCEPT-only logs if you don't need rejected traffic analysis
# 3. Enable S3 lifecycle policies to transition old logs to Glacier
# 4. Use Athena instead of CloudWatch Logs for cost-effective analysis
# 5. Filter logs with custom format (fewer fields = smaller files)
#
# LIMITATIONS:
# - Flow logs do not capture real-time traffic (5-10 minute delay)
# - Does not capture packet contents (use VPC Traffic Mirroring for that)
# - Some traffic is not logged (AWS DNS, instance metadata, etc.)
# - Cannot be enabled on VPC peering connections
#
# COMPLIANCE NOTES:
# - Flow logs provide network activity audit trail for compliance
# - Retain logs based on compliance requirements (90 days, 1 year, 7 years)
# - Consider enabling log file integrity checking (not built-in, use S3 versioning)
# - For PCI-DSS: Flow logs help satisfy requirement 10 (tracking network access)
# ============================================================================

# OpenArena AWS - Complete Deployment Guide

This guide provides **step-by-step instructions** for deploying, using, and destroying the OpenArena game server infrastructure with comprehensive security logging and cost monitoring.

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Cost Breakdown](#cost-breakdown)
3. [Initial Setup](#initial-setup)
4. [Deployment Steps](#deployment-steps)
5. [Post-Deployment Configuration](#post-deployment-configuration)
6. [Using the Infrastructure](#using-the-infrastructure)
7. [Monitoring and Alerts](#monitoring-and-alerts)
8. [Cost Optimization](#cost-optimization)
9. [Destroying Infrastructure](#destroying-infrastructure)
10. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software
- **Terraform** >= 1.0 ([Install](https://developer.hashicorp.com/terraform/downloads))
- **Ansible** >= 2.9 ([Install](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html))
- **AWS CLI** >= 2.0 ([Install](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- **SSH client** (OpenSSH or PuTTY)

### Required AWS Account Setup
1. **AWS Account** with billing enabled
2. **IAM User** with permissions:
   - EC2, VPC, S3, CloudTrail, GuardDuty
   - Budgets, Cost Explorer, CloudWatch
   - IAM (for creating roles)
3. **AWS credentials** configured:
   ```bash
   aws configure
   # OR use environment variables:
   export AWS_ACCESS_KEY_ID="your-key-id"
   export AWS_SECRET_ACCESS_KEY="your-secret-key"
   export AWS_DEFAULT_REGION="us-west-2"
   ```

### Optional (for DNS)
- **Cloudflare account** with domain name
- **Cloudflare API token** with DNS edit permissions

---

## Cost Breakdown

### Monthly Cost Estimates

#### 🎯 **RECOMMENDED: Cost-Optimized Configuration**
```
EC2 t2.micro (730 hours)         : $8.50
EBS volume (8 GB)                : $0.80
Data transfer (10 GB)            : $0.90
S3 storage (audit logs)          : $0.50
CloudTrail (first trail)         : FREE
AWS Budgets (first 2)            : FREE
Cost Anomaly Detection           : FREE
CloudWatch Billing Alarm         : FREE
CUR                              : FREE
─────────────────────────────────────────
TOTAL                            : ~$10.70/month
```

#### 🛡️ **Full Security Configuration**
```
Cost-Optimized (above)           : $10.70
GuardDuty                        : $10.00
VPC Flow Logs                    : $3.00
CloudWatch Logs (EC2)            : $1.50
─────────────────────────────────────────
TOTAL                            : ~$25.20/month
```

#### 💡 **With Auto-Shutdown (50% idle time)**
```
EC2 t2.micro (365 hours)         : $4.25
Other costs                      : $2.45
─────────────────────────────────────────
TOTAL                            : ~$6.70/month
```

### Cost by Player Activity

| Scenario | Monthly Cost |
|----------|--------------|
| **Idle server (auto-shutdown)** | ~$2-3 |
| **Weekend gaming (Fri-Sun)** | ~$4-5 |
| **Daily casual play (2-4 hours)** | ~$8-10 |
| **24/7 active server** | ~$11-25 |

---

## Initial Setup

### 1. Clone and Navigate to Repository

```bash
cd /Users/alex.lux/Desktop/AWS/openarena-aws
```

### 2. Create Environment Configuration

```bash
cp .env.example .env
```

Edit `.env` with your settings:

```bash
# AWS Configuration
AWS_REGION="us-west-2"
INSTANCE_TYPE="t2.micro"

# SSH Configuration
SSH_KEY_NAME="your-existing-key"  # OR create new key:
CREATE_KEY_PAIR="true"
SSH_PUBLIC_KEY_FILE="~/.ssh/id_rsa.pub"
SSH_PRIVATE_KEY_FILE="~/.ssh/id_rsa"
SSH_ALLOWED_CIDR="0.0.0.0/0"  # CHANGE THIS to your IP: "1.2.3.4/32"

# Cloudflare DNS (Optional)
CLOUDFLARE_API_TOKEN="your-cloudflare-token"
CLOUDFLARE_ZONE_ID="your-zone-id"
CLOUDFLARE_ZONE_NAME="example.com"
CLOUDFLARE_SUBDOMAIN="quake"

# Cost Monitoring (NEW)
LOG_BUCKET_NAME="alexflux-audit-logs-123456789012"  # CHANGE 123456789012 to your AWS account ID
FLOWLOG_BUCKET_NAME="alexflux-flowlogs-123456789012"
CUR_BUCKET_NAME="alexflux-cur-123456789012"
BILLING_ALERT_EMAIL="your-email@example.com"  # IMPORTANT: Change this!
MONTHLY_BUDGET_USD="15"

# Feature Toggles (Cost Optimization)
ENABLE_CLOUDTRAIL="true"           # FREE - keep enabled
ENABLE_GUARDDUTY="false"           # $10/month - disable to save money
ENABLE_VPC_FLOW_LOGS="false"       # $3/month - disable to save money
ENABLE_COST_BUDGETS="true"         # FREE - keep enabled
ENABLE_COST_ANOMALY_DETECTION="true"  # FREE - keep enabled
ENABLE_BILLING_ALARM="true"        # FREE - keep enabled
ENABLE_CUR="true"                  # FREE - keep enabled
ENABLE_CLOUDWATCH_LOGS="false"     # $1.50/month - disable to save money
```

### 3. Get Your AWS Account ID

```bash
aws sts get-caller-identity --query Account --output text
# Output: 123456789012

# Update bucket names in .env with your account ID
```

### 4. Create Terraform Variables File

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform/terraform.tfvars` with your values from `.env`

---

## Deployment Steps

### Step 1: Validate Environment

```bash
# Check environment variables
./terraform/check-env.sh

# Expected output: ✓ All required environment variables are set
```

### Step 2: Deploy Infrastructure with Terraform

```bash
cd terraform

# Initialize Terraform (download providers)
terraform init

# Review what will be created
terraform plan

# Deploy infrastructure (takes ~5-10 minutes)
terraform apply

# Type 'yes' when prompted
```

**What gets created:**
- EC2 instance (t2.micro)
- Security group (SSH + game server port)
- Elastic IP
- S3 buckets (3 buckets for logs)
- CloudTrail
- SNS topics (budget alerts)
- AWS Budgets
- Cost Anomaly Detection
- CloudWatch Billing Alarm
- CUR report configuration
- IAM roles (if CloudWatch Logs enabled)

### Step 3: Configure Game Server with Ansible

```bash
# Go back to project root
cd ..

# Run full deployment (Terraform + Ansible)
./scripts/deploy.sh
```

**OR manually run Ansible:**

```bash
# Wait for EC2 instance to be ready
sleep 60

# Run Ansible playbook
cd ansible
ansible-playbook -i inventory/hosts.ini playbooks/site.yml
```

**What Ansible does:**
- Installs OpenArena game server
- Configures server settings
- Creates systemd service (auto-start on boot)
- (Optional) Installs CloudWatch Agent for log collection

### Step 4: Verify Deployment

```bash
# Get server details
cd terraform
terraform output

# Output includes:
# - public_ip: EC2 instance IP address
# - fqdn: DNS name (if Cloudflare configured)
# - ssh_user: SSH username (ec2-user)
```

Test SSH connection:

```bash
ssh -i ~/.ssh/id_rsa ec2-user@<public_ip>

# Check game server status
sudo systemctl status openarena

# View game server logs
sudo journalctl -u openarena -f
```

Test game connection:
1. Open OpenArena client
2. Multiplayer → Specify Server
3. Enter: `<public_ip>:27960` (or your DNS name)
4. Connect!

---

## Post-Deployment Configuration

### 1. Confirm SNS Email Subscriptions (CRITICAL!)

After deployment, you'll receive **2 confirmation emails**:

1. **Budget Alerts Subscription**
   - Subject: "AWS Notification - Subscription Confirmation"
   - Sender: `no-reply@sns.amazonaws.com`
   - **Click "Confirm subscription" link**

2. **Anomaly Alerts Subscription**
   - Another email with same subject
   - **Click "Confirm subscription" link**

**Until you confirm, you won't receive any cost alerts!**

### 2. Enable CloudWatch Billing Alerts (One-Time, REQUIRED)

This is a **manual AWS Console step**:

1. Sign in to AWS Console
2. Go to: **Billing → Billing Preferences**
3. Check: **"Receive CloudWatch Billing Alerts"**
4. Click: **Save preferences**
5. Wait 15-30 minutes for billing metrics to appear

### 3. Activate Cost Allocation Tags (Optional, for Tag-Filtered Budgets)

1. Go to: **Billing → Cost allocation tags**
2. Find and activate: `Project`, `Environment`, `ManagedBy`
3. Click: **Activate**
4. Wait 24 hours for tag data to appear in Cost Explorer

### 4. Verify Log Delivery (After 24 Hours)

**CloudTrail Logs:**
```bash
aws s3 ls s3://alexflux-audit-logs-<account-id>/cloudtrail/ --recursive
```

**GuardDuty Findings (if enabled):**
```bash
aws s3 ls s3://alexflux-audit-logs-<account-id>/guardduty/ --recursive
```

**VPC Flow Logs (if enabled):**
```bash
aws s3 ls s3://alexflux-flowlogs-<account-id>/vpcflow/ --recursive
```

**Cost and Usage Report:**
```bash
aws s3 ls s3://alexflux-cur-<account-id>/cur/ --recursive
```

---

## Using the Infrastructure

### Connecting to Game Server

**Option 1: Direct IP**
```
Server: <public_ip>:27960
Example: 54.123.45.67:27960
```

**Option 2: DNS (if Cloudflare configured)**
```
Server: quake.example.com:27960
```

### Managing the Game Server

**SSH into instance:**
```bash
ssh -i ~/.ssh/id_rsa ec2-user@<public_ip>
```

**Common operations:**
```bash
# Check server status
sudo systemctl status openarena

# View live logs
sudo journalctl -u openarena -f

# Restart server
sudo systemctl restart openarena

# Stop server
sudo systemctl stop openarena

# Start server
sudo systemctl start openarena

# Edit server config
sudo vi /etc/openarena/server.cfg
sudo systemctl restart openarena  # Apply changes
```

### Monitoring Costs

**AWS Cost Explorer (Console):**
1. Go to: **Billing → Cost Explorer**
2. View: Daily/monthly costs by service
3. Filter by: Tags (Project=openarena)

**AWS Budgets (Console):**
1. Go to: **Billing → Budgets**
2. View: "openarena-monthly-total" budget
3. See: Current spend vs budget

**Cost Anomaly Detection (Console):**
1. Go to: **Cost Management → Cost Anomaly Detection**
2. View: Detected anomalies and root causes

**CloudWatch Billing Alarm (Console):**
1. Go to: **CloudWatch (us-east-1) → Alarms**
2. View: "openarena-estimated-charges" alarm status

**Cost via CLI:**
```bash
# Get current month spend
aws ce get-cost-and-usage \
  --time-period Start=$(date -u +%Y-%m-01),End=$(date -u +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# Get EC2 costs specifically
aws ce get-cost-and-usage \
  --time-period Start=$(date -u +%Y-%m-01),End=$(date -u +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --filter file://<(echo '{"Dimensions":{"Key":"SERVICE","Values":["Amazon Elastic Compute Cloud - Compute"]}}')
```

### Viewing Security Logs

**CloudTrail (API Activity):**
```bash
# List log files
aws s3 ls s3://alexflux-audit-logs-<account-id>/cloudtrail/ --recursive | tail -20

# Download recent log
aws s3 cp s3://alexflux-audit-logs-<account-id>/cloudtrail/AWSLogs/<account-id>/CloudTrail/<region>/2024/01/15/<file>.json.gz .
gunzip <file>.json.gz
less <file>.json
```

**GuardDuty Findings (if enabled):**
1. Go to: **GuardDuty → Findings**
2. View: Real-time threat detections
3. Export: Download from S3 for analysis

**VPC Flow Logs (if enabled):**
```bash
# Download flow log file
aws s3 cp s3://alexflux-flowlogs-<account-id>/vpcflow/<path>/<file>.gz .
gunzip <file>.gz
less <file>
```

---

## Monitoring and Alerts

### Email Alerts You'll Receive

**Budget Alerts (3 thresholds):**
- **50% of budget:** Early warning ($7.50 if $15 budget)
- **80% of budget:** Critical warning ($12 if $15 budget)
- **100% of budget:** Budget exceeded ($15)
- **100% forecasted:** AWS predicts you'll exceed budget by month-end

**Cost Anomaly Alerts:**
- **Daily digest:** Summary of detected spending anomalies
- **Impact threshold:** Only alerts if anomaly >= $5 (configurable)
- **Example:** "EC2 cost increased 200% on Jan 15"

**CloudWatch Billing Alarm:**
- **Failsafe backup:** Triggers if estimated charges exceed $20 (configurable)
- **Frequency:** Checks every 6 hours

### Setting Up CloudWatch Alarms for Security Events (Optional)

Create alarm for failed SSH attempts:

```bash
# Create metric filter
aws logs put-metric-filter \
  --log-group-name /openarena/ec2/auth \
  --filter-name FailedSSHLogins \
  --filter-pattern '[... msg="Failed password"]' \
  --metric-transformations \
      metricName=FailedSSHAttempts,metricNamespace=OpenArena/Security,metricValue=1

# Create alarm
aws cloudwatch put-metric-alarm \
  --alarm-name openarena-failed-ssh \
  --alarm-description "Alert on multiple failed SSH login attempts" \
  --metric-name FailedSSHAttempts \
  --namespace OpenArena/Security \
  --statistic Sum \
  --period 300 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --alarm-actions <SNS-topic-ARN>
```

---

## Cost Optimization

### 1. Use Cost-Optimized Configuration (Recommended)

In your `.env` file, disable expensive features:

```bash
ENABLE_GUARDDUTY="false"           # Saves $10/month
ENABLE_VPC_FLOW_LOGS="false"       # Saves $3/month
ENABLE_CLOUDWATCH_LOGS="false"     # Saves $1.50/month
```

**Savings: ~$14.50/month**

### 2. Auto-Shutdown When Idle (COMING SOON)

I can create a Lambda function that:
- Checks game server connections every 10 minutes
- Stops EC2 instance after 10 minutes of inactivity
- Restarts manually when needed

**Savings:** ~$4-7/month (depending on idle time)

### 3. Manual Start/Stop

**Stop instance when not playing:**
```bash
# Get instance ID
INSTANCE_ID=$(cd terraform && terraform output -json | jq -r '.instance_id.value')

# Stop instance
aws ec2 stop-instances --instance-ids $INSTANCE_ID

# Start instance when ready to play
aws ec2 start-instances --instance-ids $INSTANCE_ID

# Wait for startup (~30 seconds)
sleep 30

# Get new public IP (changes after each start)
aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text
```

**Savings:** If you stop server when not playing (50% uptime):
- **~$4.25/month** instead of $8.50/month

### 4. Use Spot Instances (Advanced)

Edit `terraform/modules/openarena/main.tf`:

```hcl
resource "aws_instance" "this" {
  # ... existing config ...

  # Add spot instance configuration
  instance_market_options {
    market_type = "spot"
    spot_options {
      max_price = "0.005"  # Maximum price per hour
    }
  }
}
```

**Savings:** ~70% off EC2 costs (~$2.50/month instead of $8.50)

**Caveat:** AWS can terminate instance with 2-minute warning if capacity needed

### 5. S3 Lifecycle Policies (Reduce Storage Costs)

Automatically move old logs to cheaper storage:

```bash
# Edit terraform/modules/cost/s3_buckets.tf
# Uncomment the lifecycle_configuration blocks
terraform apply
```

**Savings:** ~$0.20-0.50/month on S3 storage

### 6. Reduce Log Retention

Edit `terraform/modules/cost/variables.tf`:

```hcl
variable "cw_log_group_retention_days" {
  default = 7  # Instead of 30 days
}
```

**Savings:** ~$0.30/month on CloudWatch Logs storage

---

## Destroying Infrastructure

### Complete Teardown (Delete Everything)

⚠️ **WARNING:** This deletes ALL resources and data. Cannot be undone!

```bash
# Option 1: Use destroy script
./scripts/destroy.sh

# Option 2: Manual Terraform destroy
cd terraform
terraform destroy

# Type 'yes' when prompted
```

### What Gets Deleted

- ✅ EC2 instance
- ✅ Security group
- ✅ Elastic IP
- ✅ Key pair (if created by Terraform)
- ✅ S3 buckets (if `s3_bucket_force_destroy=true`)
- ✅ CloudTrail trail
- ✅ GuardDuty detector
- ✅ VPC Flow Logs
- ✅ SNS topics and subscriptions
- ✅ AWS Budgets
- ✅ Cost Anomaly Detection monitors
- ✅ CloudWatch Alarms
- ✅ CUR report definition
- ✅ IAM roles and policies
- ✅ Cloudflare DNS record

### Important Notes

**S3 Buckets:**
- By default, S3 buckets with objects will **NOT** be deleted (safety)
- To allow deletion of non-empty buckets, set in `.env`:
  ```bash
  S3_BUCKET_FORCE_DESTROY="true"
  ```
- **Alternative:** Manually empty buckets before destroy:
  ```bash
  aws s3 rm s3://alexflux-audit-logs-<account-id> --recursive
  aws s3 rm s3://alexflux-flowlogs-<account-id> --recursive
  aws s3 rm s3://alexflux-cur-<account-id> --recursive
  ```

**Cost After Destroy:**
- Most costs stop immediately
- S3 storage costs continue until buckets deleted
- Negligible costs: ~$0.10-0.50/month if buckets remain

**Backup Before Destroy:**
```bash
# Download all logs for archival
aws s3 sync s3://alexflux-audit-logs-<account-id> ./backups/audit-logs/
aws s3 sync s3://alexflux-flowlogs-<account-id> ./backups/flowlogs/
aws s3 sync s3://alexflux-cur-<account-id> ./backups/cur/
```

---

## Troubleshooting

### Deployment Issues

**Issue: Terraform apply fails with "AccessDenied"**

Solution:
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Check IAM permissions (need Admin or Power User)
aws iam get-user --user-name <your-username>
```

**Issue: "Bucket name already exists" error**

Solution:
- S3 bucket names are globally unique
- Change bucket names in `.env` to include your account ID:
  ```bash
  LOG_BUCKET_NAME="alexflux-audit-logs-123456789012"
  ```

**Issue: Ansible fails with "Host key verification failed"**

Solution:
```bash
# Wait longer for instance to boot
sleep 60

# OR disable host key checking (less secure)
export ANSIBLE_HOST_KEY_CHECKING=False
ansible-playbook ...
```

**Issue: Can't connect to game server**

Solution:
1. Verify security group allows UDP 27960:
   ```bash
   aws ec2 describe-security-groups --group-ids <sg-id>
   ```
2. Check server is running:
   ```bash
   ssh ec2-user@<public_ip> "sudo systemctl status openarena"
   ```
3. Verify firewall on your local machine allows outbound UDP

### Cost Monitoring Issues

**Issue: Not receiving budget alert emails**

Solutions:
1. **Check SNS subscription confirmation:**
   ```bash
   aws sns list-subscriptions
   # Look for Status="PendingConfirmation"
   ```
   - Resend confirmation: Go to SNS console → Subscriptions → Request confirmation

2. **Check email spam folder**

3. **Verify budget exists:**
   ```bash
   aws budgets describe-budgets --account-id <account-id>
   ```

**Issue: CloudWatch Billing Alarm stuck in "INSUFFICIENT_DATA"**

Solutions:
1. **Enable Billing Alerts (one-time):**
   - AWS Console → Billing → Preferences
   - Check "Receive CloudWatch Billing Alerts"

2. **Wait 15-30 minutes** for metric to appear

3. **Verify in us-east-1:**
   ```bash
   aws cloudwatch list-metrics \
     --namespace AWS/Billing \
     --region us-east-1
   ```

**Issue: GuardDuty not detecting threats**

- GuardDuty needs 7-14 days to establish baseline
- Test with sample findings:
  ```bash
  DETECTOR_ID=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text)
  aws guardduty create-sample-findings --detector-id $DETECTOR_ID \
    --finding-types UnauthorizedAccess:EC2/SSHBruteForce
  ```

### Log Collection Issues

**Issue: CloudWatch Logs not appearing**

Solutions:
1. **Verify IAM instance profile attached to EC2:**
   ```bash
   aws ec2 describe-instances --instance-ids <instance-id> \
     --query 'Reservations[0].Instances[0].IamInstanceProfile'
   ```

2. **Check CloudWatch Agent status:**
   ```bash
   ssh ec2-user@<public_ip>
   sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a query
   ```

3. **View agent logs:**
   ```bash
   sudo tail -f /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
   ```

---

## Additional Resources

### AWS Console Links

- **EC2 Instances:** https://console.aws.amazon.com/ec2/home?region=us-west-2#Instances:
- **Cost Explorer:** https://console.aws.amazon.com/cost-management/home#/cost-explorer
- **Budgets:** https://console.aws.amazon.com/billing/home#/budgets
- **CloudTrail:** https://console.aws.amazon.com/cloudtrail/home?region=us-west-2#/trails
- **GuardDuty:** https://console.aws.amazon.com/guardduty/home?region=us-west-2#/findings
- **S3 Buckets:** https://s3.console.aws.amazon.com/s3/buckets

### Documentation

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Ansible AWS Modules](https://docs.ansible.com/ansible/latest/collections/amazon/aws/)
- [AWS Budgets User Guide](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html)
- [CloudTrail User Guide](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/)
- [GuardDuty User Guide](https://docs.aws.amazon.com/guardduty/latest/ug/)

### Support

- **Project Issues:** https://github.com/anthropics/claude-code/issues
- **AWS Support:** https://console.aws.amazon.com/support/home

---

## Quick Reference

### Common Commands

```bash
# Deploy everything
./scripts/deploy.sh

# Check current costs
aws ce get-cost-and-usage --time-period Start=$(date -u +%Y-%m-01),End=$(date -u +%Y-%m-%d) --granularity MONTHLY --metrics UnblendedCost

# Stop server to save money
aws ec2 stop-instances --instance-ids $(terraform output -raw instance_id)

# Start server
aws ec2 start-instances --instance-ids $(terraform output -raw instance_id)

# SSH to server
ssh -i ~/.ssh/id_rsa ec2-user@$(terraform output -raw public_ip)

# View game server logs
ssh ec2-user@$(terraform output -raw public_ip) "sudo journalctl -u openarena -f"

# Destroy everything
./scripts/destroy.sh
```

### Cost Summary

| Configuration | Monthly Cost |
|---------------|--------------|
| Minimal (auto-shutdown, no monitoring) | $2-3 |
| Weekend gaming | $4-5 |
| Cost-optimized 24/7 | $11 |
| Full security 24/7 | $25-28 |

---

**Questions? Need help? Want the auto-shutdown Lambda function?**

Let me know and I'll create additional scripts and features!

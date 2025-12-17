# OpenArena AWS Infrastructure

Enterprise-grade infrastructure for hosting OpenArena (Quake) game servers on AWS with comprehensive security logging and cost monitoring.

## 🎮 Features

- **EC2 Game Server**: Amazon Linux 2, t2.micro (free tier eligible)
- **Elastic IP**: Static IP address for consistent DNS
- **Cloudflare DNS**: Custom domain support (e.g., quake.alexflux.com)
- **Security Logging**: CloudTrail, GuardDuty (optional), VPC Flow Logs (optional)
- **Cost Monitoring**: Budgets, Anomaly Detection, Billing Alarms
- **Infrastructure as Code**: Terraform + Ansible
- **Python 3.8 Auto-Install**: Automatic Python upgrade for Ansible compatibility
- **CI/CD Ready**: GitHub Actions workflows

## 📋 Prerequisites

- **AWS Account** with appropriate IAM permissions (see [IAM Setup](#-iam-permissions) below)
- **Terraform** >= 1.5.0 ([Install Guide](https://developer.hashicorp.com/terraform/install))
- **Ansible** ([Install Guide](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html))
- **AWS CLI** configured ([Setup Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- **Cloudflare Account** (optional, for custom DNS)
- **Git** (for version control)

## 🔐 IAM Permissions

Your AWS IAM user needs the following managed policies attached:

### Required IAM Policies

1. **Attach via AWS Console** or use the provided script:

```bash
# Attach the 3 required IAM policies to your terraform user
./scripts/attach-iam-policy.sh

# This creates and attaches:
# - OpenArenaTerraformMonitoring (SNS, Budgets, Cost Explorer, CUR)
# - OpenArenaTerraformSecurity (IAM, KMS, GuardDuty)
# - OpenArenaTerraformCloudTrail (CloudTrail management)
```

2. **Existing AWS Managed Policies** (attach via AWS Console):
   - `AmazonEC2FullAccess`
   - `AmazonS3FullAccess`
   - `AmazonVPCFullAccess`

### IAM Policy Files

The custom IAM policies are provided in the project root:
- `iam-policy-terraform-monitoring.json`
- `iam-policy-terraform-security.json`
- `iam-policy-terraform-cloudtrail.json`

See [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for detailed IAM setup instructions.

## 🚀 Quick Start

### 1. Clone and Setup

```bash
git clone <your-repo-url>
cd openarena-aws
```

### 2. Configure Environment Variables

**Create .env file (required for deployment scripts):**

```bash
cp .env.example .env
# Edit .env with your values
```

**Key variables in .env:**
```bash
AWS_REGION="us-west-2"
SSH_KEY_NAME="terraform"                    # Your AWS SSH key pair name
SSH_PRIVATE_KEY_FILE="./terraform.pem"      # Path to your private key
SSH_ALLOWED_CIDR="23.242.22.13/32"          # Your public IP (use /32 for single IP)

# Cloudflare (optional - set to "dummy" if not using)
CLOUDFLARE_API_TOKEN="your-token-or-dummy"
```

**Find your public IP:**
```bash
curl ifconfig.me
# Add /32 to the end: 23.242.22.13/32
```

### 3. Configure Terraform Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

**Critical variables in terraform.tfvars:**
```hcl
# AWS Configuration
aws_region          = "us-west-2"
ssh_key_name        = "terraform"
create_key_pair     = false              # Set to true if key doesn't exist in AWS
ssh_allowed_cidr    = "23.242.22.13/32"  # Your public IP

# S3 Bucket Names (MUST be globally unique)
# Replace 026600053230 with your AWS Account ID
# Get it: aws sts get-caller-identity --query Account --output text
log_bucket_name     = "openarena-audit-logs-026600053230"
flowlog_bucket_name = "openarena-flowlogs-026600053230"
cur_bucket_name     = "openarena-cur-026600053230"

# Email for cost alerts
billing_alert_email = "your-email@example.com"  # MUST CONFIRM SNS SUBSCRIPTION!

# Cloudflare (optional - leave empty to skip)
cloudflare_zone_id   = ""  # Empty = no DNS
cloudflare_zone_name = ""  # Empty = no DNS

# Feature toggles (save money by disabling optional features)
enable_cloudtrail      = true   # FREE - keep enabled
enable_guardduty       = false  # $10/month - disabled to save money
enable_vpc_flow_logs   = false  # $3/month - disabled to save money
enable_cloudwatch_logs = false  # $1.50/month - disabled to save money
```

### 4. Deploy

**Recommended: Layered Deploy (step-by-step with confirmations)**
```bash
make layered-deploy
# OR
./scripts/layered-deploy.sh
```

**Alternative: One-Command Deploy**
```bash
make deploy
# OR
./scripts/deploy.sh
```

**Dry-Run (validate without deploying)**
```bash
make dry-run
# OR
./scripts/layered-deploy.sh --dry-run
```

### 5. Connect to Your Server

After deployment completes, you'll see:

```
Public IP: 44.226.98.196
FQDN:      quake.alexflux.com
Connect:   quake.alexflux.com:27960
```

**To play OpenArena:**

1. Download OpenArena client from https://openarena.ws/
2. Install and launch the game
3. Press `~` to open console
4. Type: `/connect quake.alexflux.com` (or use the IP address)
5. Press Enter

**Note**: OpenArena is a native desktop game client, NOT a web browser game. You need to download and install the game client to connect.

## 📁 Project Structure

```
openarena-aws/
├── terraform/                 # Infrastructure as Code
│   ├── modules/
│   │   ├── openarena/         # Game server module
│   │   │   ├── main.tf        # EC2, EIP, Security Groups, Python 3.8 setup
│   │   │   ├── variables.tf
│   │   │   └── versions.tf    # Provider declarations (AWS, Cloudflare)
│   │   └── cost/              # Security & cost monitoring module
│   │       ├── cloudtrail.tf  # Audit logging
│   │       ├── guardduty.tf   # Threat detection (optional)
│   │       ├── vpc_flow_logs.tf
│   │       ├── budgets.tf     # Cost budgets
│   │       ├── anomaly_detection.tf
│   │       └── s3_buckets.tf  # Encrypted storage
│   ├── main.tf
│   ├── variables.tf
│   ├── providers.tf
│   └── terraform.tfvars       # Your config (gitignored)
├── ansible/                   # Configuration management
│   ├── playbooks/
│   │   └── site.yml           # Main playbook
│   ├── roles/
│   │   ├── openarena/         # Game server setup
│   │   │   ├── tasks/main.yml # Install OpenArena, configure systemd
│   │   │   ├── templates/
│   │   │   │   ├── openarena.service.j2
│   │   │   │   └── server.cfg.j2
│   │   │   └── defaults/main.yml
│   │   └── cloudwatch_agent/
│   ├── inventory/hosts.ini    # Generated by deploy script
│   ├── ansible.cfg
│   └── files/
│       └── openarena-0.8.8.zip  # Game server binaries
├── scripts/                   # Deployment automation
│   ├── deploy.sh              # One-command full deployment
│   ├── layered-deploy.sh      # Step-by-step deployment
│   ├── redeploy.sh            # Tear down and rebuild
│   ├── destroy.sh             # Remove all infrastructure
│   ├── attach-iam-policy.sh   # Attach IAM policies
│   ├── security-scan.sh       # Security scanning
│   ├── validate-project.sh    # Validation checks
│   └── snyk-scan.sh           # Snyk vulnerability scan
├── .env                       # Environment variables (gitignored)
├── .env.example               # Template for .env
├── terraform.pem              # SSH private key (gitignored)
├── terraform.pub              # SSH public key (gitignored)
├── iam-policy-*.json          # IAM policy definitions
├── Makefile                   # Convenient commands
└── README.md                  # This file
```

## 🛠️ Available Commands

All commands can be run via Make or directly:

| Command | Script | Description |
|---------|--------|-------------|
| `make deploy` | `scripts/deploy.sh` | Full deployment (one command) |
| `make layered-deploy` | `scripts/layered-deploy.sh` | Step-by-step deployment with confirmations |
| `make dry-run` | `scripts/layered-deploy.sh --dry-run` | Validate without deploying |
| `make redeploy` | `scripts/redeploy.sh` | Tear down and rebuild (with confirmations) |
| `make redeploy-auto` | `scripts/redeploy.sh --auto-approve` | Tear down and rebuild (auto-approve) |
| `make destroy` | `scripts/destroy.sh` | Destroy all infrastructure |
| `make validate` | `scripts/validate-project.sh` | Comprehensive validation |
| `make security-scan` | `scripts/security-scan.sh` | Security-focused scan |
| `make snyk-scan` | `scripts/snyk-scan.sh` | Snyk vulnerability scan |
| `make quick-check` | Built-in | Fast validation (Terraform + Ansible syntax) |

## 🔐 Security Best Practices

### ✅ Implemented Security Features

1. **No Hardcoded Secrets**
   - All credentials in `.env` (gitignored)
   - Cloudflare token via environment variable
   - SSH keys in `.pem` files (gitignored)

2. **Network Security**
   - SSH access restricted to your IP only (`/32` CIDR)
   - Security groups properly configured
   - Public subnet with proper internet gateway routing

3. **Data Encryption**
   - S3 buckets encrypted at rest (AES-256)
   - CloudTrail logs encrypted
   - KMS keys for sensitive data

4. **Audit Logging**
   - CloudTrail enabled by default (FREE)
   - VPC Flow Logs optional
   - All S3 buckets with versioning

5. **Access Control**
   - Minimal IAM permissions
   - Separate IAM policies for different services
   - No wildcard resource permissions

### ⚠️ Security Checklist Before Deployment

- [ ] Update `ssh_allowed_cidr` to your actual public IP
- [ ] Never commit `.env`, `terraform.tfvars`, or `.pem` files
- [ ] Use strong SSH key pairs (minimum 2048-bit RSA)
- [ ] Confirm SNS subscription emails for cost alerts
- [ ] Review IAM policies before attaching
- [ ] Enable CloudTrail (FREE - already enabled by default)
- [ ] Regularly review CloudTrail logs for unauthorized access
- [ ] Keep Terraform state file secure (consider remote backend)

### 🔒 .gitignore Protection

The following files are automatically gitignored:
- `*.tfvars` (except `*.tfvars.example`)
- `*.pem`, `*.key` (SSH keys)
- `.env`, `.env.local`
- `.terraform/`, `*.tfstate`
- `terraform.pub`

**Verify protection:**
```bash
git check-ignore terraform.tfvars .env terraform.pem
# Should show all three files are ignored
```

## 💰 Cost Breakdown

### Base Cost (with defaults)

| Service | Monthly Cost | Notes |
|---------|--------------|-------|
| EC2 t2.micro | ~$8.50 | Free tier eligible (750 hrs/month) |
| EBS Storage | ~$0.80 | 8 GB GP2 volume |
| Elastic IP | $0 | Free while attached to running instance |
| Data Transfer | ~$0.90 | Outbound traffic (first 1 GB free) |
| CloudTrail | $0 | First trail is FREE |
| SNS | $0 | First 1,000 emails free |
| AWS Budgets | $0 | First 2 budgets free |
| **Total** | **~$11/month** | With optional features disabled |

### Optional Features (disabled by default to save money)

| Service | Monthly Cost | Enable in terraform.tfvars |
|---------|--------------|----------------------------|
| GuardDuty | $8-15 | `enable_guardduty = true` |
| VPC Flow Logs | $2-5 | `enable_vpc_flow_logs = true` |
| CloudWatch Logs | $0.50-2 | `enable_cloudwatch_logs = true` |

**Total with all features: ~$25/month**

### Cost Optimization Tips

1. **Stop the server when not playing** (saves ~$8.50/month):
   ```bash
   aws ec2 stop-instances --instance-ids i-xxxxx
   # Elastic IP remains attached (still FREE)
   # Start when needed: aws ec2 start-instances --instance-ids i-xxxxx
   ```

2. **Use spot instances** (70% cheaper):
   - Edit `terraform/modules/openarena/main.tf`
   - Add `instance_market_options` for spot pricing
   - Risk: Instance may be terminated if spot price increases

3. **Disable optional monitoring** (default):
   - GuardDuty: disabled (saves $10/month)
   - VPC Flow Logs: disabled (saves $3/month)
   - CloudWatch Logs: disabled (saves $1.50/month)

4. **Set billing alarms**:
   - Default threshold: $20/month
   - Adjust in `terraform.tfvars`: `billing_alarm_usd = 20`

## 🧪 Testing & Validation

### Pre-Deployment Validation

```bash
# Quick syntax check
make quick-check

# Comprehensive validation
make validate

# Security scan
make security-scan

# Dry-run deployment
make dry-run
```

### Post-Deployment Testing

```bash
# SSH to server
ssh -i terraform.pem ec2-user@quake.alexflux.com

# Check OpenArena service status
sudo systemctl status openarena

# View game server logs
sudo journalctl -u openarena -f

# Test UDP connectivity
nc -vzu quake.alexflux.com 27960

# Check DNS resolution
host quake.alexflux.com
```

## 🐛 Troubleshooting

### Common Issues

**1. Terraform Init Fails - Cloudflare Provider Error**
```
Error: Could not retrieve provider versions
```
**Solution**: Create `.env` file with `CLOUDFLARE_API_TOKEN="dummy"` even if not using Cloudflare.

**2. Ansible Fails - Python Version Error**
```
SyntaxError: invalid syntax (Python 3.7)
```
**Solution**: Already fixed! Python 3.8 is now auto-installed via EC2 user_data.

**3. Ansible Fails - DNF Backend Error**
```
Could not detect which major revision of dnf is in use
```
**Solution**: Already fixed! Now using `command` module instead of `yum` module.

**4. SSH Connection Refused**
```
Permission denied (publickey)
```
**Solution**:
- Verify SSH key path in `.env`: `SSH_PRIVATE_KEY_FILE="./terraform.pem"`
- Check key permissions: `chmod 400 terraform.pem`
- Ensure `ssh_key_name` in `terraform.tfvars` matches AWS key pair name

**5. Instance in Private Subnet**
```
Instance is not in public subnet
```
**Solution**: Already fixed! Terraform now:
- Filters for public subnets only (`map-public-ip-on-launch = true`)
- Excludes us-west-2d (t2.micro not supported)
- Auto-creates public subnet if none exist

**6. IAM Permission Errors**
```
not authorized to perform: iam:CreateRole
```
**Solution**: Run IAM policy attachment script:
```bash
./scripts/attach-iam-policy.sh
```

**7. OpenArena Service Not Starting**
```
ExitCode=203/EXEC
```
**Solution**: Already fixed! Now using correct binary path: `/opt/openarena-0.8.8/oa_ded.x86_64`

**8. Can't Access via Web Browser**

OpenArena is NOT a web-based game. You need the OpenArena game client:
- Download from: https://openarena.ws/
- Install and run the game
- Connect via console: `/connect quake.alexflux.com`

### Debug Commands

```bash
# Terraform debugging
export TF_LOG=DEBUG
terraform apply

# Ansible debugging
ansible-playbook -vvv playbooks/site.yml

# Check Terraform state
terraform show

# View resource details
terraform state list
terraform state show module.openarena.aws_instance.this

# SSH troubleshooting
ssh -v -i terraform.pem ec2-user@<ip-address>
```

## 🔄 Maintenance

### Update OpenArena Server

```bash
# SSH to server
ssh -i terraform.pem ec2-user@<ip-address>

# Stop service
sudo systemctl stop openarena

# Update game files (manual process)
# ...

# Restart service
sudo systemctl start openarena
```

### Update Infrastructure

```bash
# Pull latest changes
git pull

# Review changes
terraform plan

# Apply updates
terraform apply

# Re-run Ansible for config changes
cd ansible
ansible-playbook -i inventory/hosts.ini playbooks/site.yml
```

### Backup Important Data

```bash
# Backup Terraform state
cp terraform/terraform.tfstate terraform/terraform.tfstate.backup

# Backup configuration
tar -czf openarena-backup.tar.gz terraform.tfvars .env

# Store backups securely (encrypted, off-site)
```

## 📚 Additional Documentation

- **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - Complete deployment guide with cost breakdown
- **[terraform/SECURITY.md](terraform/SECURITY.md)** - Security best practices and hardening
- **[TODO.txt](TODO.txt)** - Future enhancements and roadmap

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Run validation: `make validate`
4. Run security scan: `make security-scan`
5. Ensure all tests pass
6. Submit pull request

## 📝 License

This project is for educational and personal use.

## 🙏 Acknowledgments

- OpenArena Team - Free, open-source Quake III Arena clone
- ioquake3 - Modern Quake III engine
- Terraform - Infrastructure as Code
- Ansible - Configuration management

---

**Project Status:** ✅ Production Ready

**Last Updated:** 2025-12-17

**Deployed Server:**
- Public IP: 44.226.98.196
- DNS: quake.alexflux.com:27960
- Region: us-west-2
- Instance ID: i-0ac363289310874d2

**Key Improvements in This Version:**
- ✅ Python 3.8 auto-install via EC2 user_data (fixes Ansible compatibility)
- ✅ Fixed public subnet detection and creation
- ✅ Fixed Ansible yum module DNF backend issues
- ✅ Fixed OpenArena systemd service binary path
- ✅ Comprehensive IAM policy setup scripts
- ✅ Enhanced security with proper gitignore protection
- ✅ Complete troubleshooting guide

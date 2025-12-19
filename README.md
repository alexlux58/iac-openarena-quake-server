# 🎮 Browser Game Arcade on AWS

**Deploy a complete browser-based game arcade on AWS with classic games like 2048, PvP Arena, Pac-Man, Super Mario Bros, and QuakeJS!**

[![Terraform](https://img.shields.io/badge/terraform-1.5+-blue.svg)](https://www.terraform.io/)
[![Ansible](https://img.shields.io/badge/ansible-2.9+-red.svg)](https://www.ansible.com/)
[![AWS](https://img.shields.io/badge/AWS-EC2-orange.svg)](https://aws.amazon.com/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

## ✨ Features

- 🎯 **Multi-Game Arcade** - Beautiful game selection screen with multiple browser games
- 🌐 **Browser-Based** - All games run directly in your browser, no downloads needed
- 🚀 **One-Command Deploy** - Full infrastructure and game deployment with `make deploy`
- 💰 **Cost-Optimized** - ~$11/month with optional features disabled
- 🔒 **Secure** - SSH restricted, encrypted storage, audit logging
- 📊 **Monitoring** - Cost budgets, anomaly detection, billing alarms
- 🎨 **Modern UI** - Responsive game selection interface
- 🐳 **Docker-Based** - QuakeJS runs in Docker for reliability

## 🎮 Available Games

| Game | Type | Players | Description |
|------|------|---------|-------------|
| **2048** | Puzzle | Single | Classic number merging puzzle game |
| **PvP Arena** | Action | 1-4 | Fast-paced multiplayer arena shooter |
| **Pac-Man** | Arcade | Single | Classic maze game with ghosts and dots |
| **Super Mario Bros** | Platformer | Single | HTML5 remake with all 32 original levels |
| **Snake** | Arcade | Single | Classic snake game - grow longer by eating food |
| **Tetris** | Puzzle | Single | Legendary puzzle game with falling blocks |
| **Pong** | Arcade | Single | The original arcade classic |
| **Flappy Bird** | Arcade | Single | Navigate through pipes in this addictive game |
| **Space Invaders** | Arcade | Single | Defend Earth from alien invaders |
| **Breakout** | Arcade | Single | Break all the bricks with your paddle |
| **Asteroids** | Arcade | Single | Destroy asteroids in space |
| **QuakeJS** | FPS | Multiplayer | Classic Quake/OpenArena in your browser - no downloads required |
| **Tic-Tac-Toe** | Puzzle | 2 Players | Classic strategy game - get three in a row |

## 🚀 Quick Start

### Prerequisites

- **AWS Account** with billing enabled
- **Terraform** >= 1.5.0 ([Install](https://developer.hashicorp.com/terraform/downloads))
- **Ansible** >= 2.9 ([Install](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html))
- **AWS CLI** configured ([Setup](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- **Git** for cloning the repository
- **QuakeJS Files** (see [QuakeJS Setup](#quakejs-setup) below)

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/openarena-aws.git
cd openarena-aws
```

### 2. Configure Environment

**Create `.env` file:**
```bash
cp .env.example .env
# Edit .env with your values
```

**Key variables:**
```bash
# AWS Configuration
AWS_REGION="us-west-2"
INSTANCE_TYPE="t2.micro"

# SSH Configuration
SSH_KEY_NAME="your-key-name"
SSH_PRIVATE_KEY_FILE="./terraform.pem"
SSH_ALLOWED_CIDR="YOUR_IP/32"  # Get with: curl ifconfig.me

# Cloudflare (optional - set to "dummy" if not using)
CLOUDFLARE_API_TOKEN="your-token-or-dummy"
CLOUDFLARE_ZONE_ID="your-zone-id"
CLOUDFLARE_ZONE_NAME="example.com"
CLOUDFLARE_SUBDOMAIN="games"
CLOUDFLARE_TTL="300"

# Cost Monitoring
LOG_BUCKET_NAME="your-audit-logs-YOUR_ACCOUNT_ID"
FLOWLOG_BUCKET_NAME="your-flowlogs-YOUR_ACCOUNT_ID"
CUR_BUCKET_NAME="your-cur-YOUR_ACCOUNT_ID"
BILLING_ALERT_EMAIL="your-email@example.com"
MONTHLY_BUDGET_USD="15"
```

**Get your AWS Account ID:**
```bash
aws sts get-caller-identity --query Account --output text
# Update bucket names in .env with your account ID
```

**Create `terraform/terraform.tfvars`:**
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

**Critical variables:**
```hcl
aws_region          = "us-west-2"
ssh_key_name        = "your-key-name"
ssh_allowed_cidr    = "YOUR_IP/32"

# S3 Bucket Names (MUST be globally unique - include your AWS Account ID)
log_bucket_name     = "your-audit-logs-YOUR_ACCOUNT_ID"
flowlog_bucket_name = "your-flowlogs-YOUR_ACCOUNT_ID"
cur_bucket_name     = "your-cur-YOUR_ACCOUNT_ID"

# Email for cost alerts (MUST CONFIRM SNS SUBSCRIPTION!)
billing_alert_email = "your-email@example.com"
```

### 3. Set Up IAM Permissions

```bash
# Attach required IAM policies
./scripts/attach-iam-policy.sh
```

This creates and attaches:
- `OpenArenaTerraformMonitoring` - SNS, Budgets, Cost Explorer, CUR
- `OpenArenaTerraformSecurity` - IAM, KMS, GuardDuty
- `OpenArenaTerraformCloudTrail` - CloudTrail management

**Also attach via AWS Console:**
- `AmazonEC2FullAccess`
- `AmazonS3FullAccess`
- `AmazonVPCFullAccess`

### 4. Deploy

```bash
# One-command deployment
make deploy

# OR step-by-step with confirmations
make layered-deploy
```

**Deployment takes ~8-10 minutes** and creates:
- EC2 instance (t2.micro)
- Elastic IP
- Security groups (SSH + HTTP)
- S3 buckets for logging
- CloudTrail audit logging
- Cost monitoring (budgets, alarms)
- All browser games deployed
- QuakeJS Docker container

### 5. Setup QuakeJS Files (Required for QuakeJS)

Before deploying, copy the required QuakeJS files to `ansible/files/`:

**Option 1: Use the setup script (if you have QuakeFiles directory)**
```bash
# If QuakeFiles is in ../QuakeFiles (relative to repo root)
./scripts/setup-quakejs-files.sh

# Or specify custom path
QUAKEFILES_DIR=/path/to/QuakeFiles ./scripts/setup-quakejs-files.sh
```

**Option 2: Manual copy**
```bash
# Copy pak0.pk3 (REQUIRED - ~450MB)
cp /path/to/QuakeFiles/pak0.pk3 ansible/files/pak0.pk3

# Copy Docker image tar (OPTIONAL but recommended - ~1GB)
cp /path/to/QuakeFiles/quakejs_images.tar ansible/files/quakejs_images.tar
```

**Note:** 
- `pak0.pk3` is **required** for QuakeJS to work
- `quakejs_images.tar` is optional - if not provided, deployment will attempt to pull from Docker Hub (may fail)

See `ansible/files/README.md` for more details.

### 6. Access Your Arcade

After deployment, visit:
- **Game Selection:** `http://games.alexflux.com` (or your IP)
- **QuakeJS:** `http://games.alexflux.com/quakejs/`
- **2048:** `http://games.alexflux.com/2048/`
- **PvP Arena:** `http://games.alexflux.com/pvp/`
- **Pac-Man:** `http://games.alexflux.com/pacman/`
- **Super Mario Bros:** `http://games.alexflux.com/mario/`

## 📁 Project Structure

```
openarena-aws/
├── terraform/                 # Infrastructure as Code
│   ├── modules/
│   │   ├── openarena/         # EC2, EIP, Security Groups
│   │   └── cost/              # Monitoring, budgets, CloudTrail
│   ├── main.tf
│   └── terraform.tfvars      # Your config (gitignored)
├── ansible/                   # Configuration management
│   ├── playbooks/
│   │   └── site.yml           # Main playbook
│   ├── roles/
│   │   └── web-game/          # Browser games deployment
│   │       ├── tasks/
│   │       │   ├── deploy-2048.yml
│   │       │   ├── deploy-pvp.yml
│   │       │   ├── deploy-pacman.yml
│   │       │   ├── deploy-mario.yml
│   │       │   └── docker-quakejs.yml
│   │       └── templates/
│   │           ├── game-selection.html.j2
│   │           └── nginx.conf.j2
│   └── inventory/
│       └── hosts.ini          # Generated by deploy script
├── scripts/                   # Deployment automation
│   ├── deploy.sh              # Full deployment
│   ├── layered-deploy.sh      # Step-by-step
│   └── destroy.sh             # Teardown
├── ansible/files/             # Game files (pak0.pk3, quakejs_images.tar)
│   └── README.md              # Instructions for required files
├── Makefile                   # Convenient commands
└── README.md                  # This file
```

## 🛠️ Available Commands

| Command | Description |
|---------|-------------|
| `make deploy` | Full deployment (Terraform + Ansible) |
| `make layered-deploy` | Step-by-step with confirmations |
| `make dry-run` | Validate without deploying |
| `make redeploy` | Tear down and rebuild |
| `make destroy` | Remove all infrastructure |
| `make validate` | Comprehensive validation |
| `make security-scan` | Security-focused scan |
| `make quick-check` | Fast syntax validation |

## 💰 Cost Breakdown

### Monthly Cost (Cost-Optimized Configuration)

| Service | Cost | Notes |
|---------|------|-------|
| EC2 t2.micro | $8.50 | Free tier eligible (750 hrs/month) |
| EBS Storage (8 GB) | $0.80 | GP2 volume |
| Data Transfer | $0.90 | Outbound traffic |
| CloudTrail | **FREE** | First trail is free |
| SNS | **FREE** | First 1,000 emails free |
| AWS Budgets | **FREE** | First 2 budgets free |
| **Total** | **~$11/month** | |

### Optional Features (Disabled by Default)

| Feature | Cost | Enable in terraform.tfvars |
|---------|------|---------------------------|
| GuardDuty | $10/month | `enable_guardduty = true` |
| VPC Flow Logs | $3/month | `enable_vpc_flow_logs = true` |
| CloudWatch Logs | $1.50/month | `enable_cloudwatch_logs = true` |

**Total with all features: ~$25/month**

### Cost Optimization Tips

1. **Stop server when not playing:**
   ```bash
   aws ec2 stop-instances --instance-ids $(terraform output -raw instance_id)
   # Saves ~$4-7/month if stopped 50% of the time
   ```

2. **Use free tier:** EC2 t2.micro is free tier eligible (750 hours/month)

3. **Disable optional features:** GuardDuty, VPC Flow Logs disabled by default

## 🔒 Security Features

- ✅ **SSH Access Restricted** - Only your IP can SSH (`/32` CIDR)
- ✅ **Encrypted Storage** - All S3 buckets encrypted (AES-256)
- ✅ **Audit Logging** - CloudTrail enabled (FREE)
- ✅ **Cost Monitoring** - Budgets, anomaly detection, billing alarms
- ✅ **No Hardcoded Secrets** - All credentials in `.env` (gitignored)
- ✅ **Minimal IAM Permissions** - Granular policies per service
- ✅ **HTTP Only** - No UDP ports exposed (browser-based games only)

### Security Checklist

- [ ] Update `ssh_allowed_cidr` to your actual public IP
- [ ] Never commit `.env`, `terraform.tfvars`, or `.pem` files
- [ ] Confirm SNS subscription emails for cost alerts
- [ ] Review IAM policies before attaching
- [ ] Enable CloudTrail (already enabled by default)
- [ ] Use Cloudflare API token with minimal permissions (DNS + Page Rules Edit)

### Security Best Practices

#### Credential Management

**AWS Credentials (in order of preference):**
1. **IAM Roles** - Use EC2 Instance Profiles or OIDC for CI/CD
2. **AWS SSO/CLI Profiles** - `aws configure sso`
3. **Environment Variables** - For CI/CD pipelines
4. **Local Credentials** - `~/.aws/credentials` (development only)

**Cloudflare API Token:**
- Use environment variable: `export CLOUDFLARE_API_TOKEN="your-token"`
- Set in `.env` file (gitignored)
- Never commit tokens to git

#### Files to NEVER Commit

- `*.tfvars` (except `*.tfvars.example`)
- `*.tfstate` and `*.tfstate.*`
- `.terraform/` directory
- `.env` files
- SSH keys (`.pem`, `.key`, `.pub`)
- Any files containing secrets

## 📊 Post-Deployment Configuration

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

### 3. Verify Deployment

```bash
# Get server details
cd terraform
terraform output

# Output includes:
# - public_ip: EC2 instance IP address
# - fqdn: DNS name (if Cloudflare configured)
# - ssh_user: SSH username (ec2-user)
```

**Test SSH connection:**
```bash
ssh -i terraform.pem ec2-user@$(terraform output -raw public_ip)

# Check web server status
sudo systemctl status nginx

# Check QuakeJS container status
sudo docker ps
sudo docker logs quakejs

# View web server logs
sudo journalctl -u nginx -f
```

**Test games:**
1. Open browser and go to: `http://<public_ip>` or `http://games.yourdomain.com`
2. Select a game from the menu (e.g., QuakeJS, 2048, PvP Arena)
3. Play directly in your browser!

## 🎮 Managing the Server

### Accessing Games

**Option 1: Direct IP**
```
URL: http://<public_ip>
Example: http://54.123.45.67
```

**Option 2: DNS (if Cloudflare configured)**
```
URL: http://games.example.com
QuakeJS: http://games.example.com/quakejs/
```

### Common Operations

**SSH into instance:**
```bash
ssh -i ~/.ssh/id_rsa ec2-user@<public_ip>
```

**Web server management:**
```bash
# Check web server status
sudo systemctl status nginx

# View web server logs
sudo journalctl -u nginx -f

# Restart web server
sudo systemctl restart nginx
```

**QuakeJS container management:**
```bash
# Check container status
sudo docker ps
sudo docker logs quakejs

# Restart QuakeJS container
cd /opt/quakejs
sudo docker-compose restart

# Stop QuakeJS container
sudo docker-compose down

# Start QuakeJS container
sudo docker-compose up -d
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
```

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

## 🎯 Adding New Games

Want to add more games? It's easy!

### Requirements

Games must be:
- ✅ **Pure HTML5/CSS/JavaScript** - No server-side code required
- ✅ **Available on GitHub** - As a zip download or git repository
- ✅ **No build process** - Or pre-built files available
- ✅ **Browser-compatible** - Works in modern browsers (Chrome, Firefox, Safari, Edge)
- ✅ **Open source** - With a permissive license

### Step-by-Step Guide

#### 1. Create Deployment Task

Create `ansible/roles/web-game/tasks/deploy-[gamename].yml`:

```yaml
---
# Deploy [Game Name] to /[gamename]/ subdirectory

- name: Create [Game Name] game directory
  ansible.builtin.file:
    path: "{{ web_game_dir }}/[gamename]"
    state: directory
    mode: "0755"
    owner: "{{ nginx_user }}"
    group: "{{ nginx_user }}"

- name: Download [Game Name] game
  ansible.builtin.get_url:
    url: https://github.com/user/repo/archive/refs/heads/master.zip
    dest: /tmp/[gamename]-master.zip
    mode: "0644"
  register: game_download

- name: Extract [Game Name] game
  ansible.builtin.unarchive:
    src: /tmp/[gamename]-master.zip
    dest: /tmp
    remote_src: true
    creates: /tmp/[gamename]-master

- name: Copy [Game Name] game files
  ansible.builtin.shell: |
    if [ -d /tmp/[gamename]-master ]; then
      find /tmp/[gamename]-master -mindepth 1 -maxdepth 1 -exec cp -r {} {{ web_game_dir }}/[gamename]/ \;
      chown -R {{ nginx_user }}:{{ nginx_user }} {{ web_game_dir }}/[gamename]/
    fi
  changed_when: true
```

#### 2. Add to Main Deployment

Edit `ansible/roles/web-game/tasks/main.yml`:

```yaml
- name: Deploy [Game Name] game
  ansible.builtin.include_tasks: deploy-[gamename].yml
```

#### 3. Add Game Card

Edit `ansible/roles/web-game/templates/game-selection.html.j2`:

```html
<a href="/[gamename]/" class="game-card">
    <span class="game-icon">🎮</span>
    <h2 class="game-title">[Game Name]</h2>
    <span class="badge singleplayer">Single Player</span>
    <span class="badge action">Action</span>
    <p class="game-description">
        [Game description]
    </p>
    <ul class="game-features">
        <li>Feature 1</li>
        <li>Feature 2</li>
    </ul>
    <span class="play-btn">Play Now →</span>
</a>
```

**Badge options:**
- `singleplayer` - Blue badge
- `multiplayer` - Green badge
- `puzzle` - Orange badge
- `action` - Red badge
- `arcade` - Purple badge
- `platformer` - Pink badge

#### 4. Add Nginx Route

Edit `ansible/roles/web-game/templates/nginx.conf.j2`:

```nginx
location /[gamename]/ {
    alias {{ web_game_dir }}/[gamename]/;
    try_files $uri $uri/ /[gamename]/index.html;
}
```

#### 5. Deploy

```bash
make deploy
```

## 🐛 Troubleshooting

### Common Issues

**1. Terraform init fails - Cloudflare provider error**
- **Solution:** Create `.env` with `CLOUDFLARE_API_TOKEN="dummy"` even if not using Cloudflare.

**2. Ansible fails - Python version error**
- **Solution:** Already fixed! Python 3.8 is auto-installed via EC2 user_data.

**3. SSH connection refused**
- **Solution:** 
  - Verify SSH key path in `.env`
  - Check key permissions: `chmod 400 terraform.pem`
  - Ensure `ssh_allowed_cidr` matches your IP
  - Wait 60 seconds after instance creation for SSH to be ready

**4. Games not loading**
- **Solution:**
  - Check Nginx is running: `sudo systemctl status nginx`
  - Verify files exist: `ls -la /var/www/html/[gamename]/`
  - Check Nginx logs: `sudo tail -f /var/log/nginx/error.log`
  - Test locally: `curl http://localhost/[gamename]/`

**5. QuakeJS not working**
- **Solution:**
  - Check Docker container: `sudo docker ps`
  - View container logs: `sudo docker logs quakejs`
  - Verify pak0.pk3 exists: `ls -lh /opt/quakejs/baseoa/pak0.pk3`
  - Restart container: `cd /opt/quakejs && sudo docker-compose restart`

**6. Terraform apply fails with "AccessDenied"**
- **Solution:**
  ```bash
  # Verify AWS credentials
  aws sts get-caller-identity
  
  # Check IAM permissions (need Admin or Power User)
  aws iam get-user --user-name <your-username>
  ```

**7. "Bucket name already exists" error**
- **Solution:** S3 bucket names are globally unique. Change bucket names in `.env` to include your account ID.

**8. Not receiving budget alert emails**
- **Solutions:**
  1. Check SNS subscription confirmation:
     ```bash
     aws sns list-subscriptions
     # Look for Status="PendingConfirmation"
     ```
  2. Check email spam folder
  3. Verify budget exists:
     ```bash
     aws budgets describe-budgets --account-id <account-id>
     ```

**9. CloudWatch Billing Alarm stuck in "INSUFFICIENT_DATA"**
- **Solutions:**
  1. Enable Billing Alerts (one-time): AWS Console → Billing → Preferences → Check "Receive CloudWatch Billing Alerts"
  2. Wait 15-30 minutes for metric to appear
  3. Verify in us-east-1 region

### Debug Commands

```bash
# Check Terraform state
cd terraform && terraform show

# SSH to server
ssh -i terraform.pem ec2-user@$(terraform output -raw public_ip)

# Check game server status
sudo systemctl status nginx
sudo docker ps  # Check QuakeJS container

# View logs
sudo journalctl -u nginx -f
sudo docker logs quakejs  # View QuakeJS container logs

# Test game URLs
curl http://localhost/2048/
curl http://localhost/pvp/
curl http://localhost/quakejs/  # Test QuakeJS
```

## 🤝 Contributing

We welcome contributions! Here's how to get started:

### 1. Fork and Clone

```bash
git clone https://github.com/yourusername/openarena-aws.git
cd openarena-aws
```

### 2. Create a Feature Branch

```bash
git checkout -b feature/add-new-game
```

### 3. Make Your Changes

- Add new games (see [Adding New Games](#-adding-new-games))
- Fix bugs
- Improve documentation
- Add features

### 4. Test Your Changes

```bash
# Validate syntax
make quick-check

# Comprehensive validation
make validate

# Security scan
make security-scan
```

### 5. Submit a Pull Request

- Write a clear description of your changes
- Reference any related issues
- Ensure all tests pass
- Update documentation if needed

### Contribution Guidelines

- **Code Style:** Follow existing Ansible/Terraform conventions
- **Documentation:** Update README.md for new features
- **Testing:** Test locally before submitting PR
- **Commits:** Write clear, descriptive commit messages

## 🌐 Cloudflare Configuration

### Setting Up Cloudflare DNS

If you want to use a custom domain (e.g., `games.alexflux.com`):

1. **Create Cloudflare API Token:**
   - Go to: https://dash.cloudflare.com/profile/api-tokens
   - Click "Create Token" → "Create Custom Token"
   - Permissions needed:
     - Zone → DNS → Edit
     - Zone → Page Rules → Edit
   - Zone Resources: Select your zone (`alexflux.com`)
   - Copy the token

2. **Add Token to `.env`:**
   ```bash
   CLOUDFLARE_API_TOKEN="your-token-here"
   CLOUDFLARE_ZONE_ID="your-zone-id"
   CLOUDFLARE_ZONE_NAME="alexflux.com"
   CLOUDFLARE_SUBDOMAIN="games"
   ```

3. **Configure SSL Mode:**
   - Root domain (`alexflux.com`): Set to Full/Full Strict in Cloudflare dashboard
   - Games subdomain (`games.alexflux.com`): Automatically set to Flexible via Page Rule
   - This allows Vercel (root) to use Full Strict while QuakeJS (games) uses Flexible

### Cloudflare Page Rule

The deployment automatically creates a Page Rule:
- **Target:** `games.alexflux.com/*`
- **SSL Mode:** Flexible
- This allows the root domain to use Full/Full Strict while games subdomain uses Flexible

## 📝 License

This project is for educational and personal use.

## 🙏 Acknowledgments

- **QuakeJS** - Browser-based Quake engine ([mazaclub/quakejs](https://github.com/mazaclub/quakejs))
- **OpenArena** - Free, open-source Quake III Arena clone (used for game assets)
- **2048** - [gabrielecirulli/2048](https://github.com/gabrielecirulli/2048)
- **PvP** - [kesiev/pvp](https://github.com/kesiev/pvp)
- **Pac-Man** - [GerardAlbajar/Pacman-js](https://github.com/GerardAlbajar/Pacman-js)
- **Super Mario Bros** - [umaim/Mario](https://github.com/umaim/Mario)
- **Terraform** - Infrastructure as Code
- **Ansible** - Configuration management

## 📞 Support

- **Issues:** [GitHub Issues](https://github.com/yourusername/openarena-aws/issues)
- **Discussions:** [GitHub Discussions](https://github.com/yourusername/openarena-aws/discussions)

---

**Made with ❤️ for the gaming community**

**Status:** ✅ Production Ready | **Last Updated:** 2025-12-19

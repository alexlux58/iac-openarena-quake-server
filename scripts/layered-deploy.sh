#!/usr/bin/env bash
# ============================================================================
# Layered Deployment Script - Step-by-Step Infrastructure Deployment
# ============================================================================
# Deploys infrastructure in layers with confirmation at each step
# Supports dry-run mode for validation without actual deployment
# ============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Defaults
DRY_RUN=false
SKIP_CONFIRM=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-confirm)
            SKIP_CONFIRM=true
            shift
            ;;
        --help)
            echo "Usage: $0 [--dry-run] [--skip-confirm]"
            echo ""
            echo "Options:"
            echo "  --dry-run       Validate and plan without applying changes"
            echo "  --skip-confirm  Skip confirmation prompts (use with caution)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

confirm() {
    if [ "$SKIP_CONFIRM" = true ]; then
        return 0
    fi
    local prompt="$1"
    read -p "$(echo -e ${YELLOW}$prompt${NC} [y/N]): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# ============================================================================
# Pre-flight Checks
# ============================================================================
echo "============================================================================"
echo "Layered Deployment Script"
echo "============================================================================"
echo ""

if [ "$DRY_RUN" = true ]; then
    log_info "DRY-RUN MODE: No changes will be applied"
    echo ""
fi

log_info "Running pre-flight checks..."

# Check prerequisites
for cmd in aws terraform ansible-playbook; do
    if ! command -v $cmd &> /dev/null; then
        log_error "$cmd not found. Please install it first."
        exit 1
    fi
done
log_success "All prerequisites installed"

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials not configured"
    exit 1
fi
log_success "AWS credentials configured"

# Check for .env file (optional for dry-run, required for actual deployment)
if [ ! -f .env ]; then
    if [ "$DRY_RUN" = true ]; then
        log_warning ".env file not found. Using terraform.tfvars for dry-run."
        log_info "For actual deployment, create .env from .env.example"
        # Set minimal defaults for dry-run
        SSH_PRIVATE_KEY_FILE="${SSH_PRIVATE_KEY_FILE:-~/.ssh/id_rsa}"
        SSH_USER="${SSH_USER:-ec2-user}"
    else
        log_error ".env file not found. Copy .env.example to .env and configure it."
        exit 1
    fi
else
    log_success ".env file found"
    source .env
    # Export environment variables for Terraform (especially Cloudflare token)
    # This ensures Terraform providers can access them
    [ -n "${CLOUDFLARE_API_TOKEN:-}" ] && export CLOUDFLARE_API_TOKEN
    [ -n "${AWS_REGION:-}" ] && export AWS_REGION
    [ -n "${AWS_PROFILE:-}" ] && export AWS_PROFILE
fi

# ============================================================================
# Layer 1: Terraform Validation & Planning
# ============================================================================
log_step "Layer 1: Terraform Validation & Planning"

cd terraform

log_info "Initializing Terraform..."
# Ensure Cloudflare token is available for Terraform provider
if [ -z "${CLOUDFLARE_API_TOKEN:-}" ] && [ "$DRY_RUN" = false ]; then
    log_warning "CLOUDFLARE_API_TOKEN not set. Cloudflare provider may fail if using Cloudflare DNS."
    log_info "Set CLOUDFLARE_API_TOKEN in .env file (or 'dummy' if not using Cloudflare)"
fi
terraform init -upgrade

log_info "Validating Terraform configuration..."
if terraform validate; then
    log_success "Terraform configuration is valid"
else
    log_error "Terraform validation failed"
    exit 1
fi

log_info "Formatting Terraform files..."
terraform fmt -recursive
log_success "Terraform files formatted"

log_info "Running Terraform plan..."
terraform plan -out=tfplan

if [ "$DRY_RUN" = true ]; then
    log_success "Dry-run complete: Terraform plan generated successfully"
    log_info "Review the plan above. No changes were applied."
    exit 0
fi

if ! confirm "Review the plan above. Continue with Layer 2 (Core Infrastructure)?"; then
    log_info "Deployment cancelled"
    exit 0
fi

# ============================================================================
# Layer 2: Core Infrastructure (EC2, Security Groups, EIP)
# ============================================================================
log_step "Layer 2: Core Infrastructure (EC2, Security Groups, EIP)"

log_info "Applying core infrastructure..."
terraform apply -target=module.openarena -auto-approve
log_success "Core infrastructure deployed"

PUBLIC_IP=$(terraform output -raw public_ip 2>/dev/null || echo "")
FQDN=$(terraform output -raw fqdn 2>/dev/null || echo "")
SSH_USER=$(terraform output -raw ssh_user 2>/dev/null || echo "ec2-user")

if [ -z "$PUBLIC_IP" ]; then
    log_error "Failed to get public IP from Terraform output"
    exit 1
fi

log_info "Core infrastructure details:"
echo "  Public IP: $PUBLIC_IP"
echo "  FQDN:      $FQDN"
echo "  SSH User:  $SSH_USER"

if ! confirm "Core infrastructure deployed. Continue with Layer 3 (Wait for SSH)?"; then
    log_info "Stopping deployment. Infrastructure is partially deployed."
    exit 0
fi

# ============================================================================
# Layer 3: Wait for SSH Availability
# ============================================================================
log_step "Layer 3: Wait for SSH Availability"

log_info "Waiting for SSH to become available (up to 5 minutes)..."
SSH_READY=false
for i in {1..60}; do
    if ssh -i "${SSH_PRIVATE_KEY_FILE}" \
        -o StrictHostKeyChecking=accept-new \
        -o ConnectTimeout=5 \
        -o BatchMode=yes \
        "${SSH_USER}@${PUBLIC_IP}" "echo ok" >/dev/null 2>&1; then
        SSH_READY=true
        break
    fi
    echo -n "."
    sleep 5
done
echo ""

if [ "$SSH_READY" = true ]; then
    log_success "SSH is available"
else
    log_warning "SSH not available after 5 minutes. Continuing anyway..."
fi

if ! confirm "SSH check complete. Continue with Layer 4 (Ansible Configuration)?"; then
    log_info "Stopping deployment. Infrastructure is ready but not configured."
    exit 0
fi

# ============================================================================
# Layer 4: Ansible Configuration
# ============================================================================
log_step "Layer 4: Ansible Configuration"

cd ../ansible

log_info "Generating Ansible inventory..."
cat > inventory/hosts.ini <<EOF
[quake]
${PUBLIC_IP} ansible_user=${SSH_USER} ansible_ssh_private_key_file=${SSH_PRIVATE_KEY_FILE}
EOF
log_success "Ansible inventory created"

log_info "Running Ansible playbook..."
if ansible-playbook -i inventory/hosts.ini playbooks/site.yml; then
    log_success "Ansible configuration complete"
else
    log_error "Ansible playbook failed"
    exit 1
fi

if ! confirm "Ansible configuration complete. Continue with Layer 5 (Cost Monitoring)?"; then
    log_info "Stopping deployment. Server is configured but cost monitoring not enabled."
    exit 0
fi

# ============================================================================
# Layer 5: Cost Monitoring (Optional)
# ============================================================================
log_step "Layer 5: Cost Monitoring Infrastructure"

cd terraform

log_info "Applying cost monitoring resources..."
# Apply cost module resources
terraform apply -target=module.cost -auto-approve
log_success "Cost monitoring deployed"

if ! confirm "Cost monitoring deployed. Continue with Layer 6 (Final Apply)?"; then
    log_info "Stopping deployment. Most infrastructure is deployed."
    exit 0
fi

# ============================================================================
# Layer 6: Final Apply (Any Remaining Resources)
# ============================================================================
log_step "Layer 6: Final Apply (Any Remaining Resources)"

log_info "Applying any remaining resources..."
terraform apply -auto-approve
log_success "All resources deployed"

cd ..

# ============================================================================
# Deployment Summary
# ============================================================================
echo ""
echo "============================================================================"
log_success "Deployment Complete!"
echo "============================================================================"
echo ""
echo "Server Information:"
echo "  Public IP: $PUBLIC_IP"
echo "  FQDN:      $FQDN"
echo "  SSH User:  $SSH_USER"
echo ""
echo "Game Server Connection:"
echo "  $FQDN:27960"
echo ""
echo "SSH Connection:"
echo "  ssh -i ${SSH_PRIVATE_KEY_FILE} ${SSH_USER}@${PUBLIC_IP}"
echo ""


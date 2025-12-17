#!/usr/bin/env bash
# ============================================================================
# Redeploy Script - Tear Down and Bring Up Infrastructure
# ============================================================================
# This script destroys existing infrastructure and then redeploys it
# Useful for testing, updates, or complete infrastructure refresh
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

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

# Defaults
SKIP_DESTROY=false
SKIP_DEPLOY=false
AUTO_APPROVE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-destroy)
            SKIP_DESTROY=true
            shift
            ;;
        --skip-deploy)
            SKIP_DEPLOY=true
            shift
            ;;
        --auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-destroy   Skip the destroy step (only deploy)"
            echo "  --skip-deploy    Skip the deploy step (only destroy)"
            echo "  --auto-approve   Skip confirmation prompts"
            echo "  --help           Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

confirm() {
    if [ "$AUTO_APPROVE" = true ]; then
        return 0
    fi
    local prompt="$1"
    read -p "$(echo -e ${YELLOW}$prompt${NC} [y/N]): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

echo "============================================================================"
echo "Redeploy Script - Tear Down and Bring Up Infrastructure"
echo "============================================================================"
echo ""

# Pre-flight checks
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

# Check for .env file
if [ ! -f .env ]; then
    log_error ".env file not found. Copy .env.example to .env and configure it."
    exit 1
fi
log_success ".env file found"
source .env

# Export environment variables for Terraform
export TF_IN_AUTOMATION=1
export AWS_REGION="${AWS_REGION}"
[[ -n "${AWS_PROFILE:-}" ]] && export AWS_PROFILE
[ -n "${CLOUDFLARE_API_TOKEN:-}" ] && export CLOUDFLARE_API_TOKEN

# ============================================================================
# Step 1: Destroy Existing Infrastructure
# ============================================================================
if [ "$SKIP_DESTROY" = false ]; then
    log_step "Step 1: Destroying Existing Infrastructure"
    
    if ! confirm "This will DESTROY all infrastructure. Are you sure you want to continue?"; then
        log_info "Redeploy cancelled"
        exit 0
    fi
    
    log_info "Destroying infrastructure..."
    cd terraform
    
    log_info "Initializing Terraform..."
    terraform init -upgrade > /dev/null 2>&1
    
    log_info "Running terraform destroy..."
    if terraform destroy -auto-approve; then
        log_success "Infrastructure destroyed successfully"
    else
        log_warning "Destroy completed with warnings (this may be normal if infrastructure doesn't exist)"
    fi
    
    cd ..
    echo ""
else
    log_info "Skipping destroy step (--skip-destroy)"
fi

# ============================================================================
# Step 2: Deploy New Infrastructure
# ============================================================================
if [ "$SKIP_DEPLOY" = false ]; then
    log_step "Step 2: Deploying New Infrastructure"
    
    if ! confirm "Ready to deploy new infrastructure. Continue?"; then
        log_info "Deployment cancelled"
        exit 0
    fi
    
    log_info "Deploying infrastructure..."
    
    # Use the existing deploy script
    if ./scripts/deploy.sh; then
        log_success "Infrastructure deployed successfully"
    else
        log_error "Deployment failed"
        exit 1
    fi
else
    log_info "Skipping deploy step (--skip-deploy)"
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "============================================================================"
log_success "Redeploy Complete!"
echo "============================================================================"
echo ""

if [ "$SKIP_DEPLOY" = false ]; then
    cd terraform
    PUBLIC_IP=$(terraform output -raw public_ip 2>/dev/null || echo "N/A")
    FQDN=$(terraform output -raw fqdn 2>/dev/null || echo "N/A")
    SSH_USER=$(terraform output -raw ssh_user 2>/dev/null || echo "ec2-user")
    cd ..
    
    echo "Server Information:"
    echo "  Public IP: $PUBLIC_IP"
    echo "  FQDN:      $FQDN"
    echo "  SSH User:  $SSH_USER"
    echo ""
    echo "Game Server Connection:"
    echo "  $FQDN:27960"
    echo ""
fi


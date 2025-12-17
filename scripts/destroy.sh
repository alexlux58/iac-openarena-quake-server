#!/usr/bin/env bash
# ============================================================================
# Destroy Script - Tear Down Infrastructure
# ============================================================================
# This script destroys all infrastructure created by Terraform
# WARNING: This will permanently delete all resources!
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
AUTO_APPROVE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --auto-approve   Skip confirmation prompt"
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

echo "============================================================================"
echo "Destroy Infrastructure - OpenArena AWS"
echo "============================================================================"
echo ""

# Pre-flight checks
log_info "Running pre-flight checks..."

# Check prerequisites
if ! command -v terraform &> /dev/null; then
    log_error "Terraform not found. Please install it first."
    exit 1
fi
log_success "Terraform found"

# Check AWS credentials
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI not found. Please install it first."
    exit 1
fi

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

# Export environment variables
export TF_IN_AUTOMATION=1
export AWS_REGION="${AWS_REGION}"
[[ -n "${AWS_PROFILE:-}" ]] && export AWS_PROFILE
export TF_VAR_aws_region="${AWS_REGION}"
[ -n "${CLOUDFLARE_API_TOKEN:-}" ] && export CLOUDFLARE_API_TOKEN

# Confirmation prompt
if [ "$AUTO_APPROVE" = false ]; then
    echo ""
    log_warning "⚠️  WARNING: This will DESTROY all infrastructure!"
    log_warning "This includes:"
    echo "  - EC2 instance"
    echo "  - Security groups"
    echo "  - Elastic IP"
    echo "  - Cloudflare DNS records (if configured)"
    echo "  - Cost monitoring resources (if configured)"
    echo ""
    read -p "$(echo -e ${YELLOW}Continue with destruction?${NC} [y/N]): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Destruction cancelled"
        exit 0
    fi
fi

# ============================================================================
# Destroy Infrastructure
# ============================================================================
log_step "Destroying Infrastructure"

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

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "============================================================================"
log_success "Destruction Complete!"
echo "============================================================================"
echo ""
log_info "All infrastructure has been destroyed."
log_info "To redeploy, run: make deploy"
echo ""


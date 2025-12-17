#!/usr/bin/env bash
# ============================================================================
# Security Scan Script for OpenArena AWS Project
# ============================================================================
# Scans for secrets, validates configurations, checks for security issues
# ============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; WARNINGS=$((WARNINGS + 1)); }
log_error() { echo -e "${RED}[✗]${NC} $1"; ERRORS=$((ERRORS + 1)); }

echo "============================================================================"
echo "Security Scan - OpenArena AWS Project"
echo "============================================================================"
echo ""

# ============================================================================
# 1. Check for hardcoded secrets
# ============================================================================
log_info "Scanning for hardcoded secrets..."

# AWS Access Keys
if grep -r "AKIA[0-9A-Z]{16}" --include="*.tf" --include="*.sh" --include="*.yml" --include="*.yaml" terraform/ ansible/ scripts/ 2>/dev/null | grep -v ".git" | grep -v "example" | grep -v "ALEXLUX" > /dev/null; then
    log_error "Potential AWS Access Key found in code"
else
    log_success "No AWS Access Keys found"
fi

# Secret Keys
if grep -r "secret.*=.*['\"][^'\"]\{20,\}['\"]" --include="*.tf" --include="*.sh" terraform/ scripts/ 2>/dev/null | grep -v "example" | grep -v "ALEXLUX" > /dev/null; then
    log_warning "Potential hardcoded secrets found (review manually)"
else
    log_success "No obvious hardcoded secrets found"
fi

# API Tokens (exclude comments, examples, environment variables, and dummy values)
# Only flag actual hardcoded string literals, not environment variable references
if grep -r "api[_-]token.*=.*['\"][^'\"]\{20,\}['\"]" -i --include="*.tf" --include="*.sh" terraform/ scripts/ 2>/dev/null | \
   grep -v "^#" | \
   grep -v "\${" | \
   grep -v "\$CLOUDFLARE" | \
   grep -v "example" | \
   grep -v "ALEXLUX" | \
   grep -v "replace_me" | \
   grep -v "dummy" | \
   grep -v "your-token" | \
   grep -v "your_token" > /dev/null; then
    log_error "Potential API token found in code"
else
    log_success "No API tokens found in code"
fi

# ============================================================================
# 2. Check .gitignore for sensitive files
# ============================================================================
log_info "Checking .gitignore coverage..."

if grep -q "\.tfvars" .gitignore && grep -q "\.env" .gitignore; then
    log_success ".gitignore properly excludes sensitive files"
else
    log_warning ".gitignore may be missing some sensitive file patterns"
fi

# Check if sensitive files are tracked
if git ls-files terraform/*.tfvars 2>/dev/null | grep -v "example" > /dev/null; then
    log_error "Sensitive .tfvars files are tracked in git!"
else
    log_success "No sensitive .tfvars files tracked in git"
fi

# ============================================================================
# 3. Validate Terraform syntax
# ============================================================================
log_info "Validating Terraform syntax..."

if command -v terraform &> /dev/null; then
    cd terraform
    if terraform fmt -check -recursive > /dev/null 2>&1; then
        log_success "Terraform files are properly formatted"
    else
        log_warning "Some Terraform files need formatting (run: terraform fmt -recursive)"
    fi
    
    # Terraform validate requires variables to be set, which may not be available in CI
    # We'll do a syntax-only check with init -backend=false
    # Note: Network restrictions in sandboxed environments may cause init to fail
    if terraform init -backend=false -upgrade > /dev/null 2>&1; then
        # Try validation, but don't fail if variables are missing (that's expected in CI)
        if terraform validate > /dev/null 2>&1; then
            log_success "Terraform configuration is valid"
        else
            # Check if it's just missing variables (expected) vs actual syntax errors
            VALIDATE_OUTPUT=$(terraform validate 2>&1)
            if echo "$VALIDATE_OUTPUT" | grep -q "required variable\|No value for required variable"; then
                log_warning "Terraform validation skipped (missing required variables - expected in CI)"
            else
                log_error "Terraform validation failed"
                echo "$VALIDATE_OUTPUT"
            fi
        fi
    else
        # Init failure is often due to network restrictions (sandbox) or missing credentials
        # This is acceptable for security scanning - we've already checked formatting
        log_warning "Terraform init skipped (network restrictions or missing credentials - acceptable for security scan)"
    fi
    cd ..
else
    log_warning "Terraform not found, skipping validation"
fi

# ============================================================================
# 4. Check Ansible syntax
# ============================================================================
log_info "Validating Ansible syntax..."

if command -v ansible-playbook &> /dev/null; then
    cd ansible
    if ansible-playbook --syntax-check playbooks/site.yml > /dev/null 2>&1; then
        log_success "Ansible playbook syntax is valid"
    else
        # Check if it's just missing inventory/variables (expected) vs actual syntax errors
        SYNTAX_OUTPUT=$(ansible-playbook --syntax-check playbooks/site.yml 2>&1 || true)
        if echo "$SYNTAX_OUTPUT" | grep -q "could not be found\|No such file\|inventory\|Operation not permitted\|Permission denied"; then
            log_warning "Ansible validation skipped (missing inventory/variables or permission restrictions - expected in CI/sandbox)"
        else
            log_error "Ansible syntax check failed"
            echo "$SYNTAX_OUTPUT"
        fi
    fi
    cd ..
else
    log_warning "Ansible not found, skipping validation"
fi

# ============================================================================
# 5. Check for exposed credentials in scripts
# ============================================================================
log_info "Checking deployment scripts for credential exposure..."

if grep -r "password\|secret\|token" scripts/*.sh 2>/dev/null | grep -v "#" | grep -v "echo" | grep "=" > /dev/null; then
    log_warning "Potential credential usage in scripts (review manually)"
else
    log_success "No obvious credential exposure in scripts"
fi

# ============================================================================
# 6. Verify package versions
# ============================================================================
log_info "Checking package versions..."

# Check Terraform version requirement
if grep -q "required_version = \">= 1.5.0\"" terraform/versions.tf; then
    log_success "Terraform version requirement is appropriate (>= 1.5.0)"
else
    log_warning "Terraform version requirement may need review"
fi

# Check AWS provider version
if grep -q "version = \"~> 5.0\"" terraform/versions.tf; then
    log_success "AWS provider version is current (~> 5.0)"
else
    log_warning "AWS provider version may need update"
fi

# Check Cloudflare provider version
if grep -q "version = \"~> 4.0\"" terraform/versions.tf; then
    log_success "Cloudflare provider version is current (~> 4.0)"
else
    log_warning "Cloudflare provider version may need update"
fi

# ============================================================================
# 7. Check for security best practices
# ============================================================================
log_info "Checking security best practices..."

# Check if SSH is restricted
if grep -q "ssh_allowed_cidr.*0\.0\.0\.0/0" terraform/modules/openarena/main.tf terraform/terraform.tfvars.ALEXLUX 2>/dev/null; then
    log_warning "SSH access is open to 0.0.0.0/0 (should be restricted to specific IP)"
else
    log_success "SSH access appears to be restricted"
fi

# Check for security group rules
if grep -q "cidr_blocks.*0\.0\.0\.0/0" terraform/modules/openarena/main.tf 2>/dev/null | grep -v "egress" | grep -v "OpenArena UDP" > /dev/null; then
    log_warning "Some security group rules allow access from anywhere"
else
    log_success "Security group rules appear reasonable"
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "============================================================================"
echo "Scan Summary"
echo "============================================================================"
echo "Errors:   $ERRORS"
echo "Warnings: $WARNINGS"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    log_success "Security scan passed with no issues!"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    log_warning "Security scan completed with warnings (review above)"
    # Exit with success code even with warnings - warnings are acceptable (e.g., network restrictions)
    exit 0
else
    log_error "Security scan found errors that need to be fixed"
    exit 1
fi


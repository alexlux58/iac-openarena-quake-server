#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

IAM_USER="terraform"
AWS_ACCOUNT_ID="026600053230"

echo -e "${BLUE}Attaching IAM policies to user: $IAM_USER${NC}\n"

attach_policy() {
    local POLICY_NAME=$1
    local POLICY_FILE=$2
    local POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"
    
    echo -e "${YELLOW}$POLICY_NAME${NC}"
    if aws iam get-policy --policy-arn "$POLICY_ARN" &>/dev/null; then
        aws iam detach-user-policy --user-name "$IAM_USER" --policy-arn "$POLICY_ARN" 2>/dev/null || true
        aws iam delete-policy --policy-arn "$POLICY_ARN" || true
    fi
    aws iam create-policy --policy-name "$POLICY_NAME" --policy-document "file://$POLICY_FILE" &>/dev/null
    aws iam attach-user-policy --user-name "$IAM_USER" --policy-arn "$POLICY_ARN"
    echo -e "${GREEN}✓ Attached${NC}\n"
}

attach_policy "OpenArenaTerraformMonitoring" "iam-policy-terraform-monitoring.json"
attach_policy "OpenArenaTerraformSecurity" "iam-policy-terraform-security.json"
attach_policy "OpenArenaTerraformCloudTrail" "iam-policy-terraform-cloudtrail.json"

echo -e "${GREEN}SUCCESS! All 3 policies attached to $IAM_USER${NC}"

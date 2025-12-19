#!/usr/bin/env bash
# Helper script to import S3 bucket into Terraform state
# This script sources .env to get the Cloudflare token needed for provider initialization

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source .env file to get environment variables
cd "$ROOT_DIR"
source .env

# Export Cloudflare token for Terraform provider
export CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN}"

# Import the bucket
cd "$SCRIPT_DIR"
echo "Importing S3 bucket into Terraform state..."
terraform import module.cost.aws_s3_bucket.log_bucket alexflux-audit-logs-026600053230

echo "✅ Bucket imported successfully!"
echo "You can now run 'make deploy' from the project root."


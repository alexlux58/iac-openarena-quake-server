provider "aws" {
  region = var.aws_region

  # Enterprise Security Best Practices:
  # 1. Use IAM roles (instance profiles, OIDC, assume role) - NO credentials needed
  # 2. Use AWS SSO/CLI profiles - credentials managed by AWS CLI
  # 3. Use environment variables: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN
  # 4. Use ~/.aws/credentials and ~/.aws/config (for local development only)
  # 5. NEVER hardcode credentials in code or commit to version control
  #
  # The AWS provider automatically uses the AWS credential chain in this order:
  # - Environment variables
  # - Shared credentials file (~/.aws/credentials)
  # - Shared config file (~/.aws/config)
  # - Container credentials (ECS task roles)
  # - Instance profile credentials (EC2 instance roles)
  # - Web identity token (EKS, OIDC)
}

# Cloudflare Provider Configuration
# Cloudflare is OPTIONAL - only needed if you're using Cloudflare DNS
#
# IMPORTANT: Terraform initializes ALL providers listed in required_providers,
# so the Cloudflare provider will try to initialize even if you're not using it.
#
# Configuration Priority:
# 1. CLOUDFLARE_API_TOKEN environment variable (from .env file - recommended)
# 2. var.cloudflare_api_token Terraform variable (fallback)
#
# Usage:
# - If using Cloudflare: Set CLOUDFLARE_API_TOKEN in .env, set zone_id/zone_name in terraform.tfvars
# - If NOT using Cloudflare: 
#   * Set CLOUDFLARE_API_TOKEN="dummy" in .env (provider needs a value, but it won't be used)
#   * OR set cloudflare_zone_id="" and cloudflare_zone_name="" in terraform.tfvars
#   * The provider will initialize but no Cloudflare resources will be created
#
provider "cloudflare" {
  # Cloudflare provider authentication:
  # The provider will automatically use CLOUDFLARE_API_TOKEN environment variable
  # (which is exported from .env file by deploy.sh script).
  #
  # If you want to use a Terraform variable instead, uncomment the line below:
  # api_token = var.cloudflare_api_token
  #
  # IMPORTANT: The provider requires a token value during initialization, even if you're
  # not creating any Cloudflare resources. Set CLOUDFLARE_API_TOKEN in your .env file.
  # If not using Cloudflare, set it to "dummy" - it won't be validated until resources are created.
}


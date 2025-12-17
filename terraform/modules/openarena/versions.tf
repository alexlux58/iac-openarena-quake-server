# Terraform Version and Provider Requirements for OpenArena Module
# This file specifies which providers this module requires

terraform {
  required_providers {
    # AWS Provider - for managing AWS resources (EC2, VPC, Security Groups, etc.)
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    # Cloudflare Provider - for managing DNS records
    # IMPORTANT: Use cloudflare/cloudflare, NOT hashicorp/cloudflare
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

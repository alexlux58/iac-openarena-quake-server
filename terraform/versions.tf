# Terraform Version and Provider Requirements
# This file specifies the minimum Terraform version and required provider versions

terraform {
  # Minimum Terraform version required
  # Version 1.5.0+ includes improved error messages and features
  required_version = ">= 1.5.0"

  # Required providers and their versions
  required_providers {
    # AWS Provider - for managing AWS resources (EC2, VPC, Security Groups, etc.)
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Allows 5.x versions, excludes 6.0+
    }
    # Cloudflare Provider - for managing DNS records
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0" # Allows 4.x versions, excludes 5.0+
    }
  }
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "ssh_key_name" {
  description = "Name of the SSH key pair"
  type        = string
}

variable "create_key_pair" {
  description = "Whether to create a new SSH key pair"
  type        = bool
  default     = false
}

variable "ssh_public_key_file" {
  description = "Path to SSH public key file for key pair creation"
  type        = string
  default     = ""
}

variable "ssh_allowed_cidr" {
  description = "CIDR block allowed for SSH access"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID (optional - leave empty to skip Cloudflare DNS)"
  type        = string
  default     = ""
}

variable "cloudflare_zone_name" {
  description = "Cloudflare zone name (e.g. example.com) (optional - leave empty to skip Cloudflare DNS)"
  type        = string
  default     = ""
}

variable "cloudflare_subdomain" {
  description = "Cloudflare subdomain for the DNS record"
  type        = string
  default     = "quake"
}

variable "cloudflare_ttl" {
  description = "TTL for Cloudflare DNS records"
  type        = number
  default     = 300
}


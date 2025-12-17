# OpenArena Module Outputs
# These outputs expose values from resources created in this module
# They can be referenced by the root module or other modules

# Public IP address (Elastic IP)
# This is the static IP address players will connect to
output "public_ip" {
  description = "Public IP address of the EC2 instance (Elastic IP)"
  value       = aws_eip.this.public_ip
}

# Fully Qualified Domain Name (FQDN)
# The complete domain name for the game server (e.g., quake.alexflux.com)
# Returns "Use public_ip instead" if Cloudflare is not configured
output "fqdn" {
  description = "Fully qualified domain name for the game server (or 'Use public_ip instead' if Cloudflare not configured)"
  value       = var.cloudflare_zone_id != "" && var.cloudflare_zone_name != "" && var.cloudflare_zone_id != "your-zone-id-here" && var.cloudflare_zone_id != "replace_me" && !startswith(var.cloudflare_zone_id, "your-") && !startswith(var.cloudflare_zone_id, "replace") ? try(cloudflare_record.quake[0].hostname, "${var.cloudflare_subdomain}.${var.cloudflare_zone_name}") : "Use public_ip instead"
}

# SSH user for connecting to the instance
# Amazon Linux 2 uses 'ec2-user' as the default SSH user
output "ssh_user" {
  description = "SSH user for connecting to the EC2 instance (ec2-user for Amazon Linux 2)"
  value       = "ec2-user"
}

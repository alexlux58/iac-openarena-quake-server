# Root Module Outputs
# These outputs expose values from the openarena module
# They can be used by other modules or displayed after terraform apply

output "public_ip" {
  description = "Public IP address (Elastic IP) of the EC2 instance - use this to SSH or check server status"
  value       = module.openarena.public_ip
}

output "fqdn" {
  description = "Fully qualified domain name - players connect to this address (e.g., quake.alexflux.com)"
  value       = module.openarena.fqdn
}

output "ssh_user" {
  description = "SSH username for connecting to the EC2 instance (ec2-user for Amazon Linux 2)"
  value       = module.openarena.ssh_user
}

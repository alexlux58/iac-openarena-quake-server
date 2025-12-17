# OpenArena Infrastructure Module
# This module creates an EC2 instance with Elastic IP, Security Group, and Cloudflare DNS record
# for hosting an OpenArena (Quake) game server on AWS

# Data source to get the default VPC
# Amazon Linux instances need to be in a VPC (EC2-Classic is deprecated)
data "aws_vpc" "default" {
  default = true
}

# Data source to get PUBLIC subnets in the default VPC
# IMPORTANT: Filter for public subnets only (those with MapPublicIpOnLaunch = true)
# Private subnets won't work for EC2 Instance Connect or direct internet access
# ALSO: Exclude us-west-2d where t2.micro instances are not supported
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  # Only select PUBLIC subnets (those that auto-assign public IPs)
  # This excludes private subnets like RDS-Pvt-subnet-*
  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }

  # Exclude us-west-2d availability zone (t2.micro not supported there)
  # Only include us-west-2a, us-west-2b, us-west-2c
  filter {
    name   = "availability-zone"
    values = ["us-west-2a", "us-west-2b", "us-west-2c"]
  }
}

# Data source to get the default internet gateway
# Needed for creating a public subnet if none exists
data "aws_internet_gateway" "default" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Create a public subnet if none exist in supported AZs
# This ensures we always have a public subnet available for the EC2 instance
resource "aws_subnet" "public" {
  count = length(data.aws_subnets.default.ids) == 0 ? 1 : 0

  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.128.0/20" # Use unused CIDR range in default VPC
  availability_zone       = "us-west-2a"      # t2.micro supported AZ
  map_public_ip_on_launch = true              # Make it a public subnet

  tags = {
    Name = "openarena-public-subnet"
  }
}

# Create or update route table for the new subnet (if created)
resource "aws_route_table" "public" {
  count = length(data.aws_subnets.default.ids) == 0 ? 1 : 0

  vpc_id = data.aws_vpc.default.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.default.id
  }

  tags = {
    Name = "openarena-public-rt"
  }
}

# Associate the route table with the new subnet
resource "aws_route_table_association" "public" {
  count = length(data.aws_subnets.default.ids) == 0 ? 1 : 0

  subnet_id      = aws_subnet.public[0].id
  route_table_id = aws_route_table.public[0].id
}

# Data source to find the latest Amazon Linux 2 AMI
# Amazon Linux 2 is optimized for AWS and is free tier eligible
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"] # Official Amazon AMIs

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"] # HVM virtualization, x86_64, GP2 EBS
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Security Group for OpenArena server
# Controls inbound and outbound traffic to/from the EC2 instance
resource "aws_security_group" "openarena" {
  name   = "openarena-sg"
  vpc_id = data.aws_vpc.default.id

  # SSH access - restricted to specified CIDR block for security
  ingress {
    description = "SSH access for server administration"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  # OpenArena game server port (UDP)
  # Port 27960 is the default Quake/OpenArena server port
  ingress {
    description = "OpenArena game server (UDP port 27960)"
    from_port   = 27960
    to_port     = 27960
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"] # Allow from anywhere for game clients
  }

  # Allow all outbound traffic
  # Needed for package updates, DNS resolution, and game server communication
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # All protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "openarena-sg"
  }
}

# Optional: Create SSH key pair in AWS if requested
# If create_key_pair is false, assumes the key already exists in AWS
resource "aws_key_pair" "this" {
  count      = var.create_key_pair ? 1 : 0
  key_name   = var.ssh_key_name
  public_key = file(var.ssh_public_key_file)

  tags = {
    Name = "${var.cloudflare_subdomain}-key-pair"
  }
}

# Local values for computed values used across resources
locals {
  # Resolve SSH key name: use created key if create_key_pair is true, otherwise use provided name
  resolved_key_name = var.create_key_pair ? aws_key_pair.this[0].key_name : var.ssh_key_name

  # Use the first available PUBLIC subnet (avoiding us-west-2d where t2.micro is not supported)
  # If no public subnets exist, use the one we created
  # Public subnets in us-west-2: us-west-2a, us-west-2b, us-west-2c (supported), us-west-2d (NOT supported for t2.micro)
  subnet_id = length(data.aws_subnets.default.ids) > 0 ? data.aws_subnets.default.ids[0] : aws_subnet.public[0].id
}

# EC2 Instance - The game server
# Amazon Linux 2 AMI, configured with security group and SSH key
resource "aws_instance" "this" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type # t2.micro for free tier
  subnet_id              = local.subnet_id
  key_name               = local.resolved_key_name
  vpc_security_group_ids = [aws_security_group.openarena.id]

  # Install Python 3.8+ for Ansible compatibility
  # Amazon Linux 2 default Python 3.7 doesn't support modern Ansible modules
  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Install Python 3.8 from amazon-linux-extras
    amazon-linux-extras enable python3.8
    yum install -y python38 python38-pip

    # Make Python 3.8 the default python3
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.8 1

    # Verify installation
    python3 --version
  EOF

  tags = {
    Name = "openarena-server"
  }
}

# Elastic IP (EIP) - Static public IP address
# Needed because EC2 instances get new IPs on restart by default
# EIP ensures the DNS record always points to the correct IP
resource "aws_eip" "this" {
  domain = "vpc" # VPC domain (not EC2-Classic)
}

# Associate the Elastic IP with the EC2 instance
# This gives the instance a static public IP address
resource "aws_eip_association" "this" {
  instance_id   = aws_instance.this.id
  allocation_id = aws_eip.this.id
}

# Cloudflare DNS record (optional)
# Creates an A record pointing the subdomain to the Elastic IP
# This allows players to connect using a friendly domain name (e.g., quake.alexflux.com)
# Only created if cloudflare_zone_id is provided and is not a placeholder value
locals {
  # Check if zone_id is a valid value (not empty and not a placeholder)
  cloudflare_enabled = var.cloudflare_zone_id != "" && var.cloudflare_zone_name != "" && var.cloudflare_zone_id != "your-zone-id-here" && var.cloudflare_zone_id != "replace_me" && !startswith(var.cloudflare_zone_id, "your-") && !startswith(var.cloudflare_zone_id, "replace")
}

resource "cloudflare_record" "quake" {
  count = local.cloudflare_enabled ? 1 : 0

  zone_id = var.cloudflare_zone_id
  name    = var.cloudflare_subdomain # e.g., "quake"
  type    = "A"                      # IPv4 address record
  content = aws_eip.this.public_ip   # Point to the Elastic IP
  ttl     = var.cloudflare_ttl       # DNS cache TTL in seconds
  proxied = false                    # DNS-only, not proxied (needed for game traffic)
}

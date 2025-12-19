#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

source .env

# Get IP from Terraform output or use provided IP as argument
if [ -n "${1:-}" ]; then
  PUBLIC_IP="$1"
else
  cd terraform
  PUBLIC_IP="$(terraform output -raw public_ip)"
  cd ..
fi

SSH_USER="ec2-user"
SSH_PRIVATE_KEY_FILE="${SSH_PRIVATE_KEY_FILE:-terraform.pem}"

echo "Running Ansible against: ${PUBLIC_IP}"

cat > ansible/inventory/hosts.ini <<INVENTORY_EOF
[quake]
${PUBLIC_IP} ansible_user=${SSH_USER} ansible_ssh_private_key_file=${SSH_PRIVATE_KEY_FILE}
INVENTORY_EOF

cd ansible
ansible-playbook -i inventory/hosts.ini playbooks/site.yml
cd ..

echo ""
echo "✅ Ansible deployment complete!"
echo "Public IP: ${PUBLIC_IP}"


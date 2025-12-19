#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

source .env

export TF_IN_AUTOMATION=1
export AWS_REGION="${AWS_REGION}"
[[ -n "${AWS_PROFILE:-}" ]] && export AWS_PROFILE

# Export Cloudflare API token for provider authentication
export CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN}"

export TF_VAR_aws_region="${AWS_REGION}"
export TF_VAR_instance_type="${INSTANCE_TYPE}"
export TF_VAR_ssh_allowed_cidr="${SSH_ALLOWED_CIDR}"
export TF_VAR_cloudflare_api_token="${CLOUDFLARE_API_TOKEN}"
export TF_VAR_cloudflare_zone_id="${CLOUDFLARE_ZONE_ID}"
export TF_VAR_cloudflare_zone_name="${CLOUDFLARE_ZONE_NAME}"
export TF_VAR_cloudflare_subdomain="${CLOUDFLARE_SUBDOMAIN}"
export TF_VAR_cloudflare_ttl="${CLOUDFLARE_TTL}"
export TF_VAR_ssh_key_name="${SSH_KEY_NAME}"
export TF_VAR_create_key_pair="${CREATE_KEY_PAIR}"
export TF_VAR_ssh_public_key_file="${SSH_PUBLIC_KEY_FILE}"

pushd terraform >/dev/null
terraform init -upgrade
terraform apply -auto-approve
PUBLIC_IP="$(terraform output -raw public_ip)"
FQDN="$(terraform output -raw fqdn)"
SSH_USER="$(terraform output -raw ssh_user)"
popd >/dev/null

for i in {1..60}; do
  if ssh -i "${SSH_PRIVATE_KEY_FILE}" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 \
    "${SSH_USER}@${PUBLIC_IP}" "echo ok" >/dev/null 2>&1; then
    break
  fi
  sleep 5
done

cat > ansible/inventory/hosts.ini <<EOF
[quake]
${PUBLIC_IP} ansible_user=${SSH_USER} ansible_ssh_private_key_file=${SSH_PRIVATE_KEY_FILE}
EOF

pushd ansible >/dev/null
ansible-playbook -i inventory/hosts.ini playbooks/site.yml
popd >/dev/null

echo "Public IP: ${PUBLIC_IP}"
echo "FQDN:      ${FQDN}"
echo "Game Menu: http://${FQDN}"
echo "QuakeJS:   http://${FQDN}/quakejs/"


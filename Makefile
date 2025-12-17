SHELL := /bin/bash
.PHONY: deploy destroy redeploy validate security-scan snyk-scan layered-deploy dry-run

# Standard deployment
deploy:
	./scripts/deploy.sh

# Destroy infrastructure
destroy:
	./scripts/destroy.sh

# Redeploy: Tear down and bring up infrastructure
redeploy:
	./scripts/redeploy.sh

# Redeploy with auto-approve (no confirmations)
redeploy-auto:
	./scripts/redeploy.sh --auto-approve

# Validate project (no deployment)
validate:
	./scripts/validate-project.sh

# Security scan for secrets and issues
security-scan:
	./scripts/security-scan.sh

# Snyk security scan (requires Snyk CLI)
snyk-scan:
	./scripts/snyk-scan.sh

# Layered deployment with step-by-step confirmations
layered-deploy:
	./scripts/layered-deploy.sh

# Dry-run validation (plan only, no apply)
dry-run:
	./scripts/layered-deploy.sh --dry-run

# Full validation suite (runs all checks)
full-check: validate security-scan
	@echo "Full validation complete"

# Quick validation (fast checks only)
quick-check:
	@cd terraform && terraform fmt -check -recursive && terraform validate
	@cd ansible && ansible-playbook --syntax-check playbooks/site.yml


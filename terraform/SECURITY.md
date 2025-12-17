# Terraform Security Best Practices

## Credential Management

### AWS Credentials

**Enterprise Best Practices (in order of preference):**

1. **IAM Roles (Recommended for Production)**
   - Use EC2 Instance Profiles
   - Use OIDC for CI/CD (GitHub Actions, GitLab CI, etc.)
   - Use Assume Role for cross-account access
   - No credentials needed in code or environment

2. **AWS SSO / CLI Profiles**
   - Configure AWS SSO: `aws configure sso`
   - Use named profiles: `aws --profile myprofile`
   - Terraform automatically uses AWS credential chain

3. **Environment Variables** (for CI/CD)
   ```bash
   export AWS_ACCESS_KEY_ID="your-key"
   export AWS_SECRET_ACCESS_KEY="your-secret"
   export AWS_SESSION_TOKEN="your-token"  # if using temporary credentials
   ```

4. **Local Development Only**
   - `~/.aws/credentials` and `~/.aws/config`
   - Use separate profiles for different environments
   - Never commit these files

### Cloudflare API Token

**Enterprise Best Practices (in order of preference):**

1. **Environment Variable (Recommended)**
   ```bash
   export CLOUDFLARE_API_TOKEN="your-token"
   ```
   - Set in CI/CD pipeline secrets
   - Set in your shell for local development
   - Leave `var.cloudflare_api_token` empty/unset in terraform.tfvars

2. **Secret Management Systems**
   - AWS Secrets Manager
   - HashiCorp Vault
   - Azure Key Vault
   - Google Secret Manager
   - Retrieve via data sources or external scripts

3. **Terraform Cloud/Enterprise**
   - Use variable sets with sensitive flag
   - Managed by HashiCorp
   - Encrypted at rest and in transit

4. **Terraform Variables (Last Resort)**
   - Only for local development
   - Use `terraform.tfvars` (gitignored)
   - NEVER commit to version control

## File Security

### Files to NEVER Commit

- `*.tfvars` (except `*.tfvars.example`)
- `*.tfstate` and `*.tfstate.*`
- `.terraform/` directory
- Any files containing secrets, keys, or tokens
- `.env` files

### Gitignore Protection

The `.gitignore` file is configured to exclude:
- All `.tfvars` files (except examples)
- Terraform state files
- Sensitive key files
- Environment files

## CI/CD Integration

### GitHub Actions Example

```yaml
env:
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
  CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
```

### GitLab CI Example

```yaml
variables:
  AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY
  CLOUDFLARE_API_TOKEN: $CLOUDFLARE_API_TOKEN
```

### Using OIDC (Most Secure for CI/CD)

```yaml
# GitHub Actions with OIDC
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v2
  with:
    role-to-assume: arn:aws:iam::123456789012:role/github-actions
    aws-region: us-west-2
```

## Local Development Setup

1. Copy the example variables file:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Set environment variables:
   ```bash
   export CLOUDFLARE_API_TOKEN="your-token"
   # AWS credentials are automatically read from ~/.aws/credentials
   ```

3. Fill in non-sensitive variables in `terraform.tfvars`

4. Verify `.gitignore` excludes `terraform.tfvars`

## Compliance and Auditing

- Use Terraform Cloud/Enterprise for audit logs
- Enable AWS CloudTrail for API calls
- Use separate AWS accounts for different environments
- Rotate credentials regularly
- Use least-privilege IAM policies
- Enable MFA for all AWS accounts
- Review and audit access regularly


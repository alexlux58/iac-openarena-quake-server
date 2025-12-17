#!/bin/bash
# Script to check if required environment variables are set

echo "=== Environment Variable Check ==="
echo ""

# Check Cloudflare API Token
if [ -z "${CLOUDFLARE_API_TOKEN}" ]; then
    echo "❌ CLOUDFLARE_API_TOKEN is NOT set"
    echo "   Set it with: export CLOUDFLARE_API_TOKEN=\"your-token\""
else
    echo "✅ CLOUDFLARE_API_TOKEN is set"
    # Show first 4 and last 4 characters for verification (without exposing full token)
    token_length=${#CLOUDFLARE_API_TOKEN}
    if [ $token_length -gt 8 ]; then
        echo "   Token preview: ${CLOUDFLARE_API_TOKEN:0:4}...${CLOUDFLARE_API_TOKEN: -4}"
    else
        echo "   Token length: $token_length characters"
    fi
fi

echo ""

# Check AWS credentials (optional - AWS provider uses credential chain)
echo "=== AWS Credentials Check ==="
if [ -n "${AWS_ACCESS_KEY_ID}" ]; then
    echo "✅ AWS_ACCESS_KEY_ID is set (from environment)"
else
    echo "ℹ️  AWS_ACCESS_KEY_ID not in environment (checking credential files...)"
    if [ -f ~/.aws/credentials ]; then
        echo "   ✅ ~/.aws/credentials exists"
    else
        echo "   ⚠️  ~/.aws/credentials not found"
    fi
    if [ -f ~/.aws/config ]; then
        echo "   ✅ ~/.aws/config exists"
    else
        echo "   ⚠️  ~/.aws/config not found"
    fi
fi

echo ""
echo "=== Summary ==="
if [ -z "${CLOUDFLARE_API_TOKEN}" ]; then
    echo "⚠️  CLOUDFLARE_API_TOKEN is required for Cloudflare provider"
    exit 1
else
    echo "✅ All required environment variables are set"
    exit 0
fi


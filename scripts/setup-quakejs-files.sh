#!/usr/bin/env bash
# Setup script to copy QuakeJS files from QuakeFiles directory to ansible/files/
# Run this before deploying if you have QuakeFiles directory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
QUAKEFILES_DIR="${QUAKEFILES_DIR:-$ROOT_DIR/../QuakeFiles}"
FILES_DIR="$ROOT_DIR/ansible/files"

echo "Setting up QuakeJS files for deployment..."
echo "Source: $QUAKEFILES_DIR"
echo "Destination: $FILES_DIR"
echo ""

# Check if QuakeFiles directory exists
if [ ! -d "$QUAKEFILES_DIR" ]; then
    echo "⚠️  QuakeFiles directory not found at: $QUAKEFILES_DIR"
    echo "   Set QUAKEFILES_DIR environment variable to point to your QuakeFiles directory"
    echo "   Example: QUAKEFILES_DIR=/path/to/QuakeFiles ./scripts/setup-quakejs-files.sh"
    exit 1
fi

# Ensure ansible/files directory exists
mkdir -p "$FILES_DIR"

# Copy pak0.pk3 (required)
if [ -f "$QUAKEFILES_DIR/pak0.pk3" ]; then
    echo "📦 Copying pak0.pk3..."
    cp "$QUAKEFILES_DIR/pak0.pk3" "$FILES_DIR/pak0.pk3"
    echo "✅ pak0.pk3 copied successfully"
else
    echo "❌ ERROR: pak0.pk3 not found in $QUAKEFILES_DIR"
    echo "   This file is REQUIRED for QuakeJS to work"
    exit 1
fi

# Copy quakejs_images.tar (optional but recommended)
if [ -f "$QUAKEFILES_DIR/quakejs_images.tar" ]; then
    echo "🐳 Copying quakejs_images.tar..."
    cp "$QUAKEFILES_DIR/quakejs_images.tar" "$FILES_DIR/quakejs_images.tar"
    echo "✅ quakejs_images.tar copied successfully"
    echo "   Note: This file is optional. If not present, deployment will try to pull from Docker Hub"
else
    echo "⚠️  WARNING: quakejs_images.tar not found in $QUAKEFILES_DIR"
    echo "   Deployment will attempt to pull Docker image from Docker Hub"
    echo "   This may fail if the image doesn't exist publicly"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "Files ready for deployment:"
ls -lh "$FILES_DIR"/*.pk3 "$FILES_DIR"/*.tar 2>/dev/null || true
echo ""
echo "You can now run: make deploy"


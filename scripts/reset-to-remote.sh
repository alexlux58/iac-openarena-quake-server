#!/usr/bin/env bash
# Reset local repository to match remote HEAD
# WARNING: This will discard ALL local changes!

set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "=== Reset to Remote HEAD ==="
echo ""
echo "WARNING: This will discard ALL local changes!"
echo ""

# Check current status
echo "Current git status:"
git status --short
echo ""

# Ask for confirmation
read -p "Are you sure you want to reset to remote HEAD? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Fetching latest from remote..."
git fetch origin

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: $CURRENT_BRANCH"
echo ""

# Reset to remote HEAD
echo "Resetting to origin/$CURRENT_BRANCH..."
git reset --hard "origin/$CURRENT_BRANCH"

# Clean untracked files (optional - uncomment if you want to remove untracked files too)
# echo "Cleaning untracked files..."
# git clean -fd

echo ""
echo "✓ Reset complete!"
echo ""
echo "Current status:"
git status --short


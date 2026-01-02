#!/bin/bash

# CRM Workspace - Clone All Repositories
# Usage: ./clone-all.sh

set -e

echo "=== CRM Platform - Cloning All Repositories ==="
echo ""

REPOS=(
    "crm-backend"
    "crm-admin"
    "web-booking"
    "v0-modern-lp-design"
)

GITHUB_ORG="plus61"

for repo in "${REPOS[@]}"; do
    if [ -d "$repo" ]; then
        echo "[$repo] Already exists, pulling latest..."
        cd "$repo"
        git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || echo "  Warning: Could not pull"
        cd ..
    else
        echo "[$repo] Cloning..."
        git clone "https://github.com/${GITHUB_ORG}/${repo}.git"
    fi
    echo ""
done

echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. cp .env.example .env"
echo "  2. Edit .env with your credentials"
echo "  3. docker-compose up -d  (or start each service manually)"
echo ""

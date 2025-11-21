#!/bin/bash

################################################################################
# Resolve Git Merge Conflict
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warning() { echo -e "${YELLOW}[!]${NC} $1"; }

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║           Resolve Merge Conflict                              ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

warning "You have local changes that conflict with remote changes"
echo ""
info "Options:"
echo "  1. Keep remote changes (recommended - has all the fixes)"
echo "  2. Keep local changes"
echo "  3. Cancel and review differences"
echo ""

read -p "Choose option (1/2/3): " -n 1 -r CHOICE
echo ""

case $CHOICE in
    1)
        info "Keeping remote changes (has analytics fixes)..."
        git stash push -m "Local changes before analytics fix"
        success "Local changes stashed"

        info "Pulling latest changes..."
        git pull origin claude/self-hosted-supabase-setup-013rsokCVPnLpeDgAX8ax3BX
        success "Updated to latest version with analytics fixes"

        echo ""
        info "Your local changes are saved in stash"
        info "To see what was stashed: git stash show -p stash@{0}"
        info "To apply stashed changes: git stash pop"
        echo ""
        success "Ready to run: ./restart-with-analytics-fix.sh"
        ;;
    2)
        info "Keeping local changes..."
        info "Creating backup of local docker-compose.yml..."
        cp docker-compose.yml docker-compose.yml.local.backup
        success "Backup saved: docker-compose.yml.local.backup"

        info "Resetting to remote version..."
        git reset --hard origin/claude/self-hosted-supabase-setup-013rsokCVPnLpeDgAX8ax3BX

        info "Restoring your local changes..."
        cp docker-compose.yml.local.backup docker-compose.yml
        success "Local changes restored"

        warning "Note: You're using local version - may be missing analytics fixes"
        ;;
    3)
        info "Showing differences..."
        echo ""
        git diff docker-compose.yml
        echo ""
        info "Run this script again when ready"
        exit 0
        ;;
    *)
        warning "Invalid choice"
        exit 1
        ;;
esac

echo ""

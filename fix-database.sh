#!/bin/bash

################################################################################
# Database Fix Script
# Fixes the pgsodium initialization error by clearing old data
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║              Database Initialization Fix                      ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

warning "This script will:"
echo "  1. Stop all Supabase containers"
echo "  2. Clear old database data (DESTRUCTIVE)"
echo "  3. Fix directory permissions"
echo "  4. Restart services with fresh database"
echo ""
echo "⚠️  ALL EXISTING DATABASE DATA WILL BE LOST!"
echo ""

read -p "Do you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Aborted. No changes made."
    exit 0
fi

echo ""
info "Step 1: Stopping all containers..."
docker compose down
success "Containers stopped"

echo ""
info "Step 2: Clearing old database data..."
if [ -d "volumes/db/data" ]; then
    info "Backing up old data to volumes/db/data.old.$(date +%Y%m%d_%H%M%S)..."
    mv volumes/db/data "volumes/db/data.old.$(date +%Y%m%d_%H%M%S)"
    success "Old data backed up"
else
    info "No old data directory found"
fi

# Create fresh data directory
mkdir -p volumes/db/data
success "Fresh data directory created"

echo ""
info "Step 3: Fixing directory permissions..."
# PostgreSQL runs as user 999:999 in the container
sudo chown -R 999:999 volumes/db/
success "Permissions fixed"

echo ""
info "Step 4: Starting services..."
docker compose up -d

echo ""
info "Waiting for services to start (30 seconds)..."
sleep 30

echo ""
info "Checking database health..."
if docker exec supabase-db pg_isready -U postgres > /dev/null 2>&1; then
    success "Database is healthy!"
    echo ""
    info "Checking container status..."
    docker compose ps
else
    error "Database is not responding"
    echo ""
    info "Checking logs..."
    docker logs supabase-db --tail 50
    exit 1
fi

echo ""
success "Database fix complete!"
echo ""
info "Next steps:"
echo "  1. Check all services: docker compose ps"
echo "  2. Run health check: ./health-check.sh"
echo "  3. Access Studio: https://studio.qoqnuz.com"
echo ""

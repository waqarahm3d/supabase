#!/bin/bash

################################################################################
# Cleanup and Status Check
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warning() { echo -e "${YELLOW}[!]${NC} $1"; }

echo "Cleaning up orphan containers and checking status..."
echo ""

info "Removing orphan containers (supabase-vector)..."
docker compose down --remove-orphans
success "Orphans removed"

echo ""
info "Starting all services..."
docker compose up -d

echo ""
info "Waiting 30 seconds for initial startup..."
sleep 30

echo ""
info "Current service status:"
docker compose ps

echo ""
info "Checking critical services..."

# Database
if docker exec supabase-db pg_isready -U postgres > /dev/null 2>&1; then
    success "Database: HEALTHY ✓"
else
    warning "Database: NOT READY"
fi

# Analytics
if docker exec supabase-analytics curl -sf http://localhost:4000/health > /dev/null 2>&1; then
    success "Analytics: HEALTHY ✓"
else
    warning "Analytics: Still initializing (this is OK, check in 2-3 minutes)"
    info "    Run: docker logs supabase-analytics --tail 50"
fi

# Auth
if docker exec supabase-auth wget -q --spider http://localhost:9999/health 2>/dev/null; then
    success "Auth: HEALTHY ✓"
else
    warning "Auth: Still starting..."
fi

# Studio
if docker ps | grep supabase-studio | grep -q "Up"; then
    success "Studio: RUNNING ✓"
    info "    Access at: https://studio.qoqnuz.com (after SSL setup)"
else
    warning "Studio: Not started"
fi

echo ""
info "To monitor logs for any service:"
echo "    docker logs supabase-<service-name> -f"
echo ""
info "To see detailed status:"
echo "    docker compose ps"
echo ""

#!/bin/bash

################################################################################
# Check and Fix Database Initialization
# Expert approach: Verify then fix
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }
warning() { echo -e "${YELLOW}[!]${NC} $1"; }
section() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}\n"; }

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║        Database Initialization Check & Fix                    ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

section "Step 1: Check Current Database State"

info "Checking if database is running..."
if ! docker exec supabase-db pg_isready -U postgres > /dev/null 2>&1; then
    error "Database is not running!"
    exit 1
fi
success "Database is running"

info "Checking if required roles exist..."
ROLES=$(docker exec supabase-db psql -U postgres -t -c "SELECT string_agg(rolname, ', ') FROM pg_roles WHERE rolname IN ('supabase_admin', 'supabase_auth_admin', 'supabase_storage_admin', 'authenticator', 'anon', 'service_role');" 2>/dev/null | xargs)

if [ -z "$ROLES" ]; then
    error "NO ROLES FOUND - Database was not initialized properly"
    NEEDS_INIT=true
else
    success "Found roles: $ROLES"

    # Check if all required roles exist
    if [[ "$ROLES" == *"supabase_admin"* ]] && [[ "$ROLES" == *"supabase_auth_admin"* ]] && [[ "$ROLES" == *"authenticator"* ]]; then
        success "All critical roles exist"
        NEEDS_INIT=false
    else
        warning "Some roles are missing"
        NEEDS_INIT=true
    fi
fi

if [ "$NEEDS_INIT" = false ]; then
    section "Database is Properly Initialized"
    success "No action needed - roles exist"
    info "If services are still failing, check passwords in .env file"
    exit 0
fi

section "Step 2: Database Needs Initialization"

warning "The database started but init scripts didn't run"
warning "This happens when data directory exists before first boot"
echo ""
info "We need to manually run the initialization scripts"
echo ""

read -p "Run database initialization scripts now? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Aborted"
    exit 0
fi

section "Step 3: Running Initialization Scripts"

info "Copying SQL files into container..."
docker exec supabase-db mkdir -p /tmp/init-scripts

docker cp volumes/db/roles.sql supabase-db:/tmp/init-scripts/
docker cp volumes/db/jwt.sql supabase-db:/tmp/init-scripts/
docker cp volumes/db/webhooks.sql supabase-db:/tmp/init-scripts/
docker cp volumes/db/realtime.sql supabase-db:/tmp/init-scripts/
docker cp volumes/db/logs.sql supabase-db:/tmp/init-scripts/

success "Files copied"

info "Executing roles.sql..."
docker exec supabase-db psql -U postgres -f /tmp/init-scripts/roles.sql 2>&1 | grep -v "already exists" || true

info "Executing jwt.sql..."
docker exec supabase-db psql -U postgres -f /tmp/init-scripts/jwt.sql 2>&1 | grep -v "already exists" || true

info "Executing webhooks.sql..."
docker exec supabase-db psql -U postgres -f /tmp/init-scripts/webhooks.sql 2>&1 | grep -v "already exists" || true

info "Executing realtime.sql..."
docker exec supabase-db psql -U postgres -f /tmp/init-scripts/realtime.sql 2>&1 | grep -v "already exists" || true

info "Executing logs.sql..."
docker exec supabase-db psql -U postgres -f /tmp/init-scripts/logs.sql 2>&1 | grep -v "already exists" || true

success "All initialization scripts executed"

section "Step 4: Verify Roles Were Created"

ROLES_AFTER=$(docker exec supabase-db psql -U postgres -t -c "SELECT string_agg(rolname, ', ') FROM pg_roles WHERE rolname IN ('supabase_admin', 'supabase_auth_admin', 'supabase_storage_admin', 'authenticator', 'anon', 'service_role');" 2>/dev/null | xargs)

if [ -n "$ROLES_AFTER" ]; then
    success "Roles created: $ROLES_AFTER"
else
    error "Failed to create roles"
    exit 1
fi

section "Step 5: Restart Services to Reconnect"

info "Restarting all services to pick up new database roles..."
docker compose restart auth storage realtime meta analytics kong

info "Waiting 30 seconds for services to reconnect..."
sleep 30

section "Step 6: Verify Service Health"

docker compose ps

echo ""
success "Database initialization complete!"
echo ""
info "Check service health above"
info "If still unhealthy, check:"
echo "  - Password in .env matches POSTGRES_PASSWORD"
echo "  - Service logs: docker logs supabase-<service>"
echo ""

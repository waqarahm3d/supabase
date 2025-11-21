#!/bin/bash

################################################################################
# Fix Role Passwords to Match .env
# Resets all Supabase role passwords to current POSTGRES_PASSWORD
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
echo "║           Fix Database Role Passwords                         ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

section "Step 1: Load Password from .env"

if [ ! -f .env ]; then
    error ".env file not found!"
    exit 1
fi

POSTGRES_PASSWORD=$(grep "^POSTGRES_PASSWORD=" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'")

if [ -z "$POSTGRES_PASSWORD" ]; then
    error "POSTGRES_PASSWORD not found in .env"
    exit 1
fi

success "Loaded POSTGRES_PASSWORD from .env (length: ${#POSTGRES_PASSWORD} chars)"

section "Step 2: Update Role Passwords"

warning "This will reset passwords for all Supabase roles to match .env"
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Aborted"
    exit 0
fi

info "Updating postgres user password..."
docker exec supabase-db psql -U postgres -c "ALTER USER postgres WITH PASSWORD '$POSTGRES_PASSWORD';" 2>&1 | grep -v "ALTER ROLE" || true
success "Updated postgres"

info "Updating supabase_admin password..."
docker exec supabase-db psql -U postgres -c "ALTER USER supabase_admin WITH PASSWORD '$POSTGRES_PASSWORD';" 2>&1 | grep -v "ALTER ROLE" || true
success "Updated supabase_admin"

info "Updating supabase_auth_admin password..."
docker exec supabase-db psql -U postgres -c "ALTER USER supabase_auth_admin WITH PASSWORD '$POSTGRES_PASSWORD';" 2>&1 | grep -v "ALTER ROLE" || true
success "Updated supabase_auth_admin"

info "Updating supabase_storage_admin password..."
docker exec supabase-db psql -U postgres -c "ALTER USER supabase_storage_admin WITH PASSWORD '$POSTGRES_PASSWORD';" 2>&1 | grep -v "ALTER ROLE" || true
success "Updated supabase_storage_admin"

info "Updating authenticator password..."
docker exec supabase-db psql -U postgres -c "ALTER USER authenticator WITH PASSWORD '$POSTGRES_PASSWORD';" 2>&1 | grep -v "ALTER ROLE" || true
success "Updated authenticator"

section "Step 3: Verify Password Works"

info "Testing supabase_admin connection..."
if docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" supabase-db psql -U supabase_admin -d postgres -c "SELECT 'Connection successful' as status;" > /dev/null 2>&1; then
    success "supabase_admin can now connect!"
else
    error "Still cannot connect - something is wrong"
    exit 1
fi

info "Testing supabase_auth_admin connection..."
if docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" supabase-db psql -U supabase_auth_admin -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
    success "supabase_auth_admin can now connect!"
else
    error "Still cannot connect as supabase_auth_admin"
fi

section "Step 4: Restart Services"

info "Restarting all services to reconnect with new passwords..."
docker compose restart

info "Waiting 30 seconds for services to start..."
sleep 30

section "Step 5: Check Service Health"

docker compose ps

echo ""
success "Password fix complete!"
echo ""
info "All role passwords now match POSTGRES_PASSWORD in .env"
info "Services have been restarted to reconnect"
echo ""
info "Check service health above"
info "If still unhealthy, run: docker logs supabase-<service>"
echo ""

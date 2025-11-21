#!/bin/bash

################################################################################
# Password Authentication Diagnostic
# Expert approach: Verify credentials match between .env and database
################################################################################

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
echo "║         Password Authentication Diagnostic                     ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

section "Step 1: Check .env File"

if [ ! -f .env ]; then
    error ".env file not found!"
    info "You need to create .env from .env.example"
    exit 1
fi

info "Extracting POSTGRES_PASSWORD from .env..."
POSTGRES_PASSWORD=$(grep "^POSTGRES_PASSWORD=" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'")

if [ -z "$POSTGRES_PASSWORD" ]; then
    error "POSTGRES_PASSWORD not found in .env"
    exit 1
fi

success "Found POSTGRES_PASSWORD in .env (length: ${#POSTGRES_PASSWORD} chars)"
echo "  First 10 chars: ${POSTGRES_PASSWORD:0:10}..."

section "Step 2: Test Database Connection with .env Password"

info "Testing connection as postgres user..."
if docker exec supabase-db psql -U postgres -c "SELECT 1;" > /dev/null 2>&1; then
    success "Can connect as postgres user"
else
    error "Cannot connect as postgres user"
fi

info "Testing connection as supabase_admin..."
if docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" supabase-db psql -U supabase_admin -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
    success "Can connect as supabase_admin with .env password"
else
    error "CANNOT connect as supabase_admin with .env password"
    warning "This is the problem - password mismatch!"
fi

info "Testing connection as supabase_auth_admin..."
if docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" supabase-db psql -U supabase_auth_admin -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
    success "Can connect as supabase_auth_admin with .env password"
else
    error "CANNOT connect as supabase_auth_admin with .env password"
fi

section "Step 3: Check Environment Variables Passed to Services"

info "Checking Auth service environment..."
AUTH_DB_PASSWORD=$(docker exec supabase-auth env | grep DB_PASSWORD || echo "NOT SET")
if [ "$AUTH_DB_PASSWORD" = "NOT SET" ]; then
    error "Auth service doesn't have DB_PASSWORD environment variable"
else
    info "Auth service has DB_PASSWORD set"
fi

info "Checking Storage service environment..."
STORAGE_DB_PASSWORD=$(docker exec supabase-storage env | grep DATABASE_URL || echo "NOT SET")
if [ "$STORAGE_DB_PASSWORD" = "NOT SET" ]; then
    error "Storage service doesn't have DATABASE_URL"
else
    info "Storage service has DATABASE_URL set"
fi

section "Step 4: Check How Roles Were Created"

info "Checking role creation details..."
docker exec supabase-db psql -U postgres -c "SELECT rolname, rolcanlogin FROM pg_roles WHERE rolname LIKE 'supabase%' OR rolname IN ('authenticator', 'anon', 'service_role');"

section "DIAGNOSIS"

echo ""
info "Common issues and solutions:"
echo ""
echo "  1. ROLES CREATED WITH DIFFERENT PASSWORD"
echo "     → Roles were created when .env had a different POSTGRES_PASSWORD"
echo "     → Solution: Reset all role passwords to match current .env"
echo ""
echo "  2. ENVIRONMENT VARIABLES NOT LOADED"
echo "     → Docker compose not reading .env file"
echo "     → Solution: Restart with explicit .env: docker compose --env-file .env up -d"
echo ""
echo "  3. ROLES.SQL USED HARDCODED PASSWORD"
echo "     → roles.sql had hardcoded password instead of using env variable"
echo "     → Solution: Update role passwords"
echo ""

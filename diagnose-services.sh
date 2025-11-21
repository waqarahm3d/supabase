#!/bin/bash

################################################################################
# Service Diagnostic Tool - Check Why Services Are Unhealthy
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
section() { echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${CYAN} $1${NC}"; echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║            Service Health Diagnostic Report                   ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

section "1. DATABASE - Checking Core Setup"

info "Checking if database is accessible..."
if docker exec supabase-db pg_isready -U postgres > /dev/null 2>&1; then
    success "Database is responding"
else
    error "Database is NOT responding - this will cause all services to fail"
    exit 1
fi

info "Checking if required roles exist..."
docker exec supabase-db psql -U postgres -t -c "SELECT rolname FROM pg_roles WHERE rolname IN ('supabase_admin', 'supabase_auth_admin', 'supabase_storage_admin', 'authenticator', 'anon', 'service_role');" 2>&1

info "Checking if database was initialized..."
docker exec supabase-db psql -U postgres -t -c "SELECT datname FROM pg_database WHERE datname = 'postgres';" 2>&1

section "2. AUTH SERVICE - GoTrue"

info "Last 30 lines of Auth logs:"
docker logs supabase-auth --tail 30 2>&1 | tail -30

info "Checking Auth healthcheck manually..."
docker exec supabase-auth wget --no-verbose --tries=1 --spider http://localhost:9999/health 2>&1 || echo "Health check failed"

section "3. KONG - API Gateway"

info "Last 30 lines of Kong logs:"
docker logs supabase-kong --tail 30 2>&1 | tail -30

info "Checking Kong ports..."
docker exec supabase-kong netstat -tlnp 2>/dev/null | grep -E ':(8000|8443)' || echo "Kong not listening on expected ports"

section "4. STORAGE SERVICE"

info "Last 30 lines of Storage logs:"
docker logs supabase-storage --tail 30 2>&1 | tail -30

section "5. REALTIME SERVICE"

info "Last 30 lines of Realtime logs:"
docker logs supabase-realtime --tail 30 2>&1 | tail -30

section "6. ANALYTICS - Logflare"

info "Last 30 lines of Analytics logs:"
docker logs supabase-analytics --tail 30 2>&1 | tail -30

section "7. NETWORK CONNECTIVITY"

info "Can Auth reach Database?"
docker exec supabase-auth ping -c 2 supabase-db 2>&1 | grep -E '(bytes from|unreachable)' || echo "Network check failed"

info "Can Auth connect to Database port?"
docker exec supabase-auth nc -zv supabase-db 5432 2>&1 || echo "Cannot connect to database port"

section "SUMMARY"

echo ""
info "Check the logs above for specific error messages"
info "Common issues to look for:"
echo "  - Database connection errors (wrong password, host, port)"
echo "  - Missing database roles or schemas"
echo "  - Port conflicts"
echo "  - Environment variable issues"
echo ""

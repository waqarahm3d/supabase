#!/bin/bash

################################################################################
# Diagnostic Script - Systematic Troubleshooting
# Expert approach: Diagnose before fixing
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }
section() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}\n"; }

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║         Supabase Deployment Diagnostic Tool                   ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

section "1. Container Status"
docker compose ps

section "2. Database Status (Critical)"
if docker exec supabase-db pg_isready -U postgres > /dev/null 2>&1; then
    success "Database is responding"
    docker exec supabase-db psql -U postgres -c "SELECT version();" 2>/dev/null | head -3
else
    error "Database is not responding"
fi

section "3. Analytics Container (Currently Failing)"
info "Analytics container logs (last 100 lines):"
docker logs supabase-analytics --tail 100 2>&1 || echo "Container not running or no logs"

section "4. Analytics Dependencies Check"
info "Analytics depends on database. Checking connection..."
docker exec supabase-analytics nc -zv supabase-db 5432 2>&1 || echo "Cannot connect to database"

section "5. Environment Variables Check"
info "Checking critical environment variables..."
if [ -f .env ]; then
    echo "POSTGRES_PASSWORD: $(grep POSTGRES_PASSWORD .env | cut -d'=' -f2 | head -c 20)..."
    echo "POSTGRES_DB: $(grep POSTGRES_DB .env | cut -d'=' -f2)"
    echo "LOGFLARE_API_KEY: $(grep LOGFLARE_API_KEY .env | cut -d'=' -f2 | head -c 20)..."
else
    error ".env file not found"
fi

section "6. Network Status"
info "Checking Docker network..."
docker network inspect supabase_default | grep -A 5 '"Name": "supabase' || echo "Network issue"

section "7. Resource Usage"
info "System resources:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null || echo "Stats unavailable"

section "8. Port Conflicts"
info "Checking for port conflicts..."
netstat -tulpn 2>/dev/null | grep -E ':(8000|8443|5432|4000|3000)' || echo "Ports seem available"

section "Diagnosis Summary"
echo ""
info "Next steps based on findings above:"
echo "  1. Check analytics logs for specific error messages"
echo "  2. Verify database schema initialization"
echo "  3. Check if analytics can connect to database"
echo "  4. Verify all required environment variables are set"
echo ""

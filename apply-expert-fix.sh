#!/bin/bash

################################################################################
# Expert Fix - Resilient Startup Configuration
# Addresses: Overly strict service dependencies causing startup failures
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
warning() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }
section() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}\n"; }

cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║               Expert-Level Supabase Fix                           ║
║        Resilient Service Startup Configuration                    ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝

WHAT THIS FIXES:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Problem Identified:
  - Analytics (Logflare) container runs database migrations on startup
  - All other services have HARD dependency on analytics being "healthy"
  - If analytics takes time to migrate or fails healthcheck, everything stops
  - This creates a fragile, brittle startup sequence

Expert Solution:
  1. Change service dependencies from "service_healthy" to "service_started"
     → Services can start even if analytics is still initializing
  2. Give analytics MORE time to complete its database migrations
     → Increased healthcheck timeout, interval, and retries
     → Added 60-second start period before health checking begins
  3. Analytics will eventually become healthy, but won't block other services

This is how production-grade systems handle service dependencies.

EOF

echo ""
read -p "Apply this expert fix? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Aborted. No changes made."
    exit 0
fi

section "Step 1: Backup Current Configuration"
if [ -f "docker-compose.yml" ]; then
    cp docker-compose.yml "docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S)"
    success "Backed up docker-compose.yml"
else
    error "docker-compose.yml not found!"
    exit 1
fi

section "Step 2: Stop All Services"
info "Stopping containers..."
docker compose down
success "All services stopped"

section "Step 3: Apply Fixed Configuration"
if [ -f "docker-compose.fixed.yml" ]; then
    cp docker-compose.fixed.yml docker-compose.yml
    success "Applied resilient configuration"
else
    error "docker-compose.fixed.yml not found!"
    exit 1
fi

section "Step 4: Verify Database is Ready"
info "Checking database directory..."
if [ -d "volumes/db/data" ] && [ "$(ls -A volumes/db/data)" ]; then
    success "Database data exists"
else
    warning "Database data directory is empty - will initialize from scratch"
fi

section "Step 5: Start Services in Order"
info "Starting database first..."
docker compose up -d db

info "Waiting for database to be healthy (30 seconds)..."
sleep 30

if docker exec supabase-db pg_isready -U postgres > /dev/null 2>&1; then
    success "Database is healthy"
else
    error "Database is not healthy. Check logs: docker logs supabase-db"
    exit 1
fi

info "Starting analytics (will run migrations)..."
docker compose up -d analytics

info "Giving analytics time to run migrations (60 seconds)..."
echo "  → This is normal - Logflare needs to set up database schemas"
sleep 60

info "Starting remaining services..."
docker compose up -d

section "Step 6: Monitor Startup Progress"
info "Waiting for services to stabilize (60 seconds)..."
sleep 60

section "Step 7: Check Service Status"
docker compose ps

section "Step 8: Verify Critical Services"

echo ""
info "Checking database..."
if docker exec supabase-db pg_isready -U postgres > /dev/null 2>&1; then
    success "Database: HEALTHY"
else
    error "Database: UNHEALTHY"
fi

echo ""
info "Checking analytics..."
if docker exec supabase-analytics curl -sf http://localhost:4000/health > /dev/null 2>&1; then
    success "Analytics: HEALTHY"
else
    warning "Analytics: Still starting (this is OK - other services will work)"
    info "Check progress: docker logs supabase-analytics --tail 50"
fi

echo ""
info "Checking authentication..."
if docker exec supabase-auth wget -q --spider http://localhost:9999/health > /dev/null 2>&1; then
    success "Auth: HEALTHY"
else
    warning "Auth: Still starting..."
fi

echo ""
info "Checking API (PostgREST)..."
if docker ps | grep supabase-rest | grep -q "Up"; then
    success "REST API: RUNNING"
else
    warning "REST API: Not yet started"
fi

echo ""
info "Checking Studio..."
if docker ps | grep supabase-studio | grep -q "Up"; then
    success "Studio: RUNNING"
else
    warning "Studio: Not yet started"
fi

section "Summary"
echo ""
success "Expert fix applied successfully!"
echo ""
info "What was fixed:"
echo "  ✓ Service dependencies made more resilient"
echo "  ✓ Analytics given proper time to initialize"
echo "  ✓ Other services no longer blocked by analytics startup"
echo ""
info "Next steps:"
echo "  1. Wait 2-3 minutes for all services to fully start"
echo "  2. Check status: docker compose ps"
echo "  3. View logs if needed: docker logs <container-name>"
echo "  4. Run health check: ./health-check.sh"
echo ""
info "If analytics is still unhealthy after 5 minutes:"
echo "  → Check logs: docker logs supabase-analytics"
echo "  → This won't affect other services - they will work fine"
echo ""
warning "Important: Analytics provides logging/observability"
warning "If it fails, your Supabase will still work, you just won't have logs in Studio"
echo ""

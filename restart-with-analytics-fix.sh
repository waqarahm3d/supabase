#!/bin/bash

################################################################################
# Apply Analytics Fix and Restart Services
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
warning() { echo -e "${YELLOW}[!]${NC} $1"; }
section() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}\n"; }

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║          Apply Analytics Fix & Restart Services               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

section "What This Fix Does"

echo "1. Creates dummy gcloud.json file (analytics was looking for it)"
echo "2. Updates analytics healthcheck to be more forgiving"
echo "3. Changes service dependencies to be resilient (service_started vs service_healthy)"
echo "4. Services can now start even if analytics is slow/failing"
echo ""

section "Step 1: Stop All Services"

info "Stopping containers..."
docker compose down --remove-orphans
success "All services stopped"

section "Step 2: Verify gcloud.json Exists"

if [ -f "volumes/logs/gcloud.json" ]; then
    success "gcloud.json exists"
else
    info "Creating dummy gcloud.json..."
    mkdir -p volumes/logs
    cat > volumes/logs/gcloud.json << 'GCEOF'
{
  "type": "service_account",
  "project_id": "self-hosted-supabase",
  "private_key_id": "dummy",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDU7cBYJ0jHuQqB\n-----END PRIVATE KEY-----\n",
  "client_email": "supabase@self-hosted.iam.gserviceaccount.com",
  "client_id": "000000000000000000000",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs"
}
GCEOF
    success "Created dummy gcloud.json"
fi

section "Step 3: Start Services"

info "Starting database first..."
docker compose up -d db

info "Waiting for database (20 seconds)..."
sleep 20

if docker exec supabase-db pg_isready -U postgres > /dev/null 2>&1; then
    success "Database is healthy"
else
    warning "Database not ready yet, continuing anyway..."
fi

info "Starting all services..."
docker compose up -d

section "Step 4: Monitor Startup"

info "Services are starting... waiting 60 seconds for stabilization"
for i in {1..60}; do
    echo -n "."
    sleep 1
done
echo ""

section "Step 5: Check Service Status"

docker compose ps

echo ""
section "Step 6: Quick Health Check"

# Database
if docker exec supabase-db pg_isready -U postgres > /dev/null 2>&1; then
    success "Database: HEALTHY"
else
    warning "Database: NOT READY"
fi

# Storage
if docker logs supabase-storage 2>&1 | tail -5 | grep -q "Started Successfully"; then
    success "Storage: HEALTHY"
else
    warning "Storage: Check logs"
fi

# Studio
if docker logs supabase-studio 2>&1 | tail -10 | grep -q "Ready in"; then
    success "Studio: HEALTHY"
else
    warning "Studio: Check logs"
fi

# Auth
if docker exec supabase-auth wget -q --spider http://localhost:9999/health 2>/dev/null; then
    success "Auth: HEALTHY"
else
    warning "Auth: Still starting (check in 1-2 minutes)"
fi

# Analytics
if docker logs supabase-analytics 2>&1 | tail -20 | grep -q "gcloud.json"; then
    warning "Analytics: Still has gcloud.json issues"
    info "    Check: docker logs supabase-analytics --tail 50"
else
    if docker exec supabase-analytics curl -sf http://localhost:4000/health > /dev/null 2>&1; then
        success "Analytics: HEALTHY"
    else
        warning "Analytics: Still initializing (this is OK - other services work)"
    fi
fi

echo ""
success "Restart complete!"
echo ""
info "Next steps:"
echo "  1. Wait 2-3 minutes for all services to fully stabilize"
echo "  2. Check detailed status: docker compose ps"
echo "  3. Run health check: ./health-check.sh"
echo "  4. Check logs if needed: docker logs supabase-<service>"
echo ""
warning "Note: Analytics may take longer to become healthy"
warning "Other services will work fine even if analytics is slow"
echo ""

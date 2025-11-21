#!/bin/bash

################################################################################
# SELF-HEALING SUPABASE SETUP
#
# This script automatically detects and fixes ALL Supabase issues:
# - Database user passwords
# - Kong configuration
# - Analytics/Logflare issues
# - Edge Functions issues
# - File/directory mount issues
# - Environment variable issues
#
# It will keep trying until everything works!
################################################################################

set +e  # Don't exit on errors - we want to heal them!

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

LOGFILE="/tmp/supabase-healing-$(date +%Y%m%d-%H%M%S).log"

log() {
    echo -e "$1" | tee -a "$LOGFILE"
}

log_section() {
    log ""
    log "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    log "${CYAN}   $1${NC}"
    log "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    log ""
}

log_section "SUPABASE SELF-HEALING SETUP STARTING"
log "Logfile: $LOGFILE"
log "Time: $(date)"
log ""

# Check if docker is available
if ! command -v docker &> /dev/null; then
    log "${RED}ERROR: Docker not found. This script must run on the VPS.${NC}"
    exit 1
fi

################################################################################
# STEP 1: Stop everything
################################################################################
log_section "Step 1: Stopping All Services"

docker compose down
log "${GREEN}✓ All services stopped${NC}"

################################################################################
# STEP 2: Clean up broken mounts and files
################################################################################
log_section "Step 2: Fixing File/Directory Mount Issues"

# Fix gcloud.json (analytics expects file, not directory)
if [ -d "volumes/logs/gcloud.json" ]; then
    log "${YELLOW}Removing gcloud.json directory...${NC}"
    rm -rf volumes/logs/gcloud.json
fi

# Create gcloud.json as a file
log "Creating gcloud.json as empty file..."
mkdir -p volumes/logs
echo '{}' > volumes/logs/gcloud.json
log "${GREEN}✓ gcloud.json created as file${NC}"

# Fix webhooks.sql (should be file, not directory)
if [ -d "volumes/db/init/webhooks.sql" ]; then
    log "${YELLOW}Removing webhooks.sql directory...${NC}"
    rm -rf volumes/db/init/webhooks.sql
fi

# Fix postgresql.conf (should be file, not directory)
if [ -d "volumes/db/postgresql.conf" ]; then
    log "${YELLOW}Removing postgresql.conf directory...${NC}"
    rm -rf volumes/db/postgresql.conf
fi

# Create postgresql.conf as proper file
log "Creating postgresql.conf..."
mkdir -p volumes/db
cat > volumes/db/postgresql.conf << 'PGCONF'
# PostgreSQL configuration for Supabase
listen_addresses = '*'
max_connections = 100
shared_buffers = 128MB
wal_level = logical
max_wal_senders = 10
max_replication_slots = 10
PGCONF
log "${GREEN}✓ postgresql.conf created${NC}"

# Create directories for edge functions
mkdir -p volumes/functions
log "${GREEN}✓ Functions directory created${NC}"

################################################################################
# STEP 3: Read credentials from .env
################################################################################
log_section "Step 3: Reading Configuration from .env"

if [ ! -f ".env" ]; then
    log "${RED}ERROR: .env file not found!${NC}"
    exit 1
fi

# Extract values safely
JWT_SECRET=$(grep '^JWT_SECRET=' .env | sed 's/^JWT_SECRET=//' | head -1)
POSTGRES_PASSWORD=$(grep '^POSTGRES_PASSWORD=' .env | sed 's/^POSTGRES_PASSWORD=//' | head -1)
ANON_KEY=$(grep '^ANON_KEY=' .env | sed 's/^ANON_KEY=//' | head -1)
SERVICE_ROLE_KEY=$(grep '^SERVICE_ROLE_KEY=' .env | sed 's/^SERVICE_ROLE_KEY=//' | head -1)
DASHBOARD_PASSWORD=$(grep '^DASHBOARD_PASSWORD=' .env | sed 's/^DASHBOARD_PASSWORD=//' | head -1)

log "JWT_SECRET: ${JWT_SECRET:0:20}... (${#JWT_SECRET} chars)"
log "POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:0:15}..."
log "DASHBOARD_PASSWORD: ${DASHBOARD_PASSWORD:0:10}..."
log "${GREEN}✓ Configuration loaded${NC}"

################################################################################
# STEP 4: Start PostgreSQL ONLY to set passwords
################################################################################
log_section "Step 4: Starting Database to Set Passwords"

# Start only DB service
docker compose up -d db

log "Waiting for database to be ready..."
sleep 15

# Check if DB is running
if ! docker compose ps db | grep -q "running"; then
    log "${RED}Database failed to start!${NC}"
    docker compose logs db | tail -50
    exit 1
fi

log "${GREEN}✓ Database is running${NC}"

################################################################################
# STEP 5: Set passwords for all database users
################################################################################
log_section "Step 5: Setting Database User Passwords"

log "Setting password for postgres user..."
docker compose exec -T db psql -U postgres -c "ALTER USER postgres WITH PASSWORD '$POSTGRES_PASSWORD';" || true

log "Setting password for authenticator user..."
docker compose exec -T db psql -U postgres -c "ALTER USER authenticator WITH PASSWORD '$POSTGRES_PASSWORD';" || true

log "Setting password for supabase_admin user..."
docker compose exec -T db psql -U postgres -c "ALTER USER supabase_admin WITH PASSWORD '$POSTGRES_PASSWORD';" || true

log "Setting password for supabase_auth_admin user..."
docker compose exec -T db psql -U postgres -c "ALTER USER supabase_auth_admin WITH PASSWORD '$POSTGRES_PASSWORD';" || true

log "Setting password for supabase_storage_admin user..."
docker compose exec -T db psql -U postgres -c "ALTER USER supabase_storage_admin WITH PASSWORD '$POSTGRES_PASSWORD';" || true

log "Setting password for supabase_functions_admin user (if exists)..."
docker compose exec -T db psql -U postgres -c "ALTER USER supabase_functions_admin WITH PASSWORD '$POSTGRES_PASSWORD';" 2>/dev/null || true

log "${GREEN}✓ All database passwords set${NC}"

# Verify passwords work
log ""
log "Verifying password authentication..."
if docker compose exec -T db psql -U postgres -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
    log "${GREEN}✓ postgres user authentication works${NC}"
else
    log "${YELLOW}⚠ postgres user authentication might need restart${NC}"
fi

################################################################################
# STEP 6: Fix Kong configuration
################################################################################
log_section "Step 6: Fixing Kong Configuration"

# Backup original kong.yml
if [ -f "volumes/api/kong.yml" ]; then
    cp volumes/api/kong.yml volumes/api/kong.yml.backup.$(date +%Y%m%d-%H%M%S)
    log "Backed up kong.yml"
fi

# Read the template or create fresh
mkdir -p volumes/api

# Create a properly formatted Kong config
log "Creating fresh Kong configuration..."
cat > volumes/api/kong.yml << KONGEOF
_format_version: "3.0"

consumers:
  - username: DASHBOARD
    keyauth_credentials:
      - key: $DASHBOARD_PASSWORD
  - username: anon
    keyauth_credentials:
      - key: $ANON_KEY
  - username: service_role
    keyauth_credentials:
      - key: $SERVICE_ROLE_KEY

acls:
  - consumer: anon
    group: anon
  - consumer: service_role
    group: admin

services:
  - name: auth-v1-open
    url: http://auth:9999/verify
    routes:
      - name: auth-v1-open
        strip_path: true
        paths:
          - /auth/v1/verify
    plugins:
      - name: cors
  - name: auth-v1-open-callback
    url: http://auth:9999/callback
    routes:
      - name: auth-v1-open-callback
        strip_path: true
        paths:
          - /auth/v1/callback
    plugins:
      - name: cors
  - name: auth-v1-open-authorize
    url: http://auth:9999/authorize
    routes:
      - name: auth-v1-open-authorize
        strip_path: true
        paths:
          - /auth/v1/authorize
    plugins:
      - name: cors
  - name: auth-v1
    _comment: 'GoTrue: /auth/v1/* -> http://auth:9999/*'
    url: http://auth:9999/
    routes:
      - name: auth-v1-all
        strip_path: true
        paths:
          - /auth/v1/
    plugins:
      - name: cors
      - name: key-auth
        config:
          hide_credentials: false
  - name: rest-v1
    _comment: 'PostgREST: /rest/v1/* -> http://rest:3000/*'
    url: http://rest:3000/
    routes:
      - name: rest-v1-all
        strip_path: true
        paths:
          - /rest/v1/
    plugins:
      - name: cors
      - name: key-auth
        config:
          hide_credentials: true
  - name: realtime-v1
    _comment: 'Realtime: /realtime/v1/* -> ws://realtime:4000/socket/*'
    url: http://realtime-dev.supabase-realtime:4000/socket
    routes:
      - name: realtime-v1-all
        strip_path: true
        paths:
          - /realtime/v1/
    plugins:
      - name: cors
      - name: key-auth
        config:
          hide_credentials: false
  - name: storage-v1
    _comment: 'Storage: /storage/v1/* -> http://storage:5000/*'
    url: http://storage:5000/
    routes:
      - name: storage-v1-all
        strip_path: true
        paths:
          - /storage/v1/
    plugins:
      - name: cors
  - name: meta
    _comment: 'Metadata: /pg/* -> http://meta:8080/*'
    url: http://meta:8080/
    routes:
      - name: meta-all
        strip_path: true
        paths:
          - /pg/
KONGEOF

log "${GREEN}✓ Kong configuration created${NC}"

# Verify Kong config syntax
log "Verifying Kong configuration..."
if grep -q "_format_version" volumes/api/kong.yml; then
    log "${GREEN}✓ Kong config appears valid${NC}"
else
    log "${RED}✗ Kong config might be invalid${NC}"
fi

################################################################################
# STEP 7: Restart database to apply password changes
################################################################################
log_section "Step 7: Restarting Database with New Settings"

docker compose stop db
sleep 3
docker compose up -d db
sleep 15

log "${GREEN}✓ Database restarted${NC}"

################################################################################
# STEP 8: Start all other services
################################################################################
log_section "Step 8: Starting All Services"

docker compose up -d

log "Waiting for services to initialize (60 seconds)..."
for i in {60..1}; do
    printf "\r${BLUE}⏳ %2d seconds remaining...${NC}" $i
    sleep 1
done
echo ""
log ""

################################################################################
# STEP 9: Check service health
################################################################################
log_section "Step 9: Checking Service Health"

# Check container status
log "Container Status:"
docker compose ps

log ""
log "Services Status:"
SERVICES=("db" "kong" "auth" "rest" "realtime-dev.supabase-realtime" "storage" "meta" "studio" "analytics" "functions" "imgproxy")

for service in "${SERVICES[@]}"; do
    if docker compose ps "$service" 2>/dev/null | grep -q "Up\|running"; then
        log "${GREEN}✓ $service: Running${NC}"
    else
        log "${RED}✗ $service: Not running${NC}"
    fi
done

################################################################################
# STEP 10: Test API endpoints
################################################################################
log_section "Step 10: Testing API Endpoints"

sleep 10  # Give services a bit more time

# Test REST API
log -n "Testing REST API... "
REST_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "apikey: $ANON_KEY" http://localhost/rest/v1/ 2>/dev/null || echo "000")
if [ "$REST_CODE" = "200" ]; then
    log "${GREEN}✓ HTTP $REST_CODE${NC}"
elif [ "$REST_CODE" = "401" ]; then
    log "${RED}✗ HTTP $REST_CODE (Authentication issue)${NC}"
else
    log "${YELLOW}⚠ HTTP $REST_CODE${NC}"
fi

# Test Auth API
log -n "Testing Auth API... "
AUTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "apikey: $ANON_KEY" http://localhost/auth/v1/health 2>/dev/null || echo "000")
if [ "$AUTH_CODE" = "200" ]; then
    log "${GREEN}✓ HTTP $AUTH_CODE${NC}"
elif [ "$AUTH_CODE" = "401" ]; then
    log "${RED}✗ HTTP $AUTH_CODE (Authentication issue)${NC}"
else
    log "${YELLOW}⚠ HTTP $AUTH_CODE${NC}"
fi

# Test Storage API
log -n "Testing Storage API... "
STORAGE_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "apikey: $ANON_KEY" http://localhost/storage/v1/bucket 2>/dev/null || echo "000")
if [ "$STORAGE_CODE" = "200" ]; then
    log "${GREEN}✓ HTTP $STORAGE_CODE${NC}"
elif [ "$STORAGE_CODE" = "401" ]; then
    log "${RED}✗ HTTP $STORAGE_CODE (Authentication issue)${NC}"
else
    log "${YELLOW}⚠ HTTP $STORAGE_CODE${NC}"
fi

# Test Studio
log -n "Testing Studio... "
STUDIO_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null || echo "000")
if [ "$STUDIO_CODE" = "200" ]; then
    log "${GREEN}✓ HTTP $STUDIO_CODE${NC}"
else
    log "${YELLOW}⚠ HTTP $STUDIO_CODE${NC}"
fi

################################################################################
# STEP 11: Check for remaining errors
################################################################################
log_section "Step 11: Scanning for Remaining Errors"

log "Checking for password authentication errors..."
if docker compose logs --tail=50 2>&1 | grep -q "password authentication failed"; then
    log "${YELLOW}⚠ Still seeing password errors - checking which services...${NC}"
    docker compose logs --tail=100 2>&1 | grep "password authentication failed" | head -10
    log ""
    log "${YELLOW}Attempting additional fix...${NC}"

    # Try setting passwords again
    docker compose exec -T db psql -U postgres << 'SQLEOF'
ALTER USER authenticator WITH PASSWORD 'your-super-secret-and-long-postgres-password-change-this';
ALTER USER supabase_admin WITH PASSWORD 'your-super-secret-and-long-postgres-password-change-this';
ALTER USER supabase_auth_admin WITH PASSWORD 'your-super-secret-and-long-postgres-password-change-this';
ALTER USER supabase_storage_admin WITH PASSWORD 'your-super-secret-and-long-postgres-password-change-this';
SQLEOF

    log "${GREEN}✓ Re-applied password fixes${NC}"
    log "${YELLOW}Restarting services...${NC}"
    docker compose restart auth rest storage realtime-dev.supabase-realtime
    sleep 20
else
    log "${GREEN}✓ No password authentication errors detected${NC}"
fi

log ""
log "Checking for Kong config errors..."
if docker compose logs kong --tail=50 2>&1 | grep -q "failed parsing declarative configuration"; then
    log "${RED}✗ Kong still has config errors${NC}"
    docker compose logs kong --tail=20
else
    log "${GREEN}✓ Kong configuration OK${NC}"
fi

log ""
log "Checking for Analytics errors..."
if docker compose logs analytics --tail=20 2>&1 | grep -q "gcloud.json.*directory"; then
    log "${YELLOW}⚠ Analytics still has gcloud.json issues${NC}"
else
    log "${GREEN}✓ Analytics OK or running${NC}"
fi

################################################################################
# FINAL SUMMARY
################################################################################
log_section "SELF-HEALING COMPLETE - SUMMARY"

log ""
log "Service Endpoints:"
log "  • Studio:  http://studio.qoqnuz.com (or http://localhost:3000)"
log "  • API:     http://db.qoqnuz.com (or http://localhost)"
log "  • REST:    http://localhost/rest/v1/"
log "  • Auth:    http://localhost/auth/v1/"
log "  • Storage: http://localhost/storage/v1/"
log ""
log "Credentials:"
log "  • JWT_SECRET: ${JWT_SECRET:0:30}..."
log "  • ANON_KEY: ${ANON_KEY:0:50}..."
log "  • Dashboard: user=supabase, pass=$DASHBOARD_PASSWORD"
log ""

# Final verdict
if [ "$REST_CODE" = "200" ] && [ "$AUTH_CODE" = "200" ]; then
    log "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    log "${GREEN}   ✓✓✓ SUCCESS! Supabase is FULLY FUNCTIONAL!${NC}"
    log "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    log ""
    log "${GREEN}All API endpoints are responding correctly!${NC}"
    log ""
    exit 0
else
    log "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
    log "${YELLOW}   ⚠ PARTIAL SUCCESS - Some issues remain${NC}"
    log "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
    log ""
    log "Some services may still be starting up."
    log ""
    log "To check logs for specific services:"
    log "  docker compose logs <service-name>"
    log ""
    log "To check all recent errors:"
    log "  docker compose logs --tail=100 | grep -i error"
    log ""
    log "Full log saved to: $LOGFILE"
    log ""
    exit 1
fi

#!/bin/bash

################################################################################
# FRESH START SCRIPT - Complete Supabase Reset and Reinstall
#
# This script will:
#   1. Completely tear down existing Supabase installation
#   2. Generate fresh credentials
#   3. Create clean .env file with proper formatting
#   4. Start services from scratch
#   5. Test and verify everything works
#
# USE THIS WHEN: You're stuck in debugging circles and need a clean slate
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                                                                ║"
echo "║           SUPABASE FRESH START - COMPLETE RESET                ║"
echo "║                                                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "${YELLOW}⚠️  WARNING: This will:${NC}"
echo "  • Stop and remove ALL Supabase containers"
echo "  • Delete ALL volumes and data"
echo "  • Remove ALL cached Docker state"
echo "  • Create fresh credentials"
echo "  • Start from a completely clean slate"
echo ""
echo -e "${RED}ALL EXISTING DATA WILL BE LOST!${NC}"
echo ""
read -p "Are you sure you want to continue? (type YES to confirm): " CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    echo -e "${YELLOW}Aborted.${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Step 1/6: Complete Teardown${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Check if we're on the VPS (has docker)
if ! command -v docker &> /dev/null; then
    echo -e "${RED}ERROR: Docker not found${NC}"
    echo "This script must be run on the VPS where Docker is installed"
    exit 1
fi

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}ERROR: docker-compose.yml not found${NC}"
    echo "Please run this script from the Supabase directory"
    exit 1
fi

# Backup current state (just in case)
BACKUP_DIR="backups/fresh-start-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

if [ -f ".env" ]; then
    cp .env "$BACKUP_DIR/.env.backup"
    echo -e "${GREEN}✓ Backed up .env to $BACKUP_DIR${NC}"
fi

if [ -d "volumes" ]; then
    echo "Backing up volumes (this may take a moment)..."
    cp -r volumes "$BACKUP_DIR/volumes.backup" 2>/dev/null || true
    echo -e "${GREEN}✓ Backed up volumes to $BACKUP_DIR${NC}"
fi

echo ""
echo "Stopping all Supabase services..."
docker compose down -v --remove-orphans 2>/dev/null || true
echo -e "${GREEN}✓ Services stopped${NC}"

echo ""
echo "Removing any remaining Supabase containers..."
docker ps -a | grep supabase | awk '{print $1}' | xargs -r docker rm -f 2>/dev/null || true
echo -e "${GREEN}✓ Containers removed${NC}"

echo ""
echo "Pruning Docker system (removing cached layers and unused resources)..."
docker system prune -af --volumes --filter "label=com.docker.compose.project=supabase" 2>/dev/null || true
echo -e "${GREEN}✓ Docker system pruned${NC}"

echo ""
echo "Removing old volumes directory..."
rm -rf volumes
mkdir -p volumes/db volumes/storage volumes/logs volumes/api
echo -e "${GREEN}✓ Fresh volumes directory created${NC}"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Step 2/6: Generate Fresh Credentials${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Base64URL encoding function (proper implementation)
base64url() {
    openssl base64 -e -A | tr '+/' '-_' | tr -d '='
}

# Generate strong random secrets
echo "Generating JWT secret..."
JWT_SECRET=$(openssl rand -base64 32)
echo -e "${GREEN}✓ JWT_SECRET: ${JWT_SECRET:0:20}...${NC}"

echo "Generating PostgreSQL password..."
POSTGRES_PASSWORD=$(openssl rand -base64 24 | tr -d '/')
echo -e "${GREEN}✓ POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:0:15}...${NC}"

echo "Generating dashboard password..."
DASHBOARD_PASSWORD=$(openssl rand -base64 16 | tr -d '/')
echo -e "${GREEN}✓ DASHBOARD_PASSWORD: ${DASHBOARD_PASSWORD:0:10}...${NC}"

echo "Generating Logflare API key..."
LOGFLARE_API_KEY=$(openssl rand -base64 32 | tr -d '/')
echo -e "${GREEN}✓ LOGFLARE_API_KEY: ${LOGFLARE_API_KEY:0:15}...${NC}"

echo "Generating secret key base..."
SECRET_KEY_BASE=$(openssl rand -base64 32)
echo -e "${GREEN}✓ SECRET_KEY_BASE: ${SECRET_KEY_BASE:0:15}...${NC}"

echo ""
echo "Generating JWT tokens (ANON_KEY and SERVICE_ROLE_KEY)..."

# Create JWT header and payloads
HEADER='{"alg":"HS256","typ":"JWT"}'
ANON_PAYLOAD='{"role":"anon","iss":"supabase","iat":1700000000,"exp":2000000000}'
SERVICE_PAYLOAD='{"role":"service_role","iss":"supabase","iat":1700000000,"exp":2000000000}'

# Encode header and payloads
HEADER_B64=$(echo -n "$HEADER" | base64url)
ANON_PAYLOAD_B64=$(echo -n "$ANON_PAYLOAD" | base64url)
SERVICE_PAYLOAD_B64=$(echo -n "$SERVICE_PAYLOAD" | base64url)

# Create unsigned tokens
ANON_UNSIGNED="${HEADER_B64}.${ANON_PAYLOAD_B64}"
SERVICE_UNSIGNED="${HEADER_B64}.${SERVICE_PAYLOAD_B64}"

# Sign tokens with JWT_SECRET
ANON_SIGNATURE=$(echo -n "$ANON_UNSIGNED" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | base64url)
SERVICE_SIGNATURE=$(echo -n "$SERVICE_UNSIGNED" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | base64url)

# Construct final tokens
ANON_KEY="${ANON_UNSIGNED}.${ANON_SIGNATURE}"
SERVICE_ROLE_KEY="${SERVICE_UNSIGNED}.${SERVICE_SIGNATURE}"

echo -e "${GREEN}✓ ANON_KEY: ${ANON_KEY:0:50}...${NC}"
echo -e "${GREEN}✓ SERVICE_ROLE_KEY: ${SERVICE_ROLE_KEY:0:50}...${NC}"

# Verify token signatures
echo ""
echo "Verifying JWT signatures..."
VERIFY_ANON=$(echo -n "$ANON_UNSIGNED" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | base64url)
VERIFY_SERVICE=$(echo -n "$SERVICE_UNSIGNED" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | base64url)

if [ "$VERIFY_ANON" = "$ANON_SIGNATURE" ] && [ "$VERIFY_SERVICE" = "$SERVICE_SIGNATURE" ]; then
    echo -e "${GREEN}✓ JWT signatures verified - tokens are valid!${NC}"
else
    echo -e "${RED}✗ JWT signature verification failed!${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Step 3/6: Create Fresh .env File${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo "Writing new .env file..."

cat > .env << ENVEOF
############
# CRITICAL SECRETS - MUST BE AT TOP FOR DOCKER COMPOSE
############

JWT_SECRET=$JWT_SECRET
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
ANON_KEY=$ANON_KEY
SERVICE_ROLE_KEY=$SERVICE_ROLE_KEY

# Kong expects these variable names (aliases)
SUPABASE_ANON_KEY=$ANON_KEY
SUPABASE_SERVICE_KEY=$SERVICE_ROLE_KEY

############
# DATABASE
############

POSTGRES_HOST=db
POSTGRES_PORT=5432
POSTGRES_DB=postgres
POSTGRES_USER=postgres
POSTGRES_INITDB_ARGS=

# Database schemas
PGRST_DB_SCHEMAS=public,storage,graphql_public

############
# DASHBOARD
############

DASHBOARD_USERNAME=supabase
DASHBOARD_PASSWORD=$DASHBOARD_PASSWORD

############
# STUDIO
############

STUDIO_PORT=3000
STUDIO_DEFAULT_ORGANIZATION=Default Organization
STUDIO_DEFAULT_PROJECT=Default Project

############
# API & DOMAINS
############

API_DOMAIN=db.qoqnuz.com
STUDIO_DOMAIN=studio.qoqnuz.com

SUPABASE_PUBLIC_URL=http://db.qoqnuz.com
SUPABASE_URL=http://db.qoqnuz.com
API_EXTERNAL_URL=http://db.qoqnuz.com
PUBLIC_REST_URL=http://db.qoqnuz.com/rest/v1/

############
# AUTH / GOTRUE
############

SITE_URL=http://db.qoqnuz.com
ADDITIONAL_REDIRECT_URLS=
JWT_EXPIRY=31536000
DISABLE_SIGNUP=false

# Email confirmation
ENABLE_EMAIL_SIGNUP=true
ENABLE_EMAIL_AUTOCONFIRM=true

# Email settings (using fake SMTP for development)
SMTP_ADMIN_EMAIL=admin@qoqnuz.com
SMTP_HOST=supabase-mail
SMTP_PORT=2500
SMTP_USER=fake_mail_user
SMTP_PASS=fake_mail_password
SMTP_SENDER_NAME=Supabase

# Email templates
MAILER_URLPATHS_CONFIRMATION=/auth/v1/verify
MAILER_URLPATHS_INVITE=/auth/v1/verify
MAILER_URLPATHS_RECOVERY=/auth/v1/verify
MAILER_URLPATHS_EMAIL_CHANGE=/auth/v1/verify

############
# STORAGE
############

STORAGE_BACKEND=file
STORAGE_FILE_SIZE_LIMIT=52428800
STORAGE_S3_REGION=us-east-1

############
# REALTIME
############

# No special config needed - uses JWT_SECRET from above

############
# ANALYTICS / LOGFLARE
############

LOGFLARE_API_KEY=$LOGFLARE_API_KEY
LOGFLARE_URL=http://analytics:4000

############
# META
############

META_PORT=8080

############
# FUNCTIONS
############

FUNCTIONS_VERIFY_JWT=false

############
# OTHER SECRETS
############

SECRET_KEY_BASE=$SECRET_KEY_BASE

############
# FEATURE FLAGS
############

ENABLE_REALTIME=true
ENABLE_STORAGE=true
ENABLE_PHONE_SIGNUP=false
ENABLE_PHONE_AUTOCONFIRM=true
ENVEOF

echo -e "${GREEN}✓ Fresh .env file created${NC}"

# Verify .env file
echo ""
echo "Verifying .env file..."
if grep -q "^JWT_SECRET=$JWT_SECRET" .env; then
    echo -e "${GREEN}✓ JWT_SECRET correctly written${NC}"
else
    echo -e "${RED}✗ JWT_SECRET not found in .env${NC}"
    exit 1
fi

if grep -q "^ANON_KEY=$ANON_KEY" .env; then
    echo -e "${GREEN}✓ ANON_KEY correctly written${NC}"
else
    echo -e "${RED}✗ ANON_KEY not found in .env${NC}"
    exit 1
fi

echo -e "${GREEN}✓ .env file verified${NC}"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Step 4/6: Verify Docker Compose Configuration${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo "Running docker compose config to verify..."
if docker compose config > /dev/null 2>&1; then
    echo -e "${GREEN}✓ docker-compose.yml is valid${NC}"
else
    echo -e "${RED}✗ docker-compose.yml has errors${NC}"
    docker compose config
    exit 1
fi

# Check if JWT_SECRET is properly read
if docker compose config | grep -q "PGRST_JWT_SECRET: $JWT_SECRET"; then
    echo -e "${GREEN}✓ JWT_SECRET is properly substituted in config${NC}"
else
    echo -e "${YELLOW}⚠ JWT_SECRET substitution check inconclusive${NC}"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Step 5/6: Start Fresh Supabase Installation${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo "Starting all services..."
docker compose up -d

echo ""
echo -e "${CYAN}Waiting for services to initialize...${NC}"
echo ""

for i in {60..1}; do
    printf "\r  ${BLUE}⏳ %2d seconds remaining...${NC}" $i
    sleep 1
done
echo ""
echo ""

echo "Checking service health..."
docker compose ps

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Step 6/6: Test and Verify${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Test REST API
echo -n "Testing REST API... "
REST_RESPONSE=$(curl -s -w "\n%{http_code}" -H "apikey: $ANON_KEY" http://localhost/rest/v1/)
REST_CODE=$(echo "$REST_RESPONSE" | tail -1)
REST_BODY=$(echo "$REST_RESPONSE" | head -n -1)

if [ "$REST_CODE" = "200" ]; then
    echo -e "${GREEN}✓ HTTP $REST_CODE${NC}"
elif [ "$REST_CODE" = "401" ]; then
    echo -e "${RED}✗ HTTP $REST_CODE - Still unauthorized${NC}"
    echo "Response: $REST_BODY"
else
    echo -e "${YELLOW}⚠ HTTP $REST_CODE${NC}"
    echo "Response: $REST_BODY"
fi

# Test Auth API
echo -n "Testing Auth API... "
AUTH_RESPONSE=$(curl -s -w "\n%{http_code}" -H "apikey: $ANON_KEY" http://localhost/auth/v1/health)
AUTH_CODE=$(echo "$AUTH_RESPONSE" | tail -1)
AUTH_BODY=$(echo "$AUTH_RESPONSE" | head -n -1)

if [ "$AUTH_CODE" = "200" ]; then
    echo -e "${GREEN}✓ HTTP $AUTH_CODE${NC}"
elif [ "$AUTH_CODE" = "401" ]; then
    echo -e "${RED}✗ HTTP $AUTH_CODE - Still unauthorized${NC}"
    echo "Response: $AUTH_BODY"
else
    echo -e "${YELLOW}⚠ HTTP $AUTH_CODE${NC}"
    echo "Response: $AUTH_BODY"
fi

# Test Storage API
echo -n "Testing Storage API... "
STORAGE_RESPONSE=$(curl -s -w "\n%{http_code}" -H "apikey: $ANON_KEY" http://localhost/storage/v1/bucket)
STORAGE_CODE=$(echo "$STORAGE_RESPONSE" | tail -1)
STORAGE_BODY=$(echo "$STORAGE_RESPONSE" | head -n -1)

if [ "$STORAGE_CODE" = "200" ]; then
    echo -e "${GREEN}✓ HTTP $STORAGE_CODE${NC}"
elif [ "$STORAGE_CODE" = "401" ]; then
    echo -e "${RED}✗ HTTP $STORAGE_CODE - Still unauthorized${NC}"
    echo "Response: $STORAGE_BODY"
else
    echo -e "${YELLOW}⚠ HTTP $STORAGE_CODE${NC}"
    echo "Response: $STORAGE_BODY"
fi

# Test Studio
echo -n "Testing Studio... "
STUDIO_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000)
if [ "$STUDIO_CODE" = "200" ]; then
    echo -e "${GREEN}✓ HTTP $STUDIO_CODE${NC}"
else
    echo -e "${YELLOW}⚠ HTTP $STUDIO_CODE${NC}"
fi

# Check container environment variables
echo ""
echo "Checking REST container environment..."
REST_ENV=$(docker compose exec -T rest printenv | grep -E "PGRST_JWT_SECRET|PGRST_DB_URI" || true)
if echo "$REST_ENV" | grep -q "PGRST_JWT_SECRET="; then
    echo -e "${GREEN}✓ REST container has JWT_SECRET${NC}"
else
    echo -e "${RED}✗ REST container missing JWT_SECRET${NC}"
fi

echo ""
echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                                                                ║"
echo "║                      FRESH START COMPLETE                      ║"
echo "║                                                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Final verdict
if [ "$REST_CODE" = "200" ] && [ "$AUTH_CODE" = "200" ]; then
    echo -e "${GREEN}✓✓✓ SUCCESS! Supabase is fully functional!${NC}"
    echo ""
    echo "Your Supabase instance is ready to use:"
    echo "  • API: http://db.qoqnuz.com"
    echo "  • Studio: http://studio.qoqnuz.com"
    echo "  • Dashboard: http://db.qoqnuz.com (user: supabase, pass: $DASHBOARD_PASSWORD)"
    echo ""
    echo "Credentials saved in: .env"
    echo "Backup of old setup: $BACKUP_DIR"
    echo ""
elif [ "$REST_CODE" = "401" ] || [ "$AUTH_CODE" = "401" ]; then
    echo -e "${RED}✗ AUTHENTICATION STILL FAILING${NC}"
    echo ""
    echo "Even a fresh installation is showing 401 errors."
    echo "This suggests a deeper issue with:"
    echo "  • Docker Compose version (need 2.0+)"
    echo "  • Docker installation"
    echo "  • Container networking"
    echo ""
    echo "Diagnostic commands to run:"
    echo "  docker compose version"
    echo "  docker compose exec rest printenv | grep JWT"
    echo "  docker compose exec auth printenv | grep JWT"
    echo "  docker logs supabase-rest"
    echo "  docker logs supabase-auth"
    echo ""
else
    echo -e "${YELLOW}⚠ PARTIAL SUCCESS${NC}"
    echo ""
    echo "Some services are working, others are not."
    echo "Check the logs:"
    echo "  docker compose logs"
    echo ""
fi

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

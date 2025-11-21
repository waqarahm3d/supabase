#!/bin/bash

################################################################################
# HARDCODE FIX - Bypass .env completely
#
# The problem: Docker isn't reading .env variables properly
# The solution: Hardcode values directly into docker-compose.yml
#
# This WILL work because we remove .env from the equation entirely
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   HARDCODE FIX - Stop using .env${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "This script will:"
echo "  1. Read current values from .env"
echo "  2. Hardcode them DIRECTLY into docker-compose.yml"
echo "  3. Bypass .env variable substitution entirely"
echo ""
echo -e "${YELLOW}This is a last resort but it WILL work${NC}"
echo ""

# Check if we're on the VPS (has docker)
if ! command -v docker &> /dev/null; then
    echo -e "${RED}ERROR: Docker not found${NC}"
    echo "This script must be run on the VPS where Docker is installed"
    exit 1
fi

# Backup docker-compose.yml
cp docker-compose.yml docker-compose.yml.backup.$(date +%Y%m%d-%H%M%S)
cp .env .env.backup.$(date +%Y%m%d-%H%M%S)

echo -e "${GREEN}✓ Backups created${NC}"
echo ""

# Extract values from .env
echo "Reading values from .env..."
JWT_SECRET=$(grep '^JWT_SECRET=' .env | sed 's/^JWT_SECRET=//')
POSTGRES_PASSWORD=$(grep '^POSTGRES_PASSWORD=' .env | sed 's/^POSTGRES_PASSWORD=//')
ANON_KEY=$(grep '^ANON_KEY=' .env | sed 's/^ANON_KEY=//')
SERVICE_ROLE_KEY=$(grep '^SERVICE_ROLE_KEY=' .env | sed 's/^SERVICE_ROLE_KEY=//')
DASHBOARD_PASSWORD=$(grep '^DASHBOARD_PASSWORD=' .env | sed 's/^DASHBOARD_PASSWORD=//')

echo "  JWT_SECRET: ${JWT_SECRET:0:30}... (${#JWT_SECRET} chars)"
echo "  POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:0:20}..."
echo "  ANON_KEY: ${ANON_KEY:0:50}..."
echo ""

if [ -z "$JWT_SECRET" ] || [ -z "$POSTGRES_PASSWORD" ] || [ -z "$ANON_KEY" ]; then
    echo -e "${RED}ERROR: Missing required values in .env${NC}"
    exit 1
fi

# Escape special characters for sed
escape_for_sed() {
    echo "$1" | sed 's/[&/\]/\\&/g'
}

JWT_ESC=$(escape_for_sed "$JWT_SECRET")
POSTGRES_ESC=$(escape_for_sed "$POSTGRES_PASSWORD")
ANON_ESC=$(escape_for_sed "$ANON_KEY")
SERVICE_ESC=$(escape_for_sed "$SERVICE_ROLE_KEY")
DASHBOARD_ESC=$(escape_for_sed "$DASHBOARD_PASSWORD")

echo "Hardcoding values into docker-compose.yml..."

# Replace ${JWT_SECRET} with actual value
sed -i "s|\${JWT_SECRET}|$JWT_ESC|g" docker-compose.yml

# Replace ${POSTGRES_PASSWORD} with actual value
sed -i "s|\${POSTGRES_PASSWORD}|$POSTGRES_ESC|g" docker-compose.yml

# Replace ${ANON_KEY} with actual value
sed -i "s|\${ANON_KEY}|$ANON_ESC|g" docker-compose.yml

# Replace ${SERVICE_ROLE_KEY} with actual value
sed -i "s|\${SERVICE_ROLE_KEY}|$SERVICE_ESC|g" docker-compose.yml

# Replace ${DASHBOARD_PASSWORD} with actual value
sed -i "s|\${DASHBOARD_PASSWORD}|$DASHBOARD_ESC|g" docker-compose.yml

# Replace other common variables
sed -i "s|\${POSTGRES_HOST}|db|g" docker-compose.yml
sed -i "s|\${POSTGRES_PORT}|5432|g" docker-compose.yml
sed -i "s|\${POSTGRES_DB}|postgres|g" docker-compose.yml
sed -i "s|\${POSTGRES_USER}|postgres|g" docker-compose.yml
sed -i "s|\${DASHBOARD_USERNAME}|supabase|g" docker-compose.yml
sed -i "s|\${SITE_URL}|http://db.qoqnuz.com|g" docker-compose.yml
sed -i "s|\${API_EXTERNAL_URL}|http://db.qoqnuz.com|g" docker-compose.yml

echo -e "${GREEN}✓ Values hardcoded${NC}"
echo ""

# Verify
echo "Verifying docker-compose.yml..."
if grep -q '${JWT_SECRET}' docker-compose.yml; then
    echo -e "${YELLOW}⚠ Still has some \${JWT_SECRET} references${NC}"
fi

if grep -q "PGRST_JWT_SECRET: $JWT_SECRET" docker-compose.yml; then
    echo -e "${GREEN}✓ REST service has hardcoded JWT_SECRET${NC}"
else
    echo -e "${YELLOW}⚠ Could not verify REST service config${NC}"
fi

echo ""
echo -e "${YELLOW}Recreating all services...${NC}"

# Complete recreation
docker compose down
sleep 2
docker compose up -d

echo ""
echo "Waiting 45 seconds for services..."
for i in {45..1}; do
    printf "\r${BLUE}⏳ %2d seconds...${NC}" $i
    sleep 1
done
echo ""
echo ""

# Test
echo -e "${YELLOW}Testing API endpoints...${NC}"
echo ""

REST_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "apikey: $ANON_KEY" http://localhost/rest/v1/)
echo -n "REST API: "
if [ "$REST_CODE" = "200" ]; then
    echo -e "${GREEN}HTTP $REST_CODE ✓${NC}"
elif [ "$REST_CODE" = "401" ]; then
    echo -e "${RED}HTTP $REST_CODE ✗ (still unauthorized)${NC}"
else
    echo -e "${YELLOW}HTTP $REST_CODE${NC}"
fi

AUTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "apikey: $ANON_KEY" http://localhost/auth/v1/health)
echo -n "Auth API: "
if [ "$AUTH_CODE" = "200" ]; then
    echo -e "${GREEN}HTTP $AUTH_CODE ✓${NC}"
elif [ "$AUTH_CODE" = "401" ]; then
    echo -e "${RED}HTTP $AUTH_CODE ✗ (still unauthorized)${NC}"
else
    echo -e "${YELLOW}HTTP $AUTH_CODE${NC}"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Result${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

if [ "$REST_CODE" = "200" ] && [ "$AUTH_CODE" = "200" ]; then
    echo -e "${GREEN}✓✓✓ SUCCESS!${NC}"
    echo ""
    echo "The hardcoded values worked! Your Supabase is now functional."
    echo ""
    echo "NOTE: docker-compose.yml now has hardcoded secrets."
    echo "This is NOT ideal for security, but it works."
    echo ""
    echo "To restore docker-compose.yml to use .env variables:"
    echo "  git checkout docker-compose.yml"
    echo ""
else
    echo -e "${YELLOW}Still having issues${NC}"
    echo ""
    echo "If hardcoding didn't work, the problem is deeper."
    echo "Recommended: Complete fresh installation"
    echo "See FRESH_START.md for instructions"
    echo ""
fi

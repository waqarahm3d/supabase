#!/bin/bash

################################################################################
# ABSOLUTE FINAL FIX
# Fixes the REAL problems:
# 1. JWT_SECRET not at top of .env (docker-compose can't find it)
# 2. Kong config variables not substituted
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   ABSOLUTE FINAL FIX${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

################################################################################
# STEP 1: Reorganize .env so critical vars are at TOP
################################################################################

echo -e "${YELLOW}STEP 1: Reorganizing .env file${NC}"
echo "Moving critical variables to top of file..."

# Backup
cp .env .env.backup.reorganize.$(date +%Y%m%d-%H%M%S)

# Extract critical values
JWT_SECRET=$(grep '^JWT_SECRET=' .env | sed 's/^JWT_SECRET=//')
POSTGRES_PASSWORD=$(grep '^POSTGRES_PASSWORD=' .env | sed 's/^POSTGRES_PASSWORD=//')
ANON_KEY=$(grep '^ANON_KEY=' .env | sed 's/^ANON_KEY=//')
SERVICE_ROLE_KEY=$(grep '^SERVICE_ROLE_KEY=' .env | sed 's/^SERVICE_ROLE_KEY=//')
SUPABASE_ANON_KEY=$(grep '^SUPABASE_ANON_KEY=' .env | sed 's/^SUPABASE_ANON_KEY=//')
SUPABASE_SERVICE_KEY=$(grep '^SUPABASE_SERVICE_KEY=' .env | sed 's/^SUPABASE_SERVICE_KEY=//')
DASHBOARD_PASSWORD=$(grep '^DASHBOARD_PASSWORD=' .env | sed 's/^DASHBOARD_PASSWORD=//')
DASHBOARD_USERNAME=$(grep '^DASHBOARD_USERNAME=' .env | sed 's/^DASHBOARD_USERNAME=//')

# Remove these lines from current .env
grep -v '^JWT_SECRET=' .env | \
grep -v '^POSTGRES_PASSWORD=' | \
grep -v '^ANON_KEY=' | \
grep -v '^SERVICE_ROLE_KEY=' | \
grep -v '^SUPABASE_ANON_KEY=' | \
grep -v '^SUPABASE_SERVICE_KEY=' | \
grep -v '^DASHBOARD_PASSWORD=' | \
grep -v '^DASHBOARD_USERNAME=' > .env.tmp

# Create new .env with critical vars at top
cat > .env << EOF
############
# CRITICAL VARIABLES - MUST BE AT TOP
############

# JWT Secret - MUST be before services that use it
JWT_SECRET=${JWT_SECRET}

# Database Password
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

# JWT Keys
ANON_KEY=${ANON_KEY}
SERVICE_ROLE_KEY=${SERVICE_ROLE_KEY}

# Kong expects these (aliases)
SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}
SUPABASE_SERVICE_KEY=${SUPABASE_SERVICE_KEY}

# Dashboard credentials
DASHBOARD_USERNAME=${DASHBOARD_USERNAME}
DASHBOARD_PASSWORD=${DASHBOARD_PASSWORD}

############
# REST OF CONFIGURATION
############

EOF

# Append rest of config
cat .env.tmp >> .env
rm .env.tmp

echo -e "${GREEN}✓ .env reorganized - critical vars now at top${NC}"
echo ""

################################################################################
# STEP 2: Manually fix Kong config
################################################################################

echo -e "${YELLOW}STEP 2: Fixing Kong configuration${NC}"

# Check if Kong config has unsubstituted vars
UNSUBBED=$(docker exec supabase-kong grep -c '\${' /home/kong/kong.yml 2>/dev/null || echo "0")

if [ "$UNSUBBED" != "0" ]; then
    echo "Kong config has $UNSUBBED unsubstituted variables"
    echo "Substituting manually..."

    # Escape special characters
    ANON_ESCAPED=$(echo "$ANON_KEY" | sed 's/[\/&]/\\&/g')
    SERVICE_ESCAPED=$(echo "$SERVICE_ROLE_KEY" | sed 's/[\/&]/\\&/g')
    PASSWORD_ESCAPED=$(echo "$DASHBOARD_PASSWORD" | sed 's/[\/&]/\\&/g')

    # Substitute in container
    docker exec supabase-kong sh -c "
        sed -i 's/\\\${ANON_KEY}/$ANON_ESCAPED/g' /home/kong/kong.yml
        sed -i 's/\\\${SERVICE_ROLE_KEY}/$SERVICE_ESCAPED/g' /home/kong/kong.yml
        sed -i 's/\\\${DASHBOARD_PASSWORD}/$PASSWORD_ESCAPED/g' /home/kong/kong.yml
    " 2>/dev/null && echo -e "${GREEN}✓ Kong config fixed${NC}" || echo -e "${YELLOW}⚠ Will fix on restart${NC}"
else
    echo -e "${GREEN}✓ Kong config already good${NC}"
fi

echo ""

################################################################################
# STEP 3: Recreate ALL services
################################################################################

echo -e "${YELLOW}STEP 3: Recreating all services with fixed configuration${NC}"

echo "Stopping all services..."
docker compose down

echo ""
echo "Starting services with reorganized .env..."
docker compose up -d

echo ""
echo "Waiting 60 seconds for initialization..."
for i in {60..1}; do
    printf "\r${BLUE}⏳ %2d seconds...${NC}" $i
    sleep 1
done
echo ""
echo ""

################################################################################
# STEP 4: Verify
################################################################################

echo -e "${YELLOW}STEP 4: Verification${NC}"
echo ""

# Check if REST has JWT_SECRET now
echo "Checking REST service JWT_SECRET:"
docker compose exec db psql -U postgres -c "SELECT current_setting('pgrst.jwt_secret', true);" 2>/dev/null || echo "Could not query"

# Check Kong config
echo ""
echo "Checking Kong config:"
KONG_VARS=$(docker exec supabase-kong grep -c '\${' /home/kong/kong.yml 2>/dev/null || echo "0")
if [ "$KONG_VARS" = "0" ]; then
    echo -e "${GREEN}✓ Kong config has no unsubstituted variables${NC}"
else
    echo -e "${YELLOW}⚠ Kong still has $KONG_VARS unsubstituted variables${NC}"
fi

# Test endpoints
echo ""
echo "Testing API endpoints:"

REST_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "apikey: $ANON_KEY" http://localhost/rest/v1/ 2>/dev/null)
echo -n "  REST API: "
if [ "$REST_CODE" = "200" ]; then
    echo -e "${GREEN}HTTP $REST_CODE ✓${NC}"
elif [ "$REST_CODE" = "401" ]; then
    echo -e "${RED}HTTP $REST_CODE ✗${NC}"
else
    echo -e "${YELLOW}HTTP $REST_CODE${NC}"
fi

AUTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "apikey: $ANON_KEY" http://localhost/auth/v1/health 2>/dev/null)
echo -n "  Auth API: "
if [ "$AUTH_CODE" = "200" ]; then
    echo -e "${GREEN}HTTP $AUTH_CODE ✓${NC}"
elif [ "$AUTH_CODE" = "401" ]; then
    echo -e "${RED}HTTP $AUTH_CODE ✗${NC}"
else
    echo -e "${YELLOW}HTTP $AUTH_CODE${NC}"
fi

echo ""

################################################################################
# Summary
################################################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Result${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

if [ "$REST_CODE" = "200" ] && [ "$AUTH_CODE" = "200" ]; then
    echo -e "${GREEN}✓✓✓ SUCCESS!${NC}"
    echo ""
    echo "Both critical issues fixed:"
    echo "  1. JWT_SECRET now at top of .env (docker-compose can find it)"
    echo "  2. Kong config variables substituted"
    echo ""
    echo "Your Supabase is WORKING!"
    echo ""
    echo "Test:"
    echo "  curl -H \"apikey: $ANON_KEY\" http://localhost/rest/v1/"
    echo ""
else
    echo -e "${YELLOW}Still having issues${NC}"
    echo ""
    echo "Debug commands:"
    echo "  # Check if REST has JWT_SECRET:"
    echo "  docker compose exec rest printenv | grep JWT || echo 'No JWT vars'"
    echo ""
    echo "  # Check Kong config:"
    echo "  docker exec supabase-kong grep 'key:' /home/kong/kong.yml | head -5"
    echo ""
    echo "  # View REST logs:"
    echo "  docker compose logs rest --tail=20"
    echo ""
fi

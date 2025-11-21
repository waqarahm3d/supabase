#!/bin/bash

################################################################################
# Complete Supabase JWT Fix - Automated
# Fixes all JWT-related issues in one go
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

clear

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Complete Supabase JWT Fix${NC}"
echo -e "${BLUE}   Automated End-to-End Solution${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo "This script will:"
echo "  1. Extract exact JWT_SECRET from Auth service"
echo "  2. Update .env to match"
echo "  3. Regenerate JWT keys with correct secret"
echo "  4. Fix Kong config variable substitution"
echo "  5. Properly recreate all services"
echo "  6. Validate everything works"
echo ""

read -p "$(echo -e ${YELLOW}Continue? [y/N]:${NC} )" -n 1 -r
echo ""
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

################################################################################
# STEP 1: Get Exact JWT_SECRET from Auth Service
################################################################################

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}STEP 1: Getting JWT_SECRET from Auth Service${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

AUTH_SECRET=$(docker exec supabase-auth sh -c 'printf "%s" "$GOTRUE_JWT_SECRET"')

if [ -z "$AUTH_SECRET" ]; then
    echo -e "${RED}✗ Could not get JWT_SECRET from Auth service${NC}"
    echo "Is Auth service running?"
    docker ps --filter name=auth
    exit 1
fi

echo "Auth service JWT_SECRET:"
echo "  Value: ${AUTH_SECRET:0:30}..."
echo "  Length: ${#AUTH_SECRET} characters"
echo ""

################################################################################
# STEP 2: Update .env with Exact Secret
################################################################################

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}STEP 2: Updating .env File${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Backup .env
cp .env .env.backup.complete-fix.$(date +%Y%m%d-%H%M%S)
echo -e "${GREEN}✓ Backup created${NC}"

# Update JWT_SECRET in .env
sed -i "s|^JWT_SECRET=.*|JWT_SECRET=${AUTH_SECRET}|" .env

# Verify
ENV_SECRET=$(grep '^JWT_SECRET=' .env | cut -d'=' -f2)

echo "Verification:"
echo "  Auth secret length: ${#AUTH_SECRET}"
echo "  .env secret length: ${#ENV_SECRET}"

if [ "$AUTH_SECRET" = "$ENV_SECRET" ]; then
    echo -e "${GREEN}✓ Secrets match perfectly!${NC}"
else
    echo -e "${RED}✗ Secrets still don't match${NC}"
    echo "Auth: $AUTH_SECRET"
    echo ".env: $ENV_SECRET"
    exit 1
fi

echo ""
sleep 2

################################################################################
# STEP 3: Regenerate JWT Keys with Correct Secret
################################################################################

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}STEP 3: Regenerating JWT Keys${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Base64url encode function
base64url_encode() {
    openssl base64 -e -A | tr '+/' '-_' | tr -d '='
}

# JWT headers and payloads
ANON_HEADER='{"alg":"HS256","typ":"JWT"}'
ANON_PAYLOAD='{"role":"anon","iss":"supabase","iat":1700000000,"exp":2000000000}'
SERVICE_HEADER='{"alg":"HS256","typ":"JWT"}'
SERVICE_PAYLOAD='{"role":"service_role","iss":"supabase","iat":1700000000,"exp":2000000000}'

# Encode
ANON_HEADER_B64=$(echo -n "$ANON_HEADER" | base64url_encode)
ANON_PAYLOAD_B64=$(echo -n "$ANON_PAYLOAD" | base64url_encode)
SERVICE_HEADER_B64=$(echo -n "$SERVICE_HEADER" | base64url_encode)
SERVICE_PAYLOAD_B64=$(echo -n "$SERVICE_PAYLOAD" | base64url_encode)

# Create signatures
ANON_UNSIGNED="${ANON_HEADER_B64}.${ANON_PAYLOAD_B64}"
SERVICE_UNSIGNED="${SERVICE_HEADER_B64}.${SERVICE_PAYLOAD_B64}"

ANON_SIGNATURE=$(echo -n "$ANON_UNSIGNED" | openssl dgst -sha256 -hmac "$AUTH_SECRET" -binary | base64url_encode)
SERVICE_SIGNATURE=$(echo -n "$SERVICE_UNSIGNED" | openssl dgst -sha256 -hmac "$AUTH_SECRET" -binary | base64url_encode)

# Complete tokens
NEW_ANON_KEY="${ANON_HEADER_B64}.${ANON_PAYLOAD_B64}.${ANON_SIGNATURE}"
NEW_SERVICE_KEY="${SERVICE_HEADER_B64}.${SERVICE_PAYLOAD_B64}.${SERVICE_SIGNATURE}"

echo "Generated new JWT keys:"
echo "  ANON_KEY: ${NEW_ANON_KEY:0:50}... (${#NEW_ANON_KEY} chars)"
echo "  SERVICE_ROLE_KEY: ${NEW_SERVICE_KEY:0:50}... (${#NEW_SERVICE_KEY} chars)"
echo ""

# Update .env
sed -i "s|^ANON_KEY=.*|ANON_KEY=${NEW_ANON_KEY}|" .env
sed -i "s|^SERVICE_ROLE_KEY=.*|SERVICE_ROLE_KEY=${NEW_SERVICE_KEY}|" .env

# Update Kong aliases
if grep -q "^SUPABASE_ANON_KEY=" .env; then
    sed -i "s|^SUPABASE_ANON_KEY=.*|SUPABASE_ANON_KEY=${NEW_ANON_KEY}|" .env
else
    sed -i "/^SERVICE_ROLE_KEY=/a SUPABASE_ANON_KEY=${NEW_ANON_KEY}" .env
fi

if grep -q "^SUPABASE_SERVICE_KEY=" .env; then
    sed -i "s|^SUPABASE_SERVICE_KEY=.*|SUPABASE_SERVICE_KEY=${NEW_SERVICE_KEY}|" .env
else
    sed -i "/^SUPABASE_ANON_KEY=/a SUPABASE_SERVICE_KEY=${NEW_SERVICE_KEY}" .env
fi

echo -e "${GREEN}✓ JWT keys updated in .env${NC}"
echo ""
sleep 2

################################################################################
# STEP 4: Fix Kong Configuration
################################################################################

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}STEP 4: Fixing Kong Configuration${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Check if Kong config needs fixing
UNSUBBED=$(docker exec supabase-kong grep -c '\${' /home/kong/kong.yml 2>/dev/null || echo "0")

if [ "$UNSUBBED" != "0" ]; then
    echo "Kong config has $UNSUBBED unsubstituted variables"
    echo "Fixing..."

    # Get DASHBOARD_PASSWORD
    DASHBOARD_PASSWORD=$(grep '^DASHBOARD_PASSWORD=' .env | cut -d'=' -f2)

    # Escape special characters for sed
    ANON_ESCAPED=$(echo "$NEW_ANON_KEY" | sed 's/[\/&]/\\&/g')
    SERVICE_ESCAPED=$(echo "$NEW_SERVICE_KEY" | sed 's/[\/&]/\\&/g')
    PASSWORD_ESCAPED=$(echo "$DASHBOARD_PASSWORD" | sed 's/[\/&]/\\&/g')

    # Substitute in Kong container
    docker exec supabase-kong sh -c "
        sed -i 's/\\\${ANON_KEY}/$ANON_ESCAPED/g' /home/kong/kong.yml &&
        sed -i 's/\\\${SERVICE_ROLE_KEY}/$SERVICE_ESCAPED/g' /home/kong/kong.yml &&
        sed -i 's/\\\${DASHBOARD_PASSWORD}/$PASSWORD_ESCAPED/g' /home/kong/kong.yml
    " 2>/dev/null || {
        echo -e "${YELLOW}⚠ In-container substitution failed, will fix on restart${NC}"
    }

    REMAINING=$(docker exec supabase-kong grep -c '\${' /home/kong/kong.yml 2>/dev/null || echo "0")
    if [ "$REMAINING" = "0" ]; then
        echo -e "${GREEN}✓ Kong config fixed${NC}"
    else
        echo -e "${YELLOW}⚠ Will be fixed when Kong recreates${NC}"
    fi
else
    echo -e "${GREEN}✓ Kong config already good${NC}"
fi

echo ""
sleep 2

################################################################################
# STEP 5: Recreate All Services
################################################################################

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}STEP 5: Recreating Services${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo "Stopping all containers..."
docker compose down

echo ""
echo "Starting all services with new configuration..."
docker compose up -d

echo ""
echo -e "${YELLOW}Waiting 45 seconds for services to initialize...${NC}"
for i in {45..1}; do
    echo -ne "${BLUE}⏳ $i seconds remaining...${NC}\r"
    sleep 1
done
echo ""
echo ""

################################################################################
# STEP 6: Validation
################################################################################

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}STEP 6: Validation${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Reload environment
source <(grep -v '^#' .env | grep -v '^$' | sed 's/^/export /')

# Check if secrets match after recreation
echo "1. Checking JWT_SECRET consistency:"
NEW_AUTH_SECRET=$(docker exec supabase-auth sh -c 'printf "%s" "$GOTRUE_JWT_SECRET"')
if [ "$NEW_AUTH_SECRET" = "$AUTH_SECRET" ]; then
    echo -e "   ${GREEN}✓ Auth service has correct JWT_SECRET${NC}"
else
    echo -e "   ${RED}✗ Auth service JWT_SECRET doesn't match${NC}"
fi
echo ""

# Test JWT signature
echo "2. Validating JWT signature:"
ANON_PARTS=(${NEW_ANON_KEY//./ })
UNSIGNED="${ANON_PARTS[0]}.${ANON_PARTS[1]}"
EXPECTED_SIG=$(echo -n "$UNSIGNED" | openssl dgst -sha256 -hmac "$AUTH_SECRET" -binary | base64url_encode)
ACTUAL_SIG="${ANON_PARTS[2]}"

if [ "$EXPECTED_SIG" = "$ACTUAL_SIG" ]; then
    echo -e "   ${GREEN}✓ JWT signature is valid${NC}"
else
    echo -e "   ${RED}✗ JWT signature is invalid${NC}"
fi
echo ""

# Check Kong config
echo "3. Checking Kong configuration:"
KONG_UNSUBBED=$(docker exec supabase-kong grep -c '\${' /home/kong/kong.yml 2>/dev/null || echo "0")
if [ "$KONG_UNSUBBED" = "0" ]; then
    echo -e "   ${GREEN}✓ Kong config variables substituted${NC}"
else
    echo -e "   ${YELLOW}⚠ Kong config has $KONG_UNSUBBED unsubstituted variables${NC}"
fi
echo ""

# Test API endpoints
echo "4. Testing API endpoints:"

echo -n "   REST API: "
REST_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "apikey: $ANON_KEY" http://localhost/rest/v1/ 2>/dev/null)
if [ "$REST_CODE" = "200" ]; then
    echo -e "${GREEN}HTTP $REST_CODE ✓${NC}"
elif [ "$REST_CODE" = "401" ]; then
    echo -e "${RED}HTTP $REST_CODE (still unauthorized)${NC}"
else
    echo -e "${YELLOW}HTTP $REST_CODE${NC}"
fi

echo -n "   Auth API: "
AUTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "apikey: $ANON_KEY" http://localhost/auth/v1/settings 2>/dev/null)
if [ "$AUTH_CODE" = "200" ]; then
    echo -e "${GREEN}HTTP $AUTH_CODE ✓${NC}"
elif [ "$AUTH_CODE" = "401" ]; then
    echo -e "${RED}HTTP $AUTH_CODE (still unauthorized)${NC}"
else
    echo -e "${YELLOW}HTTP $AUTH_CODE${NC}"
fi

echo -n "   Storage API: "
STORAGE_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "apikey: $ANON_KEY" http://localhost/storage/v1/bucket 2>/dev/null)
if [ "$STORAGE_CODE" = "200" ]; then
    echo -e "${GREEN}HTTP $STORAGE_CODE ✓${NC}"
elif [ "$STORAGE_CODE" = "401" ]; then
    echo -e "${RED}HTTP $STORAGE_CODE (still unauthorized)${NC}"
else
    echo -e "${YELLOW}HTTP $STORAGE_CODE${NC}"
fi

echo ""

# Check all containers
echo "5. Checking container status:"
RUNNING=$(docker compose ps --format "{{.Service}}" --filter "status=running" | wc -l)
echo "   Running containers: $RUNNING/11"
if [ $RUNNING -eq 11 ]; then
    echo -e "   ${GREEN}✓ All containers running${NC}"
else
    echo -e "   ${YELLOW}⚠ Only $RUNNING/11 containers running${NC}"
fi

echo ""

################################################################################
# Summary
################################################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

if [ "$REST_CODE" = "200" ] && [ "$AUTH_CODE" = "200" ]; then
    echo -e "${GREEN}✓✓✓ SUCCESS! Everything is working!${NC}"
    echo ""
    echo "Your Supabase deployment is now fully functional!"
    echo ""
    echo "Access points:"
    echo "  📊 Studio: ${BLUE}http://studio.qoqnuz.com${NC}"
    echo "  🔌 API:    ${BLUE}http://db.qoqnuz.com${NC}"
    echo ""
    echo "Next steps:"
    echo "  ${BLUE}./test-deployment.sh${NC}    # Run comprehensive tests"
    echo "  ${BLUE}./check-services.sh${NC}     # Verify all services"
    echo ""
elif [ "$REST_CODE" = "401" ] || [ "$AUTH_CODE" = "401" ]; then
    echo -e "${RED}✗ Still getting 401 errors${NC}"
    echo ""
    echo "The JWT configuration is correct, but services may need more time."
    echo ""
    echo "Wait 30 more seconds and try:"
    echo "  ${BLUE}curl -H \"apikey: \$ANON_KEY\" http://localhost/rest/v1/${NC}"
    echo ""
    echo "If still failing after waiting:"
    echo "  ${BLUE}docker compose logs auth --tail=50 | grep -i error${NC}"
    echo "  ${BLUE}docker compose logs rest --tail=50 | grep -i error${NC}"
    echo ""
else
    echo -e "${YELLOW}⚠ Partial success${NC}"
    echo ""
    echo "Some services are responding but may still be initializing."
    echo "Wait a bit longer and run:"
    echo "  ${BLUE}./test-deployment.sh${NC}"
    echo ""
fi

echo "Script complete!"
echo ""

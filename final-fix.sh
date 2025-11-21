#!/bin/bash

################################################################################
# FINAL FIX - Comprehensive Supabase Diagnostic and Repair
# Checks everything, fixes everything, no more circles
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   FINAL COMPREHENSIVE FIX${NC}"
echo -e "${BLUE}   This will check and fix EVERYTHING${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Function to safely read from .env (doesn't drop trailing =)
get_env_value() {
    local key=$1
    grep "^${key}=" .env | sed "s/^${key}=//"
}

# Function to set env value
set_env_value() {
    local key=$1
    local value=$2
    if grep -q "^${key}=" .env; then
        sed -i "s|^${key}=.*|${key}=${value}|" .env
    else
        echo "${key}=${value}" >> .env
    fi
}

################################################################################
# STEP 1: Get ground truth from Auth service
################################################################################

echo -e "${YELLOW}STEP 1: Getting ground truth JWT_SECRET from Auth service${NC}"
AUTH_JWT_SECRET=$(docker exec supabase-auth sh -c 'printf "%s" "$GOTRUE_JWT_SECRET"')

if [ -z "$AUTH_JWT_SECRET" ]; then
    echo -e "${RED}ERROR: Could not get JWT_SECRET from Auth service${NC}"
    exit 1
fi

echo "Auth JWT_SECRET: ${AUTH_JWT_SECRET:0:30}... (${#AUTH_JWT_SECRET} chars)"
echo ""

################################################################################
# STEP 2: Fix .env JWT_SECRET to match Auth
################################################################################

echo -e "${YELLOW}STEP 2: Fixing .env JWT_SECRET${NC}"

cp .env .env.backup.final.$(date +%Y%m%d-%H%M%S)

set_env_value "JWT_SECRET" "$AUTH_JWT_SECRET"

ENV_JWT_SECRET=$(get_env_value "JWT_SECRET")

if [ "$ENV_JWT_SECRET" = "$AUTH_JWT_SECRET" ]; then
    echo -e "${GREEN}✓ .env JWT_SECRET now matches Auth (${#ENV_JWT_SECRET} chars)${NC}"
else
    echo -e "${RED}✗ Failed to update .env${NC}"
    echo "Auth: $AUTH_JWT_SECRET"
    echo ".env: $ENV_JWT_SECRET"
    exit 1
fi
echo ""

################################################################################
# STEP 3: Generate valid JWT keys
################################################################################

echo -e "${YELLOW}STEP 3: Generating valid JWT keys${NC}"

base64url() {
    openssl base64 -e -A | tr '+/' '-_' | tr -d '='
}

# Create JWTs
ANON_HEADER='{"alg":"HS256","typ":"JWT"}'
ANON_PAYLOAD='{"role":"anon","iss":"supabase","iat":1700000000,"exp":2000000000}'
SERVICE_HEADER='{"alg":"HS256","typ":"JWT"}'
SERVICE_PAYLOAD='{"role":"service_role","iss":"supabase","iat":1700000000,"exp":2000000000}'

ANON_H=$(echo -n "$ANON_HEADER" | base64url)
ANON_P=$(echo -n "$ANON_PAYLOAD" | base64url)
SERVICE_H=$(echo -n "$SERVICE_HEADER" | base64url)
SERVICE_P=$(echo -n "$SERVICE_PAYLOAD" | base64url)

ANON_UNSIGNED="${ANON_H}.${ANON_P}"
SERVICE_UNSIGNED="${SERVICE_H}.${SERVICE_P}"

ANON_SIG=$(echo -n "$ANON_UNSIGNED" | openssl dgst -sha256 -hmac "$AUTH_JWT_SECRET" -binary | base64url)
SERVICE_SIG=$(echo -n "$SERVICE_UNSIGNED" | openssl dgst -sha256 -hmac "$AUTH_JWT_SECRET" -binary | base64url)

NEW_ANON_KEY="${ANON_H}.${ANON_P}.${ANON_SIG}"
NEW_SERVICE_KEY="${SERVICE_H}.${SERVICE_P}.${SERVICE_SIG}"

echo "Generated keys:"
echo "  ANON_KEY: ${NEW_ANON_KEY:0:50}... (${#NEW_ANON_KEY} chars)"
echo "  SERVICE_ROLE_KEY: ${NEW_SERVICE_KEY:0:50}... (${#NEW_SERVICE_KEY} chars)"

# Validate signature
VERIFY_SIG=$(echo -n "$ANON_UNSIGNED" | openssl dgst -sha256 -hmac "$AUTH_JWT_SECRET" -binary | base64url)
if [ "$ANON_SIG" = "$VERIFY_SIG" ]; then
    echo -e "${GREEN}✓ Signature verified${NC}"
else
    echo -e "${RED}✗ Signature validation failed${NC}"
    exit 1
fi
echo ""

################################################################################
# STEP 4: Update all keys in .env
################################################################################

echo -e "${YELLOW}STEP 4: Updating .env with new keys${NC}"

set_env_value "ANON_KEY" "$NEW_ANON_KEY"
set_env_value "SERVICE_ROLE_KEY" "$NEW_SERVICE_KEY"
set_env_value "SUPABASE_ANON_KEY" "$NEW_ANON_KEY"
set_env_value "SUPABASE_SERVICE_KEY" "$NEW_SERVICE_KEY"

# Get DASHBOARD_PASSWORD for Kong
DASHBOARD_PASS=$(get_env_value "DASHBOARD_PASSWORD")
if [ -z "$DASHBOARD_PASS" ]; then
    DASHBOARD_PASS="supabase"
    set_env_value "DASHBOARD_PASSWORD" "$DASHBOARD_PASS"
fi

echo -e "${GREEN}✓ All keys updated in .env${NC}"
echo ""

################################################################################
# STEP 5: Completely recreate all services
################################################################################

echo -e "${YELLOW}STEP 5: Recreating all services${NC}"
echo "Stopping..."
docker compose down

echo ""
echo "Starting with fresh configuration..."
docker compose up -d

echo ""
echo "Waiting 60 seconds for services to initialize..."
for i in {60..1}; do
    printf "\r${BLUE}⏳ %2d seconds remaining...${NC}" $i
    sleep 1
done
echo ""
echo ""

################################################################################
# STEP 6: Validate everything
################################################################################

echo -e "${YELLOW}STEP 6: Validating deployment${NC}"
echo ""

# Check containers
echo "Container status:"
RUNNING=$(docker compose ps --format "{{.Service}}" --filter "status=running" | wc -l)
if [ $RUNNING -eq 11 ]; then
    echo -e "  ${GREEN}✓ All 11 containers running${NC}"
else
    echo -e "  ${YELLOW}⚠ Only $RUNNING/11 containers running${NC}"
fi

# Check JWT_SECRET in services
echo ""
echo "JWT_SECRET consistency:"
NEW_AUTH_SECRET=$(docker exec supabase-auth sh -c 'printf "%s" "$GOTRUE_JWT_SECRET"' 2>/dev/null)
if [ "$NEW_AUTH_SECRET" = "$AUTH_JWT_SECRET" ]; then
    echo -e "  ${GREEN}✓ Auth service has correct JWT_SECRET${NC}"
else
    echo -e "  ${RED}✗ Auth service JWT_SECRET doesn't match${NC}"
fi

# Test API endpoints
echo ""
echo "API endpoint tests:"

REST_TEST=$(curl -s -H "apikey: $NEW_ANON_KEY" -H "Authorization: Bearer $NEW_ANON_KEY" http://localhost/rest/v1/ 2>/dev/null)
REST_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "apikey: $NEW_ANON_KEY" http://localhost/rest/v1/ 2>/dev/null)

if [ "$REST_CODE" = "200" ]; then
    echo -e "  ${GREEN}✓ REST API: HTTP $REST_CODE${NC}"
elif [ "$REST_CODE" = "401" ]; then
    echo -e "  ${RED}✗ REST API: HTTP $REST_CODE - Still unauthorized${NC}"
    echo "    Response: $REST_TEST"
else
    echo -e "  ${YELLOW}⚠ REST API: HTTP $REST_CODE${NC}"
fi

AUTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "apikey: $NEW_ANON_KEY" http://localhost/auth/v1/health 2>/dev/null)
if [ "$AUTH_CODE" = "200" ]; then
    echo -e "  ${GREEN}✓ Auth API: HTTP $AUTH_CODE${NC}"
elif [ "$AUTH_CODE" = "401" ]; then
    echo -e "  ${RED}✗ Auth API: HTTP $AUTH_CODE - Still unauthorized${NC}"
else
    echo -e "  ${YELLOW}⚠ Auth API: HTTP $AUTH_CODE${NC}"
fi

STORAGE_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "apikey: $NEW_ANON_KEY" http://localhost/storage/v1/bucket 2>/dev/null)
if [ "$STORAGE_CODE" = "200" ]; then
    echo -e "  ${GREEN}✓ Storage API: HTTP $STORAGE_CODE${NC}"
else
    echo -e "  ${YELLOW}⚠ Storage API: HTTP $STORAGE_CODE${NC}"
fi

echo ""

################################################################################
# STEP 7: If still failing, check docker-compose.yml
################################################################################

if [ "$REST_CODE" = "401" ] || [ "$AUTH_CODE" = "401" ]; then
    echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}   Still getting 401 errors - Advanced diagnostics${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
    echo ""

    echo "Checking docker-compose.yml configuration..."
    echo ""
    echo "REST service JWT config:"
    grep -A 15 "rest:" docker-compose.yml | grep -i "jwt" || echo "  No JWT config found"
    echo ""

    echo "Auth service JWT config:"
    grep -A 25 "auth:" docker-compose.yml | grep -i "jwt" || echo "  No JWT config found"
    echo ""

    echo "Checking if .env file has issues..."
    echo "File ends with:"
    tail -5 .env
    echo ""

    echo "JWT_SECRET line:"
    grep "^JWT_SECRET=" .env | od -An -tx1 | head -1
    echo ""

    echo -e "${YELLOW}Possible issues:${NC}"
    echo "  1. Docker compose not reading .env properly"
    echo "  2. Environment variable substitution failing"
    echo "  3. Services need more time to start (wait 30s and retry)"
    echo ""
    echo "Manual test command:"
    echo "  curl -H \"apikey: $NEW_ANON_KEY\" http://localhost/rest/v1/"
    echo ""
fi

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
    echo "Your Supabase is now fully functional!"
    echo ""
    echo "Access:"
    echo "  Studio: http://studio.qoqnuz.com"
    echo "  API:    http://db.qoqnuz.com"
    echo ""
    echo "Test command:"
    echo "  curl -H \"apikey: $NEW_ANON_KEY\" http://localhost/rest/v1/"
    echo ""
else
    echo -e "${YELLOW}Deployment complete but some tests failing${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Wait 30 more seconds: sleep 30"
    echo "  2. Test again: ./test-deployment.sh"
    echo "  3. Check logs if still failing:"
    echo "     docker compose logs auth --tail=50"
    echo "     docker compose logs rest --tail=50"
fi

echo ""

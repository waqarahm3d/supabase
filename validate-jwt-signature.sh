#!/bin/bash

# Validate JWT Signature
# Checks if ANON_KEY signature is valid for current JWT_SECRET

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   JWT Signature Validation${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Load from .env
JWT_SECRET=$(grep '^JWT_SECRET=' .env | cut -d'=' -f2)
ANON_KEY=$(grep '^ANON_KEY=' .env | cut -d'=' -f2)
SERVICE_ROLE_KEY=$(grep '^SERVICE_ROLE_KEY=' .env | cut -d'=' -f2)

echo "JWT_SECRET: ${JWT_SECRET:0:20}... (${#JWT_SECRET} chars)"
echo "ANON_KEY: ${ANON_KEY:0:50}... (${#ANON_KEY} chars)"
echo ""

# Split JWT token into parts
IFS='.' read -r header payload signature <<< "$ANON_KEY"

echo "JWT Structure:"
echo "  Header: $header"
echo "  Payload: $payload"
echo "  Signature: $signature"
echo ""

# Base64url decode function
base64url_decode() {
    local len=$((${#1} % 4))
    local result="$1"
    if [ $len -eq 2 ]; then result="$1"'=='
    elif [ $len -eq 3 ]; then result="$1"'='
    fi
    echo "$result" | tr '_-' '/+' | base64 -d 2>/dev/null
}

# Decode header and payload
echo "Decoded JWT:"
echo "  Header:"
base64url_decode "$header" | jq . 2>/dev/null || base64url_decode "$header"
echo ""
echo "  Payload:"
base64url_decode "$payload" | jq . 2>/dev/null || base64url_decode "$payload"
echo ""

# Validate signature
echo -e "${YELLOW}Validating signature...${NC}"

# Create the unsigned token
unsigned="${header}.${payload}"

# Generate expected signature
base64url_encode() {
    openssl base64 -e -A | tr '+/' '-_' | tr -d '='
}

expected_signature=$(echo -n "$unsigned" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | base64url_encode)

echo "Expected signature: $expected_signature"
echo "Actual signature:   $signature"
echo ""

if [ "$signature" = "$expected_signature" ]; then
    echo -e "${GREEN}✓✓✓ Signature is VALID!${NC}"
    echo "ANON_KEY is correctly signed with your JWT_SECRET"
    echo ""
    SIGNATURE_VALID=true
else
    echo -e "${RED}✗✗✗ Signature is INVALID!${NC}"
    echo "ANON_KEY is NOT signed with your current JWT_SECRET"
    echo ""
    echo "This means the JWT key was generated with a DIFFERENT secret"
    echo "than what's currently in your .env file."
    echo ""
    SIGNATURE_VALID=false
fi

# Check what services have
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Service JWT_SECRET Values${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo "Auth service (GOTRUE_JWT_SECRET):"
AUTH_SECRET=$(docker exec supabase-auth sh -c 'echo $GOTRUE_JWT_SECRET' 2>/dev/null)
if [ -n "$AUTH_SECRET" ]; then
    echo "  ${AUTH_SECRET:0:20}... (${#AUTH_SECRET} chars)"
    if [ "$AUTH_SECRET" = "$JWT_SECRET" ]; then
        echo -e "  ${GREEN}✓ Matches .env JWT_SECRET${NC}"
    else
        echo -e "  ${RED}✗ DOES NOT match .env JWT_SECRET${NC}"
        echo "  This is why Auth returns 401!"
    fi
else
    echo -e "  ${RED}✗ Not set${NC}"
fi
echo ""

echo "REST service (PGRST_JWT_SECRET):"
REST_SECRET=$(docker exec supabase-rest cat /etc/postgrest.conf 2>/dev/null | grep "jwt-secret" | cut -d'"' -f2)
if [ -n "$REST_SECRET" ]; then
    echo "  ${REST_SECRET:0:20}... (${#REST_SECRET} chars)"
    if [ "$REST_SECRET" = "$JWT_SECRET" ]; then
        echo -e "  ${GREEN}✓ Matches .env JWT_SECRET${NC}"
    else
        echo -e "  ${RED}✗ DOES NOT match .env JWT_SECRET${NC}"
        echo "  This is why REST returns 401!"
    fi
else
    echo -e "  ${YELLOW}⚠ Could not read (might use env var)${NC}"
    # Try environment variable
    REST_SECRET_ENV=$(docker exec supabase-rest sh -c 'echo $PGRST_JWT_SECRET' 2>/dev/null)
    if [ -n "$REST_SECRET_ENV" ]; then
        echo "  From env: ${REST_SECRET_ENV:0:20}... (${#REST_SECRET_ENV} chars)"
        if [ "$REST_SECRET_ENV" = "$JWT_SECRET" ]; then
            echo -e "  ${GREEN}✓ Matches .env JWT_SECRET${NC}"
        else
            echo -e "  ${RED}✗ DOES NOT match .env JWT_SECRET${NC}"
        fi
    fi
fi
echo ""

echo "Storage service (uses Auth JWT):"
STORAGE_SECRET=$(docker exec supabase-storage sh -c 'echo $GOTRUE_JWT_SECRET' 2>/dev/null)
if [ -n "$STORAGE_SECRET" ]; then
    echo "  ${STORAGE_SECRET:0:20}... (${#STORAGE_SECRET} chars)"
    if [ "$STORAGE_SECRET" = "$JWT_SECRET" ]; then
        echo -e "  ${GREEN}✓ Matches .env JWT_SECRET${NC}"
    else
        echo -e "  ${RED}✗ DOES NOT match .env JWT_SECRET${NC}"
    fi
else
    echo -e "  ${RED}✗ Not set${NC}"
fi
echo ""

# Summary and fix
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Diagnosis${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

if ! $SIGNATURE_VALID; then
    echo -e "${RED}PROBLEM: ANON_KEY signature doesn't match JWT_SECRET${NC}"
    echo ""
    echo "Your ANON_KEY was signed with a different secret than what's"
    echo "currently in .env. This can happen if:"
    echo "  1. JWT_SECRET was changed after generating keys"
    echo "  2. Keys were copied from another installation"
    echo "  3. Key generation script used wrong secret"
    echo ""
    echo -e "${YELLOW}FIX: Regenerate JWT keys with current JWT_SECRET${NC}"
    echo "  ./regenerate-jwt-keys.sh"
    echo ""
elif [ "$AUTH_SECRET" != "$JWT_SECRET" ] || [ "$REST_SECRET" != "$JWT_SECRET" ]; then
    echo -e "${RED}PROBLEM: Services have different JWT_SECRET than .env${NC}"
    echo ""
    echo "Your JWT keys are valid, but services loaded a different"
    echo "JWT_SECRET than what's in your .env file."
    echo ""
    echo -e "${YELLOW}FIX: Check docker-compose.yml environment variables${NC}"
    echo "Ensure services use: \${JWT_SECRET}"
    echo ""
    echo "Then recreate services:"
    echo "  docker compose up -d --force-recreate auth rest storage"
else
    echo -e "${GREEN}✓ Everything looks correct!${NC}"
    echo ""
    echo "JWT signature is valid and services have matching secrets."
    echo ""
    echo "If still getting 401 errors, wait 30 seconds for services"
    echo "to fully initialize, then test again:"
    echo ""
    echo "  sleep 30"
    echo "  curl -H \"apikey: \$ANON_KEY\" http://localhost/rest/v1/"
fi

echo ""

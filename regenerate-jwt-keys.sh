#!/bin/bash

# Regenerate JWT Keys to Match JWT_SECRET
# This fixes "Invalid authentication credentials" errors

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   JWT Keys Regeneration${NC}"
echo -e "${BLUE}   Generate keys that match your JWT_SECRET${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Load JWT_SECRET from .env
echo -e "${YELLOW}Loading JWT_SECRET from .env...${NC}"
JWT_SECRET=$(grep '^JWT_SECRET=' .env | cut -d'=' -f2)

if [ -z "$JWT_SECRET" ]; then
    echo -e "${RED}✗ JWT_SECRET not found in .env${NC}"
    exit 1
fi

echo "JWT_SECRET length: ${#JWT_SECRET} characters"
echo ""

if [ ${#JWT_SECRET} -lt 32 ]; then
    echo -e "${YELLOW}⚠ WARNING: JWT_SECRET is less than 32 characters${NC}"
    echo "This is less secure than recommended"
    echo ""
fi

# Check if using default secret
if echo "$JWT_SECRET" | grep -q "your-super-secret-jwt-token-with-at-least-32-characters-long"; then
    echo -e "${RED}✗ CRITICAL: You're using the DEFAULT JWT_SECRET!${NC}"
    echo ""
    echo "This is extremely insecure. Would you like to generate a new one?"
    read -p "Generate new JWT_SECRET? [y/N]: " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        NEW_JWT_SECRET=$(openssl rand -base64 32)
        sed -i "s|^JWT_SECRET=.*|JWT_SECRET=$NEW_JWT_SECRET|" .env
        JWT_SECRET="$NEW_JWT_SECRET"
        echo -e "${GREEN}✓ New JWT_SECRET generated${NC}"
        echo ""
    else
        echo -e "${YELLOW}⚠ Continuing with default secret (NOT RECOMMENDED!)${NC}"
        echo ""
    fi
fi

# Backup .env
echo -e "${YELLOW}Creating backup...${NC}"
cp .env .env.backup.jwt.$(date +%Y%m%d-%H%M%S)
echo -e "${GREEN}✓ Backup created${NC}"
echo ""

# Generate new JWT tokens
echo -e "${YELLOW}Generating new JWT tokens signed with your JWT_SECRET...${NC}"
echo ""

# Base64url encode function
base64url_encode() {
    openssl base64 -e -A | tr '+/' '-_' | tr -d '='
}

# JWT headers
ANON_HEADER='{"alg":"HS256","typ":"JWT"}'
SERVICE_HEADER='{"alg":"HS256","typ":"JWT"}'

# JWT payloads - valid for ~30 years
ANON_PAYLOAD='{"role":"anon","iss":"supabase","iat":1700000000,"exp":2000000000}'
SERVICE_PAYLOAD='{"role":"service_role","iss":"supabase","iat":1700000000,"exp":2000000000}'

# Encode headers and payloads
ANON_HEADER_B64=$(echo -n "$ANON_HEADER" | base64url_encode)
ANON_PAYLOAD_B64=$(echo -n "$ANON_PAYLOAD" | base64url_encode)
SERVICE_HEADER_B64=$(echo -n "$SERVICE_HEADER" | base64url_encode)
SERVICE_PAYLOAD_B64=$(echo -n "$SERVICE_PAYLOAD" | base64url_encode)

# Create unsigned tokens
ANON_UNSIGNED="${ANON_HEADER_B64}.${ANON_PAYLOAD_B64}"
SERVICE_UNSIGNED="${SERVICE_HEADER_B64}.${SERVICE_PAYLOAD_B64}"

# Sign with HMAC-SHA256
ANON_SIGNATURE=$(echo -n "$ANON_UNSIGNED" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | base64url_encode)
SERVICE_SIGNATURE=$(echo -n "$SERVICE_UNSIGNED" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | base64url_encode)

# Complete JWT tokens
NEW_ANON_KEY="${ANON_HEADER_B64}.${ANON_PAYLOAD_B64}.${ANON_SIGNATURE}"
NEW_SERVICE_KEY="${SERVICE_HEADER_B64}.${SERVICE_PAYLOAD_B64}.${SERVICE_SIGNATURE}"

echo "Generated:"
echo "  ANON_KEY: ${NEW_ANON_KEY:0:50}... (${#NEW_ANON_KEY} chars)"
echo "  SERVICE_ROLE_KEY: ${NEW_SERVICE_KEY:0:50}... (${#NEW_SERVICE_KEY} chars)"
echo ""

# Update .env
echo -e "${YELLOW}Updating .env file...${NC}"
sed -i "s|^ANON_KEY=.*|ANON_KEY=$NEW_ANON_KEY|" .env
sed -i "s|^SERVICE_ROLE_KEY=.*|SERVICE_ROLE_KEY=$NEW_SERVICE_KEY|" .env

# Update Kong aliases
if grep -q "^SUPABASE_ANON_KEY=" .env; then
    sed -i "s|^SUPABASE_ANON_KEY=.*|SUPABASE_ANON_KEY=$NEW_ANON_KEY|" .env
else
    sed -i "/^SERVICE_ROLE_KEY=/a SUPABASE_ANON_KEY=$NEW_ANON_KEY" .env
fi

if grep -q "^SUPABASE_SERVICE_KEY=" .env; then
    sed -i "s|^SUPABASE_SERVICE_KEY=.*|SUPABASE_SERVICE_KEY=$NEW_SERVICE_KEY|" .env
else
    sed -i "/^SUPABASE_ANON_KEY=/a SUPABASE_SERVICE_KEY=$NEW_SERVICE_KEY" .env
fi

echo -e "${GREEN}✓ .env updated with new JWT keys${NC}"
echo ""

# Verify
echo -e "${YELLOW}Verifying JWT format...${NC}"
if echo "$NEW_ANON_KEY" | grep -qE '^ey[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$'; then
    echo -e "${GREEN}✓ ANON_KEY format valid${NC}"
else
    echo -e "${RED}✗ ANON_KEY format invalid${NC}"
fi

if echo "$NEW_SERVICE_KEY" | grep -qE '^ey[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$'; then
    echo -e "${GREEN}✓ SERVICE_ROLE_KEY format valid${NC}"
else
    echo -e "${RED}✗ SERVICE_ROLE_KEY format invalid${NC}"
fi
echo ""

# Restart services
echo -e "${YELLOW}Restarting services to apply new JWT keys...${NC}"
echo "This will restart all services with the new configuration."
echo ""
read -p "Continue? [y/N]: " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Skipped restart. Run manually:"
    echo "  docker compose restart"
    exit 0
fi

docker compose restart

echo ""
echo -e "${YELLOW}Waiting 30 seconds for services to restart...${NC}"
for i in {30..1}; do
    echo -ne "${BLUE}⏳ $i seconds...${NC}\r"
    sleep 1
done
echo ""
echo ""

# Test new keys
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Testing New JWT Keys${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Reload for testing
source <(grep -v '^#' .env | grep -v '^$' | sed 's/^/export /')

echo "1. Testing REST API with new ANON_KEY:"
REST_RESPONSE=$(curl -s -H "apikey: $ANON_KEY" http://localhost/rest/v1/ 2>&1)
REST_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "apikey: $ANON_KEY" http://localhost/rest/v1/)

if [ "$REST_CODE" = "200" ]; then
    echo -e "${GREEN}✓ REST API accepts new key (HTTP $REST_CODE)${NC}"
    echo "Response: $REST_RESPONSE" | head -3
elif [ "$REST_CODE" = "401" ]; then
    echo -e "${RED}✗ Still getting HTTP 401 - key not accepted${NC}"
    echo "Response: $REST_RESPONSE"
else
    echo -e "${YELLOW}⚠ HTTP $REST_CODE (may need more time)${NC}"
fi
echo ""

echo "2. Testing Auth API:"
AUTH_RESPONSE=$(curl -s -H "apikey: $ANON_KEY" http://localhost/auth/v1/settings 2>&1)
AUTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "apikey: $ANON_KEY" http://localhost/auth/v1/settings)

if [ "$AUTH_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Auth API accepts new key (HTTP $AUTH_CODE)${NC}"
elif [ "$AUTH_CODE" = "401" ]; then
    echo -e "${RED}✗ Still getting HTTP 401${NC}"
    echo "Response: $AUTH_RESPONSE"
else
    echo -e "${YELLOW}⚠ HTTP $AUTH_CODE${NC}"
fi
echo ""

echo "3. Testing Storage API:"
STORAGE_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "apikey: $ANON_KEY" http://localhost/storage/v1/bucket)

if [ "$STORAGE_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Storage API accepts new key (HTTP $STORAGE_CODE)${NC}"
elif [ "$STORAGE_CODE" = "401" ]; then
    echo -e "${RED}✗ Still getting HTTP 401${NC}"
else
    echo -e "${YELLOW}⚠ HTTP $STORAGE_CODE${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

if [ "$REST_CODE" = "200" ] || [ "$AUTH_CODE" = "200" ]; then
    echo -e "${GREEN}✓✓✓ JWT keys successfully regenerated!${NC}"
    echo -e "${GREEN}✓ Services accepting new keys${NC}"
    echo ""
    echo "Your deployment should now be fully functional!"
    echo ""
    echo "Next steps:"
    echo "  ${BLUE}./test-deployment.sh${NC}    # Should show 95%+ pass rate"
    echo "  ${BLUE}./check-services.sh${NC}     # Verify all services"
    echo ""
    echo "Try accessing Studio:"
    echo "  ${BLUE}http://studio.qoqnuz.com${NC}"
else
    echo -e "${YELLOW}⚠ Keys generated but services may still be starting${NC}"
    echo ""
    echo "Wait 30 more seconds and run:"
    echo "  ${BLUE}./test-deployment.sh${NC}"
    echo ""
    echo "If still failing, check logs:"
    echo "  ${BLUE}docker compose logs auth --tail=50${NC}"
    echo "  ${BLUE}docker compose logs rest --tail=50${NC}"
fi

echo ""

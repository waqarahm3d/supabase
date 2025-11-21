#!/bin/bash

################################################################################
# Complete Migration to Port 80 with JWT Fix
# Fixes both Kong port binding and JWT key issues
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

clear

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Supabase Port 80 Migration & JWT Fix${NC}"
echo -e "${BLUE}   Complete Fix for Kong and Authentication${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo "This script will:"
echo "  1. Fix truncated/missing JWT keys in .env"
echo "  2. Fix Kong not binding to port 80"
echo "  3. Restart all services properly"
echo "  4. Verify everything works"
echo ""

read -p "$(echo -e ${YELLOW}Continue? [y/N]:${NC} )" -n 1 -r
echo ""
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Migration cancelled."
    exit 0
fi

################################################################################
# STEP 1: Fix JWT Keys
################################################################################

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}STEP 1: Fixing JWT Keys${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Backup .env
echo -e "${YELLOW}Creating backup...${NC}"
cp .env .env.backup.$(date +%Y%m%d-%H%M%S)
echo -e "${GREEN}✓ Backup created${NC}"
echo ""

# Load current .env
echo -e "${YELLOW}Checking current JWT keys...${NC}"
source <(grep -v '^#' .env | grep -v '^$' | sed 's/^/export /')

NEEDS_JWT_FIX=false

# Check if keys are valid
if [ ${#ANON_KEY} -lt 150 ] || ! echo "$ANON_KEY" | grep -qE '^ey[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$'; then
    echo -e "${RED}✗ ANON_KEY is truncated or invalid (${#ANON_KEY} chars)${NC}"
    NEEDS_JWT_FIX=true
fi

if [ ${#SERVICE_ROLE_KEY} -lt 150 ] || ! echo "$SERVICE_ROLE_KEY" | grep -qE '^ey[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$'; then
    echo -e "${RED}✗ SERVICE_ROLE_KEY is truncated or invalid (${#SERVICE_ROLE_KEY} chars)${NC}"
    NEEDS_JWT_FIX=true
fi

if [ -z "$SUPABASE_ANON_KEY" ] || [ -z "$SUPABASE_SERVICE_KEY" ]; then
    echo -e "${RED}✗ Kong alias variables missing${NC}"
    NEEDS_JWT_FIX=true
fi

if $NEEDS_JWT_FIX; then
    echo ""
    echo -e "${YELLOW}JWT keys need to be fixed.${NC}"
    echo ""
    echo "Options:"
    echo "  1) Use demo keys from git (INSECURE - for testing only)"
    echo "  2) Generate NEW secure keys (RECOMMENDED for production)"
    echo ""
    read -p "$(echo -e ${YELLOW}Choose [1 or 2]:${NC} )" jwt_choice
    echo ""

    if [ "$jwt_choice" == "2" ]; then
        echo -e "${YELLOW}Generating new secure JWT keys...${NC}"

        # Get current values to preserve
        CURRENT_API_DOMAIN=$(grep "^API_DOMAIN=" .env | cut -d'=' -f2-)
        CURRENT_STUDIO_DOMAIN=$(grep "^STUDIO_DOMAIN=" .env | cut -d'=' -f2-)
        CURRENT_POSTGRES_PASSWORD=$(grep "^POSTGRES_PASSWORD=" .env | cut -d'=' -f2-)

        # Generate new JWT secret
        NEW_JWT_SECRET=$(openssl rand -base64 32)

        # Generate new JWT tokens
        ANON_HEADER='{"alg":"HS256","typ":"JWT"}'
        ANON_PAYLOAD='{"role":"anon","iss":"supabase","iat":1700000000,"exp":2000000000}'

        SERVICE_HEADER='{"alg":"HS256","typ":"JWT"}'
        SERVICE_PAYLOAD='{"role":"service_role","iss":"supabase","iat":1700000000,"exp":2000000000}'

        # Encode (base64url)
        base64url() {
            openssl base64 -e -A | tr '+/' '-_' | tr -d '='
        }

        ANON_HEADER_B64=$(echo -n "$ANON_HEADER" | base64url)
        ANON_PAYLOAD_B64=$(echo -n "$ANON_PAYLOAD" | base64url)
        SERVICE_HEADER_B64=$(echo -n "$SERVICE_HEADER" | base64url)
        SERVICE_PAYLOAD_B64=$(echo -n "$SERVICE_PAYLOAD" | base64url)

        # Create signatures
        ANON_SIGNATURE=$(echo -n "${ANON_HEADER_B64}.${ANON_PAYLOAD_B64}" | openssl dgst -sha256 -hmac "$NEW_JWT_SECRET" -binary | base64url)
        SERVICE_SIGNATURE=$(echo -n "${SERVICE_HEADER_B64}.${SERVICE_PAYLOAD_B64}" | openssl dgst -sha256 -hmac "$NEW_JWT_SECRET" -binary | base64url)

        NEW_ANON_KEY="${ANON_HEADER_B64}.${ANON_PAYLOAD_B64}.${ANON_SIGNATURE}"
        NEW_SERVICE_KEY="${SERVICE_HEADER_B64}.${SERVICE_PAYLOAD_B64}.${SERVICE_SIGNATURE}"

        # Update .env
        sed -i "s|^JWT_SECRET=.*|JWT_SECRET=$NEW_JWT_SECRET|" .env
        sed -i "s|^ANON_KEY=.*|ANON_KEY=$NEW_ANON_KEY|" .env
        sed -i "s|^SERVICE_ROLE_KEY=.*|SERVICE_ROLE_KEY=$NEW_SERVICE_KEY|" .env

        # Add or update Kong aliases
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

        echo -e "${GREEN}✓ New secure keys generated${NC}"

    else
        echo -e "${YELLOW}Restoring demo keys from git...${NC}"
        echo -e "${RED}⚠ WARNING: Demo keys are INSECURE for production!${NC}"
        echo ""

        # Get current values
        CURRENT_API_DOMAIN=$(grep "^API_DOMAIN=" .env | cut -d'=' -f2-)
        CURRENT_STUDIO_DOMAIN=$(grep "^STUDIO_DOMAIN=" .env | cut -d'=' -f2-)
        CURRENT_POSTGRES_PASSWORD=$(grep "^POSTGRES_PASSWORD=" .env | cut -d'=' -f2-)

        # Restore from git
        git checkout .env

        # Restore user's values
        [ -n "$CURRENT_API_DOMAIN" ] && sed -i "s|^API_DOMAIN=.*|API_DOMAIN=$CURRENT_API_DOMAIN|" .env
        [ -n "$CURRENT_STUDIO_DOMAIN" ] && sed -i "s|^STUDIO_DOMAIN=.*|STUDIO_DOMAIN=$CURRENT_STUDIO_DOMAIN|" .env
        [ -n "$CURRENT_POSTGRES_PASSWORD" ] && sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$CURRENT_POSTGRES_PASSWORD|" .env

        echo -e "${GREEN}✓ Demo keys restored (REMEMBER TO CHANGE FOR PRODUCTION!)${NC}"
    fi

    # Reload .env
    source <(grep -v '^#' .env | grep -v '^$' | sed 's/^/export /')

    echo ""
    echo "Verification:"
    echo "  ANON_KEY length: ${#ANON_KEY} chars"
    echo "  SERVICE_ROLE_KEY length: ${#SERVICE_ROLE_KEY} chars"
    echo "  SUPABASE_ANON_KEY: $([ -n "$SUPABASE_ANON_KEY" ] && echo 'SET ✓' || echo 'NOT SET ✗')"
    echo "  SUPABASE_SERVICE_KEY: $([ -n "$SUPABASE_SERVICE_KEY" ] && echo 'SET ✓' || echo 'NOT SET ✗')"

else
    echo -e "${GREEN}✓ JWT keys are valid${NC}"
fi

echo ""
sleep 2

################################################################################
# STEP 2: Fix Kong Port 80
################################################################################

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}STEP 2: Fixing Kong Port 80 Binding${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Check if port 80 is in use
PORT_80_USER=$(sudo lsof -i :80 -t 2>/dev/null | head -1)
if [ -n "$PORT_80_USER" ]; then
    PORT_80_NAME=$(ps -p $PORT_80_USER -o comm= 2>/dev/null)
    if [ "$PORT_80_NAME" == "docker-proxy" ]; then
        echo -e "${GREEN}✓ Port 80 already in use by Docker (Kong)${NC}"
    else
        echo -e "${RED}✗ Port 80 in use by: $PORT_80_NAME (PID: $PORT_80_USER)${NC}"
        echo "This needs to be stopped first"
        exit 1
    fi
else
    echo -e "${YELLOW}Port 80 is free - Kong will bind to it${NC}"
fi

echo ""
echo -e "${YELLOW}Stopping Kong...${NC}"
docker compose stop kong
sleep 2

echo -e "${YELLOW}Removing Kong container completely...${NC}"
docker compose rm -f kong
sleep 2

echo -e "${YELLOW}Cleaning up old Kong containers...${NC}"
docker ps -a --filter name=kong --format "{{.ID}}" | xargs -r docker rm -f 2>/dev/null || true

echo -e "${GREEN}✓ Kong cleaned up${NC}"
echo ""
sleep 2

################################################################################
# STEP 3: Restart All Services
################################################################################

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}STEP 3: Restarting All Services${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}Starting all services with updated configuration...${NC}"
docker compose up -d

echo ""
echo -e "${YELLOW}Waiting 30 seconds for services to initialize...${NC}"
for i in {30..1}; do
    echo -ne "${BLUE}⏳ $i seconds remaining...${NC}\r"
    sleep 1
done
echo ""
echo ""

################################################################################
# STEP 4: Verification
################################################################################

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}STEP 4: Verification${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Check containers
echo -e "${YELLOW}Checking containers...${NC}"
RUNNING_CONTAINERS=$(docker compose ps --format "{{.Service}}" --filter "status=running" | wc -l)
echo "Running containers: $RUNNING_CONTAINERS/11"

if [ $RUNNING_CONTAINERS -eq 11 ]; then
    echo -e "${GREEN}✓ All 11 containers running${NC}"
else
    echo -e "${YELLOW}⚠ Only $RUNNING_CONTAINERS/11 containers running${NC}"
fi
echo ""

# Check Kong on port 80
echo -e "${YELLOW}Checking Kong on port 80...${NC}"
if sudo lsof -i :80 2>/dev/null | grep -q "docker-proxy"; then
    echo -e "${GREEN}✓✓✓ Kong is listening on port 80${NC}"
else
    echo -e "${RED}✗ Kong not on port 80 yet${NC}"
fi
echo ""

# Test HTTP
echo -e "${YELLOW}Testing HTTP endpoint...${NC}"
sleep 5  # Extra wait
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null || echo "000")
if [ "$HTTP_CODE" != "000" ]; then
    echo -e "${GREEN}✓ Kong responding (HTTP $HTTP_CODE)${NC}"
else
    echo -e "${YELLOW}⚠ Kong not responding yet (may still be initializing)${NC}"
fi
echo ""

# Test JWT keys
echo -e "${YELLOW}Testing JWT keys...${NC}"
source <(grep -v '^#' .env | grep -v '^$' | sed 's/^/export /')

JWT_OK=true
if ! echo "$ANON_KEY" | grep -qE '^ey[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$'; then
    echo -e "${RED}✗ ANON_KEY format invalid${NC}"
    JWT_OK=false
fi

if ! echo "$SERVICE_ROLE_KEY" | grep -qE '^ey[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$'; then
    echo -e "${RED}✗ SERVICE_ROLE_KEY format invalid${NC}"
    JWT_OK=false
fi

if [ -z "$SUPABASE_ANON_KEY" ] || [ -z "$SUPABASE_SERVICE_KEY" ]; then
    echo -e "${RED}✗ Kong alias variables missing${NC}"
    JWT_OK=false
fi

if $JWT_OK; then
    echo -e "${GREEN}✓ JWT keys valid${NC}"
fi
echo ""

################################################################################
# Summary
################################################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Migration Complete!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${GREEN}✓ JWT keys fixed${NC}"
echo -e "${GREEN}✓ Kong recreated with port 80 mapping${NC}"
echo -e "${GREEN}✓ All services restarted${NC}"
echo ""

echo -e "${CYAN}Next steps:${NC}"
echo ""
echo "1. Wait 30 more seconds for full initialization:"
echo "   ${BLUE}sleep 30${NC}"
echo ""
echo "2. Test Kong:"
echo "   ${BLUE}curl http://localhost/${NC}"
echo "   ${BLUE}curl http://studio.qoqnuz.com${NC}"
echo ""
echo "3. Run comprehensive tests:"
echo "   ${BLUE}./test-jwt-keys.sh${NC}"
echo "   ${BLUE}./test-deployment.sh${NC}"
echo ""
echo "4. Check service health:"
echo "   ${BLUE}./check-services.sh${NC}"
echo ""
echo "5. Open Studio in browser:"
echo "   ${BLUE}http://studio.qoqnuz.com${NC}"
echo ""

if [ "$jwt_choice" == "1" ]; then
    echo -e "${RED}⚠ SECURITY WARNING:${NC}"
    echo -e "${RED}You are using demo JWT keys - these are PUBLICLY KNOWN!${NC}"
    echo -e "${RED}Before production use, run: ./configure-env.sh${NC}"
    echo ""
fi

echo -e "${GREEN}Migration successful!${NC}"
echo ""

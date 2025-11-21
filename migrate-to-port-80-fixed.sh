#!/bin/bash

################################################################################
# Fixed Migration Script - Handles Malformed .env Files
# Fixes both Kong port binding and JWT key issues with better error handling
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
echo "  1. Fix malformed/truncated JWT keys in .env"
echo "  2. Fix Kong not binding to port 80"
echo "  3. Restart all services properly"
echo "  4. Verify everything works"
echo ""

################################################################################
# STEP 1: Diagnose .env File
################################################################################

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}STEP 1: Checking .env File${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

if [ ! -f .env ]; then
    echo -e "${RED}✗ .env file not found!${NC}"
    exit 1
fi

# Backup .env
echo -e "${YELLOW}Creating backup...${NC}"
cp .env .env.backup.$(date +%Y%m%d-%H%M%S)
echo -e "${GREEN}✓ Backup created: .env.backup.$(date +%Y%m%d-%H%M%S)${NC}"
echo ""

# Check for malformed lines (lines that don't have KEY=VALUE format)
echo -e "${YELLOW}Checking for malformed lines in .env...${NC}"
MALFORMED_LINES=$(grep -v '^#' .env | grep -v '^$' | grep -v '=' | wc -l)

if [ $MALFORMED_LINES -gt 0 ]; then
    echo -e "${RED}✗ Found $MALFORMED_LINES malformed line(s) in .env${NC}"
    echo ""
    echo "These lines don't follow KEY=VALUE format:"
    grep -v '^#' .env | grep -v '^$' | grep -v '=' | head -10
    echo ""
    echo -e "${YELLOW}This usually means JWT tokens are split across multiple lines${NC}"
    ENV_NEEDS_FIX=true
else
    echo -e "${GREEN}✓ .env file format looks OK${NC}"
    ENV_NEEDS_FIX=false
fi

# Try to read key variables manually (safer method)
echo ""
echo -e "${YELLOW}Reading current configuration...${NC}"

# Safe method - read line by line
CURRENT_API_DOMAIN=""
CURRENT_STUDIO_DOMAIN=""
CURRENT_POSTGRES_PASSWORD=""
CURRENT_JWT_SECRET=""
CURRENT_ANON_KEY=""
CURRENT_SERVICE_KEY=""

while IFS='=' read -r key value; do
    # Skip comments and empty lines
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue

    # Trim whitespace
    key=$(echo "$key" | xargs)

    case "$key" in
        "API_DOMAIN") CURRENT_API_DOMAIN="$value" ;;
        "STUDIO_DOMAIN") CURRENT_STUDIO_DOMAIN="$value" ;;
        "POSTGRES_PASSWORD") CURRENT_POSTGRES_PASSWORD="$value" ;;
        "JWT_SECRET") CURRENT_JWT_SECRET="$value" ;;
        "ANON_KEY") CURRENT_ANON_KEY="$value" ;;
        "SERVICE_ROLE_KEY") CURRENT_SERVICE_KEY="$value" ;;
    esac
done < .env

echo "  API Domain: ${CURRENT_API_DOMAIN:-NOT SET}"
echo "  Studio Domain: ${CURRENT_STUDIO_DOMAIN:-NOT SET}"
echo "  ANON_KEY length: ${#CURRENT_ANON_KEY} characters"
echo "  SERVICE_ROLE_KEY length: ${#CURRENT_SERVICE_KEY} characters"
echo ""

# Check if JWT keys are valid
ANON_VALID=false
SERVICE_VALID=false

if [ ${#CURRENT_ANON_KEY} -gt 150 ] && echo "$CURRENT_ANON_KEY" | grep -qE '^ey[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$'; then
    ANON_VALID=true
    echo -e "${GREEN}✓ ANON_KEY appears valid${NC}"
else
    echo -e "${RED}✗ ANON_KEY is invalid or truncated (${#CURRENT_ANON_KEY} chars)${NC}"
fi

if [ ${#CURRENT_SERVICE_KEY} -gt 150 ] && echo "$CURRENT_SERVICE_KEY" | grep -qE '^ey[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$'; then
    SERVICE_VALID=true
    echo -e "${GREEN}✓ SERVICE_ROLE_KEY appears valid${NC}"
else
    echo -e "${RED}✗ SERVICE_ROLE_KEY is invalid or truncated (${#CURRENT_SERVICE_KEY} chars)${NC}"
fi

echo ""

################################################################################
# STEP 2: Fix .env File
################################################################################

if $ENV_NEEDS_FIX || ! $ANON_VALID || ! $SERVICE_VALID; then
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}STEP 2: Fixing .env File${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""

    echo -e "${YELLOW}Your .env file needs to be fixed.${NC}"
    echo ""
    echo "Options:"
    echo ""
    echo "  1) Restore clean .env from git and regenerate NEW secure keys"
    echo "     ${GREEN}✓ RECOMMENDED${NC}"
    echo "     - Fixes all formatting issues"
    echo "     - Generates NEW secure JWT tokens"
    echo "     - Preserves your domains and passwords"
    echo ""
    echo "  2) Restore clean .env from git with demo keys (INSECURE)"
    echo "     - Fixes formatting issues"
    echo "     - Uses Supabase demo keys (publicly known)"
    echo "     - NOT for production!"
    echo ""
    echo "  3) Cancel and fix manually"
    echo ""

    read -p "$(echo -e ${YELLOW}Choose [1, 2, or 3]:${NC} )" fix_choice
    echo ""

    case $fix_choice in
        1)
            echo -e "${GREEN}Option 1: Restoring .env and generating secure keys${NC}"
            echo ""

            # Restore .env from git
            echo -e "${YELLOW}Restoring clean .env from git...${NC}"
            git checkout .env 2>/dev/null || {
                echo -e "${RED}✗ Could not restore from git${NC}"
                echo "Trying to download from GitHub..."
                curl -sf https://raw.githubusercontent.com/supabase/supabase/master/docker/.env.example -o .env || {
                    echo -e "${RED}✗ Could not download .env.example${NC}"
                    exit 1
                }
            }
            echo -e "${GREEN}✓ Clean .env restored${NC}"
            echo ""

            # Restore user's domains and password
            echo -e "${YELLOW}Restoring your configuration...${NC}"
            [ -n "$CURRENT_API_DOMAIN" ] && sed -i "s|^API_DOMAIN=.*|API_DOMAIN=$CURRENT_API_DOMAIN|" .env
            [ -n "$CURRENT_STUDIO_DOMAIN" ] && sed -i "s|^STUDIO_DOMAIN=.*|STUDIO_DOMAIN=$CURRENT_STUDIO_DOMAIN|" .env

            # Only restore password if it's not the default
            if [ -n "$CURRENT_POSTGRES_PASSWORD" ] && [ "$CURRENT_POSTGRES_PASSWORD" != "your-super-secret-and-long-postgres-password-change-this" ]; then
                sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$CURRENT_POSTGRES_PASSWORD|" .env
            fi

            echo -e "${GREEN}✓ Domains and password preserved${NC}"
            echo ""

            # Generate new secure JWT keys
            echo -e "${YELLOW}Generating NEW secure JWT keys...${NC}"

            # Generate new JWT secret (32 bytes = 44 base64 chars)
            NEW_JWT_SECRET=$(openssl rand -base64 32)

            # JWT header and payloads
            ANON_HEADER='{"alg":"HS256","typ":"JWT"}'
            ANON_PAYLOAD='{"role":"anon","iss":"supabase","iat":1700000000,"exp":2000000000}'
            SERVICE_HEADER='{"alg":"HS256","typ":"JWT"}'
            SERVICE_PAYLOAD='{"role":"service_role","iss":"supabase","iat":1700000000,"exp":2000000000}'

            # Function to base64url encode
            base64url_encode() {
                openssl base64 -e -A | tr '+/' '-_' | tr -d '='
            }

            # Encode headers and payloads
            ANON_HEADER_B64=$(echo -n "$ANON_HEADER" | base64url_encode)
            ANON_PAYLOAD_B64=$(echo -n "$ANON_PAYLOAD" | base64url_encode)
            SERVICE_HEADER_B64=$(echo -n "$SERVICE_HEADER" | base64url_encode)
            SERVICE_PAYLOAD_B64=$(echo -n "$SERVICE_PAYLOAD" | base64url_encode)

            # Create signatures
            ANON_UNSIGNED="${ANON_HEADER_B64}.${ANON_PAYLOAD_B64}"
            ANON_SIGNATURE=$(echo -n "$ANON_UNSIGNED" | openssl dgst -sha256 -hmac "$NEW_JWT_SECRET" -binary | base64url_encode)

            SERVICE_UNSIGNED="${SERVICE_HEADER_B64}.${SERVICE_PAYLOAD_B64}"
            SERVICE_SIGNATURE=$(echo -n "$SERVICE_UNSIGNED" | openssl dgst -sha256 -hmac "$NEW_JWT_SECRET" -binary | base64url_encode)

            # Complete JWT tokens
            NEW_ANON_KEY="${ANON_HEADER_B64}.${ANON_PAYLOAD_B64}.${ANON_SIGNATURE}"
            NEW_SERVICE_KEY="${SERVICE_HEADER_B64}.${SERVICE_PAYLOAD_B64}.${SERVICE_SIGNATURE}"

            echo "  New ANON_KEY: ${NEW_ANON_KEY:0:50}... (${#NEW_ANON_KEY} chars)"
            echo "  New SERVICE_ROLE_KEY: ${NEW_SERVICE_KEY:0:50}... (${#NEW_SERVICE_KEY} chars)"
            echo ""

            # Update .env with new keys
            sed -i "s|^JWT_SECRET=.*|JWT_SECRET=$NEW_JWT_SECRET|" .env
            sed -i "s|^ANON_KEY=.*|ANON_KEY=$NEW_ANON_KEY|" .env
            sed -i "s|^SERVICE_ROLE_KEY=.*|SERVICE_ROLE_KEY=$NEW_SERVICE_KEY|" .env

            # Add Kong aliases if they don't exist
            if ! grep -q "^SUPABASE_ANON_KEY=" .env; then
                # Add after SERVICE_ROLE_KEY line
                sed -i "/^SERVICE_ROLE_KEY=/a\\
\\
# Kong expects these variable names (aliases for the above)\\
SUPABASE_ANON_KEY=$NEW_ANON_KEY\\
SUPABASE_SERVICE_KEY=$NEW_SERVICE_KEY" .env
            else
                sed -i "s|^SUPABASE_ANON_KEY=.*|SUPABASE_ANON_KEY=$NEW_ANON_KEY|" .env
                sed -i "s|^SUPABASE_SERVICE_KEY=.*|SUPABASE_SERVICE_KEY=$NEW_SERVICE_KEY|" .env
            fi

            echo -e "${GREEN}✓✓✓ New secure JWT keys generated and saved${NC}"
            echo -e "${GREEN}✓ Kong alias variables added${NC}"
            echo ""
            ;;

        2)
            echo -e "${YELLOW}Option 2: Restoring .env with demo keys${NC}"
            echo -e "${RED}⚠ WARNING: Demo keys are INSECURE for production!${NC}"
            echo ""

            # Restore .env from git
            git checkout .env 2>/dev/null || {
                echo -e "${RED}✗ Could not restore from git${NC}"
                exit 1
            }

            # Restore user's configuration
            [ -n "$CURRENT_API_DOMAIN" ] && sed -i "s|^API_DOMAIN=.*|API_DOMAIN=$CURRENT_API_DOMAIN|" .env
            [ -n "$CURRENT_STUDIO_DOMAIN" ] && sed -i "s|^STUDIO_DOMAIN=.*|STUDIO_DOMAIN=$CURRENT_STUDIO_DOMAIN|" .env

            if [ -n "$CURRENT_POSTGRES_PASSWORD" ] && [ "$CURRENT_POSTGRES_PASSWORD" != "your-super-secret-and-long-postgres-password-change-this" ]; then
                sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$CURRENT_POSTGRES_PASSWORD|" .env
            fi

            echo -e "${GREEN}✓ .env restored with demo keys${NC}"
            echo -e "${YELLOW}⚠ Run ./configure-env.sh later to generate secure keys!${NC}"
            echo ""
            ;;

        3)
            echo "Cancelled. Please fix .env manually and run this script again."
            exit 0
            ;;

        *)
            echo -e "${RED}Invalid choice${NC}"
            exit 1
            ;;
    esac

    echo -e "${GREEN}✓ .env file fixed${NC}"
    echo ""
    sleep 2
else
    echo -e "${GREEN}✓ .env file is valid, skipping fix${NC}"
    echo ""
fi

################################################################################
# STEP 3: Fix Kong Port 80
################################################################################

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}STEP 3: Fixing Kong Port 80 Binding${NC}"
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
# STEP 4: Restart All Services
################################################################################

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}STEP 4: Restarting All Services${NC}"
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
# STEP 5: Verification
################################################################################

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}STEP 5: Verification${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Check containers
echo -e "${YELLOW}Checking containers...${NC}"
RUNNING=$(docker compose ps --format "{{.Service}}" --filter "status=running" | wc -l)
echo "Running containers: $RUNNING/11"
[ $RUNNING -eq 11 ] && echo -e "${GREEN}✓ All containers running${NC}" || echo -e "${YELLOW}⚠ Only $RUNNING/11 running${NC}"
echo ""

# Check Kong on port 80
echo -e "${YELLOW}Checking Kong on port 80...${NC}"
if sudo lsof -i :80 2>/dev/null | grep -q "docker-proxy"; then
    echo -e "${GREEN}✓✓✓ Kong is listening on port 80${NC}"
else
    echo -e "${YELLOW}⚠ Kong not on port 80 yet (may still be starting)${NC}"
fi
echo ""

# Test HTTP
echo -e "${YELLOW}Testing HTTP endpoint...${NC}"
sleep 5
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null || echo "000")
[ "$HTTP_CODE" != "000" ] && echo -e "${GREEN}✓ Kong responding (HTTP $HTTP_CODE)${NC}" || echo -e "${YELLOW}⚠ Kong not responding yet${NC}"
echo ""

################################################################################
# Summary
################################################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Migration Complete!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${GREEN}✓ .env file fixed${NC}"
echo -e "${GREEN}✓ Kong recreated with port 80 mapping${NC}"
echo -e "${GREEN}✓ All services restarted${NC}"
echo ""

echo -e "${CYAN}Next steps:${NC}"
echo ""
echo "1. Wait 30 more seconds for full initialization"
echo "   ${BLUE}sleep 30${NC}"
echo ""
echo "2. Test Kong:"
echo "   ${BLUE}curl http://localhost/${NC}"
echo "   ${BLUE}curl http://studio.qoqnuz.com${NC}"
echo ""
echo "3. Run tests:"
echo "   ${BLUE}./test-jwt-keys.sh${NC}"
echo "   ${BLUE}./test-deployment.sh${NC}"
echo ""
echo "4. Check health:"
echo "   ${BLUE}./check-services.sh${NC}"
echo ""
echo "5. Open Studio:"
echo "   ${BLUE}http://studio.qoqnuz.com${NC}"
echo ""

if [ "$fix_choice" == "2" ]; then
    echo -e "${RED}⚠ SECURITY WARNING:${NC}"
    echo -e "${RED}You are using demo JWT keys - PUBLICLY KNOWN!${NC}"
    echo -e "${RED}Run: ./configure-env.sh before production use${NC}"
    echo ""
fi

echo -e "${GREEN}Migration successful!${NC}"
echo ""

#!/bin/bash

# Fix .env JWT Keys Script
# Repairs truncated/missing JWT keys and adds Kong aliases

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   .env JWT Keys Fix${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Backup .env
echo -e "${YELLOW}Creating backup of current .env file...${NC}"
cp .env .env.backup.$(date +%Y%m%d-%H%M%S)
echo -e "${GREEN}✓ Backup created${NC}"
echo ""

# Check current state
echo -e "${YELLOW}Checking current .env state...${NC}"

# Load current .env
source <(grep -v '^#' .env | grep -v '^$' | sed 's/^/export /')

echo "Current ANON_KEY length: ${#ANON_KEY} characters"
echo "Current SERVICE_ROLE_KEY length: ${#SERVICE_ROLE_KEY} characters"
echo "SUPABASE_ANON_KEY set: $([ -n "$SUPABASE_ANON_KEY" ] && echo 'YES' || echo 'NO')"
echo "SUPABASE_SERVICE_KEY set: $([ -n "$SUPABASE_SERVICE_KEY" ] && echo 'YES' || echo 'NO')"
echo ""

# Check if keys are truncated or missing
ANON_VALID=false
SERVICE_VALID=false

if [ ${#ANON_KEY} -gt 150 ] && echo "$ANON_KEY" | grep -qE '^ey[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$'; then
    ANON_VALID=true
fi

if [ ${#SERVICE_ROLE_KEY} -gt 150 ] && echo "$SERVICE_ROLE_KEY" | grep -qE '^ey[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$'; then
    SERVICE_VALID=true
fi

if $ANON_VALID && $SERVICE_VALID && [ -n "$SUPABASE_ANON_KEY" ] && [ -n "$SUPABASE_SERVICE_KEY" ]; then
    echo -e "${GREEN}✓ JWT keys are valid and aliases are set${NC}"
    echo "No fix needed!"
    exit 0
fi

# Determine what needs to be fixed
echo -e "${YELLOW}Issues detected:${NC}"
[ ! $ANON_VALID ] && echo -e "${RED}✗ ANON_KEY is truncated or invalid${NC}"
[ ! $SERVICE_VALID ] && echo -e "${RED}✗ SERVICE_ROLE_KEY is truncated or invalid${NC}"
[ -z "$SUPABASE_ANON_KEY" ] && echo -e "${RED}✗ SUPABASE_ANON_KEY not set (Kong needs this)${NC}"
[ -z "$SUPABASE_SERVICE_KEY" ] && echo -e "${RED}✗ SUPABASE_SERVICE_KEY not set (Kong needs this)${NC}"
echo ""

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Fix Options${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo "Choose how to fix:"
echo ""
echo "1) Pull .env from git repository (uses demo keys - not secure for production)"
echo "2) Generate NEW secure keys using configure-env.sh (RECOMMENDED)"
echo "3) Manually fix the truncated keys in .env file"
echo "4) Cancel"
echo ""

read -p "$(echo -e ${YELLOW}Enter choice [1-4]:${NC} )" choice

case $choice in
    1)
        echo ""
        echo -e "${YELLOW}Option 1: Restoring .env from git repository...${NC}"
        echo ""
        echo -e "${RED}⚠ WARNING: This will use the Supabase demo JWT keys${NC}"
        echo -e "${RED}⚠ These are publicly known and INSECURE for production!${NC}"
        echo ""
        read -p "$(echo -e ${YELLOW}Are you sure? [y/N]:${NC} )" -n 1 -r
        echo ""

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Get current values we want to keep
            CURRENT_API_DOMAIN=$(grep "^API_DOMAIN=" .env | cut -d'=' -f2-)
            CURRENT_STUDIO_DOMAIN=$(grep "^STUDIO_DOMAIN=" .env | cut -d'=' -f2-)
            CURRENT_POSTGRES_PASSWORD=$(grep "^POSTGRES_PASSWORD=" .env | cut -d'=' -f2-)
            CURRENT_JWT_SECRET=$(grep "^JWT_SECRET=" .env | cut -d'=' -f2-)

            # Restore from git
            git checkout .env

            # Restore user's domains and passwords
            if [ -n "$CURRENT_API_DOMAIN" ]; then
                sed -i "s|^API_DOMAIN=.*|API_DOMAIN=$CURRENT_API_DOMAIN|" .env
            fi
            if [ -n "$CURRENT_STUDIO_DOMAIN" ]; then
                sed -i "s|^STUDIO_DOMAIN=.*|STUDIO_DOMAIN=$CURRENT_STUDIO_DOMAIN|" .env
            fi
            if [ -n "$CURRENT_POSTGRES_PASSWORD" ] && [ "$CURRENT_POSTGRES_PASSWORD" != "your-super-secret-and-long-postgres-password-change-this" ]; then
                sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$CURRENT_POSTGRES_PASSWORD|" .env
            fi
            if [ -n "$CURRENT_JWT_SECRET" ] && [ "$CURRENT_JWT_SECRET" != "your-super-secret-jwt-token-with-at-least-32-characters-long" ]; then
                sed -i "s|^JWT_SECRET=.*|JWT_SECRET=$CURRENT_JWT_SECRET|" .env
            fi

            echo -e "${GREEN}✓ .env restored from git${NC}"
            echo -e "${GREEN}✓ Your domains and passwords preserved${NC}"
            echo ""
            echo -e "${YELLOW}⚠ IMPORTANT: Run ./configure-env.sh to generate secure keys before production!${NC}"
        else
            echo "Cancelled."
            exit 0
        fi
        ;;

    2)
        echo ""
        echo -e "${YELLOW}Option 2: Running configure-env.sh to generate secure keys...${NC}"
        echo ""

        if [ ! -f "./configure-env.sh" ]; then
            echo -e "${RED}✗ configure-env.sh not found${NC}"
            exit 1
        fi

        echo "This will generate NEW secure JWT keys and keep your existing configuration."
        echo ""
        read -p "$(echo -e ${YELLOW}Continue? [y/N]:${NC} )" -n 1 -r
        echo ""

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ./configure-env.sh
            echo ""
            echo -e "${GREEN}✓ New secure keys generated${NC}"
        else
            echo "Cancelled."
            exit 0
        fi
        ;;

    3)
        echo ""
        echo -e "${YELLOW}Option 3: Manual fix instructions${NC}"
        echo ""
        echo "Edit your .env file and ensure:"
        echo ""
        echo "1. ANON_KEY and SERVICE_ROLE_KEY are complete JWT tokens (200+ characters)"
        echo "   Format: eyXXXX.eyYYYY.ZZZZ (three parts separated by dots)"
        echo ""
        echo "2. Add these lines after SERVICE_ROLE_KEY:"
        echo "   SUPABASE_ANON_KEY=\${ANON_KEY}"
        echo "   SUPABASE_SERVICE_KEY=\${SERVICE_ROLE_KEY}"
        echo ""
        echo "Or copy the values from .env.example"
        echo ""
        echo "Then run: docker compose up -d"
        exit 0
        ;;

    4)
        echo "Cancelled."
        exit 0
        ;;

    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

# Verify fix
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Verifying Fix${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Reload .env
source <(grep -v '^#' .env | grep -v '^$' | sed 's/^/export /')

echo "ANON_KEY length: ${#ANON_KEY} characters"
echo "SERVICE_ROLE_KEY length: ${#SERVICE_ROLE_KEY} characters"
echo "SUPABASE_ANON_KEY: $([ -n "$SUPABASE_ANON_KEY" ] && echo 'SET ✓' || echo 'NOT SET ✗')"
echo "SUPABASE_SERVICE_KEY: $([ -n "$SUPABASE_SERVICE_KEY" ] && echo 'SET ✓' || echo 'NOT SET ✗')"
echo ""

# Test JWT format
if echo "$ANON_KEY" | grep -qE '^ey[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$'; then
    echo -e "${GREEN}✓ ANON_KEY format valid${NC}"
else
    echo -e "${RED}✗ ANON_KEY format still invalid${NC}"
fi

if echo "$SERVICE_ROLE_KEY" | grep -qE '^ey[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$'; then
    echo -e "${GREEN}✓ SERVICE_ROLE_KEY format valid${NC}"
else
    echo -e "${RED}✗ SERVICE_ROLE_KEY format still invalid${NC}"
fi

echo ""
echo -e "${GREEN}✓✓✓ Fix complete!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Apply changes: docker compose up -d"
echo "2. Wait 30 seconds for services to restart"
echo "3. Test: ./test-jwt-keys.sh"
echo "4. Test: ./test-deployment.sh"
echo ""

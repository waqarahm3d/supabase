#!/bin/bash

# Check and fix .env domains

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   .env Domains Diagnostic and Fix${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Show first 15 lines of .env
echo -e "${YELLOW}First 15 lines of your .env file:${NC}"
head -15 .env
echo ""

# Check for API_DOMAIN
echo -e "${YELLOW}Checking API_DOMAIN...${NC}"
if grep -q "^API_DOMAIN=" .env; then
    API_LINE=$(grep "^API_DOMAIN=" .env)
    echo -e "${GREEN}✓ Found: $API_LINE${NC}"
else
    echo -e "${RED}✗ API_DOMAIN not found in .env${NC}"
fi

# Check for STUDIO_DOMAIN
echo -e "${YELLOW}Checking STUDIO_DOMAIN...${NC}"
if grep -q "^STUDIO_DOMAIN=" .env; then
    STUDIO_LINE=$(grep "^STUDIO_DOMAIN=" .env)
    echo -e "${GREEN}✓ Found: $STUDIO_LINE${NC}"
else
    echo -e "${RED}✗ STUDIO_DOMAIN not found in .env${NC}"
fi

echo ""

# Check what git has
echo -e "${YELLOW}Checking what's in git repository...${NC}"
if git show HEAD:.env | grep -q "^API_DOMAIN="; then
    GIT_API=$(git show HEAD:.env | grep "^API_DOMAIN=")
    echo "Git has: $GIT_API"
else
    echo "Git: API_DOMAIN not found"
fi

if git show HEAD:.env | grep -q "^STUDIO_DOMAIN="; then
    GIT_STUDIO=$(git show HEAD:.env | grep "^STUDIO_DOMAIN=")
    echo "Git has: $GIT_STUDIO"
else
    echo "Git: STUDIO_DOMAIN not found"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Fix Options${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo "1) Restore .env from git (has domains: db.qoqnuz.com, studio.qoqnuz.com)"
echo "2) Add domain lines manually to current .env"
echo "3) Show me the differences between current .env and git"
echo "4) Cancel"
echo ""

read -p "$(echo -e ${YELLOW}Choose [1-4]:${NC} )" choice

case $choice in
    1)
        echo ""
        echo -e "${YELLOW}Backing up current .env...${NC}"
        cp .env .env.backup.domains.$(date +%Y%m%d-%H%M%S)

        echo -e "${YELLOW}Restoring .env from git...${NC}"
        git checkout .env

        echo -e "${GREEN}✓ .env restored from git${NC}"
        echo ""

        # Verify domains are now present
        if grep -q "^API_DOMAIN=db.qoqnuz.com" .env && grep -q "^STUDIO_DOMAIN=studio.qoqnuz.com" .env; then
            echo -e "${GREEN}✓ Domains are now set:${NC}"
            grep "^API_DOMAIN=" .env
            grep "^STUDIO_DOMAIN=" .env
        else
            echo -e "${RED}✗ Domains still not found after restore${NC}"
        fi
        ;;

    2)
        echo ""
        echo -e "${YELLOW}Adding domain lines manually...${NC}"

        # Check if domains section exists
        if grep -q "^# DOMAINS" .env || grep -q "^############" .env; then
            echo "Adding after DOMAINS section..."

            # Remove any existing API_DOMAIN or STUDIO_DOMAIN lines first
            sed -i '/^API_DOMAIN=/d' .env
            sed -i '/^STUDIO_DOMAIN=/d' .env

            # Add after the first section header
            sed -i '1a\
# DOMAINS\
API_DOMAIN=db.qoqnuz.com\
STUDIO_DOMAIN=studio.qoqnuz.com\
' .env
        else
            # Add at the very top
            sed -i '1i\
############\
# DOMAINS\
############\
API_DOMAIN=db.qoqnuz.com\
STUDIO_DOMAIN=studio.qoqnuz.com\
' .env
        fi

        echo -e "${GREEN}✓ Domains added${NC}"
        echo ""
        echo "Verification:"
        grep "^API_DOMAIN=" .env || echo "API_DOMAIN still not found"
        grep "^STUDIO_DOMAIN=" .env || echo "STUDIO_DOMAIN still not found"
        ;;

    3)
        echo ""
        echo -e "${YELLOW}Differences between current .env and git:${NC}"
        echo ""
        git diff .env || echo "No differences (files are identical)"
        echo ""
        exit 0
        ;;

    4)
        echo "Cancelled"
        exit 0
        ;;

    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Next Steps${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo "Now restart services to apply domain configuration:"
echo ""
echo "  ${BLUE}docker compose restart${NC}"
echo "  ${BLUE}sleep 30${NC}"
echo "  ${BLUE}./test-deployment.sh${NC}"
echo ""

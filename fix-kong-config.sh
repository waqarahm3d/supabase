#!/bin/bash

# Fix Kong Configuration - Substitute Variables Manually
# The Kong entrypoint sed substitution is failing, so we do it manually

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Kong Configuration Fix${NC}"
echo -e "${BLUE}   Manually Substitute Environment Variables${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Load .env
echo -e "${YELLOW}Loading .env file...${NC}"
if [ ! -f .env ]; then
    echo -e "${RED}✗ .env file not found${NC}"
    exit 1
fi

# Safe load
while IFS='=' read -r key value; do
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue
    key=$(echo "$key" | xargs)

    case "$key" in
        "ANON_KEY") ANON_KEY="$value" ;;
        "SERVICE_ROLE_KEY") SERVICE_ROLE_KEY="$value" ;;
        "DASHBOARD_PASSWORD") DASHBOARD_PASSWORD="$value" ;;
        "DASHBOARD_USERNAME") DASHBOARD_USERNAME="$value" ;;
    esac
done < .env

echo "Loaded:"
echo "  ANON_KEY: ${#ANON_KEY} characters"
echo "  SERVICE_ROLE_KEY: ${#SERVICE_ROLE_KEY} characters"
echo "  DASHBOARD_PASSWORD: $([ -n "$DASHBOARD_PASSWORD" ] && echo 'SET' || echo 'NOT SET')"
echo ""

# Validate
if [ ${#ANON_KEY} -lt 100 ]; then
    echo -e "${RED}✗ ANON_KEY is too short or empty${NC}"
    exit 1
fi

if [ ${#SERVICE_ROLE_KEY} -lt 100 ]; then
    echo -e "${RED}✗ SERVICE_ROLE_KEY is too short or empty${NC}"
    exit 1
fi

if [ -z "$DASHBOARD_PASSWORD" ]; then
    echo -e "${RED}✗ DASHBOARD_PASSWORD is not set${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All variables validated${NC}"
echo ""

# Check current Kong config
echo -e "${YELLOW}Checking current Kong config...${NC}"
UNSUBBED=$(docker exec supabase-kong grep -c '\${' /home/kong/kong.yml || echo "0")
echo "Unsubstituted variables in kong.yml: $UNSUBBED"
echo ""

if [ "$UNSUBBED" -eq 0 ]; then
    echo -e "${GREEN}✓ Kong config already looks good!${NC}"
    echo "No unsubstituted variables found."
    echo ""
    echo "If Kong is still not working, try restarting:"
    echo "  docker compose restart kong"
    exit 0
fi

# Backup current kong.yml
echo -e "${YELLOW}Creating backup of current kong.yml...${NC}"
docker exec supabase-kong cp /home/kong/kong.yml /home/kong/kong.yml.backup || true
echo ""

# Method 1: Try to fix in-place using docker exec
echo -e "${YELLOW}Attempting to fix kong.yml in container...${NC}"

# Escape special characters for sed
ANON_ESCAPED=$(echo "$ANON_KEY" | sed 's/[\/&]/\\&/g')
SERVICE_ESCAPED=$(echo "$SERVICE_ROLE_KEY" | sed 's/[\/&]/\\&/g')
PASSWORD_ESCAPED=$(echo "$DASHBOARD_PASSWORD" | sed 's/[\/&]/\\&/g')

# Run sed inside container
docker exec supabase-kong sh -c "
    sed -i 's/\\\${ANON_KEY}/$ANON_ESCAPED/g' /home/kong/kong.yml &&
    sed -i 's/\\\${SERVICE_ROLE_KEY}/$SERVICE_ESCAPED/g' /home/kong/kong.yml &&
    sed -i 's/\\\${DASHBOARD_PASSWORD}/$PASSWORD_ESCAPED/g' /home/kong/kong.yml
"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Successfully substituted variables${NC}"
else
    echo -e "${RED}✗ sed command failed${NC}"
    echo "Trying alternative method..."

    # Method 2: Copy out, fix, copy back
    echo -e "${YELLOW}Copying kong.yml out of container...${NC}"
    docker cp supabase-kong:/home/kong/temp.yml /tmp/kong-temp.yml

    echo -e "${YELLOW}Performing substitution locally...${NC}"
    sed -e "s/\${ANON_KEY}/$ANON_ESCAPED/g" \
        -e "s/\${SERVICE_ROLE_KEY}/$SERVICE_ESCAPED/g" \
        -e "s/\${DASHBOARD_PASSWORD}/$PASSWORD_ESCAPED/g" \
        /tmp/kong-temp.yml > /tmp/kong-fixed.yml

    echo -e "${YELLOW}Copying fixed config back...${NC}"
    docker cp /tmp/kong-fixed.yml supabase-kong:/home/kong/kong.yml

    # Cleanup
    rm -f /tmp/kong-temp.yml /tmp/kong-fixed.yml

    echo -e "${GREEN}✓ Config copied back to container${NC}"
fi

echo ""

# Verify fix
echo -e "${YELLOW}Verifying fix...${NC}"
REMAINING=$(docker exec supabase-kong grep -c '\${' /home/kong/kong.yml || echo "0")

if [ "$REMAINING" -eq 0 ]; then
    echo -e "${GREEN}✓✓✓ All variables successfully substituted!${NC}"
else
    echo -e "${YELLOW}⚠ Still found $REMAINING unsubstituted variable(s)${NC}"
    echo "Showing remaining:"
    docker exec supabase-kong grep '\${' /home/kong/kong.yml
fi

echo ""

# Reload Kong
echo -e "${YELLOW}Reloading Kong configuration...${NC}"
docker exec supabase-kong kong reload || {
    echo -e "${YELLOW}⚠ kong reload command not available, restarting container instead${NC}"
    docker compose restart kong

    echo ""
    echo -e "${YELLOW}Waiting 15 seconds for Kong to restart...${NC}"
    sleep 15
}

echo -e "${GREEN}✓ Kong reloaded${NC}"
echo ""

# Test Kong
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Testing Kong${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo "Testing root endpoint:"
curl -s -o /tmp/kong-test-root.txt -w "HTTP %{http_code}\n" http://localhost/
cat /tmp/kong-test-root.txt | head -3
echo ""

echo "Testing auth endpoint:"
curl -s -w "HTTP %{http_code}\n" http://localhost/auth/v1/health
echo ""

echo "Testing rest endpoint with API key:"
curl -s -H "apikey: $ANON_KEY" -w "\nHTTP %{http_code}\n" http://localhost/rest/v1/
echo ""

# Final summary
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

if [ "$REMAINING" -eq 0 ]; then
    echo -e "${GREEN}✓ Kong configuration fixed${NC}"
    echo -e "${GREEN}✓ All variables substituted${NC}"
    echo -e "${GREEN}✓ Kong reloaded${NC}"
    echo ""
    echo "Next steps:"
    echo "  ${BLUE}./test-deployment.sh${NC}    # Should now show 90%+ pass rate"
    echo "  ${BLUE}./check-services.sh${NC}     # Verify all services"
    echo ""
    echo "Try accessing Studio:"
    echo "  ${BLUE}http://studio.qoqnuz.com${NC}"
else
    echo -e "${YELLOW}⚠ Some variables may still be unsubstituted${NC}"
    echo "You may need to check the kong.yml manually"
    echo ""
    echo "View config:"
    echo "  ${BLUE}docker exec supabase-kong cat /home/kong/kong.yml | head -50${NC}"
fi

echo ""

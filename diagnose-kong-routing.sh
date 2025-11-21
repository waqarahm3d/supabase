#!/bin/bash

# Kong Routing Diagnostic
# Checks why Kong is listening but not routing

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Kong Routing Diagnostic${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# 1. Check Kong container status
echo -e "${YELLOW}1. Kong Container Status${NC}"
docker ps --filter name=kong --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# 2. Check if Kong is listening inside container
echo -e "${YELLOW}2. Kong Listening Ports (inside container)${NC}"
docker exec supabase-kong sh -c "netstat -tuln 2>/dev/null | grep LISTEN | grep -E ':(8000|8443|8001|8444)' || ss -tuln 2>/dev/null | grep LISTEN | grep -E ':(8000|8443|8001|8444)' || echo 'netstat/ss not available'"
echo ""

# 3. Test Kong directly from inside container
echo -e "${YELLOW}3. Testing Kong from Inside Container${NC}"
INTERNAL_TEST=$(docker exec supabase-kong sh -c "curl -s -o /dev/null -w '%{http_code}' http://localhost:8000/ 2>/dev/null" || echo "FAIL")
if [ "$INTERNAL_TEST" != "FAIL" ] && [ "$INTERNAL_TEST" != "000" ]; then
    echo -e "${GREEN}✓ Kong responding inside container (HTTP $INTERNAL_TEST)${NC}"
else
    echo -e "${RED}✗ Kong NOT responding inside container${NC}"
fi
echo ""

# 4. Test Kong from host on port 80
echo -e "${YELLOW}4. Testing Kong from Host (port 80)${NC}"
HOST_TEST=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:80/ 2>/dev/null || echo "000")
if [ "$HOST_TEST" != "000" ]; then
    echo -e "${GREEN}✓ Kong responding on host port 80 (HTTP $HOST_TEST)${NC}"
else
    echo -e "${RED}✗ Kong NOT responding on host port 80${NC}"
fi
echo ""

# 5. Check Kong configuration file
echo -e "${YELLOW}5. Kong Configuration File Status${NC}"
if docker exec supabase-kong test -f /home/kong/kong.yml; then
    echo -e "${GREEN}✓ /home/kong/kong.yml exists${NC}"

    # Check file size
    SIZE=$(docker exec supabase-kong sh -c "wc -c < /home/kong/kong.yml")
    echo "File size: $SIZE bytes"

    if [ "$SIZE" -lt 100 ]; then
        echo -e "${RED}✗ File is suspiciously small - may be empty or corrupted${NC}"
    fi
else
    echo -e "${RED}✗ /home/kong/kong.yml NOT FOUND${NC}"
fi
echo ""

# 6. Check if kong.yml was generated from template
echo -e "${YELLOW}6. Checking Kong Template Processing${NC}"
if docker exec supabase-kong test -f /home/kong/temp.yml; then
    echo -e "${GREEN}✓ Template file exists${NC}"
else
    echo -e "${RED}✗ Template file missing${NC}"
fi

# Check for sed substitution patterns
echo "Checking if environment variables were substituted..."
docker exec supabase-kong sh -c "grep -c '\${' /home/kong/kong.yml 2>/dev/null || echo '0'" > /tmp/kong_vars
VAR_COUNT=$(cat /tmp/kong_vars)
if [ "$VAR_COUNT" -gt 0 ]; then
    echo -e "${RED}✗ Found $VAR_COUNT unsubstituted variables in kong.yml${NC}"
    echo "Variables still present:"
    docker exec supabase-kong grep '\${' /home/kong/kong.yml | head -5
else
    echo -e "${GREEN}✓ All variables substituted${NC}"
fi
echo ""

# 7. Check Kong logs for errors
echo -e "${YELLOW}7. Recent Kong Logs (last 20 lines)${NC}"
docker logs supabase-kong --tail 20 2>&1
echo ""

# 8. Test specific Kong routes
echo -e "${YELLOW}8. Testing Kong Routes${NC}"

# Test root
echo -n "  Testing /: "
ROOT_TEST=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:80/ 2>/dev/null || echo "000")
if [ "$ROOT_TEST" != "000" ]; then
    echo -e "${GREEN}HTTP $ROOT_TEST${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi

# Test /auth/v1/health
echo -n "  Testing /auth/v1/health: "
AUTH_TEST=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:80/auth/v1/health 2>/dev/null || echo "000")
if [ "$AUTH_TEST" == "200" ]; then
    echo -e "${GREEN}HTTP $AUTH_TEST${NC}"
else
    echo -e "${YELLOW}HTTP $AUTH_TEST${NC}"
fi

# Test /rest/v1/
echo -n "  Testing /rest/v1/: "
REST_TEST=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:80/rest/v1/ 2>/dev/null || echo "000")
if [ "$REST_TEST" != "000" ]; then
    echo -e "${GREEN}HTTP $REST_TEST${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi

echo ""

# 9. Check environment variables in Kong container
echo -e "${YELLOW}9. Environment Variables in Kong Container${NC}"
echo "SUPABASE_ANON_KEY length:"
docker exec supabase-kong sh -c 'echo ${#SUPABASE_ANON_KEY}'

echo "SUPABASE_SERVICE_KEY length:"
docker exec supabase-kong sh -c 'echo ${#SUPABASE_SERVICE_KEY}'

echo "DASHBOARD_PASSWORD set:"
docker exec supabase-kong sh -c '[ -n "$DASHBOARD_PASSWORD" ] && echo "YES" || echo "NO"'

echo ""

# 10. Check Kong declarative config
echo -e "${YELLOW}10. Kong Declarative Config Status${NC}"
echo "KONG_DECLARATIVE_CONFIG value:"
docker exec supabase-kong sh -c 'echo $KONG_DECLARATIVE_CONFIG'

# Try to validate Kong config
echo ""
echo "Attempting to validate Kong configuration..."
docker exec supabase-kong kong config db_import /home/kong/kong.yml -c /etc/kong/kong.conf 2>&1 || echo "Validation failed or command not available"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Diagnosis Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

ISSUES=0

# Summarize issues
if [ "$INTERNAL_TEST" == "FAIL" ] || [ "$INTERNAL_TEST" == "000" ]; then
    echo -e "${RED}✗ Kong not responding inside container${NC}"
    echo "  → Kong service may not be running or config is invalid"
    ISSUES=$((ISSUES + 1))
fi

if [ "$HOST_TEST" == "000" ]; then
    echo -e "${RED}✗ Kong not accessible on host port 80${NC}"
    echo "  → Port mapping issue or Kong not listening"
    ISSUES=$((ISSUES + 1))
fi

if [ "$VAR_COUNT" -gt 0 ]; then
    echo -e "${RED}✗ Kong config has unsubstituted variables${NC}"
    echo "  → Entrypoint script didn't substitute \${ANON_KEY} etc."
    echo "  → Environment variables missing in Kong container"
    ISSUES=$((ISSUES + 1))
fi

if [ "$ROOT_TEST" == "000" ] || [ "$AUTH_TEST" == "000" ] || [ "$REST_TEST" == "000" ]; then
    echo -e "${RED}✗ Kong routes not working${NC}"
    echo "  → Kong config not loaded or routes not configured"
    ISSUES=$((ISSUES + 1))
fi

if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✓ Kong appears to be working correctly${NC}"
    echo ""
    echo "If tests are still failing, the issue may be:"
    echo "  • Domain DNS not resolving"
    echo "  • Firewall blocking external access"
    echo "  • Backend services (auth, rest, storage) not responding"
else
    echo ""
    echo -e "${YELLOW}Found $ISSUES issue(s) with Kong${NC}"
    echo ""
    echo "Recommended fixes:"
    echo ""
    echo "1. If Kong config has unsubstituted variables:"
    echo "   ${BLUE}docker compose logs kong | grep error${NC}"
    echo "   ${BLUE}docker compose restart kong${NC}"
    echo ""
    echo "2. If Kong not responding inside container:"
    echo "   ${BLUE}docker compose stop kong${NC}"
    echo "   ${BLUE}docker compose rm -f kong${NC}"
    echo "   ${BLUE}docker compose up -d kong${NC}"
    echo ""
    echo "3. Check .env file has all required variables:"
    echo "   ${BLUE}grep 'SUPABASE_ANON_KEY\\|SUPABASE_SERVICE_KEY\\|DASHBOARD_PASSWORD' .env${NC}"
fi

echo ""

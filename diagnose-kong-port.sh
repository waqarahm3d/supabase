#!/bin/bash

# Kong Port 80 Diagnostic and Fix Script
# This script diagnoses why Kong isn't binding to port 80 and fixes it

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Kong Port 80 Diagnostic and Fix${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# 1. Check current Kong status
echo -e "${YELLOW}1. Checking Kong container status...${NC}"
docker ps --filter name=kong --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# 2. Check what's on port 80
echo -e "${YELLOW}2. Checking what's using port 80...${NC}"
PORT_80_CHECK=$(sudo lsof -i :80 2>/dev/null || echo "")
if [ -z "$PORT_80_CHECK" ]; then
    echo -e "${RED}✗ Nothing is listening on port 80!${NC}"
    echo "This is the problem - Kong should be here"
else
    echo "$PORT_80_CHECK"
fi
echo ""

# 3. Check docker-compose.yml port configuration
echo -e "${YELLOW}3. Checking docker-compose.yml Kong ports configuration...${NC}"
KONG_PORTS=$(grep -A 2 "kong:" docker-compose.yml | grep -A 5 "ports:" | head -5)
echo "$KONG_PORTS"
echo ""

# 4. Check Kong logs for errors
echo -e "${YELLOW}4. Checking Kong logs for errors...${NC}"
echo "Last 20 lines of Kong logs:"
docker logs supabase-kong --tail 20 2>&1 | tail -20
echo ""

# 5. Check if Kong is listening inside the container
echo -e "${YELLOW}5. Checking if Kong is listening inside container...${NC}"
KONG_INTERNAL=$(docker exec supabase-kong sh -c "netstat -tuln 2>/dev/null | grep 8000 || ss -tuln 2>/dev/null | grep 8000 || echo 'netstat/ss not available'")
if echo "$KONG_INTERNAL" | grep -q "8000"; then
    echo -e "${GREEN}✓ Kong IS listening on port 8000 inside container${NC}"
    echo "$KONG_INTERNAL"
else
    echo -e "${RED}✗ Kong NOT listening on port 8000 inside container${NC}"
    echo "$KONG_INTERNAL"
fi
echo ""

# 6. Check docker port mapping
echo -e "${YELLOW}6. Checking Docker port mappings...${NC}"
docker port supabase-kong 2>/dev/null || echo "No port mappings found"
echo ""

# 7. Check if there's a port mapping issue
echo -e "${YELLOW}7. Analyzing the issue...${NC}"
INSPECT_PORTS=$(docker inspect supabase-kong --format '{{json .NetworkSettings.Ports}}' 2>/dev/null)
echo "Docker inspect ports: $INSPECT_PORTS"
echo ""

# Diagnosis
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Diagnosis${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

if echo "$INSPECT_PORTS" | grep -q "8000/tcp"; then
    if echo "$INSPECT_PORTS" | grep -q "HostPort"; then
        HOST_PORT=$(echo "$INSPECT_PORTS" | grep -o '"HostPort":"[^"]*"' | head -1 | cut -d'"' -f4)
        echo -e "${YELLOW}Kong container has port mapping configured:${NC}"
        echo "Container port 8000 → Host port $HOST_PORT"

        if [ "$HOST_PORT" != "80" ]; then
            echo -e "${RED}✗ PROBLEM: Kong is mapped to port $HOST_PORT instead of 80${NC}"
            echo "This might be because Kong was recreated without properly removing the old container"
        else
            echo -e "${YELLOW}Port mapping is correct (80:8000) but Kong isn't listening${NC}"
            echo "This usually means Kong failed to start properly"
        fi
    else
        echo -e "${RED}✗ PROBLEM: Kong port 8000 has no host port mapping${NC}"
        echo "The ports section in docker-compose.yml isn't being applied"
    fi
else
    echo -e "${RED}✗ PROBLEM: Kong isn't exposing port 8000 at all${NC}"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Recommended Fix${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo "The issue is likely that Kong needs to be completely removed and recreated"
echo "to properly apply the port 80 mapping."
echo ""

read -p "$(echo -e ${YELLOW}Do you want to fix this now? [y/N]:${NC} )" -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Applying fix...${NC}"
    echo ""

    # Step 1: Stop Kong
    echo -e "${YELLOW}Step 1: Stopping Kong container...${NC}"
    docker compose stop kong
    sleep 2

    # Step 2: Remove Kong container completely
    echo -e "${YELLOW}Step 2: Removing Kong container...${NC}"
    docker compose rm -f kong
    sleep 2

    # Step 3: Remove any dangling Kong containers
    echo -e "${YELLOW}Step 3: Cleaning up any old Kong containers...${NC}"
    OLD_KONG=$(docker ps -a --filter name=kong --format "{{.ID}}" | head -1)
    if [ -n "$OLD_KONG" ]; then
        echo "Found old Kong container: $OLD_KONG"
        docker rm -f "$OLD_KONG" 2>/dev/null || true
    fi

    # Step 4: Check port 80 is free
    echo -e "${YELLOW}Step 4: Ensuring port 80 is free...${NC}"
    PORT_80_USER=$(sudo lsof -i :80 -t 2>/dev/null | head -1)
    if [ -n "$PORT_80_USER" ]; then
        PORT_80_NAME=$(ps -p $PORT_80_USER -o comm= 2>/dev/null)
        echo -e "${RED}✗ Port 80 is still in use by: $PORT_80_NAME (PID: $PORT_80_USER)${NC}"
        echo "You may need to stop this service first"
        exit 1
    else
        echo -e "${GREEN}✓ Port 80 is free${NC}"
    fi

    # Step 5: Recreate Kong with proper port mapping
    echo -e "${YELLOW}Step 5: Creating Kong container with port 80 mapping...${NC}"
    docker compose up -d kong

    # Step 6: Wait for Kong to initialize
    echo -e "${YELLOW}Step 6: Waiting 20 seconds for Kong to initialize...${NC}"
    for i in {20..1}; do
        echo -ne "${BLUE}⏳ $i seconds remaining...${NC}\r"
        sleep 1
    done
    echo ""

    # Step 7: Verify Kong is on port 80
    echo -e "${YELLOW}Step 7: Verifying Kong is listening on port 80...${NC}"
    PORT_80_NOW=$(sudo lsof -i :80 2>/dev/null | grep LISTEN || echo "")
    if echo "$PORT_80_NOW" | grep -q "docker-proxy"; then
        echo -e "${GREEN}✓✓✓ SUCCESS! Kong is now listening on port 80${NC}"
        echo "$PORT_80_NOW"
    else
        echo -e "${RED}✗ Kong still not on port 80${NC}"
        echo "Current port 80 status:"
        sudo lsof -i :80 2>/dev/null || echo "Nothing on port 80"
    fi
    echo ""

    # Step 8: Test Kong
    echo -e "${YELLOW}Step 8: Testing Kong HTTP endpoint...${NC}"
    sleep 5  # Extra wait
    HTTP_TEST=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:80/ 2>/dev/null || echo "000")
    if [ "$HTTP_TEST" != "000" ]; then
        echo -e "${GREEN}✓ Kong responding on port 80! (HTTP $HTTP_TEST)${NC}"
    else
        echo -e "${YELLOW}⚠ Kong not responding yet (may still be initializing)${NC}"
        echo "Wait 10 more seconds and try: curl http://localhost/"
    fi
    echo ""

    # Step 9: Show final status
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}   Final Status${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""

    echo "Kong container status:"
    docker ps --filter name=kong --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""

    echo "Port 80 status:"
    sudo lsof -i :80 2>/dev/null || echo "Nothing listening on port 80"
    echo ""

    echo -e "${GREEN}Fix applied!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Wait 30 seconds for all services to stabilize"
    echo "2. Run: curl http://localhost/"
    echo "3. Run: curl http://studio.qoqnuz.com"
    echo "4. Run: ./test-deployment.sh"
    echo "5. Open browser: http://studio.qoqnuz.com"

else
    echo -e "${YELLOW}Fix cancelled. No changes made.${NC}"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

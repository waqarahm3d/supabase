#!/bin/bash

################################################################################
# Supabase Service Restart and Recovery Script
################################################################################

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Supabase Service Recovery${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Check which services are down
echo -e "${YELLOW}Checking service status...${NC}"
echo ""

STOPPED_SERVICES=()

check_container() {
    local container=$1
    if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        STOPPED_SERVICES+=("$container")
        echo -e "  ${RED}✗${NC} $container is stopped"
        return 1
    else
        local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
        if [ "$status" != "running" ]; then
            STOPPED_SERVICES+=("$container")
            echo -e "  ${RED}✗${NC} $container is not running (status: $status)"
            return 1
        else
            echo -e "  ${GREEN}✓${NC} $container is running"
            return 0
        fi
    fi
}

# Check all services
check_container "supabase-db"
check_container "supabase-auth"
check_container "supabase-rest"
check_container "supabase-kong"
check_container "realtime-dev.supabase-realtime"
check_container "supabase-storage"
check_container "supabase-studio"
check_container "supabase-analytics"
check_container "supabase-functions"
check_container "supabase-imgproxy"
check_container "supabase-meta"

echo ""

if [ ${#STOPPED_SERVICES[@]} -eq 0 ]; then
    echo -e "${GREEN}All services are running!${NC}"
    exit 0
fi

echo -e "${YELLOW}Found ${#STOPPED_SERVICES[@]} stopped services${NC}"
echo ""

# Show recent logs for stopped services
echo -e "${BLUE}Recent logs from stopped services:${NC}"
echo ""

for service in "${STOPPED_SERVICES[@]}"; do
    echo -e "${YELLOW}━━━ $service (last 20 lines) ━━━${NC}"
    docker logs "$service" --tail=20 2>&1 | tail -20
    echo ""
done

# Ask user if they want to restart
echo -e "${YELLOW}Would you like to restart the stopped services? (yes/no)${NC}"
read -p "> " answer

if [ "$answer" != "yes" ]; then
    echo "Exiting without restarting."
    exit 0
fi

# Restart stopped services
echo ""
echo -e "${BLUE}Restarting services...${NC}"
echo ""

for service in "${STOPPED_SERVICES[@]}"; do
    echo -n "  Restarting $service... "
    if docker restart "$service" > /dev/null 2>&1; then
        echo -e "${GREEN}Done${NC}"
    else
        echo -e "${RED}Failed${NC}"
    fi
    sleep 2
done

echo ""
echo -e "${BLUE}Waiting 10 seconds for services to start...${NC}"
sleep 10

echo ""
echo -e "${BLUE}Checking service status after restart:${NC}"
echo ""

# Check again
STILL_DOWN=0
for service in "${STOPPED_SERVICES[@]}"; do
    if check_container "$service"; then
        echo -e "  ${GREEN}✓${NC} $service is now running"
    else
        echo -e "  ${RED}✗${NC} $service is still down"
        STILL_DOWN=$((STILL_DOWN + 1))
    fi
done

echo ""

if [ $STILL_DOWN -eq 0 ]; then
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ All services successfully restarted!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}Run ./check-services.sh to verify full system health${NC}"
else
    echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}⚠ $STILL_DOWN service(s) failed to restart${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Check logs: docker compose logs <service-name>"
    echo "  2. Check resources: docker stats"
    echo "  3. Try full restart: docker compose restart"
fi

echo ""

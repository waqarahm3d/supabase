#!/bin/bash

################################################################################
# Apply Port Changes - Restart Kong with New Configuration
################################################################################

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Applying Port Configuration Changes${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}This will restart Kong to apply the new port configuration:${NC}"
echo "  • HTTP: Port 80 (was 8000)"
echo "  • HTTPS: Port 443 (was 8443)"
echo ""
echo -e "${YELLOW}Studio will be accessible at: http://studio.qoqnuz.com${NC}"
echo -e "${YELLOW}API will be accessible at: http://db.qoqnuz.com${NC}"
echo ""

read -p "Continue? (yes/no): " answer

if [ "$answer" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo -e "${BLUE}Restarting Kong...${NC}"

# Stop Kong
docker compose stop kong

# Wait a moment
sleep 2

# Start Kong with new configuration
docker compose up -d kong

# Wait for Kong to be ready
echo "Waiting for Kong to start..."
sleep 5

# Check if Kong is running
if docker ps --format '{{.Names}}' | grep -q '^supabase-kong$'; then
    echo -e "${GREEN}✓ Kong restarted successfully${NC}"

    # Test new ports
    echo ""
    echo -e "${BLUE}Testing new ports...${NC}"

    echo -n "  Port 80 (HTTP)... "
    if curl -sf http://localhost/ &> /dev/null; then
        echo -e "${GREEN}ACCESSIBLE${NC}"
    else
        echo -e "${RED}NOT ACCESSIBLE${NC}"
        echo -e "${YELLOW}Note: May need a few more seconds to fully initialize${NC}"
    fi

    echo ""
    echo -e "${GREEN}✓ Port configuration applied!${NC}"
    echo ""
    echo -e "${CYAN}Access Points:${NC}"
    echo -e "  📊 Studio: ${GREEN}http://studio.qoqnuz.com${NC}"
    echo -e "  🔌 API:    ${GREEN}http://db.qoqnuz.com${NC}"
    echo ""
    echo -e "${BLUE}Run ./test-deployment.sh to verify all tests pass${NC}"
else
    echo -e "${RED}✗ Kong failed to start${NC}"
    echo "Check logs: docker compose logs kong"
    exit 1
fi

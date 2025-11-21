#!/bin/bash

################################################################################
# Port 80 Conflict Resolver
# Diagnoses and resolves port 80 conflicts
################################################################################

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Port 80 Conflict Resolver${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Check what's using port 80
echo -e "${CYAN}Checking what's using port 80...${NC}"
echo ""

PORT_80_PROCESS=$(lsof -i :80 -t 2>/dev/null | head -1)
if [ -z "$PORT_80_PROCESS" ]; then
    PORT_80_PROCESS=$(netstat -tlnp 2>/dev/null | grep ':80 ' | awk '{print $7}' | cut -d'/' -f1 | head -1)
fi

if [ -n "$PORT_80_PROCESS" ]; then
    PORT_80_NAME=$(ps -p $PORT_80_PROCESS -o comm= 2>/dev/null)
    echo -e "${YELLOW}Port 80 is in use by:${NC}"
    echo "  Process ID: $PORT_80_PROCESS"
    echo "  Process Name: $PORT_80_NAME"
    echo ""

    # Get full process info
    ps -p $PORT_80_PROCESS -f 2>/dev/null
    echo ""
else
    echo -e "${GREEN}Port 80 appears to be free${NC}"
    echo "Attempting to start Kong..."
    docker compose up -d kong
    exit 0
fi

# Provide options
echo -e "${YELLOW}You have several options:${NC}"
echo ""
echo "1. Stop the conflicting service and use standard ports (80/443)"
echo "2. Use alternative ports (8000/8443) - requires updating firewall"
echo "3. Set up reverse proxy (advanced)"
echo ""
echo -e "${CYAN}Option 1: Stop Conflicting Service (Recommended)${NC}"
echo ""

# Identify common services
case "$PORT_80_NAME" in
    apache2)
        echo "Apache web server is running."
        echo ""
        echo "To stop Apache temporarily:"
        echo "  ${BLUE}systemctl stop apache2${NC}"
        echo ""
        echo "To disable Apache permanently:"
        echo "  ${BLUE}systemctl stop apache2 && systemctl disable apache2${NC}"
        ;;
    nginx)
        echo "Nginx web server is running."
        echo ""
        echo "To stop Nginx temporarily:"
        echo "  ${BLUE}systemctl stop nginx${NC}"
        echo ""
        echo "To disable Nginx permanently:"
        echo "  ${BLUE}systemctl stop nginx && systemctl disable nginx${NC}"
        ;;
    *)
        echo "Unknown service: $PORT_80_NAME"
        echo ""
        echo "To stop this process:"
        echo "  ${BLUE}kill $PORT_80_PROCESS${NC}"
        ;;
esac

echo ""
echo -e "${CYAN}Option 2: Use Alternative Ports${NC}"
echo ""
echo "Keep your existing web server and use ports 8000/8443 for Supabase:"
echo "  1. Edit docker-compose.yml Kong ports back to 8000:8000 and 8443:8443"
echo "  2. Update firewall: ${BLUE}ufw allow 8000/tcp && ufw allow 8443/tcp${NC}"
echo "  3. Access Studio at: http://studio.qoqnuz.com:8000"
echo ""

echo -e "${CYAN}Option 3: Reverse Proxy (Advanced)${NC}"
echo ""
echo "Use your existing web server as a reverse proxy to Kong."
echo "This allows both to run simultaneously."
echo ""

# Interactive choice
echo ""
read -p "Would you like to automatically stop $PORT_80_NAME and start Kong? (yes/no): " CHOICE

if [ "$CHOICE" == "yes" ]; then
    echo ""
    echo -e "${BLUE}Stopping $PORT_80_NAME...${NC}"

    case "$PORT_80_NAME" in
        apache2)
            systemctl stop apache2
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ Apache stopped${NC}"

                read -p "Disable Apache permanently? (yes/no): " DISABLE
                if [ "$DISABLE" == "yes" ]; then
                    systemctl disable apache2
                    echo -e "${GREEN}✓ Apache disabled${NC}"
                fi
            fi
            ;;
        nginx)
            systemctl stop nginx
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ Nginx stopped${NC}"

                read -p "Disable Nginx permanently? (yes/no): " DISABLE
                if [ "$DISABLE" == "yes" ]; then
                    systemctl disable nginx
                    echo -e "${GREEN}✓ Nginx disabled${NC}"
                fi
            fi
            ;;
        *)
            kill $PORT_80_PROCESS
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ Process stopped${NC}"
            fi
            ;;
    esac

    echo ""
    echo -e "${BLUE}Starting Kong on port 80...${NC}"
    sleep 2

    docker compose up -d kong

    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✓ Kong started successfully!${NC}"
        echo ""

        # Wait for Kong to be ready
        echo "Waiting for Kong to be ready..."
        sleep 5

        # Test port 80
        if curl -sf http://localhost/ &> /dev/null; then
            echo -e "${GREEN}✓ Port 80 is now accessible${NC}"
            echo ""
            echo -e "${CYAN}Access Points:${NC}"
            echo -e "  📊 Studio: ${GREEN}http://studio.qoqnuz.com${NC}"
            echo -e "  🔌 API:    ${GREEN}http://db.qoqnuz.com${NC}"
        else
            echo -e "${YELLOW}⚠ Port 80 accessible but Kong may still be initializing${NC}"
            echo "Wait 10 more seconds and try: curl http://localhost/"
        fi
    else
        echo -e "${RED}✗ Failed to start Kong${NC}"
        echo "Check logs: docker compose logs kong"
    fi
else
    echo ""
    echo "No changes made. Choose one of the options above and apply manually."
fi

echo ""

#!/bin/bash

################################################################################
# Supabase Services Health Check Script
# Comprehensive service validation
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
echo -e "${BLUE}   Supabase Services Health Check${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Load environment variables
if [ -f .env ]; then
    set -a
    source .env
    set +a
else
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

# Service check function
check_service() {
    local name=$1
    local container=$2
    local health_cmd=$3
    local port=$4

    echo -n "  🔍 ${name}... "

    # Check if container exists and is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        echo -e "${RED}NOT RUNNING${NC}"
        return 1
    fi

    # Check container health status
    local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
    if [ "$status" != "running" ]; then
        echo -e "${RED}STOPPED${NC}"
        return 1
    fi

    # Run health check command if provided
    if [ -n "$health_cmd" ]; then
        if eval "$health_cmd" &> /dev/null; then
            echo -e "${GREEN}HEALTHY${NC}"
            return 0
        else
            echo -e "${YELLOW}RUNNING (health check failed)${NC}"
            return 1
        fi
    else
        echo -e "${GREEN}RUNNING${NC}"
        return 0
    fi
}

################################################################################
# Check Core Services
################################################################################

echo -e "${CYAN}Core Services:${NC}"

check_service "Database (PostgreSQL)" "supabase-db" \
    "docker exec supabase-db pg_isready -U postgres"

check_service "Auth (GoTrue)" "supabase-auth" \
    "curl -sf http://localhost:9999/health"

check_service "REST API (PostgREST)" "supabase-rest" \
    "docker logs supabase-rest 2>&1 | grep -q 'Listening on port'"

check_service "Realtime" "realtime-dev.supabase-realtime" \
    "docker logs realtime-dev.supabase-realtime 2>&1 | grep -q 'Running'"

check_service "Storage" "supabase-storage" \
    "docker logs supabase-storage 2>&1 | tail -5 | grep -q 'Started'"

check_service "Meta (DB Management)" "supabase-meta" \
    "curl -sf http://localhost:8080/health"

check_service "Kong (API Gateway)" "supabase-kong" \
    "docker exec supabase-kong kong health"

echo ""
echo -e "${CYAN}Optional Services:${NC}"

check_service "Analytics (Logflare)" "supabase-analytics" \
    "curl -sf http://localhost:4000/health"

check_service "Functions (Deno)" "supabase-functions" \
    "docker logs supabase-functions 2>&1 | grep -q 'listening on'"

check_service "ImgProxy" "supabase-imgproxy" \
    "docker logs supabase-imgproxy 2>&1 | grep -q 'Started'"

check_service "Studio (Dashboard)" "supabase-studio" \
    "docker logs supabase-studio 2>&1 | tail -10 | grep -q 'Ready'"

################################################################################
# Check Network Connectivity
################################################################################

echo ""
echo -e "${CYAN}Network Connectivity:${NC}"

echo -n "  🌐 Kong HTTP (8000)... "
if curl -sf http://localhost:8000/ > /dev/null 2>&1; then
    echo -e "${GREEN}ACCESSIBLE${NC}"
else
    echo -e "${RED}NOT ACCESSIBLE${NC}"
fi

echo -n "  🌐 Studio via Kong... "
if curl -sf http://localhost:8000/ 2>&1 | grep -q "<!DOCTYPE html>"; then
    echo -e "${GREEN}ACCESSIBLE${NC}"
else
    echo -e "${YELLOW}LIMITED${NC}"
fi

################################################################################
# Check Database
################################################################################

echo ""
echo -e "${CYAN}Database Status:${NC}"

# Check database size
echo -n "  💾 Database size... "
DB_SIZE=$(docker exec supabase-db psql -U postgres -t -c "SELECT pg_size_pretty(pg_database_size('postgres'));" 2>/dev/null | xargs)
if [ -n "$DB_SIZE" ]; then
    echo -e "${GREEN}${DB_SIZE}${NC}"
else
    echo -e "${RED}UNKNOWN${NC}"
fi

# Check connections
echo -n "  🔌 Active connections... "
CONNECTIONS=$(docker exec supabase-db psql -U postgres -t -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';" 2>/dev/null | xargs)
if [ -n "$CONNECTIONS" ]; then
    echo -e "${GREEN}${CONNECTIONS}${NC}"
else
    echo -e "${RED}UNKNOWN${NC}"
fi

# Check roles
echo -n "  👥 Database roles... "
ROLES=$(docker exec supabase-db psql -U postgres -t -c "SELECT count(*) FROM pg_roles WHERE rolname LIKE 'supabase%';" 2>/dev/null | xargs)
if [ "$ROLES" -gt 0 ]; then
    echo -e "${GREEN}${ROLES} roles${NC}"
else
    echo -e "${RED}NOT CONFIGURED${NC}"
fi

# Check extensions
echo -n "  🔧 PostgreSQL extensions... "
EXTENSIONS=$(docker exec supabase-db psql -U postgres -t -c "SELECT count(*) FROM pg_extension;" 2>/dev/null | xargs)
if [ -n "$EXTENSIONS" ] && [ "$EXTENSIONS" -gt 0 ]; then
    echo -e "${GREEN}${EXTENSIONS} installed${NC}"
else
    echo -e "${RED}UNKNOWN${NC}"
fi

################################################################################
# Check Docker Resources
################################################################################

echo ""
echo -e "${CYAN}Resource Usage:${NC}"

# Memory usage
echo -n "  🧠 Memory usage... "
MEMORY=$(docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}" | grep supabase | awk '{sum+=$2} END {print sum}')
echo -e "${GREEN}Monitoring${NC}"

# CPU usage
echo -n "  ⚡ CPU usage... "
echo -e "${GREEN}Monitoring${NC}"

# Disk usage
echo -n "  💿 Disk usage (volumes)... "
DISK_USAGE=$(du -sh volumes 2>/dev/null | awk '{print $1}')
if [ -n "$DISK_USAGE" ]; then
    echo -e "${GREEN}${DISK_USAGE}${NC}"
else
    echo -e "${YELLOW}UNKNOWN${NC}"
fi

################################################################################
# Check Configuration
################################################################################

echo ""
echo -e "${CYAN}Configuration:${NC}"

echo -n "  📝 .env file... "
if [ -f .env ]; then
    echo -e "${GREEN}EXISTS${NC}"
else
    echo -e "${RED}MISSING${NC}"
fi

echo -n "  🔑 JWT keys configured... "
if [ -n "$ANON_KEY" ] && [ -n "$SERVICE_ROLE_KEY" ]; then
    echo -e "${GREEN}YES${NC}"
else
    echo -e "${RED}NO${NC}"
fi

echo -n "  🌐 Domains configured... "
if [ -n "$API_DOMAIN" ] && [ -n "$STUDIO_DOMAIN" ]; then
    echo -e "${GREEN}${API_DOMAIN}, ${STUDIO_DOMAIN}${NC}"
else
    echo -e "${RED}NOT SET${NC}"
fi

################################################################################
# Check Logs for Errors
################################################################################

echo ""
echo -e "${CYAN}Recent Errors (last 5 minutes):${NC}"

ERROR_COUNT=0

for container in supabase-db supabase-auth supabase-rest supabase-kong realtime-dev.supabase-realtime supabase-storage supabase-studio; do
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        ERRORS=$(docker logs --since=5m "$container" 2>&1 | grep -i "error\|fatal\|panic" | wc -l)
        if [ "$ERRORS" -gt 0 ]; then
            echo -e "  ${RED}✗ ${container}: ${ERRORS} errors${NC}"
            ERROR_COUNT=$((ERROR_COUNT + ERRORS))
        fi
    fi
done

if [ "$ERROR_COUNT" -eq 0 ]; then
    echo -e "  ${GREEN}✓ No recent errors detected${NC}"
fi

################################################################################
# Summary
################################################################################

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

RUNNING_COUNT=$(docker ps --format '{{.Names}}' | grep supabase | wc -l)

if [ "$RUNNING_COUNT" -ge 10 ]; then
    echo -e "${GREEN}✓ System Status: HEALTHY${NC}"
    echo -e "${GREEN}  ${RUNNING_COUNT}/11 services running${NC}"
elif [ "$RUNNING_COUNT" -ge 7 ]; then
    echo -e "${YELLOW}⚠ System Status: PARTIAL${NC}"
    echo -e "${YELLOW}  ${RUNNING_COUNT}/11 services running${NC}"
else
    echo -e "${RED}✗ System Status: DEGRADED${NC}"
    echo -e "${RED}  ${RUNNING_COUNT}/11 services running${NC}"
fi

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

if [ -n "$STUDIO_DOMAIN" ]; then
    echo -e "${CYAN}Access Points:${NC}"
    echo -e "  📊 Studio: ${GREEN}http://${STUDIO_DOMAIN}:8000${NC}"
    echo -e "  🔌 API:    ${GREEN}http://${API_DOMAIN}:8000${NC}"
    echo ""
fi

# Suggest actions if issues found
if [ "$RUNNING_COUNT" -lt 10 ] || [ "$ERROR_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}Suggested Actions:${NC}"
    if [ "$RUNNING_COUNT" -lt 10 ]; then
        echo "  • Check service logs: docker compose logs <service-name>"
        echo "  • Restart all services: docker compose restart"
    fi
    if [ "$ERROR_COUNT" -gt 5 ]; then
        echo "  • Review error logs: docker compose logs --tail=100"
        echo "  • Check system resources: docker stats"
    fi
    echo ""
fi

echo -e "${CYAN}Useful Commands:${NC}"
echo "  • View all logs:        docker compose logs -f"
echo "  • View service logs:    docker compose logs -f <service>"
echo "  • Restart service:      docker compose restart <service>"
echo "  • Check disk space:     df -h"
echo "  • Check memory:         free -h"
echo ""

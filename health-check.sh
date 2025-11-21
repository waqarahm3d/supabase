#!/bin/bash

# Health check script for Supabase services

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "╔═══════════════════════════════════════════╗"
echo "║     Supabase Health Check                 ║"
echo "╚═══════════════════════════════════════════╝"
echo ""

# Check if services are running
echo -e "${BLUE}Docker Services Status:${NC}"
docker-compose ps

echo ""
echo -e "${BLUE}Service Health Checks:${NC}"

# Check database
echo -n "Database (PostgreSQL)... "
if docker exec supabase-db pg_isready -U postgres &>/dev/null; then
    echo -e "${GREEN}✓ Healthy${NC}"
else
    echo -e "${RED}✗ Unhealthy${NC}"
fi

# Check Kong (API Gateway)
echo -n "API Gateway (Kong)... "
if curl -s -f http://localhost:8000/health &>/dev/null; then
    echo -e "${GREEN}✓ Healthy${NC}"
else
    echo -e "${RED}✗ Unhealthy${NC}"
fi

# Check Auth
echo -n "Auth Service... "
if docker exec supabase-auth wget -q --spider http://localhost:9999/health &>/dev/null; then
    echo -e "${GREEN}✓ Healthy${NC}"
else
    echo -e "${RED}✗ Unhealthy${NC}"
fi

# Check Storage
echo -n "Storage Service... "
if docker exec supabase-storage wget -q --spider http://localhost:5000/status &>/dev/null; then
    echo -e "${GREEN}✓ Healthy${NC}"
else
    echo -e "${RED}✗ Unhealthy${NC}"
fi

# Check Realtime
echo -n "Realtime Service... "
if docker exec realtime-dev.supabase-realtime nc -z localhost 4000 &>/dev/null; then
    echo -e "${GREEN}✓ Healthy${NC}"
else
    echo -e "${RED}✗ Unhealthy${NC}"
fi

# System resources
echo ""
echo -e "${BLUE}System Resources:${NC}"
echo "Memory Usage:"
free -h | grep -E "Mem|Swap"

echo ""
echo "Disk Usage:"
df -h | grep -E "Filesystem|/dev/|overlay"

echo ""
echo -e "${BLUE}Docker Resource Usage:${NC}"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"

echo ""
echo -e "${BLUE}Container Logs (last 10 lines):${NC}"
echo "To view full logs for a service, run:"
echo "  docker-compose logs -f [service_name]"
echo ""

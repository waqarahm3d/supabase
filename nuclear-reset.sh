#!/bin/bash

################################################################################
# NUCLEAR RESET - DELETE EVERYTHING
#
# This script will:
# 1. Stop and remove ALL Docker containers, volumes, networks
# 2. Delete ALL files in the repository except .git
# 3. Start completely fresh
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                                                                ║"
echo "║               ⚠️  NUCLEAR RESET - DELETE EVERYTHING ⚠️          ║"
echo "║                                                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "${RED}This will DELETE EVERYTHING:${NC}"
echo "  • All Docker containers"
echo "  • All Docker volumes"
echo "  • All Docker networks"
echo "  • All files in this directory (except .git)"
echo "  • All Supabase data"
echo "  • All configuration"
echo ""
echo -e "${YELLOW}You will need to re-clone or re-download Supabase after this!${NC}"
echo ""
read -p "Type 'DELETE EVERYTHING' to confirm: " CONFIRM

if [ "$CONFIRM" != "DELETE EVERYTHING" ]; then
    echo -e "${YELLOW}Aborted. Nothing was deleted.${NC}"
    exit 0
fi

echo ""
echo -e "${RED}Starting nuclear reset in 5 seconds...${NC}"
sleep 1
echo "5..."
sleep 1
echo "4..."
sleep 1
echo "3..."
sleep 1
echo "2..."
sleep 1
echo "1..."
sleep 1
echo ""

# Stop and remove ALL Docker containers
echo -e "${BLUE}Stopping all containers...${NC}"
docker compose down -v --remove-orphans 2>/dev/null || true
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm -f $(docker ps -aq) 2>/dev/null || true
echo -e "${GREEN}✓ All containers stopped and removed${NC}"

# Remove ALL Docker volumes
echo -e "${BLUE}Removing all Docker volumes...${NC}"
docker volume rm $(docker volume ls -q) 2>/dev/null || true
echo -e "${GREEN}✓ All volumes removed${NC}"

# Remove ALL Docker networks (except defaults)
echo -e "${BLUE}Removing Docker networks...${NC}"
docker network prune -f 2>/dev/null || true
echo -e "${GREEN}✓ Networks cleaned${NC}"

# Prune everything
echo -e "${BLUE}Pruning Docker system...${NC}"
docker system prune -af --volumes 2>/dev/null || true
echo -e "${GREEN}✓ Docker system pruned${NC}"

# Delete ALL files except .git
echo ""
echo -e "${BLUE}Deleting all files in repository...${NC}"
find . -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} + 2>/dev/null || true
echo -e "${GREEN}✓ All files deleted${NC}"

# Show what's left
echo ""
echo -e "${GREEN}Nuclear reset complete!${NC}"
echo ""
echo "What remains:"
ls -la
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Clone fresh Supabase:"
echo "   git clone --depth 1 https://github.com/supabase/supabase"
echo "   cd supabase/docker"
echo ""
echo "2. Or download fresh docker setup:"
echo "   curl -o docker-compose.yml https://raw.githubusercontent.com/supabase/supabase/master/docker/docker-compose.yml"
echo "   curl -o .env.example https://raw.githubusercontent.com/supabase/supabase/master/docker/.env.example"
echo "   cp .env.example .env"
echo ""
echo -e "${RED}Repository is now empty and ready for fresh start!${NC}"

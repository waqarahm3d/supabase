#!/bin/bash

# Stop script for Supabase

set -e

# Colors
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${YELLOW}Stopping Supabase services...${NC}"

docker-compose down

echo ""
echo -e "${GREEN}✓ Supabase services stopped${NC}"
echo ""
echo "To start again, run:"
echo "  ./start.sh"
echo ""

#!/bin/bash

# Quick start script for Supabase

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Starting Supabase services...${NC}"

# Check if .env exists
if [ ! -f .env ]; then
    echo "Error: .env file not found. Please run ./setup.sh first."
    exit 1
fi

# Start services
docker-compose up -d

echo ""
echo -e "${GREEN}✓ Supabase is starting up!${NC}"
echo ""
echo "Services Status:"
docker-compose ps

echo ""
echo "To view logs:"
echo "  docker-compose logs -f"
echo ""
echo "To access Supabase Studio:"
echo "  https://studio.qoqnuz.com"
echo ""
echo "API Endpoint:"
echo "  https://db.qoqnuz.com"
echo ""

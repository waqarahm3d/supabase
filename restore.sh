#!/bin/bash

# Restore script for Supabase database and storage

set -e

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if backup directory is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Please provide backup directory${NC}"
    echo "Usage: ./restore.sh <backup_directory>"
    echo ""
    echo "Available backups:"
    ls -1 backups/ 2>/dev/null || echo "  No backups found"
    exit 1
fi

BACKUP_DIR="$1"

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${RED}Error: Backup directory not found: $BACKUP_DIR${NC}"
    exit 1
fi

echo -e "${YELLOW}WARNING: This will overwrite your current database and storage!${NC}"
read -p "Are you sure you want to continue? (yes/no): " -r
echo
if [[ ! $REPLY == "yes" ]]; then
    echo "Restore cancelled."
    exit 0
fi

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

echo -e "${BLUE}Restoring from backup: $BACKUP_DIR${NC}"

# Stop services
echo "Stopping Supabase services..."
docker-compose down
echo -e "${GREEN}✓ Services stopped${NC}"

# Restore database
echo "Restoring PostgreSQL database..."
docker-compose up -d db
sleep 10  # Wait for database to be ready
docker exec -i supabase-db psql -U postgres postgres < "$BACKUP_DIR/database.sql"
echo -e "${GREEN}✓ Database restored${NC}"

# Restore storage
echo "Restoring storage files..."
rm -rf volumes/storage/*
tar -xzf "$BACKUP_DIR/storage.tar.gz" -C .
echo -e "${GREEN}✓ Storage restored${NC}"

# Restart all services
echo "Starting all services..."
docker-compose up -d
sleep 10

echo ""
echo -e "${GREEN}✓ Restore complete!${NC}"
echo ""
echo "Services Status:"
docker-compose ps
echo ""

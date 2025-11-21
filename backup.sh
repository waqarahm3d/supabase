#!/bin/bash

# Backup script for Supabase database and storage

set -e

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

# Create backup directory
BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo -e "${BLUE}Creating backup in $BACKUP_DIR${NC}"

# Backup database
echo "Backing up PostgreSQL database..."
docker exec supabase-db pg_dump -U postgres postgres > "$BACKUP_DIR/database.sql"
echo -e "${GREEN}✓ Database backup complete${NC}"

# Backup storage
echo "Backing up storage files..."
tar -czf "$BACKUP_DIR/storage.tar.gz" volumes/storage/
echo -e "${GREEN}✓ Storage backup complete${NC}"

# Backup configuration
echo "Backing up configuration..."
cp .env "$BACKUP_DIR/.env.backup"
cp docker-compose.yml "$BACKUP_DIR/docker-compose.yml.backup"
echo -e "${GREEN}✓ Configuration backup complete${NC}"

# Create backup info
cat > "$BACKUP_DIR/backup_info.txt" << EOF
Backup Information
==================
Date: $(date)
Database: postgres
Version: $(docker exec supabase-db psql -U postgres -c "SELECT version();" -t | head -1)

Files Included:
- database.sql (PostgreSQL dump)
- storage.tar.gz (Storage files)
- .env.backup (Environment configuration)
- docker-compose.yml.backup (Docker Compose configuration)
EOF

echo ""
echo -e "${GREEN}✓ Backup complete!${NC}"
echo "Backup location: $BACKUP_DIR"
echo ""
echo "To restore this backup:"
echo "  ./restore.sh $BACKUP_DIR"
echo ""

# Clean up old backups (keep last 7 days)
echo "Cleaning up old backups (keeping last 7 days)..."
find backups/ -maxdepth 1 -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null || true
echo -e "${GREEN}✓ Cleanup complete${NC}"

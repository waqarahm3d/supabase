#!/bin/bash

################################################################################
# FIX MOUNT ERROR - Create required config files before Docker starts
#
# Error: Docker trying to mount postgresql.conf but it's a directory not a file
# Solution: Create the file BEFORE starting containers
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Fixing Docker mount error...${NC}"
echo ""

# Stop any running containers
echo "Stopping containers..."
docker compose down 2>/dev/null || true

# Remove the incorrectly created directory
echo "Removing incorrect postgresql.conf directory..."
if [ -d "volumes/db/postgresql.conf" ]; then
    rm -rf volumes/db/postgresql.conf
    echo -e "${GREEN}✓ Removed directory${NC}"
fi

# Create volumes/db if it doesn't exist
mkdir -p volumes/db

# Create postgresql.conf as a FILE with proper content
echo "Creating postgresql.conf as a file..."
cat > volumes/db/postgresql.conf << 'EOF'
# PostgreSQL configuration file for Supabase
listen_addresses = '*'
max_connections = 100
shared_buffers = 128MB
dynamic_shared_memory_type = posix
max_wal_size = 1GB
min_wal_size = 80MB
log_timezone = 'UTC'
datestyle = 'iso, mdy'
timezone = 'UTC'
lc_messages = 'en_US.utf8'
lc_monetary = 'en_US.utf8'
lc_numeric = 'en_US.utf8'
lc_time = 'en_US.utf8'
default_text_search_config = 'pg_catalog.english'
EOF

echo -e "${GREEN}✓ Created postgresql.conf as file${NC}"

# Verify it's a file, not a directory
if [ -f "volumes/db/postgresql.conf" ]; then
    echo -e "${GREEN}✓ Verified: postgresql.conf is a file${NC}"
    ls -lh volumes/db/postgresql.conf
else
    echo -e "${RED}✗ ERROR: postgresql.conf is not a file${NC}"
    exit 1
fi

# Create other required config files if they're mounted
echo ""
echo "Creating other required files..."

# Check docker-compose.yml for other file mounts
if grep -q "volumes/db/pg_hba.conf" docker-compose.yml 2>/dev/null; then
    echo "Creating pg_hba.conf..."
    cat > volumes/db/pg_hba.conf << 'EOF'
# PostgreSQL Client Authentication Configuration File
local   all             all                                     trust
host    all             all             127.0.0.1/32            trust
host    all             all             ::1/128                 trust
host    all             all             0.0.0.0/0               md5
EOF
    echo -e "${GREEN}✓ Created pg_hba.conf${NC}"
fi

echo ""
echo -e "${GREEN}✓ All mount issues fixed!${NC}"
echo ""
echo "Now starting containers..."
docker compose up -d

echo ""
echo "Waiting 30 seconds for services to start..."
sleep 30

echo ""
echo "Checking database container..."
if docker compose ps db | grep -q "running"; then
    echo -e "${GREEN}✓ Database container is running!${NC}"
else
    echo -e "${RED}✗ Database container failed to start${NC}"
    echo ""
    echo "Checking logs..."
    docker compose logs db
fi

echo ""
echo -e "${BLUE}Done! Try your tests now.${NC}"

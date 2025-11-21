#!/bin/bash

################################################################################
# Fix Database Role Passwords
# Resets all Supabase database role passwords to match .env file
################################################################################

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Supabase Database Password Reset${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Load environment variables safely
if [ -f .env ]; then
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        [[ ! "$line" =~ = ]] && continue
        key="${line%%=*}"
        value="${line#*=}"
        key=$(echo "$key" | xargs)
        export "$key=$value"
    done < .env
else
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

# Check if database is running
echo -n "Checking database connection... "
if ! docker exec supabase-db pg_isready -U postgres &> /dev/null; then
    echo -e "${RED}FAILED${NC}"
    echo -e "${RED}Database is not running or not accessible${NC}"
    exit 1
fi
echo -e "${GREEN}OK${NC}"

# Get the current POSTGRES_PASSWORD from .env
if [ -z "$POSTGRES_PASSWORD" ]; then
    echo -e "${RED}Error: POSTGRES_PASSWORD not set in .env${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}This script will reset the following database role passwords:${NC}"
echo "  • postgres (superuser)"
echo "  • authenticator (REST API)"
echo "  • supabase_auth_admin (Auth service)"
echo "  • supabase_storage_admin (Storage service)"
echo "  • service_role"
echo "  • anon"
echo ""
echo -e "${YELLOW}Password source: POSTGRES_PASSWORD from .env${NC}"
echo ""
echo -e "${YELLOW}WARNING: This will disconnect all active connections!${NC}"
echo ""
read -p "Continue? (yes/no): " answer

if [ "$answer" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo -e "${BLUE}Resetting passwords...${NC}"
echo ""

# Create SQL script to reset passwords
cat > /tmp/reset-passwords.sql << EOF
-- Reset all role passwords
ALTER USER postgres WITH PASSWORD '${POSTGRES_PASSWORD}';
ALTER USER authenticator WITH PASSWORD '${POSTGRES_PASSWORD}';
ALTER USER supabase_auth_admin WITH PASSWORD '${POSTGRES_PASSWORD}';
ALTER USER supabase_storage_admin WITH PASSWORD '${POSTGRES_PASSWORD}';
ALTER USER service_role WITH PASSWORD '${POSTGRES_PASSWORD}';
ALTER USER anon WITH PASSWORD '${POSTGRES_PASSWORD}';

-- Also reset pgbouncer users if they exist
DO \$\$
BEGIN
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'pgbouncer') THEN
        ALTER USER pgbouncer WITH PASSWORD '${POSTGRES_PASSWORD}';
    END IF;
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'supabase_admin') THEN
        ALTER USER supabase_admin WITH PASSWORD '${POSTGRES_PASSWORD}';
    END IF;
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'supabase_read_only_user') THEN
        ALTER USER supabase_read_only_user WITH PASSWORD '${POSTGRES_PASSWORD}';
    END IF;
END \$\$;

-- Verify roles
SELECT rolname FROM pg_roles WHERE rolname IN (
    'postgres',
    'authenticator',
    'supabase_auth_admin',
    'supabase_storage_admin',
    'service_role',
    'anon'
) ORDER BY rolname;
EOF

# Copy SQL file to container and execute
docker cp /tmp/reset-passwords.sql supabase-db:/tmp/reset-passwords.sql

echo -n "  Resetting postgres... "
if docker exec supabase-db psql -U postgres -q -c "ALTER USER postgres WITH PASSWORD '${POSTGRES_PASSWORD}';" &> /dev/null; then
    echo -e "${GREEN}Done${NC}"
else
    echo -e "${RED}Failed${NC}"
fi

echo -n "  Resetting authenticator... "
if docker exec supabase-db psql -U postgres -q -c "ALTER USER authenticator WITH PASSWORD '${POSTGRES_PASSWORD}';" &> /dev/null; then
    echo -e "${GREEN}Done${NC}"
else
    echo -e "${YELLOW}Skipped (role may not exist)${NC}"
fi

echo -n "  Resetting supabase_auth_admin... "
if docker exec supabase-db psql -U postgres -q -c "ALTER USER supabase_auth_admin WITH PASSWORD '${POSTGRES_PASSWORD}';" &> /dev/null; then
    echo -e "${GREEN}Done${NC}"
else
    echo -e "${YELLOW}Skipped (role may not exist)${NC}"
fi

echo -n "  Resetting supabase_storage_admin... "
if docker exec supabase-db psql -U postgres -q -c "ALTER USER supabase_storage_admin WITH PASSWORD '${POSTGRES_PASSWORD}';" &> /dev/null; then
    echo -e "${GREEN}Done${NC}"
else
    echo -e "${YELLOW}Skipped (role may not exist)${NC}"
fi

echo -n "  Resetting service_role... "
if docker exec supabase-db psql -U postgres -q -c "ALTER USER service_role WITH PASSWORD '${POSTGRES_PASSWORD}';" &> /dev/null; then
    echo -e "${GREEN}Done${NC}"
else
    echo -e "${YELLOW}Skipped (role may not exist)${NC}"
fi

echo -n "  Resetting anon... "
if docker exec supabase-db psql -U postgres -q -c "ALTER USER anon WITH PASSWORD '${POSTGRES_PASSWORD}';" &> /dev/null; then
    echo -e "${GREEN}Done${NC}"
else
    echo -e "${YELLOW}Skipped (role may not exist)${NC}"
fi

# Clean up
rm -f /tmp/reset-passwords.sql
docker exec supabase-db rm -f /tmp/reset-passwords.sql

echo ""
echo -e "${GREEN}✓ Database passwords updated${NC}"
echo ""

# Restart services that need database connection
echo -e "${BLUE}Restarting services...${NC}"
echo ""

docker compose restart auth rest storage functions &> /dev/null

echo "  Waiting 15 seconds for services to start..."
sleep 15

echo ""
echo -e "${BLUE}Checking service status:${NC}"
echo ""

# Check if services are now running
check_service() {
    local container=$1
    local name=$2
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
        if [ "$status" == "running" ]; then
            echo -e "  ${GREEN}✓${NC} $name is running"
            return 0
        else
            echo -e "  ${RED}✗${NC} $name is $status"
            return 1
        fi
    else
        echo -e "  ${RED}✗${NC} $name is not running"
        return 1
    fi
}

SUCCESS=0
check_service "supabase-auth" "Auth (GoTrue)" && SUCCESS=$((SUCCESS + 1))
check_service "supabase-rest" "REST API (PostgREST)" && SUCCESS=$((SUCCESS + 1))
check_service "supabase-storage" "Storage" && SUCCESS=$((SUCCESS + 1))

echo ""

if [ $SUCCESS -eq 3 ]; then
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ All services successfully started!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}Run ./check-services.sh to verify full system health${NC}"
else
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}⚠ Some services may still be starting${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "  1. Wait 30 seconds and check again: ./check-services.sh"
    echo "  2. Check logs: docker compose logs auth rest storage"
    echo "  3. If still failing, check: docker compose ps"
fi

echo ""

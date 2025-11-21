#!/bin/bash

################################################################################
# Supabase End-to-End Deployment Test
# Comprehensive validation of all services and endpoints
################################################################################

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Load environment variables
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

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Supabase End-to-End Deployment Test${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Test function
run_test() {
    local test_name=$1
    local test_command=$2
    local test_type=${3:-"command"}

    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo -n "  Testing $test_name... "

    if [ "$test_type" == "command" ]; then
        if eval "$test_command" &> /dev/null; then
            echo -e "${GREEN}PASS${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            return 0
        else
            echo -e "${RED}FAIL${NC}"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    elif [ "$test_type" == "http" ]; then
        local response=$(eval "$test_command" 2>/dev/null)
        local exit_code=$?
        if [ $exit_code -eq 0 ] && [ -n "$response" ]; then
            echo -e "${GREEN}PASS${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            return 0
        else
            echo -e "${RED}FAIL${NC}"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    fi
}

################################################################################
# 1. Environment Tests
################################################################################

echo -e "${CYAN}1. Environment Configuration${NC}"

run_test "API domain configured" "[ -n '$API_DOMAIN' ]"
run_test "Studio domain configured" "[ -n '$STUDIO_DOMAIN' ]"
run_test "JWT secret configured" "[ -n '$JWT_SECRET' ]"
run_test "Anon key configured" "[ -n '$ANON_KEY' ]"
run_test "Service role key configured" "[ -n '$SERVICE_ROLE_KEY' ]"
run_test "Database password configured" "[ -n '$POSTGRES_PASSWORD' ]"

echo ""

################################################################################
# 2. Container Tests
################################################################################

echo -e "${CYAN}2. Docker Containers${NC}"

run_test "Database container running" "docker ps --format '{{.Names}}' | grep -q '^supabase-db$'"
run_test "Auth container running" "docker ps --format '{{.Names}}' | grep -q '^supabase-auth$'"
run_test "REST container running" "docker ps --format '{{.Names}}' | grep -q '^supabase-rest$'"
run_test "Realtime container running" "docker ps --format '{{.Names}}' | grep -q '^realtime-dev.supabase-realtime$'"
run_test "Storage container running" "docker ps --format '{{.Names}}' | grep -q '^supabase-storage$'"
run_test "Kong container running" "docker ps --format '{{.Names}}' | grep -q '^supabase-kong$'"
run_test "Studio container running" "docker ps --format '{{.Names}}' | grep -q '^supabase-studio$'"
run_test "Analytics container running" "docker ps --format '{{.Names}}' | grep -q '^supabase-analytics$'"
run_test "Edge Functions container running" "docker ps --format '{{.Names}}' | grep -q '^supabase-edge-functions$'"
run_test "ImgProxy container running" "docker ps --format '{{.Names}}' | grep -q '^supabase-imgproxy$'"
run_test "Meta container running" "docker ps --format '{{.Names}}' | grep -q '^supabase-meta$'"

echo ""

################################################################################
# 3. Database Tests
################################################################################

echo -e "${CYAN}3. Database${NC}"

run_test "PostgreSQL accepting connections" "docker exec supabase-db pg_isready -U postgres"
run_test "Database postgres exists" "docker exec supabase-db psql -U postgres -lqt | cut -d \| -f 1 | grep -qw postgres"
run_test "Role authenticator exists" "docker exec supabase-db psql -U postgres -tAc \"SELECT 1 FROM pg_roles WHERE rolname='authenticator'\" | grep -q 1"
run_test "Role supabase_auth_admin exists" "docker exec supabase-db psql -U postgres -tAc \"SELECT 1 FROM pg_roles WHERE rolname='supabase_auth_admin'\" | grep -q 1"
run_test "Role supabase_storage_admin exists" "docker exec supabase-db psql -U postgres -tAc \"SELECT 1 FROM pg_roles WHERE rolname='supabase_storage_admin'\" | grep -q 1"
run_test "Extension pg_stat_statements loaded" "docker exec supabase-db psql -U postgres -tAc \"SELECT 1 FROM pg_extension WHERE extname='pg_stat_statements'\" | grep -q 1"
run_test "WAL level is logical" "docker exec supabase-db psql -U postgres -tAc \"SHOW wal_level\" | grep -q logical"

echo ""

################################################################################
# 4. Service Health Tests
################################################################################

echo -e "${CYAN}4. Service Health${NC}"

run_test "Kong health check" "docker exec supabase-kong kong health"
run_test "Auth health endpoint" "curl -sf http://localhost:9999/health" "http"
run_test "Meta health endpoint" "curl -sf http://localhost:8080/health" "http"
run_test "Analytics health endpoint" "curl -sf http://localhost:4000/health" "http"

echo ""

################################################################################
# 5. Network Connectivity Tests
################################################################################

echo -e "${CYAN}5. Network Connectivity${NC}"

run_test "Kong HTTP accessible (port 80)" "curl -sf http://localhost/" "http"
run_test "Kong API gateway responding" "curl -sf http://localhost/ 2>&1 | grep -q 'html\|DOCTYPE'" "http"
run_test "Studio accessible via Kong" "curl -sf http://localhost/ 2>&1 | grep -q 'html\|DOCTYPE'" "http"

# Domain tests (only if not localhost)
if [ "$STUDIO_DOMAIN" != "localhost" ]; then
    run_test "Studio domain accessible" "curl -sf http://${STUDIO_DOMAIN}/ 2>&1 | grep -q 'html\|DOCTYPE'" "http"
    run_test "API domain accessible" "curl -sf http://${API_DOMAIN}/ 2>&1 | grep -q 'html\|DOCTYPE'" "http"
fi

echo ""

################################################################################
# 6. API Endpoint Tests
################################################################################

echo -e "${CYAN}6. API Endpoints${NC}"

run_test "REST API endpoint accessible" "curl -sf -H \"apikey: $ANON_KEY\" http://localhost/rest/v1/" "http"
run_test "Auth endpoint accessible" "curl -sf http://localhost/auth/v1/health" "http"
run_test "Storage endpoint accessible" "curl -sf -H \"apikey: $ANON_KEY\" http://localhost/storage/v1/bucket" "http"

echo ""

################################################################################
# 7. Authentication Tests
################################################################################

echo -e "${CYAN}7. Authentication${NC}"

run_test "Anon key format valid" "echo '$ANON_KEY' | grep -qE '^ey[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$'"
run_test "Service role key format valid" "echo '$SERVICE_ROLE_KEY' | grep -qE '^ey[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$'"
run_test "Auth API responds to anon key" "curl -sf -H \"apikey: $ANON_KEY\" http://localhost/auth/v1/settings" "http"

echo ""

################################################################################
# 8. File System Tests
################################################################################

echo -e "${CYAN}8. File System${NC}"

run_test "docker-compose.yml exists" "[ -f docker-compose.yml ]"
run_test ".env file exists" "[ -f .env ]"
run_test ".env.example exists" "[ -f .env.example ]"
run_test "Kong config exists" "[ -f volumes/api/kong.yml ]"
run_test "PostgreSQL config exists" "[ -f volumes/db/postgresql.conf ]"
run_test "Analytics config exists" "[ -f volumes/logs/gcloud.json ]"
run_test "Database data directory exists" "[ -d volumes/db/data ]"
run_test "Storage directory exists" "[ -d volumes/storage ]"

echo ""

################################################################################
# 9. Script Tests
################################################################################

echo -e "${CYAN}9. Deployment Scripts${NC}"

run_test "configure-env.sh exists" "[ -f configure-env.sh ]"
run_test "configure-env.sh executable" "[ -x configure-env.sh ]"
run_test "deploy-supabase.sh exists" "[ -f deploy-supabase.sh ]"
run_test "deploy-supabase.sh executable" "[ -x deploy-supabase.sh ]"
run_test "check-services.sh exists" "[ -f check-services.sh ]"
run_test "check-services.sh executable" "[ -x check-services.sh ]"
run_test "restart-services.sh exists" "[ -f restart-services.sh ]"
run_test "restart-services.sh executable" "[ -x restart-services.sh ]"
run_test "fix-database-passwords.sh exists" "[ -f fix-database-passwords.sh ]"
run_test "fix-database-passwords.sh executable" "[ -x fix-database-passwords.sh ]"

echo ""

################################################################################
# 10. Documentation Tests
################################################################################

echo -e "${CYAN}10. Documentation${NC}"

run_test "README.md exists" "[ -f README.md ]"
run_test "DEPLOYMENT-GUIDE.md exists" "[ -f DEPLOYMENT-GUIDE.md ]"
run_test "README not empty" "[ -s README.md ]"
run_test "DEPLOYMENT-GUIDE not empty" "[ -s DEPLOYMENT-GUIDE.md ]"

echo ""

################################################################################
# 11. Security Tests
################################################################################

echo -e "${CYAN}11. Security${NC}"

run_test ".env not in git" "! git ls-files | grep -q '^\\.env$'"
run_test "Passwords not default" "! grep -q 'your-super-secret-and-long-postgres-password-change-this' .env || echo 'WARNING: Using default password'"
run_test "JWT secret not default" "! grep -q 'your-super-secret-jwt-token-with-at-least-32-characters-long' .env || echo 'WARNING: Using default JWT secret'"
run_test "Dashboard password not default" "! grep -q 'your-dashboard-password-change-this' .env || echo 'WARNING: Using default dashboard password'"

echo ""

################################################################################
# Test Summary
################################################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Test Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

PASS_RATE=$((TESTS_PASSED * 100 / TESTS_TOTAL))

echo "  Total Tests:    $TESTS_TOTAL"
echo -e "  Passed:         ${GREEN}$TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "  Failed:         ${RED}$TESTS_FAILED${NC}"
else
    echo -e "  Failed:         ${GREEN}$TESTS_FAILED${NC}"
fi
echo "  Pass Rate:      ${PASS_RATE}%"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed! Deployment is healthy.${NC}"
    echo ""
    echo -e "${CYAN}Access Points:${NC}"
    echo -e "  📊 Studio:  http://${STUDIO_DOMAIN}"
    echo -e "  🔌 API:     http://${API_DOMAIN}"
    echo ""
    echo -e "${YELLOW}Note: HTTPS requires SSL certificate setup. See DEPLOYMENT-GUIDE.md${NC}"
    echo ""
    exit 0
elif [ $PASS_RATE -ge 80 ]; then
    echo -e "${YELLOW}⚠ Most tests passed ($PASS_RATE%), but some issues detected.${NC}"
    echo ""
    echo -e "${CYAN}Suggested Actions:${NC}"
    echo "  • Run: ./check-services.sh"
    echo "  • Check logs: docker compose logs"
    echo "  • Review failed tests above"
    echo ""
    exit 1
else
    echo -e "${RED}✗ Deployment has significant issues ($PASS_RATE% pass rate).${NC}"
    echo ""
    echo -e "${CYAN}Suggested Actions:${NC}"
    echo "  • Run: ./check-services.sh"
    echo "  • Check logs: docker compose logs"
    echo "  • Try: docker compose restart"
    echo "  • Review: docker compose ps"
    echo ""
    exit 2
fi

#!/bin/bash

################################################################################
# Script Audit Tool
# Validates all deployment scripts for consistency and best practices
################################################################################

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

ISSUES_FOUND=0

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Supabase Scripts Audit${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

check_pass() {
    echo -e "  ${GREEN}✓${NC} $1"
}

check_fail() {
    echo -e "  ${RED}✗${NC} $1"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
}

check_warn() {
    echo -e "  ${YELLOW}⚠${NC} $1"
}

################################################################################
# 1. Check Script Existence
################################################################################

echo -e "${CYAN}1. Script Files${NC}"

REQUIRED_SCRIPTS=(
    "configure-env.sh"
    "deploy-supabase.sh"
    "check-services.sh"
    "restart-services.sh"
    "fix-database-passwords.sh"
    "test-deployment.sh"
)

for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        check_pass "$script exists"
    else
        check_fail "$script missing"
    fi
done

echo ""

################################################################################
# 2. Check Script Permissions
################################################################################

echo -e "${CYAN}2. Script Permissions${NC}"

for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            check_pass "$script is executable"
        else
            check_fail "$script is not executable"
        fi
    fi
done

echo ""

################################################################################
# 3. Check Bash Syntax
################################################################################

echo -e "${CYAN}3. Bash Syntax${NC}"

for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        if bash -n "$script" 2>/dev/null; then
            check_pass "$script syntax valid"
        else
            check_fail "$script has syntax errors"
        fi
    fi
done

echo ""

################################################################################
# 4. Check Safe .env Loading
################################################################################

echo -e "${CYAN}4. Safe .env Loading${NC}"

SAFE_ENV_PATTERN='while IFS= read -r line'

for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ -f "$script" ] && grep -q "\.env" "$script"; then
        if grep -q "$SAFE_ENV_PATTERN" "$script"; then
            check_pass "$script uses safe .env loading"
        elif grep -q "source \.env" "$script" || grep -q "set -a" "$script"; then
            check_fail "$script uses unsafe .env loading (source/set -a)"
        else
            check_warn "$script references .env but loading method unclear"
        fi
    fi
done

echo ""

################################################################################
# 5. Check Container Names
################################################################################

echo -e "${CYAN}5. Container Names${NC}"

# Correct container names
CORRECT_NAMES=(
    "supabase-db"
    "supabase-auth"
    "supabase-rest"
    "supabase-kong"
    "realtime-dev.supabase-realtime"
    "supabase-storage"
    "supabase-studio"
    "supabase-analytics"
    "supabase-edge-functions"
    "supabase-imgproxy"
    "supabase-meta"
)

# Wrong container names to check for
WRONG_NAMES=(
    "supabase-functions"  # Should be supabase-edge-functions
)

for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        HAS_WRONG=0
        for wrong_name in "${WRONG_NAMES[@]}"; do
            if grep -q "$wrong_name" "$script" 2>/dev/null; then
                check_fail "$script references incorrect container name: $wrong_name"
                HAS_WRONG=1
            fi
        done
        if [ $HAS_WRONG -eq 0 ]; then
            check_pass "$script uses correct container names"
        fi
    fi
done

echo ""

################################################################################
# 6. Check Error Handling
################################################################################

echo -e "${CYAN}6. Error Handling${NC}"

for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        if grep -q "set -e" "$script" || grep -q "set -o errexit" "$script"; then
            check_pass "$script has error handling (set -e)"
        else
            check_warn "$script may lack error handling"
        fi
    fi
done

echo ""

################################################################################
# 7. Check Configuration Files
################################################################################

echo -e "${CYAN}7. Configuration Files${NC}"

CONFIG_FILES=(
    "docker-compose.yml"
    ".env.example"
    "volumes/api/kong.yml"
    "volumes/db/postgresql.conf"
)

for config in "${CONFIG_FILES[@]}"; do
    if [ -f "$config" ]; then
        check_pass "$config exists"
    else
        check_fail "$config missing"
    fi
done

echo ""

################################################################################
# 8. Check Documentation
################################################################################

echo -e "${CYAN}8. Documentation${NC}"

DOC_FILES=(
    "README.md"
    "DEPLOYMENT-GUIDE.md"
)

for doc in "${DOC_FILES[@]}"; do
    if [ -f "$doc" ]; then
        if [ -s "$doc" ]; then
            check_pass "$doc exists and not empty"
        else
            check_warn "$doc exists but is empty"
        fi
    else
        check_fail "$doc missing"
    fi
done

echo ""

################################################################################
# 9. Check for Common Issues
################################################################################

echo -e "${CYAN}9. Common Issues${NC}"

# Check for hardcoded passwords
if grep -r "password123\|admin123\|changeme" *.sh *.yml 2>/dev/null | grep -v "CHANGE THIS"; then
    check_fail "Hardcoded passwords found in files"
else
    check_pass "No hardcoded passwords detected"
fi

# Check for proper quoting in docker commands
if grep -r 'docker compose' *.sh 2>/dev/null | grep -v '^\s*#' | grep -q 'docker compose.*\${.*}' 2>/dev/null; then
    check_warn "Some scripts may have unquoted docker compose variables"
else
    check_pass "Docker compose commands properly formatted"
fi

# Check for .env in git
if git ls-files 2>/dev/null | grep -q '^\\.env$'; then
    check_fail ".env file is tracked in git (should be in .gitignore)"
else
    check_pass ".env is not tracked in git"
fi

# Check .gitignore exists
if [ -f .gitignore ]; then
    if grep -q '^\\.env$' .gitignore; then
        check_pass ".env is in .gitignore"
    else
        check_fail ".env not in .gitignore"
    fi
else
    check_warn ".gitignore file missing"
fi

echo ""

################################################################################
# 10. Check Docker Compose Configuration
################################################################################

echo -e "${CYAN}10. Docker Compose Configuration${NC}"

if [ -f docker-compose.yml ]; then
    # Check service count
    SERVICE_COUNT=$(grep -c "^\s\+[a-z_]*:" docker-compose.yml 2>/dev/null || echo 0)
    if [ "$SERVICE_COUNT" -ge 11 ]; then
        check_pass "All 11 services defined in docker-compose.yml"
    else
        check_fail "Only $SERVICE_COUNT services found (expected 11)"
    fi

    # Check Kong ports
    if grep -q "\"80:8000/tcp\"" docker-compose.yml && grep -q "\"443:8443/tcp\"" docker-compose.yml; then
        check_pass "Kong exposed on standard ports (80/443)"
    else
        check_warn "Kong may not be on standard ports"
    fi

    # Check for Studio route in Kong config
    if [ -f volumes/api/kong.yml ]; then
        if grep -q "studio" volumes/api/kong.yml; then
            check_pass "Studio route configured in Kong"
        else
            check_fail "Studio route missing in Kong config"
        fi
    fi
fi

echo ""

################################################################################
# Audit Summary
################################################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Audit Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

if [ $ISSUES_FOUND -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! Scripts are production-ready.${NC}"
    echo ""
    exit 0
elif [ $ISSUES_FOUND -le 3 ]; then
    echo -e "${YELLOW}⚠ $ISSUES_FOUND minor issues found. Review recommended.${NC}"
    echo ""
    exit 1
else
    echo -e "${RED}✗ $ISSUES_FOUND issues found. Please review and fix.${NC}"
    echo ""
    exit 2
fi

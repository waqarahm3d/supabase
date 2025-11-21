#!/bin/bash

# JWT Keys Test Script
# Quick test to verify JWT keys are loaded correctly

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   JWT Keys Diagnostic${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Load .env
echo -e "${YELLOW}Loading .env file...${NC}"
if [ -f .env ]; then
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        [[ ! "$line" =~ = ]] && continue
        key="${line%%=*}"
        value="${line#*=}"
        key=$(echo "$key" | xargs)
        export "$key=$value"
    done < .env
    echo -e "${GREEN}✓ .env loaded${NC}"
else
    echo -e "${RED}✗ .env file not found${NC}"
    exit 1
fi
echo ""

# Check ANON_KEY
echo -e "${YELLOW}Checking ANON_KEY...${NC}"
if [ -z "$ANON_KEY" ]; then
    echo -e "${RED}✗ ANON_KEY not set${NC}"
else
    echo -e "${GREEN}✓ ANON_KEY is set${NC}"
    echo "Length: ${#ANON_KEY} characters"
    echo "First 50 chars: ${ANON_KEY:0:50}..."

    # Test format
    if echo "$ANON_KEY" | grep -qE '^ey[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$'; then
        echo -e "${GREEN}✓ ANON_KEY format valid (JWT)${NC}"
    else
        echo -e "${RED}✗ ANON_KEY format invalid${NC}"
        echo "Full value: $ANON_KEY"
    fi

    # Check if it's the demo key
    if echo "$ANON_KEY" | grep -q "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24i"; then
        echo -e "${YELLOW}⚠ WARNING: Using Supabase demo ANON_KEY${NC}"
        echo "This is insecure for production! Run ./configure-env.sh to generate new keys"
    fi
fi
echo ""

# Check SERVICE_ROLE_KEY
echo -e "${YELLOW}Checking SERVICE_ROLE_KEY...${NC}"
if [ -z "$SERVICE_ROLE_KEY" ]; then
    echo -e "${RED}✗ SERVICE_ROLE_KEY not set${NC}"
else
    echo -e "${GREEN}✓ SERVICE_ROLE_KEY is set${NC}"
    echo "Length: ${#SERVICE_ROLE_KEY} characters"
    echo "First 50 chars: ${SERVICE_ROLE_KEY:0:50}..."

    # Test format
    if echo "$SERVICE_ROLE_KEY" | grep -qE '^ey[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$'; then
        echo -e "${GREEN}✓ SERVICE_ROLE_KEY format valid (JWT)${NC}"
    else
        echo -e "${RED}✗ SERVICE_ROLE_KEY format invalid${NC}"
        echo "Full value: $SERVICE_ROLE_KEY"
    fi

    # Check if it's the demo key
    if echo "$SERVICE_ROLE_KEY" | grep -q "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSI"; then
        echo -e "${YELLOW}⚠ WARNING: Using Supabase demo SERVICE_ROLE_KEY${NC}"
        echo "This is insecure for production! Run ./configure-env.sh to generate new keys"
    fi
fi
echo ""

# Check alias keys
echo -e "${YELLOW}Checking SUPABASE_ANON_KEY (Kong alias)...${NC}"
if [ -z "$SUPABASE_ANON_KEY" ]; then
    echo -e "${RED}✗ SUPABASE_ANON_KEY not set${NC}"
else
    echo -e "${GREEN}✓ SUPABASE_ANON_KEY is set${NC}"
    if [ "$SUPABASE_ANON_KEY" == "$ANON_KEY" ]; then
        echo -e "${GREEN}✓ Matches ANON_KEY (correct)${NC}"
    else
        echo -e "${YELLOW}⚠ Different from ANON_KEY${NC}"
    fi
fi
echo ""

echo -e "${YELLOW}Checking SUPABASE_SERVICE_KEY (Kong alias)...${NC}"
if [ -z "$SUPABASE_SERVICE_KEY" ]; then
    echo -e "${RED}✗ SUPABASE_SERVICE_KEY not set${NC}"
else
    echo -e "${GREEN}✓ SUPABASE_SERVICE_KEY is set${NC}"
    if [ "$SUPABASE_SERVICE_KEY" == "$SERVICE_ROLE_KEY" ]; then
        echo -e "${GREEN}✓ Matches SERVICE_ROLE_KEY (correct)${NC}"
    else
        echo -e "${YELLOW}⚠ Different from SERVICE_ROLE_KEY${NC}"
    fi
fi
echo ""

# Check JWT_SECRET
echo -e "${YELLOW}Checking JWT_SECRET...${NC}"
if [ -z "$JWT_SECRET" ]; then
    echo -e "${RED}✗ JWT_SECRET not set${NC}"
else
    echo -e "${GREEN}✓ JWT_SECRET is set${NC}"
    echo "Length: ${#JWT_SECRET} characters"

    if [ ${#JWT_SECRET} -lt 32 ]; then
        echo -e "${YELLOW}⚠ WARNING: JWT_SECRET is less than 32 characters${NC}"
    else
        echo -e "${GREEN}✓ JWT_SECRET length adequate${NC}"
    fi

    # Check if it's the demo secret
    if echo "$JWT_SECRET" | grep -q "your-super-secret-jwt-token-with-at-least-32-characters-long"; then
        echo -e "${RED}✗ CRITICAL: Using default JWT_SECRET!${NC}"
        echo "Run ./configure-env.sh immediately to generate a secure secret"
    fi
fi
echo ""

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

ISSUES=0

# Summary checks
if [ -z "$ANON_KEY" ] || ! echo "$ANON_KEY" | grep -qE '^ey[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$'; then
    echo -e "${RED}✗ ANON_KEY issue detected${NC}"
    ISSUES=$((ISSUES + 1))
fi

if [ -z "$SERVICE_ROLE_KEY" ] || ! echo "$SERVICE_ROLE_KEY" | grep -qE '^ey[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$'; then
    echo -e "${RED}✗ SERVICE_ROLE_KEY issue detected${NC}"
    ISSUES=$((ISSUES + 1))
fi

if [ -z "$SUPABASE_ANON_KEY" ]; then
    echo -e "${RED}✗ SUPABASE_ANON_KEY not set (Kong will have issues)${NC}"
    ISSUES=$((ISSUES + 1))
fi

if [ -z "$SUPABASE_SERVICE_KEY" ]; then
    echo -e "${RED}✗ SUPABASE_SERVICE_KEY not set (Kong will have issues)${NC}"
    ISSUES=$((ISSUES + 1))
fi

# Check for demo keys
if echo "$ANON_KEY" | grep -q "supabase-demo"; then
    echo -e "${YELLOW}⚠ Using Supabase demo keys (security risk)${NC}"
    ISSUES=$((ISSUES + 1))
fi

if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✓✓✓ All JWT keys configured correctly${NC}"
    echo ""
    echo "Your JWT keys are valid and properly configured."
else
    echo -e "${RED}Found $ISSUES issue(s) with JWT configuration${NC}"
    echo ""
    echo "Recommended action:"
    echo "  ./configure-env.sh    # Generate new secure keys"
    echo "  docker compose up -d  # Apply changes"
fi

echo ""

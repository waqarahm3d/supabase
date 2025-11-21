#!/bin/bash

################################################################################
# Supabase Environment Configuration Wizard
# Interactive setup for .env file
################################################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Supabase Self-Hosted Configuration Wizard${NC}"
echo -e "${BLUE}   Expert Setup - Production Ready${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Check if .env already exists
if [ -f .env ]; then
    echo -e "${YELLOW}Warning: .env file already exists!${NC}"
    read -p "Do you want to overwrite it? (yes/no): " OVERWRITE
    if [ "$OVERWRITE" != "yes" ]; then
        echo "Exiting without changes."
        exit 0
    fi
    # Backup existing .env
    cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
    echo -e "${GREEN}Existing .env backed up${NC}"
fi

echo ""
echo -e "${CYAN}This wizard will help you configure your Supabase instance.${NC}"
echo -e "${CYAN}Press Enter to use default values shown in [brackets].${NC}"
echo ""

################################################################################
# Domain Configuration
################################################################################

echo -e "${BLUE}━━━ Domain Configuration ━━━${NC}"
echo ""

read -p "Enter your API domain (e.g., api.yourdomain.com) [db.qoqnuz.com]: " API_DOMAIN
API_DOMAIN=${API_DOMAIN:-db.qoqnuz.com}

read -p "Enter your Studio domain (e.g., studio.yourdomain.com) [studio.qoqnuz.com]: " STUDIO_DOMAIN
STUDIO_DOMAIN=${STUDIO_DOMAIN:-studio.qoqnuz.com}

read -p "Enter your main application URL (e.g., https://app.yourdomain.com) [https://studio.qoqnuz.com]: " SITE_URL
SITE_URL=${SITE_URL:-https://studio.qoqnuz.com}

################################################################################
# Generate Secure Secrets
################################################################################

echo ""
echo -e "${BLUE}━━━ Generating Secure Secrets ━━━${NC}"
echo ""

echo -e "${CYAN}Generating secure random passwords and keys...${NC}"

# Generate secure random values
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
JWT_SECRET=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
DASHBOARD_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-24)
LOGFLARE_API_KEY=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)

echo -e "${GREEN}✓ PostgreSQL password generated${NC}"
echo -e "${GREEN}✓ JWT secret generated${NC}"
echo -e "${GREEN}✓ Dashboard password generated${NC}"
echo -e "${GREEN}✓ Logflare API key generated${NC}"

# Ask if user wants to customize dashboard credentials
echo ""
read -p "Dashboard username [supabase]: " DASHBOARD_USERNAME
DASHBOARD_USERNAME=${DASHBOARD_USERNAME:-supabase}

read -p "Use auto-generated dashboard password? (yes/no) [yes]: " USE_AUTO_PASS
USE_AUTO_PASS=${USE_AUTO_PASS:-yes}

if [ "$USE_AUTO_PASS" != "yes" ]; then
    read -sp "Enter dashboard password: " CUSTOM_DASHBOARD_PASSWORD
    echo ""
    read -sp "Confirm dashboard password: " CUSTOM_DASHBOARD_PASSWORD_CONFIRM
    echo ""

    if [ "$CUSTOM_DASHBOARD_PASSWORD" == "$CUSTOM_DASHBOARD_PASSWORD_CONFIRM" ]; then
        DASHBOARD_PASSWORD="$CUSTOM_DASHBOARD_PASSWORD"
        echo -e "${GREEN}✓ Custom dashboard password set${NC}"
    else
        echo -e "${RED}Passwords don't match. Using auto-generated password.${NC}"
    fi
fi

################################################################################
# Generate JWT Tokens
################################################################################

echo ""
echo -e "${CYAN}Generating JWT tokens...${NC}"

# Generate anon key (role: anon, never expires)
ANON_PAYLOAD=$(echo -n '{"role":"anon","iss":"supabase","iat":1700000000,"exp":2000000000}' | base64 | tr -d '=' | tr '+/' '-_')
ANON_HEADER=$(echo -n '{"alg":"HS256","typ":"JWT"}' | base64 | tr -d '=' | tr '+/' '-_')
ANON_SIGNATURE=$(echo -n "${ANON_HEADER}.${ANON_PAYLOAD}" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | base64 | tr -d '=' | tr '+/' '-_')
ANON_KEY="${ANON_HEADER}.${ANON_PAYLOAD}.${ANON_SIGNATURE}"

# Generate service_role key (role: service_role, never expires)
SERVICE_PAYLOAD=$(echo -n '{"role":"service_role","iss":"supabase","iat":1700000000,"exp":2000000000}' | base64 | tr -d '=' | tr '+/' '-_')
SERVICE_HEADER=$(echo -n '{"alg":"HS256","typ":"JWT"}' | base64 | tr -d '=' | tr '+/' '-_')
SERVICE_SIGNATURE=$(echo -n "${SERVICE_HEADER}.${SERVICE_PAYLOAD}" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | base64 | tr -d '=' | tr '+/' '-_')
SERVICE_ROLE_KEY="${SERVICE_HEADER}.${SERVICE_PAYLOAD}.${SERVICE_SIGNATURE}"

echo -e "${GREEN}✓ Anon key generated${NC}"
echo -e "${GREEN}✓ Service role key generated${NC}"

################################################################################
# Email Configuration
################################################################################

echo ""
echo -e "${BLUE}━━━ Email Configuration ━━━${NC}"
echo ""

read -p "Enable email signup? (true/false) [true]: " ENABLE_EMAIL_SIGNUP
ENABLE_EMAIL_SIGNUP=${ENABLE_EMAIL_SIGNUP:-true}

read -p "Auto-confirm email signups (skip verification)? (true/false) [false]: " ENABLE_EMAIL_AUTOCONFIRM
ENABLE_EMAIL_AUTOCONFIRM=${ENABLE_EMAIL_AUTOCONFIRM:-false}

read -p "Admin email address [admin@${API_DOMAIN}]: " SMTP_ADMIN_EMAIL
SMTP_ADMIN_EMAIL=${SMTP_ADMIN_EMAIL:-admin@${API_DOMAIN}}

echo ""
echo -e "${CYAN}SMTP Configuration (press Enter to skip):${NC}"
read -p "SMTP Host [smtp.gmail.com]: " SMTP_HOST
SMTP_HOST=${SMTP_HOST:-smtp.gmail.com}

read -p "SMTP Port [587]: " SMTP_PORT
SMTP_PORT=${SMTP_PORT:-587}

read -p "SMTP User: " SMTP_USER
read -sp "SMTP Password: " SMTP_PASS
echo ""

read -p "SMTP Sender Name [Supabase]: " SMTP_SENDER_NAME
SMTP_SENDER_NAME=${SMTP_SENDER_NAME:-Supabase}

################################################################################
# Additional Settings
################################################################################

echo ""
echo -e "${BLUE}━━━ Additional Settings ━━━${NC}"
echo ""

read -p "Disable public signups? (true/false) [false]: " DISABLE_SIGNUP
DISABLE_SIGNUP=${DISABLE_SIGNUP:-false}

read -p "JWT expiry in seconds [3600]: " JWT_EXPIRY
JWT_EXPIRY=${JWT_EXPIRY:-3600}

read -p "Studio default organization name [Default Organization]: " STUDIO_DEFAULT_ORGANIZATION
STUDIO_DEFAULT_ORGANIZATION=${STUDIO_DEFAULT_ORGANIZATION:-Default Organization}

read -p "Studio default project name [Default Project]: " STUDIO_DEFAULT_PROJECT
STUDIO_DEFAULT_PROJECT=${STUDIO_DEFAULT_PROJECT:-Default Project}

################################################################################
# Create .env File
################################################################################

echo ""
echo -e "${CYAN}Creating .env file...${NC}"

cat > .env << EOF
############
# DOMAINS
############
API_DOMAIN=${API_DOMAIN}
STUDIO_DOMAIN=${STUDIO_DOMAIN}

############
# SECRETS
############
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
JWT_SECRET=${JWT_SECRET}
ANON_KEY=${ANON_KEY}
SERVICE_ROLE_KEY=${SERVICE_ROLE_KEY}
DASHBOARD_USERNAME=${DASHBOARD_USERNAME}
DASHBOARD_PASSWORD=${DASHBOARD_PASSWORD}
LOGFLARE_API_KEY=${LOGFLARE_API_KEY}

############
# DATABASE
############
POSTGRES_HOST=db
POSTGRES_DB=postgres
POSTGRES_PORT=5432
PGRST_DB_SCHEMAS=public,storage,graphql_public

############
# API SETTINGS
############
JWT_EXPIRY=${JWT_EXPIRY}
SITE_URL=${SITE_URL}
ADDITIONAL_REDIRECT_URLS=
DISABLE_SIGNUP=${DISABLE_SIGNUP}

############
# EMAIL
############
ENABLE_EMAIL_SIGNUP=${ENABLE_EMAIL_SIGNUP}
ENABLE_EMAIL_AUTOCONFIRM=${ENABLE_EMAIL_AUTOCONFIRM}
SMTP_ADMIN_EMAIL=${SMTP_ADMIN_EMAIL}
SMTP_HOST=${SMTP_HOST}
SMTP_PORT=${SMTP_PORT}
SMTP_USER=${SMTP_USER}
SMTP_PASS=${SMTP_PASS}
SMTP_SENDER_NAME=${SMTP_SENDER_NAME}

############
# PHONE
############
ENABLE_PHONE_SIGNUP=false
ENABLE_PHONE_AUTOCONFIRM=false

############
# STUDIO
############
STUDIO_DEFAULT_ORGANIZATION=${STUDIO_DEFAULT_ORGANIZATION}
STUDIO_DEFAULT_PROJECT=${STUDIO_DEFAULT_PROJECT}

############
# FUNCTIONS
############
FUNCTIONS_VERIFY_JWT=false

############
# KONG
############
KONG_HTTP_PORT=8000
KONG_HTTPS_PORT=8443

############
# IMAGE PROXY
############
IMGPROXY_ENABLE_WEBP_DETECTION=true

############
# MISC
############
DOCKER_SOCKET_LOCATION=/var/run/docker.sock
EOF

chmod 600 .env

echo -e "${GREEN}✓ .env file created successfully${NC}"

################################################################################
# Display Summary
################################################################################

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Configuration Complete!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}Your Supabase configuration:${NC}"
echo ""
echo -e "  🌐 API Domain:        ${GREEN}${API_DOMAIN}${NC}"
echo -e "  🖥️  Studio Domain:     ${GREEN}${STUDIO_DOMAIN}${NC}"
echo -e "  👤 Dashboard User:    ${GREEN}${DASHBOARD_USERNAME}${NC}"
echo -e "  🔑 Dashboard Pass:    ${GREEN}${DASHBOARD_PASSWORD}${NC}"
echo ""
echo -e "${YELLOW}IMPORTANT: Save your credentials securely!${NC}"
echo ""
echo -e "  Dashboard Password: ${GREEN}${DASHBOARD_PASSWORD}${NC}"
echo -e "  Postgres Password:  ${GREEN}${POSTGRES_PASSWORD}${NC}"
echo -e "  Anon Key:          ${GREEN}${ANON_KEY:0:30}...${NC}"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo "  1. Ensure your DNS records point to this server:"
echo "     ${API_DOMAIN} -> $(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP')"
echo "     ${STUDIO_DOMAIN} -> $(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP')"
echo ""
echo "  2. Run the deployment script:"
echo "     ${GREEN}sudo ./deploy-supabase.sh${NC}"
echo ""
echo "  3. After deployment, access Studio at:"
echo "     ${GREEN}http://${STUDIO_DOMAIN}:8000${NC}"
echo ""
echo -e "${YELLOW}Note: Credentials have been saved to .env${NC}"
echo -e "${YELLOW}This file is gitignored and contains sensitive data.${NC}"
echo ""

# Save credentials to a separate file
CREDS_FILE=".credentials-$(date +%Y%m%d_%H%M%S).txt"
cat > "$CREDS_FILE" << EOF
Supabase Self-Hosted Credentials
Generated: $(date)

API Domain: ${API_DOMAIN}
Studio Domain: ${STUDIO_DOMAIN}
Site URL: ${SITE_URL}

Dashboard Username: ${DASHBOARD_USERNAME}
Dashboard Password: ${DASHBOARD_PASSWORD}

PostgreSQL Password: ${POSTGRES_PASSWORD}

JWT Secret: ${JWT_SECRET}

Anon Key: ${ANON_KEY}

Service Role Key: ${SERVICE_ROLE_KEY}

Logflare API Key: ${LOGFLARE_API_KEY}

IMPORTANT: Store this file securely and delete it after backing up!
EOF

chmod 600 "$CREDS_FILE"

echo -e "${GREEN}✓ Credentials also saved to: ${CREDS_FILE}${NC}"
echo -e "${YELLOW}  Please backup this file and delete it from the server!${NC}"
echo ""

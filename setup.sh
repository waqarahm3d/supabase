#!/bin/bash

# Supabase Self-Hosted Setup Script
# Optimized for 4GB RAM / 2 CPU servers
# Domains: db.qoqnuz.com (API) and studio.qoqnuz.com (Studio)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to generate secure random strings
generate_secret() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

# Function to generate JWT tokens
generate_jwt() {
    local secret=$1
    local role=$2
    local exp=$3

    # Header
    header='{"alg":"HS256","typ":"JWT"}'
    header_b64=$(echo -n "$header" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

    # Payload
    payload="{\"iss\":\"supabase\",\"role\":\"$role\",\"exp\":$exp}"
    payload_b64=$(echo -n "$payload" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

    # Signature
    signature=$(echo -n "${header_b64}.${payload_b64}" | openssl dgst -sha256 -hmac "$secret" -binary | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

    echo "${header_b64}.${payload_b64}.${signature}"
}

# Print banner
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║         Supabase Self-Hosted Setup Script                    ║"
echo "║         Optimized for 4GB RAM / 2 CPU                        ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run this script as root or with sudo"
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

print_info "All prerequisites are installed."

# Check if .env file already exists
if [ -f .env ]; then
    print_warning ".env file already exists."
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Keeping existing .env file."
        USE_EXISTING_ENV=true
    else
        USE_EXISTING_ENV=false
    fi
else
    USE_EXISTING_ENV=false
fi

if [ "$USE_EXISTING_ENV" = false ]; then
    print_info "Generating secure secrets and configuration..."

    # Generate secrets
    POSTGRES_PASSWORD=$(generate_secret)
    JWT_SECRET=$(generate_secret)
    DASHBOARD_PASSWORD=$(generate_secret)
    LOGFLARE_API_KEY=$(generate_secret)

    # Generate JWT tokens (expire in 10 years: 2024 + 10 years = ~2034)
    JWT_EXP=2019847200
    ANON_KEY=$(generate_jwt "$JWT_SECRET" "anon" $JWT_EXP)
    SERVICE_ROLE_KEY=$(generate_jwt "$JWT_SECRET" "service_role" $JWT_EXP)

    # Get domain configuration
    print_info "Domain Configuration"
    read -p "Enter your API domain (default: db.qoqnuz.com): " API_DOMAIN
    API_DOMAIN=${API_DOMAIN:-db.qoqnuz.com}

    read -p "Enter your Studio domain (default: studio.qoqnuz.com): " STUDIO_DOMAIN
    STUDIO_DOMAIN=${STUDIO_DOMAIN:-studio.qoqnuz.com}

    # Get site URL
    read -p "Enter your application URL (default: https://$API_DOMAIN): " SITE_URL
    SITE_URL=${SITE_URL:-https://$API_DOMAIN}

    # Get email configuration
    print_info "Email Configuration (optional - press enter to skip)"
    read -p "SMTP Host (e.g., smtp.gmail.com): " SMTP_HOST
    SMTP_HOST=${SMTP_HOST:-smtp.gmail.com}

    read -p "SMTP Port (default: 587): " SMTP_PORT
    SMTP_PORT=${SMTP_PORT:-587}

    read -p "SMTP User: " SMTP_USER
    read -p "SMTP Password: " SMTP_PASS
    read -p "Admin Email: " SMTP_ADMIN_EMAIL
    SMTP_ADMIN_EMAIL=${SMTP_ADMIN_EMAIL:-admin@example.com}

    # Create .env file
    print_info "Creating .env file..."
    cat > .env << EOF
############
# DOMAINS
############
API_DOMAIN=$API_DOMAIN
STUDIO_DOMAIN=$STUDIO_DOMAIN

############
# SECRETS
############
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
JWT_SECRET=$JWT_SECRET
ANON_KEY=$ANON_KEY
SERVICE_ROLE_KEY=$SERVICE_ROLE_KEY
DASHBOARD_USERNAME=supabase
DASHBOARD_PASSWORD=$DASHBOARD_PASSWORD
LOGFLARE_API_KEY=$LOGFLARE_API_KEY

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
JWT_EXPIRY=3600
SITE_URL=$SITE_URL
ADDITIONAL_REDIRECT_URLS=
DISABLE_SIGNUP=false

############
# EMAIL
############
ENABLE_EMAIL_SIGNUP=true
ENABLE_EMAIL_AUTOCONFIRM=false
SMTP_ADMIN_EMAIL=$SMTP_ADMIN_EMAIL
SMTP_HOST=$SMTP_HOST
SMTP_PORT=$SMTP_PORT
SMTP_USER=$SMTP_USER
SMTP_PASS=$SMTP_PASS
SMTP_SENDER_NAME=Supabase

############
# PHONE
############
ENABLE_PHONE_SIGNUP=false
ENABLE_PHONE_AUTOCONFIRM=false

############
# STUDIO
############
STUDIO_DEFAULT_ORGANIZATION=Default Organization
STUDIO_DEFAULT_PROJECT=Default Project

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

    print_success ".env file created successfully!"

    # Update roles.sql with actual password
    print_info "Updating database initialization scripts..."
    sed -i "s/POSTGRES_PASSWORD_PLACEHOLDER/$POSTGRES_PASSWORD/g" volumes/db/roles.sql

fi

# Create necessary directories
print_info "Creating necessary directories..."
mkdir -p volumes/db/data
mkdir -p volumes/storage
mkdir -p volumes/functions/main
mkdir -p volumes/logs
mkdir -p ssl

# Create a simple Edge Function example
if [ ! -f volumes/functions/main/index.ts ]; then
    print_info "Creating example Edge Function..."
    cat > volumes/functions/main/index.ts << 'EOF'
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  return new Response(
    JSON.stringify({ message: "Hello from Supabase Edge Functions!" }),
    { headers: { "Content-Type": "application/json" } },
  )
})
EOF
fi

print_success "Directory structure created!"

# Check Docker system resources
print_info "Checking Docker system..."
docker system df

# Pull images
print_info "Pulling Docker images (this may take a while)..."
docker-compose pull

print_success "All images pulled successfully!"

# Display important information
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║                    Setup Complete!                            ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

if [ "$USE_EXISTING_ENV" = false ]; then
    print_success "Your Supabase instance is configured!"
    echo ""
    print_info "Important Credentials (SAVE THESE SECURELY!):"
    echo ""
    echo "  API Domain:          https://$API_DOMAIN"
    echo "  Studio Domain:       https://$STUDIO_DOMAIN"
    echo "  Dashboard Username:  supabase"
    echo "  Dashboard Password:  $DASHBOARD_PASSWORD"
    echo "  Database Password:   $POSTGRES_PASSWORD"
    echo ""
    echo "  Anon Key:            $ANON_KEY"
    echo "  Service Role Key:    $SERVICE_ROLE_KEY"
    echo ""

    # Save credentials to a file
    cat > credentials.txt << EOF
Supabase Self-Hosted Credentials
Generated on: $(date)

API Domain:          https://$API_DOMAIN
Studio Domain:       https://$STUDIO_DOMAIN
Dashboard Username:  supabase
Dashboard Password:  $DASHBOARD_PASSWORD
Database Password:   $POSTGRES_PASSWORD

Anon Key:            $ANON_KEY
Service Role Key:    $SERVICE_ROLE_KEY

IMPORTANT: Keep this file secure and delete it after saving the credentials elsewhere!
EOF
    chmod 600 credentials.txt
    print_success "Credentials saved to credentials.txt (read-only)"
fi

echo ""
print_warning "Before starting Supabase, please ensure:"
echo "  1. DNS records point db.qoqnuz.com and studio.qoqnuz.com to this server"
echo "  2. SSL certificates are placed in ./ssl/ directory:"
echo "     - ./ssl/db.qoqnuz.com.crt and ./ssl/db.qoqnuz.com.key"
echo "     - ./ssl/studio.qoqnuz.com.crt and ./ssl/studio.qoqnuz.com.key"
echo "  3. Ports 80, 443, 5432 are open in your firewall"
echo ""
print_info "To start Supabase, run:"
echo "  docker-compose up -d"
echo ""
print_info "To view logs:"
echo "  docker-compose logs -f"
echo ""
print_info "To stop Supabase:"
echo "  docker-compose down"
echo ""
print_info "To access Supabase Studio:"
echo "  Open https://studio.qoqnuz.com in your browser"
echo ""

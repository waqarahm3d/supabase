#!/bin/bash

################################################################################
# Supabase Self-Hosted Deployment Script
# Expert Configuration - Production Ready
# Tested on 4GB RAM / 2 CPU Ubuntu VPS
################################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root"
   exit 1
fi

log_info "Starting Supabase Self-Hosted Deployment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

################################################################################
# STEP 1: Check Prerequisites
################################################################################

log_info "Step 1/10: Checking prerequisites..."

# Check if .env file exists
if [ ! -f .env ]; then
    log_error ".env file not found!"
    log_info "Please run ./configure-env.sh first to set up your environment"
    exit 1
fi

# Source the .env file safely
# Read each line and export variables properly
while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    # Skip lines that don't contain =
    [[ ! "$line" =~ = ]] && continue
    # Extract key and value
    key="${line%%=*}"
    value="${line#*=}"
    # Trim whitespace from key
    key=$(echo "$key" | xargs)
    # Export the variable (keeping value as-is to preserve special characters)
    export "$key=$value"
done < .env

# Verify critical environment variables
REQUIRED_VARS=("API_DOMAIN" "STUDIO_DOMAIN" "POSTGRES_PASSWORD" "JWT_SECRET" "ANON_KEY" "SERVICE_ROLE_KEY" "DASHBOARD_PASSWORD")
for VAR in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!VAR}" ]; then
        log_error "Required environment variable $VAR is not set in .env"
        exit 1
    fi
done

log_success "All required environment variables are set"

################################################################################
# STEP 2: System Updates and Security Hardening
################################################################################

log_info "Step 2/10: Updating system packages..."

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq

log_success "System packages updated"

################################################################################
# STEP 3: Install Required Packages
################################################################################

log_info "Step 3/10: Installing required packages..."

apt-get install -y -qq \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    ufw \
    fail2ban \
    unattended-upgrades \
    software-properties-common

log_success "Required packages installed"

################################################################################
# STEP 4: Install Docker
################################################################################

log_info "Step 4/10: Installing Docker..."

# Check if Docker is already installed
if command -v docker &> /dev/null; then
    log_warning "Docker is already installed"
    DOCKER_VERSION=$(docker --version)
    log_info "Current version: $DOCKER_VERSION"
else
    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Add Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Start and enable Docker
    systemctl start docker
    systemctl enable docker

    log_success "Docker installed successfully"
fi

################################################################################
# STEP 5: Configure Firewall
################################################################################

log_info "Step 5/10: Configuring firewall..."

# Detect SSH service name (Ubuntu uses 'ssh', others use 'sshd')
if systemctl list-units --full --all | grep -q "ssh.service"; then
    SSH_SERVICE="ssh"
else
    SSH_SERVICE="sshd"
fi

# Configure UFW
ufw --force disable
ufw --force reset

# Allow SSH
ufw allow OpenSSH

# Allow HTTP and HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Allow Supabase ports (Kong)
ufw allow 8000/tcp  # Kong HTTP
ufw allow 8443/tcp  # Kong HTTPS

# Enable UFW
ufw --force enable

log_success "Firewall configured"

################################################################################
# STEP 6: Configure Fail2ban
################################################################################

log_info "Step 6/10: Configuring Fail2ban..."

systemctl enable fail2ban
systemctl start fail2ban

log_success "Fail2ban configured"

################################################################################
# STEP 7: Prepare Supabase Directories
################################################################################

log_info "Step 7/10: Preparing Supabase directories..."

# Create required directories
mkdir -p volumes/db/data
mkdir -p volumes/db/init
mkdir -p volumes/storage
mkdir -p volumes/functions
mkdir -p volumes/logs

# Set proper permissions
chmod 755 volumes
chmod 700 volumes/db/data

log_success "Directories prepared"

################################################################################
# STEP 8: Generate Analytics Configuration
################################################################################

log_info "Step 8/10: Generating analytics configuration..."

# Generate gcloud.json for analytics
cat > volumes/logs/gcloud.json << 'EOF'
{
  "type": "service_account",
  "project_id": "self-hosted",
  "private_key_id": "self-hosted-key",
  "private_key": "-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQEAyD3X8xBdKqZdR7z8p5kQvC9YdH0pP6qYZmWxGfC3YhH8L0kX\nD8N5QzBvP7yGfLwZ0pK8QvH7y5dL0K9qZ8xB5p6qL0z8H5y6p8K0z9q5L7y8p6qZ\n0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L\n7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p\n5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z\n0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5QIDAQABAoIBABQkH7z8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z\n0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L\n7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p\n5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z\n0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L\n7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p\n5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z\n0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L\nAoGBAO8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L\n7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p\n5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8AoGBA\nNe8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p\n5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z\n0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8p5q6Z0K9L7y8\n-----END RSA PRIVATE KEY-----",
  "client_email": "self-hosted@self-hosted.iam.gserviceaccount.com",
  "client_id": "000000000000000000000",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs"
}
EOF

chmod 644 volumes/logs/gcloud.json

log_success "Analytics configuration generated"

################################################################################
# STEP 9: Deploy Supabase Stack
################################################################################

log_info "Step 9/10: Deploying Supabase stack..."

# Stop any existing containers
if docker compose ps -q 2>/dev/null | grep -q .; then
    log_warning "Stopping existing containers..."
    docker compose down
fi

# Pull latest images
log_info "Pulling Docker images (this may take a few minutes)..."
docker compose pull

# Start services
log_info "Starting Supabase services..."
docker compose up -d

log_success "Supabase stack deployed"

################################################################################
# STEP 10: Wait for Services to be Healthy
################################################################################

log_info "Step 10/10: Waiting for services to become healthy..."

# Wait for database to be ready
log_info "Waiting for database..."
for i in {1..60}; do
    if docker exec supabase-db pg_isready -U postgres &> /dev/null; then
        log_success "Database is ready"
        break
    fi
    if [ $i -eq 60 ]; then
        log_error "Database failed to start within 60 seconds"
        exit 1
    fi
    sleep 1
done

# Wait for Kong to be ready
log_info "Waiting for Kong..."
for i in {1..60}; do
    if docker exec supabase-kong kong health &> /dev/null; then
        log_success "Kong is ready"
        break
    fi
    if [ $i -eq 60 ]; then
        log_error "Kong failed to start within 60 seconds"
        exit 1
    fi
    sleep 1
done

# Wait for Studio to be ready
log_info "Waiting for Studio..."
for i in {1..60}; do
    if curl -s http://localhost:3000/api/profile &> /dev/null; then
        log_success "Studio is ready"
        break
    fi
    if [ $i -eq 60 ]; then
        log_warning "Studio may not be ready yet, but continuing..."
        break
    fi
    sleep 1
done

################################################################################
# Deployment Complete
################################################################################

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_success "Supabase deployment completed successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
log_info "Access your Supabase instance at:"
echo ""
echo "  📊 Studio Dashboard: http://${STUDIO_DOMAIN}:8000"
echo "  🔌 API Endpoint:     http://${API_DOMAIN}:8000"
echo ""
log_info "Your credentials:"
echo ""
echo "  👤 Dashboard Username: ${DASHBOARD_USERNAME}"
echo "  🔑 Dashboard Password: ${DASHBOARD_PASSWORD}"
echo "  🎫 Anon Key:          ${ANON_KEY}"
echo ""
log_warning "IMPORTANT: Save these credentials securely!"
echo ""
log_info "Next steps:"
echo "  1. Configure SSL certificates for HTTPS"
echo "  2. Run ./check-services.sh to verify all services"
echo "  3. Configure your application to use the API endpoint"
echo ""
log_info "For SSL setup, ensure your DNS records point to this server:"
echo "  ${API_DOMAIN} -> $(curl -s ifconfig.me)"
echo "  ${STUDIO_DOMAIN} -> $(curl -s ifconfig.me)"
echo ""

# Run service health check
if [ -f ./check-services.sh ]; then
    log_info "Running service health check..."
    ./check-services.sh
fi

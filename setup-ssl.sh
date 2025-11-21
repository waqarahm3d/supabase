#!/bin/bash

# SSL Certificate Setup Script for Supabase
# Supports both Let's Encrypt (Certbot) and self-signed certificates

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║         SSL Certificate Setup for Supabase                    ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    print_error ".env file not found. Please run ./setup.sh first."
    exit 1
fi

API_DOMAIN=${API_DOMAIN:-db.qoqnuz.com}
STUDIO_DOMAIN=${STUDIO_DOMAIN:-studio.qoqnuz.com}

# Create ssl directory
mkdir -p ssl

echo "SSL Certificate Options:"
echo "1) Let's Encrypt (Free, recommended for production)"
echo "2) Self-signed certificates (For testing only)"
echo ""
read -p "Select an option (1 or 2): " -n 1 -r
echo ""

if [[ $REPLY == "1" ]]; then
    # Let's Encrypt setup
    print_info "Setting up Let's Encrypt certificates..."

    # Check if certbot is installed
    if ! command -v certbot &> /dev/null; then
        print_info "Installing certbot..."
        apt-get update
        apt-get install -y certbot
    fi

    print_warning "Before proceeding, ensure:"
    echo "  1. DNS records for $API_DOMAIN and $STUDIO_DOMAIN point to this server"
    echo "  2. Ports 80 and 443 are open"
    echo "  3. No web server is currently running on port 80"
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Cancelled."
        exit 0
    fi

    # Get email for Let's Encrypt
    read -p "Enter your email address for Let's Encrypt: " LE_EMAIL

    # Get certificates for API domain
    print_info "Requesting certificate for $API_DOMAIN..."
    certbot certonly --standalone -d $API_DOMAIN --email $LE_EMAIL --agree-tos --non-interactive

    # Get certificates for Studio domain
    print_info "Requesting certificate for $STUDIO_DOMAIN..."
    certbot certonly --standalone -d $STUDIO_DOMAIN --email $LE_EMAIL --agree-tos --non-interactive

    # Copy certificates to ssl directory
    print_info "Copying certificates..."
    cp /etc/letsencrypt/live/$API_DOMAIN/fullchain.pem ssl/$API_DOMAIN.crt
    cp /etc/letsencrypt/live/$API_DOMAIN/privkey.pem ssl/$API_DOMAIN.key
    cp /etc/letsencrypt/live/$STUDIO_DOMAIN/fullchain.pem ssl/$STUDIO_DOMAIN.crt
    cp /etc/letsencrypt/live/$STUDIO_DOMAIN/privkey.pem ssl/$STUDIO_DOMAIN.key

    # Set proper permissions
    chmod 644 ssl/*.crt
    chmod 600 ssl/*.key

    print_success "Let's Encrypt certificates installed successfully!"

    # Set up auto-renewal
    print_info "Setting up automatic certificate renewal..."
    cat > /etc/cron.daily/renew-supabase-certs << 'EOFCRON'
#!/bin/bash
certbot renew --quiet --deploy-hook "
    cp /etc/letsencrypt/live/db.qoqnuz.com/fullchain.pem /home/user/supabase/ssl/db.qoqnuz.com.crt
    cp /etc/letsencrypt/live/db.qoqnuz.com/privkey.pem /home/user/supabase/ssl/db.qoqnuz.com.key
    cp /etc/letsencrypt/live/studio.qoqnuz.com/fullchain.pem /home/user/supabase/ssl/studio.qoqnuz.com.crt
    cp /etc/letsencrypt/live/studio.qoqnuz.com/privkey.pem /home/user/supabase/ssl/studio.qoqnuz.com.key
    docker restart nginx
"
EOFCRON
    chmod +x /etc/cron.daily/renew-supabase-certs
    print_success "Auto-renewal configured!"

elif [[ $REPLY == "2" ]]; then
    # Self-signed certificates
    print_warning "Creating self-signed certificates (NOT for production use)..."

    # Generate self-signed certificate for API domain
    print_info "Generating certificate for $API_DOMAIN..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout ssl/$API_DOMAIN.key \
        -out ssl/$API_DOMAIN.crt \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=$API_DOMAIN"

    # Generate self-signed certificate for Studio domain
    print_info "Generating certificate for $STUDIO_DOMAIN..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout ssl/$STUDIO_DOMAIN.key \
        -out ssl/$STUDIO_DOMAIN.crt \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=$STUDIO_DOMAIN"

    # Set proper permissions
    chmod 644 ssl/*.crt
    chmod 600 ssl/*.key

    print_success "Self-signed certificates created!"
    print_warning "Remember: Self-signed certificates will show security warnings in browsers."

else
    print_error "Invalid option selected."
    exit 1
fi

echo ""
print_success "SSL setup complete!"
echo ""
print_info "Certificate locations:"
echo "  $API_DOMAIN:"
echo "    - Certificate: ssl/$API_DOMAIN.crt"
echo "    - Private Key: ssl/$API_DOMAIN.key"
echo ""
echo "  $STUDIO_DOMAIN:"
echo "    - Certificate: ssl/$STUDIO_DOMAIN.crt"
echo "    - Private Key: ssl/$STUDIO_DOMAIN.key"
echo ""
print_info "Next steps:"
echo "  1. Review nginx.conf to ensure SSL paths are correct"
echo "  2. Start Supabase with: ./start.sh"
echo "  3. Access Studio at: https://$STUDIO_DOMAIN"
echo ""

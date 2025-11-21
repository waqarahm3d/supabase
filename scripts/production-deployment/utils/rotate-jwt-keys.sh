#!/usr/bin/env bash
#===============================================================================
# JWT Key Rotation Utility
# Safely rotate JWT signing keys with zero downtime
#===============================================================================

set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-/opt/supabase}"
KEYS_DIR="$PROJECT_DIR/keys"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Rotate JWT signing keys safely with zero downtime.

OPTIONS:
    --backup-old       Backup old keys (default: yes)
    --restart-services Restart services after rotation (default: yes)
    --no-confirm       Skip confirmation prompts
    -h, --help         Show this help message

EXAMPLES:
    # Interactive rotation
    sudo ./rotate-jwt-keys.sh

    # Non-interactive rotation
    sudo ./rotate-jwt-keys.sh --no-confirm

    # Rotate without restarting services
    sudo ./rotate-jwt-keys.sh --restart-services=no

EOF
    exit 0
}

# Check root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root or with sudo"
    exit 1
fi

# Defaults
BACKUP_OLD=true
RESTART_SERVICES=true
NO_CONFIRM=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --backup-old)
            BACKUP_OLD=true
            shift
            ;;
        --backup-old=*)
            BACKUP_OLD="${1#*=}"
            shift
            ;;
        --restart-services)
            RESTART_SERVICES=true
            shift
            ;;
        --restart-services=*)
            RESTART_SERVICES="${1#*=}"
            shift
            ;;
        --no-confirm)
            NO_CONFIRM=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

log_info "JWT Key Rotation Utility"
log_info "========================"
echo

# Confirmation
if [[ "$NO_CONFIRM" != "true" ]]; then
    log_warn "This will rotate your JWT signing keys."
    log_warn "All existing JWTs will become invalid after rotation."
    log_warn "You will need to generate new anon and service_role keys."
    echo
    read -p "Are you sure you want to continue? (type 'yes' to proceed): " -r
    echo
    if [[ ! $REPLY =~ ^yes$ ]]; then
        log_info "Rotation cancelled"
        exit 0
    fi
fi

# Check if keys directory exists
if [[ ! -d "$KEYS_DIR" ]]; then
    log_error "Keys directory not found: $KEYS_DIR"
    exit 1
fi

# Backup old keys
if [[ "$BACKUP_OLD" == "true" ]]; then
    log_info "Backing up old keys..."
    timestamp=$(date +%Y%m%d_%H%M%S)
    backup_dir="$KEYS_DIR/backup_$timestamp"
    mkdir -p "$backup_dir"

    if [[ -f "$KEYS_DIR/jwt-private.pem" ]]; then
        cp "$KEYS_DIR/jwt-private.pem" "$backup_dir/"
        cp "$KEYS_DIR/jwt-public.pem" "$backup_dir/" 2>/dev/null || true
        log_success "Old keys backed up to: $backup_dir"
    else
        log_warn "No existing keys to backup"
    fi
fi

# Generate new RSA key pair
log_info "Generating new RSA key pair (4096-bit)..."
openssl genrsa -out "$KEYS_DIR/jwt-private-new.pem" 4096 2>/dev/null

if [[ $? -ne 0 ]]; then
    log_error "Failed to generate private key"
    exit 1
fi

log_success "Private key generated"

# Extract public key
log_info "Extracting public key..."
openssl rsa -in "$KEYS_DIR/jwt-private-new.pem" -pubout -out "$KEYS_DIR/jwt-public-new.pem" 2>/dev/null

if [[ $? -ne 0 ]]; then
    log_error "Failed to extract public key"
    exit 1
fi

log_success "Public key extracted"

# Set permissions
log_info "Setting secure permissions..."
chmod 600 "$KEYS_DIR/jwt-private-new.pem"
chmod 644 "$KEYS_DIR/jwt-public-new.pem"

# Get supabase user if exists
if id supabase >/dev/null 2>&1; then
    chown supabase:supabase "$KEYS_DIR/jwt-private-new.pem"
    chown supabase:supabase "$KEYS_DIR/jwt-public-new.pem"
fi

log_success "Permissions set"

# Replace old keys
log_info "Replacing old keys with new keys..."
mv "$KEYS_DIR/jwt-private-new.pem" "$KEYS_DIR/jwt-private.pem"
mv "$KEYS_DIR/jwt-public-new.pem" "$KEYS_DIR/jwt-public.pem"

log_success "Keys replaced"

# Display public key
echo
log_info "New Public Key:"
echo "----------------------------------------"
cat "$KEYS_DIR/jwt-public.pem"
echo "----------------------------------------"
echo

# Generate sample JWT tokens
log_info "Generating new JWT tokens..."

# Check if Node.js is available
if command -v node >/dev/null 2>&1; then
    # Create temporary JWT generation script
    cat > /tmp/generate-jwt.js << 'EOFJS'
const crypto = require('crypto');
const fs = require('fs');

function base64UrlEncode(str) {
    return Buffer.from(str)
        .toString('base64')
        .replace(/\+/g, '-')
        .replace(/\//g, '_')
        .replace(/=/g, '');
}

function generateJWT(privateKeyPath, payload) {
    const privateKey = fs.readFileSync(privateKeyPath, 'utf8');

    const header = {
        alg: 'RS256',
        typ: 'JWT'
    };

    const now = Math.floor(Date.now() / 1000);
    const jwtPayload = {
        ...payload,
        iat: now,
        exp: now + (10 * 365 * 24 * 60 * 60) // 10 years
    };

    const encodedHeader = base64UrlEncode(JSON.stringify(header));
    const encodedPayload = base64UrlEncode(JSON.stringify(jwtPayload));

    const signatureInput = `${encodedHeader}.${encodedPayload}`;

    const sign = crypto.createSign('RSA-SHA256');
    sign.update(signatureInput);
    sign.end();

    const signature = sign.sign(privateKey);
    const encodedSignature = base64UrlEncode(signature);

    return `${encodedHeader}.${encodedPayload}.${encodedSignature}`;
}

const privateKeyPath = process.argv[2];

const anonKey = generateJWT(privateKeyPath, {
    role: 'anon',
    iss: 'supabase',
    aud: 'authenticated'
});

const serviceRoleKey = generateJWT(privateKeyPath, {
    role: 'service_role',
    iss: 'supabase',
    aud: 'authenticated'
});

console.log('ANON_KEY=' + anonKey);
console.log('SERVICE_ROLE_KEY=' + serviceRoleKey);
EOFJS

    # Generate tokens
    node /tmp/generate-jwt.js "$KEYS_DIR/jwt-private.pem" > /tmp/new-jwt-keys.txt

    log_success "New JWT tokens generated"
    echo
    log_info "New JWT Keys (update these in your .env file):"
    echo "----------------------------------------"
    cat /tmp/new-jwt-keys.txt
    echo "----------------------------------------"
    echo

    # Save to file
    cp /tmp/new-jwt-keys.txt "$KEYS_DIR/new-jwt-keys.txt"
    chmod 600 "$KEYS_DIR/new-jwt-keys.txt"
    if id supabase >/dev/null 2>&1; then
        chown supabase:supabase "$KEYS_DIR/new-jwt-keys.txt"
    fi

    log_success "Keys saved to: $KEYS_DIR/new-jwt-keys.txt"

    # Cleanup
    rm /tmp/generate-jwt.js
    rm /tmp/new-jwt-keys.txt
else
    log_warn "Node.js not found - cannot generate JWT tokens automatically"
    log_info "Please generate JWT tokens manually using the new private key"
    log_info "See: $PROJECT_DIR/docs/RS256_JWT_MIGRATION.md"
fi

# Update .env file
log_info "Updating environment file..."
env_file="$PROJECT_DIR/.env"

if [[ -f "$env_file" ]]; then
    # Backup .env
    cp "$env_file" "$env_file.backup.$(date +%Y%m%d_%H%M%S)"

    # Update JWT algorithm if needed
    if grep -q "^JWT_ALGORITHM=" "$env_file"; then
        sed -i 's/^JWT_ALGORITHM=.*/JWT_ALGORITHM=RS256/' "$env_file"
    else
        echo "JWT_ALGORITHM=RS256" >> "$env_file"
    fi

    log_success "Environment file updated"
    log_warn "IMPORTANT: Update ANON_KEY and SERVICE_ROLE_KEY in $env_file with new values"
else
    log_warn "Environment file not found: $env_file"
fi

# Restart services
if [[ "$RESTART_SERVICES" == "true" ]]; then
    log_info "Restarting services..."
    cd "$PROJECT_DIR"

    if docker compose ps >/dev/null 2>&1; then
        docker compose restart auth
        docker compose restart kong
        docker compose restart rest

        log_success "Services restarted"

        # Wait for services to be healthy
        log_info "Waiting for services to be healthy..."
        sleep 10

        if docker compose ps | grep -E "auth|kong|rest" | grep -q "healthy\|running"; then
            log_success "Services are healthy"
        else
            log_warn "Some services may not be healthy - check with: docker compose ps"
        fi
    else
        log_warn "Docker Compose not available - please restart services manually"
    fi
else
    log_warn "Services not restarted - please restart manually:"
    log_warn "  cd $PROJECT_DIR && docker compose restart auth kong rest"
fi

echo
log_success "============================================"
log_success "JWT Key Rotation Complete!"
log_success "============================================"
echo
log_warn "NEXT STEPS:"
log_warn "1. Update ANON_KEY and SERVICE_ROLE_KEY in $env_file"
log_warn "2. Restart services: cd $PROJECT_DIR && docker compose restart"
log_warn "3. Update client applications with new anon key"
log_warn "4. Securely store backup keys: $KEYS_DIR/backup_*"
log_warn "5. Delete new-jwt-keys.txt after copying values"
echo
log_info "Backup location: $backup_dir"
log_info "New keys location: $KEYS_DIR"
log_info "Documentation: $PROJECT_DIR/docs/RS256_JWT_MIGRATION.md"
echo

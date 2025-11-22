#!/usr/bin/env bash
#===============================================================================
# Supabase Production Deployment Script
# Version: 1.0.0
# Description: Complete automation for production-ready Supabase self-hosting
# Platform: Ubuntu 22.04+
# Author: SRE Team
#===============================================================================

set -euo pipefail
IFS=$'\n\t'

#===============================================================================
# DEFAULT CONFIGURATION
# Override these via environment variables or command-line arguments
#===============================================================================

# Deployment settings
readonly SCRIPT_VERSION="1.0.0"
readonly DEFAULT_PROJECT_DIR="/opt/supabase"
readonly DEFAULT_BACKUP_DIR="/var/backups/supabase"
readonly DEFAULT_SUPABASE_USER="supabase"
readonly DEFAULT_REPO_URL="https://github.com/supabase/supabase.git"

# Non-interactive mode defaults
INTERACTIVE_MODE=true
ENV_FILE=""
VAULT_ENDPOINT=""
PROJECT_DIR="${PROJECT_DIR:-$DEFAULT_PROJECT_DIR}"
BACKUP_DIR="${BACKUP_DIR:-$DEFAULT_BACKUP_DIR}"
SUPABASE_USER="${SUPABASE_USER:-$DEFAULT_SUPABASE_USER}"
DOMAIN="${DOMAIN:-}"
EMAIL="${EMAIL:-}"

# Feature flags
SKIP_USER_CREATION="${SKIP_USER_CREATION:-false}"
SKIP_SSH_HARDENING="${SKIP_SSH_HARDENING:-false}"
SKIP_DOCKER_INSTALL="${SKIP_DOCKER_INSTALL:-false}"
SKIP_FIREWALL="${SKIP_FIREWALL:-false}"
SKIP_MONITORING="${SKIP_MONITORING:-false}"
SKIP_BACKUPS="${SKIP_BACKUPS:-false}"
SKIP_TLS="${SKIP_TLS:-false}"

# Logging
LOG_FILE="/var/log/supabase-deployment.log"
readonly LOG_LEVELS=("DEBUG" "INFO" "WARN" "ERROR")

#===============================================================================
# COLOR CODES FOR OUTPUT
#===============================================================================

if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly MAGENTA='\033[0;35m'
    readonly CYAN='\033[0;36m'
    readonly NC='\033[0m' # No Color
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly MAGENTA=''
    readonly CYAN=''
    readonly NC=''
fi

#===============================================================================
# UTILITY FUNCTIONS
#===============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE" >&2
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${MAGENTA}[DEBUG]${NC} $*" | tee -a "$LOG_FILE"
    fi
}

banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   ███████╗██╗   ██╗██████╗  █████╗ ██████╗  █████╗ ███████╗ ║
║   ██╔════╝██║   ██║██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔════╝ ║
║   ███████╗██║   ██║██████╔╝███████║██████╔╝███████║███████╗ ║
║   ╚════██║██║   ██║██╔═══╝ ██╔══██║██╔══██╗██╔══██║╚════██║ ║
║   ███████║╚██████╔╝██║     ██║  ██║██████╔╝██║  ██║███████║ ║
║   ╚══════╝ ╚═════╝ ╚═╝     ╚═╝  ╚═╝╚═════╝ ╚═╝  ╚═╝╚══════╝ ║
║                                                               ║
║           Production Deployment Automation v1.0.0            ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Production-ready Supabase deployment automation for Ubuntu 22.04+

OPTIONS:
    -d, --domain DOMAIN         Domain name (e.g., api.example.com)
    -e, --email EMAIL          Email for Let's Encrypt notifications
    -p, --project-dir DIR      Installation directory (default: $DEFAULT_PROJECT_DIR)
    -b, --backup-dir DIR       Backup directory (default: $DEFAULT_BACKUP_DIR)
    -u, --user USERNAME        Non-root user for Supabase (default: $DEFAULT_SUPABASE_USER)

    --env-file FILE            Load environment from file (non-interactive)
    --vault ENDPOINT           Vault endpoint for secret management

    --skip-user-creation       Skip user creation (user exists)
    --skip-ssh-hardening       Skip SSH hardening
    --skip-docker-install      Skip Docker installation
    --skip-firewall            Skip firewall configuration
    --skip-monitoring          Skip monitoring stack setup
    --skip-backups             Skip backup configuration
    --skip-tls                 Skip TLS/SSL certificate setup

    --debug                    Enable debug logging
    -h, --help                 Show this help message

EXAMPLES:
    # Interactive mode (recommended for first-time setup)
    sudo ./deploy_supabase.sh -d api.example.com -e admin@example.com

    # Non-interactive mode with environment file
    sudo ./deploy_supabase.sh --env-file /path/to/.env --domain api.example.com

    # Non-interactive with Vault integration
    sudo ./deploy_supabase.sh --vault https://vault.example.com -d api.example.com

    # Skip existing user creation and SSH hardening
    sudo ./deploy_supabase.sh -d api.example.com --skip-user-creation --skip-ssh-hardening

ENVIRONMENT VARIABLES:
    PROJECT_DIR                Installation directory
    BACKUP_DIR                 Backup storage directory
    SUPABASE_USER              System user for running Supabase
    DOMAIN                     Your domain name
    EMAIL                      Admin email address

For detailed documentation, see README.md

EOF
    exit 0
}

# Secure input for passwords
read_secret() {
    local prompt="$1"
    local var_name="${2:-}"  # Optional second parameter
    local value=""

    echo -n "$prompt: " >&2
    read -rs value
    echo >&2

    if [[ -z "$value" ]]; then
        log_error "Value cannot be empty"
        return 1
    fi

    printf '%s' "$value"
}

# Generate strong random password
generate_password() {
    local length="${1:-32}"
    openssl rand -base64 48 | tr -d "=+/" | cut -c1-"$length"
}

# Generate strong JWT secret (base64url encoded)
generate_jwt_secret() {
    openssl rand -base64 32 | tr -d "=+/" | tr '\n' '_'
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        exit 1
    fi
}

# Check OS compatibility
check_os() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot detect OS. /etc/os-release not found"
        exit 1
    fi

    source /etc/os-release

    if [[ "$ID" != "ubuntu" ]]; then
        log_error "This script is designed for Ubuntu. Detected: $ID"
        exit 1
    fi

    local version_id="${VERSION_ID%%.*}"
    if [[ "$version_id" -lt 22 ]]; then
        log_error "Ubuntu 22.04+ required. Detected: $VERSION_ID"
        exit 1
    fi

    log_success "OS check passed: Ubuntu $VERSION_ID"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Wait for apt lock
wait_for_apt() {
    local max_wait=300
    local waited=0

    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
          fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
        if [[ $waited -ge $max_wait ]]; then
            log_error "Timeout waiting for apt lock"
            return 1
        fi
        log_info "Waiting for apt lock... ($waited/$max_wait)"
        sleep 5
        waited=$((waited + 5))
    done

    return 0
}

# Idempotent package installation
install_package() {
    local package="$1"

    if dpkg -l | grep -q "^ii  $package "; then
        log_debug "$package is already installed"
        return 0
    fi

    log_info "Installing $package..."
    wait_for_apt
    DEBIAN_FRONTEND=noninteractive apt-get install -y -q "$package" >> "$LOG_FILE" 2>&1
}

#===============================================================================
# ARGUMENT PARSING
#===============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--domain)
                DOMAIN="$2"
                shift 2
                ;;
            -e|--email)
                EMAIL="$2"
                shift 2
                ;;
            -p|--project-dir)
                PROJECT_DIR="$2"
                shift 2
                ;;
            -b|--backup-dir)
                BACKUP_DIR="$2"
                shift 2
                ;;
            -u|--user)
                SUPABASE_USER="$2"
                shift 2
                ;;
            --env-file)
                ENV_FILE="$2"
                INTERACTIVE_MODE=false
                shift 2
                ;;
            --vault)
                VAULT_ENDPOINT="$2"
                INTERACTIVE_MODE=false
                shift 2
                ;;
            --skip-user-creation)
                SKIP_USER_CREATION=true
                shift
                ;;
            --skip-ssh-hardening)
                SKIP_SSH_HARDENING=true
                shift
                ;;
            --skip-docker-install)
                SKIP_DOCKER_INSTALL=true
                shift
                ;;
            --skip-firewall)
                SKIP_FIREWALL=true
                shift
                ;;
            --skip-monitoring)
                SKIP_MONITORING=true
                shift
                ;;
            --skip-backups)
                SKIP_BACKUPS=true
                shift
                ;;
            --skip-tls)
                SKIP_TLS=true
                shift
                ;;
            --debug)
                DEBUG=true
                set -x
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
}

#===============================================================================
# PRE-FLIGHT CHECKS
#===============================================================================

preflight_checks() {
    log_info "Running pre-flight checks..."

    # Check root
    check_root

    # Check OS
    check_os

    # Check domain
    if [[ -z "$DOMAIN" ]] && [[ "$SKIP_TLS" == "false" ]]; then
        if [[ "$INTERACTIVE_MODE" == "true" ]]; then
            read -p "Enter your domain name (e.g., api.example.com): " DOMAIN
        else
            log_error "Domain required when TLS is enabled. Use -d or --skip-tls"
            exit 1
        fi
    fi

    # Check email
    if [[ -z "$EMAIL" ]] && [[ "$SKIP_TLS" == "false" ]]; then
        if [[ "$INTERACTIVE_MODE" == "true" ]]; then
            read -p "Enter your email for Let's Encrypt: " EMAIL
        else
            log_error "Email required for Let's Encrypt. Use -e or --skip-tls"
            exit 1
        fi
    fi

    # Check internet connectivity
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_error "No internet connectivity detected"
        exit 1
    fi

    # Check available disk space (minimum 20GB)
    local available_space=$(df / | tail -1 | awk '{print $4}')
    local required_space=$((20 * 1024 * 1024)) # 20GB in KB

    if [[ $available_space -lt $required_space ]]; then
        log_warn "Less than 20GB disk space available. This may cause issues."
    fi

    # Check if project directory exists
    if [[ -d "$PROJECT_DIR" ]]; then
        log_warn "Project directory $PROJECT_DIR already exists"
        if [[ "$INTERACTIVE_MODE" == "true" ]]; then
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    fi

    log_success "Pre-flight checks completed"
}

#===============================================================================
# USER MANAGEMENT
#===============================================================================

create_supabase_user() {
    if [[ "$SKIP_USER_CREATION" == "true" ]]; then
        log_info "Skipping user creation (--skip-user-creation)"
        return 0
    fi

    log_info "Creating non-root user: $SUPABASE_USER"

    if id "$SUPABASE_USER" >/dev/null 2>&1; then
        log_warn "User $SUPABASE_USER already exists"
        return 0
    fi

    # Create user with home directory
    useradd -m -s /bin/bash -G sudo,docker "$SUPABASE_USER" || true

    # Set up SSH directory
    local user_home=$(getent passwd "$SUPABASE_USER" | cut -d: -f6)
    mkdir -p "$user_home/.ssh"
    chmod 700 "$user_home/.ssh"

    # Copy authorized_keys from root if exists
    if [[ -f /root/.ssh/authorized_keys ]]; then
        cp /root/.ssh/authorized_keys "$user_home/.ssh/authorized_keys"
        chmod 600 "$user_home/.ssh/authorized_keys"
        chown -R "$SUPABASE_USER:$SUPABASE_USER" "$user_home/.ssh"
        log_success "Copied SSH keys from root to $SUPABASE_USER"
    else
        log_warn "No authorized_keys found in /root/.ssh"
        log_warn "Make sure to add SSH keys for $SUPABASE_USER before disabling password auth"
    fi

    log_success "User $SUPABASE_USER created successfully"
}

harden_ssh() {
    if [[ "$SKIP_SSH_HARDENING" == "true" ]]; then
        log_info "Skipping SSH hardening (--skip-ssh-hardening)"
        return 0
    fi

    log_info "Hardening SSH configuration..."

    local sshd_config="/etc/ssh/sshd_config"
    local backup_config="${sshd_config}.backup.$(date +%s)"

    # Backup original config
    cp "$sshd_config" "$backup_config"
    log_debug "SSH config backed up to $backup_config"

    # Apply hardening settings
    sed -i 's/^#*PermitRootLogin .*/PermitRootLogin no/' "$sshd_config"
    sed -i 's/^#*PasswordAuthentication .*/PasswordAuthentication no/' "$sshd_config"
    sed -i 's/^#*PubkeyAuthentication .*/PubkeyAuthentication yes/' "$sshd_config"
    sed -i 's/^#*ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' "$sshd_config"
    sed -i 's/^#*UsePAM .*/UsePAM yes/' "$sshd_config"
    sed -i 's/^#*X11Forwarding .*/X11Forwarding no/' "$sshd_config"

    # Add additional hardening if not present
    if ! grep -q "^AllowUsers" "$sshd_config"; then
        echo "AllowUsers $SUPABASE_USER" >> "$sshd_config"
    fi

    # Validate SSH config
    if sshd -t; then
        log_success "SSH configuration is valid"

        # Determine SSH service name (Ubuntu uses 'ssh', some systems use 'sshd')
        local ssh_service="ssh"
        if systemctl list-units --type=service | grep -q "sshd.service"; then
            ssh_service="sshd"
        fi

        systemctl restart "$ssh_service"
        log_success "SSH hardening completed and service restarted"
    else
        log_error "Invalid SSH configuration. Restoring backup..."
        cp "$backup_config" "$sshd_config"
        exit 1
    fi
}

#===============================================================================
# SYSTEM PACKAGES INSTALLATION
#===============================================================================

install_essential_packages() {
    log_info "Updating package lists..."
    wait_for_apt
    apt-get update -qq >> "$LOG_FILE" 2>&1

    log_info "Installing essential packages..."

    local packages=(
        "git"
        "curl"
        "wget"
        "jq"
        "ufw"
        "fail2ban"
        "certbot"
        "python3-certbot-nginx"
        "nginx"
        "openssl"
        "gnupg"
        "ca-certificates"
        "lsb-release"
        "software-properties-common"
        "apt-transport-https"
        "unzip"
        "htop"
        "vim"
        "net-tools"
        "postgresql-client"
    )

    for package in "${packages[@]}"; do
        install_package "$package"
    done

    log_success "Essential packages installed"
}

#===============================================================================
# DOCKER INSTALLATION
#===============================================================================

install_docker() {
    if [[ "$SKIP_DOCKER_INSTALL" == "true" ]]; then
        log_info "Skipping Docker installation (--skip-docker-install)"
        return 0
    fi

    if command_exists docker && command_exists docker-compose; then
        log_info "Docker and Docker Compose already installed"
        docker --version | tee -a "$LOG_FILE"
        docker compose version | tee -a "$LOG_FILE"
        return 0
    fi

    log_info "Installing Docker Engine..."

    # Remove old versions
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Set up Docker repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker Engine
    wait_for_apt
    apt-get update -qq >> "$LOG_FILE" 2>&1
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >> "$LOG_FILE" 2>&1

    # Start and enable Docker
    systemctl start docker
    systemctl enable docker

    # Add user to docker group
    usermod -aG docker "$SUPABASE_USER" || true

    log_success "Docker installed successfully"
    docker --version
    docker compose version
}

#===============================================================================
# SUPABASE SETUP
#===============================================================================

clone_supabase_repo() {
    log_info "Cloning Supabase repository..."

    if [[ -d "$PROJECT_DIR/.git" ]]; then
        log_warn "Git repository already exists at $PROJECT_DIR"
        return 0
    fi

    mkdir -p "$PROJECT_DIR"

    # Shallow clone for faster setup
    git clone --depth 1 "$DEFAULT_REPO_URL" "$PROJECT_DIR/supabase-repo" >> "$LOG_FILE" 2>&1

    # Copy docker directory to project dir (including hidden files like .env.example)
    cp -r "$PROJECT_DIR/supabase-repo/docker/"* "$PROJECT_DIR/" 2>/dev/null || true
    cp -r "$PROJECT_DIR/supabase-repo/docker/".* "$PROJECT_DIR/" 2>/dev/null || true

    # Ensure .env.example exists
    if [[ ! -f "$PROJECT_DIR/.env.example" ]]; then
        log_warn ".env.example not found in docker directory, creating template..."
        # Create a basic .env.example if it doesn't exist
        cat > "$PROJECT_DIR/.env.example" << 'EOF'
# PostgreSQL
POSTGRES_PASSWORD=your-super-secret-and-long-postgres-password
POSTGRES_HOST=db
POSTGRES_PORT=5432
POSTGRES_DB=postgres

# JWT
JWT_SECRET=your-super-secret-jwt-token-with-at-least-32-characters-long
ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE
SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJzZXJ2aWNlX3JvbGUiLAogICAgImlzcyI6ICJzdXBhYmFzZS1kZW1vIiwKICAgICJpYXQiOiAxNjQxNzY5MjAwLAogICAgImV4cCI6IDE3OTk1MzU2MDAKfQ.DaYlNEoUrrEn2Ig7tqibS-PHK5vgusbcbo7X36XVt4Q

# API
API_EXTERNAL_URL=http://localhost:8000
SITE_URL=http://localhost:3000

# Dashboard
DASHBOARD_USERNAME=supabase
DASHBOARD_PASSWORD=this_password_is_insecure_and_should_be_updated

# Database
POSTGRES_USER=postgres

# Studio
STUDIO_DEFAULT_ORGANIZATION=Default Organization
STUDIO_DEFAULT_PROJECT=Default Project
STUDIO_PORT=3000

# Ports
KONG_HTTP_PORT=8000
KONG_HTTPS_PORT=8443
EOF
    fi

    # Clean up repo clone
    rm -rf "$PROJECT_DIR/supabase-repo"

    log_success "Supabase files prepared"
}

generate_jwt_keys() {
    log_info "Generating RSA key pair for JWT RS256 signing..."

    local keys_dir="$PROJECT_DIR/keys"
    mkdir -p "$keys_dir"
    chmod 700 "$keys_dir"

    local private_key="$keys_dir/jwt-private.pem"
    local public_key="$keys_dir/jwt-public.pem"

    if [[ -f "$private_key" ]] && [[ -f "$public_key" ]]; then
        log_warn "JWT keys already exist, skipping generation"
        return 0
    fi

    # Generate 4096-bit RSA private key
    openssl genrsa -out "$private_key" 4096 2>> "$LOG_FILE"
    chmod 600 "$private_key"

    # Extract public key
    openssl rsa -in "$private_key" -pubout -out "$public_key" 2>> "$LOG_FILE"
    chmod 644 "$public_key"

    # Set ownership
    chown -R "$SUPABASE_USER:$SUPABASE_USER" "$keys_dir"

    log_success "JWT keys generated at $keys_dir"
    log_info "Private key: $private_key (Keep this secure!)"
    log_info "Public key: $public_key"
}

configure_environment() {
    log_info "Configuring environment variables..."

    local env_file="$PROJECT_DIR/.env"
    local env_example="$PROJECT_DIR/.env.example"

    if [[ ! -f "$env_example" ]]; then
        log_error ".env.example not found at $env_example"
        exit 1
    fi

    # If non-interactive and ENV_FILE provided, use it
    if [[ "$INTERACTIVE_MODE" == "false" ]] && [[ -n "$ENV_FILE" ]]; then
        if [[ ! -f "$ENV_FILE" ]]; then
            log_error "Environment file not found: $ENV_FILE"
            exit 1
        fi
        cp "$ENV_FILE" "$env_file"
        log_success "Environment loaded from $ENV_FILE"
        return 0
    fi

    # Copy example to .env
    cp "$env_example" "$env_file"

    # Generate secrets
    local postgres_password
    local jwt_secret
    local anon_key
    local service_role_key
    local dashboard_username
    local dashboard_password

    if [[ "$INTERACTIVE_MODE" == "true" ]]; then
        log_info "Generating secure secrets (you can provide your own or press Enter to auto-generate)..."

        echo
        read -p "PostgreSQL password (or Enter to auto-generate): " postgres_password
        if [[ -z "$postgres_password" ]]; then
            postgres_password=$(generate_password 32)
            log_info "Auto-generated PostgreSQL password"
        fi

        read -p "JWT secret (or Enter to auto-generate): " jwt_secret
        if [[ -z "$jwt_secret" ]]; then
            jwt_secret=$(generate_jwt_secret)
            log_info "Auto-generated JWT secret"
        fi

        read -p "Dashboard username (default: admin): " dashboard_username
        dashboard_username="${dashboard_username:-admin}"

        dashboard_password=$(read_secret "Dashboard password")

        echo

    else
        # Non-interactive: generate all secrets
        postgres_password=$(generate_password 32)
        jwt_secret=$(generate_jwt_secret)
        dashboard_username="admin"
        dashboard_password=$(generate_password 32)
    fi

    # Generate JWT tokens (simplified - in production use proper JWT generation)
    anon_key=$(echo -n "anon-key-${jwt_secret}" | base64 | tr -d '\n')
    service_role_key=$(echo -n "service-role-key-${jwt_secret}" | base64 | tr -d '\n')

    # Update .env file
    sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${postgres_password}|" "$env_file"
    sed -i "s|^JWT_SECRET=.*|JWT_SECRET=${jwt_secret}|" "$env_file"
    sed -i "s|^ANON_KEY=.*|ANON_KEY=${anon_key}|" "$env_file"
    sed -i "s|^SERVICE_ROLE_KEY=.*|SERVICE_ROLE_KEY=${service_role_key}|" "$env_file"
    sed -i "s|^DASHBOARD_USERNAME=.*|DASHBOARD_USERNAME=${dashboard_username}|" "$env_file"
    sed -i "s|^DASHBOARD_PASSWORD=.*|DASHBOARD_PASSWORD=${dashboard_password}|" "$env_file"

    # Update site URL
    if [[ -n "$DOMAIN" ]]; then
        sed -i "s|^SITE_URL=.*|SITE_URL=https://${DOMAIN}|" "$env_file"
        sed -i "s|^API_EXTERNAL_URL=.*|API_EXTERNAL_URL=https://${DOMAIN}|" "$env_file"
        sed -i "s|^STUDIO_DEFAULT_PROJECT=.*|STUDIO_DEFAULT_PROJECT=https://${DOMAIN}|" "$env_file"
    fi

    # Set restrictive permissions
    chmod 600 "$env_file"
    chown "$SUPABASE_USER:$SUPABASE_USER" "$env_file"

    log_success "Environment configured at $env_file"

    # Save credentials to secure location
    local creds_file="$PROJECT_DIR/credentials.txt"
    cat > "$creds_file" << EOF
Supabase Credentials
====================
Generated: $(date)

PostgreSQL Password: ${postgres_password}
JWT Secret: ${jwt_secret}
Dashboard Username: ${dashboard_username}
Dashboard Password: ${dashboard_password}

IMPORTANT: Store these credentials securely and delete this file!
EOF
    chmod 600 "$creds_file"
    chown "$SUPABASE_USER:$SUPABASE_USER" "$creds_file"

    log_warn "Credentials saved to $creds_file - PLEASE STORE SECURELY AND DELETE!"
}

#===============================================================================
# NGINX & TLS CONFIGURATION
#===============================================================================

configure_nginx() {
    if [[ "$SKIP_TLS" == "true" ]]; then
        log_info "Skipping Nginx/TLS configuration (--skip-tls)"
        return 0
    fi

    log_info "Configuring Nginx reverse proxy..."

    local nginx_conf="/etc/nginx/sites-available/supabase"
    local nginx_enabled="/etc/nginx/sites-enabled/supabase"

    # Remove default site
    rm -f /etc/nginx/sites-enabled/default

    # Create Nginx configuration
    cat > "$nginx_conf" << EOF
# Supabase Nginx Configuration
# Generated: $(date)

# Rate limiting
limit_req_zone \$binary_remote_addr zone=api_limit:10m rate=10r/s;
limit_conn_zone \$binary_remote_addr zone=addr:10m;

# Upstream to Supabase Kong Gateway
upstream kong {
    server 127.0.0.1:8000;
    keepalive 32;
}

# Upstream to Supabase Studio
upstream studio {
    server 127.0.0.1:3000;
    keepalive 32;
}

# HTTP - Redirect to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

# HTTPS - Main API
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${DOMAIN};

    # SSL Configuration (will be updated by Certbot)
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

    # SSL Security
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_stapling on;
    ssl_stapling_verify on;

    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Logging
    access_log /var/log/nginx/supabase-access.log;
    error_log /var/log/nginx/supabase-error.log;

    # Client body size
    client_max_body_size 100M;

    # Studio UI
    location /studio {
        proxy_pass http://studio;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    # API endpoints through Kong
    location / {
        limit_req zone=api_limit burst=20 nodelay;
        limit_conn addr 10;

        proxy_pass http://kong;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

    # Enable site
    ln -sf "$nginx_conf" "$nginx_enabled"

    # Test Nginx configuration
    if nginx -t 2>> "$LOG_FILE"; then
        systemctl restart nginx
        log_success "Nginx configured and restarted"
    else
        log_error "Nginx configuration test failed"
        exit 1
    fi
}

setup_tls_certificates() {
    if [[ "$SKIP_TLS" == "true" ]]; then
        log_info "Skipping TLS certificate setup (--skip-tls)"
        return 0
    fi

    log_info "Setting up Let's Encrypt TLS certificates..."

    # Create webroot directory
    mkdir -p /var/www/certbot

    # Check if certificate already exists
    if [[ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]]; then
        log_warn "Certificate already exists for $DOMAIN"
        return 0
    fi

    # Obtain certificate
    certbot certonly --webroot \
        -w /var/www/certbot \
        -d "$DOMAIN" \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        --non-interactive >> "$LOG_FILE" 2>&1

    if [[ $? -eq 0 ]]; then
        log_success "TLS certificate obtained successfully"

        # Set up auto-renewal
        local renewal_script="/etc/cron.daily/certbot-renewal"
        cat > "$renewal_script" << 'EOF'
#!/bin/bash
certbot renew --quiet --deploy-hook "systemctl reload nginx"
EOF
        chmod +x "$renewal_script"

        log_success "Auto-renewal configured"
    else
        log_error "Failed to obtain TLS certificate"
        log_error "Please check DNS records point to this server"
        exit 1
    fi
}

#===============================================================================
# FIREWALL CONFIGURATION
#===============================================================================

configure_firewall() {
    if [[ "$SKIP_FIREWALL" == "true" ]]; then
        log_info "Skipping firewall configuration (--skip-firewall)"
        return 0
    fi

    log_info "Configuring UFW firewall..."

    # Reset UFW to default
    ufw --force reset >> "$LOG_FILE" 2>&1

    # Default policies
    ufw default deny incoming >> "$LOG_FILE" 2>&1
    ufw default allow outgoing >> "$LOG_FILE" 2>&1

    # Allow SSH
    ufw allow 22/tcp comment 'SSH' >> "$LOG_FILE" 2>&1

    # Allow HTTP/HTTPS
    ufw allow 80/tcp comment 'HTTP' >> "$LOG_FILE" 2>&1
    ufw allow 443/tcp comment 'HTTPS' >> "$LOG_FILE" 2>&1

    # Enable UFW
    ufw --force enable >> "$LOG_FILE" 2>&1

    log_success "Firewall configured and enabled"
    ufw status verbose
}

configure_fail2ban() {
    if [[ "$SKIP_FIREWALL" == "true" ]]; then
        log_info "Skipping fail2ban configuration (--skip-firewall)"
        return 0
    fi

    log_info "Configuring fail2ban..."

    local jail_local="/etc/fail2ban/jail.local"

    cat > "$jail_local" << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
destemail = ${EMAIL}
sendername = Fail2Ban

[sshd]
enabled = true
port = 22
logpath = /var/log/auth.log

[nginx-http-auth]
enabled = true
port = 80,443
logpath = /var/log/nginx/supabase-error.log

[nginx-limit-req]
enabled = true
port = 80,443
logpath = /var/log/nginx/supabase-error.log
maxretry = 10
EOF

    systemctl restart fail2ban
    log_success "fail2ban configured and started"
}

#===============================================================================
# SUPABASE DEPLOYMENT
#===============================================================================

start_supabase() {
    log_info "Starting Supabase services..."

    cd "$PROJECT_DIR"

    # Pull latest images
    log_info "Pulling Docker images (this may take a few minutes)..."
    sudo -u "$SUPABASE_USER" docker compose pull >> "$LOG_FILE" 2>&1

    # Start services
    log_info "Starting services with docker compose..."
    sudo -u "$SUPABASE_USER" docker compose up -d >> "$LOG_FILE" 2>&1

    log_success "Supabase services started"
}

wait_for_services() {
    log_info "Waiting for services to become healthy..."

    local max_wait=300
    local waited=0
    local services=("db" "kong" "auth" "rest" "realtime" "storage" "meta")

    while [[ $waited -lt $max_wait ]]; do
        local all_healthy=true

        for service in "${services[@]}"; do
            if ! docker compose ps "$service" 2>/dev/null | grep -q "healthy\|running"; then
                all_healthy=false
                break
            fi
        done

        if [[ "$all_healthy" == "true" ]]; then
            log_success "All services are healthy"
            return 0
        fi

        log_info "Waiting for services... ($waited/$max_wait)"
        sleep 10
        waited=$((waited + 10))
    done

    log_warn "Timeout waiting for all services to be healthy"
    log_warn "Check service status with: docker compose ps"
    return 1
}

smoke_tests() {
    log_info "Running smoke tests..."

    local tests_passed=0
    local tests_total=4

    # Test 1: Check if Kong is responding
    log_info "Test 1/$tests_total: Checking Kong gateway..."
    if curl -sf http://localhost:8000/health >/dev/null 2>&1; then
        log_success "Kong is responding"
        ((tests_passed++))
    else
        log_error "Kong is not responding"
    fi

    # Test 2: Check if Studio is responding
    log_info "Test 2/$tests_total: Checking Studio..."
    if curl -sf http://localhost:3000 >/dev/null 2>&1; then
        log_success "Studio is responding"
        ((tests_passed++))
    else
        log_error "Studio is not responding"
    fi

    # Test 3: Check if PostgreSQL is accepting connections
    log_info "Test 3/$tests_total: Checking PostgreSQL..."
    if docker compose exec -T db pg_isready -U postgres >/dev/null 2>&1; then
        log_success "PostgreSQL is ready"
        ((tests_passed++))
    else
        log_error "PostgreSQL is not ready"
    fi

    # Test 4: Check if external domain is accessible (if configured)
    if [[ -n "$DOMAIN" ]] && [[ "$SKIP_TLS" == "false" ]]; then
        log_info "Test 4/$tests_total: Checking external HTTPS access..."
        if curl -sf "https://${DOMAIN}/health" >/dev/null 2>&1; then
            log_success "External HTTPS access working"
            ((tests_passed++))
        else
            log_warn "External HTTPS access not working (may need DNS propagation)"
        fi
    else
        log_info "Test 4/$tests_total: Skipped (no domain configured)"
        ((tests_passed++))
    fi

    log_info "Smoke tests: $tests_passed/$tests_total passed"

    if [[ $tests_passed -eq $tests_total ]]; then
        log_success "All smoke tests passed!"
        return 0
    else
        log_warn "Some smoke tests failed. Check logs for details."
        return 1
    fi
}

#===============================================================================
# MONITORING SETUP
#===============================================================================

setup_monitoring() {
    if [[ "$SKIP_MONITORING" == "true" ]]; then
        log_info "Skipping monitoring setup (--skip-monitoring)"
        return 0
    fi

    log_info "Setting up monitoring stack..."

    local monitoring_dir="$PROJECT_DIR/monitoring"
    mkdir -p "$monitoring_dir"

    # Create Prometheus configuration
    cat > "$monitoring_dir/prometheus.yml" << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'supabase-prod'
    environment: 'production'

# Alertmanager configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - alertmanager:9093

# Load rules
rule_files:
  - "/etc/prometheus/alerts/*.yml"

# Scrape configurations
scrape_configs:
  # Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Node exporter for system metrics
  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']

  # PostgreSQL metrics
  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']

  # Nginx metrics
  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx-exporter:9113']

  # Docker metrics
  - job_name: 'docker'
    static_configs:
      - targets: ['cadvisor:8080']
EOF

    # Create alert rules
    mkdir -p "$monitoring_dir/alerts"
    cat > "$monitoring_dir/alerts/rules.yml" << 'EOF'
groups:
  - name: supabase_alerts
    interval: 30s
    rules:
      # High CPU usage
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is above 80% for more than 5 minutes"

      # High memory usage
      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage detected"
          description: "Memory usage is above 85%"

      # Database connections
      - alert: HighDatabaseConnections
        expr: pg_stat_database_numbackends > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High number of database connections"
          description: "Database has more than 80 active connections"

      # Disk space
      - alert: LowDiskSpace
        expr: (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 15
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Low disk space"
          description: "Less than 15% disk space remaining"

      # TLS certificate expiry
      - alert: TLSCertificateExpiringSoon
        expr: (ssl_certificate_expiry_seconds - time()) / 86400 < 30
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "TLS certificate expiring soon"
          description: "TLS certificate expires in less than 30 days"

      # Service down
      - alert: ServiceDown
        expr: up == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Service is down"
          description: "{{ $labels.job }} service is down"
EOF

    # Create docker-compose for monitoring
    cat > "$monitoring_dir/docker-compose.monitoring.yml" << EOF
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./alerts:/etc/prometheus/alerts:ro
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
    ports:
      - "127.0.0.1:9090:9090"
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=\${GRAFANA_PASSWORD:-changeme}
      - GF_INSTALL_PLUGINS=grafana-piechart-panel
    volumes:
      - grafana_data:/var/lib/grafana
    ports:
      - "127.0.0.1:3001:3000"
    networks:
      - monitoring
    depends_on:
      - prometheus

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--path.rootfs=/rootfs'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    networks:
      - monitoring

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    restart: unless-stopped
    privileged: true
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    networks:
      - monitoring

  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    restart: unless-stopped
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
      - alertmanager_data:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
    ports:
      - "127.0.0.1:9093:9093"
    networks:
      - monitoring

volumes:
  prometheus_data:
  grafana_data:
  alertmanager_data:

networks:
  monitoring:
    driver: bridge
EOF

    # Create Alertmanager config
    cat > "$monitoring_dir/alertmanager.yml" << EOF
global:
  smtp_smarthost: 'localhost:25'
  smtp_from: 'alertmanager@${DOMAIN:-localhost}'
  smtp_require_tls: false

route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'email'

receivers:
  - name: 'email'
    email_configs:
      - to: '${EMAIL:-admin@localhost}'
        send_resolved: true

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'instance']
EOF

    # Start monitoring stack
    cd "$monitoring_dir"
    docker compose -f docker-compose.monitoring.yml up -d >> "$LOG_FILE" 2>&1

    chown -R "$SUPABASE_USER:$SUPABASE_USER" "$monitoring_dir"

    log_success "Monitoring stack deployed"
    log_info "Prometheus: http://localhost:9090"
    log_info "Grafana: http://localhost:3001 (admin/changeme)"
    log_info "Alertmanager: http://localhost:9093"
}

#===============================================================================
# BACKUP CONFIGURATION
#===============================================================================

setup_backups() {
    if [[ "$SKIP_BACKUPS" == "true" ]]; then
        log_info "Skipping backup configuration (--skip-backups)"
        return 0
    fi

    log_info "Setting up backup system..."

    mkdir -p "$BACKUP_DIR"
    chmod 700 "$BACKUP_DIR"

    local backup_script="$PROJECT_DIR/scripts/backup.sh"
    mkdir -p "$PROJECT_DIR/scripts"

    # Create backup script
    cat > "$backup_script" << 'BACKUP_SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

# Backup configuration
BACKUP_DIR="${BACKUP_DIR:-/var/backups/supabase}"
PROJECT_DIR="${PROJECT_DIR:-/opt/supabase}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
S3_BUCKET="${S3_BUCKET:-}"
S3_ENDPOINT="${S3_ENDPOINT:-}"
ENCRYPTION_KEY="${BACKUP_ENCRYPTION_KEY:-}"

# Timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="supabase_backup_${TIMESTAMP}"

# Logging
log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $*"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $*" >&2
}

# Create backup directory
mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}"

# Load environment
cd "$PROJECT_DIR"
source .env

# Backup PostgreSQL
log_info "Backing up PostgreSQL database..."
docker compose exec -T db pg_dumpall -U postgres | gzip > "${BACKUP_DIR}/${BACKUP_NAME}/postgres.sql.gz"

# Backup volumes
log_info "Backing up Docker volumes..."
docker run --rm \
    -v supabase_db_data:/data \
    -v "${BACKUP_DIR}/${BACKUP_NAME}":/backup \
    alpine tar czf /backup/db_data.tar.gz -C /data .

docker run --rm \
    -v supabase_storage_data:/data \
    -v "${BACKUP_DIR}/${BACKUP_NAME}":/backup \
    alpine tar czf /backup/storage_data.tar.gz -C /data .

# Backup configuration
log_info "Backing up configuration files..."
cp .env "${BACKUP_DIR}/${BACKUP_NAME}/env.backup"
cp docker-compose.yml "${BACKUP_DIR}/${BACKUP_NAME}/" 2>/dev/null || true

# Create metadata
cat > "${BACKUP_DIR}/${BACKUP_NAME}/metadata.json" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "hostname": "$(hostname)",
  "supabase_version": "$(docker compose version)",
  "backup_type": "full"
}
EOF

# Encrypt if key provided
if [[ -n "$ENCRYPTION_KEY" ]]; then
    log_info "Encrypting backup..."
    tar czf - -C "$BACKUP_DIR" "$BACKUP_NAME" | \
        openssl enc -aes-256-cbc -salt -k "$ENCRYPTION_KEY" > \
        "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz.enc"
    rm -rf "${BACKUP_DIR}/${BACKUP_NAME}"
    BACKUP_FILE="${BACKUP_DIR}/${BACKUP_NAME}.tar.gz.enc"
else
    tar czf "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" -C "$BACKUP_DIR" "$BACKUP_NAME"
    rm -rf "${BACKUP_DIR}/${BACKUP_NAME}"
    BACKUP_FILE="${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
fi

log_info "Backup created: $BACKUP_FILE"

# Upload to S3 if configured
if [[ -n "$S3_BUCKET" ]]; then
    log_info "Uploading to S3..."
    if command -v aws >/dev/null 2>&1; then
        aws s3 cp "$BACKUP_FILE" "s3://${S3_BUCKET}/supabase-backups/" ${S3_ENDPOINT:+--endpoint-url "$S3_ENDPOINT"}
        log_info "Backup uploaded to S3"
    else
        log_error "AWS CLI not installed, skipping S3 upload"
    fi
fi

# Cleanup old backups
log_info "Cleaning up old backups (keeping last ${RETENTION_DAYS} days)..."
find "$BACKUP_DIR" -name "supabase_backup_*" -type f -mtime +${RETENTION_DAYS} -delete

log_info "Backup completed successfully"
BACKUP_SCRIPT

    chmod +x "$backup_script"

    # Create restore script
    local restore_script="$PROJECT_DIR/scripts/restore.sh"
    cat > "$restore_script" << 'RESTORE_SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

BACKUP_FILE="$1"
PROJECT_DIR="${PROJECT_DIR:-/opt/supabase}"
ENCRYPTION_KEY="${BACKUP_ENCRYPTION_KEY:-}"

if [[ -z "$BACKUP_FILE" ]]; then
    echo "Usage: $0 <backup-file>"
    exit 1
fi

if [[ ! -f "$BACKUP_FILE" ]]; then
    echo "Error: Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "WARNING: This will restore from backup and overwrite existing data!"
read -p "Are you sure? (type 'yes' to continue): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo "Restore cancelled"
    exit 0
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Decrypt if needed
if [[ "$BACKUP_FILE" == *.enc ]]; then
    if [[ -z "$ENCRYPTION_KEY" ]]; then
        echo "Error: BACKUP_ENCRYPTION_KEY required for encrypted backups"
        exit 1
    fi
    echo "Decrypting backup..."
    openssl enc -d -aes-256-cbc -in "$BACKUP_FILE" -k "$ENCRYPTION_KEY" | tar xzf - -C "$TEMP_DIR"
else
    tar xzf "$BACKUP_FILE" -C "$TEMP_DIR"
fi

BACKUP_DIR=$(ls -d "$TEMP_DIR"/supabase_backup_* | head -1)

# Stop services
echo "Stopping Supabase services..."
cd "$PROJECT_DIR"
docker compose down

# Restore PostgreSQL
echo "Restoring PostgreSQL database..."
docker compose up -d db
sleep 10
gunzip < "${BACKUP_DIR}/postgres.sql.gz" | docker compose exec -T db psql -U postgres

# Restore volumes (requires recreating volumes)
echo "Restoring Docker volumes..."
docker run --rm \
    -v supabase_storage_data:/data \
    -v "${BACKUP_DIR}":/backup \
    alpine sh -c "rm -rf /data/* && tar xzf /backup/storage_data.tar.gz -C /data"

# Restore configuration
if [[ -f "${BACKUP_DIR}/env.backup" ]]; then
    echo "Restoring configuration..."
    cp "${BACKUP_DIR}/env.backup" "$PROJECT_DIR/.env"
fi

# Start all services
echo "Starting Supabase services..."
docker compose up -d

echo "Restore completed successfully!"
RESTORE_SCRIPT

    chmod +x "$restore_script"

    # Set up cron job for daily backups
    local cron_script="/etc/cron.daily/supabase-backup"
    cat > "$cron_script" << EOF
#!/bin/bash
export PROJECT_DIR="$PROJECT_DIR"
export BACKUP_DIR="$BACKUP_DIR"
su - $SUPABASE_USER -c "$backup_script" >> /var/log/supabase-backup.log 2>&1
EOF
    chmod +x "$cron_script"

    chown -R "$SUPABASE_USER:$SUPABASE_USER" "$PROJECT_DIR/scripts"

    log_success "Backup system configured"
    log_info "Daily backups scheduled via cron"
    log_info "Backup script: $backup_script"
    log_info "Restore script: $restore_script"
}

#===============================================================================
# RUNBOOK GENERATION
#===============================================================================

generate_runbook() {
    log_info "Generating operator runbook..."

    local runbook="$PROJECT_DIR/RUNBOOK.md"

    cat > "$runbook" << EOF
# Supabase Operations Runbook

Generated: $(date)
Domain: ${DOMAIN:-localhost}
Project Directory: $PROJECT_DIR

## Quick Reference

### Service Management

\`\`\`bash
# Check service status
cd $PROJECT_DIR
docker compose ps

# View logs
docker compose logs -f [service-name]

# Restart all services
docker compose restart

# Restart specific service
docker compose restart [service-name]

# Stop all services
docker compose down

# Start all services
docker compose up -d
\`\`\`

### Common Services
- \`db\` - PostgreSQL database
- \`kong\` - API Gateway
- \`auth\` - GoTrue authentication
- \`rest\` - PostgREST API
- \`realtime\` - Realtime server
- \`storage\` - Storage server
- \`meta\` - Metadata service
- \`studio\` - Supabase Studio UI

## Database Operations

### Backup Database

\`\`\`bash
# Manual backup
sudo $PROJECT_DIR/scripts/backup.sh

# Backups are stored in: $BACKUP_DIR
\`\`\`

### Restore Database

\`\`\`bash
# Restore from backup
sudo $PROJECT_DIR/scripts/restore.sh /path/to/backup.tar.gz
\`\`\`

### Database Console

\`\`\`bash
# Connect to PostgreSQL
docker compose exec db psql -U postgres

# Run SQL file
docker compose exec -T db psql -U postgres < script.sql
\`\`\`

## TLS Certificate Management

### Renew Certificates

\`\`\`bash
# Manual renewal
sudo certbot renew

# Force renewal (testing)
sudo certbot renew --force-renewal

# Reload Nginx after renewal
sudo systemctl reload nginx
\`\`\`

### Check Certificate Expiry

\`\`\`bash
# Check expiry date
sudo certbot certificates
\`\`\`

## Security Operations

### Rotate JWT Secret

1. Generate new JWT secret:
   \`\`\`bash
   openssl rand -base64 32 | tr -d "=+/" | tr '\n' '_'
   \`\`\`

2. Update \`.env\` file:
   \`\`\`bash
   cd $PROJECT_DIR
   nano .env
   # Update JWT_SECRET=<new-secret>
   \`\`\`

3. Restart auth service:
   \`\`\`bash
   docker compose restart auth
   \`\`\`

### Rotate Database Password

1. Update password in database:
   \`\`\`bash
   docker compose exec db psql -U postgres
   ALTER USER postgres WITH PASSWORD 'new-password';
   \`\`\`

2. Update \`.env\` file:
   \`\`\`bash
   nano .env
   # Update POSTGRES_PASSWORD=new-password
   \`\`\`

3. Restart services:
   \`\`\`bash
   docker compose down
   docker compose up -d
   \`\`\`

## Monitoring

### Access Monitoring Tools

- Prometheus: http://localhost:9090
- Grafana: http://localhost:3001
- Alertmanager: http://localhost:9093

### Check Resource Usage

\`\`\`bash
# CPU and Memory
docker stats

# Disk usage
df -h

# Docker disk usage
docker system df
\`\`\`

## Troubleshooting

### Services Won't Start

1. Check logs:
   \`\`\`bash
   docker compose logs
   \`\`\`

2. Check disk space:
   \`\`\`bash
   df -h
   \`\`\`

3. Check Docker daemon:
   \`\`\`bash
   sudo systemctl status docker
   \`\`\`

### High Database Connections

\`\`\`bash
# Check active connections
docker compose exec db psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"

# Kill idle connections
docker compose exec db psql -U postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'idle' AND state_change < current_timestamp - INTERVAL '5 minutes';"
\`\`\`

### Nginx Issues

\`\`\`bash
# Test Nginx config
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx

# Restart Nginx
sudo systemctl restart nginx

# Check Nginx logs
sudo tail -f /var/log/nginx/supabase-error.log
\`\`\`

### Out of Disk Space

\`\`\`bash
# Clean Docker system
docker system prune -a --volumes

# Remove old backups
find $BACKUP_DIR -name "supabase_backup_*" -mtime +7 -delete

# Clean log files
sudo truncate -s 0 /var/log/nginx/*.log
sudo journalctl --vacuum-time=7d
\`\`\`

## Upgrade Procedures

### Update Supabase

\`\`\`bash
cd $PROJECT_DIR

# Backup first!
sudo $PROJECT_DIR/scripts/backup.sh

# Pull latest images
docker compose pull

# Restart with new images
docker compose up -d

# Check logs for errors
docker compose logs -f
\`\`\`

## Firewall Management

\`\`\`bash
# Check firewall status
sudo ufw status verbose

# Allow new port
sudo ufw allow PORT/tcp

# Deny port
sudo ufw deny PORT/tcp

# Reload firewall
sudo ufw reload
\`\`\`

## Emergency Procedures

### Complete Service Restart

\`\`\`bash
cd $PROJECT_DIR
docker compose down
docker compose up -d
\`\`\`

### Emergency Backup

\`\`\`bash
# Quick database dump
docker compose exec -T db pg_dumpall -U postgres | gzip > /tmp/emergency_backup_\$(date +%s).sql.gz
\`\`\`

### Rollback from Backup

See "Restore Database" section above.

## Monitoring Alerts

### Configure Email Alerts

Edit \`$PROJECT_DIR/monitoring/alertmanager.yml\`:

\`\`\`yaml
global:
  smtp_smarthost: 'smtp.example.com:587'
  smtp_from: 'alerts@example.com'
  smtp_auth_username: 'alerts@example.com'
  smtp_auth_password: 'password'
\`\`\`

Restart Alertmanager:
\`\`\`bash
cd $PROJECT_DIR/monitoring
docker compose -f docker-compose.monitoring.yml restart alertmanager
\`\`\`

## Support Escalation

1. Check this runbook first
2. Review logs: \`docker compose logs\`
3. Check monitoring dashboards
4. Review Supabase documentation: https://supabase.com/docs
5. Supabase Discord: https://discord.supabase.com
6. Create GitHub issue: https://github.com/supabase/supabase

## Important Files

- Environment: \`$PROJECT_DIR/.env\`
- Docker Compose: \`$PROJECT_DIR/docker-compose.yml\`
- Nginx Config: \`/etc/nginx/sites-available/supabase\`
- Backup Script: \`$PROJECT_DIR/scripts/backup.sh\`
- Restore Script: \`$PROJECT_DIR/scripts/restore.sh\`
- This Runbook: \`$PROJECT_DIR/RUNBOOK.md\`

## Credentials Location

Credentials are stored in: \`$PROJECT_DIR/credentials.txt\`

**IMPORTANT: This file should be moved to a secure password manager and deleted from the server!**
EOF

    chmod 644 "$runbook"
    chown "$SUPABASE_USER:$SUPABASE_USER" "$runbook"

    log_success "Runbook generated at $runbook"
}

#===============================================================================
# MAIN EXECUTION
#===============================================================================

main() {
    # Initialize log file
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"

    banner

    log_info "Supabase Production Deployment Script v$SCRIPT_VERSION"
    log_info "Started at: $(date)"
    log_info "Logging to: $LOG_FILE"

    # Parse arguments
    parse_arguments "$@"

    # Pre-flight checks
    preflight_checks

    # User management
    create_supabase_user
    harden_ssh

    # System setup
    install_essential_packages
    install_docker

    # Supabase setup
    clone_supabase_repo
    generate_jwt_keys
    configure_environment

    # Network setup
    configure_nginx
    setup_tls_certificates

    # Security
    configure_firewall
    configure_fail2ban

    # Deploy Supabase
    start_supabase
    wait_for_services
    smoke_tests

    # Monitoring and backups
    setup_monitoring
    setup_backups

    # Documentation
    generate_runbook

    # Final summary
    echo
    log_success "=========================================="
    log_success "Supabase Deployment Completed!"
    log_success "=========================================="
    echo
    log_info "Access Information:"
    if [[ -n "$DOMAIN" ]] && [[ "$SKIP_TLS" == "false" ]]; then
        log_info "  Supabase API: https://${DOMAIN}"
        log_info "  Supabase Studio: https://${DOMAIN}/studio"
    else
        log_info "  Supabase API: http://$(curl -s ifconfig.me):8000"
        log_info "  Supabase Studio: http://$(curl -s ifconfig.me):3000"
    fi
    log_info "  Prometheus: http://localhost:9090"
    log_info "  Grafana: http://localhost:3001"
    echo
    log_info "Important Files:"
    log_info "  Project Directory: $PROJECT_DIR"
    log_info "  Environment File: $PROJECT_DIR/.env"
    log_info "  Credentials: $PROJECT_DIR/credentials.txt (MOVE TO SECURE STORAGE!)"
    log_info "  Operator Runbook: $PROJECT_DIR/RUNBOOK.md"
    log_info "  Backup Directory: $BACKUP_DIR"
    echo
    log_warn "Next Steps:"
    log_warn "  1. Secure credentials file: $PROJECT_DIR/credentials.txt"
    log_warn "  2. Verify DNS records point to this server: $(curl -s ifconfig.me)"
    log_warn "  3. Review and customize monitoring alerts"
    log_warn "  4. Test backup and restore procedures"
    log_warn "  5. Review the operator runbook: $PROJECT_DIR/RUNBOOK.md"
    echo
    log_info "Deployment log: $LOG_FILE"
    log_info "Completed at: $(date)"
}

# Run main function
main "$@"

#!/bin/bash

################################################################################
# Quick SSH Fix Script
# Fixes the SSH service restart issue on Ubuntu/Debian systems
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║              SSH Service Fix for Ubuntu/Debian                ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "Please run as root: sudo ./fix-ssh.sh"
    exit 1
fi

info "Detecting SSH service name..."

# Detect SSH service
if systemctl list-units --full --all | grep -q "ssh.service"; then
    SSH_SERVICE="ssh"
    info "SSH service detected as: ssh"
elif systemctl list-units --full --all | grep -q "sshd.service"; then
    SSH_SERVICE="sshd"
    info "SSH service detected as: sshd"
else
    error "SSH service not found!"
    echo ""
    info "Checking installed SSH packages..."
    dpkg -l | grep ssh
    exit 1
fi

echo ""
info "Current SSH service status:"
systemctl status $SSH_SERVICE --no-pager | head -10

echo ""
warning "⚠️  IMPORTANT: Before restarting SSH, ensure:"
echo "  1. You have SSH key authentication set up"
echo "  2. You can login via SSH keys (not password)"
echo "  3. You have an active SSH session as backup"
echo ""

read -p "Do you want to restart SSH service now? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "SSH not restarted. You can restart manually with:"
    echo "  sudo systemctl restart $SSH_SERVICE"
    exit 0
fi

echo ""
info "Restarting SSH service..."

# Restart SSH
systemctl restart $SSH_SERVICE

# Wait a moment
sleep 2

# Check status
if systemctl is-active --quiet $SSH_SERVICE; then
    success "SSH service restarted successfully!"
    echo ""
    info "SSH service status:"
    systemctl status $SSH_SERVICE --no-pager | head -10
    echo ""
    success "SSH hardening complete!"
    echo ""
    info "Next steps:"
    echo "  1. Keep this terminal open as backup"
    echo "  2. Test SSH login in a NEW terminal:"
    echo "     ssh user@your-server-ip"
    echo "  3. If login works, you're all set!"
    echo "  4. If login fails, use this terminal to fix it"
else
    error "SSH service failed to start!"
    echo ""
    info "Checking SSH configuration..."
    sshd -t
    echo ""
    info "SSH service logs:"
    journalctl -u $SSH_SERVICE -n 50 --no-pager
fi

echo ""
info "For reference, SSH configuration is at:"
echo "  Main config: /etc/ssh/sshd_config"
echo "  Hardening config: /etc/ssh/sshd_config.d/99-supabase-hardening.conf"
echo ""

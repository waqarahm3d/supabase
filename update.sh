#!/bin/bash

# Update script for Supabase

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
echo "║         Supabase Update Script                                ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run this script as root or with sudo"
    exit 1
fi

print_warning "This script will:"
echo "  1. Create a backup of your current setup"
echo "  2. Pull the latest Docker images"
echo "  3. Restart all services"
echo "  4. Verify everything is working"
echo ""
read -p "Do you want to continue? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Update cancelled."
    exit 0
fi

# Create pre-update backup
print_info "Creating pre-update backup..."
./backup.sh
print_success "Backup created!"

# Check current versions
print_info "Current Docker images:"
docker-compose images

# Pull latest images
print_info "Pulling latest Docker images..."
docker-compose pull

# Show new versions
print_info "New Docker images:"
docker-compose images

# Stop services
print_info "Stopping services..."
docker-compose down

# Start services with new images
print_info "Starting services with updated images..."
docker-compose up -d

# Wait for services to initialize
print_info "Waiting for services to initialize (60 seconds)..."
for i in {1..60}; do
    echo -n "."
    sleep 1
done
echo ""

# Check health
print_info "Checking service health..."
sleep 10
./health-check.sh

echo ""
print_success "Update complete!"
echo ""
print_info "Please verify:"
echo "  1. Studio is accessible: https://studio.qoqnuz.com"
echo "  2. API is responding: https://db.qoqnuz.com/health"
echo "  3. Test your application functionality"
echo ""
print_info "If there are any issues, restore from backup:"
echo "  ./restore.sh backups/[latest_backup]"
echo ""

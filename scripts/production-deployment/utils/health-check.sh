#!/usr/bin/env bash
#===============================================================================
# Supabase Health Check Utility
# Performs comprehensive health checks on all Supabase services
#===============================================================================

set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-/opt/supabase}"
DOMAIN="${DOMAIN:-localhost}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

passed=0
failed=0
warnings=0

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((passed++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((failed++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((warnings++))
}

echo "=================================="
echo "Supabase Health Check"
echo "=================================="
echo

# 1. Docker Services
echo "1. Checking Docker Services..."
cd "$PROJECT_DIR"

if ! command -v docker >/dev/null 2>&1; then
    check_fail "Docker is not installed"
else
    check_pass "Docker is installed"
fi

if docker compose ps >/dev/null 2>&1; then
    check_pass "Docker Compose is working"

    # Check individual services
    services=("db" "kong" "auth" "rest" "realtime" "storage" "meta" "studio")
    for service in "${services[@]}"; do
        if docker compose ps "$service" 2>/dev/null | grep -q "running\|healthy"; then
            check_pass "Service $service is running"
        else
            check_fail "Service $service is not running"
        fi
    done
else
    check_fail "Docker Compose is not working"
fi

echo

# 2. Database Connectivity
echo "2. Checking Database..."
if docker compose exec -T db pg_isready -U postgres >/dev/null 2>&1; then
    check_pass "PostgreSQL is accepting connections"

    # Check database size
    db_size=$(docker compose exec -T db psql -U postgres -t -c "SELECT pg_size_pretty(pg_database_size('postgres'));" | tr -d ' ')
    echo "   Database size: $db_size"
else
    check_fail "PostgreSQL is not accepting connections"
fi

echo

# 3. API Endpoints
echo "3. Checking API Endpoints..."

# Kong
if curl -sf http://localhost:8000/health >/dev/null 2>&1; then
    check_pass "Kong API Gateway is responding"
else
    check_fail "Kong API Gateway is not responding"
fi

# Studio
if curl -sf http://localhost:3000 >/dev/null 2>&1; then
    check_pass "Studio is responding"
else
    check_fail "Studio is not responding"
fi

# REST API
if curl -sf http://localhost:8000/rest/v1/ 2>&1 | grep -q "JWT"; then
    check_pass "REST API is responding"
else
    check_warn "REST API response unexpected (may be configured correctly)"
fi

echo

# 4. TLS Certificates
echo "4. Checking TLS Certificates..."
if [[ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]]; then
    check_pass "TLS certificate exists"

    # Check expiry
    expiry_date=$(openssl x509 -enddate -noout -in "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" | cut -d'=' -f2)
    expiry_epoch=$(date -d "$expiry_date" +%s)
    now_epoch=$(date +%s)
    days_remaining=$(( (expiry_epoch - now_epoch) / 86400 ))

    if [[ $days_remaining -lt 30 ]]; then
        check_warn "Certificate expires in $days_remaining days"
    else
        check_pass "Certificate valid for $days_remaining days"
    fi
else
    check_warn "TLS certificate not found (may be using --skip-tls)"
fi

echo

# 5. Nginx
echo "5. Checking Nginx..."
if systemctl is-active --quiet nginx; then
    check_pass "Nginx is running"

    if nginx -t >/dev/null 2>&1; then
        check_pass "Nginx configuration is valid"
    else
        check_fail "Nginx configuration has errors"
    fi
else
    check_warn "Nginx is not running"
fi

echo

# 6. Firewall
echo "6. Checking Firewall..."
if command -v ufw >/dev/null 2>&1; then
    if ufw status | grep -q "Status: active"; then
        check_pass "UFW firewall is active"

        # Check required ports
        if ufw status | grep -q "80/tcp"; then
            check_pass "Port 80 is allowed"
        else
            check_warn "Port 80 is not explicitly allowed"
        fi

        if ufw status | grep -q "443/tcp"; then
            check_pass "Port 443 is allowed"
        else
            check_warn "Port 443 is not explicitly allowed"
        fi
    else
        check_warn "UFW firewall is not active"
    fi
else
    check_warn "UFW is not installed"
fi

echo

# 7. System Resources
echo "7. Checking System Resources..."

# Disk space
disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [[ $disk_usage -lt 80 ]]; then
    check_pass "Disk usage is ${disk_usage}%"
else
    check_warn "Disk usage is high: ${disk_usage}%"
fi

# Memory
memory_usage=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
if [[ $memory_usage -lt 85 ]]; then
    check_pass "Memory usage is ${memory_usage}%"
else
    check_warn "Memory usage is high: ${memory_usage}%"
fi

# CPU Load
load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
echo "   System load: $load_avg"

echo

# 8. Monitoring
echo "8. Checking Monitoring Stack..."
if [[ -d "$PROJECT_DIR/monitoring" ]]; then
    cd "$PROJECT_DIR/monitoring"

    # Prometheus
    if curl -sf http://localhost:9090/-/healthy >/dev/null 2>&1; then
        check_pass "Prometheus is healthy"
    else
        check_warn "Prometheus is not responding"
    fi

    # Grafana
    if curl -sf http://localhost:3001/api/health >/dev/null 2>&1; then
        check_pass "Grafana is healthy"
    else
        check_warn "Grafana is not responding"
    fi

    # Alertmanager
    if curl -sf http://localhost:9093/-/healthy >/dev/null 2>&1; then
        check_pass "Alertmanager is healthy"
    else
        check_warn "Alertmanager is not responding"
    fi
else
    check_warn "Monitoring stack not found (may be using --skip-monitoring)"
fi

echo

# 9. Backups
echo "9. Checking Backup System..."
backup_dir="${BACKUP_DIR:-/var/backups/supabase}"

if [[ -d "$backup_dir" ]]; then
    check_pass "Backup directory exists"

    # Check for recent backups
    recent_backup=$(find "$backup_dir" -name "supabase_backup_*" -mtime -1 -type f 2>/dev/null | head -1)
    if [[ -n "$recent_backup" ]]; then
        check_pass "Recent backup found (less than 24 hours old)"
    else
        check_warn "No recent backup found (check backup cron job)"
    fi
else
    check_warn "Backup directory not found"
fi

# Check backup script
if [[ -x "$PROJECT_DIR/scripts/backup.sh" ]]; then
    check_pass "Backup script is executable"
else
    check_warn "Backup script not found or not executable"
fi

echo

# Summary
echo "=================================="
echo "Health Check Summary"
echo "=================================="
echo -e "${GREEN}Passed:${NC} $passed"
echo -e "${YELLOW}Warnings:${NC} $warnings"
echo -e "${RED}Failed:${NC} $failed"
echo

if [[ $failed -eq 0 ]]; then
    echo -e "${GREEN}Overall Status: HEALTHY${NC}"
    exit 0
elif [[ $failed -lt 3 ]]; then
    echo -e "${YELLOW}Overall Status: DEGRADED${NC}"
    exit 1
else
    echo -e "${RED}Overall Status: UNHEALTHY${NC}"
    exit 2
fi

#!/bin/bash

# Monitoring script for Supabase
# Run this periodically (via cron) to monitor system health

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ALERT_EMAIL="${ALERT_EMAIL:-admin@qoqnuz.com}"
LOG_FILE="/var/log/supabase-monitor.log"
ALERT_FILE="/tmp/supabase-alert-sent"
ALERT_COOLDOWN=3600  # Don't send alerts more than once per hour

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to send alert
send_alert() {
    local subject="$1"
    local message="$2"

    # Check if we've sent an alert recently
    if [ -f "$ALERT_FILE" ]; then
        last_alert=$(stat -c %Y "$ALERT_FILE" 2>/dev/null || echo 0)
        current_time=$(date +%s)
        time_diff=$((current_time - last_alert))

        if [ $time_diff -lt $ALERT_COOLDOWN ]; then
            log_message "Skipping alert (cooldown period)"
            return
        fi
    fi

    # Send email alert (if mail is configured)
    if command -v mail &> /dev/null; then
        echo "$message" | mail -s "$subject" "$ALERT_EMAIL"
        log_message "Alert sent: $subject"
        touch "$ALERT_FILE"
    else
        log_message "WARNING: mail command not found, cannot send alerts"
    fi
}

# Start monitoring
log_message "=== Starting Supabase Health Monitor ==="

# Check if services are running
check_services() {
    local failed_services=""
    local all_services=(db kong auth rest storage realtime meta studio analytics)

    for service in "${all_services[@]}"; do
        if ! docker-compose ps | grep "supabase-$service" | grep -q "Up"; then
            failed_services="$failed_services $service"
            log_message "ERROR: Service $service is not running"
        fi
    done

    if [ -n "$failed_services" ]; then
        send_alert "Supabase Alert: Services Down" "The following services are not running:$failed_services"
        return 1
    else
        log_message "OK: All services are running"
        return 0
    fi
}

# Check database connectivity
check_database() {
    if docker exec supabase-db pg_isready -U postgres &>/dev/null; then
        log_message "OK: Database is accessible"
        return 0
    else
        log_message "ERROR: Database is not accessible"
        send_alert "Supabase Alert: Database Down" "PostgreSQL database is not responding"
        return 1
    fi
}

# Check API endpoint
check_api() {
    if curl -s -f http://localhost:8000/health &>/dev/null; then
        log_message "OK: API endpoint is responding"
        return 0
    else
        log_message "ERROR: API endpoint is not responding"
        send_alert "Supabase Alert: API Down" "Kong API Gateway is not responding"
        return 1
    fi
}

# Check disk space
check_disk_space() {
    local threshold=80
    local usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')

    if [ "$usage" -gt "$threshold" ]; then
        log_message "WARNING: Disk usage is at ${usage}%"
        send_alert "Supabase Alert: High Disk Usage" "Disk usage is at ${usage}%, threshold is ${threshold}%"
        return 1
    else
        log_message "OK: Disk usage is at ${usage}%"
        return 0
    fi
}

# Check memory usage
check_memory() {
    local threshold=90
    local usage=$(free | grep Mem | awk '{print int($3/$2 * 100)}')

    if [ "$usage" -gt "$threshold" ]; then
        log_message "WARNING: Memory usage is at ${usage}%"
        send_alert "Supabase Alert: High Memory Usage" "Memory usage is at ${usage}%, threshold is ${threshold}%"
        return 1
    else
        log_message "OK: Memory usage is at ${usage}%"
        return 0
    fi
}

# Check Docker container health
check_container_health() {
    local unhealthy_containers=$(docker ps --filter health=unhealthy --format "{{.Names}}")

    if [ -n "$unhealthy_containers" ]; then
        log_message "ERROR: Unhealthy containers detected: $unhealthy_containers"
        send_alert "Supabase Alert: Unhealthy Containers" "The following containers are unhealthy: $unhealthy_containers"
        return 1
    else
        log_message "OK: All containers are healthy"
        return 0
    fi
}

# Check backup age
check_backup_age() {
    local max_age=86400  # 24 hours in seconds
    local latest_backup=$(ls -t backups/ 2>/dev/null | head -1)

    if [ -z "$latest_backup" ]; then
        log_message "WARNING: No backups found"
        send_alert "Supabase Alert: No Backups" "No backup directory found. Please run ./backup.sh"
        return 1
    fi

    local backup_time=$(stat -c %Y "backups/$latest_backup" 2>/dev/null || echo 0)
    local current_time=$(date +%s)
    local age=$((current_time - backup_time))

    if [ $age -gt $max_age ]; then
        log_message "WARNING: Last backup is $(($age / 3600)) hours old"
        send_alert "Supabase Alert: Old Backup" "Last backup is $(($age / 3600)) hours old. Consider running ./backup.sh"
        return 1
    else
        log_message "OK: Last backup is $(($age / 3600)) hours old"
        return 0
    fi
}

# Check SSL certificate expiry
check_ssl_expiry() {
    local warning_days=30
    local cert_file="ssl/db.qoqnuz.com.crt"

    if [ ! -f "$cert_file" ]; then
        log_message "WARNING: SSL certificate not found"
        return 1
    fi

    local expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
    local expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null || echo 0)
    local current_epoch=$(date +%s)
    local days_left=$(( (expiry_epoch - current_epoch) / 86400 ))

    if [ $days_left -lt $warning_days ]; then
        log_message "WARNING: SSL certificate expires in $days_left days"
        send_alert "Supabase Alert: SSL Expiring Soon" "SSL certificate expires in $days_left days. Run certbot renew."
        return 1
    else
        log_message "OK: SSL certificate valid for $days_left days"
        return 0
    fi
}

# Run all checks
CHECKS_PASSED=0
CHECKS_FAILED=0

run_check() {
    local check_name="$1"
    local check_function="$2"

    if $check_function; then
        ((CHECKS_PASSED++))
    else
        ((CHECKS_FAILED++))
    fi
}

run_check "Services" check_services
run_check "Database" check_database
run_check "API" check_api
run_check "Disk Space" check_disk_space
run_check "Memory" check_memory
run_check "Container Health" check_container_health
run_check "Backup Age" check_backup_age
run_check "SSL Expiry" check_ssl_expiry

# Summary
log_message "=== Monitor Summary: $CHECKS_PASSED passed, $CHECKS_FAILED failed ==="

if [ $CHECKS_FAILED -gt 0 ]; then
    exit 1
else
    # Clear alert cooldown if all checks passed
    rm -f "$ALERT_FILE"
    exit 0
fi

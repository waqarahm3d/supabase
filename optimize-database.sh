#!/bin/bash

################################################################################
# Database Optimization Script
# Expert-level PostgreSQL tuning and maintenance
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
echo "║         Database Optimization & Maintenance                   ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Load environment
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    error ".env file not found"
    exit 1
fi

# Check if database is running
if ! docker exec supabase-db pg_isready -U postgres > /dev/null 2>&1; then
    error "Database is not running"
    exit 1
fi

info "Running database optimization..."
echo ""

# 1. Analyze database statistics
info "1. Analyzing database statistics..."
docker exec supabase-db psql -U postgres -d $POSTGRES_DB -c "ANALYZE;"
success "Statistics analyzed"

# 2. Vacuum database
info "2. Running VACUUM..."
docker exec supabase-db psql -U postgres -d $POSTGRES_DB -c "VACUUM (VERBOSE, ANALYZE);"
success "Database vacuumed"

# 3. Reindex database (if needed)
read -p "Run REINDEX? This may take time and lock tables (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    info "3. Reindexing database..."
    docker exec supabase-db psql -U postgres -d $POSTGRES_DB -c "REINDEX DATABASE $POSTGRES_DB;"
    success "Database reindexed"
else
    info "Skipping REINDEX"
fi

# 4. Check for bloat
info "4. Checking table bloat..."
docker exec supabase-db psql -U postgres -d $POSTGRES_DB << 'EOF'
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) AS indexes_size,
    round(100 * pg_total_relation_size(schemaname||'.'||tablename) / pg_database_size(current_database())) AS percent_of_db
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;
EOF

# 5. Check slow queries
info "5. Analyzing slow queries..."
docker exec supabase-db psql -U postgres -d $POSTGRES_DB << 'EOF'
SELECT
    substring(query, 1, 50) AS short_query,
    round(total_exec_time::numeric, 2) AS total_time_ms,
    calls,
    round(mean_exec_time::numeric, 2) AS avg_time_ms,
    round((100 * total_exec_time / sum(total_exec_time) OVER ())::numeric, 2) AS percentage
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;
EOF

# 6. Check index usage
info "6. Checking unused indexes..."
docker exec supabase-db psql -U postgres -d $POSTGRES_DB << 'EOF'
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan as index_scans,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_stat_user_indexes
WHERE idx_scan < 10
    AND schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_relation_size(indexrelid) DESC;
EOF

# 7. Check missing indexes
info "7. Suggesting missing indexes..."
docker exec supabase-db psql -U postgres -d $POSTGRES_DB << 'EOF'
SELECT
    schemaname,
    tablename,
    attname,
    n_distinct,
    correlation
FROM pg_stats
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
    AND n_distinct > 100
    AND correlation < 0.1
ORDER BY n_distinct DESC
LIMIT 10;
EOF

# 8. Check connection statistics
info "8. Connection statistics..."
docker exec supabase-db psql -U postgres -d $POSTGRES_DB << 'EOF'
SELECT
    datname,
    numbackends as connections,
    xact_commit as commits,
    xact_rollback as rollbacks,
    blks_read as blocks_read,
    blks_hit as blocks_hit,
    round(100 * blks_hit::numeric / nullif(blks_hit + blks_read, 0), 2) as cache_hit_ratio
FROM pg_stat_database
WHERE datname = current_database();
EOF

# 9. Optimize PostgreSQL config based on current usage
info "9. Generating optimized configuration..."

# Get current database size
DB_SIZE=$(docker exec supabase-db psql -U postgres -t -c "SELECT pg_database_size('$POSTGRES_DB');" | tr -d ' ')
DB_SIZE_MB=$((DB_SIZE / 1024 / 1024))

# Get available RAM
AVAILABLE_RAM=$(free -m | awk '/^Mem:/{print $2}')

# Calculate optimal settings
SHARED_BUFFERS=$((AVAILABLE_RAM / 4))
if [ $SHARED_BUFFERS -gt 2048 ]; then
    SHARED_BUFFERS=2048  # Max 2GB for safety
fi

EFFECTIVE_CACHE=$((AVAILABLE_RAM * 3 / 4))
WORK_MEM=$((AVAILABLE_RAM / 100))
MAINTENANCE_WORK_MEM=$((AVAILABLE_RAM / 16))

info "Current database size: ${DB_SIZE_MB}MB"
info "Available RAM: ${AVAILABLE_RAM}MB"
echo ""
info "Recommended settings:"
echo "  shared_buffers = ${SHARED_BUFFERS}MB"
echo "  effective_cache_size = ${EFFECTIVE_CACHE}MB"
echo "  work_mem = ${WORK_MEM}MB"
echo "  maintenance_work_mem = ${MAINTENANCE_WORK_MEM}MB"
echo ""

read -p "Apply these settings? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Backup current config
    cp volumes/db/postgresql.conf volumes/db/postgresql.conf.backup.$(date +%Y%m%d_%H%M%S)

    # Update config
    sed -i "s/^shared_buffers = .*/shared_buffers = ${SHARED_BUFFERS}MB/" volumes/db/postgresql.conf
    sed -i "s/^effective_cache_size = .*/effective_cache_size = ${EFFECTIVE_CACHE}MB/" volumes/db/postgresql.conf
    sed -i "s/^work_mem = .*/work_mem = ${WORK_MEM}MB/" volumes/db/postgresql.conf
    sed -i "s/^maintenance_work_mem = .*/maintenance_work_mem = ${MAINTENANCE_WORK_MEM}MB/" volumes/db/postgresql.conf

    warning "Database will be restarted to apply settings"
    read -p "Restart now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker-compose restart db
        sleep 10
        if docker exec supabase-db pg_isready -U postgres > /dev/null 2>&1; then
            success "Database restarted with new settings"
        else
            error "Database failed to restart. Restoring backup..."
            cp volumes/db/postgresql.conf.backup.* volumes/db/postgresql.conf
            docker-compose restart db
        fi
    fi
fi

# 10. Generate optimization report
info "10. Generating optimization report..."

cat > /tmp/db-optimization-report.txt << EOF
Database Optimization Report
Generated: $(date)
Database: $POSTGRES_DB
Size: ${DB_SIZE_MB}MB
Server RAM: ${AVAILABLE_RAM}MB

=== Current Configuration ===
shared_buffers: $(grep "^shared_buffers" volumes/db/postgresql.conf)
effective_cache_size: $(grep "^effective_cache_size" volumes/db/postgresql.conf)
work_mem: $(grep "^work_mem" volumes/db/postgresql.conf)
maintenance_work_mem: $(grep "^maintenance_work_mem" volumes/db/postgresql.conf)
max_connections: $(grep "^max_connections" volumes/db/postgresql.conf)

=== Recommendations ===
1. Run VACUUM ANALYZE weekly
2. Monitor slow queries using pg_stat_statements
3. Create indexes on frequently queried columns
4. Consider partitioning large tables (> 10M rows)
5. Set up regular reindexing for heavily updated tables
6. Monitor cache hit ratio (should be > 95%)

=== Next Optimization Run ===
Recommended: $(date -d "+1 week")

EOF

cat /tmp/db-optimization-report.txt

success "Optimization report saved to: /tmp/db-optimization-report.txt"

echo ""
success "Database optimization complete!"
echo ""
info "Next steps:"
echo "  1. Review slow queries and add indexes"
echo "  2. Monitor performance over next few days"
echo "  3. Run this script weekly for best results"
echo ""

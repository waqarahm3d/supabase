# Supabase Quick Reference Card

## 🚀 Access Points

- **Studio Dashboard**: http://studio.qoqnuz.com *(no port needed!)*
- **API Endpoint**: http://db.qoqnuz.com

## ⚡ Quick Commands

### Check System Health
```bash
./check-services.sh                 # Full health check
docker compose ps                   # Container status
docker stats                        # Resource usage
```

### Run Tests
```bash
./test-deployment.sh                # Comprehensive E2E tests (65 tests)
./audit-scripts.sh                  # Validate all scripts
```

### View Logs
```bash
docker compose logs -f              # All services (follow mode)
docker compose logs -f kong         # Specific service
docker compose logs --tail=100      # Last 100 lines
```

### Restart Services
```bash
./restart-services.sh               # Interactive restart tool
docker compose restart              # Restart all
docker compose restart kong         # Restart specific service
```

### Database Operations
```bash
# Connect to database
docker exec -it supabase-db psql -U postgres

# Database size
docker exec supabase-db psql -U postgres -c \
  "SELECT pg_size_pretty(pg_database_size('postgres'));"

# Active connections
docker exec supabase-db psql -U postgres -c \
  "SELECT count(*) FROM pg_stat_activity;"

# Backup
docker exec supabase-db pg_dump -U postgres postgres | gzip > backup-$(date +%Y%m%d).sql.gz
```

### Fix Common Issues
```bash
./fix-database-passwords.sh         # Reset database passwords
./fix-port-conflict.sh              # Resolve port 80 conflicts
docker compose up -d                # Start all services
docker compose restart              # Restart all services
```

## 📊 All 11 Services

| Service | Container Name | Purpose |
|---------|----------------|---------|
| **PostgreSQL** | supabase-db | Database |
| **Auth** | supabase-auth | Authentication (GoTrue) |
| **REST** | supabase-rest | REST API (PostgREST) |
| **Realtime** | realtime-dev.supabase-realtime | WebSocket & Realtime |
| **Storage** | supabase-storage | File storage (S3-compatible) |
| **Kong** | supabase-kong | API Gateway (ports 80/443) |
| **Studio** | supabase-studio | Dashboard UI |
| **Analytics** | supabase-analytics | Logging (Logflare) |
| **Edge Functions** | supabase-edge-functions | Serverless functions (Deno) |
| **ImgProxy** | supabase-imgproxy | Image optimization |
| **Meta** | supabase-meta | Database management |

## 🔥 Emergency Commands

### All Services Down
```bash
docker compose up -d
sleep 20
./check-services.sh
```

### Database Won't Start
```bash
docker compose logs db              # Check error
docker compose restart db           # Restart
docker exec supabase-db pg_isready  # Test connection
```

### Kong Not Responding
```bash
docker compose logs kong            # Check error
docker compose restart kong         # Restart
sleep 15                            # Wait for initialization
curl http://localhost/              # Test
```

### Port 80 Conflict
```bash
sudo lsof -i :80                    # What's using port 80?
./fix-port-conflict.sh              # Auto-resolve
```

### Out of Memory
```bash
docker stats                        # Check usage
docker compose restart              # Restart services
# Consider reducing PostgreSQL max_connections in volumes/db/postgresql.conf
```

### Can't Access Studio
```bash
# Check Kong is running
docker compose ps kong

# Check Studio container
docker compose ps studio

# Test locally
curl http://localhost/

# Check DNS
ping studio.qoqnuz.com

# Check firewall
sudo ufw status | grep 80
```

## 📁 Important Files

| File | Purpose |
|------|---------|
| `.env` | Environment variables (NOT in git) |
| `docker-compose.yml` | Service orchestration |
| `volumes/api/kong.yml` | Kong API gateway config |
| `volumes/db/postgresql.conf` | PostgreSQL optimization |
| `volumes/logs/gcloud.json` | Analytics configuration |

## 🔐 Security

### View Current Keys
```bash
# Load environment
source <(grep -v '^#' .env | sed 's/^/export /')

# Display (be careful - these are sensitive!)
echo "Anon Key: $ANON_KEY"
echo "Service Role Key: $SERVICE_ROLE_KEY"
echo "JWT Secret: $JWT_SECRET"
```

### Regenerate Keys
```bash
./configure-env.sh                  # Interactive wizard
docker compose up -d                # Apply changes
./test-deployment.sh                # Verify
```

### Check Security
```bash
# Firewall status
sudo ufw status

# Fail2ban status
sudo fail2ban-client status

# Check for exposed secrets
grep -r "your-super-secret" .env    # Should be empty
```

## 📈 Monitoring

### Check Disk Space
```bash
df -h                               # Overall disk
du -sh volumes/*                    # Supabase volumes
```

### Database Metrics
```bash
docker exec supabase-db psql -U postgres -c "
  SELECT
    datname,
    pg_size_pretty(pg_database_size(datname)) as size,
    (SELECT count(*) FROM pg_stat_activity WHERE datname=d.datname) as connections
  FROM pg_database d
  WHERE datname NOT IN ('template0', 'template1');
"
```

### Service Uptime
```bash
docker compose ps --format "table {{.Service}}\t{{.Status}}"
```

## 🎯 Performance Tuning

### PostgreSQL Connections
```bash
# View current connections
docker exec supabase-db psql -U postgres -c \
  "SELECT count(*), state FROM pg_stat_activity GROUP BY state;"

# Kill idle connections (if needed)
docker exec supabase-db psql -U postgres -c \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity
   WHERE state='idle' AND state_change < now() - interval '1 hour';"
```

### Clear Docker Logs (if too large)
```bash
# Check log sizes
du -sh /var/lib/docker/containers/*/*-json.log

# Truncate logs
sudo truncate -s 0 /var/lib/docker/containers/*/*-json.log
```

## 📚 Documentation

- **FINAL-VERIFICATION.md** - Verification steps to run on your server
- **PRODUCTION-READY-SUMMARY.md** - Complete deployment status
- **DEPLOYMENT-GUIDE.md** - Full deployment guide (900+ lines)
- **README.md** - Quick start guide
- **.env.example** - Environment template

## 🆘 Getting Help

1. Run `./check-services.sh` first
2. Check logs: `docker compose logs`
3. Review DEPLOYMENT-GUIDE.md troubleshooting section
4. Check specific service: `docker compose logs <service-name>`
5. Verify environment: `cat .env | grep -v '#' | grep -v '^$'`

## ✅ Regular Maintenance

### Daily
- Run `./check-services.sh` once
- Monitor disk space: `df -h`

### Weekly
- Run `./test-deployment.sh`
- Check for errors: `docker compose logs --tail=1000 | grep -i error`
- Review resource usage: `docker stats`

### Monthly
- Update images: `docker compose pull && docker compose up -d`
- Vacuum database: `docker exec supabase-db psql -U postgres -c "VACUUM ANALYZE;"`
- System updates: `apt-get update && apt-get upgrade -y`
- Verify backups work

---

**Everything you need at your fingertips! 🚀**

For detailed information, see PRODUCTION-READY-SUMMARY.md

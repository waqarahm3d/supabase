# Supabase Operations - Quick Reference Card

**Print this and keep it handy for emergency operations**

## 🚨 Emergency Contacts & Escalation

```
Team Lead:     ___________________________
On-Call:       ___________________________
Vendor:        https://discord.supabase.com
Documentation: /opt/supabase/RUNBOOK.md
```

## 📍 Critical Paths

```
Project Dir:    /opt/supabase
Environment:    /opt/supabase/.env
Credentials:    DELETED (in password manager)
Backups:        /var/backups/supabase
Logs:           /var/log/supabase-*.log
Nginx Logs:     /var/log/nginx/supabase-*.log
```

## ⚡ Emergency Commands

### Service Down - Restart Everything
```bash
cd /opt/supabase
docker compose restart
# Wait 30 seconds
docker compose ps
```

### Database Emergency
```bash
# Check PostgreSQL
docker compose exec db pg_isready -U postgres

# View connections
docker compose exec db psql -U postgres -c \
  "SELECT count(*), state FROM pg_stat_activity GROUP BY state;"

# Kill idle connections (if needed)
docker compose exec db psql -U postgres -c \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity \
   WHERE state = 'idle' AND state_change < current_timestamp - INTERVAL '5 minutes';"
```

### Emergency Backup NOW
```bash
docker compose exec -T db pg_dumpall -U postgres | \
  gzip > /tmp/emergency_$(date +%s).sql.gz
# Copy to safe location immediately
```

### Out of Disk Space
```bash
# Check usage
df -h

# Clean Docker
docker system prune -a --volumes -f

# Clean logs
sudo journalctl --vacuum-time=3d
sudo truncate -s 0 /var/log/nginx/*.log

# Remove old backups
find /var/backups/supabase -mtime +3 -delete
```

### Certificate Expired
```bash
# Renew immediately
sudo certbot renew --force-renewal
sudo systemctl reload nginx
```

### Too Many Failed Login Attempts (fail2ban)
```bash
# Check ban list
sudo fail2ban-client status sshd

# Unban IP
sudo fail2ban-client set sshd unbanip <IP_ADDRESS>
```

## 🔧 Common Operations

### Check Service Status
```bash
cd /opt/supabase
docker compose ps
# All should show: running/healthy
```

### View Logs (Real-time)
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f auth    # Authentication
docker compose logs -f db      # Database
docker compose logs -f kong    # API Gateway
docker compose logs -f rest    # REST API
```

### Restart Single Service
```bash
docker compose restart SERVICE_NAME
# Services: db, kong, auth, rest, realtime, storage, meta, studio
```

### Health Check
```bash
sudo /opt/supabase/utils/health-check.sh
```

### Manual Backup
```bash
sudo /opt/supabase/scripts/backup.sh
```

### Restore from Backup
```bash
sudo /opt/supabase/scripts/restore.sh /path/to/backup.tar.gz
# WARNING: This stops services and overwrites data!
```

## 🔍 Diagnostics

### Check Resource Usage
```bash
# CPU and Memory
htop
# or
docker stats

# Disk
df -h

# Network
netstat -tlnp | grep -E ':(80|443|8000|5432)'
```

### Check API Endpoints
```bash
# Health
curl https://DOMAIN/health

# Kong
curl http://localhost:8000/health

# Studio
curl http://localhost:3000
```

### Check Firewall
```bash
sudo ufw status verbose
```

### Check TLS Certificate
```bash
sudo certbot certificates
# or
echo | openssl s_client -connect DOMAIN:443 2>/dev/null | \
  openssl x509 -noout -dates
```

### Database Connection String
```bash
# Internal (from Docker)
postgresql://postgres:PASSWORD@db:5432/postgres

# External (if exposed)
postgresql://postgres:PASSWORD@DOMAIN:5432/postgres
```

## 📊 Monitoring Access (SSH Tunnel)

```bash
# From your laptop
ssh -L 9090:localhost:9090 supabase@SERVER  # Prometheus
ssh -L 3001:localhost:3001 supabase@SERVER  # Grafana
ssh -L 9093:localhost:9093 supabase@SERVER  # Alertmanager

# Then access
http://localhost:9090  # Prometheus
http://localhost:3001  # Grafana
http://localhost:9093  # Alertmanager
```

## 🔐 Security Operations

### Rotate JWT Keys
```bash
sudo /opt/supabase/utils/rotate-jwt-keys.sh
# Follow prompts
# Update .env with new ANON_KEY and SERVICE_ROLE_KEY
```

### Change Database Password
```bash
# 1. Update password in database
docker compose exec db psql -U postgres
ALTER USER postgres WITH PASSWORD 'new-password';
\q

# 2. Update .env
sudo nano /opt/supabase/.env
# Update POSTGRES_PASSWORD=new-password

# 3. Restart
docker compose down
docker compose up -d
```

### Review fail2ban Bans
```bash
sudo fail2ban-client status
sudo fail2ban-client status sshd
```

## 📦 Updates

### Update Supabase Images
```bash
cd /opt/supabase

# 1. BACKUP FIRST!
sudo /opt/supabase/scripts/backup.sh

# 2. Pull new images
docker compose pull

# 3. Restart with new images
docker compose up -d

# 4. Check status
docker compose ps
docker compose logs -f
```

### Update System Packages
```bash
sudo apt update
sudo apt upgrade -y
sudo reboot  # If kernel updated
```

## 🔔 Alert Thresholds (Defaults)

- CPU Usage: > 80% for 5 min → WARNING
- Memory Usage: > 85% for 5 min → WARNING
- Disk Space: < 15% free → CRITICAL
- DB Connections: > 80 → WARNING
- TLS Expiry: < 30 days → WARNING
- Service Down: > 2 min → CRITICAL

## 📱 Contact Vendor

**Supabase Community Support:**
- Discord: https://discord.supabase.com
- GitHub: https://github.com/supabase/supabase/issues
- Docs: https://supabase.com/docs

**For Enterprise Support:**
- Contact your Supabase account manager
- Or: support@supabase.com

## 🎯 Performance Baselines (Adjust for Your System)

```
Normal CPU: 10-30%
Normal Memory: 40-60%
Normal Disk I/O: < 50% utilized
DB Connections: < 50 active
API Response Time: < 100ms (p95)
```

## 🛠️ Useful One-Liners

```bash
# Count API requests in last hour (Nginx)
sudo grep "$(date -d '1 hour ago' '+%d/%b/%Y:%H')" \
  /var/log/nginx/supabase-access.log | wc -l

# Find slow queries (requires pg_stat_statements)
docker compose exec db psql -U postgres -c \
  "SELECT query, mean_exec_time FROM pg_stat_statements \
   ORDER BY mean_exec_time DESC LIMIT 10;"

# Check Docker disk usage
docker system df

# Check which service is using most CPU
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}" | sort -k2 -h

# Test database write performance
docker compose exec db psql -U postgres -c \
  "SELECT COUNT(*) FROM pg_stat_activity WHERE state = 'active';"
```

## 📋 Pre-Maintenance Checklist

Before planned maintenance:
- [ ] Notify users of maintenance window
- [ ] Run full backup: `sudo /opt/supabase/scripts/backup.sh`
- [ ] Verify backup completed: `ls -lh /var/backups/supabase/`
- [ ] Document current state: `docker compose ps > /tmp/pre-maint.txt`
- [ ] Take system snapshot (if cloud provider supports)

## 📋 Post-Incident Checklist

After resolving an incident:
- [ ] Services running: `docker compose ps`
- [ ] Run health check: `sudo /opt/supabase/utils/health-check.sh`
- [ ] Check logs for errors: `docker compose logs --tail=100`
- [ ] Verify API accessible: `curl https://DOMAIN/health`
- [ ] Check monitoring: Prometheus/Grafana
- [ ] Create backup: `sudo /opt/supabase/scripts/backup.sh`
- [ ] Document incident and resolution
- [ ] Update runbook if needed

## 🔄 Service Dependencies

```
        Internet
            ↓
        Nginx (80/443)
            ↓
        Kong (8000)
            ↓
    ┌───────┼───────┐
    ↓       ↓       ↓
  Auth   Storage  Rest ← All depend on PostgreSQL
    ↓       ↓       ↓
      PostgreSQL (5432)
```

If database is down, all services will fail.
If Kong is down, all API requests will fail.
If Nginx is down, external access will fail.

## 📖 More Info

Full documentation: `/opt/supabase/RUNBOOK.md`
Detailed README: `/opt/supabase/README.md` (if exists)
This directory: `/opt/supabase/`

---

**Last Updated:** _______________
**Maintained By:** _______________
**Version:** 1.0.0

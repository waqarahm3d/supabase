# Troubleshooting Guide

Common issues and their solutions for Supabase self-hosted setup.

## 🔍 General Diagnostic Commands

Before diving into specific issues, run these diagnostic commands:

```bash
# Check service status
docker-compose ps

# Check service health
./health-check.sh

# View all logs
docker-compose logs --tail=100

# Check system resources
free -h
df -h
docker stats --no-stream

# Test network connectivity
curl -v http://localhost:8000/health
curl -v https://db.qoqnuz.com/health
```

## 🚫 Common Issues

### 1. Services Won't Start

#### Symptom
```
Error: Container failed to start
```

#### Diagnosis
```bash
# Check specific service logs
docker-compose logs db
docker-compose logs kong
docker-compose logs auth

# Check for port conflicts
sudo netstat -tulpn | grep -E '(80|443|5432|8000|3000|4000)'

# Check disk space
df -h
```

#### Solutions

**Port already in use:**
```bash
# Find what's using the port
sudo lsof -i :8000

# Stop the conflicting service
sudo systemctl stop apache2
sudo systemctl stop nginx

# Or change port in .env
nano .env
# Change KONG_HTTP_PORT to 8001
```

**Out of disk space:**
```bash
# Clean up Docker
docker system prune -a

# Check volumes
du -sh volumes/

# Remove old backups
rm -rf backups/old_backup_dir
```

**Permission issues:**
```bash
# Fix permissions
sudo chown -R $(whoami):$(whoami) volumes/
sudo chmod -R 755 volumes/
```

### 2. Can't Access Studio

#### Symptom
- Browser shows "Connection refused"
- "This site can't be reached"
- SSL certificate error

#### Diagnosis
```bash
# Check DNS resolution
nslookup studio.qoqnuz.com

# Check if service is running
docker-compose ps studio

# Check studio logs
docker-compose logs studio

# Test direct connection
curl http://localhost:3000
```

#### Solutions

**DNS not pointing to server:**
```bash
# Verify your server IP
curl ifconfig.me

# Check DNS propagation
nslookup studio.qoqnuz.com
# Should show your server IP

# Wait for DNS propagation (can take 24-48 hours)
```

**SSL certificate issues:**
```bash
# Check certificates exist
ls -la ssl/

# Verify certificate
openssl x509 -in ssl/studio.qoqnuz.com.crt -text -noout

# Re-run SSL setup
./setup-ssl.sh
```

**Firewall blocking:**
```bash
# Check firewall
sudo ufw status

# Allow HTTPS
sudo ufw allow 443/tcp

# Check iptables
sudo iptables -L -n
```

**Service not running:**
```bash
# Restart specific service
docker-compose restart studio

# Or restart all
./stop.sh && ./start.sh
```

### 3. Database Connection Errors

#### Symptom
```
Error: Could not connect to database
FATAL: password authentication failed
Connection refused
```

#### Diagnosis
```bash
# Check database is running
docker-compose ps db

# Check database logs
docker-compose logs db | tail -50

# Test database connection
docker exec supabase-db pg_isready -U postgres

# Try connecting
docker exec -it supabase-db psql -U postgres
```

#### Solutions

**Database not initialized:**
```bash
# Check if data directory is empty
ls -la volumes/db/data/

# If empty, database needs initialization
docker-compose down
docker-compose up -d db
# Wait 30 seconds
docker-compose logs db
```

**Wrong password:**
```bash
# Check password in .env
grep POSTGRES_PASSWORD .env

# Update roles.sql if needed
nano volumes/db/roles.sql

# Restart database
docker-compose restart db
```

**Database crashed:**
```bash
# Check logs for crash
docker-compose logs db | grep -i "error\|fatal\|panic"

# Try restarting
docker-compose restart db

# If that fails, check data integrity
docker exec supabase-db pg_controldata /var/lib/postgresql/data
```

**Out of memory:**
```bash
# Check memory usage
free -h
docker stats supabase-db

# Reduce shared_buffers in postgresql.conf
nano volumes/db/postgresql.conf
# Change: shared_buffers = 512MB

# Restart
docker-compose restart db
```

### 4. API Returns 401 Unauthorized

#### Symptom
```
{
  "code": "401",
  "message": "Invalid API key"
}
```

#### Diagnosis
```bash
# Check if using correct API key
grep ANON_KEY .env

# Test with correct key
curl -H "apikey: YOUR_ANON_KEY" https://db.qoqnuz.com/rest/v1/
```

#### Solutions

**Using wrong API key:**
- Ensure using `ANON_KEY` for client-side requests
- `SERVICE_ROLE_KEY` should only be used server-side
- Copy keys from `credentials.txt` or `.env`

**JWT expired:**
```bash
# Check JWT expiry
# Decode JWT at jwt.io

# Regenerate if needed
./setup.sh
# Choose to regenerate keys
```

**Kong configuration issue:**
```bash
# Check Kong logs
docker-compose logs kong

# Restart Kong
docker-compose restart kong
```

### 5. Storage Upload Fails

#### Symptom
```
Error uploading file
413 Request Entity Too Large
```

#### Diagnosis
```bash
# Check storage service
docker-compose logs storage

# Check disk space
df -h

# Check storage directory permissions
ls -la volumes/storage/
```

#### Solutions

**File too large:**
```bash
# Increase file size limit in docker-compose.yml
nano docker-compose.yml
# Under storage service, change:
# FILE_SIZE_LIMIT: 104857600  # 100MB

# Restart
docker-compose restart storage
```

**Permissions issue:**
```bash
# Fix permissions
sudo chown -R 70:70 volumes/storage/
sudo chmod -R 755 volumes/storage/
```

**Out of disk space:**
```bash
# Check usage
du -sh volumes/storage/

# Clean up if needed
# (Carefully! This deletes files)
docker exec supabase-storage rm -rf /var/lib/storage/temp/*
```

### 6. Realtime Not Working

#### Symptom
- Websocket connection fails
- Real-time updates not received
- Connection timeout

#### Diagnosis
```bash
# Check realtime service
docker-compose ps realtime

# Check logs
docker-compose logs realtime

# Test websocket connection
curl -i -N -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  http://localhost:4000/socket/websocket
```

#### Solutions

**Service not running:**
```bash
docker-compose restart realtime
```

**Websocket blocked:**
```bash
# Check nginx/proxy config
# Ensure WebSocket upgrade headers are set

# In nginx.conf, verify:
# proxy_set_header Upgrade $http_upgrade;
# proxy_set_header Connection 'upgrade';
```

**Table not enabled for realtime:**
```sql
-- In Studio SQL editor or psql:
ALTER PUBLICATION supabase_realtime ADD TABLE your_table;
```

### 7. Authentication Issues

#### Symptom
- Can't sign up users
- Email not sending
- OAuth not working

#### Diagnosis
```bash
# Check auth service
docker-compose logs auth

# Check email configuration
grep SMTP .env

# Test SMTP connection
telnet smtp.gmail.com 587
```

#### Solutions

**Email signup disabled:**
```bash
# Enable in .env
nano .env
# Set: ENABLE_EMAIL_SIGNUP=true
# Set: DISABLE_SIGNUP=false

# Restart
docker-compose restart auth
```

**SMTP not configured:**
```bash
# Update SMTP settings in .env
nano .env
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password

# For Gmail, use App Password:
# https://support.google.com/accounts/answer/185833

# Restart
docker-compose restart auth
```

**OAuth provider not configured:**
- Configure in Studio → Authentication → Providers
- Add client ID and secret
- Set redirect URLs

### 8. High Memory Usage

#### Symptom
```
Server running slow
Out of memory errors
OOMKilled containers
```

#### Diagnosis
```bash
# Check memory usage
free -h
docker stats --no-stream

# Check which service is using memory
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}"

# Check for memory leaks
docker-compose logs | grep -i "out of memory\|oom"
```

#### Solutions

**Reduce PostgreSQL memory:**
```bash
# Edit postgresql.conf
nano volumes/db/postgresql.conf

# Reduce these values:
shared_buffers = 512MB         # Was 1GB
effective_cache_size = 2GB     # Was 3GB
work_mem = 8MB                 # Was 16MB

# Restart
docker-compose restart db
```

**Reduce max connections:**
```bash
# Edit postgresql.conf
nano volumes/db/postgresql.conf

# Change:
max_connections = 50           # Was 100

# Restart
docker-compose restart db
```

**Add swap space:**
```bash
# Create 2GB swap
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

**Restart services periodically:**
```bash
# Add to cron for weekly restart
(crontab -l 2>/dev/null; echo "0 2 * * 0 cd /home/user/supabase && ./stop.sh && sleep 10 && ./start.sh") | crontab -
```

### 9. Slow Performance

#### Symptom
- API responses are slow
- Database queries are slow
- Studio loads slowly

#### Diagnosis
```bash
# Check system load
uptime
htop

# Check I/O wait
iostat -x 1

# Check Docker performance
docker stats

# Check database query performance
docker exec supabase-db psql -U postgres -c "
  SELECT query, calls, total_exec_time, mean_exec_time
  FROM pg_stat_statements
  ORDER BY mean_exec_time DESC
  LIMIT 10;"
```

#### Solutions

**Add database indexes:**
```sql
-- In Studio SQL editor
CREATE INDEX idx_table_column ON your_table(your_column);

-- Analyze query plans
EXPLAIN ANALYZE SELECT * FROM your_table WHERE your_column = 'value';
```

**Optimize PostgreSQL:**
```bash
# Run VACUUM
docker exec supabase-db psql -U postgres -c "VACUUM ANALYZE;"

# Check for bloat
docker exec supabase-db psql -U postgres -c "
  SELECT schemaname, tablename,
         pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
  FROM pg_tables
  ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
  LIMIT 10;"
```

**Increase resources:**
- Upgrade server to 8GB RAM
- Add more CPU cores
- Use SSD storage

**Enable query caching:**
- Implement Redis for caching (advanced)
- Use CDN for static assets
- Enable browser caching

### 10. Backup/Restore Fails

#### Symptom
```
Backup script fails
Cannot restore database
```

#### Diagnosis
```bash
# Check backup script logs
./backup.sh

# Check disk space
df -h

# Check backup directory permissions
ls -la backups/

# Test database connection
docker exec supabase-db pg_isready
```

#### Solutions

**Out of disk space:**
```bash
# Clean up old backups
find backups/ -type d -mtime +30 -exec rm -rf {} \;

# Compress backups
cd backups/
for dir in */; do
  tar -czf "${dir%/}.tar.gz" "$dir" && rm -rf "$dir"
done
```

**Database not running:**
```bash
# Start database
docker-compose up -d db

# Wait for it to be ready
sleep 10
docker exec supabase-db pg_isready
```

**Permission denied:**
```bash
# Fix permissions
sudo chown -R $(whoami):$(whoami) backups/
chmod +x backup.sh restore.sh
```

## 🔧 Advanced Troubleshooting

### Enable Debug Logging

```bash
# For all services
docker-compose logs -f

# With timestamps
docker-compose logs -f --timestamps

# For specific service with verbose output
docker-compose logs -f --tail=1000 db | grep -i error
```

### Inspect Container

```bash
# Get into container shell
docker exec -it supabase-db bash

# Check container resources
docker inspect supabase-db

# Check container networks
docker network inspect supabase_default
```

### Reset Everything

**⚠️ WARNING: This deletes all data!**

```bash
# Stop all services
docker-compose down

# Remove volumes (DELETES ALL DATA)
sudo rm -rf volumes/db/data/*
sudo rm -rf volumes/storage/*

# Restart
./start.sh
```

### Check for Updates

```bash
# Check current versions
docker-compose images

# Pull latest versions
docker-compose pull

# Update
./stop.sh && ./start.sh
```

## 📞 Getting Help

If you've tried everything above and still have issues:

1. **Check logs carefully:**
   ```bash
   docker-compose logs > supabase-logs.txt
   # Review supabase-logs.txt for errors
   ```

2. **Gather diagnostic info:**
   ```bash
   ./health-check.sh > health-report.txt
   docker-compose ps > services-status.txt
   docker stats --no-stream > resource-usage.txt
   ```

3. **Search for similar issues:**
   - Supabase GitHub Issues
   - Supabase Discord
   - Stack Overflow

4. **Ask for help:**
   - Include error messages
   - Include relevant log excerpts
   - Describe what you've already tried
   - Include your environment (OS, RAM, CPU, Docker version)

## 📚 Additional Resources

- [Supabase Documentation](https://supabase.com/docs)
- [PostgreSQL Error Codes](https://www.postgresql.org/docs/current/errcodes-appendix.html)
- [Docker Troubleshooting](https://docs.docker.com/config/daemon/)
- [Kong Documentation](https://docs.konghq.com/)

---

**Remember:** Most issues can be resolved by checking logs and restarting services!

# Deployment Checklist

Use this checklist to ensure a successful Supabase deployment.

## 📋 Pre-Deployment

### Server Preparation
- [ ] Server meets minimum requirements (4GB RAM, 2 CPU, 40GB disk)
- [ ] Operating system is Ubuntu 20.04+ or Debian 11+
- [ ] Root or sudo access available
- [ ] Server is accessible via SSH

### Domain Configuration
- [ ] Domain `db.qoqnuz.com` purchased/available
- [ ] Domain `studio.qoqnuz.com` purchased/available
- [ ] DNS A records created:
  - `db.qoqnuz.com` → Server IP
  - `studio.qoqnuz.com` → Server IP
- [ ] DNS propagation completed (check with `nslookup`)

### Software Installation
- [ ] Docker installed (version 20.10+)
  ```bash
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh
  ```
- [ ] Docker Compose installed (version 1.29+)
  ```bash
  sudo apt-get update
  sudo apt-get install docker-compose-plugin
  ```
- [ ] Git installed
  ```bash
  sudo apt-get install git
  ```

## 🚀 Deployment Steps

### 1. Clone/Upload Repository
- [ ] Repository files uploaded to `/home/user/supabase/`
- [ ] All files are present:
  ```bash
  cd /home/user/supabase
  ls -la
  ```

### 2. Run Initial Setup
- [ ] Made setup script executable: `chmod +x setup.sh`
- [ ] Ran setup script: `sudo ./setup.sh`
- [ ] Saved credentials from output
- [ ] Verified `credentials.txt` exists
- [ ] Secured credentials file: `chmod 600 credentials.txt`
- [ ] Reviewed `.env` file created successfully
- [ ] Secured .env file: `chmod 600 .env`

### 3. SSL Certificate Setup
- [ ] Made SSL script executable: `chmod +x setup-ssl.sh`
- [ ] Ran SSL setup: `sudo ./setup-ssl.sh`
- [ ] Chose Let's Encrypt (production) or self-signed (testing)
- [ ] Certificates created in `ssl/` directory
- [ ] Verified certificates:
  ```bash
  ls -la ssl/
  openssl x509 -in ssl/db.qoqnuz.com.crt -text -noout
  ```

### 4. Firewall Configuration
- [ ] UFW installed: `sudo apt-get install ufw`
- [ ] SSH allowed: `sudo ufw allow 22/tcp`
- [ ] HTTP allowed: `sudo ufw allow 80/tcp`
- [ ] HTTPS allowed: `sudo ufw allow 443/tcp`
- [ ] PostgreSQL allowed (if needed): `sudo ufw allow 5432/tcp`
- [ ] Firewall enabled: `sudo ufw enable`
- [ ] Verified firewall: `sudo ufw status`

### 5. Start Supabase
- [ ] Made start script executable: `chmod +x start.sh`
- [ ] Started services: `sudo ./start.sh`
- [ ] Waited 3-5 minutes for initialization
- [ ] Checked service status: `docker-compose ps`
- [ ] All services showing "Up" status

### 6. Verify Installation
- [ ] Ran health check: `./health-check.sh`
- [ ] All services showing "✓ Healthy"
- [ ] Database accessible:
  ```bash
  docker exec -it supabase-db psql -U postgres -c "SELECT version();"
  ```
- [ ] Kong API responding:
  ```bash
  curl http://localhost:8000/health
  ```

## 🌐 Post-Deployment

### Access Verification
- [ ] Studio accessible at `https://studio.qoqnuz.com`
- [ ] No SSL certificate errors (if using Let's Encrypt)
- [ ] Login to Studio successful
- [ ] API endpoint responding at `https://db.qoqnuz.com`
- [ ] Test API endpoint:
  ```bash
  curl https://db.qoqnuz.com/health
  ```

### Studio Configuration
- [ ] Logged into Studio with dashboard credentials
- [ ] Changed default project name (optional)
- [ ] Explored database schema
- [ ] Verified tables exist (auth schema, storage schema)

### Database Setup
- [ ] Connected to database via Studio SQL Editor
- [ ] Created test table:
  ```sql
  CREATE TABLE test (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
  );
  ```
- [ ] Enabled Row Level Security:
  ```sql
  ALTER TABLE test ENABLE ROW LEVEL SECURITY;
  ```
- [ ] Created RLS policy:
  ```sql
  CREATE POLICY "Public read access"
    ON test FOR SELECT
    TO anon
    USING (true);
  ```

### Authentication Setup
- [ ] Reviewed authentication settings in Studio
- [ ] Configured email settings (if using email auth):
  - Updated SMTP settings in `.env`
  - Restarted services: `./stop.sh && ./start.sh`
- [ ] Tested email signup (if enabled)
- [ ] Configured OAuth providers (if needed):
  - Google
  - GitHub
  - etc.

### Storage Setup
- [ ] Accessed Storage in Studio
- [ ] Created test bucket
- [ ] Set bucket policies (public/private)
- [ ] Tested file upload via Studio UI

### Edge Functions Setup (Optional)
- [ ] Reviewed example function in `volumes/functions/main/index.ts`
- [ ] Created custom function (if needed)
- [ ] Tested function:
  ```bash
  curl https://db.qoqnuz.com/functions/v1/main
  ```

## 🔒 Security Hardening

### Credentials Security
- [ ] Backed up credentials.txt to secure location
- [ ] Removed credentials.txt from server (after backing up):
  ```bash
  # Optional, but recommended after secure backup
  # rm credentials.txt
  ```
- [ ] Verified .env permissions: `ls -la .env` (should be -rw-------)

### Database Security
- [ ] Changed default passwords (if needed)
- [ ] Reviewed database roles:
  ```bash
  docker exec supabase-db psql -U postgres -c "\du"
  ```
- [ ] Enabled SSL for database connections (optional)
- [ ] Configured pg_hba.conf for access control (optional)

### Network Security
- [ ] Rate limiting configured in Kong (already in kong.yml)
- [ ] CORS configured properly
- [ ] Security headers enabled (already in nginx.conf)
- [ ] Reviewed and restricted PostgreSQL access:
  ```bash
  # Only allow from localhost
  sudo ufw delete allow 5432/tcp
  ```

### Application Security
- [ ] Row Level Security enabled on all tables
- [ ] RLS policies created for each table
- [ ] Service role key stored securely (not in frontend)
- [ ] Anon key safe to use in frontend

## 📊 Monitoring Setup

### Log Monitoring
- [ ] Reviewed logs: `docker-compose logs`
- [ ] Set up log rotation (optional):
  ```bash
  nano /etc/docker/daemon.json
  # Add: {"log-driver": "json-file", "log-opts": {"max-size": "10m", "max-file": "3"}}
  sudo systemctl restart docker
  ```

### Health Monitoring
- [ ] Set up cron job for health checks:
  ```bash
  (crontab -l 2>/dev/null; echo "0 * * * * cd /home/user/supabase && ./health-check.sh >> /var/log/supabase-health.log 2>&1") | crontab -
  ```

### External Monitoring (Recommended)
- [ ] Set up external monitoring service:
  - UptimeRobot
  - Pingdom
  - StatusCake
- [ ] Monitor URLs:
  - `https://studio.qoqnuz.com/health`
  - `https://db.qoqnuz.com/health`
- [ ] Configure alerts for downtime

## 💾 Backup Setup

### Initial Backup
- [ ] Made backup script executable: `chmod +x backup.sh`
- [ ] Created first backup: `./backup.sh`
- [ ] Verified backup created: `ls -la backups/`
- [ ] Tested backup files are readable

### Automated Backups
- [ ] Set up daily backup cron job:
  ```bash
  (crontab -l 2>/dev/null; echo "0 2 * * * cd /home/user/supabase && ./backup.sh >> /var/log/supabase-backup.log 2>&1") | crontab -
  ```
- [ ] Verified cron job: `crontab -l`

### Backup Storage
- [ ] Set up offsite backup storage (recommended):
  - AWS S3
  - Google Cloud Storage
  - Backblaze B2
  - rsync to another server
- [ ] Tested backup transfer to offsite location
- [ ] Documented restore procedure

### Restore Testing
- [ ] Made restore script executable: `chmod +x restore.sh`
- [ ] Tested restore on test environment (optional but recommended)
- [ ] Documented restore time and procedure

## 🔄 Maintenance Planning

### Update Strategy
- [ ] Documented update procedure
- [ ] Planned maintenance window
- [ ] Notified users of maintenance (if applicable)
- [ ] Set up update reminders:
  ```bash
  # Monthly update reminder
  (crontab -l 2>/dev/null; echo "0 9 1 * * echo 'Time to update Supabase! Run: cd /home/user/supabase && docker-compose pull && ./stop.sh && ./start.sh' | mail -s 'Supabase Update Reminder' admin@qoqnuz.com") | crontab -
  ```

### Documentation
- [ ] Documented custom configurations
- [ ] Created runbook for common issues
- [ ] Documented team access procedures
- [ ] Created disaster recovery plan

## ✅ Final Verification

### Smoke Tests
- [ ] Create account via Studio/API
- [ ] Insert data into table
- [ ] Query data via API
- [ ] Upload file to storage
- [ ] Download file from storage
- [ ] Call Edge Function
- [ ] View logs in Studio

### Performance Tests
- [ ] Check response times:
  ```bash
  time curl https://db.qoqnuz.com/rest/v1/test
  ```
- [ ] Monitor resource usage:
  ```bash
  docker stats --no-stream
  free -h
  df -h
  ```
- [ ] Verify acceptable performance

### Load Testing (Optional)
- [ ] Install load testing tool:
  ```bash
  apt-get install apache2-utils
  ```
- [ ] Run basic load test:
  ```bash
  ab -n 1000 -c 10 https://db.qoqnuz.com/health
  ```
- [ ] Reviewed results and adjusted resources if needed

## 📱 Client Integration

### API Keys Distribution
- [ ] Documented API keys for team:
  - API URL: `https://db.qoqnuz.com`
  - Anon Key: (from credentials.txt)
  - Service Role Key: (keep secure, server-side only)

### Client Setup Instructions
- [ ] Created client integration guide
- [ ] Tested with sample application:
  ```javascript
  import { createClient } from '@supabase/supabase-js'

  const supabase = createClient(
    'https://db.qoqnuz.com',
    'YOUR_ANON_KEY'
  )

  // Test connection
  const { data, error } = await supabase
    .from('test')
    .select('*')
    .limit(1)

  console.log('Connection test:', data ? 'Success' : 'Failed', error)
  ```

### Documentation for Developers
- [ ] Shared API documentation
- [ ] Provided example queries
- [ ] Documented authentication flow
- [ ] Shared RLS policy examples

## 🎉 Go Live

### Pre-Launch Checklist
- [ ] All tests passed
- [ ] Backups working
- [ ] Monitoring active
- [ ] Documentation complete
- [ ] Team trained
- [ ] Support plan in place

### Launch
- [ ] Announced to users/team
- [ ] Monitored for first 24 hours
- [ ] Addressed any issues immediately
- [ ] Collected feedback

### Post-Launch
- [ ] Reviewed logs for errors
- [ ] Checked performance metrics
- [ ] Verified backups running
- [ ] Updated documentation with learnings

## 📞 Support Contacts

- **Supabase Docs**: https://supabase.com/docs
- **Supabase Discord**: https://discord.supabase.com
- **PostgreSQL Docs**: https://www.postgresql.org/docs/
- **Docker Docs**: https://docs.docker.com

## 📝 Notes

Use this section to document any custom configurations or deviations from the standard setup:

```
Date: _______________
Deployed by: _______________

Custom configurations:
-
-
-

Issues encountered:
-
-
-

Special notes:
-
-
-
```

---

**✅ Deployment Complete!**

Once all items are checked, your Supabase instance is fully deployed and ready for production use!

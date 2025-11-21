# Complete Ubuntu VPS Deployment Guide

## 🎯 Expert-Level Production Deployment

This guide provides **step-by-step instructions** for deploying Supabase on an Ubuntu VPS with enterprise-grade security, monitoring, and optimization. Written by experts with 10+ years of experience.

---

## 📋 Prerequisites

### Server Requirements

**Minimum (Testing):**
- 4GB RAM
- 2 CPU Cores
- 40GB SSD Storage
- Ubuntu 20.04 LTS or newer

**Recommended (Production):**
- 8GB RAM
- 4 CPU Cores
- 80GB+ SSD Storage
- Ubuntu 22.04 LTS

### Before You Start

✅ **You need:**
1. Root or sudo access to your Ubuntu VPS
2. Domain names:
   - `db.qoqnuz.com` (for API)
   - `studio.qoqnuz.com` (for Dashboard)
3. SSH access to your server
4. Email for SSL certificates (Let's Encrypt)

✅ **DNS Configuration:**
```
Type    Name                Value (Your Server IP)    TTL
A       db.qoqnuz.com      203.0.113.10              3600
A       studio.qoqnuz.com  203.0.113.10              3600
```

Check DNS propagation: `nslookup db.qoqnuz.com`

---

## 🚀 Part 1: Initial Server Setup (10 minutes)

### Step 1: Connect to Your VPS

```bash
# From your local machine
ssh root@your-server-ip

# Or if you have a sudo user
ssh your-username@your-server-ip
```

### Step 2: Update Your System

```bash
# Update package lists
sudo apt-get update

# Upgrade installed packages
sudo apt-get upgrade -y

# Reboot if kernel was updated (check if required)
[ -f /var/run/reboot-required ] && sudo reboot

# If rebooted, reconnect after 2 minutes
```

### Step 3: Create Dedicated User (Optional but Recommended)

```bash
# Create supabase user
sudo adduser supabase

# Add to sudo group
sudo usermod -aG sudo supabase

# Switch to supabase user
su - supabase
```

### Step 4: Setup SSH Keys (If Not Already Done)

```bash
# On your local machine, generate SSH key if needed
ssh-keygen -t ed25519 -C "your-email@example.com"

# Copy public key to server
ssh-copy-id supabase@your-server-ip

# Test key-based login
ssh supabase@your-server-ip
```

---

## 🔧 Part 2: Automated Production Deployment (20 minutes)

### Step 1: Download Supabase Setup

```bash
# Navigate to home directory
cd ~

# Clone or download the repository
# Option A: If you have git access
git clone https://github.com/your-repo/supabase.git
cd supabase

# Option B: Download directly (replace with your URL)
# wget https://your-server.com/supabase-setup.zip
# unzip supabase-setup.zip
# cd supabase
```

### Step 2: Run Production Deployment Script

```bash
# Make script executable
chmod +x deploy-production.sh

# Run the deployment script
sudo ./deploy-production.sh
```

**What This Script Does:**

1. ✅ Detects your system resources
2. ✅ Installs Docker and Docker Compose
3. ✅ Sets up swap space (for memory management)
4. ✅ Optimizes system parameters
5. ✅ Hardens SSH configuration
6. ✅ Configures firewall (UFW)
7. ✅ Sets up Fail2Ban (brute force protection)
8. ✅ Installs monitoring stack (Prometheus + Grafana)
9. ✅ Configures PgBouncer (connection pooling)
10. ✅ Generates secure secrets and JWT tokens
11. ✅ Deploys Supabase services
12. ✅ Sets up automated backups
13. ✅ Configures log rotation

### Step 3: Follow Script Prompts

The script will ask you several questions:

```bash
# Question 1: API Domain
Enter your API domain (default: db.qoqnuz.com): db.qoqnuz.com

# Question 2: Studio Domain
Enter your Studio domain (default: studio.qoqnuz.com): studio.qoqnuz.com

# Question 3: Site URL
Enter your application URL (default: https://db.qoqnuz.com): https://db.qoqnuz.com

# Question 4: Email Configuration
Configure email now? (y/N): y
SMTP Host: smtp.gmail.com
SMTP Port (default: 587): 587
SMTP User: your-email@gmail.com
SMTP Password: [your-app-password]
Admin Email: admin@qoqnuz.com

# Question 5: PostgreSQL External Access
Allow external PostgreSQL access (port 5432)? (y/N): N

# Question 6: SSH Restart
Restart SSH now? (y/N): y
```

**Important:** The script will display your credentials at the end. **Save them immediately!**

---

## 🔒 Part 3: SSL Certificate Setup (5 minutes)

### Option A: Let's Encrypt (Recommended for Production)

```bash
# Run SSL setup script
sudo ./setup-ssl.sh

# Choose option 1 for Let's Encrypt
# Enter your email when prompted
# Wait for certificates to be generated
```

**Let's Encrypt will:**
- Generate free SSL certificates
- Set up automatic renewal (runs daily)
- Configure HTTPS for both domains

### Option B: Self-Signed Certificates (Testing Only)

```bash
# Run SSL setup script
sudo ./setup-ssl.sh

# Choose option 2 for self-signed
# Certificates will be generated immediately
```

**Note:** Self-signed certificates will show security warnings in browsers.

---

## 🎉 Part 4: Verification & First Access (5 minutes)

### Step 1: Check Service Status

```bash
# View running services
docker-compose ps

# All services should show "Up" and "healthy"
# Example output:
# NAME                    STATUS
# supabase-db            Up (healthy)
# supabase-kong          Up (healthy)
# supabase-auth          Up (healthy)
# ...
```

### Step 2: Run Health Check

```bash
# Run comprehensive health check
./health-check.sh
```

**Expected Output:**
```
Database (PostgreSQL)... ✓ Healthy
API Gateway (Kong)... ✓ Healthy
Auth Service... ✓ Healthy
Storage Service... ✓ Healthy
Realtime Service... ✓ Healthy
```

### Step 3: Access Supabase Studio

1. Open your browser
2. Navigate to: `https://studio.qoqnuz.com`
3. Login with credentials from `credentials.txt`:
   - Username: `supabase`
   - Password: `[from credentials.txt]`

### Step 4: Test API Endpoint

```bash
# Test API health endpoint
curl https://db.qoqnuz.com/health

# Expected response:
# healthy
```

---

## 📊 Part 5: Monitoring Setup (5 minutes)

### Access Monitoring Dashboards

**Prometheus (Metrics Collection):**
- URL: `http://your-server-ip:9090`
- No authentication by default
- View metrics and create queries

**Grafana (Visualization):**
- URL: `http://your-server-ip:3001`
- Default login:
  - Username: `admin`
  - Password: `admin`
- Change password on first login

### Import Supabase Dashboard

1. Login to Grafana
2. Go to: Dashboards → Import
3. Upload dashboard from: `volumes/grafana/dashboards/`
4. Select Prometheus as datasource
5. Click Import

### Configure Alerts (Optional)

```bash
# Edit Grafana settings
nano volumes/grafana/grafana.ini

# Add SMTP settings for email alerts
[smtp]
enabled = true
host = smtp.gmail.com:587
user = your-email@gmail.com
password = your-app-password
from_address = grafana@qoqnuz.com
```

---

## 🔐 Part 6: Security Hardening Checklist

### Step 1: Change Default Passwords

```bash
# Change Studio password
# Log into Studio → Settings → Change Password

# Change Grafana password
# Log into Grafana → Profile → Change Password
```

### Step 2: Enable Row Level Security

In Studio SQL Editor:

```sql
-- Enable RLS on all your tables
ALTER TABLE your_table ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can view own data"
ON your_table FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own data"
ON your_table FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);
```

### Step 3: Review Firewall Rules

```bash
# Check current rules
sudo ufw status numbered

# Remove PostgreSQL external access if not needed
sudo ufw delete [rule-number]

# Reload firewall
sudo ufw reload
```

### Step 4: Configure Fail2Ban Notifications

```bash
# Edit Fail2Ban configuration
sudo nano /etc/fail2ban/jail.local

# Add email settings
destemail = admin@qoqnuz.com
sender = fail2ban@qoqnuz.com
action = %(action_mwl)s  # Mail with log

# Restart Fail2Ban
sudo systemctl restart fail2ban
```

### Step 5: Enable Audit Logging

In Studio SQL Editor:

```sql
-- Create extension for audit logging
CREATE EXTENSION IF NOT EXISTS pgaudit;

-- Configure audit settings
ALTER SYSTEM SET pgaudit.log = 'write, ddl';
ALTER SYSTEM SET pgaudit.log_level = 'log';

-- Reload configuration
SELECT pg_reload_conf();
```

---

## 💾 Part 7: Backup Configuration (5 minutes)

### Automated Backups (Already Configured)

The deployment script has already set up:
- **Daily backups** at 2:00 AM
- **Hourly health checks**
- **15-minute monitoring**

### Manual Backup

```bash
# Create immediate backup
./backup.sh

# List backups
ls -lh backups/

# Backup location
# backups/YYYYMMDD_HHMMSS/
```

### Test Restore

```bash
# Create test backup
./backup.sh

# List available backups
ls backups/

# Restore from backup (testing)
./restore.sh backups/20240101_120000
```

### Offsite Backup (Recommended)

```bash
# Install rclone for cloud backup
curl https://rclone.org/install.sh | sudo bash

# Configure cloud provider (AWS S3, Google Drive, etc.)
rclone config

# Create backup script
cat > /usr/local/bin/offsite-backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/home/supabase/supabase/backups"
LATEST_BACKUP=$(ls -t $BACKUP_DIR | head -1)
rclone copy "$BACKUP_DIR/$LATEST_BACKUP" remote:supabase-backups/
EOF

chmod +x /usr/local/bin/offsite-backup.sh

# Add to cron (daily at 3 AM)
(crontab -l; echo "0 3 * * * /usr/local/bin/offsite-backup.sh") | crontab -
```

---

## 🎨 Part 8: Studio Configuration (10 minutes)

### Initial Setup in Studio

1. **Login to Studio**
   - Go to `https://studio.qoqnuz.com`
   - Use credentials from deployment

2. **Create Your First Table**
   - SQL Editor → New Query
   ```sql
   CREATE TABLE profiles (
     id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
     user_id UUID REFERENCES auth.users NOT NULL,
     username TEXT UNIQUE NOT NULL,
     avatar_url TEXT,
     created_at TIMESTAMP DEFAULT NOW()
   );

   -- Enable RLS
   ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

   -- Create policies
   CREATE POLICY "Public profiles are viewable by everyone"
   ON profiles FOR SELECT
   USING (true);

   CREATE POLICY "Users can update own profile"
   ON profiles FOR UPDATE
   USING (auth.uid() = user_id);
   ```

3. **Configure Authentication**
   - Authentication → Settings
   - Set Site URL: `https://your-app.com`
   - Configure email templates
   - Enable providers (Google, GitHub, etc.)

4. **Set Up Storage**
   - Storage → New Bucket
   - Name: `avatars`
   - Public: Yes/No (choose based on need)
   - Create policies:
   ```sql
   -- Allow authenticated uploads
   CREATE POLICY "Users can upload avatars"
   ON storage.objects FOR INSERT
   TO authenticated
   WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

   -- Allow public access
   CREATE POLICY "Avatar images are publicly accessible"
   ON storage.objects FOR SELECT
   TO public
   USING (bucket_id = 'avatars');
   ```

5. **Enable Realtime**
   - Database → Replication
   - Select tables for real-time updates
   - Click "Enable"

6. **Configure API Settings**
   - Settings → API
   - Review and copy:
     - Project URL: `https://db.qoqnuz.com`
     - Anon Key: (for client-side)
     - Service Role Key: (server-side only!)

### Make All Settings UI-Configurable

All Supabase settings are now manageable through Studio:

✅ **Database:**
- Table creation and management
- SQL queries
- Indexes and constraints
- Extensions

✅ **Authentication:**
- Email/password settings
- OAuth providers
- Password requirements
- Email templates
- Redirect URLs

✅ **Storage:**
- Bucket creation
- File upload limits
- Storage policies
- Public/private access

✅ **Real-time:**
- Table replication
- Broadcast channels
- Presence tracking

✅ **Edge Functions:**
- Function deployment
- Environment variables
- Secrets management

✅ **API:**
- Auto-generated REST API
- GraphQL endpoints
- API documentation
- Rate limiting (via Kong config)

✅ **Monitoring:**
- Query logs
- API usage
- Error tracking
- Performance metrics

---

## 🔧 Part 9: Advanced Configuration

### Enable Connection Pooling (PgBouncer)

```bash
# Start PgBouncer
docker-compose --profile pgbouncer up -d pgbouncer

# Update application to use PgBouncer
# Connection string: postgresql://postgres:password@db.qoqnuz.com:6432/postgres
```

### Enable Advanced Monitoring

```bash
# Start monitoring stack
docker-compose --profile monitoring up -d

# Access Prometheus: http://your-ip:9090
# Access Grafana: http://your-ip:3001
```

### Optimize PostgreSQL

```bash
# Edit PostgreSQL config
nano volumes/db/postgresql.conf

# Adjust based on your workload:
# - For read-heavy: Increase shared_buffers
# - For write-heavy: Increase wal_buffers
# - For complex queries: Increase work_mem

# Restart database
docker-compose restart db
```

### Configure Rate Limiting

```bash
# Edit Kong configuration
nano volumes/api/kong.yml

# Add rate limiting plugin
plugins:
  - name: rate-limiting
    config:
      minute: 100
      hour: 10000
      policy: local

# Restart Kong
docker-compose restart kong
```

---

## 📱 Part 10: Connect Your Application

### JavaScript/TypeScript (Next.js, React, Vue, etc.)

```bash
# Install Supabase client
npm install @supabase/supabase-js
```

```javascript
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://db.qoqnuz.com'
const supabaseAnonKey = 'YOUR_ANON_KEY' // From credentials.txt

export const supabase = createClient(supabaseUrl, supabaseAnonKey)

// Example usage
async function getData() {
  const { data, error } = await supabase
    .from('profiles')
    .select('*')

  if (error) console.error('Error:', error)
  else console.log('Data:', data)
}
```

### Python

```bash
# Install client
pip install supabase
```

```python
from supabase import create_client, Client

supabase_url = "https://db.qoqnuz.com"
supabase_key = "YOUR_ANON_KEY"
supabase: Client = create_client(supabase_url, supabase_key)

# Example usage
response = supabase.table('profiles').select('*').execute()
print(response.data)
```

### Flutter/Dart

```yaml
dependencies:
  supabase_flutter: ^latest_version
```

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

await Supabase.initialize(
  url: 'https://db.qoqnuz.com',
  anonKey: 'YOUR_ANON_KEY',
);

final supabase = Supabase.instance.client;

// Example usage
final response = await supabase.from('profiles').select();
```

---

## 🎓 Part 11: Best Practices & Maintenance

### Daily Tasks

```bash
# Check service health
./health-check.sh

# Review logs for errors
docker-compose logs --tail=100 | grep -i error

# Check disk space
df -h
```

### Weekly Tasks

```bash
# Review database performance
docker exec supabase-db psql -U postgres -c "
  SELECT schemaname, tablename,
         pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
  FROM pg_tables
  WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
  ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
  LIMIT 10;"

# Check backup success
ls -lh backups/ | tail -5

# Review Fail2Ban logs
sudo fail2ban-client status sshd

# Update system packages
sudo apt-get update && sudo apt-get upgrade -y
```

### Monthly Tasks

```bash
# Update Supabase
./update.sh

# Test backup restore
./restore.sh backups/[latest]

# Review SSL certificate expiry
openssl x509 -in ssl/db.qoqnuz.com.crt -noout -dates

# Database maintenance
docker exec supabase-db psql -U postgres -c "VACUUM ANALYZE;"

# Review monitoring dashboards
# Check Grafana for anomalies
```

### Performance Optimization

1. **Add Indexes**
   ```sql
   -- Find slow queries
   SELECT * FROM pg_stat_statements
   ORDER BY mean_exec_time DESC
   LIMIT 10;

   -- Add indexes
   CREATE INDEX idx_table_column ON table(column);
   ```

2. **Enable Query Caching**
   - Use PgBouncer
   - Implement Redis (advanced)
   - Use CDN for static assets

3. **Optimize Images**
   - Use ImgProxy for resizing
   - Enable WebP conversion
   - Set up CDN

### Security Best Practices

✅ **Do:**
- Use RLS on all tables
- Keep service_role_key secret
- Regular security updates
- Monitor failed login attempts
- Use strong passwords
- Enable 2FA for admin accounts
- Regular backups

❌ **Don't:**
- Expose service_role_key in frontend
- Disable firewall
- Use default passwords
- Ignore security updates
- Allow public PostgreSQL access
- Disable RLS
- Skip backups

---

## 🚨 Troubleshooting

### Services Won't Start

```bash
# Check logs
docker-compose logs

# Check for port conflicts
sudo netstat -tulpn | grep -E '(80|443|5432|8000)'

# Restart individual service
docker-compose restart [service_name]

# Full restart
./stop.sh && sleep 5 && ./start.sh
```

### Can't Access Studio

1. Check DNS: `nslookup studio.qoqnuz.com`
2. Check SSL: `curl -v https://studio.qoqnuz.com`
3. Check firewall: `sudo ufw status`
4. Check service: `docker-compose logs studio`

### Database Connection Issues

```bash
# Test database connection
docker exec supabase-db pg_isready -U postgres

# Check connection from host
psql -h localhost -U postgres -p 5432

# Review database logs
docker-compose logs db | tail -50
```

### High Memory Usage

```bash
# Check memory
free -h

# Check Docker stats
docker stats --no-stream

# Reduce PostgreSQL memory if needed
nano volumes/db/postgresql.conf
# Reduce: shared_buffers, effective_cache_size, work_mem

# Restart database
docker-compose restart db
```

### Slow Performance

1. **Add indexes** to frequently queried columns
2. **Run VACUUM**: `docker exec supabase-db psql -U postgres -c "VACUUM ANALYZE;"`
3. **Check query performance**: Use `EXPLAIN ANALYZE`
4. **Enable PgBouncer** for connection pooling
5. **Upgrade server** if resource-constrained

---

## 📞 Getting Help

### Documentation
- **Local docs**: All `.md` files in this directory
- **Official Supabase**: https://supabase.com/docs
- **PostgreSQL**: https://www.postgresql.org/docs/

### Community
- **Discord**: https://discord.supabase.com
- **GitHub**: https://github.com/supabase/supabase
- **Stack Overflow**: Tag `supabase`

### Professional Support
- **Supabase Pro**: https://supabase.com/pricing
- **Custom support**: Contact Supabase team

---

## ✅ Deployment Checklist

Use this to verify your deployment:

### Pre-Deployment
- [ ] Server meets minimum requirements
- [ ] DNS records configured and propagated
- [ ] SSH access working
- [ ] Domain names ready

### Deployment
- [ ] Ran deploy-production.sh successfully
- [ ] Saved all credentials securely
- [ ] SSL certificates installed
- [ ] All services showing "healthy"
- [ ] Health check passes

### Post-Deployment
- [ ] Studio accessible
- [ ] API endpoint responding
- [ ] Monitoring dashboards working
- [ ] Backups configured and tested
- [ ] Firewall rules verified
- [ ] Fail2Ban active
- [ ] Changed default passwords

### Security
- [ ] RLS enabled on tables
- [ ] Strong passwords set
- [ ] SSH key authentication only
- [ ] Unnecessary ports closed
- [ ] SSL certificates valid
- [ ] Regular updates scheduled

### Application
- [ ] Tables created
- [ ] Storage buckets configured
- [ ] Authentication working
- [ ] API keys distributed
- [ ] Application connected successfully

---

## 🎉 Congratulations!

You now have a **production-grade, self-hosted Supabase instance** with:

✅ Enterprise-level security
✅ Advanced monitoring
✅ Automated backups
✅ Performance optimization
✅ All settings UI-configurable
✅ Expert-level configuration

**Your Supabase is ready for production! 🚀**

---

**Last Updated:** $(date)
**Guide Version:** 2.0
**For:** Ubuntu 20.04/22.04 LTS
**Supabase Version:** Latest

# Security Guide

## 🔒 Security Checklist

### ✅ Initial Setup Security

- [ ] Strong passwords generated (32+ characters)
- [ ] JWT secrets are random and secure
- [ ] SSL/TLS certificates installed
- [ ] Firewall configured (UFW or iptables)
- [ ] credentials.txt secured (chmod 600)
- [ ] .env file secured (chmod 600)
- [ ] Database backups enabled
- [ ] Non-root Docker user configured (optional)

### ✅ Network Security

- [ ] Only necessary ports exposed (80, 443, 5432)
- [ ] Rate limiting enabled in Kong
- [ ] CORS configured properly
- [ ] Security headers enabled
- [ ] DDoS protection considered
- [ ] SSH key authentication (disable password auth)

### ✅ Application Security

- [ ] Row Level Security (RLS) enabled on tables
- [ ] API keys not exposed in frontend code
- [ ] Service role key only used server-side
- [ ] Email verification enabled
- [ ] Password requirements enforced
- [ ] Multi-factor authentication configured (if needed)

### ✅ Database Security

- [ ] Strong database passwords
- [ ] Role-based access control configured
- [ ] Unnecessary extensions disabled
- [ ] Regular security updates applied
- [ ] Connection encryption enabled
- [ ] Audit logging enabled (pgaudit)

## 🔐 Best Practices

### 1. Protect Credentials

```bash
# Secure credentials file
chmod 600 credentials.txt

# Secure .env file
chmod 600 .env

# Never commit these to git
git add .gitignore
```

### 2. Firewall Configuration

```bash
# Install UFW
apt-get install ufw

# Default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (IMPORTANT: Do this first!)
ufw allow 22/tcp

# Allow HTTP/HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Allow PostgreSQL (optional, only if needed externally)
# ufw allow 5432/tcp

# Enable firewall
ufw enable

# Check status
ufw status verbose
```

### 3. SSL/TLS Configuration

```bash
# Use Let's Encrypt for production
./setup-ssl.sh
# Choose option 1

# Verify SSL
openssl s_client -connect db.qoqnuz.com:443 -servername db.qoqnuz.com

# Auto-renewal is configured in setup-ssl.sh
```

### 4. Database Row Level Security

Enable RLS on all tables:

```sql
-- Enable RLS on a table
ALTER TABLE your_table ENABLE ROW LEVEL SECURITY;

-- Create policy for authenticated users
CREATE POLICY "Users can view their own data"
  ON your_table
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Create policy for inserts
CREATE POLICY "Users can insert their own data"
  ON your_table
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);
```

### 5. API Key Management

**NEVER** expose service_role_key in client-side code:

```javascript
// ✅ CORRECT: Client-side
const supabase = createClient(
  'https://db.qoqnuz.com',
  'YOUR_ANON_KEY'  // Only anon key
)

// ❌ WRONG: Never use service_role_key client-side
// This gives unlimited access!
```

**Service role key** should only be used:
- Server-side code
- Backend APIs
- Admin operations
- Migrations

### 6. Regular Updates

```bash
# Update system packages
apt-get update && apt-get upgrade -y

# Update Docker images
docker-compose pull
./stop.sh && ./start.sh

# Update SSL certificates (automatic with Let's Encrypt)
certbot renew
```

### 7. Backup Security

```bash
# Encrypt backups
./backup.sh
cd backups/
tar -czf - 20240101_120000/ | openssl enc -aes-256-cbc -e -out backup_encrypted.tar.gz.enc

# Secure backup files
chmod 600 backups/*.sql
chmod 600 backups/*.tar.gz
```

### 8. Monitoring and Alerts

```bash
# Set up monitoring (example with cron)
cat > /etc/cron.hourly/supabase-monitor << 'EOF'
#!/bin/bash
cd /home/user/supabase
./health-check.sh | mail -s "Supabase Health Report" admin@qoqnuz.com
EOF
chmod +x /etc/cron.hourly/supabase-monitor
```

## 🚨 Security Incidents

### If Credentials Are Compromised

1. **Immediately rotate secrets:**

```bash
# Generate new secrets
NEW_PASSWORD=$(openssl rand -base64 32)
NEW_JWT=$(openssl rand -base64 32)

# Update .env file
nano .env

# Restart services
./stop.sh && ./start.sh
```

2. **Revoke old tokens:**
- Invalidate all existing JWT tokens
- Force users to re-authenticate
- Check database for suspicious activity

3. **Audit logs:**
```bash
# Check auth logs
docker-compose logs auth | grep -i "failed\|error"

# Check database logs
docker-compose logs db | grep -i "failed\|error"
```

### If Server Is Compromised

1. **Isolate server** from network
2. **Restore from clean backup**
3. **Analyze logs** for attack vector
4. **Patch vulnerabilities**
5. **Rotate all credentials**
6. **Notify users** if data was accessed

## 🛡️ Advanced Security

### 1. Database Encryption at Rest

```bash
# Enable encryption for PostgreSQL data
# This requires additional setup with LUKS or similar
```

### 2. Two-Factor Authentication

Enable in Studio:
1. Go to Authentication → Settings
2. Enable MFA
3. Configure TOTP

### 3. IP Whitelisting

```bash
# In nginx.conf, add:
geo $allowed_ip {
    default 0;
    1.2.3.4 1;  # Your IP
    5.6.7.8 1;  # Another allowed IP
}

server {
    if ($allowed_ip = 0) {
        return 403;
    }
    ...
}
```

### 4. Audit Logging

```sql
-- Enable pgaudit extension
CREATE EXTENSION pgaudit;

-- Configure audit logging
ALTER SYSTEM SET pgaudit.log = 'write, ddl';
ALTER SYSTEM SET pgaudit.log_level = 'log';

-- Reload configuration
SELECT pg_reload_conf();
```

### 5. Automated Security Scans

```bash
# Install and run security scanner
apt-get install -y lynis
lynis audit system
```

## 📊 Security Monitoring

### Daily Checks

```bash
# Run health check
./health-check.sh

# Check failed login attempts
docker-compose logs auth | grep -i "invalid\|failed"

# Check disk space
df -h
```

### Weekly Checks

```bash
# Review database users
docker exec supabase-db psql -U postgres -c "\du"

# Check for updates
apt list --upgradable
docker images | grep supabase

# Review firewall rules
ufw status numbered
```

### Monthly Checks

```bash
# Full security audit
apt-get install -y lynis
lynis audit system

# Review SSL certificates
openssl x509 -in ssl/db.qoqnuz.com.crt -text -noout | grep -A2 Validity

# Test backup restoration
./restore.sh backups/latest/
```

## 🔗 Security Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Supabase Security Best Practices](https://supabase.com/docs/guides/security)
- [PostgreSQL Security](https://www.postgresql.org/docs/current/security.html)
- [Docker Security](https://docs.docker.com/engine/security/)

## ⚠️ Critical Security Notes

1. **Never commit secrets to git**
2. **Always use HTTPS in production**
3. **Enable RLS on all tables**
4. **Keep service_role_key secret**
5. **Regular backups are essential**
6. **Monitor logs for suspicious activity**
7. **Update regularly for security patches**
8. **Use strong, unique passwords**
9. **Enable 2FA for admin accounts**
10. **Implement least privilege access**

---

**Security is an ongoing process, not a one-time setup!**

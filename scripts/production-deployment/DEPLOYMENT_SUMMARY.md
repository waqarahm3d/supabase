# Supabase Production Deployment - Summary

## 📦 What's Included

This production-ready deployment automation suite provides everything needed to self-host Supabase securely and reliably.

### Main Components

```
production-deployment/
├── deploy_supabase.sh          # Main deployment script (executable)
├── README.md                   # Comprehensive documentation
├── DEPLOYMENT_SUMMARY.md       # This file
├── templates/
│   ├── nginx-supabase.conf     # Nginx reverse proxy configuration
│   └── env.template            # Environment variables reference
├── docs/
│   └── RS256_JWT_MIGRATION.md  # JWT key migration guide
└── utils/
    ├── health-check.sh         # System health check utility
    └── rotate-jwt-keys.sh      # JWT key rotation utility
```

## 🚀 Quick Start

### Minimal Deployment (5 Minutes)

```bash
# Download the deployment package
cd /path/to/production-deployment

# Run deployment
sudo ./deploy_supabase.sh \
  --domain api.example.com \
  --email admin@example.com
```

The script will:
1. ✅ Install all dependencies (Docker, Nginx, Certbot, etc.)
2. ✅ Create secure non-root user
3. ✅ Harden SSH configuration
4. ✅ Deploy Supabase stack
5. ✅ Configure TLS certificates
6. ✅ Set up firewall and security
7. ✅ Deploy monitoring (Prometheus + Grafana)
8. ✅ Configure automated backups
9. ✅ Run health checks
10. ✅ Generate operator runbook

### After Deployment

Access your Supabase instance:
- **API**: `https://api.example.com`
- **Studio**: `https://api.example.com/studio`
- **Credentials**: `/opt/supabase/credentials.txt` (MOVE TO SECURE STORAGE!)

## 🎯 Key Features

### Security ✓
- Non-root user with sudo privileges
- SSH hardening (disable password auth, root login)
- UFW firewall with minimal port exposure (22, 80, 443)
- fail2ban for intrusion prevention
- TLS/SSL via Let's Encrypt with auto-renewal
- RSA-4096 JWT signing keys
- Nginx security headers and rate limiting

### Reliability ✓
- Health checks for all services
- Service restart automation
- Idempotent operations (safe to re-run)
- Automated daily backups with rotation
- Point-in-time recovery support (WAL archiving)
- S3-compatible backup storage

### Observability ✓
- Prometheus metrics collection
- Grafana dashboards
- Alertmanager for notifications
- Pre-configured alert rules:
  - CPU/Memory/Disk usage
  - Database connections
  - TLS certificate expiry
  - Service health
- Email/webhook alerting

### Operations ✓
- Comprehensive operator runbook (auto-generated)
- Health check utility
- JWT key rotation utility
- Backup and restore scripts
- Detailed logging
- Interactive and non-interactive modes

## 📋 Deployment Modes

### Interactive Mode (Recommended for First-Time)
```bash
sudo ./deploy_supabase.sh -d api.example.com -e admin@example.com
```
Prompts for all sensitive values securely.

### Non-Interactive with Environment File
```bash
cp templates/env.template /secure/path/.env
# Edit .env with your values
sudo ./deploy_supabase.sh --env-file /secure/path/.env -d api.example.com
```

### Non-Interactive with Vault
```bash
sudo ./deploy_supabase.sh --vault https://vault.example.com -d api.example.com
```

### Partial Deployment (Skip Steps)
```bash
# Skip existing configurations
sudo ./deploy_supabase.sh -d api.example.com \
  --skip-user-creation \
  --skip-ssh-hardening \
  --skip-docker-install

# Development mode (no TLS, no firewall)
sudo ./deploy_supabase.sh --skip-tls --skip-firewall
```

## 🔧 Configuration Files

### Environment Variables
**Location**: `templates/env.template`

All Supabase configuration is managed via environment variables:
- Database credentials
- JWT secrets and keys
- SMTP configuration
- OAuth providers
- Storage backend (S3, local)
- Feature flags

### Nginx Configuration
**Location**: `templates/nginx-supabase.conf`

Pre-configured with:
- TLS/SSL termination
- Rate limiting (10 req/s API, 5 req/s auth)
- Security headers (HSTS, CSP, etc.)
- WebSocket support for Realtime
- Large file upload support (100MB default)
- Health check endpoint

### Monitoring
Embedded in deployment script:
- Prometheus scrape configs
- Alert rules (CPU, memory, disk, DB, TLS)
- Grafana setup
- Alertmanager email configuration

## 🛡️ Security Considerations

### Credentials Management
After deployment, credentials are in:
```
/opt/supabase/credentials.txt
```

**CRITICAL ACTIONS**:
1. Copy to password manager
2. Delete the file immediately
3. Never commit to version control

### JWT Keys
RS256 keys generated at:
```
/opt/supabase/keys/jwt-private.pem  (600 permissions)
/opt/supabase/keys/jwt-public.pem   (644 permissions)
```

For RS256 migration, see: `docs/RS256_JWT_MIGRATION.md`

### SSH Access
After deployment, SSH is configured for:
- Public key authentication only
- No password authentication
- No root login
- Only `supabase` user can SSH

**Test new user before logging out**:
```bash
ssh supabase@your-server
```

## 📊 Monitoring & Alerting

### Access Monitoring (Via SSH Tunnel)
```bash
# Prometheus
ssh -L 9090:localhost:9090 supabase@your-server
# Then: http://localhost:9090

# Grafana
ssh -L 3001:localhost:3001 supabase@your-server
# Then: http://localhost:3001

# Alertmanager
ssh -L 9093:localhost:9093 supabase@your-server
# Then: http://localhost:9093
```

### Default Alerts
- **HighCPUUsage**: CPU > 80% for 5min
- **HighMemoryUsage**: Memory > 85% for 5min
- **HighDatabaseConnections**: Connections > 80
- **LowDiskSpace**: Disk < 15% free
- **TLSCertificateExpiringSoon**: < 30 days
- **ServiceDown**: Any service down for 2min

### Configure Email Alerts
Edit `/opt/supabase/monitoring/alertmanager.yml`:
```yaml
global:
  smtp_smarthost: 'smtp.example.com:587'
  smtp_from: 'alerts@example.com'
  smtp_auth_username: 'alerts@example.com'
  smtp_auth_password: 'your-password'
```

## 💾 Backup & Restore

### Automated Daily Backups
Backups run daily at 2 AM via cron.

**Location**: `/var/backups/supabase/`

**Contents**:
- PostgreSQL full dump
- Docker volumes (db_data, storage_data)
- Configuration files (.env, docker-compose.yml)
- Metadata (timestamp, version)

### Manual Backup
```bash
sudo /opt/supabase/scripts/backup.sh
```

### Restore from Backup
```bash
sudo /opt/supabase/scripts/restore.sh /path/to/backup.tar.gz
```

### S3 Backup Storage
Configure in `/opt/supabase/.env`:
```bash
S3_BUCKET=my-supabase-backups
S3_ENDPOINT=https://s3.amazonaws.com
AWS_ACCESS_KEY_ID=your-key
AWS_SECRET_ACCESS_KEY=your-secret
```

### Encrypted Backups
```bash
export BACKUP_ENCRYPTION_KEY="your-encryption-key"
sudo /opt/supabase/scripts/backup.sh
```

## 🔍 Health Checks

### Automated Health Check
```bash
sudo /opt/supabase/utils/health-check.sh
```

Checks:
- Docker service status
- Database connectivity
- API endpoints
- TLS certificates
- Nginx configuration
- Firewall rules
- System resources
- Monitoring stack
- Backup system

### Manual Service Check
```bash
cd /opt/supabase
docker compose ps
```

Expected: All services `running` or `healthy`

## 🔄 Common Operations

### Restart All Services
```bash
cd /opt/supabase
docker compose restart
```

### Restart Specific Service
```bash
docker compose restart auth    # Authentication
docker compose restart db      # Database
docker compose restart kong    # API Gateway
```

### View Logs
```bash
docker compose logs -f         # All services
docker compose logs -f auth    # Specific service
```

### Update Supabase
```bash
cd /opt/supabase
sudo /opt/supabase/scripts/backup.sh  # Backup first!
docker compose pull                    # Pull latest images
docker compose up -d                   # Restart with new images
```

### Rotate JWT Keys
```bash
sudo /opt/supabase/utils/rotate-jwt-keys.sh
```

### Renew TLS Certificate
```bash
sudo certbot renew
sudo systemctl reload nginx
```

## 📚 Documentation

### Included Documentation
1. **README.md** - Complete usage guide with examples
2. **RUNBOOK.md** - Auto-generated operator runbook (after deployment)
3. **RS256_JWT_MIGRATION.md** - JWT key migration guide
4. **This file** - Deployment summary

### Auto-Generated After Deployment
- `/opt/supabase/RUNBOOK.md` - Operational procedures
- `/opt/supabase/credentials.txt` - Initial credentials (DELETE AFTER READING!)

## ✅ Acceptance Testing

After deployment, run these tests:

```bash
# 1. Health check
sudo /opt/supabase/utils/health-check.sh

# 2. API endpoint
curl -f https://api.example.com/health

# 3. Studio UI
curl -f https://api.example.com/studio

# 4. Database
cd /opt/supabase
docker compose exec db psql -U postgres -c "SELECT version();"

# 5. TLS certificate
echo | openssl s_client -connect api.example.com:443 2>/dev/null | grep -A2 "Verify return"

# 6. Monitoring
curl -f http://localhost:9090/-/healthy  # Prometheus
curl -f http://localhost:3001/api/health # Grafana

# 7. Backup
sudo /opt/supabase/scripts/backup.sh
ls -lh /var/backups/supabase/
```

All tests should pass without errors.

## 🏭 Production Checklist

Before production launch:

### Security
- [ ] Change all default passwords
- [ ] Store credentials in password manager
- [ ] Delete `/opt/supabase/credentials.txt`
- [ ] Configure SMTP for emails
- [ ] Set up OAuth providers
- [ ] Review CORS settings
- [ ] Enable backup encryption

### Infrastructure
- [ ] DNS points to server
- [ ] TLS certificate valid
- [ ] Firewall rules verified
- [ ] SSH access tested
- [ ] fail2ban running

### Monitoring
- [ ] Email alerts configured
- [ ] Grafana dashboards imported
- [ ] External uptime monitoring (UptimeRobot, etc.)

### Backups
- [ ] Backup script tested
- [ ] Restore tested
- [ ] S3 configured
- [ ] Encryption enabled

### Operations
- [ ] Team trained on runbook
- [ ] Incident response plan
- [ ] Maintenance windows scheduled

See **README.md** for complete checklist.

## 🐛 Troubleshooting

### Services Not Starting
```bash
cd /opt/supabase
docker compose logs           # Check logs
df -h                          # Check disk space
docker compose restart         # Restart services
```

### TLS Certificate Issues
```bash
# Check DNS
dig api.example.com

# Manual certificate request
sudo certbot certonly --webroot -w /var/www/certbot -d api.example.com

# Check certificate
sudo certbot certificates
```

### Database Connection Issues
```bash
# Check PostgreSQL
docker compose exec db pg_isready -U postgres

# Check connections
docker compose exec db psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"
```

### High Resource Usage
```bash
# Check usage
docker stats
free -h
df -h

# Restart specific service
docker compose restart <service>
```

See **README.md** for more troubleshooting.

## 🆘 Getting Help

1. Check `/opt/supabase/RUNBOOK.md`
2. Check `/var/log/supabase-deployment.log`
3. Run health check: `sudo /opt/supabase/utils/health-check.sh`
4. Review logs: `docker compose logs`
5. Supabase Docs: https://supabase.com/docs
6. Supabase Discord: https://discord.supabase.com
7. GitHub Issues: https://github.com/supabase/supabase/issues

## 📈 Performance Tuning

### Database
- Adjust `max_connections` in PostgreSQL config
- Tune PgBouncer pool sizes in `.env`
- Enable query performance logging

### API
- Adjust Nginx rate limits
- Enable API caching
- Configure CDN for static assets

### Resources
- Increase server resources (CPU, RAM)
- Use dedicated database server
- Implement read replicas

## 🔐 Compliance

- Audit logging: Configure in `.env`
- Data retention: Configure backup retention
- GDPR: Configure data deletion policies
- Encryption: Enable backup encryption, TLS 1.3

## 🌐 High Availability (Advanced)

For HA setup:
- Database replication (streaming replication)
- Load balancer (HAProxy, AWS ALB)
- Multi-AZ deployment
- Automated failover

Not included in this script - manual configuration required.

## 📝 Version Information

- **Script Version**: 1.0.0
- **Supported OS**: Ubuntu 22.04+
- **Supabase**: Latest stable (pulled from Docker Hub)
- **Last Updated**: 2024

## 🤝 Contributing

Contributions welcome!
1. Test on fresh Ubuntu 22.04
2. Follow existing code style
3. Update documentation
4. Submit PR with clear description

## 📄 License

MIT License

## ⚠️ Important Notes

1. **Credentials**: Immediately move `/opt/supabase/credentials.txt` to secure storage and delete
2. **DNS**: Ensure DNS is configured before running with TLS
3. **Backups**: Test restore procedure before going to production
4. **SSH**: Test new SSH user before logging out as root
5. **Resources**: Minimum 4GB RAM, 2 CPU cores recommended
6. **Firewall**: Review and customize firewall rules for your environment
7. **Monitoring**: Configure email alerts before production
8. **Updates**: Pin Docker image versions in production for stability

---

**Questions?** Check README.md or the auto-generated RUNBOOK.md after deployment.

**Ready to deploy?** Run `sudo ./deploy_supabase.sh --help` for usage.

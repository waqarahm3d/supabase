# Supabase Production Deployment Automation

Complete, production-ready automation suite for self-hosting Supabase on Ubuntu 22.04+ servers.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Configuration](#configuration)
- [Security](#security)
- [Monitoring & Alerts](#monitoring--alerts)
- [Backup & Restore](#backup--restore)
- [Troubleshooting](#troubleshooting)
- [Acceptance Testing](#acceptance-testing)
- [Production Checklist](#production-checklist)

## Overview

This deployment automation provides a single-command solution to deploy a production-grade Supabase instance with:

- **Security**: Hardened SSH, firewall, fail2ban, TLS certificates
- **Reliability**: Health checks, monitoring, automated backups
- **Observability**: Prometheus, Grafana, alerting
- **Operations**: Comprehensive runbook, backup/restore procedures

## Features

### Core Deployment
- ✅ Automated installation of all dependencies (Docker, Nginx, Certbot, etc.)
- ✅ Non-root user creation with sudo privileges
- ✅ SSH hardening (disable password auth, root login)
- ✅ Supabase stack deployment (Kong, PostgREST, GoTrue, Realtime, Storage, Studio)
- ✅ Production environment configuration

### Security
- ✅ UFW firewall with minimal port exposure
- ✅ fail2ban for intrusion prevention
- ✅ TLS/SSL certificates via Let's Encrypt with auto-renewal
- ✅ RSA-4096 key generation for JWT RS256 signing
- ✅ Secure credential storage with restrictive permissions
- ✅ Nginx security headers and rate limiting

### Monitoring
- ✅ Prometheus metrics collection
- ✅ Grafana dashboards
- ✅ Alertmanager for notifications
- ✅ System metrics (CPU, memory, disk)
- ✅ Database metrics (connections, queries)
- ✅ Custom alert rules (resource usage, TLS expiry, service health)

### Backup & Recovery
- ✅ Automated daily PostgreSQL backups
- ✅ Docker volume backups
- ✅ Optional encryption for backups
- ✅ S3-compatible storage support
- ✅ Backup rotation (configurable retention)
- ✅ One-command restore functionality

### Operations
- ✅ Comprehensive operator runbook
- ✅ Service health checks and smoke tests
- ✅ Idempotent operations (safe to re-run)
- ✅ Detailed logging
- ✅ Both interactive and non-interactive modes

## Prerequisites

### Server Requirements

- **OS**: Ubuntu 22.04 LTS or newer
- **CPU**: Minimum 2 cores (4+ recommended for production)
- **RAM**: Minimum 4GB (8GB+ recommended for production)
- **Disk**: Minimum 20GB free space (50GB+ recommended)
- **Network**: Public IPv4 address with ports 80/443 accessible

### DNS Configuration

Before running the script, ensure:
1. You have a domain name (e.g., `api.example.com`)
2. DNS A record points to your server's public IP
3. DNS has propagated (check with `dig api.example.com`)

### Access Requirements

- Root or sudo access to the server
- SSH key-based authentication configured (recommended)
- Email address for Let's Encrypt notifications

### Optional

- S3-compatible storage for backups (AWS S3, MinIO, DigitalOcean Spaces, etc.)
- SMTP server for email notifications
- Vault or secrets management system

## Quick Start

### 1. Clone Repository

```bash
git clone https://github.com/yourusername/supabase-production.git
cd supabase-production
```

### 2. Run Deployment (Interactive Mode)

```bash
sudo ./deploy_supabase.sh \
  --domain api.example.com \
  --email admin@example.com
```

The script will:
1. Prompt for necessary credentials
2. Install all dependencies
3. Configure Supabase with production settings
4. Set up monitoring and backups
5. Obtain TLS certificates
6. Run health checks

### 3. Access Your Instance

After successful deployment:

- **API**: `https://api.example.com`
- **Studio**: `https://api.example.com/studio`
- **Grafana**: `http://localhost:3001` (SSH tunnel recommended)
- **Prometheus**: `http://localhost:9090` (SSH tunnel recommended)

## Usage

### Interactive Mode (Recommended for First-Time Setup)

```bash
sudo ./deploy_supabase.sh -d api.example.com -e admin@example.com
```

The script will interactively prompt for:
- PostgreSQL password
- JWT secret
- Dashboard credentials
- SMTP settings (optional)

### Non-Interactive Mode

#### With Environment File

```bash
# Create environment file
cp templates/env.template /secure/path/.env
# Edit /secure/path/.env with your values

# Run deployment
sudo ./deploy_supabase.sh \
  --env-file /secure/path/.env \
  --domain api.example.com \
  --email admin@example.com
```

#### With Vault Integration

```bash
sudo ./deploy_supabase.sh \
  --vault https://vault.example.com \
  --domain api.example.com \
  --email admin@example.com
```

### Partial Deployment

Skip certain steps if already configured:

```bash
# Skip user creation if user exists
sudo ./deploy_supabase.sh \
  --domain api.example.com \
  --skip-user-creation \
  --skip-ssh-hardening

# Skip Docker installation if already installed
sudo ./deploy_supabase.sh \
  --domain api.example.com \
  --skip-docker-install

# Skip monitoring stack
sudo ./deploy_supabase.sh \
  --domain api.example.com \
  --skip-monitoring

# Development setup (no TLS, no firewall)
sudo ./deploy_supabase.sh \
  --skip-tls \
  --skip-firewall
```

### Command-Line Options

```
Options:
  -d, --domain DOMAIN         Domain name (required for TLS)
  -e, --email EMAIL          Email for Let's Encrypt
  -p, --project-dir DIR      Installation directory (default: /opt/supabase)
  -b, --backup-dir DIR       Backup directory (default: /var/backups/supabase)
  -u, --user USERNAME        System user (default: supabase)

  --env-file FILE            Load environment from file
  --vault ENDPOINT           Vault endpoint for secrets

  --skip-user-creation       Skip user creation
  --skip-ssh-hardening       Skip SSH hardening
  --skip-docker-install      Skip Docker installation
  --skip-firewall            Skip firewall configuration
  --skip-monitoring          Skip monitoring stack
  --skip-backups             Skip backup configuration
  --skip-tls                 Skip TLS certificate setup

  --debug                    Enable debug logging
  -h, --help                 Show help message
```

## Configuration

### Environment Variables

All configuration is managed via environment variables. See `templates/env.template` for a complete reference.

#### Critical Variables

```bash
# Security (auto-generated if not provided)
POSTGRES_PASSWORD=          # PostgreSQL admin password
JWT_SECRET=                 # JWT signing secret
SERVICE_ROLE_KEY=           # Admin API key
DASHBOARD_PASSWORD=         # Studio password

# Site Configuration
SITE_URL=                   # Your public URL
API_EXTERNAL_URL=           # Public API URL

# SMTP (for authentication emails)
SMTP_HOST=
SMTP_PORT=
SMTP_USER=
SMTP_PASS=
```

#### Backup Configuration

```bash
# Backup settings
BACKUP_DIR=/var/backups/supabase
RETENTION_DAYS=7
BACKUP_ENCRYPTION_KEY=your-encryption-key

# S3 backup (optional)
S3_BUCKET=my-supabase-backups
S3_ENDPOINT=https://s3.amazonaws.com
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
```

### Nginx Configuration

Custom Nginx configuration: `templates/nginx-supabase.conf`

Modify rate limiting, timeouts, or security headers:

```nginx
# Rate limiting
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;

# File upload size
client_max_body_size 100M;
```

### Monitoring Configuration

Prometheus scrape configs and alerts: embedded in deployment script

Grafana dashboards: Import from [Supabase monitoring repository](https://github.com/supabase/supabase/tree/master/docker/monitoring)

## Security

### Credentials Storage

After deployment, credentials are saved to:
```
/opt/supabase/credentials.txt
```

**IMPORTANT**:
1. Copy credentials to a secure password manager
2. Delete the file: `sudo rm /opt/supabase/credentials.txt`
3. Never commit credentials to version control

### JWT Key Management

RS256 keys are generated at:
- Private: `/opt/supabase/keys/jwt-private.pem` (600 permissions)
- Public: `/opt/supabase/keys/jwt-public.pem` (644 permissions)

**Rotating JWT Keys**:
```bash
cd /opt/supabase
./scripts/rotate-jwt-keys.sh
```

### SSH Hardening

The script configures:
- Disable root login
- Disable password authentication
- Enable public key authentication only
- Restrict SSH access to supabase user

**After deployment**, ensure you can SSH as the new user before logging out:
```bash
ssh supabase@your-server
```

### Firewall Rules

Default UFW rules:
- **Allow**: 22 (SSH), 80 (HTTP), 443 (HTTPS)
- **Deny**: All other incoming traffic

View current rules:
```bash
sudo ufw status verbose
```

### TLS Certificate Management

Certificates auto-renew via cron. Manual renewal:
```bash
sudo certbot renew
sudo systemctl reload nginx
```

Check certificate expiry:
```bash
sudo certbot certificates
```

## Monitoring & Alerts

### Accessing Monitoring Tools

For security, monitoring tools are bound to localhost. Access via SSH tunnel:

```bash
# Prometheus
ssh -L 9090:localhost:9090 supabase@your-server

# Grafana
ssh -L 3001:localhost:3001 supabase@your-server

# Alertmanager
ssh -L 9093:localhost:9093 supabase@your-server
```

Then access:
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3001
- Alertmanager: http://localhost:9093

### Default Grafana Credentials

- Username: `admin`
- Password: Check `/opt/supabase/.env` or set `GRAFANA_PASSWORD`

### Alert Rules

Pre-configured alerts:
- **HighCPUUsage**: CPU > 80% for 5 minutes
- **HighMemoryUsage**: Memory > 85% for 5 minutes
- **HighDatabaseConnections**: PostgreSQL connections > 80
- **LowDiskSpace**: Disk usage > 85%
- **TLSCertificateExpiringSoon**: Certificate expires in < 30 days
- **ServiceDown**: Any monitored service is down for 2 minutes

### Configuring Email Alerts

Edit `/opt/supabase/monitoring/alertmanager.yml`:

```yaml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alerts@example.com'
  smtp_auth_username: 'alerts@example.com'
  smtp_auth_password: 'your-app-password'
  smtp_require_tls: true

receivers:
  - name: 'email'
    email_configs:
      - to: 'admin@example.com'
        send_resolved: true
```

Restart Alertmanager:
```bash
cd /opt/supabase/monitoring
docker compose -f docker-compose.monitoring.yml restart alertmanager
```

### Custom Dashboards

Import Supabase dashboards in Grafana:
1. Login to Grafana
2. Go to Dashboards → Import
3. Use dashboard IDs or JSON files from Supabase repo

## Backup & Restore

### Manual Backup

```bash
sudo /opt/supabase/scripts/backup.sh
```

Backups are stored in `/var/backups/supabase/` by default.

### Automated Backups

Backups run daily via cron at 2 AM (system time).

View backup logs:
```bash
tail -f /var/log/supabase-backup.log
```

### Backup Contents

Each backup includes:
- Full PostgreSQL dump (pg_dumpall)
- Docker volumes (db_data, storage_data)
- Configuration files (.env, docker-compose.yml)
- Metadata (timestamp, version info)

### Restore from Backup

```bash
sudo /opt/supabase/scripts/restore.sh /var/backups/supabase/supabase_backup_YYYYMMDD_HHMMSS.tar.gz
```

**Warning**: This will stop services and overwrite current data!

### Encrypted Backups

Set encryption key in environment:
```bash
export BACKUP_ENCRYPTION_KEY="your-strong-encryption-key"
```

Encrypted backups have `.enc` extension and require the key to restore.

### S3 Backup Storage

Configure S3 in `/opt/supabase/.env`:
```bash
S3_BUCKET=my-supabase-backups
S3_ENDPOINT=https://s3.amazonaws.com
AWS_ACCESS_KEY_ID=your-key
AWS_SECRET_ACCESS_KEY=your-secret
```

Backups will automatically upload to S3 after local creation.

## Troubleshooting

### Common Issues

#### 1. DNS not resolving

**Symptom**: Certificate generation fails
```
Error: DNS problem: NXDOMAIN looking up A for api.example.com
```

**Solution**:
```bash
# Verify DNS
dig api.example.com

# Wait for DNS propagation (can take up to 24 hours)
# Use --skip-tls flag and configure TLS later
```

#### 2. Port 80/443 not accessible

**Symptom**: Cannot access site via HTTPS

**Solution**:
```bash
# Check firewall
sudo ufw status

# Check if Nginx is running
sudo systemctl status nginx

# Check if ports are open
sudo netstat -tlnp | grep -E ':(80|443)'

# Verify cloud provider security groups allow 80/443
```

#### 3. Services not starting

**Symptom**: `docker compose ps` shows services as unhealthy

**Solution**:
```bash
# Check logs
cd /opt/supabase
docker compose logs

# Check disk space
df -h

# Restart services
docker compose restart

# Nuclear option: restart from scratch
docker compose down
docker compose up -d
```

#### 4. Out of memory

**Symptom**: Services crashing, OOM errors in logs

**Solution**:
```bash
# Check memory usage
free -h
docker stats

# Reduce worker counts in .env
# Add swap space
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

#### 5. High database connections

**Symptom**: "too many connections" errors

**Solution**:
```bash
# Check current connections
docker compose exec db psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"

# Kill idle connections
docker compose exec db psql -U postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'idle';"

# Increase max connections in postgresql.conf
# Adjust PgBouncer pool sizes in .env
```

### Getting Help

1. Check the operator runbook: `/opt/supabase/RUNBOOK.md`
2. View deployment logs: `/var/log/supabase-deployment.log`
3. Check service logs: `docker compose logs [service]`
4. Review Supabase documentation: https://supabase.com/docs
5. Join Supabase Discord: https://discord.supabase.com
6. File an issue: https://github.com/supabase/supabase/issues

## Acceptance Testing

Run these tests after deployment to verify everything works:

### 1. Service Health Checks

```bash
# Check all containers are running
cd /opt/supabase
docker compose ps

# Expected: All services should show "running" or "healthy"
```

### 2. API Endpoint Tests

```bash
# Health check
curl -f https://api.example.com/health

# Expected: HTTP 200, "healthy"

# REST API (should return 401 without API key)
curl -I https://api.example.com/rest/v1/

# Expected: HTTP 401 or similar auth error (proves API is working)
```

### 3. Studio Access

```bash
# Access Studio UI
curl -f https://api.example.com/studio

# Expected: HTTP 200, HTML response

# Login via browser: https://api.example.com/studio
# Use credentials from /opt/supabase/credentials.txt
```

### 4. Database Connectivity

```bash
# Test PostgreSQL connection
docker compose exec db psql -U postgres -c "SELECT version();"

# Expected: PostgreSQL version information
```

### 5. TLS Certificate Validation

```bash
# Check certificate
echo | openssl s_client -servername api.example.com -connect api.example.com:443 2>/dev/null | openssl x509 -noout -dates

# Expected: Valid not before/after dates, not expired
```

### 6. Monitoring Stack

```bash
# Check Prometheus
curl -f http://localhost:9090/-/healthy

# Check Grafana
curl -f http://localhost:3001/api/health

# Expected: HTTP 200 for both
```

### 7. Backup System

```bash
# Run manual backup
sudo /opt/supabase/scripts/backup.sh

# Verify backup created
ls -lh /var/backups/supabase/

# Expected: New backup file with recent timestamp
```

### 8. Firewall Rules

```bash
# Check UFW status
sudo ufw status verbose

# Expected: 22, 80, 443 allowed; default deny incoming
```

### 9. Create Test User (API Test)

```bash
# Get your anon key from .env
ANON_KEY=$(grep ANON_KEY /opt/supabase/.env | cut -d'=' -f2)

# Try to sign up (should work if signup enabled)
curl -X POST "https://api.example.com/auth/v1/signup" \
  -H "apikey: $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "testpassword123"
  }'

# Expected: User created or error response (proves auth is working)
```

### 10. Storage Upload Test

```bash
# Create test bucket via Studio or API
# Upload test file
# Verify file accessible

# This validates the storage service is working
```

## Production Checklist

Before going live with production traffic:

### Security
- [ ] Change all default passwords
- [ ] Store credentials in password manager
- [ ] Delete `/opt/supabase/credentials.txt`
- [ ] Configure SMTP for authentication emails
- [ ] Set up OAuth providers (Google, GitHub, etc.)
- [ ] Review and customize CORS settings
- [ ] Enable rate limiting appropriate for your use case
- [ ] Set up API key rotation policy
- [ ] Configure backup encryption

### DNS & Networking
- [ ] DNS A record points to server
- [ ] DNS has fully propagated
- [ ] TLS certificate obtained and valid
- [ ] Certificate auto-renewal tested
- [ ] Firewall rules reviewed
- [ ] fail2ban configured and running

### Monitoring
- [ ] Email alerts configured and tested
- [ ] Grafana dashboards imported
- [ ] Custom alerts added for your use case
- [ ] Log aggregation configured
- [ ] Uptime monitoring (external service like UptimeRobot)

### Backups
- [ ] Backup script tested
- [ ] Restore procedure tested
- [ ] S3 or remote backup storage configured
- [ ] Backup encryption enabled
- [ ] Backup monitoring/alerts configured
- [ ] Documented backup/restore procedures

### Performance
- [ ] Database connection pooling configured
- [ ] PgBouncer settings tuned for your workload
- [ ] Nginx caching configured (if applicable)
- [ ] CDN configured for static assets (optional)
- [ ] Load testing performed

### Documentation
- [ ] Operator runbook reviewed
- [ ] Team trained on operational procedures
- [ ] Incident response plan documented
- [ ] Escalation paths defined
- [ ] Maintenance windows scheduled

### Compliance
- [ ] Data retention policies configured
- [ ] Audit logging enabled
- [ ] Privacy policy updated
- [ ] Terms of service updated
- [ ] GDPR/compliance requirements met (if applicable)

### High Availability (Optional)
- [ ] Database replication configured
- [ ] Load balancer configured
- [ ] Multi-AZ deployment
- [ ] Disaster recovery plan tested

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                            │
└────────────────────────┬────────────────────────────────────┘
                         │
                    Port 80/443
                         │
                         ▼
              ┌──────────────────────┐
              │  Nginx Reverse Proxy │
              │  - TLS Termination   │
              │  - Rate Limiting     │
              │  - Security Headers  │
              └──────────┬───────────┘
                         │
           ┌─────────────┼─────────────┐
           │             │             │
           ▼             ▼             ▼
    ┌───────────┐ ┌───────────┐ ┌───────────┐
    │   Kong    │ │  Studio   │ │ Monitoring│
    │  Gateway  │ │    UI     │ │   Stack   │
    └─────┬─────┘ └───────────┘ └───────────┘
          │
    ┌─────┴──────┬──────────┬──────────┬─────────┐
    │            │          │          │         │
    ▼            ▼          ▼          ▼         ▼
┌────────┐  ┌────────┐ ┌─────────┐ ┌────────┐ ┌────────┐
│GoTrue  │  │PostgREST│ │Realtime│ │Storage │ │  Meta  │
│ Auth   │  │   API   │ │         │ │        │ │        │
└────┬───┘  └────┬────┘ └────┬────┘ └───┬────┘ └────┬───┘
     │           │           │           │          │
     └───────────┴───────────┴───────────┴──────────┘
                         │
                         ▼
                 ┌───────────────┐
                 │  PostgreSQL   │
                 │   Database    │
                 └───────┬───────┘
                         │
                         ▼
                  ┌─────────────┐
                  │   Backups   │
                  │  (Local/S3) │
                  └─────────────┘
```

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Test thoroughly on a fresh Ubuntu 22.04 instance
4. Submit pull request with clear description

## License

MIT License - see LICENSE file for details

## Support

- Documentation: This README and `/opt/supabase/RUNBOOK.md`
- Issues: GitHub Issues
- Community: Supabase Discord
- Commercial Support: Contact Supabase team

---

**Maintained by**: SRE Team
**Last Updated**: 2024
**Version**: 1.0.0

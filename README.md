# Supabase Self-Hosted Setup

Complete self-hosted Supabase installation optimized for **4GB RAM / 2 CPU servers** with full security, automation, and monitoring.

## 🎯 Overview

This setup provides:
- **Optimized Performance**: Tuned for 4GB RAM / 2 CPU hardware
- **Secure by Default**: Strong passwords, JWT secrets, SSL/TLS
- **Automated Setup**: One command to generate all configurations
- **Easy Management**: Simple scripts for start, stop, backup, restore
- **Production Ready**: Includes monitoring, logging, and health checks
- **Domain Configuration**: Pre-configured for db.qoqnuz.com (API) and studio.qoqnuz.com (Studio)

## 📋 Prerequisites

- Ubuntu 20.04+ or Debian 11+ (recommended)
- 4GB RAM minimum
- 2 CPU cores minimum
- 40GB disk space minimum
- Docker and Docker Compose installed
- Root or sudo access
- Domain names configured:
  - `db.qoqnuz.com` → Your server IP (for API)
  - `studio.qoqnuz.com` → Your server IP (for Studio/Dashboard)

## 🚀 Quick Start

### 1. Initial Setup

Run the automated setup script:

```bash
sudo chmod +x setup.sh
sudo ./setup.sh
```

This script will:
- Generate secure passwords and JWT secrets
- Create JWT tokens (anon and service_role keys)
- Configure your domains
- Set up database initialization scripts
- Create directory structure
- Pull all required Docker images

**Important**: Save the credentials displayed at the end! They are also saved in `credentials.txt`.

### 2. SSL Certificate Setup

Set up SSL certificates for HTTPS:

```bash
sudo chmod +x setup-ssl.sh
sudo ./setup-ssl.sh
```

Choose between:
- **Let's Encrypt** (recommended for production, free)
- **Self-signed** (for testing only)

### 3. Start Supabase

```bash
sudo chmod +x start.sh
sudo ./start.sh
```

Services will be available at:
- **Supabase Studio**: https://studio.qoqnuz.com
- **API Endpoint**: https://db.qoqnuz.com

## 📁 Project Structure

```
supabase/
├── docker-compose.yml          # Main Docker Compose configuration
├── .env                         # Environment variables (generated)
├── .env.example                 # Example environment file
├── nginx.conf                   # Nginx reverse proxy configuration
├── setup.sh                     # Initial setup script
├── setup-ssl.sh                 # SSL certificate setup
├── start.sh                     # Start Supabase
├── stop.sh                      # Stop Supabase
├── backup.sh                    # Backup database and storage
├── restore.sh                   # Restore from backup
├── health-check.sh              # System health check
├── credentials.txt              # Generated credentials (keep secure!)
├── ssl/                         # SSL certificates
│   ├── db.qoqnuz.com.crt
│   ├── db.qoqnuz.com.key
│   ├── studio.qoqnuz.com.crt
│   └── studio.qoqnuz.com.key
└── volumes/                     # Persistent data
    ├── api/
    │   └── kong.yml            # Kong API Gateway configuration
    ├── db/
    │   ├── data/               # PostgreSQL data (persistent)
    │   ├── postgresql.conf     # Optimized PostgreSQL config
    │   ├── roles.sql           # Database roles initialization
    │   ├── jwt.sql             # JWT functions
    │   ├── webhooks.sql        # Webhooks support
    │   ├── realtime.sql        # Realtime initialization
    │   └── logs.sql            # Logging schema
    ├── storage/                # File storage (persistent)
    ├── functions/              # Edge Functions
    │   └── main/
    │       └── index.ts        # Example function
    └── logs/
        └── vector.yml          # Log collection configuration
```

## 🔧 Management Commands

### Start/Stop

```bash
# Start all services
./start.sh

# Stop all services
./stop.sh

# Restart services
./stop.sh && ./start.sh
```

### View Logs

```bash
# View all logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f db          # Database
docker-compose logs -f kong        # API Gateway
docker-compose logs -f auth        # Auth service
docker-compose logs -f studio      # Studio UI
docker-compose logs -f storage     # Storage service
docker-compose logs -f realtime    # Realtime service
```

### Health Check

```bash
./health-check.sh
```

Shows:
- Service health status
- Memory and CPU usage
- Disk space
- Container resource usage

### Backup & Restore

```bash
# Create backup
./backup.sh

# Restore from backup
./restore.sh backups/20240101_120000

# List available backups
ls -l backups/
```

Backups include:
- Complete database dump
- Storage files
- Configuration files
- Backup metadata

## 🔒 Security Features

### 1. Strong Authentication
- Randomly generated 32-character passwords
- Secure JWT secrets
- Dashboard authentication required

### 2. SSL/TLS Encryption
- HTTPS for all connections
- Let's Encrypt integration
- Automatic certificate renewal

### 3. Network Security
- Kong API Gateway with rate limiting
- CORS configuration
- Security headers (XSS, frame protection, etc.)

### 4. Database Security
- SCRAM-SHA-256 password encryption
- Role-based access control (RBAC)
- Separate admin and service roles

### 5. Firewall Configuration

Recommended firewall rules:

```bash
# Allow SSH (be careful!)
ufw allow 22/tcp

# Allow HTTP/HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Allow PostgreSQL (optional, for external access)
ufw allow 5432/tcp

# Enable firewall
ufw enable
```

## ⚙️ Configuration

### Environment Variables

Key variables in `.env`:

```bash
# Domains
API_DOMAIN=db.qoqnuz.com
STUDIO_DOMAIN=studio.qoqnuz.com

# Security (auto-generated)
POSTGRES_PASSWORD=xxx
JWT_SECRET=xxx
ANON_KEY=xxx
SERVICE_ROLE_KEY=xxx
DASHBOARD_PASSWORD=xxx

# Email (configure for auth)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-password
```

### PostgreSQL Configuration

The PostgreSQL configuration in `volumes/db/postgresql.conf` is optimized for 4GB RAM:

- **shared_buffers**: 1GB (25% of RAM)
- **effective_cache_size**: 3GB (75% of RAM)
- **work_mem**: 16MB
- **maintenance_work_mem**: 256MB
- **max_connections**: 100
- **max_worker_processes**: 2

### Resource Limits

Docker Compose includes resource limits to prevent memory issues:

- Database: 2GB memory limit
- Kong: 512MB memory limit
- Other services: 256-512MB each

## 🌐 Accessing Supabase

### Supabase Studio (Dashboard)

1. Open https://studio.qoqnuz.com
2. Login with credentials from setup
3. Create your first project
4. Start building!

### API Access

Use these credentials in your application:

```javascript
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://db.qoqnuz.com'
const supabaseAnonKey = 'YOUR_ANON_KEY'

const supabase = createClient(supabaseUrl, supabaseAnonKey)
```

### Direct Database Access

```bash
# Connect via psql
docker exec -it supabase-db psql -U postgres

# Or from outside the container
psql -h localhost -U postgres -p 5432 -d postgres
```

## 📊 Monitoring

### Health Endpoints

- Studio: `https://studio.qoqnuz.com/health`
- API: `https://db.qoqnuz.com/health`

### System Monitoring

```bash
# Quick health check
./health-check.sh

# Docker stats
docker stats

# Service status
docker-compose ps

# System resources
htop
```

### Logs and Analytics

Supabase includes Logflare for analytics:
- Access via Studio UI
- Query logs and metrics
- Monitor API usage

## 🔄 Updates and Maintenance

### Update Supabase

```bash
# Pull latest images
docker-compose pull

# Restart services
./stop.sh && ./start.sh
```

### Database Maintenance

```bash
# Vacuum database
docker exec supabase-db psql -U postgres -c "VACUUM ANALYZE;"

# Check database size
docker exec supabase-db psql -U postgres -c "
  SELECT pg_database.datname,
         pg_size_pretty(pg_database_size(pg_database.datname)) AS size
  FROM pg_database;"
```

### Storage Cleanup

```bash
# Remove unused Docker resources
docker system prune -a

# Check disk usage
df -h
du -sh volumes/
```

## 🚨 Troubleshooting

### Services Won't Start

```bash
# Check logs
docker-compose logs

# Check for port conflicts
netstat -tulpn | grep -E '(80|443|5432|8000|3000)'

# Restart individual service
docker-compose restart [service_name]
```

### Database Connection Issues

```bash
# Check database is running
docker exec supabase-db pg_isready -U postgres

# Check connection from another service
docker exec supabase-rest nc -zv db 5432

# Review database logs
docker-compose logs db
```

### Memory Issues

```bash
# Check memory usage
free -h
docker stats --no-stream

# If out of memory, reduce max_connections in postgresql.conf
# Or increase server RAM
```

### SSL Certificate Issues

```bash
# Check certificate validity
openssl x509 -in ssl/db.qoqnuz.com.crt -text -noout

# Renew Let's Encrypt certificates
certbot renew

# Test HTTPS
curl -v https://db.qoqnuz.com/health
```

## 📝 Best Practices

1. **Regular Backups**: Run `./backup.sh` daily (set up cron job)
2. **Monitor Resources**: Check `./health-check.sh` regularly
3. **Update Regularly**: Pull updates monthly
4. **Review Logs**: Check for errors weekly
5. **Test Restores**: Verify backups work monthly
6. **Security Updates**: Keep OS and Docker updated
7. **Use Strong Passwords**: Don't change auto-generated ones to weaker versions
8. **Enable Monitoring**: Set up external monitoring (UptimeRobot, etc.)

## 🔐 Credentials Reference

After running `setup.sh`, you'll receive:

- **Dashboard Username**: supabase
- **Dashboard Password**: [auto-generated]
- **Database Password**: [auto-generated]
- **Anon Key**: [auto-generated JWT]
- **Service Role Key**: [auto-generated JWT]

These are saved in `credentials.txt` - **keep this file secure**!

## 📚 Additional Resources

- [Supabase Official Docs](https://supabase.com/docs)
- [Self-Hosting Guide](https://supabase.com/docs/guides/self-hosting)
- [PostgreSQL Tuning](https://pgtune.leopard.in.ua/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)

## 💡 Tips

### Enable Realtime for a Table

In Studio UI:
1. Go to Database → Replication
2. Enable replication for desired tables
3. Tables will receive real-time updates

### Create Edge Function

```bash
# Create new function
mkdir -p volumes/functions/my-function
nano volumes/functions/my-function/index.ts

# Restart to load
docker-compose restart functions
```

### Configure Email Auth

1. Update SMTP settings in `.env`
2. Restart: `./stop.sh && ./start.sh`
3. Test in Studio → Authentication

### Set Up Storage Buckets

1. Go to Storage in Studio
2. Create new bucket
3. Set policies (public/private)
4. Upload files via UI or API

## ⚠️ Important Notes

1. **First Time Setup**: Allow 5-10 minutes for all services to fully initialize
2. **DNS Propagation**: Ensure DNS is pointing to your server before SSL setup
3. **Firewall**: Configure firewall before exposing to internet
4. **Backups**: Set up automated backups immediately
5. **Monitoring**: Implement external monitoring for production use
6. **Resource Limits**: 4GB RAM is minimum; 8GB recommended for production
7. **Database Growth**: Monitor disk space as database grows

## 📧 Support

For issues with this setup:
1. Check logs: `docker-compose logs`
2. Run health check: `./health-check.sh`
3. Review troubleshooting section above
4. Check official Supabase docs

## 📄 License

This setup configuration is provided as-is for self-hosting Supabase.
Supabase itself is licensed under Apache 2.0.

---

**Ready to start?** Run `./setup.sh` and follow the prompts!

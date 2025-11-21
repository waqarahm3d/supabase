# Supabase Self-Hosted Project Overview

## 📊 Project Summary

This is a complete, production-ready Supabase self-hosted setup optimized for **4GB RAM / 2 CPU servers**. It includes automated deployment, security hardening, monitoring, backup/restore capabilities, and comprehensive documentation.

### Key Features

✅ **Optimized Configuration**
- PostgreSQL tuned for 4GB RAM
- Resource limits on all containers
- Efficient caching strategies
- Connection pooling configured

✅ **Security Hardened**
- SSL/TLS encryption (Let's Encrypt support)
- Strong password generation
- JWT token security
- Rate limiting enabled
- Security headers configured
- Firewall-ready configuration

✅ **Fully Automated**
- One-command setup
- Automatic secret generation
- SSL certificate automation
- Backup scheduling support
- Health monitoring

✅ **Production Ready**
- Domain configuration (db.qoqnuz.com, studio.qoqnuz.com)
- Nginx reverse proxy
- Docker Compose orchestration
- Log aggregation (Logflare)
- Monitoring scripts

✅ **Well Documented**
- Complete README
- Quick start guide
- Security guide
- Troubleshooting guide
- Deployment checklist

## 🏗️ Architecture

```
                                    Internet
                                       │
                                       ↓
                              [DNS: qoqnuz.com]
                                   │
                        ┌──────────┴──────────┐
                        │                     │
                  db.qoqnuz.com       studio.qoqnuz.com
                        │                     │
                        ↓                     ↓
                   [Nginx: 443]          [Nginx: 443]
                        │                     │
                        ↓                     ↓
                  [Kong: 8000]          [Studio: 3000]
                        │
          ┌─────────────┼─────────────┬────────────┐
          ↓             ↓             ↓            ↓
      [Auth:9999]  [REST:3000]  [Storage:5000]  [Realtime:4000]
          │             │             │            │
          └─────────────┴─────────────┴────────────┘
                            │
                            ↓
                   [PostgreSQL:5432]
                            │
                            ↓
                   [Persistent Storage]
```

### Components

| Service | Purpose | Port | Memory Limit |
|---------|---------|------|--------------|
| **PostgreSQL** | Main database | 5432 | 2GB |
| **Kong** | API Gateway | 8000, 8443 | 512MB |
| **GoTrue** | Authentication | 9999 | 256MB |
| **PostgREST** | REST API | 3000 | 256MB |
| **Storage API** | File storage | 5000 | 512MB |
| **Realtime** | WebSocket/Realtime | 4000 | 256MB |
| **Studio** | Web UI/Dashboard | 3000 | 512MB |
| **Meta** | Database metadata | 8080 | 256MB |
| **Logflare** | Logging/Analytics | 4000 | 256MB |
| **Vector** | Log collection | 9001 | 128MB |
| **ImgProxy** | Image processing | 5001 | 256MB |

**Total Memory**: ~3.8GB (leaves room for OS overhead on 4GB server)

## 📁 File Structure

```
supabase/
├── 📄 Core Configuration Files
│   ├── docker-compose.yml       # Main orchestration
│   ├── .env                     # Environment variables (generated, git-ignored)
│   ├── .env.example             # Template for environment
│   └── nginx.conf               # Reverse proxy config
│
├── 🔧 Setup & Management Scripts
│   ├── setup.sh                 # Initial setup (generates secrets)
│   ├── setup-ssl.sh             # SSL certificate setup
│   ├── start.sh                 # Start all services
│   ├── stop.sh                  # Stop all services
│   ├── backup.sh                # Create backup
│   ├── restore.sh               # Restore from backup
│   ├── update.sh                # Update to latest versions
│   ├── health-check.sh          # System health check
│   └── monitor.sh               # Monitoring script (for cron)
│
├── 📚 Documentation
│   ├── README.md                # Main documentation
│   ├── QUICK-START.md           # 5-minute quick start
│   ├── SECURITY.md              # Security guide
│   ├── TROUBLESHOOTING.md       # Common issues & solutions
│   ├── DEPLOYMENT-CHECKLIST.md  # Step-by-step deployment guide
│   └── PROJECT-OVERVIEW.md      # This file
│
├── 📂 volumes/                  # Persistent data
│   ├── api/
│   │   └── kong.yml             # Kong API Gateway routing
│   ├── db/
│   │   ├── data/                # PostgreSQL data (git-ignored)
│   │   ├── postgresql.conf      # Optimized PostgreSQL config
│   │   ├── roles.sql            # Database roles setup
│   │   ├── jwt.sql              # JWT functions
│   │   ├── webhooks.sql         # Webhooks support
│   │   ├── realtime.sql         # Realtime schema
│   │   └── logs.sql             # Logging schema
│   ├── storage/                 # File uploads (git-ignored)
│   ├── functions/               # Edge Functions
│   │   └── main/
│   │       └── index.ts         # Example function
│   └── logs/
│       └── vector.yml           # Log collection config
│
├── 🔐 ssl/                      # SSL certificates (git-ignored)
│   ├── db.qoqnuz.com.crt
│   ├── db.qoqnuz.com.key
│   ├── studio.qoqnuz.com.crt
│   └── studio.qoqnuz.com.key
│
├── 💾 backups/                  # Database backups (git-ignored)
│   └── YYYYMMDD_HHMMSS/
│       ├── database.sql
│       ├── storage.tar.gz
│       ├── .env.backup
│       └── backup_info.txt
│
└── 🔑 credentials.txt           # Generated credentials (git-ignored)
```

## 🚀 Quick Start Commands

```bash
# Initial setup
sudo ./setup.sh

# Setup SSL
sudo ./setup-ssl.sh

# Start
sudo ./start.sh

# Stop
sudo ./stop.sh

# Backup
sudo ./backup.sh

# Health check
sudo ./health-check.sh

# Update
sudo ./update.sh
```

## 🔒 Security Features

### Authentication & Authorization
- ✅ Strong password generation (32+ characters)
- ✅ JWT-based authentication
- ✅ Role-based access control (anon, authenticated, service_role)
- ✅ Row Level Security (RLS) support
- ✅ API key authentication

### Network Security
- ✅ SSL/TLS encryption (HTTPS)
- ✅ Rate limiting (Kong)
- ✅ CORS configuration
- ✅ Security headers (XSS, frame protection)
- ✅ Firewall-ready configuration

### Database Security
- ✅ SCRAM-SHA-256 password encryption
- ✅ Separate database roles
- ✅ Limited connection access
- ✅ Audit logging support (pgaudit)

### File Security
- ✅ Secured .env file (chmod 600)
- ✅ Secured credentials.txt (chmod 600)
- ✅ Secured SSL keys (chmod 600)
- ✅ Git-ignored sensitive files

## 📊 Monitoring & Maintenance

### Health Monitoring
- Automated health checks
- Service status monitoring
- Resource usage tracking
- Database connectivity tests
- API endpoint verification

### Backup Strategy
- Automated daily backups
- Database dump (pg_dump)
- Storage files backup
- Configuration backup
- 7-day retention policy

### Update Process
1. Create backup
2. Pull new images
3. Restart services
4. Verify health
5. Rollback if needed

## 🎯 Performance Optimization

### PostgreSQL Tuning (4GB RAM)
```
shared_buffers = 1GB              # 25% of RAM
effective_cache_size = 3GB        # 75% of RAM
work_mem = 16MB                   # Per operation
maintenance_work_mem = 256MB      # For VACUUM, INDEX
max_connections = 100             # Limited for low RAM
max_worker_processes = 2          # Match CPU cores
```

### Container Resource Limits
- Database: 2GB max memory
- Kong: 512MB max memory
- Storage: 512MB max memory
- Other services: 256MB each

### Caching Strategy
- PostgreSQL query cache
- Kong response caching
- Browser caching (via headers)
- Image caching (ImgProxy)

## 🌐 Domain Configuration

### API Domain: db.qoqnuz.com
**Purpose**: REST API, Auth, Storage, Realtime

**Endpoints**:
- `/rest/v1/*` - REST API (PostgREST)
- `/auth/v1/*` - Authentication (GoTrue)
- `/storage/v1/*` - File storage
- `/realtime/v1/*` - WebSocket connections
- `/functions/v1/*` - Edge Functions

**Usage in apps**:
```javascript
const supabase = createClient(
  'https://db.qoqnuz.com',
  'YOUR_ANON_KEY'
)
```

### Studio Domain: studio.qoqnuz.com
**Purpose**: Web-based database management UI

**Features**:
- SQL editor
- Table browser
- Authentication management
- Storage management
- Real-time logs
- API documentation

**Access**: `https://studio.qoqnuz.com`

## 🔧 Customization

### Adding Edge Functions
```bash
mkdir volumes/functions/my-function
nano volumes/functions/my-function/index.ts
docker-compose restart functions
```

### Changing Ports
Edit `.env`:
```bash
KONG_HTTP_PORT=8001
POSTGRES_PORT=5433
```

### Adding Custom PostgreSQL Extensions
Edit SQL files in `volumes/db/` and restart database.

### Configuring Email Auth
Update in `.env`:
```bash
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
```

## 📈 Scaling Considerations

### When to Upgrade

**Upgrade RAM (to 8GB) if:**
- Memory usage consistently > 90%
- Frequent OOMKilled containers
- Database queries are slow
- Many concurrent users (> 100)

**Upgrade CPU (to 4 cores) if:**
- CPU usage consistently > 80%
- Slow API responses
- Many concurrent connections
- Heavy real-time usage

**Add Storage if:**
- Disk usage > 80%
- Large file uploads
- Growing database

### Horizontal Scaling
For high-traffic applications, consider:
- Multiple Kong instances (load balanced)
- Read replicas for PostgreSQL
- External S3 for storage
- Redis for caching
- CDN for static assets

## 🐛 Common Issues

| Issue | Quick Fix |
|-------|-----------|
| Services won't start | `docker-compose logs` |
| Can't access Studio | Check DNS, SSL, firewall |
| Database connection fails | `docker-compose restart db` |
| API returns 401 | Verify API key from `.env` |
| Storage upload fails | Check disk space, permissions |
| High memory usage | Reduce `max_connections` |
| Slow performance | Add indexes, run VACUUM |

See `TROUBLESHOOTING.md` for detailed solutions.

## 📞 Support Resources

- **Documentation**: See files in this repository
- **Supabase Docs**: https://supabase.com/docs
- **Discord**: https://discord.supabase.com
- **GitHub Issues**: https://github.com/supabase/supabase/issues
- **Stack Overflow**: Tag `supabase`

## 🎓 Learning Resources

### For Beginners
1. Read `QUICK-START.md`
2. Follow `DEPLOYMENT-CHECKLIST.md`
3. Explore Studio UI
4. Try example queries

### For Advanced Users
1. Review `SECURITY.md`
2. Customize PostgreSQL config
3. Set up monitoring alerts
4. Implement custom Edge Functions
5. Configure OAuth providers

## 📋 Maintenance Schedule

### Daily
- ✅ Run `./health-check.sh`
- ✅ Review logs for errors
- ✅ Check disk space

### Weekly
- ✅ Review database performance
- ✅ Check backup success
- ✅ Review failed login attempts
- ✅ Check for Docker updates

### Monthly
- ✅ Run `./update.sh`
- ✅ Test backup restore
- ✅ Review SSL expiry
- ✅ Security audit
- ✅ Check for unused resources

## 🎯 Project Goals Achieved

✅ **Optimal Configuration**: Tuned for 4GB RAM / 2 CPU
✅ **UI Settings Visible**: All config in `.env`, viewable in Studio
✅ **Secure & Protected**: SSL, strong secrets, security headers
✅ **Login to Studio**: Full Studio UI access
✅ **Domain Configuration**: db.qoqnuz.com (API) & studio.qoqnuz.com (Studio)
✅ **Automated Process**: One-command setup with `./setup.sh`

## 🚦 Status Indicators

When running `./health-check.sh`, you should see:
```
Database (PostgreSQL)... ✓ Healthy
API Gateway (Kong)... ✓ Healthy
Auth Service... ✓ Healthy
Storage Service... ✓ Healthy
Realtime Service... ✓ Healthy
```

If any show `✗ Unhealthy`, see `TROUBLESHOOTING.md`.

## 📝 Next Steps

After deployment:
1. ✅ Run `./setup.sh` - Generate configuration
2. ✅ Run `./setup-ssl.sh` - Set up SSL
3. ✅ Run `./start.sh` - Start services
4. ✅ Access `https://studio.qoqnuz.com` - Log in
5. ✅ Create your first table
6. ✅ Enable RLS on tables
7. ✅ Integrate with your app
8. ✅ Set up monitoring
9. ✅ Schedule backups
10. ✅ Enjoy your self-hosted Supabase! 🎉

---

**Project Version**: 1.0.0
**Supabase Version**: Latest (as of image pull date)
**Optimized For**: 4GB RAM / 2 CPU
**Domains**: db.qoqnuz.com, studio.qoqnuz.com
**License**: Apache 2.0 (Supabase)

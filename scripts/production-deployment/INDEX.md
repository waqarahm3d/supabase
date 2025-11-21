# Supabase Production Deployment - File Index

Complete reference of all files in this deployment package.

## 📁 Directory Structure

```
production-deployment/
├── deploy_supabase.sh              ⭐ Main deployment script
├── INDEX.md                        📋 This file
├── README.md                       📖 Complete documentation
├── DEPLOYMENT_SUMMARY.md           📊 Executive summary
├── QUICK_REFERENCE.md              🔖 Operator quick reference
│
├── templates/                      📄 Configuration templates
│   ├── nginx-supabase.conf         # Nginx reverse proxy config
│   └── env.template                # Environment variables reference
│
├── docs/                           📚 Additional documentation
│   └── RS256_JWT_MIGRATION.md      # JWT RS256 migration guide
│
└── utils/                          🔧 Utility scripts
    ├── health-check.sh             # System health verification
    └── rotate-jwt-keys.sh          # JWT key rotation utility
```

## 📄 File Descriptions

### Core Scripts

#### `deploy_supabase.sh` ⭐ **[EXECUTABLE]**
**Purpose**: Main automated deployment script
**Size**: ~1000 lines
**Usage**: `sudo ./deploy_supabase.sh --domain api.example.com --email admin@example.com`

**Features**:
- Full system setup (Docker, Nginx, etc.)
- User creation and SSH hardening
- Supabase stack deployment
- TLS certificate management
- Firewall configuration
- Monitoring stack setup
- Backup configuration
- Health checks
- Interactive and non-interactive modes

**Key Functions**:
- `preflight_checks()` - System validation
- `install_docker()` - Docker Engine installation
- `configure_environment()` - Environment setup
- `setup_tls_certificates()` - Let's Encrypt integration
- `configure_firewall()` - UFW and fail2ban
- `setup_monitoring()` - Prometheus/Grafana
- `setup_backups()` - Backup automation
- `smoke_tests()` - Post-deployment validation

---

### Documentation

#### `README.md` 📖
**Purpose**: Comprehensive user and operator documentation
**Sections**:
- Quick start guide
- Usage examples (interactive/non-interactive)
- Configuration reference
- Security best practices
- Monitoring and alerting
- Backup and restore
- Troubleshooting
- Acceptance testing
- Production checklist

**Audience**: DevOps engineers, SREs, System administrators

---

#### `DEPLOYMENT_SUMMARY.md` 📊
**Purpose**: High-level overview and quick start
**Sections**:
- What's included
- Quick start (5-minute deployment)
- Key features
- Deployment modes
- Configuration overview
- Security considerations
- Common operations
- Emergency procedures

**Audience**: Managers, technical leads, new operators

---

#### `QUICK_REFERENCE.md` 🔖
**Purpose**: Emergency operations cheat sheet
**Format**: Command-line ready, printable
**Sections**:
- Emergency commands
- Common operations
- Diagnostics
- Monitoring access
- Security operations
- Alert thresholds
- Useful one-liners

**Audience**: On-call engineers, incident responders

---

#### `INDEX.md` 📋
**Purpose**: This file - complete file reference
**Audience**: All users

---

### Templates

#### `templates/nginx-supabase.conf` 🌐
**Purpose**: Production-ready Nginx configuration
**Size**: ~250 lines

**Features**:
- HTTP to HTTPS redirect
- TLS/SSL best practices (TLS 1.2/1.3 only)
- Security headers (HSTS, CSP, etc.)
- Rate limiting (API, auth, uploads)
- WebSocket support (Realtime)
- Large file uploads (500MB for storage)
- Upstream definitions (Kong, Studio)
- Health check endpoint
- Logging configuration

**Usage**: Referenced by deployment script, can be customized

**Paths**:
- Kong API: → http://localhost:8000
- Studio UI: → http://localhost:3000

---

#### `templates/env.template` ⚙️
**Purpose**: Environment variables reference
**Size**: ~200 lines
**Format**: Shell-compatible `.env` format

**Variable Categories**:
- **Secrets**: Passwords, JWT tokens, API keys
- **Site Config**: Domain, URLs, ports
- **Database**: PostgreSQL, PgBouncer settings
- **Authentication**: GoTrue, OAuth providers
- **SMTP**: Email configuration
- **Storage**: S3 or local storage backend
- **Realtime**: WebSocket settings
- **API**: PostgREST configuration
- **Monitoring**: Grafana password
- **Backups**: S3, encryption, retention
- **Features**: Feature flags

**Usage**: Copy to `/opt/supabase/.env` and customize

---

### Documentation (Additional)

#### `docs/RS256_JWT_MIGRATION.md` 🔐
**Purpose**: Guide for migrating from HS256 to RS256 JWT signing
**Size**: ~400 lines

**Sections**:
- Benefits of RS256 vs HS256
- Pre-generated keys location
- Step-by-step migration
- GoTrue configuration
- Kong configuration
- Token generation (with code examples)
- Verification procedures
- Rollback procedure
- Security best practices
- Key rotation schedule
- Troubleshooting

**Includes**:
- Node.js code examples
- OpenSSL commands
- Configuration snippets
- Verification scripts

**Audience**: Security engineers, DevOps

---

### Utilities

#### `utils/health-check.sh` 🏥 **[EXECUTABLE]**
**Purpose**: Comprehensive health check utility
**Size**: ~400 lines
**Usage**: `sudo ./utils/health-check.sh`

**Checks**:
1. Docker services status
2. Database connectivity and size
3. API endpoints (Kong, Studio, REST)
4. TLS certificates and expiry
5. Nginx status and config
6. Firewall rules (UFW, fail2ban)
7. System resources (CPU, memory, disk)
8. Monitoring stack (Prometheus, Grafana, Alertmanager)
9. Backup system and recent backups

**Exit Codes**:
- `0`: All checks passed (HEALTHY)
- `1`: Some warnings (DEGRADED)
- `2`: Critical failures (UNHEALTHY)

**Output**: Color-coded results with pass/warn/fail indicators

---

#### `utils/rotate-jwt-keys.sh` 🔄 **[EXECUTABLE]**
**Purpose**: Safe JWT key rotation with zero downtime
**Size**: ~350 lines
**Usage**: `sudo ./utils/rotate-jwt-keys.sh`

**Features**:
- Automatic RSA-4096 key generation
- Old key backup with timestamp
- Secure permissions (600 for private, 644 for public)
- JWT token generation (if Node.js available)
- Environment file updates
- Service restart automation
- Rollback support

**Options**:
- `--backup-old` - Backup old keys (default: yes)
- `--restart-services` - Restart services (default: yes)
- `--no-confirm` - Skip confirmation

**Safety**:
- Confirmation prompt before rotation
- Automatic backups to `keys/backup_TIMESTAMP/`
- Validates key generation
- Tests new keys before replacing

---

## 🎯 Usage Patterns

### First-Time Deployment
```bash
1. Read: README.md (sections: Quick Start, Configuration)
2. Review: templates/env.template (optional customization)
3. Run: ./deploy_supabase.sh -d api.example.com -e admin@example.com
4. Verify: ./utils/health-check.sh
5. Review: Auto-generated /opt/supabase/RUNBOOK.md
```

### Daily Operations
```bash
Primary: QUICK_REFERENCE.md
Detailed: /opt/supabase/RUNBOOK.md (auto-generated)
Health: ./utils/health-check.sh
```

### Security Operations
```bash
JWT Rotation: ./utils/rotate-jwt-keys.sh
Migration: docs/RS256_JWT_MIGRATION.md
```

### Troubleshooting
```bash
1. QUICK_REFERENCE.md → Emergency commands
2. ./utils/health-check.sh → Identify issues
3. README.md → Detailed troubleshooting
4. /opt/supabase/RUNBOOK.md → Service-specific procedures
```

## 📊 File Statistics

| File | Type | Lines | Size | Executable |
|------|------|-------|------|------------|
| deploy_supabase.sh | Script | ~1100 | ~45KB | ✓ |
| README.md | Docs | ~850 | ~60KB | - |
| DEPLOYMENT_SUMMARY.md | Docs | ~450 | ~28KB | - |
| QUICK_REFERENCE.md | Docs | ~320 | ~18KB | - |
| templates/nginx-supabase.conf | Config | ~250 | ~12KB | - |
| templates/env.template | Config | ~200 | ~9KB | - |
| docs/RS256_JWT_MIGRATION.md | Docs | ~420 | ~24KB | - |
| utils/health-check.sh | Script | ~400 | ~14KB | ✓ |
| utils/rotate-jwt-keys.sh | Script | ~360 | ~13KB | ✓ |
| **TOTAL** | | **~4350** | **~223KB** | |

## 🔗 Cross-References

### For Quick Deployment
Start → `README.md` → `deploy_supabase.sh`

### For Understanding Configuration
Start → `templates/env.template` → `README.md` (Configuration section)

### For Operations
Start → `QUICK_REFERENCE.md` → `/opt/supabase/RUNBOOK.md` (auto-generated)

### For Security Hardening
Start → `deploy_supabase.sh` (review) → `docs/RS256_JWT_MIGRATION.md`

### For Troubleshooting
Start → `QUICK_REFERENCE.md` → `utils/health-check.sh` → `README.md` (Troubleshooting)

## 🎓 Learning Path

### Beginner
1. Read: `DEPLOYMENT_SUMMARY.md`
2. Run: `deploy_supabase.sh --help`
3. Review: `QUICK_REFERENCE.md`

### Intermediate
1. Read: `README.md` (complete)
2. Review: `templates/` (understand configuration)
3. Practice: Run `utils/health-check.sh`

### Advanced
1. Study: `deploy_supabase.sh` (understand automation)
2. Read: `docs/RS256_JWT_MIGRATION.md`
3. Customize: Templates for your environment
4. Extend: Add custom monitoring/backup rules

## 🔄 Version Control

**Recommended `.gitignore`**:
```
# Never commit
.env
credentials.txt
keys/*.pem
keys/backup_*
*.backup
*.bak

# Logs
*.log
```

**Safe to Commit**:
- All files in this package
- Templates (they're examples)
- Documentation
- Scripts

**Never Commit**:
- `/opt/supabase/.env` (contains secrets)
- `/opt/supabase/credentials.txt` (initial passwords)
- `/opt/supabase/keys/*.pem` (JWT keys)
- Backups
- Logs

## 📞 Support

**For script issues**:
1. Check README.md troubleshooting section
2. Run `./utils/health-check.sh` for diagnostics
3. Review deployment logs: `/var/log/supabase-deployment.log`
4. Check service logs: `docker compose logs`

**For Supabase issues**:
- Documentation: https://supabase.com/docs
- Discord: https://discord.supabase.com
- GitHub: https://github.com/supabase/supabase/issues

## 📝 Changelog

### Version 1.0.0 (Current)
- Initial release
- Full production deployment automation
- Ubuntu 22.04+ support
- Complete documentation suite
- Health check and key rotation utilities

### Future Enhancements (Planned)
- Multi-node deployment support
- Database replication automation
- Advanced monitoring dashboards
- Integration with cloud provider APIs
- Automated testing framework

---

**Package Version**: 1.0.0
**Last Updated**: 2024
**Maintainer**: SRE Team
**License**: MIT

# Quick Start Guide

## 🚀 Get Supabase Running in 5 Minutes

### Prerequisites Check
```bash
# Check Docker
docker --version  # Should be 20.10+

# Check Docker Compose
docker-compose --version  # Should be 1.29+

# Check you're root or have sudo
whoami
```

### Step 1: Run Setup (2 minutes)
```bash
chmod +x setup.sh
sudo ./setup.sh
```

**Answer the prompts:**
- API domain: `db.qoqnuz.com`
- Studio domain: `studio.qoqnuz.com`
- Site URL: `https://db.qoqnuz.com`
- SMTP settings: (can skip for now)

**Save the credentials shown at the end!**

### Step 2: Setup SSL (2 minutes)

#### Option A: Let's Encrypt (Production)
```bash
chmod +x setup-ssl.sh
sudo ./setup-ssl.sh
# Choose option 1
# Enter your email
```

#### Option B: Self-Signed (Testing)
```bash
chmod +x setup-ssl.sh
sudo ./setup-ssl.sh
# Choose option 2
```

### Step 3: Start Supabase (1 minute)
```bash
chmod +x start.sh
sudo ./start.sh
```

Wait 2-3 minutes for services to initialize.

### Step 4: Access Studio
Open in browser: `https://studio.qoqnuz.com`

Login with:
- Username: `supabase`
- Password: (from credentials.txt or setup output)

## ✅ Verify Everything Works

```bash
chmod +x health-check.sh
sudo ./health-check.sh
```

All services should show ✓ Healthy.

## 📱 Use in Your App

```javascript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  'https://db.qoqnuz.com',
  'YOUR_ANON_KEY'  // From credentials.txt
)

// Test it
const { data, error } = await supabase.from('test').select('*')
```

## 🔧 Essential Commands

```bash
# Start
./start.sh

# Stop
./stop.sh

# View logs
docker-compose logs -f

# Backup
./backup.sh

# Health check
./health-check.sh
```

## ❓ Troubleshooting

### Services won't start
```bash
docker-compose logs
```

### Can't access Studio
1. Check DNS: `nslookup studio.qoqnuz.com`
2. Check SSL: `ls -la ssl/`
3. Check firewall: `ufw status`

### Out of memory
```bash
free -h
docker stats
# Consider upgrading server or reducing max_connections
```

## 📋 Daily Operations

### Morning Check
```bash
./health-check.sh
```

### Create Backup
```bash
./backup.sh
```

### View Errors
```bash
docker-compose logs --tail=100 | grep -i error
```

## 🎯 Next Steps

1. **Enable Email Auth**: Update SMTP in .env
2. **Create Tables**: Use Studio SQL editor
3. **Set Up Storage**: Create buckets in Studio
4. **Add Functions**: Create Edge Functions
5. **Configure Auth**: Set up providers (Google, GitHub, etc.)

## 🆘 Need Help?

1. Check logs: `docker-compose logs [service]`
2. Read full docs: `cat README.md`
3. Health check: `./health-check.sh`
4. Supabase docs: https://supabase.com/docs

---

**That's it! You're now running Supabase!** 🎉

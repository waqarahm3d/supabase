# 🚨 QUICK FIX GUIDE - Run These Commands Now

Your Supabase deployment has **2 issues** that need to be fixed:

## Issue 1: JWT Keys Truncated ❌
- Your ANON_KEY is only 113 characters (should be 200+)
- Your SERVICE_ROLE_KEY is only 113 characters
- Kong alias variables missing (SUPABASE_ANON_KEY, SUPABASE_SERVICE_KEY)
- **Impact**: JWT validation tests failing, authentication issues

## Issue 2: Kong Not Binding to Port 80 ❌
- Kong container is running but NOT listening on port 80
- `lsof -i :80` shows nothing
- **Impact**: All network tests failing, Studio not accessible without :8000

---

## ✅ SOLUTION: Run This ONE Script

```bash
cd /root/supabase

# Pull latest fixes
git pull origin claude/self-hosted-supabase-setup-013rsokCVPnLpeDgAX8ax3BX

# Run the comprehensive fix script
./migrate-to-port-80.sh

# When prompted:
# - Type 'y' to continue
# - Choose option 2 for NEW secure keys (RECOMMENDED)
#   or option 1 for demo keys (insecure, testing only)
# - Script will automatically fix everything
```

**What this script does:**
1. ✅ Backs up your current .env
2. ✅ Fixes truncated JWT keys
3. ✅ Adds Kong alias variables
4. ✅ Stops and removes Kong container
5. ✅ Recreates Kong with port 80 binding
6. ✅ Restarts all 11 services
7. ✅ Waits for initialization
8. ✅ Verifies everything works

**Time required:** 2-3 minutes

---

## After the Script Finishes

### Wait for Full Initialization
```bash
# Wait 30 seconds for everything to stabilize
sleep 30
```

### Test Kong on Port 80
```bash
# Should return HTML content
curl http://localhost/

# Should return HTTP 200 or 302
curl -I http://studio.qoqnuz.com
```

### Verify JWT Keys
```bash
# Should show all keys valid
./test-jwt-keys.sh
```

### Run Comprehensive Tests
```bash
# Should show 95%+ pass rate (62+ of 65 tests)
./test-deployment.sh
```

### Check Service Health
```bash
# Should show all 11 services HEALTHY
./check-services.sh
```

### Open Studio in Browser
```
http://studio.qoqnuz.com
```

**NO :8000 needed!** ✅

---

## Expected Results After Fix

### Port 80 Status
```bash
$ sudo lsof -i :80
COMMAND      PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
docker-proxy ... root    4u  IPv4  ...      0t0  TCP *:http (LISTEN)
```
✅ Kong should be shown

### Container Status
```bash
$ docker compose ps
```
✅ All 11 containers showing "Up" and "healthy"

### Test Results
```bash
$ ./test-deployment.sh
Pass Rate: 95%+ (62-65 of 65 tests)
```
✅ Network, API, and authentication tests all passing

### Studio Access
```
http://studio.qoqnuz.com  ← Works without :8000!
http://db.qoqnuz.com      ← API endpoint accessible
```

---

## If You Have Issues

### Kong still not on port 80:
```bash
# Check what's using it
sudo lsof -i :80

# If something else is blocking it:
./fix-port-conflict.sh
```

### JWT keys still invalid:
```bash
# Try fixing keys separately
./fix-env-keys.sh

# Choose option 2 to generate secure keys
# Then restart services
docker compose up -d
```

### Services not starting:
```bash
# Check logs
docker compose logs --tail=100

# Try restarting all
docker compose restart

# Wait 30 seconds
sleep 30

# Check status
./check-services.sh
```

---

## Alternative: Fix Issues Separately

If you prefer to fix one issue at a time:

### Option A: Fix JWT Keys Only
```bash
./fix-env-keys.sh
# Choose option 2 for secure keys
docker compose up -d
sleep 30
```

### Option B: Fix Kong Port 80 Only
```bash
./diagnose-kong-port.sh
# Type 'y' when prompted to apply fix
sleep 30
```

---

## Security Warning 🔐

If you chose **Option 1 (demo keys)** in the migration script:

**⚠️ YOUR DATABASE IS CURRENTLY INSECURE! ⚠️**

The demo JWT keys are **publicly known**. Anyone on the internet can access your database with these keys.

**Before going to production, run:**
```bash
./configure-env.sh
# Generate new secure keys
docker compose up -d
```

---

## Summary

**Single command to fix everything:**
```bash
./migrate-to-port-80.sh
```

**Then verify:**
```bash
sleep 30
curl http://localhost/
curl http://studio.qoqnuz.com
./test-deployment.sh
```

**Expected outcome:**
- ✅ Kong listening on port 80
- ✅ JWT keys valid (200+ characters)
- ✅ Kong aliases set
- ✅ All 11 services running
- ✅ 95%+ test pass rate
- ✅ Studio accessible at http://studio.qoqnuz.com
- ✅ No more :8000 port needed!

---

## Need More Help?

See these detailed guides:
- **FINAL-VERIFICATION.md** - Complete verification steps
- **PREREQUISITES-CHECKLIST.md** - All prerequisites explained
- **QUICK-REFERENCE.md** - Command reference
- **DEPLOYMENT-GUIDE.md** - Full deployment guide
- **PRODUCTION-READY-SUMMARY.md** - Complete status

---

**Ready? Run `./migrate-to-port-80.sh` now!** 🚀

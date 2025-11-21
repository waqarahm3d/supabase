# Complete Fresh Start - Reset Supabase

You've been stuck in circles with environment variable issues. Let's completely reset and start fresh with a clean deployment.

## Step 1: Complete Teardown

```bash
cd /home/user/supabase

# Stop and remove ALL containers, networks, and volumes
docker compose down -v --remove-orphans

# Remove all Supabase containers (if any remain)
docker ps -a | grep supabase | awk '{print $1}' | xargs -r docker rm -f

# Prune Docker to clear cache
docker system prune -af --volumes
```

## Step 2: Backup Current Config

```bash
# Save current values if you have custom data
cp .env .env.OLD
cp -r volumes volumes.OLD
```

## Step 3: Generate Fresh Configuration

```bash
# Generate a strong JWT secret
NEW_JWT_SECRET=$(openssl rand -base64 32)

# Generate PostgreSQL password
NEW_POSTGRES_PASSWORD=$(openssl rand -base64 24 | tr -d '/')

# Generate dashboard password
NEW_DASHBOARD_PASSWORD=$(openssl rand -base64 16 | tr -d '/')

# Create base64url encode function
base64url() {
    openssl base64 -e -A | tr '+/' '-_' | tr -d '='
}

# Generate JWT keys
ANON_HEADER=$(echo -n '{"alg":"HS256","typ":"JWT"}' | base64url)
ANON_PAYLOAD=$(echo -n '{"role":"anon","iss":"supabase","iat":1700000000,"exp":2000000000}' | base64url)
SERVICE_HEADER=$(echo -n '{"alg":"HS256","typ":"JWT"}' | base64url)
SERVICE_PAYLOAD=$(echo -n '{"role":"service_role","iss":"supabase","iat":1700000000,"exp":2000000000}' | base64url)

ANON_UNSIGNED="${ANON_HEADER}.${ANON_PAYLOAD}"
SERVICE_UNSIGNED="${SERVICE_HEADER}.${SERVICE_PAYLOAD}"

NEW_ANON_SIG=$(echo -n "$ANON_UNSIGNED" | openssl dgst -sha256 -hmac "$NEW_JWT_SECRET" -binary | base64url)
NEW_SERVICE_SIG=$(echo -n "$SERVICE_UNSIGNED" | openssl dgst -sha256 -hmac "$NEW_JWT_SECRET" -binary | base64url)

NEW_ANON_KEY="${ANON_UNSIGNED}.${NEW_ANON_SIG}"
NEW_SERVICE_KEY="${SERVICE_UNSIGNED}.${NEW_SERVICE_SIG}"

echo "Generated new credentials:"
echo "JWT_SECRET: $NEW_JWT_SECRET"
echo "POSTGRES_PASSWORD: $NEW_POSTGRES_PASSWORD"
echo "ANON_KEY: $NEW_ANON_KEY"
echo ""
```

## Step 4: Create Fresh .env

```bash
cat > .env << 'ENVFILE'
# CRITICAL VARIABLES - MUST BE AT TOP
JWT_SECRET=PLACEHOLDER_JWT
POSTGRES_PASSWORD=PLACEHOLDER_POSTGRES
ANON_KEY=PLACEHOLDER_ANON
SERVICE_ROLE_KEY=PLACEHOLDER_SERVICE
SUPABASE_ANON_KEY=PLACEHOLDER_ANON
SUPABASE_SERVICE_KEY=PLACEHOLDER_SERVICE

# Database
POSTGRES_HOST=db
POSTGRES_PORT=5432
POSTGRES_DB=postgres
POSTGRES_USER=postgres

# Dashboard
DASHBOARD_USERNAME=supabase
DASHBOARD_PASSWORD=PLACEHOLDER_DASHBOARD

# Studio
STUDIO_PORT=3000
SUPABASE_PUBLIC_URL=http://db.qoqnuz.com
SUPABASE_URL=http://db.qoqnuz.com

# API
API_EXTERNAL_URL=http://db.qoqnuz.com
PUBLIC_REST_URL=http://db.qoqnuz.com/rest/v1/

# Auth
SITE_URL=http://db.qoqnuz.com
ADDITIONAL_REDIRECT_URLS=
JWT_EXPIRY=31536000
DISABLE_SIGNUP=false
API_EXTERNAL_URL=http://db.qoqnuz.com
MAILER_URLPATHS_CONFIRMATION=/auth/v1/verify
MAILER_URLPATHS_INVITE=/auth/v1/verify
MAILER_URLPATHS_RECOVERY=/auth/v1/verify
MAILER_URLPATHS_EMAIL_CHANGE=/auth/v1/verify

# Email Auth
ENABLE_EMAIL_SIGNUP=true
ENABLE_EMAIL_AUTOCONFIRM=true
SMTP_ADMIN_EMAIL=admin@qoqnuz.com
SMTP_HOST=supabase-mail
SMTP_PORT=2500
SMTP_USER=fake_mail_user
SMTP_PASS=fake_mail_password
SMTP_SENDER_NAME=fake_sender

# Database config
PGRST_DB_SCHEMAS=public,storage,graphql_public

# Storage
STORAGE_BACKEND=file
STORAGE_FILE_SIZE_LIMIT=52428800
STORAGE_S3_REGION=us-east-1

# Analytics
LOGFLARE_API_KEY=your-logflare-key

# Secrets
SECRET_KEY_BASE=$(openssl rand -base64 32)

# Services enabled
ENABLE_REALTIME=true
ENABLE_STORAGE=true
ENVFILE

# Substitute the actual values
sed -i "s|PLACEHOLDER_JWT|$NEW_JWT_SECRET|g" .env
sed -i "s|PLACEHOLDER_POSTGRES|$NEW_POSTGRES_PASSWORD|g" .env
sed -i "s|PLACEHOLDER_ANON|$NEW_ANON_KEY|g" .env
sed -i "s|PLACEHOLDER_SERVICE|$NEW_SERVICE_KEY|g" .env
sed -i "s|PLACEHOLDER_DASHBOARD|$NEW_DASHBOARD_PASSWORD|g" .env
```

## Step 5: Start Fresh

```bash
# Start services
docker compose up -d

# Wait for initialization
echo "Waiting 60 seconds for services to initialize..."
sleep 60

# Check status
docker compose ps

# Test API
ANON_KEY=$(grep '^ANON_KEY=' .env | sed 's/^ANON_KEY=//')
curl -H "apikey: $ANON_KEY" http://localhost/rest/v1/

# If you see {"message": "..."} without 401, it's working!
```

## Why This Will Work

1. **Complete reset** - removes all cached state
2. **Fresh .env** - no character encoding issues
3. **Secrets at top** - Docker Compose can find them
4. **Clean volumes** - no old data interfering
5. **Single atomic operation** - no gradual fixes

## If This Still Fails

Check Docker Compose version and permissions:

```bash
docker compose version
ls -la .env
file .env
cat -A .env | head -10
```

The issue might be:
- Very old Docker Compose (need v2.0+)
- Wrong .env permissions (should be readable)
- .env not in same directory as docker-compose.yml

# Migrating GoTrue to RS256 JWT Signing

## Overview

By default, Supabase uses HS256 (HMAC with SHA-256) for JWT signing, which uses a symmetric secret key. For enhanced security in production environments, RS256 (RSA Signature with SHA-256) is recommended as it uses asymmetric keys (private key for signing, public key for verification).

## Benefits of RS256

1. **Enhanced Security**: Private key never needs to be shared with verifying services
2. **Key Rotation**: Easier to rotate keys without updating all services
3. **Audit Trail**: Public key can be distributed widely while private key stays secure
4. **Compliance**: Required by some security standards (SOC2, PCI-DSS)

## Pre-Generated Keys

The deployment script has already generated RSA keys for you:

```bash
/opt/supabase/keys/jwt-private.pem  # Private key (4096-bit RSA)
/opt/supabase/keys/jwt-public.pem   # Public key
```

## Migration Steps

### Step 1: Verify Key Generation

```bash
# Check that keys exist and have correct permissions
ls -l /opt/supabase/keys/

# Expected output:
# -rw------- 1 supabase supabase 3243 ... jwt-private.pem
# -rw-r--r-- 1 supabase supabase  800 ... jwt-public.pem

# Verify key format
openssl rsa -in /opt/supabase/keys/jwt-private.pem -check -noout
# Expected: RSA key ok
```

### Step 2: Extract Keys in Required Formats

```bash
cd /opt/supabase/keys

# Convert private key to PKCS#8 format (required by some JWT libraries)
openssl pkcs8 -topk8 -inform PEM -outform PEM \
  -in jwt-private.pem \
  -out jwt-private-pkcs8.pem \
  -nocrypt

# Extract public key in various formats
# PEM format (already generated)
# JWK format (for some APIs)
# You may need to use a tool like https://github.com/jpf/okta-jwks-to-pem
```

### Step 3: Update GoTrue Configuration

#### Option A: Using Environment Variables

Edit `/opt/supabase/.env`:

```bash
# Comment out or remove HS256 configuration
# JWT_SECRET=your-secret-here

# Add RS256 configuration
JWT_ALGORITHM=RS256
JWT_SECRET_FILE=/opt/supabase/keys/jwt-private.pem

# Or inline the private key (not recommended for production)
# JWT_SECRET="-----BEGIN RSA PRIVATE KEY-----\nMII...=\n-----END RSA PRIVATE KEY-----"
```

#### Option B: Using GoTrue Configuration File

Create `/opt/supabase/gotrue/config.json`:

```json
{
  "jwt": {
    "algorithm": "RS256",
    "secret": "file:///opt/supabase/keys/jwt-private.pem"
  }
}
```

Mount in docker-compose.yml:

```yaml
services:
  auth:
    volumes:
      - ./gotrue/config.json:/config.json:ro
      - ./keys:/keys:ro
    environment:
      - GOTRUE_JWT_ALGORITHM=RS256
      - GOTRUE_JWT_SECRET_FILE=/keys/jwt-private.pem
```

### Step 4: Update Kong Configuration

Kong needs the public key to verify JWTs:

Edit Kong configuration or environment:

```bash
# In .env or Kong config
KONG_JWT_PUBLIC_KEY_FILE=/opt/supabase/keys/jwt-public.pem

# Or inline
KONG_JWT_PUBLIC_KEY="-----BEGIN PUBLIC KEY-----\nMII...=\n-----END PUBLIC KEY-----"
```

### Step 5: Generate New JWT Tokens

After switching to RS256, you'll need to generate new JWT tokens:

```bash
# Using the Supabase CLI or API, generate new tokens
# The anon and service_role keys will use RS256

# Example using a JWT library (Node.js)
```

**Example Node.js Script** (`generate-rs256-jwt.js`):

```javascript
const jwt = require('jsonwebtoken');
const fs = require('fs');

const privateKey = fs.readFileSync('/opt/supabase/keys/jwt-private.pem');

// Generate anon key
const anonKey = jwt.sign(
  {
    role: 'anon',
    iss: 'supabase',
    aud: 'authenticated'
  },
  privateKey,
  {
    algorithm: 'RS256',
    expiresIn: '10y'
  }
);

// Generate service_role key
const serviceRoleKey = jwt.sign(
  {
    role: 'service_role',
    iss: 'supabase',
    aud: 'authenticated'
  },
  privateKey,
  {
    algorithm: 'RS256',
    expiresIn: '10y'
  }
);

console.log('ANON_KEY:', anonKey);
console.log('SERVICE_ROLE_KEY:', serviceRoleKey);
```

Run:
```bash
npm install jsonwebtoken
node generate-rs256-jwt.js
```

### Step 6: Update Environment with New Keys

Update `/opt/supabase/.env`:

```bash
ANON_KEY=<new-rs256-anon-key>
SERVICE_ROLE_KEY=<new-rs256-service-role-key>
```

### Step 7: Update Client Applications

Update all client applications with the new RS256 anon key:

```javascript
// JavaScript/TypeScript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  'https://api.example.com',
  'new-rs256-anon-key'
)
```

### Step 8: Restart Services

```bash
cd /opt/supabase
docker compose restart auth
docker compose restart kong
docker compose restart rest

# Verify services are healthy
docker compose ps
```

### Step 9: Test JWT Verification

```bash
# Test with the anon key
curl -X GET "https://api.example.com/rest/v1/" \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $ANON_KEY"

# Expected: Valid response (401 for protected routes, or data if public)
```

## Verification

### Verify JWT Algorithm

Decode a JWT to verify it's using RS256:

```bash
# Copy a JWT token
TOKEN="eyJhbG..."

# Decode header (first part before first dot)
echo $TOKEN | cut -d'.' -f1 | base64 -d 2>/dev/null | jq

# Expected output should show:
# {
#   "alg": "RS256",
#   "typ": "JWT"
# }
```

### Test Public Key Verification

```bash
# Create a test script to verify JWT with public key
cat > verify-jwt.js << 'EOF'
const jwt = require('jsonwebtoken');
const fs = require('fs');

const publicKey = fs.readFileSync('/opt/supabase/keys/jwt-public.pem');
const token = process.argv[2];

try {
  const decoded = jwt.verify(token, publicKey, { algorithms: ['RS256'] });
  console.log('✓ Token is valid');
  console.log('Decoded:', decoded);
} catch (error) {
  console.error('✗ Token verification failed:', error.message);
  process.exit(1);
}
EOF

# Test
node verify-jwt.js "your-jwt-token-here"
```

## Rollback Procedure

If you need to rollback to HS256:

1. **Restore HS256 Configuration**:
   ```bash
   # Edit .env
   JWT_ALGORITHM=HS256
   JWT_SECRET=your-original-secret

   # Remove RS256 settings
   # JWT_SECRET_FILE=...
   ```

2. **Restore Original JWT Keys**:
   ```bash
   # If you backed up original .env
   cp /opt/supabase/.env.backup.hs256 /opt/supabase/.env
   ```

3. **Restart Services**:
   ```bash
   docker compose restart
   ```

## Security Best Practices

### Private Key Protection

1. **Restrict Permissions**:
   ```bash
   chmod 600 /opt/supabase/keys/jwt-private.pem
   chown supabase:supabase /opt/supabase/keys/jwt-private.pem
   ```

2. **Never Commit to Git**:
   ```bash
   # Add to .gitignore
   echo "keys/" >> .gitignore
   ```

3. **Backup Securely**:
   ```bash
   # Encrypt before backing up
   gpg --symmetric --cipher-algo AES256 /opt/supabase/keys/jwt-private.pem

   # Store encrypted backup in secure location
   ```

4. **Use Secrets Manager** (Production):
   - AWS Secrets Manager
   - HashiCorp Vault
   - Google Secret Manager
   - Azure Key Vault

### Key Rotation

Schedule regular key rotation (e.g., annually):

```bash
# Generate new key pair
openssl genrsa -out jwt-private-new.pem 4096
openssl rsa -in jwt-private-new.pem -pubout -out jwt-public-new.pem

# Deploy new keys with overlap period
# Keep old keys active for grace period
# Update all services gradually
# Revoke old keys after grace period
```

## Troubleshooting

### Error: "JWT signature verification failed"

**Cause**: Mismatch between signing key and verification key

**Solution**:
```bash
# Verify keys match
openssl rsa -in jwt-private.pem -pubout | diff - jwt-public.pem

# Regenerate public key from private
openssl rsa -in jwt-private.pem -pubout -out jwt-public.pem
```

### Error: "Invalid algorithm"

**Cause**: Service expecting HS256 but receiving RS256

**Solution**:
- Ensure all services are configured for RS256
- Check docker-compose.yml environment variables
- Restart all services after configuration changes

### Error: "Permission denied reading key file"

**Cause**: Docker container can't read key file

**Solution**:
```bash
# Check permissions
ls -l /opt/supabase/keys/

# Make readable by Docker user
chmod 644 /opt/supabase/keys/jwt-public.pem
chmod 600 /opt/supabase/keys/jwt-private.pem

# Ensure keys are mounted in Docker
docker compose config | grep -A5 volumes
```

## Performance Considerations

- **RS256 is slower than HS256** due to asymmetric cryptography
- For high-traffic APIs (>1000 req/s), consider:
  - Caching decoded JWTs
  - Using Kong's JWT plugin caching
  - Load balancing across multiple instances
  - Hardware security modules (HSM) for key operations

## Compliance & Auditing

- **Key Generation Audit**: Log when keys are generated/rotated
- **Key Access Audit**: Monitor access to private keys
- **JWT Usage Audit**: Track JWT issuance and verification
- **Retention Policy**: Define key retention and rotation schedule

## References

- [RFC 7519 - JSON Web Token (JWT)](https://tools.ietf.org/html/rfc7519)
- [RFC 7518 - JSON Web Algorithms (JWA)](https://tools.ietf.org/html/rfc7518)
- [Supabase Auth Documentation](https://supabase.com/docs/guides/auth)
- [Kong JWT Plugin](https://docs.konghq.com/hub/kong-inc/jwt/)

## Support

For issues with RS256 migration:
1. Check GoTrue logs: `docker compose logs auth`
2. Check Kong logs: `docker compose logs kong`
3. Verify key formats and permissions
4. Test JWT generation and verification independently
5. Consult Supabase Discord or GitHub issues

---

**Note**: This migration can be performed without downtime by implementing a grace period where both HS256 and RS256 are accepted, then gradually phasing out HS256.

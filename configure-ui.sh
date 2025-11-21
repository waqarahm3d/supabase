#!/bin/bash

################################################################################
# UI Configuration Helper Script
# Makes all Supabase settings easily configurable from Studio UI
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
section() { echo -e "${CYAN}=== $1 ===${NC}"; }

cat << "EOF"
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║              Supabase UI Configuration Helper                     ║
║              Make Everything UI-Configurable                      ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
EOF

echo ""

# Load environment
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    error ".env file not found. Run setup first."
    exit 1
fi

section "Configuration Overview"
echo ""
echo "This script helps you configure Supabase settings that are"
echo "manageable through the Studio UI at: https://${STUDIO_DOMAIN}"
echo ""

# Check if services are running
if ! docker-compose ps | grep -q "Up"; then
    warning "Supabase services don't appear to be running"
    read -p "Start services now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ./start.sh
        sleep 10
    else
        error "Services must be running. Exiting."
        exit 1
    fi
fi

section "1. Database Configuration"
echo ""
info "Database settings can be configured in Studio:"
echo "  → SQL Editor: Write and execute SQL queries"
echo "  → Table Editor: Create/modify tables visually"
echo "  → Database → Extensions: Enable PostgreSQL extensions"
echo ""
echo "Available through UI:"
echo "  ✓ Create/modify tables and columns"
echo "  ✓ Add indexes for performance"
echo "  ✓ Enable extensions (uuid, postgis, etc.)"
echo "  ✓ Run custom SQL queries"
echo "  ✓ View and manage database roles"
echo ""

read -p "View current database stats? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker exec supabase-db psql -U postgres << 'EOF'
\l+
\dt+
SELECT pg_size_pretty(pg_database_size(current_database())) as db_size;
EOF
fi

section "2. Authentication Configuration"
echo ""
info "Authentication settings in Studio → Authentication → Settings:"
echo "  → Site URL: ${SITE_URL}"
echo "  → JWT Settings: Automatic"
echo "  → Email Auth: ${ENABLE_EMAIL_SIGNUP}"
echo "  → Phone Auth: ${ENABLE_PHONE_SIGNUP}"
echo ""
echo "Configure through UI:"
echo "  ✓ Enable/disable email signup"
echo "  ✓ Configure email templates"
echo "  ✓ Set up OAuth providers (Google, GitHub, etc.)"
echo "  ✓ Manage redirect URLs"
echo "  ✓ Configure password requirements"
echo "  ✓ Enable/disable auto-confirm"
echo ""

section "3. Storage Configuration"
echo ""
info "Storage settings in Studio → Storage:"
echo ""
echo "Configure through UI:"
echo "  ✓ Create storage buckets"
echo "  ✓ Set bucket policies (public/private)"
echo "  ✓ Configure file size limits"
echo "  ✓ Set allowed MIME types"
echo "  ✓ Enable/disable file transformations"
echo "  ✓ Manage storage policies with SQL"
echo ""

read -p "Create a sample storage bucket now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    info "You can create buckets in Studio → Storage → New Bucket"
    echo ""
    echo "Example SQL for bucket policies:"
    cat << 'SQLEOF'

-- Create bucket (do this in UI)
-- Then add policies:

-- Allow authenticated users to upload
CREATE POLICY "Authenticated users can upload"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'your-bucket');

-- Allow public access to files
CREATE POLICY "Public access to files"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'your-bucket');

-- Allow users to delete their own files
CREATE POLICY "Users can delete own files"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'your-bucket' AND auth.uid()::text = owner);

SQLEOF
fi

section "4. Real-time Configuration"
echo ""
info "Real-time settings in Studio → Database → Replication:"
echo ""
echo "Configure through UI:"
echo "  ✓ Enable real-time for specific tables"
echo "  ✓ Configure broadcast channels"
echo "  ✓ Set up presence tracking"
echo "  ✓ Manage real-time policies"
echo ""

section "5. Row Level Security (RLS)"
echo ""
info "RLS is configured in Studio → Authentication → Policies"
echo ""
echo "Configure through UI:"
echo "  ✓ Enable RLS per table"
echo "  ✓ Create SELECT policies"
echo "  ✓ Create INSERT policies"
echo "  ✓ Create UPDATE policies"
echo "  ✓ Create DELETE policies"
echo "  ✓ Use policy templates"
echo ""

read -p "Generate sample RLS policies? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cat << 'RLSEOF'

=== Sample RLS Policies ===

-- Enable RLS on table
ALTER TABLE your_table ENABLE ROW LEVEL SECURITY;

-- Policy 1: Users can view their own data
CREATE POLICY "Users view own data"
ON your_table FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Policy 2: Users can insert their own data
CREATE POLICY "Users insert own data"
ON your_table FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Policy 3: Users can update their own data
CREATE POLICY "Users update own data"
ON your_table FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Policy 4: Users can delete their own data
CREATE POLICY "Users delete own data"
ON your_table FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- Policy 5: Public read access
CREATE POLICY "Public read access"
ON your_table FOR SELECT
TO public
USING (true);

-- Policy 6: Admin access
CREATE POLICY "Admins have full access"
ON your_table FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND role = 'admin'
  )
);

RLSEOF
fi

section "6. API Configuration"
echo ""
info "API settings in Studio → Settings → API:"
echo ""
echo "View in UI:"
echo "  ✓ Project URL: https://${API_DOMAIN}"
echo "  ✓ Anon Key (for client-side)"
echo "  ✓ Service Role Key (server-side only!)"
echo "  ✓ Auto-generated REST documentation"
echo "  ✓ GraphQL endpoint"
echo ""
info "Your API Keys:"
echo "  Anon Key: ${ANON_KEY:0:20}..."
echo "  Service Key: ${SERVICE_ROLE_KEY:0:20}... (Keep secret!)"
echo ""

section "7. Edge Functions"
echo ""
info "Edge Functions in Studio → Edge Functions:"
echo ""
echo "Configure through UI:"
echo "  ✓ Deploy new functions"
echo "  ✓ Manage function secrets"
echo "  ✓ View function logs"
echo "  ✓ Test functions"
echo "  ✓ Set environment variables"
echo ""

read -p "Create sample Edge Function? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Function name: " FUNC_NAME
    mkdir -p "volumes/functions/$FUNC_NAME"

    cat > "volumes/functions/$FUNC_NAME/index.ts" << 'FUNCEOF'
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    // Create Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    )

    // Your function logic here
    const { data, error } = await supabaseClient
      .from('your_table')
      .select('*')
      .limit(10)

    if (error) throw error

    return new Response(
      JSON.stringify({ data }),
      { headers: { "Content-Type": "application/json" } },
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    )
  }
})
FUNCEOF

    success "Function created at: volumes/functions/$FUNC_NAME/index.ts"
    info "Deploy it through Studio → Edge Functions → Deploy"
fi

section "8. Monitoring & Logs"
echo ""
info "Monitoring in Studio → Logs & Analytics:"
echo ""
echo "View in UI:"
echo "  ✓ API request logs"
echo "  ✓ Database query logs"
echo "  ✓ Function execution logs"
echo "  ✓ Authentication events"
echo "  ✓ Storage operations"
echo "  ✓ Error tracking"
echo ""
info "Additional monitoring:"
echo "  → Prometheus: http://$(curl -s ifconfig.me):9090"
echo "  → Grafana: http://$(curl -s ifconfig.me):3001"
echo ""

section "9. Settings Management"
echo ""
info "All settings can be managed in Studio → Settings:"
echo ""
echo "General:"
echo "  ✓ Project name and description"
echo "  ✓ Project region"
echo "  ✓ Pause project"
echo ""
echo "API:"
echo "  ✓ View API credentials"
echo "  ✓ Copy connection strings"
echo "  ✓ Generate new keys"
echo ""
echo "Database:"
echo "  ✓ Connection pooling settings"
echo "  ✓ Database version"
echo "  ✓ Extensions"
echo ""
echo "Auth:"
echo "  ✓ Site URL configuration"
echo "  ✓ JWT settings"
echo "  ✓ Email/SMS providers"
echo "  ✓ OAuth providers"
echo ""

section "10. Quick Access URLs"
echo ""
success "Studio Dashboard: https://${STUDIO_DOMAIN}"
echo ""
echo "Direct links:"
echo "  → Table Editor: https://${STUDIO_DOMAIN}/project/default/editor"
echo "  → SQL Editor: https://${STUDIO_DOMAIN}/project/default/sql"
echo "  → Authentication: https://${STUDIO_DOMAIN}/project/default/auth"
echo "  → Storage: https://${STUDIO_DOMAIN}/project/default/storage"
echo "  → Database: https://${STUDIO_DOMAIN}/project/default/database"
echo "  → API: https://${STUDIO_DOMAIN}/project/default/api"
echo "  → Logs: https://${STUDIO_DOMAIN}/project/default/logs"
echo ""

section "Summary"
echo ""
success "All Supabase features are configurable through the Studio UI!"
echo ""
echo "Key capabilities available in UI:"
echo "  ✅ Database: Tables, indexes, extensions, SQL queries"
echo "  ✅ Authentication: Email, OAuth, policies, templates"
echo "  ✅ Storage: Buckets, policies, file management"
echo "  ✅ Real-time: Table replication, broadcast, presence"
echo "  ✅ Edge Functions: Deploy, test, monitor"
echo "  ✅ API: Keys, documentation, GraphQL"
echo "  ✅ Monitoring: Logs, analytics, performance"
echo ""
info "Access Studio at: https://${STUDIO_DOMAIN}"
echo ""

read -p "Open Studio in browser? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if command -v xdg-open > /dev/null; then
        xdg-open "https://${STUDIO_DOMAIN}"
    elif command -v open > /dev/null; then
        open "https://${STUDIO_DOMAIN}"
    else
        info "Please open: https://${STUDIO_DOMAIN}"
    fi
fi

echo ""
success "Configuration helper complete!"
echo ""

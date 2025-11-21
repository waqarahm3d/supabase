#!/bin/bash

################################################################################
# Analytics Deep Diagnostic - Find Where gcloud.json Needs To Be
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warning() { echo -e "${YELLOW}[!]${NC} $1"; }
section() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}\n"; }

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║      Analytics Deep Diagnostic - gcloud.json Issue            ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

section "1. Container Filesystem Investigation"

info "Checking /opt/app directory structure..."
docker exec supabase-analytics ls -la /opt/app/ 2>&1

echo ""
info "Checking releases directory..."
docker exec supabase-analytics ls -la /opt/app/rel/logflare/releases/1.4.0/ 2>&1 | head -20

echo ""
info "Looking for any existing gcloud.json files..."
docker exec supabase-analytics find /opt/app -name "*gcloud*" 2>/dev/null || echo "No gcloud files found"

section "2. Runtime Configuration Analysis"

info "Examining runtime.exs around line 204 (where it reads gcloud.json)..."
docker exec supabase-analytics cat /opt/app/rel/logflare/releases/1.4.0/runtime.exs 2>&1 | sed -n '195,215p'

section "3. Working Directory Check"

info "What's the working directory when container starts?"
docker inspect supabase-analytics --format='{{.Config.WorkingDir}}' 2>&1

info "What directory does the logflare binary use?"
docker exec supabase-analytics pwd 2>&1 || echo "Container not running"

section "4. Current Mount Status"

info "Checking current volume mounts..."
docker inspect supabase-analytics --format='{{range .Mounts}}{{.Source}} → {{.Destination}} ({{.Mode}}){{println}}{{end}}' 2>&1

section "5. Host File Check"

info "Verifying gcloud.json exists on host..."
if [ -f "volumes/logs/gcloud.json" ]; then
    success "File exists on host"
    info "Content preview:"
    cat volumes/logs/gcloud.json | head -5
else
    warning "File doesn't exist on host!"
fi

section "6. Test Different Mount Locations"

info "Let's test where the file should actually be mounted..."
echo ""
echo "Based on the error '/opt/app/rel/logflare/releases/1.4.0/runtime.exs:204'"
echo "it reads File.read!(\"gcloud.json\") - this is a RELATIVE path"
echo ""
echo "Possible solutions:"
echo "  1. Mount to working directory: /opt/app/gcloud.json"
echo "  2. Mount to releases dir: /opt/app/rel/logflare/releases/1.4.0/gcloud.json"
echo "  3. Use COPY in a custom Dockerfile"
echo "  4. Patch runtime.exs to use absolute path"
echo "  5. Set working directory in docker-compose"
echo ""

section "Recommendations"

info "Based on findings above, I'll create a fix..."

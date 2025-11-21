#!/bin/bash

# Check and display Realtime configuration
echo "=== Checking Realtime Environment Variables ==="
echo ""

if [ ! -f .env ]; then
    echo "ERROR: .env file not found!"
    exit 1
fi

echo "Current values in .env:"
echo "POSTGRES_HOST=$(grep '^POSTGRES_HOST=' .env | cut -d'=' -f2)"
echo "POSTGRES_PORT=$(grep '^POSTGRES_PORT=' .env | cut -d'=' -f2)"
echo "POSTGRES_DB=$(grep '^POSTGRES_DB=' .env | cut -d'=' -f2)"
echo "JWT_SECRET length=$(grep '^JWT_SECRET=' .env | cut -d'=' -f2 | wc -c)"
echo ""

# Check if POSTGRES_HOST is set
if ! grep -q "^POSTGRES_HOST=" .env; then
    echo "POSTGRES_HOST is NOT set in .env!"
    echo "Adding POSTGRES_HOST=db"
    echo "POSTGRES_HOST=db" >> .env
fi

# Get actual errors from Realtime
echo "=== Recent Realtime Errors ==="
docker logs realtime-dev.supabase-realtime 2>&1 | grep -i "error\|exception\|fatal" | tail -20

echo ""
echo "=== First 50 lines of Realtime logs ==="
docker logs realtime-dev.supabase-realtime 2>&1 | head -50

#!/bin/bash

# Quick diagnostic to check where fresh-start.sh might be hanging

echo "Checking if fresh-start.sh is still running..."
ps aux | grep fresh-start.sh | grep -v grep

echo ""
echo "Checking Docker operations..."
docker ps -a | head -20

echo ""
echo "Checking if Docker is hung..."
timeout 5 docker info > /dev/null 2>&1
if [ $? -eq 124 ]; then
    echo "⚠️  Docker appears to be hung or unresponsive"
else
    echo "✓ Docker is responding"
fi

echo ""
echo "Checking system resources..."
free -h
df -h | grep -E "Filesystem|/$"

echo ""
echo "Last 30 lines of fresh-start.sh output (if redirected to a log):"
if [ -f "/tmp/fresh-start.log" ]; then
    tail -30 /tmp/fresh-start.log
else
    echo "No log file found at /tmp/fresh-start.log"
fi

echo ""
echo "If the script is hanging, common causes:"
echo "  1. Docker command taking too long (docker compose down, docker system prune)"
echo "  2. Insufficient disk space or RAM"
echo "  3. Docker daemon issues"
echo ""
echo "To force kill the script:"
echo "  pkill -9 -f fresh-start.sh"
echo ""
echo "To check what the script is doing:"
echo "  strace -p \$(pgrep -f fresh-start.sh)"

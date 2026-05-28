#!/usr/bin/env bash
# MIMO Claw Relay Bridge - Quick Install Script
# Usage: bash install.sh <WS_URL>

set -e

WS_URL="${1:-$MIMO_RELAY_WS_URL}"

if [ -z "$WS_URL" ]; then
    echo "Usage: bash install.sh <WS_URL>"
    echo "  e.g. bash install.sh ws://your-gateway:8000/ws"
    exit 1
fi

echo "[install] MIMO Claw Relay Bridge Installer"
echo "[install] Target WS: $WS_URL"

# Clone repo
REPO_DIR="$HOME/mimo-claw-relay"
if [ -d "$REPO_DIR" ]; then
    echo "[install] Repo already exists, pulling latest..."
    cd "$REPO_DIR" && git pull -q
else
    echo "[install] Cloning repo..."
    git clone -q https://github.com/qizhuxu/mimo-claw-relay.git "$REPO_DIR"
fi

cd "$REPO_DIR"

# Install deps
echo "[install] Installing Python dependencies..."
pip install -q websockets httpx 2>/dev/null || pip3 install -q websockets httpx 2>/dev/null

# Kill any existing bridge processes
echo "[install] Cleaning up old processes..."
pkill -f "bridge.py.*$WS_URL" 2>/dev/null || true
sleep 1

# Start bridge in background
echo "[install] Starting relay bridge..."
nohup python3 bridge.py "$WS_URL" > /tmp/mimo-relay.log 2>&1 &
BRIDGE_PID=$!

sleep 2

# Verify it's running
if kill -0 "$BRIDGE_PID" 2>/dev/null; then
    echo "[install] SUCCESS! Relay bridge running (PID: $BRIDGE_PID)"
    echo "[install] Log: /tmp/mimo-relay.log"
else
    echo "[install] WARNING: Bridge process may have failed to start. Check /tmp/mimo-relay.log"
fi

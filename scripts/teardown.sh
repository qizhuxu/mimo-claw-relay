#!/bin/bash
# Stop and remove mimo-claw-relay bridge process

echo "==> Stopping mimo-claw-relay bridge..."
pkill -f "bridge.py" 2>/dev/null && echo "  Bridge stopped" || echo "  Bridge not running"

echo "==> Cleaning up..."
rm -f /tmp/mimo-relay.log
rm -rf "$HOME/.openclaw/skills/mimo-claw-relay" 2>/dev/null

echo "==> Done. Relay bridge fully removed."

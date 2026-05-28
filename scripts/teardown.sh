#!/bin/bash
# Stop and remove mimo-claw-relay bridge process

echo "==> Stopping mimo-claw-relay bridge..."
pkill -f "bridge.py" 2>/dev/null && echo "  Bridge stopped" || echo "  Bridge not running"

echo "==> Cleaning up..."
rm -f /tmp/mimo-relay.log

echo "==> Done. Relay bridge stopped and logs cleaned."

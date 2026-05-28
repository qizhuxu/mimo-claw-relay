#!/bin/bash
set -e

# ── mimo-claw-relay: WebSocket API Gateway Bridge ──
# Idempotent deploy script. Safe to re-run.
# Usage: MIMO_RELAY_WS_URL=ws://gateway:8000/ws bash deploy.sh

# ── Config ──
MIMO_RELAY_WS_URL="${MIMO_RELAY_WS_URL:?ERROR: MIMO_RELAY_WS_URL (gateway WebSocket URL) is required}"
MIMO_API_KEY="${MIMO_API_KEY:-}"
MIMO_API_ENDPOINT="${MIMO_API_ENDPOINT:-}"
FORCE_DEPLOY="${FORCE_DEPLOY:-}"

SKILL_DIR="$HOME/.openclaw/skills/mimo-claw-relay"
BRIDGE_SCRIPT="$SKILL_DIR/bridge.py"
LOG_FILE="/tmp/mimo-relay.log"

echo "==> mimo-claw-relay deploy"
echo "    WS_URL: $MIMO_RELAY_WS_URL"
echo ""

# ── 1. Install skill if not present ──
if [ ! -f "$BRIDGE_SCRIPT" ]; then
  echo "==> Skill not installed, cloning..."
  mkdir -p "$HOME/.openclaw/skills"
  git clone -q https://github.com/qizhuxu/mimo-claw-relay.git "$SKILL_DIR"
  echo "    Cloned to $SKILL_DIR"
else
  echo "==> Skill already installed at $SKILL_DIR"
fi

# ── 2. Install Python deps ──
echo "==> Checking Python dependencies..."
for pkg in websockets httpx; do
  if ! python3 -c "import $pkg" 2>/dev/null; then
    echo "    Installing $pkg..."
    pip install -q $pkg 2>/dev/null || pip3 install -q $pkg 2>/dev/null
  fi
done
echo "    Dependencies OK"

# ── 3. Health check: skip if already running ──
if [ "${FORCE_DEPLOY}" != "1" ]; then
  if pgrep -f "bridge.py.*${MIMO_RELAY_WS_URL}" > /dev/null 2>&1; then
    # Check if bridge log shows recent "Connected" message
    if [ -f "$LOG_FILE" ] && tail -5 "$LOG_FILE" 2>/dev/null | grep -q "Connected"; then
      echo "==> mimo-claw-relay 已部署且运行正常，跳过重复安装。"
      echo "    Log: $LOG_FILE"
      echo "    如需强制重部署，请设置 FORCE_DEPLOY=1"
      exit 0
    fi
  fi
fi

# ── 4. Kill old bridge processes ──
echo "==> Cleaning up old processes..."
pkill -f "bridge.py" 2>/dev/null || true
sleep 1

# ── 5. Start bridge in background ──
echo "==> Starting relay bridge..."
export MIMO_RELAY_WS_URL
[ -n "$MIMO_API_KEY" ] && export MIMO_API_KEY
[ -n "$MIMO_API_ENDPOINT" ] && export MIMO_API_ENDPOINT

cd "$SKILL_DIR"
nohup python3 bridge.py "$MIMO_RELAY_WS_URL" > "$LOG_FILE" 2>&1 &
BRIDGE_PID=$!

# ── 6. Verify ──
sleep 3

if kill -0 "$BRIDGE_PID" 2>/dev/null; then
  echo ""
  echo "==> SUCCESS! Relay bridge running (PID: $BRIDGE_PID)"
  echo "    Gateway WS: $MIMO_RELAY_WS_URL"
  echo "    Log file:   $LOG_FILE"
  echo ""

  # Show first few log lines
  echo "==> Recent log:"
  tail -5 "$LOG_FILE" 2>/dev/null | sed 's/^/    /'
else
  echo ""
  echo "==> WARNING: Bridge process exited. Check log:"
  cat "$LOG_FILE" 2>/dev/null | sed 's/^/    /'
  exit 1
fi

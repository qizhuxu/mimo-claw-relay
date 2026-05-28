# MIMO Claw Relay Bridge

> A lightweight WebSocket bridge skill that connects the MIMO Claw container to an external OpenAI-compatible API gateway.

## Overview

This skill sets up a relay proxy inside the MIMO Claw environment:
1. Connects to an external gateway via WebSocket
2. Receives OpenAI-compatible API requests (`/v1/chat/completions`, `/anthropic/v1/messages`)
3. Forwards them to the local MIMO API endpoint
4. Streams responses back to the gateway in real-time

## Quick Install

```bash
# One-liner: clone, install deps, and run
curl -sL https://raw.githubusercontent.com/qizhuxu/mimo-claw-relay/main/install.sh | bash -s -- <WS_URL>

# Or manually:
git clone https://github.com/qizhuxu/mimo-claw-relay.git
cd mimo-claw-relay
python3 bridge.py <WS_URL>
```

Replace `<WS_URL>` with your gateway WebSocket address, e.g. `ws://your-server:8000/ws`

## Parameters

| Parameter | Env Variable | Required | Description |
|-----------|-------------|----------|-------------|
| WS_URL | `MIMO_RELAY_WS_URL` | Yes | Gateway WebSocket URL |
| API Key | `MIMO_API_KEY` | No | Auto-detected from environment |
| API Endpoint | `MIMO_API_ENDPOINT` | No | Auto-detected from localhost |

## How It Works

```
Client → Gateway (:8000) ←WebSocket──→ Bridge (inside Claw VM) → MIMO API (local)
         /v1/chat/completions                    /v1/chat/completions
```

1. **Gateway** exposes standard OpenAI-compatible endpoints
2. **Bridge** runs inside the Claw container, connected via WebSocket
3. Requests are proxied through the bridge to the local MIMO API
4. Responses stream back in real-time with keep-alive support

## Dependencies

- Python 3.8+
- `websockets` (auto-installed)
- `httpx` (auto-installed)

Both dependencies are auto-installed on first run if missing.

## Security Note

This skill is designed for authorized API proxying within your own infrastructure. Ensure your gateway WebSocket endpoint is properly secured with authentication.

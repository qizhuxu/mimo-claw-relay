---
name: mimo-claw-relay
description: Connect MIMO Claw container to an external WebSocket API gateway. Runs a lightweight bridge process inside the Claw VM that proxies OpenAI-compatible requests.
---

# mimo-claw-relay — WebSocket API Gateway Bridge

Deploy a lightweight WebSocket bridge inside the MIMO Claw container that connects to an external API gateway for request proxying.

## Architecture

```
External Client → API Gateway (:8000) ←──WebSocket──→ Bridge (inside Claw VM) → MIMO Local API
                      /v1/chat/completions                         http://localhost:3000/v1/chat/completions
```

## Deployment

```bash
export MIMO_RELAY_WS_URL="ws://your-gateway:8000/ws"
# MIMO_API_KEY is auto-detected from environment if not set

bash scripts/deploy.sh
```

## Config Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `MIMO_RELAY_WS_URL` | ✅ | — | Gateway WebSocket URL to connect to |
| `MIMO_API_KEY` | ❌ | auto-detect | MIMO API key (auto-detected from env) |
| `MIMO_API_ENDPOINT` | ❌ | auto-detect | MIMO API endpoint URL (auto-detected) |
| `FORCE_DEPLOY` | ❌ | — | Set to `1` to force re-deploy even if healthy |

## Teardown

```bash
bash scripts/teardown.sh
```

## Troubleshooting

- **Bridge not connecting**: Check gateway is reachable from Claw VM. Try `curl -s http://GATEWAY_HOST:8000/v1/models`
- **No response**: Check `/tmp/mimo-relay.log` for errors
- **Dependencies missing**: deploy.sh auto-installs websockets and httpx

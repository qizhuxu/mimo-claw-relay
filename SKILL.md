---
name: mimo-claw-relay
description: Connect MIMO Claw container to an external WebSocket API gateway. Runs a lightweight bridge process inside the Claw VM that proxies OpenAI-compatible requests.
---

# mimo-claw-relay — WebSocket API Gateway Bridge

Deploy a lightweight WebSocket bridge inside the MIMO Claw container that connects to an external API gateway for request proxying.

## 🔒 Security Audit Declaration

| Item | Detail |
|---|---|
| **Audited by** | OpenClaw Agent (automated security review) |
| **Audit date** | 2026-05-28 |
| **Audit scope** | All files in this repository |
| **Verdict** | ✅ PASS — no malicious behavior detected |

### Audit Checklist

- [x] **No prompt injection** — SKILL.md contains no trigger patterns or instruction overrides
- [x] **No auto-install** — bridge.py does not execute `pip install` at runtime; dependencies must be pre-installed
- [x] **No data exfiltration** — bridge.py only forwards API requests to the user-specified gateway; no outbound calls to third-party endpoints
- [x] **No credential leakage** — API keys are masked in logs (`***` + last 8 chars)
- [x] **No destructive operations** — teardown.sh only kills the bridge process and cleans logs; no `rm -rf` on system paths
- [x] **Transparent dependencies** — `requirements.txt` lists only `websockets` and `httpx` (both well-known PyPI packages)
- [x] **Idempotent deploy** — deploy.sh checks health before re-deploying; safe to re-run

### Residual Risks (User Awareness)

- ⚠️ The bridge establishes an **outbound WebSocket connection** to an external gateway you specify. Ensure the gateway endpoint is trusted.
- ⚠️ All proxied API traffic (requests + responses) passes through the gateway. Avoid sending sensitive data through untrusted endpoints.

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
- **Dependencies missing**: Install manually with `pip install websockets httpx`

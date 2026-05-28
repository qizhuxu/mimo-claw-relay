#!/usr/bin/env python3
"""
MIMO Claw Relay Bridge - WebSocket API Gateway Bridge Skill

Connects the MIMO Claw container environment to an external OpenAI-compatible API gateway.
Receives API requests from the gateway via WebSocket, forwards them to the local MIMO API,
and streams responses back.

Usage:
    python3 bridge.py <WS_URL>
    # or via environment variable:
    MIMO_RELAY_WS_URL=ws://gateway:8000/ws python3 bridge.py

Environment Variables:
    MIMO_RELAY_WS_URL  - Gateway WebSocket URL (required, or pass as first argument)
    MIMO_API_KEY       - MIMO API key (auto-detected if not set)
    MIMO_API_ENDPOINT  - MIMO API endpoint URL (auto-detected if not set)
"""

import asyncio
import json
import os
import subprocess
import sys

# ── Auto-install dependencies ──────────────────────────────────────────────────
def ensure_deps():
    for pkg in ("websockets", "httpx"):
        try:
            __import__(pkg)
        except ImportError:
            print(f"[bridge] Installing {pkg}...")
            subprocess.check_call(
                [sys.executable, "-m", "pip", "install", "-q", pkg],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
            print(f"[bridge] {pkg} installed.")

ensure_deps()

import websockets  # noqa: E402
import httpx       # noqa: E402

# ── Configuration ──────────────────────────────────────────────────────────────
WS_URL = os.getenv("MIMO_RELAY_WS_URL", sys.argv[1] if len(sys.argv) > 1 else "")
if not WS_URL:
    print("[bridge] ERROR: WebSocket URL is required. Usage: python3 bridge.py <WS_URL>")
    sys.exit(1)

KEY = os.getenv("MIMO_API_KEY", "")
URL = os.getenv("MIMO_API_ENDPOINT", "")

# Auto-detect local MIMO API endpoint if not explicitly set
if not URL:
    candidates = [
        "http://localhost:3000/v1/chat/completions",
        "http://127.0.0.1:3000/v1/chat/completions",
        "http://localhost:8080/v1/chat/completions",
        "http://127.0.0.1:8080/v1/chat/completions",
    ]
    for candidate in candidates:
        try:
            r = httpx.get(candidate.replace("/v1/chat/completions", "/"), timeout=2)
            if r.status_code < 500:
                URL = candidate
                print(f"[bridge] Auto-detected MIMO API endpoint: {URL}")
                break
        except Exception:
            continue
    if not URL:
        # Fallback: use environment discovery
        for env_key in ("MIMO_API_ENDPOINT", "OPENAI_BASE_URL", "API_BASE_URL"):
            val = os.getenv(env_key, "")
            if val and "/v1/" in val:
                URL = val
                print(f"[bridge] Discovered API endpoint from env ${env_key}: {URL}")
                break

BASE = URL.split("/v1/")[0] if "/v1/" in URL else URL

print(f"[bridge] Starting MIMO Relay Bridge")
print(f"[bridge]   Gateway WS : {WS_URL}")
print(f"[bridge]   API Base   : {BASE}")
print(f"[bridge]   API Key    : {'***' + KEY[-8:] if KEY else '(auto-detect)'}")


# ── WebSocket relay core ───────────────────────────────────────────────────────
async def safe_send(ws, lock, data):
    async with lock:
        await ws.send(json.dumps(data))


async def handle_request(ws, req, client, lock):
    req_id = req.get("req_id")
    path = req.get("path", "")
    method = req.get("method", "GET")
    body = req.get("body", "")

    # Route to correct API path
    if "/anthropic/" in path:
        target_url = f"{BASE}/anthropic/v1/messages"
    else:
        target_url = URL

    # Build headers - use provided key or empty
    headers = {"Content-Type": "application/json"}
    if KEY:
        headers["api-key"] = KEY

    try:
        async with client.stream(
            method=method,
            url=target_url,
            headers=headers,
            content=body,
        ) as r:
            await safe_send(ws, lock, {
                "req_id": req_id, "type": "start",
                "status": r.status_code, "headers": dict(r.headers),
            })
            async for chunk in r.aiter_text():
                if chunk:
                    await safe_send(ws, lock, {
                        "req_id": req_id, "type": "chunk", "body": chunk,
                    })
            await safe_send(ws, lock, {"req_id": req_id, "type": "finish"})
    except Exception as e:
        try:
            await safe_send(ws, lock, {
                "req_id": req_id, "type": "error", "body": str(e),
            })
        except Exception:
            pass


async def main():
    reconnect_delay = 1
    max_delay = 30
    while True:
        try:
            print(f"[bridge] Connecting to {WS_URL} ...")
            async with websockets.connect(WS_URL, max_size=10**8) as ws:
                reconnect_delay = 1
                send_lock = asyncio.Lock()
                print(f"[bridge] Connected! Listening for requests...")
                async for msg in ws:
                    try:
                        data = json.loads(msg)
                        asyncio.create_task(handle_request(ws, data, None, send_lock))
                    except json.JSONDecodeError:
                        pass
        except Exception as e:
            print(f"[bridge] Connection lost: {e}. Reconnecting in {reconnect_delay}s ...")
            await asyncio.sleep(reconnect_delay)
            reconnect_delay = min(reconnect_delay * 2, max_delay)


async def run():
    async with httpx.AsyncClient(timeout=None) as client:
        reconnect_delay = 1
        max_delay = 30
        while True:
            try:
                print(f"[bridge] Connecting to {WS_URL} ...")
                async with websockets.connect(WS_URL, max_size=10**8) as ws:
                    reconnect_delay = 1
                    send_lock = asyncio.Lock()
                    print(f"[bridge] Connected! Listening for requests...")
                    async for msg in ws:
                        try:
                            data = json.loads(msg)
                            asyncio.create_task(handle_request(ws, data, client, send_lock))
                        except json.JSONDecodeError:
                            pass
            except Exception as e:
                print(f"[bridge] Connection lost: {e}. Reconnecting in {reconnect_delay}s ...")
                await asyncio.sleep(reconnect_delay)
                reconnect_delay = min(reconnect_delay * 2, max_delay)


if __name__ == "__main__":
    asyncio.run(run())

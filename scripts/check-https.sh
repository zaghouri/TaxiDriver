#!/usr/bin/env bash
# Checks the public endpoint: HTTPS /health/ready and a Socket.IO websocket handshake on /ws.
# Usage: scripts/check-https.sh [host]     (default: PUBLIC_HOST or SERVER_IP.sslip.io from .env)
#        SCHEME=http scripts/check-https.sh localhost:8080   (local, no TLS)
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "$0")/lib.sh"

host="${1:-$(public_host)}"
scheme="${SCHEME:-https}"
ws_scheme=wss; [ "$scheme" = http ] && ws_scheme=ws
fail=0

log "GET $scheme://$host/health/ready"
if body="$(curl -fsS --max-time 10 "$scheme://$host/health/ready")"; then
  echo "PASS health/ready: $body"
else
  echo "FAIL health/ready"; fail=1
fi

if [ "$scheme" = https ]; then
  if expiry="$(echo | openssl s_client -servername "${host%%:*}" -connect "${host%%:*}:443" 2>/dev/null \
      | openssl x509 -noout -enddate 2>/dev/null)"; then
    echo "PASS certificate: ${expiry#notAfter=}"
  else
    echo "FAIL certificate: could not read the TLS certificate"; fail=1
  fi
fi

log "websocket handshake $ws_scheme://$host/ws/?EIO=4&transport=websocket"
key="$(openssl rand -base64 16)"
# curl keeps the upgraded connection open until --max-time; we only need the status line.
headers="$(curl -sS -i -N --http1.1 --max-time 5 \
  -H 'Connection: Upgrade' -H 'Upgrade: websocket' \
  -H 'Sec-WebSocket-Version: 13' -H "Sec-WebSocket-Key: $key" \
  "$scheme://$host/ws/?EIO=4&transport=websocket" 2>/dev/null || true)"
if printf '%s' "$headers" | head -n 1 | grep -q ' 101'; then
  echo "PASS websocket: 101 Switching Protocols"
else
  echo "FAIL websocket: $(printf '%s' "$headers" | head -n 1)"; fail=1
fi

exit "$fail"

#!/usr/bin/env bash
#
# Run the app against the local backend without the ritual.
#
# Why this exists: the Android debug build used to reach the backend only at
# 127.0.0.1:8000, which on a phone means the phone itself. That works solely
# while an `adb reverse tcp:8000 tcp:8000` tunnel is alive -- and that tunnel
# dies on every cable unplug, phone reboot and `adb kill-server`, with nothing
# re-creating it. The symptom was a "Connection refused" that kept coming back
# and looked like the backend was down.
#
# This does both halves so neither has to be remembered:
#   1. re-creates the USB tunnel (harmless if it already exists);
#   2. passes this machine's current Wi-Fi address to the build, so the app
#      still reaches the backend when the tunnel is gone but the phone and the
#      laptop are on the same network.
#
# The app tries production, then the tunnel, then Wi-Fi, and uses whichever
# answers -- see ApiConfig.resolveBaseUrl.
#
# Usage:  ./scripts/dev.sh [extra flutter run args]

set -euo pipefail
cd "$(dirname "$0")/.."

PORT="${BACKEND_PORT:-8000}"

# --- is the backend actually up? ------------------------------------------
if ! lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "!! Nothing is listening on port $PORT."
  echo "   Start Postgres and the backend first:"
  echo "     docker compose up -d"
  echo "     cd backend && source venv/bin/activate && uvicorn app.main:app --host 0.0.0.0 --port $PORT"
  exit 1
fi

# --- USB tunnel ------------------------------------------------------------
if command -v adb >/dev/null 2>&1 && [ -n "$(adb devices | sed -n '2p')" ]; then
  adb reverse "tcp:$PORT" "tcp:$PORT" >/dev/null 2>&1 \
    && echo "-> adb reverse tcp:$PORT ready" \
    || echo "!! adb reverse failed; relying on Wi-Fi instead"
else
  echo "-- no adb device; relying on Wi-Fi instead"
fi

# --- Wi-Fi address ---------------------------------------------------------
# en0 is Wi-Fi on most Macs; en1 covers the rest. Empty is fine -- the app
# simply has one fewer candidate to try.
HOST_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"

if [ -n "$HOST_IP" ]; then
  echo "-> this machine is $HOST_IP on the local network"
  # The backend must be bound to 0.0.0.0, not 127.0.0.1, to answer there.
  if ! curl -s -m 3 -o /dev/null "http://$HOST_IP:$PORT/health"; then
    echo "!! $HOST_IP:$PORT does not answer /health."
    echo "   The backend is probably bound to 127.0.0.1 only. Restart it with:"
    echo "     uvicorn app.main:app --host 0.0.0.0 --port $PORT"
    echo "   Continuing anyway -- the USB tunnel may still work."
  fi
else
  echo "-- no Wi-Fi address found"
fi

DEFINES=(--dart-define-from-file=mapbox.json)
[ -n "$HOST_IP" ] && DEFINES+=(--dart-define=DEV_API_HOST="$HOST_IP")

echo
exec flutter run "${DEFINES[@]}" "$@"

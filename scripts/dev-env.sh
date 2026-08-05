#!/usr/bin/env bash
#
# Everything the app needs before `flutter run`, made idempotent and quick.
#
# Why this exists: the debug build reaches the backend at 127.0.0.1:8000, which
# on a phone means the phone itself. That only works while an
# `adb reverse tcp:8000 tcp:8000` tunnel is alive -- and the tunnel dies on
# every cable unplug, phone reboot and `adb kill-server`, with nothing putting
# it back. Launching from an IDE skipped even the one-off setup, so
# "Connection refused" kept coming back and looked like the backend was down.
#
# Run before every launch (VS Code does this via .vscode/tasks.json). It:
#   1. starts Postgres if it is not up;
#   2. starts the backend if nothing is listening, bound to 0.0.0.0 so the
#      phone can also reach it over Wi-Fi;
#   3. waits until /health actually answers;
#   4. creates the USB tunnel and leaves a watchdog re-creating it;
#   5. writes this machine's current Wi-Fi address to .dev-env.json, which the
#      launch config feeds to the build as DEV_API_HOST.
#
# Steps 4 and 5 are two independent routes to the same backend. The app tries
# both and uses whichever answers (see ApiConfig.resolveBaseUrl), so one of
# them failing is no longer a failure.
#
# Exits promptly: the watchdog is detached and outlives this script.
#
# Usage:  ./scripts/dev-env.sh          prepare everything
#         ./scripts/dev-env.sh --stop   stop the watchdog and the backend we started

set -euo pipefail
cd "$(dirname "$0")/.."

PORT="${BACKEND_PORT:-8000}"
DEFINES_FILE=".dev-env.json"
TUNNEL_PID_FILE=".dev-tunnel.pid"
BACKEND_PID_FILE=".dev-backend.pid"
BACKEND_LOG=".dev-backend.log"

stop_everything() {
  for pid_file in "$TUNNEL_PID_FILE" "$BACKEND_PID_FILE"; do
    if [ -f "$pid_file" ]; then
      kill "$(cat "$pid_file")" 2>/dev/null || true
      rm -f "$pid_file"
      echo "-- stopped $(basename "$pid_file" .pid)"
    fi
  done
  exit 0
}

[ "${1:-}" = "--stop" ] && stop_everything

# A pid file is only meaningful while that process is still alive; a stale one
# left by a crash or a reboot would otherwise suppress the restart forever.
running() {
  local pid_file="$1"
  [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null
}

# --- Postgres ---------------------------------------------------------------
if ! docker compose ps --format '{{.State}}' 2>/dev/null | grep -q running; then
  echo "-> starting Postgres"
  docker compose up -d >/dev/null
fi

# --- backend ----------------------------------------------------------------
# Left alone if something is already serving the port: that is usually the
# developer's own `uvicorn --reload` in a terminal, and replacing it would
# take their logs away.
if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "-> backend already listening on :$PORT"
else
  VENV=""
  for candidate in .venv venv backend/.venv backend/venv; do
    [ -x "$candidate/bin/uvicorn" ] && VENV="$candidate" && break
  done

  if [ -z "$VENV" ]; then
    echo "!! No virtualenv with uvicorn found (.venv or venv, here or in backend/)."
    echo "   Start the backend yourself, then launch again."
    exit 1
  fi

  echo "-> starting backend from $VENV (log: $BACKEND_LOG)"
  # 0.0.0.0, not 127.0.0.1: bound to loopback only, the Wi-Fi route below
  # cannot work and the tunnel becomes a single point of failure again.
  ( cd backend && nohup "../$VENV/bin/uvicorn" app.main:app \
      --host 0.0.0.0 --port "$PORT" > "../$BACKEND_LOG" 2>&1 &
    echo $! > "../$BACKEND_PID_FILE" )
fi

# --- wait for it to actually answer ----------------------------------------
# "Listening" is not "ready": the app's first sync fires seconds after launch,
# and a backend still opening its database connection would refuse it.
for _ in $(seq 1 40); do
  curl -s -m 2 -o /dev/null "http://127.0.0.1:$PORT/health" && break
  sleep 0.5
done

if ! curl -s -m 2 -o /dev/null "http://127.0.0.1:$PORT/health"; then
  echo "!! Backend never answered /health on :$PORT. See $BACKEND_LOG."
  exit 1
fi
echo "-> backend healthy on :$PORT"

# --- USB tunnel, kept alive -------------------------------------------------
if command -v adb >/dev/null 2>&1; then
  adb reverse "tcp:$PORT" "tcp:$PORT" >/dev/null 2>&1 || true

  if running "$TUNNEL_PID_FILE"; then
    echo "-> tunnel watchdog already running (pid $(cat "$TUNNEL_PID_FILE"))"
  else
    # Detached, so this script can return and the IDE can get on with the
    # build. Gives up after five minutes with no device attached rather than
    # lingering forever once the phone is unplugged for the day.
    nohup bash -c '
      idle=0
      while [ "$idle" -lt 100 ]; do
        if [ -n "$(adb devices 2>/dev/null | sed -n "2p")" ]; then
          idle=0
          adb reverse --list 2>/dev/null | grep -q "tcp:'"$PORT"'" \
            || adb reverse "tcp:'"$PORT"'" "tcp:'"$PORT"'" >/dev/null 2>&1 || true
        else
          idle=$((idle + 1))
        fi
        sleep 3
      done
    ' >/dev/null 2>&1 &
    echo $! > "$TUNNEL_PID_FILE"
    echo "-> tunnel watchdog started (pid $!); re-creates adb reverse whenever it drops"
  fi
else
  echo "-- adb not on PATH; relying on Wi-Fi only"
fi

# --- this machine's address on the local network ----------------------------
# Written to a file rather than baked into the launch config: DHCP reassigns
# it, and a stale address in version control is worse than none.
HOST_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"

if [ -n "$HOST_IP" ]; then
  printf '{"DEV_API_HOST": "%s"}\n' "$HOST_IP" > "$DEFINES_FILE"
  if curl -s -m 3 -o /dev/null "http://$HOST_IP:$PORT/health"; then
    echo "-> Wi-Fi route ready: $HOST_IP:$PORT"
  else
    echo "!! $HOST_IP:$PORT does not answer -- backend is probably bound to"
    echo "   127.0.0.1 only. The USB tunnel still works."
  fi
else
  printf '{"DEV_API_HOST": ""}\n' > "$DEFINES_FILE"
  echo "-- no Wi-Fi address; USB tunnel only"
fi

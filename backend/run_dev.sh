#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# Active venv if exist
if [[ -d .venv ]]; then source .venv/bin/activate; fi

# Install backend if is missing
python - <<'PY'
import importlib, subprocess, sys
def ensure_websocket_support():
    try:
        import websockets  # noqa
    except ImportError:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "uvicorn[standard]==0.38.0"])
ensure_websocket_support()
PY

PORT="${PORT:-8000}"

# Try to free the port if a previous dev server is still running
if command -v lsof >/dev/null 2>&1; then
  existing_pids="$(lsof -ti tcp:"${PORT}" 2>/dev/null || true)"
  if [[ -n "${existing_pids}" ]]; then
    echo "Stopping processes on port ${PORT}: ${existing_pids}"
    kill ${existing_pids} || true
    sleep 1
  fi
elif command -v fuser >/dev/null 2>&1; then
  if fuser -n tcp "${PORT}" >/dev/null 2>&1; then
    echo "Stopping processes on port ${PORT}"
    fuser -k -n tcp "${PORT}" || true
    sleep 1
  fi
fi

# Start
uvicorn app.main:app --reload
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
# Start
uvicorn app.main:app --reload
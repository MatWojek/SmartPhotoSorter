#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# Aktywuj venv jeśli istnieje
if [[ -d .venv ]]; then source .venv/bin/activate; fi
# Doinstaluj ws backend jeżeli brakuje
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
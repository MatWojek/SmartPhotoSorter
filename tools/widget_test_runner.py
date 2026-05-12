#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
FLUTTER_DIR = REPO_ROOT / "frontend_flutter"


def run():
    try:
        # Ensure dependencies are available
        subprocess.run(["flutter", "pub", "get"], cwd=str(FLUTTER_DIR), check=True)
        # Run tests
        proc = subprocess.run(["flutter", "test"], cwd=str(FLUTTER_DIR), capture_output=True, text=True)
        sys.stdout.write(proc.stdout)
        sys.stderr.write(proc.stderr)
        if proc.returncode != 0:
            raise SystemExit(f"widget_test_runner: FAIL (exit {proc.returncode})")
        print("widget_test_runner: PASS")
    except FileNotFoundError:
        raise SystemExit("Flutter SDK not found in PATH. Please install or add to PATH.")


if __name__ == "__main__":
    run()

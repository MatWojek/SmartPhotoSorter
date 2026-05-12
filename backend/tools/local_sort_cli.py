#!/usr/bin/env python3
import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any, Dict, Optional


def _bootstrap_imports() -> None:
    # Ensure `backend/` is on sys.path so we can import `app.*`
    backend_dir = Path(__file__).resolve().parents[1]
    if str(backend_dir) not in sys.path:
        sys.path.insert(0, str(backend_dir))


def _emit(ev: Dict[str, Any]) -> None:
    sys.stdout.write(json.dumps(ev, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def main() -> int:
    parser = argparse.ArgumentParser(description="SmartPhotoSorter local sort CLI (no HTTP, no DB)")
    parser.add_argument("--training-json", default="{}", help="JSON map person->folder")
    parser.add_argument("--unsorted-folder", required=True)
    parser.add_argument("--output-base", required=True)
    parser.add_argument("--unknown-folder", required=True)
    parser.add_argument("--remove-duplicates", dest="remove_duplicates", action="store_true")
    parser.add_argument("--no-remove-duplicates", dest="remove_duplicates", action="store_false")
    parser.set_defaults(remove_duplicates=True)

    parser.add_argument("--sort-photos", dest="sort_photos", action="store_true")
    parser.add_argument("--no-sort-photos", dest="sort_photos", action="store_false")
    parser.set_defaults(sort_photos=True)
    parser.add_argument("--match-threshold", type=float, default=0.35)
    args = parser.parse_args()

    _bootstrap_imports()

    try:
        from app.ml.face_recognition import FaceSorter  # type: ignore
    except Exception as e:
        _emit({"status": "error", "message": f"Cannot import backend ML modules: {e}"})
        return 2

    try:
        training: Dict[str, str] = json.loads(args.training_json or "{}")
        if not isinstance(training, dict):
            training = {}
        training = {str(k): str(v) for k, v in training.items()}
    except Exception:
        training = {}

    remove_duplicates = bool(args.remove_duplicates)
    sort_photos = bool(args.sort_photos)

    sorter = FaceSorter()

    def progress_cb(ev: Dict[str, Any]) -> None:
        _emit(ev)

    _emit({
        "status": "started",
        "message": "Local sorting started",
        "current": 0,
        "total": 0,
    })

    try:
        if training:
            sorter.train_from_folders(training, progress_cb, user_id=None)

        summary = sorter.sort_folder(
            args.unsorted_folder,
            args.output_base,
            args.unknown_folder,
            progress_cb,
            user_id=None,
            remove_duplicates=remove_duplicates,
            sort_photos=sort_photos,
            match_threshold=float(args.match_threshold),
        )

        _emit({"status": "done", "summary": summary})
        return 0
    except KeyboardInterrupt:
        _emit({"status": "cancelled", "message": "Cancelled"})
        return 130
    except Exception as e:
        _emit({"status": "error", "message": str(e)})
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

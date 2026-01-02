#!/usr/bin/env python3
import sys
import shutil
from pathlib import Path
import numpy as np
import cv2

# Ensure we can import the module
BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_DIR))

from app.ml import face_recognition as fr


def make_image(path: Path, color: int):
    # Create synthetic grayscale-like BGR image with a simple pattern
    img = np.full((128, 128, 3), color, dtype=np.uint8)
    cv2.rectangle(img, (32, 32), (96, 96), (255 - color, 255 - color, 255 - color), thickness=-1)
    cv2.imwrite(str(path), img)


def run():
    sandbox = BACKEND_DIR / "app" / "storage" / "test_face_sandbox"
    train_a = sandbox / "train_alice"
    train_b = sandbox / "train_bob"
    unsorted = sandbox / "unsorted"
    output = sandbox / "sorted"
    unknown = sandbox / "unknown"

    # Clean & setup folders
    if sandbox.exists():
        shutil.rmtree(sandbox)
    for d in (train_a, train_b, unsorted, output, unknown):
        d.mkdir(parents=True, exist_ok=True)

    # Generate training images
    make_image(train_a / "a1.png", 50)
    make_image(train_a / "a2.png", 60)
    make_image(train_b / "b1.png", 200)

    # Unsorted images: two similar to Alice, one unknown-ish
    make_image(unsorted / "u1.png", 55)
    make_image(unsorted / "u2.png", 62)
    make_image(unsorted / "u3.png", 180)

    # Monkeypatch face detection to a fixed box
    def fake_detect_faces(detector, img):
        h, w = img.shape[:2]
        return [(int(w*0.25), int(h*0.25), int(w*0.5), int(h*0.5))]

    fr.detect_faces = fake_detect_faces  # type: ignore

    sorter = fr.FaceSorter()

    # Train
    sorter.train_from_folders({"Alice": str(train_a), "Bob": str(train_b)})

    # Sort
    summary = sorter.sort_folder(str(unsorted), str(output), str(unknown))

    # Expectations: two known (Alice), one known (Bob) or unknown depending on threshold
    assert summary["processed"] == 3
    assert summary["known"] + summary["unknown"] == 3

    print("test_face_recognition_runner: PASS", summary)


if __name__ == "__main__":
    run()

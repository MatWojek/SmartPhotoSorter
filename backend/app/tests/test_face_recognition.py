import sys, shutil
from pathlib import Path
import numpy as np
import cv2

BACKEND_DIR = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(BACKEND_DIR))

from app.ml import face_recognition as fr

def make_image(path: Path, color: int):
	img = np.full((128, 128, 3), color, dtype=np.uint8)
	cv2.rectangle(img, (32, 32), (96, 96), (255 - color, 255 - color, 255 - color), thickness=-1)
	cv2.imwrite(str(path), img)

def test_duplicate_removal_visual_and_bit(tmp_path):
	sandbox = BACKEND_DIR / "app" / "storage" / "test_dup_sandbox"
	unsorted = sandbox / "unsorted"
	output = sandbox / "sorted"
	unknown = sandbox / "unknown"

	if sandbox.exists(): shutil.rmtree(sandbox)
	for d in (unsorted, output, unknown): d.mkdir(parents=True, exist_ok=True)

	# bit duplicate: same content
	make_image(unsorted / "a.png", 50)
	shutil.copy2(unsorted / "a.png", unsorted / "a_copy.png")
	# visual near-duplicate: similar embedding
	make_image(unsorted / "b.png", 60)
	make_image(unsorted / "b_near.png", 61)

	sorter = fr.FaceSorter()
	# Fake detectors/embeddings: ensure close colors produce similar embeddings
	def fake_detect_faces(detector, img):
		h, w = img.shape[:2]
		return [(int(w*0.25), int(h*0.25), int(w*0.5), int(h*0.5))]
	fr.detect_faces = fake_detect_faces

	def fake_face_embed(img, box, size=128):
		val = float(img.mean() / 255.0)
		return np.full((128,), val, dtype=np.float64)
	fr.face_embed = fake_face_embed

	stats = sorter.sort_folder(str(unsorted), str(output), str(unknown))
	assert stats["processed"] == 4
	# One bit dup removed + one visual dup removed
	assert stats["duplicates_removed"] >= 2


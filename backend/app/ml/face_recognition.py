import os
import cv2
import numpy as np
import hashlib
from pathlib import Path
from typing import Callable, Dict, List, Optional, Tuple

ImagePath = str
ProgressCb = Callable[[dict], None]


def list_images(folder: str, exts: Tuple[str, ...] = (".jpg", ".jpeg", ".png", ".bmp")) -> List[ImagePath]:
    base = Path(folder)
    return [
        str(base / name)
        for name in os.listdir(folder)
        if (base / name).is_file() and name.lower().endswith(exts)
    ]


def md5_file(path: str) -> str:
    h = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


def read_image(path: str) -> Optional[np.ndarray]:
    img = cv2.imread(path)
    return img


def detect_faces(detector: cv2.CascadeClassifier, img: np.ndarray) -> List[Tuple[int, int, int, int]]:
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    faces = detector.detectMultiScale(gray, scaleFactor=1.2, minNeighbors=5, minSize=(64, 64))
    # ensure a plain Python list of tuples
    return [(int(x), int(y), int(w), int(h)) for (x, y, w, h) in faces]


def face_embed(img: np.ndarray, box: Tuple[int, int, int, int], size: int = 128) -> np.ndarray:
    x, y, w, h = box
    crop = img[y:y + h, x:x + w]
    gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)
    resized = cv2.resize(gray, (size, size), interpolation=cv2.INTER_AREA)
    vec = resized.astype(np.float32).reshape(-1)
    vec /= (np.linalg.norm(vec) + 1e-8)
    return vec


def _haar_cascade_path() -> str:
    # Prefer bundle path near cv2 module
    base = Path(cv2.__file__).resolve().parent
    cand = base / "data" / "haarcascade_frontalface_default.xml"
    if cand.exists():
        return str(cand)
    # Fallback to cv2.data if available in this build
    data_attr = getattr(cv2, "data", None)
    if isinstance(data_attr, str):
        cand2 = Path(data_attr) / "haarcascade_frontalface_default.xml"
        if cand2.exists():
            return str(cand2)
    raise FileNotFoundError("Could not locate haarcascade_frontalface_default.xml for OpenCV.")


class FaceSorter:
    def __init__(self) -> None:
        self.detector = cv2.CascadeClassifier(_haar_cascade_path())
        self.person_embeds: Dict[str, List[np.ndarray]] = {}
        self.person_means: Dict[str, np.ndarray] = {}
        self.duplicate_hashes: set[str] = set()

    def train_from_folders(self, person_folders: Dict[str, str], progress: Optional[ProgressCb] = None) -> None:
        total = sum(len(list_images(folder)) for folder in person_folders.values())
        done = 0

        for person, folder in person_folders.items():
            imgs = list_images(folder)
            embeds: List[np.ndarray] = []
            for path in imgs:
                img = read_image(path)
                if img is None:
                    done += 1
                    if progress:
                        progress({"status": "skip", "current": done, "total": total, "photo": path, "message": "Unreadable"})
                    continue
                faces = detect_faces(self.detector, img)
                if not faces:
                    done += 1
                    if progress:
                        progress({"status": "skip", "current": done, "total": total, "photo": path, "message": "No face"})
                    continue
                emb = face_embed(img, faces[0])
                embeds.append(emb)
                done += 1
                if progress:
                    progress({"status": "train", "current": done, "total": total, "photo": path, "message": f"Added sample for {person}"})
            if embeds:
                self.person_embeds[person] = embeds
                self.person_means[person] = np.mean(np.stack(embeds), axis=0)

    def _match_person(self, emb: np.ndarray, threshold: float = 0.35) -> Optional[str]:
        best_name = None
        best_dist = 1e9
        for name, mean in self.person_means.items():
            dist = np.linalg.norm(emb - mean)
            if dist < best_dist:
                best_dist, best_name = dist, name
        if best_name is not None and best_dist <= threshold:
            return best_name
        return None

    def sort_folder(self, unsorted_folder: str, output_base: str, unknown_folder: str, progress: Optional[ProgressCb] = None) -> Dict[str, int]:
        paths = list_images(unsorted_folder)
        total = len(paths)
        moved_known = moved_unknown = skipped = removed_dups = 0

        os.makedirs(output_base, exist_ok=True)
        os.makedirs(unknown_folder, exist_ok=True)

        for i, path in enumerate(paths, start=1):
            file_md5 = md5_file(path)
            if file_md5 in self.duplicate_hashes:
                # exact duplicate found; remove
                try:
                    os.remove(path)
                    removed_dups += 1
                    if progress:
                        progress({"status": "duplicate", "current": i, "total": total, "photo": path, "message": "Removed duplicate"})
                    continue
                except Exception as e:
                    if progress:
                        progress({"status": "error", "current": i, "total": total, "photo": path, "message": f"Dup removal failed: {e}"})
            else:
                self.duplicate_hashes.add(file_md5)

            img = read_image(path)
            if img is None:
                skipped += 1
                if progress:
                    progress({"status": "skip", "current": i, "total": total, "photo": path, "message": "Unreadable"})
                continue

            faces = detect_faces(self.detector, img)
            if not faces:
                skipped += 1
                if progress:
                    progress({"status": "skip", "current": i, "total": total, "photo": path, "message": "No face"})
                continue

            emb = face_embed(img, faces[0])
            match = self._match_person(emb)
            dest_dir = os.path.join(output_base, match) if match else unknown_folder
            os.makedirs(dest_dir, exist_ok=True)
            dest_path = os.path.join(dest_dir, os.path.basename(path))
            try:
                os.replace(path, dest_path)
            except Exception:
                # fallback if moving across devices
                import shutil
                shutil.move(path, dest_path)

            if match:
                moved_known += 1
                if progress:
                    progress({"status": "moved", "current": i, "total": total, "photo": path, "destination": dest_dir, "message": f"Sorted to {match}"})
            else:
                moved_unknown += 1
                if progress:
                    progress({"status": "moved", "current": i, "total": total, "photo": path, "destination": dest_dir, "message": "Sorted to unknown"})

        return {
            "processed": total,
            "known": moved_known,
            "unknown": moved_unknown,
            "skipped": skipped,
            "duplicates_removed": removed_dups,
        }
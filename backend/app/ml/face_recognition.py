import os
import numpy as np
import hashlib
from pathlib import Path
from typing import Callable, Dict, List, Optional, Tuple
import shutil

from face_recognition import (
    load_image_file,
    face_locations,
    face_encodings,
    face_distance,
)

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
    try:
        img = load_image_file(path) #RGB 
        return img
    except Exception:
        return None

def detect_faces(detector, img: np.ndarray) -> List[Tuple[int, int, int, int]]:
    # face_recognition: (top, right, bottom, left)
    boxes = face_locations(img, model="hog")
    faces = []
    for top, right, bottom, left in boxes:
        x = left
        y = top
        w = right - left
        h = bottom - top
        faces.append((x, y, w, h))
    return faces

def face_embed(img: np.ndarray, box: Tuple[int, int, int, int]) -> np.ndarray:
    
    x, y, w, h = box
    top, right, bottom, left = y, x + w, y + h, x

    encodings = face_encodings(
        img,
        known_face_locations=[(top, right, bottom, left)]
    )

    if not encodings:
        raise ValueError("No face encoding")

    emb = encodings[0].astype(np.float64)
    norm = np.linalg.norm(emb)

    if norm == 0:
        raise ValueError("Zero norm embedding")

    return emb / norm


def _copy_on_error(src_path: str, user_id: Optional[str], reason: str) -> Optional[str]:

    try:
        base = Path("smartphotosorterdb") / "errors" / (user_id or "general") / reason
        base.mkdir(parents=True, exist_ok=True)
        dest = base / Path(src_path).name
        shutil.copy2(src_path, dest)
        return str(dest)
    
    except Exception:
        return None

class FaceSorter:
    """
    Face recognition sorter and trainer.

    Maintains in-memory embeddings per person, supports training from folders
    and sorting an unsorted folder into person-specific subfolders. Uses MD5
    to filter exact duplicates and a simple distance heuristic for visual dups.
    """

    def __init__(self) -> None:
        self.person_embeds: Dict[str, List[np.ndarray]] = {}
        self.person_means: Dict[str, np.ndarray] = {}
        self.duplicate_hashes: set[str] = set()
        self.image_embeddings: List[np.ndarray] = []

    def _mean_matrix(self) -> tuple[list[str], Optional[np.ndarray]]:
        if not self.person_means:
            return [], None
        names = list(self.person_means.keys())
        try:
            mat = np.stack([self.person_means[n] for n in names], axis=0)
        except Exception:
            return [], None
        return names, mat

    def load_from_db(self, user_id: str) -> None:
        """Load existing embeddings for a `user_id` from the DB into memory."""
        from app.db.mongodb import persons_collection
        docs = persons_collection.find({"user_id": user_id}, {"_id": 0, 
                                                              "name": 1, 
                                                              "embeddings": 1, 
                                                              "mean_embedding": 1
                                                            })
        for d in docs:
            name = d["name"]
            embeds = [np.array(e, dtype=np.float64) for e in d.get("embeddings", [])]
            if embeds:
                self.person_embeds[name] = embeds
                mean = d.get("mean_embedding")
                self.person_means[name] = np.array(mean, dtype=np.float64) if mean else np.mean(np.stack(embeds), axis=0)

    def _get_trained_md5s(self, user_id: str, person: str) -> set[str]:
        from app.db.mongodb import persons_collection
        doc = persons_collection.find_one({"user_id": user_id, 
                                           "name": person}, 
                                           {"trained_files": 1})
        md5s: set[str] = set()
        if doc and doc.get("trained_files"):
            for f in doc["trained_files"]:
                if isinstance(f, dict) and "md5" in f:
                    md5s.add(f["md5"])
                elif isinstance(f, str):
                    md5s.add(f)
        return md5s

    def _persist_person(
            self, 
            user_id: str, 
            person: str, 
            new_embeds: list[np.ndarray], 
            new_files: list[str], 
            folder: str
        ) -> None:

        from app.db.mongodb import persons_collection
        if not new_embeds:
            return
        persons_collection.update_one(
            {"user_id": user_id, "name": person},
            {
                "$setOnInsert": {"path": folder},
                "$push": {"embeddings": {"$each": [e.tolist() for e in new_embeds], "$slice": -200}},
                "$set": {"mean_embedding": self.person_means[person].tolist()},
                "$addToSet": {"trained_files": {"$each": [{"md5": md5_file(p), 
                                                           "filename": os.path.basename(p)} for p in new_files]}}
            },
            upsert=True
        )

    def ensure_trained_for_user(self, user_id: str, progress: Optional[ProgressCb] = None) -> None:
        """Ensure all person folders for `user_id` are trained, skipping already-trained files."""

        from app.db.mongodb import persons_collection

        persons = list(persons_collection.find({"user_id": user_id}, {"_id": 0, 
                                                                      "name": 1, 
                                                                      "path": 1, 
                                                                      "trained_files": 1}))
        for p in persons:
            name = p["name"]
            folder = p.get("path")

            if not folder:
                continue
            imgs = list_images(folder)
            trained_md5s = set()

            if p.get("trained_files"):
                for f in p["trained_files"]:
                    if isinstance(f, dict) and "md5" in f: trained_md5s.add(f["md5"])
                    elif isinstance(f, str): trained_md5s.add(f)

            new_embeds: List[np.ndarray] = []
            new_paths: List[str] = []

            for path in imgs:
                file_md5 = md5_file(path)

                if file_md5 in trained_md5s:
                    if progress: progress({
                        "status":"skip",
                        "photo":path,
                        "message":"Already trained"
                    })
                    continue
        
                img = read_image(path)

                if img is None:
                    copied = _copy_on_error(path, user_id, "unreadable")
                    if progress:
                        progress({
                            "status": "error_copy",
                            "photo": path,
                            "copied_to": copied,
                            "message": "Unreadable, copied to storage root"
                        })

                    if user_id and copied:
                        from app.photos.service import PhotoService
                        PhotoService.insert_local_photo(user_id, path, copied, note="error_unreadable")
                    
                    continue
                faces = detect_faces(None, img)

                if not faces:
                    if progress: progress({"status":"skip","photo":path,"message":"No face"})
                    continue

                try:
                    emb = face_embed(img, faces[0])
                    new_embeds.append(emb)
                    new_paths.append(path)

                    if progress: progress({"status":"train","photo":path,"message":f"Added sample for {name}"})
                except Exception:
                    if progress: progress({"status":"skip",
                                           "photo":path,
                                           "message":"Encoding failed"})
            if new_embeds:
                prev = self.person_embeds.get(name, [])
                self.person_embeds[name] = prev + new_embeds
                self.person_means[name] = np.mean(np.stack(self.person_embeds[name]), axis=0)
                self._persist_person(user_id, name, new_embeds, new_paths, folder)
    
    def _normalize(self, emb: np.ndarray) -> np.ndarray:
        norm = np.linalg.norm(emb)
        if norm == 0:
            return emb
        return emb / norm

    def _select_best_face(
        self,
        img: np.ndarray,
        faces: List[Tuple[int, int, int, int]],
        person_name: Optional[str] = None
    ) -> Tuple[int, int, int, int]:
        """
        If the person exists, select the face closest to the mean embedding. 
        If not, select the largest face.
        """

        if person_name and person_name in self.person_means:
            mean = self.person_means[person_name]
            best_face = None
            best_dist = float("inf")

            for box in faces:
                try:
                    emb = face_embed(img, box)
                    dist = np.linalg.norm(mean - emb)

                    if dist < best_dist:
                        best_dist = dist
                        best_face = box
                except Exception:
                    continue

            if best_face:
                return best_face

        # fallback → the biggest face
        return max(faces, key=lambda b: b[2] * b[3])


    def train_from_folders(
            self, 
            person_folders: Dict[str, str], 
            progress: Optional[ProgressCb] = None, 
            user_id: Optional[str] = None
        ) -> None:
        """Train embeddings from a mapping {person: folder}.

        Optionally records training in DB when `user_id` is provided.
        """
        total = sum(len(list_images(folder)) for folder in person_folders.values())
        done = 0

        for person, folder in person_folders.items():
            imgs = list_images(folder)
            embeds: List[np.ndarray] = []
            processed_paths: List[str] = []
            trained_md5s: set[str] = self._get_trained_md5s(user_id, person) if user_id else set()

            for path in imgs:
                file_md5 = md5_file(path)
                done += 1
                if user_id and file_md5 in trained_md5s:
                    if progress: progress({"status":"skip","current":done,"total":total,"photo":path,"message":"Already trained"})
                    continue
                img = read_image(path)

                if img is None:
                    copied = _copy_on_error(path, user_id, "unreadable")
                    if progress:
                        progress({
                            "status": "error_copy",
                            "photo": path,
                            "copied_to": copied,
                            "message": "Unreadable, copied to storage root"
                        })

                    if user_id and copied:
                        from app.photos.service import PhotoService
                        PhotoService.insert_local_photo(user_id, path, copied, note="error_unreadable")
                    continue
                faces = detect_faces(None, img)

                if not faces:
                    if progress: progress({"status":"skip",
                                           "current":done,
                                           "total":total,
                                           "photo":path,
                                           "message":"No face"})
                    continue

                try:
                    emb = face_embed(img, faces[0])
                    embeds.append(emb)
                    processed_paths.append(path)

                    if progress: progress({"status":"train",
                                           "current":done,
                                           "total":total,
                                           "photo":path,
                                           "message":f"Added sample for {person}"})
                        
                except Exception:
                    if progress: progress({"status":"skip",
                                           "current":done,
                                           "total":total,
                                           "photo":path,
                                           "message":"Encoding failed"})
                        
            if embeds:
                prev = self.person_embeds.get(person, [])
                self.person_embeds[person] = prev + embeds
                self.person_means[person] = np.mean(np.stack(self.person_embeds[person]), axis=0)
                if user_id:
                    self._persist_person(user_id, person, embeds, processed_paths, folder)

    def train_single(
        self,
        user_id: str,
        person_name: str,
        photo_path: str,
        progress: Optional[ProgressCb] = None
    ) -> None:
        img = read_image(photo_path)
        if img is None:
            return

        # Compute MD5 for exact duplicate detection
        file_md5 = md5_file(photo_path)

        # Detect all faces in the image
        faces = detect_faces(None, img)
        if not faces:
            return

        embeddings: list[np.ndarray] = []

        for box in faces:
            try:
                emb = face_embed(img, box)
            except Exception:
                continue

            # Normalize embedding
            norm = np.linalg.norm(emb)
            if norm == 0:
                continue
            emb = emb / norm

            # Cross-run visual deduplication (DB)
            if self._is_visual_duplicate(user_id, emb):
                continue

            embeddings.append(emb)

        if not embeddings:
            return

        # Store embeddings in memory
        prev = self.person_embeds.get(person_name, [])
        prev.extend(embeddings)
        self.person_embeds[person_name] = prev

        # Update mean embedding
        mean_emb = np.mean(np.stack(prev), axis=0)
        mean_emb = mean_emb / np.linalg.norm(mean_emb)
        self.person_means[person_name] = mean_emb

        # Persist to MongoDB
        from app.db.mongodb import persons_collection

        persons_collection.update_one(
            {"user_id": user_id, "name": person_name},
            {
                "$push": {
                    "embeddings": {
                        "$each": [e.tolist() for e in embeddings]
                    }
                },
                "$set": {
                    "mean_embedding": mean_emb.tolist()
                },
                "$addToSet": {
                    "trained_files": {
                        "md5": file_md5,
                        "filename": os.path.basename(photo_path)
                    }
                }
            },
            upsert=True
        )



    def _is_visual_duplicate(
            self, user_id: str, 
            emb: np.ndarray, 
            threshold: float = 0.15
        ) -> bool:
        # Check if a visually similar image already exists in the database
        from app.db.mongodb import photos_collection

        docs = photos_collection.find(
            {"user_id": user_id, "image_embedding": {"$exists": True}},
            {"image_embedding": 1}
        )

        for d in docs:
            other = np.array(d["image_embedding"], dtype=np.float64)
            dist = np.linalg.norm(other - emb)
            if dist < threshold:
                return True

        return False

    def _match_person(self, emb: np.ndarray, threshold: float = 0.35) -> Optional[str]:
        details = self._match_person_details(emb, threshold=threshold)
        return details["name"]

    def _match_person_details(self, emb: np.ndarray, threshold: float = 0.35) -> dict:
        """Return best match details.

        Output format:
        - name: matched person name or None
        - distance: float (lower is better)
        - confidence: float in [0..100]
        - second_distance: float|None (optional)
        """
        names, means = self._mean_matrix()
        if means is None or not names:
            return {"name": None, "distance": None, "confidence": 0.0, "second_distance": None}

        # L2 distance on normalized embeddings
        try:
            dists = np.linalg.norm(means - emb, axis=1)
        except Exception:
            return {"name": None, "distance": None, "confidence": 0.0, "second_distance": None}

        best_idx = int(np.argmin(dists))
        best_dist = float(dists[best_idx])
        second_dist: Optional[float] = None
        if len(dists) > 1:
            # second smallest without fully sorting
            second_dist = float(np.partition(dists, 1)[1])

        if best_dist > threshold:
            return {
                "name": None,
                "distance": best_dist,
                "confidence": 0.0,
                "second_distance": second_dist,
            }

        # Map distance to an interpretable 0..100 confidence.
        # NOTE: this is a heuristic calibration tied to `threshold`.
        base = max(0.0, 1.0 - (best_dist / threshold))
        sep = 0.0
        if second_dist is not None:
            sep = max(0.0, min(1.0, (second_dist - best_dist) / threshold))
        conf = base * (0.7 + 0.3 * sep)
        conf_pct = float(np.clip(conf * 100.0, 0.0, 100.0))

        return {
            "name": names[best_idx],
            "distance": best_dist,
            "confidence": round(conf_pct, 1),
            "second_distance": second_dist,
        }
    
    def sort_folder(
        self,
        unsorted_folder: str,
        output_base: str,
        unknown_folder: str,
        progress: Optional[ProgressCb] = None,
        user_id: Optional[str] = None,
        remove_duplicates: bool = True,
        sort_photos: bool = True,
        match_threshold: float = 0.35,
    ) -> Dict[str, int]:

        paths = list_images(unsorted_folder)
        total = len(paths)

        moved_known = moved_unknown = skipped = removed_dups = 0
        match_confidences: list[float] = []

        if sort_photos:
            os.makedirs(output_base, exist_ok=True)
            os.makedirs(unknown_folder, exist_ok=True)

        # Preload DB embeddings once per run (instead of O(N) per photo).
        db_embeds: Optional[np.ndarray] = None
        if user_id and remove_duplicates:
            try:
                from app.db.mongodb import photos_collection
                docs = photos_collection.find(
                    {"user_id": user_id, "image_embedding": {"$exists": True}},
                    {"_id": 0, "image_embedding": 1},
                )
                arr: list[np.ndarray] = []
                for d in docs:
                    v = d.get("image_embedding")
                    if v is None:
                        continue
                    arr.append(np.array(v, dtype=np.float64))
                if arr:
                    db_embeds = np.stack(arr, axis=0)
            except Exception:
                db_embeds = None

        for i, path in enumerate(paths, start=1):
            file_md5: Optional[str] = None
            if remove_duplicates:
                # Exact duplicate detection using MD5 hash
                file_md5 = md5_file(path)
                if file_md5 in self.duplicate_hashes:
                    os.remove(path)
                    removed_dups += 1
                    if progress:
                        progress({
                            "status": "duplicate",
                            "current": i,
                            "total": total,
                            "photo": path,
                            "message": "Exact duplicate (MD5)"
                        })
                    continue
                self.duplicate_hashes.add(file_md5)

            # Load image
            img = read_image(path)
            if img is None:
                skipped += 1
                continue

            faces = detect_faces(None, img)
            if not faces:
                skipped += 1
                continue

            # Best face + embending
            box = self._select_best_face(img, faces)

            try:
                emb = face_embed(img, box)
                emb = self._normalize(emb)
            except Exception:
                skipped += 1
                continue

            # Ram visual dedup
            if remove_duplicates:
                is_dup = False
                if self.image_embeddings:
                    try:
                        mat = np.stack(self.image_embeddings, axis=0)
                        if float(np.min(np.linalg.norm(mat - emb, axis=1))) < 0.15:
                            os.remove(path)
                            removed_dups += 1
                            is_dup = True
                            if progress:
                                progress({
                                    "status": "duplicate",
                                    "current": i,
                                    "total": total,
                                    "photo": path,
                                    "message": "Visual duplicate (RAM)"
                                })
                    except Exception:
                        # fallback to slower loop
                        for known_emb in self.image_embeddings:
                            if np.linalg.norm(known_emb - emb) < 0.15:
                                os.remove(path)
                                removed_dups += 1
                                is_dup = True
                                if progress:
                                    progress({
                                        "status": "duplicate",
                                        "current": i,
                                        "total": total,
                                        "photo": path,
                                        "message": "Visual duplicate (RAM)"
                                    })
                                break
                if is_dup:
                    continue

                # DB visual dedup (cross-run)
                if db_embeds is not None:
                    try:
                        if float(np.min(np.linalg.norm(db_embeds - emb, axis=1))) < 0.15:
                            os.remove(path)
                            removed_dups += 1
                            if progress:
                                progress({
                                    "status": "duplicate",
                                    "current": i,
                                    "total": total,
                                    "photo": path,
                                    "message": "Visual duplicate (DB)"
                                })
                            continue
                    except Exception:
                        pass

                self.image_embeddings.append(emb)

            if not sort_photos:
                if progress:
                    progress({
                        "status": "scanned",
                        "current": i,
                        "total": total,
                        "photo": path,
                        "message": "Scanned"
                    })
                continue

            # Match person + confidence
            match_details = self._match_person_details(emb, threshold=match_threshold)
            match = match_details["name"]
            conf = match_details.get("confidence", 0.0)
            if match:
                try:
                    match_confidences.append(float(conf))
                except Exception:
                    pass

            dest_dir = os.path.join(output_base, match) if match else unknown_folder
            os.makedirs(dest_dir, exist_ok=True)

            dest_path = os.path.join(dest_dir, os.path.basename(path))
            os.replace(path, dest_path)

            # DB persistence (optional)
            if user_id:
                from app.db.mongodb import photos_collection
                photos_collection.insert_one({
                    "user_id": user_id,
                    "path": dest_path,
                    "md5": file_md5,
                    "image_embedding": emb.tolist(),
                    "person": match,
                    "match_distance": match_details.get("distance"),
                    "match_confidence": conf,
                })

            if match:
                moved_known += 1
            else:
                moved_unknown += 1

            if progress:
                progress({
                    "status": "moved",
                    "current": i,
                    "total": total,
                    "photo": path,
                    "destination": dest_dir,
                    "person": match,
                    "match_distance": match_details.get("distance"),
                    "match_confidence": conf,
                    "message": f"Sorted to {match or 'unknown'}"
                })

        return {
            "processed": total,
            "known": moved_known,
            "unknown": moved_unknown,
            "skipped": skipped,
            "duplicates_removed": removed_dups,
            "avg_match_confidence": round(float(np.mean(match_confidences)), 1) if match_confidences else 0.0,
        }

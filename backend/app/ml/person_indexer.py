from pathlib import Path
from datetime import datetime
from typing import Dict, Optional, List
import os
import cv2
import numpy as np

from app.db.mongodb import photos_collection
from app.ml.face_recognition import list_images, read_image, detect_faces, face_embed, FaceSorter


def file_mtime(path: str) -> str:
    try:
        ts = os.path.getmtime(path)
        return datetime.fromtimestamp(ts).isoformat()
    except Exception:
        return datetime.now().isoformat()


class PersonIndexer:
    def __init__(self, sorter: Optional[FaceSorter] = None) -> None:
        self.sorter = sorter or FaceSorter()
        self.detector = self.sorter.detector

    def index_folder(self, user_id: str, folder: str, known_persons: Optional[Dict[str, str]] = None) -> Dict[str, int]:
        """
        Index photos to MongoDB, storing detected person names (best match), face features,
        date, location (None if unavailable), and link to the photo (path).
        """
        if known_persons:
            self.sorter.train_from_folders(known_persons)

        paths = list_images(folder)
        total = len(paths)
        inserted = skipped = 0

        for path in paths:
            img = read_image(path)
            if img is None:
                skipped += 1
                continue
            faces = detect_faces(self.detector, img)
            if not faces:
                skipped += 1
                continue

            emb = face_embed(img, faces[0])
            name = self.sorter._match_person(emb) or "Unknown"

            doc = {
                "photo_id": os.path.splitext(os.path.basename(path))[0],
                "user_id": user_id,
                "filename": os.path.basename(path),
                "path": str(Path(path).resolve()),
                "persons_detected": [name],
                "face_features": emb.tolist(),
                "metadata": {
                    "date_taken": file_mtime(path),
                    "location": None
                }
            }
            photos_collection.insert_one(doc)
            inserted += 1

        return {"processed": total, "inserted": inserted, "skipped": skipped}
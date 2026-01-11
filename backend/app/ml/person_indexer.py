from pathlib import Path
from datetime import datetime
from typing import Dict, Optional
import os
import uuid

from app.db.mongodb import photos_collection
from app.db.mongodb import persons_collection
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

    def index_folder(
        self,
        user_id: str,
        folder: str,
        known_persons: Optional[Dict[str, str]] = None
    ) -> Dict[str, int]:

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

            faces = detect_faces(None, img)
            if not faces:
                skipped += 1
                continue

            face_entries = []

            for box in faces:
                try:
                    emb = face_embed(img, box)
                except Exception:
                    continue

                name = self.sorter._match_person(emb)
                person_name = name if name else "Unknown"

                face_entries.append({
                    "person_name": person_name,
                    "person_id": None,  # supplemented with persons_collection
                    "embedding": emb.tolist()
                })

            if not face_entries:
                skipped += 1
                continue

            photo_doc = {
                "photo_id": str(uuid.uuid4()),
                "user_id": user_id,
                "filename": os.path.basename(path),
                "path": str(Path(path).resolve()),
                "faces": face_entries,
                "metadata": {
                    "date_taken": file_mtime(path),
                    "location": None
                }
            }

            photos_collection.insert_one(photo_doc)
            inserted += 1

            # updating persons_collection
            for face in face_entries:
                if face["person_name"] == "Unknown":
                    continue

                persons_collection.update_one(
                    {"user_id": user_id, "name": face["person_name"]},
                    {
                        "$setOnInsert": {
                            "person_id": str(uuid.uuid4()),
                            "folder_path": ""
                        },
                        "$inc": {"photos_count": 1}
                    },
                    upsert=True
                )

        return {
            "processed": total,
            "inserted": inserted,
            "skipped": skipped
        }

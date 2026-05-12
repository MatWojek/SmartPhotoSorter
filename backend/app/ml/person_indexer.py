from pathlib import Path
from datetime import datetime
from typing import Dict, Optional
from collections import Counter
import hashlib
import os
import uuid


from app.db.mongodb import photos_collection
from app.db.mongodb import persons_collection
from app.ml.face_attributes import extract_eye_color, extract_hair_color
from app.ml.face_recognition import (
    list_images, 
    read_image, 
    detect_faces, 
    face_embed, 
    FaceSorter,
)


def file_mtime(path: str) -> str:
    try:
        ts = os.path.getmtime(path)
        return datetime.fromtimestamp(ts).isoformat()
    except Exception:
        return datetime.now().isoformat()


HAIR_COLORS = {"black", "brown", "blond", "red", "gray"}
EYE_COLORS = {"blue", "green", "brown", "hazel", "dark"}

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

        hair_votes: Dict[str, list[str]] = {}
        eye_votes: Dict[str, list[str]] = {}

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

                match = self.sorter._match_person_details(emb)
                name = match.get("name")
                person_name = name if name else "Unknown"
                match_confidence = match.get("confidence", 0.0)
                match_distance = match.get("distance")

                # hair and eye color extraction
                if person_name != "Unknown":
                    hair = extract_hair_color(img, box)
                    eye = extract_eye_color(img, box)

                    if hair in HAIR_COLORS:
                        hair_votes.setdefault(person_name, []).append(hair)

                    if eye in EYE_COLORS:
                        eye_votes.setdefault(person_name, []).append(eye)

                face_entries.append({
                    "person_name": person_name,
                    "person_id": None,  
                    "embedding": emb.tolist(),
                    "match_confidence": match_confidence,
                    "match_distance": match_distance,
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
            
        for person_name in set(hair_votes) | set(eye_votes):
            update: dict[str, str] = {}

            if person_name in hair_votes and hair_votes[person_name]:
                most_common_hair, _ = Counter(hair_votes[person_name]).most_common(1)[0]
                update["hair_color"] = most_common_hair

            if person_name in eye_votes and eye_votes[person_name]:
                most_common_eye, _ = Counter(eye_votes[person_name]).most_common(1)[0]
                update["eye_color"] = most_common_eye

            if update:
                persons_collection.update_one(
                    {"user_id": user_id, "name": person_name},
                    {"$set": update},
                    upsert=True,
                )

        return {
            "processed": total,
            "inserted": inserted,
            "skipped": skipped
        }

import uuid
from pathlib import Path
import shutil
from datetime import datetime
from typing import List, Dict, Optional, Any
from typing_extensions import TypedDict
import mimetypes
from datetime import datetime
import os
import hashlib

from fastapi import UploadFile

from app.config import STORAGE_ROOT
"""
Photo service operations. Collections are imported inside methods to allow
tests to monkeypatch `app.db.mongodb` without stale references.
"""

UPLOAD_DIR = STORAGE_ROOT/"user_uploads"


def _md5_file(path: str) -> str:
    h = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()

class PhotoSaveResult(TypedDict):
    photo_id: str
    filename: Optional[str]
    path: Optional[str]


class PhotoService:
    """
    Service layer for photo operations:
    - saving uploaded files
    - fetching photo document
    - searching by detected person
    """

    @staticmethod
    def save_photo(user_id: str, file: UploadFile) -> PhotoSaveResult:
        """
        Save an uploaded photo for a specific user.

        Writes the file to `STORAGE_ROOT/user_uploads/{user_id}/original`,
        computes its MD5, and ensures no duplicates exist for the same user
        based on `(user_id, md5)`.

        Parameters:
        - user_id: The ID of the user uploading the photo
        - file: The FastAPI `UploadFile`

        Returns:
        - PhotoSaveResult with `photo_id`, `filename`, `path`
        """
        # Import at call time so tests can monkeypatch
        from app.db.mongodb import photos_collection

        user_folder = UPLOAD_DIR / user_id / "original"
        user_folder.mkdir(parents=True, exist_ok=True)

        file_id = str(uuid.uuid4())

        # safe filename handling
        filename = getattr(file, "filename", None)
        if filename and "." in filename:
            ext = filename.rsplit(".", 1)[1]
            if not ext:
                ext = ""
        else:
            content_type = getattr(file, "content_type", "") or ""
            guessed = mimetypes.guess_extension(content_type) or ".bin"
            ext = guessed.lstrip(".")

        save_path = user_folder / f"{file_id}.{ext}" if ext else user_folder / file_id

        # write uploaded file to disk (UploadFile.file is a file-like object)
        with open(save_path, "wb") as f:
            shutil.copyfileobj(file.file, f)

        # metadata demo (replace with real extraction if needed)
        metadata = {
            "date_taken": str(datetime.now().date()),
            "location": "Unknown"
        }

        file_md5 = _md5_file(str(save_path))
        # If a photo with the same MD5 already exists for this user, reuse it
        existing = photos_collection.find_one({"user_id": user_id, "md5": file_md5})
        if existing:
            # Optionally update filename/path/metadata to latest
            photos_collection.update_one(
                {"user_id": user_id, "md5": file_md5},
                {"$set": {"filename": filename, "path": str(save_path), "metadata": metadata}}
            )
            return {
                "photo_id": existing.get("photo_id", file_id),
                "filename": filename,
                "path": str(save_path)
            }

        # Persist as a new document including md5 to avoid duplicates
        photos_collection.insert_one({
            "photo_id": file_id,
            "user_id": user_id,
            "filename": filename,
            "path": str(save_path),
            "metadata": metadata,
            "md5": file_md5,
        })
        return {"photo_id": file_id, "filename": filename, "path": str(save_path)}

    @staticmethod
    def get_photo_doc(user_id: str, photo_id: str) -> Optional[dict]:
        """
        Return MongoDB document for given user/photo or None if not found.
        """
        from app.db.mongodb import photos_collection
        return photos_collection.find_one({"photo_id": photo_id, "user_id": user_id})

    @staticmethod
    def search_person(user_id: str, person_name: str) -> List[Dict[str, Any]]:
        """Search photos belonging to `user_id` that match `person_name`.

        Matches on `persons_detected` or `faces.person_name` fields.
        Returns a simplified list of photo records.
        """
        from app.db.mongodb import photos_collection
        q = {
            "user_id": user_id,
            "$or": [
                {"persons_detected": {"$regex": person_name, "$options": "i"}},
                {"faces.person_name": {"$regex": person_name, "$options": "i"}}
            ]
        }
        photos = list(photos_collection.find(q, {"_id": 0, "photo_id": 1, 
                                                 "filename": 1, 
                                                 "path": 1, 
                                                 "metadata": 1
                                                }))
        def normalize(p):
            md = p.get("metadata") or {}
            return {
                "photo_id": p.get("photo_id"),
                "filename": p.get("filename"),
                "path": p.get("path"),
                "date_taken": md.get("date_taken"),
                "location": md.get("location"),
            }
        return [normalize(p) for p in photos]

    @staticmethod
    def delete_photo(user_id: str, photo_id: str) -> dict:
        """Delete a single photo for a user from disk and DB by `photo_id`."""
        from app.db.mongodb import photos_collection
        doc = photos_collection.find_one({"user_id": user_id, "photo_id": photo_id})
        if not doc:
            return {"status": "not_found"}
        path = doc.get("path")
        if path:
            p = Path(path)
            try:
                if p.exists():
                    p.unlink()
            except Exception:
                pass
        photos_collection.delete_one({"user_id": user_id, "photo_id": photo_id})
        return {"status": "ok"}
    
    @staticmethod
    def update_photo_path(
            user_id: str,
            old_path: str, 
            new_path: str, 
            person_name: Optional[str] = None
        ) -> None:
        """
        Update the stored path (and MD5) of a photo, avoiding duplicates.

        If a document exists for `(user_id, path=old_path)`, update it.
        Otherwise, if a document exists for `(user_id, md5(new_path))`, update its path.
        No upsert that could create duplicate documents.
        """
        from app.db.mongodb import photos_collection
        file_md5 = _md5_file(new_path)
        update: Dict[str, Any] = {"$set": {"path": new_path, "md5": file_md5}}
        if person_name:
            update["$addToSet"] = {"persons_detected": person_name}
        res = photos_collection.update_one({"user_id": user_id, "path": old_path}, update)
        if not res.matched_count:
            photos_collection.update_one({"user_id": user_id, "md5": file_md5}, update)

    @staticmethod
    def insert_local_photo(user_id: str, src_path: str, dest_path: str, note: Optional[str] = None) -> dict:
        from app.db.mongodb import photos_collection
        """Insert a locally processed photo for a user, deduplicating by MD5.

        Returns `{status: 'ok', photo_id}` on insert, or `{status: 'exists', photo_id}` if duplicate.
        """
        file_id = str(uuid.uuid4())
        md = {"date_taken": str(datetime.now().date()), "location": "Unknown", "note": note}
        file_md5 = _md5_file(dest_path)
        existing = photos_collection.find_one({"user_id": user_id, "md5": file_md5})
        if existing:
            # ensure latest path/metadata
            photos_collection.update_one({"user_id": user_id, "md5": file_md5}, {"$set": {"path": dest_path, "metadata": md}})
            return {"status": "exists", "photo_id": existing.get("photo_id")}
        doc = {
            "photo_id": file_id,
            "user_id": user_id,
            "filename": Path(dest_path).name,
            "path": dest_path,
            "metadata": md,
            "md5": file_md5,
        }
        photos_collection.insert_one(doc)
        return {"status": "ok", "photo_id": file_id}
    
    @staticmethod
    def reassign_photo(user_id: str, photo_id: str, person_name: str) -> dict:
        """Move a photo to a person's folder and tag it with that person.

        Also increments the person's `photos_count` and ensures folder exists.
        Returns `{status: 'ok', path}` if moved.
        """
        from app.db.mongodb import photos_collection, persons_collection
        doc = photos_collection.find_one({"user_id": user_id, "photo_id": photo_id})
        if not doc or not doc.get("path"): return {"status": "not_found"}
        src = Path(doc["path"])
        person = persons_collection.find_one({"user_id": user_id, "name": person_name})
        base = STORAGE_ROOT / "persons" / user_id / person_name
        base.mkdir(parents=True, exist_ok=True)
        dest = base / src.name
        try:
            os.replace(src, dest)
        except Exception:
            return {"status": "move_failed"}
        photos_collection.update_one(
            {"user_id": user_id, "photo_id": photo_id},
            {
                "$set": {"path": str(dest)},
                "$addToSet": {"persons_detected": person_name}
            }
        )
        persons_collection.update_one(
            {"user_id": user_id, "name": person_name},
            {"$setOnInsert": {"path": str(base)}, "$inc": {"photos_count": 1}},
            upsert=True
        )
        return {"status": "ok", "path": str(dest)}
    
    @staticmethod
    def delete_batch(user_id: str, photo_ids: list[str]) -> dict:
        """Delete multiple photos by `photo_ids` for a user. Returns count deleted."""
        from app.db.mongodb import photos_collection

        deleted = 0
        for pid in photo_ids:
            doc = photos_collection.find_one({"user_id": user_id, "photo_id": pid})
            if doc:
                p = Path(doc.get("path") or "")
                try:
                    if p.exists(): p.unlink()
                except Exception: pass
                photos_collection.delete_one({"user_id": user_id, "photo_id": pid})
                deleted += 1
        return {"status": "ok", "deleted": deleted}
import uuid
from pathlib import Path
import shutil
from datetime import datetime
from typing import List, Dict, Optional
from typing_extensions import TypedDict
import mimetypes

from fastapi import UploadFile

from app.db.mongodb import photos_collection

UPLOAD_DIR = Path("app/storage/user_uploads")


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
        Save uploaded file to disk and insert metadata into MongoDB.

        :param user_id: id of the uploading user
        :param file: FastAPI UploadFile
        :return: dict with created `photo_id` and optional `filename` and `path`
        """
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

        # persist document
        photos_collection.insert_one({
            "photo_id": file_id,
            "user_id": user_id,
            "filename": filename,
            "path": str(save_path) if save_path is not None else None,
            # "persons_detected": persons,  # add when detection implemented
            "metadata": metadata
        })

        return {
            "photo_id": file_id,
            "filename": filename,
            "path": str(save_path)
        }

    @staticmethod
    def get_photo_doc(user_id: str, photo_id: str) -> Optional[dict]:
        """
        Return MongoDB document for given user/photo or None if not found.
        """
        return photos_collection.find_one({"photo_id": photo_id, "user_id": user_id})

    @staticmethod
    def search_person(user_id: str, person_name: str) -> List[Dict[str, str]]:
        """
        Search photos for a person name (case-insensitive regex on `persons_detected`).
        Returns list of dicts with `photo_id` and `filename`.
        """
        photos = list(photos_collection.find({
            "user_id": user_id,
            "persons_detected": {"$regex": person_name, "$options": "i"}
        }))
        return [{"photo_id": p["photo_id"], "filename": p["filename"]} for p in photos]
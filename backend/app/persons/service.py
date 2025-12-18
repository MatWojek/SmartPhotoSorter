from pathlib import Path
import uuid
from app.db.mongodb import persons_collection
from app.photos.service import UPLOAD_DIR

class PersonService:
    """
    Manage person folders and records:
    - create a person entry (folder on disk + mongodb doc)
    """

    @staticmethod
    def create_person(user_id: str, person_name: str) -> dict:
        person_id = str(uuid.uuid4())

        # create folder under user uploads: /app/storage/user_uploads/<user_id>/<person_name>/
        person_folder = UPLOAD_DIR / user_id / person_name
        person_folder.mkdir(parents=True, exist_ok=True)

        doc = {
            "person_id": person_id,
            "user_id": user_id,
            "name": person_name,
            "folder_path": str(person_folder),
            "photos_count": 0
        }
        persons_collection.insert_one(doc)
        return {"status": "ok", "person_id": person_id, "folder_path": str(person_folder)}

    @staticmethod
    def list_persons(user_id: str) -> list[dict]:
        docs = list(persons_collection.find({"user_id": user_id}))
        # normalize output
        return [
            {
                "person_id": d.get("person_id"),
                "name": d.get("name"),
                "folder_path": d.get("folder_path"),
                "photos_count": d.get("photos_count", 0)
            } for d in docs
        ]
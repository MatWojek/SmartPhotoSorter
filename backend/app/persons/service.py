import shutil
from pathlib import Path
from app.db.mongodb import persons_collection

from app.config import STORAGE_ROOT

BASE_STORAGE = STORAGE_ROOT/"persons"


class PersonService:
    """Operations on person collections for a given user.

    Handles creating, listing and deleting person folders and records.
    """

    @staticmethod
    def create_person(user_id: str, name: str):
        """Create a person collection folder and DB record for `user_id`."""
        path = BASE_STORAGE / user_id / name
        path.mkdir(parents=True, exist_ok=True)

        doc = {
            "user_id": user_id,
            "name": name,
            "path": str(path)
        }
        persons_collection.insert_one(doc)
        return {"status": "created", "name": name}

    @staticmethod
    def list_persons(user_id: str):
        """List all person records belonging to `user_id`."""
        return list(persons_collection.find(
            {"user_id": user_id},
            {"_id": 0}
        ))

    @staticmethod
    def delete_person_folder(user_id: str, person_name: str):
        """Delete a person's folder on disk and remove the DB record."""
        person = persons_collection.find_one({
            "user_id": user_id,
            "name": person_name
        })

        if not person:
            return {"status": "not_found"}

        folder_path = person.get("path") or person.get("folder_path")
        if not folder_path:
            persons_collection.delete_one({"_id": person["_id"]})
            return {"status": "no_folder", "person": person_name}

        folder = Path(folder_path)
        if folder.exists():
            shutil.rmtree(folder)

        persons_collection.delete_one({"_id": person["_id"]})

        return {
            "status": "deleted",
            "person": person_name
        }
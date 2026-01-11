import shutil
from pathlib import Path
from app.db.mongodb import persons_collection

from app.config import STORAGE_ROOT

BASE_STORAGE = STORAGE_ROOT/"persons"


class PersonService:

    @staticmethod
    def create_person(user_id: str, name: str):
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
        return list(persons_collection.find(
            {"user_id": user_id},
            {"_id": 0}
        ))

    @staticmethod
    def delete_person_folder(user_id: str, person_name: str):
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
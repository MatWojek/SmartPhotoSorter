import shutil
from pathlib import Path
from app.db.mongodb import persons_collection

from app.config import STORAGE_ROOT

BASE_STORAGE = STORAGE_ROOT/"persons"


class PersonService:
    """
    Operations on person collections for a given user.

    Handles creating, listing and deleting person folders and records.
    """

    @staticmethod
    def create_person(
        user_id: str,
        name: str,
        eye_color: str | None = None,
        hair_color: str | None = None,
        eye_color_confidence: float | None = None, 
        hair_color_confidence: float | None = None, 
    ):
        """
        Create a person collection folder and DB record for `user_id`.

        Optional attributes like eye and hair color are stored on the person
        document so that the UI can later filter people by these traits.
        """
        path = BASE_STORAGE / user_id / name
        path.mkdir(parents=True, exist_ok=True)

        doc: dict[str, object] = {
            "user_id": user_id,
            "name": name,
            "path": str(path),
        }

        if eye_color is not None:
            doc["eye_color"] = eye_color
        if eye_color_confidence is not None:
            doc["eye_color_confidence"] = eye_color_confidence

        if hair_color is not None:
            doc["hair_color"] = hair_color
        if hair_color_confidence is not None:
            doc["hair_color_confidence"] = hair_color_confidence

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
    def update_person_attributes(
        user_id: str,
        name: str,
        eye_color: str | None = None,
        hair_color: str | None = None,
        eye_color_confidence: float | None = None, 
        hair_color_confidence: float | None = None,
    ):
        """
        Update optional attributes (eye/hair color) for an existing person.

        This keeps the document shape backwards compatible while allowing
        the UI (or tools) to enrich people with additional traits that can
        be used for filtering.
        """
        update: dict[str, object] = {}

        if eye_color is not None:
            update["eye_color"] = eye_color
        if eye_color_confidence is not None:
            update["eye_color_confidence"] = eye_color_confidence

        if hair_color is not None:
            update["hair_color"] = hair_color
        if hair_color_confidence is not None:
            update["hair_color_confidence"] = hair_color_confidence

        if not update:
            return {"status": "no_changes"}

        res = persons_collection.update_one(
            {"user_id": user_id, "name": name},
            {"$set": update},
        )
        if not getattr(res, "matched_count", 0):
            return {"status": "not_found"}

        return {
            "status": "updated", 
            "user_id": user_id, 
            "name": name, **update
        }

    @staticmethod
    def delete_person_folder(
        user_id: str, 
        person_name: str
    ):
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
    
    @staticmethod
    def filter_persons(user_id: str, filters):
        """Filter persons by nominal traits and minimal confidence."""
        query: dict[str, object] = {
            "user_id": user_id,
        }

        if getattr(filters, "eye_color", None):
            query["eye_color"] = filters.eye_color
        if getattr(filters, "hair_color", None):
            query["hair_color"] = filters.hair_color

        if getattr(filters, "min_eye_confidence", None) is not None:
            query["eye_color_confidence"] = {"$gte": filters.min_eye_confidence}
        if getattr(filters, "min_hair_confidence", None) is not None:
            query["hair_color_confidence"] = {"$gte": filters.min_hair_confidence}

        return list(persons_collection.find(query, {"_id": 0}))
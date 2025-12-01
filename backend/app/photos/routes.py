from fastapi import APIRouter, UploadFile, File, HTTPException
from fastapi.responses import FileResponse
from .service import save_photo
from app.db.mongodb import photos_collection
from pathlib import Path

router = APIRouter()

@router.post("/upload/{user_id}")
def upload(user_id: str, file: UploadFile = File(...)):
    return save_photo(user_id, file)

@router.get("/get/{user_id}/{photo_id}")
def get_photo(user_id: str, photo_id: str):
    photo = photos_collection.find_one({"photo_id": photo_id, "user_id": user_id})
    if not photo:
        raise HTTPException(status_code=404, detail="No photos found")
    
    path = Path(photo["path"])
    if not path.exists():
        raise HTTPException(status_code=404, detail="File does not exist")
    
    return FileResponse(path)

@router.get("/search/{user_id}/{person_name}")
def search_person(user_id: str, person_name: str):
    photos = list(photos_collection.find({
        "user_id": user_id,
        "persons_detected": {"$regex": person_name, "$options": "i"}
    }))
    return [{"photo_id": p["photo_id"], "filename": p["filename"]} for p in photos]

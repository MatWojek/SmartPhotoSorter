from fastapi import APIRouter, UploadFile, File, HTTPException
from fastapi.responses import FileResponse
from pathlib import Path
from typing import Optional, List
from pydantic import BaseModel

from .service import PhotoService, PhotoSaveResult

router = APIRouter(prefix="/photos", tags=["photos"])


class PhotoSearchItem(BaseModel):
    photo_id: str
    filename: Optional[str] = None
    path: Optional[str] = None
    date_taken: Optional[str] = None
    location: Optional[str] = None

class ReassignBody(BaseModel):
  person_name: str

class DeleteBatchBody(BaseModel):
  photo_ids: list[str]


@router.post("/upload/{user_id}")
def upload(user_id: str, file: UploadFile = File(...)) -> PhotoSaveResult:
    """Upload a photo for a specific user, deduplicated by MD5."""
    return PhotoService.save_photo(user_id, file)


@router.get("/get/{user_id}/{photo_id}")
def get_photo(user_id: str, photo_id: str) -> FileResponse:
    """Return the photo file for given `user_id` and `photo_id`."""
    photo = PhotoService.get_photo_doc(user_id, photo_id)
    if not photo:
        raise HTTPException(status_code=404, detail="No photo")

    path = Path(photo["path"])
    if not path.exists():
        raise HTTPException(status_code=404, detail="File missing")

    return FileResponse(path)


@router.get("/search/{user_id}/{person_name}", response_model=List[PhotoSearchItem])
def search_person(user_id: str, person_name: str):
    """List photos for `user_id` that match the person name."""
    return PhotoService.search_person(user_id, person_name)


@router.delete("/delete/{user_id}/{photo_id}")
def delete_photo(user_id: str, photo_id: str):
    """Delete a photo by id for a user."""
    return PhotoService.delete_photo(user_id, photo_id)

@router.post("/reassign/{user_id}/{photo_id}")
def reassign(user_id: str, photo_id: str, data: ReassignBody):
    """Move a photo into another collection and train the person model."""
    from app.ml.face_recognition import FaceSorter
    res = PhotoService.reassign_photo(user_id, photo_id, data.person_name)
    if not res.get("path"):
        raise HTTPException(status_code=404, detail="Photo not found or moved")
    sorter = FaceSorter()
    sorter.train_single(user_id, data.person_name, res["path"])
    return {"status": "ok"}

@router.post("/delete-batch/{user_id}")
def delete_batch(user_id: str, body: DeleteBatchBody):
    """Delete multiple photos by ids for a user."""
    return PhotoService.delete_batch(user_id, body.photo_ids)
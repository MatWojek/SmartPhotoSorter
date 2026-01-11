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
    return PhotoService.save_photo(user_id, file)


@router.get("/get/{user_id}/{photo_id}")
def get_photo(user_id: str, photo_id: str) -> FileResponse:
    photo = PhotoService.get_photo_doc(user_id, photo_id)
    if not photo:
        raise HTTPException(status_code=404, detail="No photo")

    path = Path(photo["path"])
    if not path.exists():
        raise HTTPException(status_code=404, detail="File missing")

    return FileResponse(path)


@router.get("/search/{user_id}/{person_name}", response_model=List[PhotoSearchItem])
def search_person(user_id: str, person_name: str):
    return PhotoService.search_person(user_id, person_name)


@router.delete("/delete/{user_id}/{photo_id}")
def delete_photo(user_id: str, photo_id: str):
    return PhotoService.delete_photo(user_id, photo_id)

@router.post("/reassign/{user_id}/{photo_id}")
def reassign(user_id: str, photo_id: str, data: ReassignBody):
    from app.ml.face_recognition import FaceSorter
    res = PhotoService.reassign_photo(user_id, photo_id, data.person_name)
    if not res.get("path"):
        raise HTTPException(status_code=404, detail="Photo not found or moved")
    sorter = FaceSorter()
    sorter.train_single(user_id, data.person_name, res["path"])
    return {"status": "ok"}

@router.post("/delete-batch/{user_id}")
def delete_batch(user_id: str, body: DeleteBatchBody):
    return PhotoService.delete_batch(user_id, body.photo_ids)
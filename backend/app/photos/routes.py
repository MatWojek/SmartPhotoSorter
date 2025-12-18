from fastapi import APIRouter, UploadFile, File, HTTPException
from fastapi.responses import FileResponse
from .service import PhotoService, PhotoSaveResult
from pathlib import Path

router = APIRouter()


@router.post("/upload/{user_id}")
def upload(user_id: str, file: UploadFile = File(...)) -> PhotoSaveResult:
    """
    Upload a photo.

    Request body: multipart form with file under `file`.
    Response: dict with `photo_id`, `filename` and `path`.
    """
    return PhotoService.save_photo(user_id, file)


@router.get("/get/{user_id}/{photo_id}")
def get_photo(user_id: str, photo_id: str) -> FileResponse:
    """
    Return the file for a given user and photo id.

    - 404 when photo document not found
    - 404 when file path does not exist on disk
    """
    photo = PhotoService.get_photo_doc(user_id, photo_id)
    if not photo:
        raise HTTPException(status_code=404, detail="No photos found")

    path = Path(photo["path"])
    if not path.exists():
        raise HTTPException(status_code=404, detail="File does not exist")

    return FileResponse(path)


@router.get("/search/{user_id}/{person_name}")
def search_person(user_id: str, person_name: str) -> list[dict[str, str]]:
    """
    Search photos by detected person name (case-insensitive).

    Returns a list of objects with `photo_id` and `filename`.
    """
    return PhotoService.search_person(user_id, person_name)
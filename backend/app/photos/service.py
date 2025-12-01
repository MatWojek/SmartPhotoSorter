import uuid
from pathlib import Path
import shutil
from datetime import datetime
from app.ml import face_recognition
from app.db.mongodb import photos_collection

UPLOAD_DIR = Path("app/storage/user_uploads")

def save_photo(user_id: str, file) -> dict:
    user_folder = UPLOAD_DIR / user_id / "original"
    user_folder.mkdir(parents=True, exist_ok=True)

    file_id = str(uuid.uuid4())
    ext = file.filename.split(".")[-1]
    save_path = user_folder / f"{file_id}.{ext}"

    with open(save_path, "wb") as f:
        shutil.copyfileobj(file.file, f)

    # Face detection
    # persons = detect_faces(str(save_path))

    # metadata demo
    metadata = {
        "date_taken": str(datetime.now().date()),
        "location": "Unknown"
    }

    # save to MongoDB
    photos_collection.insert_one({
        "photo_id": file_id,
        "user_id": user_id,
        "filename": file.filename,
        "path": str(save_path),
        "persons_detected": persons,
        "metadata": metadata
    })

    return {"photo_id": file_id, "persons_detected": persons}

#!/usr/bin/env python3
import sys
from pathlib import Path

# Ensure we can import the FastAPI app
BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_DIR))

from fastapi.testclient import TestClient
from app.main import app
import app.photos.service as photos_service


class FakePhotosCollection:
    def __init__(self):
        self._docs = {}

    def insert_one(self, doc):
        self._docs[(doc["user_id"], doc["photo_id"])] = doc
        return type("InsertOneResult", (), {"inserted_id": doc["photo_id"]})

    def find_one(self, query):
        key = (query.get("user_id"), query.get("photo_id"))
        return self._docs.get(key)


def run():
    # Patch DB dependency to avoid needing a real Mongo connection
    from app.db.mongodb import photos_collection
    photos_collection = FakePhotosCollection()
    client = TestClient(app)

    user_id = "test_user"
    file_name = "hello.txt"
    file_bytes = b"Hello SmartPhotoSorter!"

    # Upload
    files = {"file": (file_name, file_bytes, "text/plain")}
    r = client.post(f"/photos/upload/{user_id}", files=files)
    assert r.status_code == 200, f"Upload failed: {r.status_code} {r.text}"
    data = r.json()
    photo_id = data.get("photo_id")
    assert photo_id, "No photo_id returned"

    # Get back
    r2 = client.get(f"/photos/get/{user_id}/{photo_id}")
    assert r2.status_code == 200, f"Get failed: {r2.status_code} {r2.text}"

    print("test_upload_runner: PASS")


if __name__ == "__main__":
    run()

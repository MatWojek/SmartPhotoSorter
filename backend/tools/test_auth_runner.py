#!/usr/bin/env python3
import sys
from pathlib import Path
import uuid

# Ensure we can import the FastAPI app
BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_DIR))

from fastapi.testclient import TestClient
from app.main import app
import app.auth.service as auth_service


class FakeUsersCollection:
    def __init__(self):
        self._docs = {}

    def find_one(self, query):
        # supports {"email": x} or {"username": y} or $or
        if "$or" in query:
            for sub in query["$or"]:
                res = self.find_one(sub)
                if res:
                    return res
            return None
        for k, v in query.items():
            for doc in self._docs.values():
                if doc.get(k) == v:
                    return doc
        return None

    def insert_one(self, doc):
        self._docs[doc["user_id"]] = doc
        return type("InsertOneResult", (), {"inserted_id": doc["user_id"]})

    def create_index(self, *args, **kwargs):
        return None


def run():
    # Patch DB dependency to avoid needing a real Mongo connection
    
    auth_service.users_collection = FakeUsersCollection()
    client = TestClient(app)

    # Unique user data per run
    uid = uuid.uuid4().hex[:8]
    payload = {
        "first_name": "John",
        "last_name": "Doe",
        "username": f"user_{uid}",
        "email": f"user_{uid}@example.com",
        "password": "Password123!"
    }

    # Register
    r = client.post("/auth/register", json=payload)
    assert r.status_code == 200, f"Register failed: {r.status_code} {r.text}"
    reg = r.json()
    assert reg.get("status") == "ok" and isinstance(reg.get("user_id"), str)

    # Login (email)
    r2 = client.post("/auth/login", json={"email": payload["email"], "password": payload["password"]})
    assert r2.status_code == 200, f"Login failed: {r2.status_code} {r2.text}"
    token = r2.json().get("access_token")
    assert token and isinstance(token, str)

    print("test_auth_runner: PASS")


if __name__ == "__main__":
    run()

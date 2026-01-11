import uuid
from fastapi import HTTPException, status
from app.auth.hashing import hash_password, verify_password
from app.auth.jwt_handler import create_access_token
from pymongo.errors import DuplicateKeyError

class AuthService:
    """
    Service layer for user registration and authentication.
    Keeps business logic out of FastAPI route handlers.
    """

    @staticmethod
    def register(first_name: str, last_name: str, username: str, email: str, password: str) -> dict[str, str]:
        """
        Register a new user.

        :param email: user's email (must be unique)
        :param password: plain-text password (will be hashed)
        :return: dict with registration status and generated user_id
        :raises HTTPException: with 400 if user already exists
        """
        # Normalize username to avoid duplicates 
        username = username.lower()

        # Normalize email to avoid case-sensitive duplicates
        email = email.strip().lower()

        # Import collections at call time so tests can monkeypatch them
        from app.db.mongodb import users_collection

        if users_collection.find_one({"email": email}) or users_collection.find_one({"username": username}):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User already exists"
            )

        user_id = str(uuid.uuid4())
        try:
            users_collection.insert_one({
                "user_id": user_id,
                "first_name": first_name, 
                "last_name": last_name, 
                "username": username,
                "email": email,
                "password_hash": hash_password(password)
            })
        except DuplicateKeyError:
            # In case of race conditions, enforce unique email at DB level
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User already exists"
            )
        return {"status": "ok", "user_id": user_id}

    @staticmethod
    def login(email: str, password: str) -> dict[str, str]:
        """
        Authenticate a user by email or nickname and return a JWT token.
        """
        # Import collections at call time so tests can monkeypatch them
        from app.db.mongodb import users_collection
        # Normalize login input (email or username)
        login = email.strip().lower()

        user = users_collection.find_one({
            "$or": [{"email": login}, {"username": login}]
        })
        if not user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Incorrect email/username or password"
            )

        if not verify_password(password, user["password_hash"]):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Incorrect email/username or password"
            )

        token = create_access_token(user["user_id"])
        return {"access_token": token, "user_id": user["user_id"]}

    @staticmethod
    def delete_account(user_id: str) -> dict[str, str]:
        """
        Permanently delete a user's account, database records and files.

        - Removes user document from users collection
        - Removes all user's persons and photos from DB
        - Deletes storage folders under STORAGE_ROOT for this user
        """
        from pathlib import Path
        from app.db.mongodb import users_collection, persons_collection, photos_collection
        from app.config import STORAGE_ROOT
        import shutil

        # Delete DB records
        users_collection.delete_one({"user_id": user_id})
        persons_collection.delete_many({"user_id": user_id})
        photos_collection.delete_many({"user_id": user_id})

        # Delete storage folders
        base = Path(STORAGE_ROOT)
        user_uploads = base / "user_uploads" / user_id
        persons_dir = base / "persons" / user_id
        errors_dir = base / "errors" / user_id
        for p in (user_uploads, persons_dir, errors_dir):
            try:
                if p.exists():
                    shutil.rmtree(p)
            except Exception:
                pass

        return {"status": "ok"}
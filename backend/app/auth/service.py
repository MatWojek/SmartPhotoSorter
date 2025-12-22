import uuid
from fastapi import HTTPException, status
from app.db.mongodb import users_collection
from app.utils import security
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
                "password_hash": security.hash_password(password)
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
        # Normalize email the same way as during registration
        login = email.strip().lower()

        user = users_collection.find_one({
            "$or": [{"email": email}, {"nickname": login}]
        })
        if not user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Incorrect email/username or password"
            )

        if not security.verify_password(password, user["password_hash"]):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Incorrect email/username or password"
            )

        token = security.create_jwt_token(user["user_id"])
        return {"access_token": token}
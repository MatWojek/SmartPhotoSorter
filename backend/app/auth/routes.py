from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.db.mongodb import users_collection
from app.utils import security
import uuid

router = APIRouter()

class RegisterUser(BaseModel):
    email: str
    password: str

class LoginUser(BaseModel):
    email: str
    password: str

@router.post("/register")
def register(data: RegisterUser) -> dict:
    if users_collection.find_one({"email": data.email}):
        raise HTTPException(400, "User exist")

    user_id = str(uuid.uuid4())

    users_collection.insert_one({
        "user_id": user_id,
        "email": data.email,
        "password_hash": security.hash_password(data.password)
    })

    return {"status": "ok", "user_id": user_id}

@router.post("/login")
def login(data: LoginUser) -> dict:
    user = users_collection.find_one({"email": data.email})
    if not user:
        raise HTTPException(400, "Incorrect email or password")

    if not security.verify_password(data.password, user["password_hash"]):
        raise HTTPException(400, "Incorrect email or password")

    token = security.create_jwt_token(user["user_id"])

    return {"access_token": token}

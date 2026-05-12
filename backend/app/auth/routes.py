from fastapi import APIRouter
from pydantic import BaseModel
from app.auth.service import AuthService

router = APIRouter()

class RegisterUser(BaseModel):
    first_name: str
    last_name: str
    username: str
    email: str
    password: str

class LoginUser(BaseModel):
    email: str
    password: str

@router.post("/register")
def register(data: RegisterUser) -> dict[str, str]:
    """
    Register a new user.

    Accepts JSON with `email` or `username` and `password`. Returns a dictionary
    with registration `status` and generated `user_id`.

    Responses:
    - 200: {"status": "ok", "user_id": "<uuid>"}
    - 400: if a user with the provided email or username already exists
    """
    return AuthService.register(data.first_name, data.last_name, data.username, data.email, data.password)

@router.post("/login")
def login(data: LoginUser) -> dict[str, str]:
    """
    Authenticate user and return access token.

    Accepts JSON with `email` and `password`. On success returns:
    - 200: {"access_token": "<jwt-token>"}
    - 400: if credentials are invalid
    """
    return AuthService.login(data.email, data.password)

@router.delete("/delete/{user_id}")
def delete_account(user_id: str) -> dict[str, str]:
    """
    Permanently delete the account and all associated data for the given user_id.
    """
    return AuthService.delete_account(user_id)

from fastapi import APIRouter
from pydantic import BaseModel
from app.auth.service import AuthService
from app.persons.service import PersonService

router = APIRouter()

class RegisterUser(BaseModel):
    email: str
    password: str

class CreatePerson(BaseModel):
    user_id: str
    name: str

@router.post("/register")
def register_user(data: RegisterUser):
    """
    Façade route to register user (calls AuthService.register).
    """
    return AuthService.register(data.email, data.password)

@router.post("/person")
def create_person(data: CreatePerson):
    """
    Façade route to create person folder + db record (calls PersonService.create_person).
    """
    return PersonService.create_person(data.user_id, data.name)
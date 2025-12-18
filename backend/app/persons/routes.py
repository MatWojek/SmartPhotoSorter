from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.persons.service import PersonService

router = APIRouter()

class CreatePerson(BaseModel):
    user_id: str
    name: str

@router.post("/create")
def create_person(data: CreatePerson):
    """
    Create a person folder and record for a user.
    """
    if not data.user_id or not data.name:
        raise HTTPException(status_code=400, detail="user_id and name required")
    return PersonService.create_person(data.user_id, data.name)

@router.get("/list/{user_id}")
def list_persons(user_id: str):
    return PersonService.list_persons(user_id)
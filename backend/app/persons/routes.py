from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel
from app.persons.service import PersonService

router = APIRouter()


class CreatePerson(BaseModel):
    user_id: str
    name: str
    eye_color: str | None = None
    eye_color_confidence: float | None = None
    hair_color: str | None = None
    hair_color_confidence: float | None = None


class UpdatePersonAttributes(BaseModel):
    eye_color: str | None = None
    eye_color_confidence: float | None = None
    hair_color: str | None = None
    hair_color_confidence: float | None = None


class PersonFilter(BaseModel):
    eye_color: str | None = None
    hair_color: str | None = None
    min_eye_confidence: float | None = None
    min_hair_confidence: float | None = None


@router.post("/create")
def create_person(data: CreatePerson):
    """Create a person folder and record for a user."""
    if not data.user_id or not data.name:
        raise HTTPException(status_code=400, detail="user_id and name required")
    return PersonService.create_person(
        data.user_id,
        data.name,
        data.eye_color,
        data.hair_color,
        data.eye_color_confidence,
        data.hair_color_confidence,
    )

@router.get("/list/{user_id}")
def list_persons(user_id: str):
    return PersonService.list_persons(user_id)


@router.put("/attributes/{user_id}/{person_name}")
def update_person_attributes(user_id: str, person_name: str, data: UpdatePersonAttributes):
    """Update eye/hair color information stored for a given person."""
    return PersonService.update_person_attributes(
        user_id,
        person_name,
        data.eye_color,
        data.hair_color,
        data.eye_color_confidence,
        data.hair_color_confidence,
    )

@router.delete("/delete-folder/{user_id}/{person_name}")
def delete_person_folder(user_id: str, person_name: str):
    """
    Deletes:
    - person folder from disk
    - person document from DB
    """
    return PersonService.delete_person_folder(user_id, person_name)

@router.get("/filter/{user_id}")
def filter_persons(user_id: str, filters: PersonFilter):
    """
    Example:
    /persons/filter/123?hair_color=brown&eye_color=blue
    """
    return PersonService.filter_persons(user_id, filters)
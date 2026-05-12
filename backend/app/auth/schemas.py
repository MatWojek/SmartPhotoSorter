"""
Pydantic schemas for authentication endpoints.

Defines request/response models for register/login/delete operations.
Use these in route handlers to validate payloads and document the API.
"""

from pydantic import BaseModel, EmailStr, Field

class RegisterUser(BaseModel):
	"""Payload for user registration."""
	first_name: str = Field(min_length=1)
	last_name: str = Field(min_length=1)
	username: str = Field(min_length=3)
	email: EmailStr
	password: str = Field(min_length=6)

class RegisterResponse(BaseModel):
	"""Response returned after successful registration."""
	status: str
	user_id: str

class LoginUser(BaseModel):
	"""Payload for user login using email or username + password."""
	email: str
	password: str

class LoginResponse(BaseModel):
	"""Response returned after successful login."""
	access_token: str
	user_id: str

class DeleteAccountResponse(BaseModel):
	"""Response for account deletion."""
	status: str


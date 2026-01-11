"""Password hashing utilities for the authentication module.

Provides functions to hash and verify passwords using `passlib`'s `CryptContext`.
Prefer these helpers over direct library calls to keep a single, consistent
configuration across the application.
"""

from passlib.context import CryptContext

_pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str) -> str:
	"""Hash a plaintext password using bcrypt.

	Parameters:
	- password: plaintext password

	Returns:
	- A bcrypt hash string suitable for storage.
	"""
	return _pwd_context.hash(password)

def verify_password(password: str, hashed: str) -> bool:
	"""Verify a plaintext password against a bcrypt hash.

	Parameters:
	- password: plaintext password provided by the user
	- hashed: stored bcrypt hash

	Returns:
	- True if the password matches the hash, False otherwise.
	"""
	return _pwd_context.verify(password, hashed)


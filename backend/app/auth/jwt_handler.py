"""JWT helpers for issuing and verifying access tokens.

Wraps `python-jose` to create and decode JWTs with HS256. Tokens include the
subject (`sub` = user_id) and expiration (`exp`).
"""

import os
from datetime import datetime, timedelta, timezone
from typing import Optional, Tuple
from jose import jwt, JWTError

SECRET_KEY = os.getenv("JWT_SECRET", "secret-key")
ALGORITHM = "HS256"

def create_access_token(user_id: str, expires_delta: Optional[timedelta] = None) -> str:
	"""Create a signed JWT for the given `user_id`.

	Parameters:
	- user_id: unique identifier of the user
	- expires_delta: optional TTL (defaults to 24h)

	Returns:
	- Encoded JWT as string.
	"""
	expire = datetime.now(timezone.utc) + (expires_delta or timedelta(days=1))
	payload = {"sub": user_id, "exp": expire}
	return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

def decode_token(token: str) -> Tuple[Optional[str], Optional[dict]]:
	"""Decode and validate a JWT.

	Parameters:
	- token: encoded JWT

	Returns:
	- (user_id, claims) tuple if valid; otherwise (None, None).
	"""
	try:
		claims = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
		return claims.get("sub"), claims
	except JWTError:
		return None, None


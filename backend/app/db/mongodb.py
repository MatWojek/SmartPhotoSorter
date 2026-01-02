import os
from pymongo import MongoClient


def _resolve_mongo_client() -> MongoClient:
	"""
	Resolve a working MongoDB connection by trying environment-provided URL first,
	then sensible local fallbacks (Docker Compose mapping to 27018, then no-auth localhost).
	"""
	candidates = []
	env_url = os.getenv("MONGO_URL")
	if env_url:
		candidates.append(env_url)

	# Docker Compose default mapping: container 27017 -> host 27018
	candidates.extend([
		"mongodb://root:example123@127.0.0.1:27018/?authSource=admin",
		"mongodb://root:example123@localhost:27018/?authSource=admin",
		# Fallbacks without auth (for local dev setups)
		"mongodb://127.0.0.1:27017",
		"mongodb://localhost:27017",
	])

	last_error: Exception | None = None
	for url in candidates:
		try:
			client = MongoClient(url, serverSelectionTimeoutMS=2000)
			# Verify credentials/connection
			client.admin.command("ping")
			# print only minimal info to avoid leaking creds
			print(f"[mongodb] Connected: {client.HOST}:{client.PORT}")
			return client
		except Exception as e:
			last_error = e
			continue

	# If all attempts fail, raise last error for visibility
	if last_error:
		raise last_error
	# Fallback (should not reach here)
	return MongoClient()


client = _resolve_mongo_client()
db = client["face_sorter_db"]

users_collection = db["users"]
photos_collection = db["photos"]
persons_collection = db["persons"]

# Ensure unique emails to prevent duplicates
try:
	users_collection.create_index("email", unique=True)
except Exception:
	# Index creation will be skipped if permissions are insufficient or already created
	pass

# Ensure unique username to prevent duplicates
try:
	users_collection.create_index("username", unique=True)
except Exception:
	pass
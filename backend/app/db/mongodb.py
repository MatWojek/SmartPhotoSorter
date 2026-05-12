import os
from pymongo import MongoClient


def _resolve_mongo_client() -> MongoClient:
	"""
	Resolve a MongoDB client by trying environment-provided URL first,
	then sensible local fallbacks.

	Important:
	- Do NOT hard-fail during module import if Mongo is temporarily unavailable.
	- Let operations fail with a clear runtime error instead of crashing the API.
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

	for url in candidates:
		try:
			# Lazy client: do not ping here to avoid crashing API on startup.
			client = MongoClient(url, serverSelectionTimeoutMS=2000)
			return client
		except Exception:
			continue

	# Last-resort fallback
	return MongoClient(serverSelectionTimeoutMS=2000)


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

try:
	photos_collection.create_index([("user_id", 1), ("md5", 1)], unique=True)
except Exception:
	pass


import os
from pymongo import MongoClient

MONGO_URL = os.getenv("MONGO_URL", "mongodb://root:example123@127.0.0.1:27017/?authSource=admin&authMechanism=SCRAM-SHA-256")

client = MongoClient(MONGO_URL)

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

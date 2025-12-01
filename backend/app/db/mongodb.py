import os
from pymongo import MongoClient

MONGO_URL = os.getenv("MONGO_URL", "mongodb://localhost:27017/")

client = MongoClient(MONGO_URL)

db = client["face_sorter_db"]

users_collection = db["users"]
photos_collection = db["photos"]
persons_collection = db["persons"]

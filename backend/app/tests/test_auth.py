from fastapi.testclient import TestClient
import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(BACKEND_DIR))

from app.main import app
import app.auth.service as auth_service

class FakeUsersCollection:
	def __init__(self):
		self._docs = {}
	def find_one(self, q):
		if "$or" in q:
			for cond in q["$or"]:
				for k, v in cond.items():
					for d in self._docs.values():
						if d.get(k) == v:
							return d
			return None
		for k, v in q.items():
			for d in self._docs.values():
				if d.get(k) == v:
					return d
		return None
	def insert_one(self, doc):
		self._docs[doc["user_id"]] = doc
		class R: inserted_id = doc["user_id"]
		return R()
	def delete_one(self, q):
		uid = q.get("user_id")
		if uid in self._docs:
			del self._docs[uid]

class FakePersonsCollection:
	def __init__(self): self._docs = []
	def delete_many(self, q):
		uid = q.get("user_id")
		self._docs = [d for d in self._docs if d.get("user_id") != uid]
	def find_one(self, q, proj=None):
		# minimal stub used by FaceSorter._get_trained_md5s
		for d in self._docs:
			ok = True
			for k, v in q.items():
				if d.get(k) != v: ok = False; break
			if ok: return d
		return None
	def find(self, q, proj=None):
		res = []
		for d in self._docs:
			ok = True
			for k, v in q.items():
				if d.get(k) != v: ok = False; break
			if ok:
				if proj:
					nd = {k: d.get(k) for k in proj.keys() if proj.get(k) == 1}
					res.append(nd)
				else:
					res.append(d)
		return res
	def update_one(self, filt, update, upsert=False):
		# Support $setOnInsert, $addToSet($each), $push($each,$slice), $set, $inc
		# Find matching doc
		target = None
		for d in self._docs:
			match = True
			for k, v in filt.items():
				if d.get(k) != v: match = False; break
			if match:
				target = d
				break
		if not target and upsert:
			target = dict(filt)
			soi = update.get("$setOnInsert") or {}
			target.update(soi)
			# initialize common fields
			if "embeddings" not in target: target["embeddings"] = []
			if "trained_files" not in target: target["trained_files"] = []
			self._docs.append(target)
		if not target:
			class R: matched_count = 0
			return R()
		# Apply $set
		if "$set" in update:
			target.update(update["$set"])
		# Apply $inc
		if "$inc" in update:
			for k, v in update["$inc"].items():
				target[k] = (target.get(k, 0) + v)
		# Apply $addToSet
		if "$addToSet" in update:
			for k, v in update["$addToSet"].items():
				arr = target.get(k) or []
				if isinstance(v, dict) and "$each" in v:
					for item in v["$each"]:
						if item not in arr:
							arr.append(item)
				else:
					if v not in arr:
						arr.append(v)
				target[k] = arr
		# Apply $push
		if "$push" in update:
			for k, v in update["$push"].items():
				arr = target.get(k) or []
				items = v.get("$each", []) if isinstance(v, dict) else [v]
				arr.extend(items)
				# handle $slice
				if isinstance(v, dict) and "$slice" in v:
					sl = v["$slice"]
					if isinstance(sl, int) and sl < 0:
						arr = arr[sl:]  # keep last |sl|
				target[k] = arr
		class R: matched_count = 1
		return R()

class FakePhotosCollection:
	def __init__(self): self._docs = []
	def find(self, q, proj=None):
		# Ignore visual duplicates
		return []
	def delete_many(self, q):
		uid = q.get("user_id")
		self._docs = [d for d in self._docs if d.get("user_id") != uid]
	def delete_one(self, q):
		# remove first matching
		for i, d in enumerate(self._docs):
			ok = True
			for k, v in q.items():
				if d.get(k) != v: ok = False; break
			if ok:
				self._docs.pop(i)
				return
	def find_one(self, q, proj=None):
		for d in self._docs:
			ok = True
			for k, v in q.items():
				if d.get(k) != v: ok = False; break
			if ok: return d
		return None
	def insert_one(self, doc):
		self._docs.append(doc)
		class R: inserted_id = doc.get("photo_id")
		return R()
	def update_one(self, filt, update, upsert=False):
		target = None
		for d in self._docs:
			match = True
			for k, v in filt.items():
				if d.get(k) != v: match = False; break
			if match:
				target = d
				break
		if not target and upsert:
			target = dict(filt)
			self._docs.append(target)
		if not target:
			class R: matched_count = 0
			return R()
		if "$set" in update:
			target.update(update["$set"])
		if "$addToSet" in update:
			for k, v in update["$addToSet"].items():
				arr = target.get(k) or []
				if v not in arr:
					arr.append(v)
				target[k] = arr
		class R: matched_count = 1
		return R()

def test_register_login_delete_account(monkeypatch, tmp_path):
	# Patch collections
	import app.db.mongodb as m
	m.users_collection = FakeUsersCollection()
	m.persons_collection = FakePersonsCollection()
	m.photos_collection = FakePhotosCollection()

	client = TestClient(app)
	payload = {
		"first_name": "Jan", "last_name": "Kowalski", "username": "janek",
		"email": "janek@example.com", "password": "sekret123"
	}
	r = client.post("/auth/register", json=payload)
	assert r.status_code == 200
	data = r.json()
	assert data.get("status") == "ok" and isinstance(data.get("user_id"), str)

	# login
	r2 = client.post("/auth/login", json={"email": payload["email"], "password": payload["password"]})
	assert r2.status_code == 200
	d2 = r2.json()
	assert "access_token" in d2 and d2.get("user_id")

	# delete account
	uid = d2["user_id"]
	r3 = client.delete(f"/auth/delete/{uid}")
	assert r3.status_code == 200
	assert r3.json().get("status") == "ok"


import sys, shutil
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(BACKEND_DIR))

from app.photos.service import PhotoService
import app.db.mongodb as m

class FakePhotosCollection:

	def __init__(self): self._docs = []

	def find_one(self, q, *args, **kwargs):
		for d in self._docs:
			ok = True
			for k, v in q.items():
				if d.get(k) != v: ok = False; break
			if ok: return d
		return None
	
	def insert_one(self, doc): self._docs.append(doc)

	def update_one(self, q, update, upsert=False):
		doc = self.find_one(q)
		if doc:
			if "$set" in update:
				doc.update(update["$set"])
				
		elif upsert:
			newdoc = {**q}
			if "$set" in update: newdoc.update(update["$set"])
			if "$setOnInsert" in update: newdoc.update(update["$setOnInsert"])
			self._docs.append(newdoc)

def test_insert_local_dedup(tmp_path, monkeypatch):
	m.photos_collection = FakePhotosCollection()
	user_id = "u1"
	p = tmp_path / "photo.png"
	p.write_bytes(b"hello")
	dest = tmp_path / "dest_photo.png"
	shutil.copy2(p, dest)

	r1 = PhotoService.insert_local_photo(user_id, str(p), str(dest))
	assert r1["status"] == "ok"
	r2 = PhotoService.insert_local_photo(user_id, str(p), str(dest))
	assert r2["status"] == "exists"


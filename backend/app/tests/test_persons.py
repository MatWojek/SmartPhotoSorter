import sys, shutil
from pathlib import Path
from fastapi.testclient import TestClient

BACKEND_DIR = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(BACKEND_DIR))

from app.main import app
import app.db.mongodb as m
import app.persons.service as persons_service

class FakePersonsCollection:

    def __init__(self): self._docs = []

    def insert_one(self, doc):
        # Add simple _id
        if "_id" not in doc:
            newdoc = dict(doc)
            newdoc["_id"] = len(self._docs) + 1
            self._docs.append(newdoc)
        else:
            self._docs.append(doc)

    def find(self, q, proj=None):
        return [d for d in self._docs if d.get('user_id') == q.get('user_id')]
    
    def find_one(self, q):
        for d in self._docs:
            if d.get('user_id') == q.get('user_id') and d.get('name') == q.get('name'):
                return d
        return None
    
    def delete_one(self, q):
        """Supports both deletion by (user_id,name) and deletion by _id."""
        uid = q.get('user_id')
        name = q.get('name')
        _doc_id = q.get('_id')
        for i, d in enumerate(self._docs):
            if _doc_id is not None:
                if d.get('_id') == _doc_id:
                    self._docs.pop(i); return
            elif uid is not None and name is not None:
                if d.get('user_id') == uid and d.get('name') == name:
                    self._docs.pop(i); return


def test_create_list_delete_person_folder(monkeypatch, tmp_path):
    
    m.persons_collection = FakePersonsCollection()
    persons_service.persons_collection = m.persons_collection
    client = TestClient(app)
    user_id = 'u1'
    name = 'Anna'

    r1 = client.post('/services/person', json={'user_id': user_id, 'name': name})
    assert r1.status_code == 200
    r2 = client.get(f'/persons/list/{user_id}')
    assert r2.status_code == 200
    items = r2.json()
    assert any(p.get('name') == name for p in items)

    r3 = client.delete(f'/persons/delete-folder/{user_id}/{name}')
    assert r3.status_code == 200

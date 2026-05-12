import sys, shutil, os
from pathlib import Path
import numpy as np
import cv2

BACKEND_DIR = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(BACKEND_DIR))

from app.ml import face_recognition as fr
import app.db.mongodb as m
from app.tests.test_auth import FakePersonsCollection, FakePhotosCollection


def test_persistence_sort(tmp_path):
    # Użyj prawdziwego zbioru danych ze storage/database jako źródła obrazów,
    # ale pracuj w osobnym sandboxie, żeby nie modyfikować oryginalnych plików.
    db_root = BACKEND_DIR / "app" / "storage" / "database"
    train_root = db_root / "train"
    test_root = db_root / "test1"

    assert train_root.is_dir()
    assert test_root.is_dir()

    # Sandbox na potrzeby testu
    sandbox = BACKEND_DIR / "app" / "storage" / "test_persist_sandbox"
    train_a = sandbox / "train_leo"
    unsorted = sandbox / "unsorted"
    output = sandbox / "sorted"
    unknown = sandbox / "unknown"

    if sandbox.exists():
        shutil.rmtree(sandbox)
    for d in (train_a, unsorted, output, unknown):
        d.mkdir(parents=True, exist_ok=True)

    # Skopiuj kilka obrazów treningowych jednej osoby (pierwszy katalog z train)
    person_dirs = [p for p in train_root.iterdir() if p.is_dir()]
    assert person_dirs
    first_person = person_dirs[0]
    train_files = sorted([p for p in first_person.iterdir() if p.is_file()])[:5]
    assert train_files
    for f in train_files:
        shutil.copy2(f, train_a / f.name)

    # Skopiuj kilka obrazów testowych do folderu unsorted
    unsorted_files = sorted([p for p in test_root.iterdir() if p.is_file()])[:8]
    assert unsorted_files
    for f in unsorted_files:
        shutil.copy2(f, unsorted / f.name)

    # Mock: lekkie odczytywanie obrazów oraz bardzo prosty detektor/embedding,
    # żeby nie korzystać z ciężkiego face_recognition/dlib w testach.
    def fake_read_image(path: str):
        img = cv2.imread(path)
        return img
    fr.read_image = fake_read_image

    def fake_detect_faces(detector, img):
        h, w = img.shape[:2]
        return [(int(w * 0.25), int(h * 0.25), int(w * 0.5), int(h * 0.5))]
    fr.detect_faces = fake_detect_faces

    def fake_face_embed(img, box):
        # embedding = średnia jasność kanałów (stały 128‑wymiarowy wektor)
        val = float(img.mean() / 255.0)
        return np.full((128,), val, dtype=np.float64)
    fr.face_embed = fake_face_embed

    # Zastąp kolekcje MongoDB wersjami in‑memory, żeby nie wymagać prawdziwej bazy
    m.persons_collection = FakePersonsCollection()
    m.photos_collection = FakePhotosCollection()

    user_id = "user1"
    sorter1 = fr.FaceSorter()
    sorter1.train_from_folders({first_person.name: str(train_a)}, user_id=user_id)

    # Nowy sorter – ładuje embeddings z "bazy" i sortuje bez ponownego treningu
    sorter2 = fr.FaceSorter()
    sorter2.load_from_db(user_id)
    initial_count = len([p for p in unsorted.iterdir() if p.is_file()])
    summary = sorter2.sort_folder(str(unsorted), str(output), str(unknown), user_id=user_id)

    # Wszystkie pliki z unsorted powinny zostać przetworzone
    assert summary["processed"] == initial_count
    # Po sortowaniu folder unsorted powinien być pusty (pliki przeniesione lub usunięte jako duplikaty)
    assert not any(unsorted.iterdir())
    # Co najmniej część zdjęć powinna trafić do jakiegokolwiek katalogu wynikowego
    total_moved = 0
    for root, _, files in os.walk(output):
        total_moved += len(files)
    total_moved += len(list(unknown.iterdir()))
    assert total_moved > 0
    # Sprawdź, że embeddings osoby zostały załadowane z "bazy" do drugiego sortera
    assert sorter2.person_embeds

    # auto-train: without new files, it doesn't increase embeddings
    # (we check that repeated ensure doesn't add)
    before = len(sorter2.person_embeds.get("Anna", []))
    sorter2.ensure_trained_for_user(user_id)
    after = len(sorter2.person_embeds.get("Anna", []))
    assert after == before
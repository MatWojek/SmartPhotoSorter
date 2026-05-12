# SmartPhotoSorter

SmartPhotoSorter is an AI-based photo organization tool designed to automatically categorize and sort images into meaningful folders.
Instead of spending hours manually moving files, you provide the application with a reference dataset of already sorted photos.
Using this dataset, the AI learns to recognize categories (such as family, pets, holidays, landscapes) and then applies this knowledge to classify and sort new, unsorted images.

This project aims to make photo management faster, smarter, and more intuitive.
It can be adapted for personal use (organizing family albums), professional workflows (photographers sorting thousands of shots), or specialized domains (medical imaging, research datasets, etc.).

## Features

- **Automatic Sorting** – Automatically organizes unsorted photos into per-person / per-collection folders.
- **Face-Based Classification** – Uses face embeddings to recognize and group people across photos.
- **Per-Person Attributes** – Extracts eye and hair color (with confidence scores) to support rich filtering.
- 🔍 **Advanced Filtering** – Filter persons by eye color, hair color and minimal confidence, and filter photos by selected people/traits in the Flutter UI.
- ⚡ **Batch Processing** – Sorts entire folders of unsorted images at once.
- **Web API + Flutter UI** – FastAPI backend with a cross‑platform Flutter frontend.

## How It Works

1. **Training / Indexing Phase**  
   - Provide a set of training folders (e.g. one folder per person).  
   - The ML module builds face embeddings for each person and stores them in MongoDB.  
   - During indexing, photos are scanned, faces detected and matched to known persons; person documents are enriched with attributes (eye_color, hair_color, confidence).

2. **Sorting Phase**  
   - Provide a folder with unsorted images.  
   - The AI analyzes each photo, matches faces to persons and routes images into the appropriate target folders (or an “unknown” folder when not sure).

3. **Exploration & Filtering (Frontend)**  
   - The Flutter app lists persons, their photos and basic traits.  
   - A filter panel lets you limit photos by person, eye color, hair color and attribute combinations.

## Project Structure

```text
SmartPhotoSorter/
├── backend/
│   ├── app/
│   │   ├── main.py
│   │   ├── config.py
│   │   ├── auth/
│   │   ├── db/
│   │   ├── ml/
│   │   ├── persons/
│   │   ├── photos/
│   │   ├── routes/
│   │   ├── storage/
│   │   ├── tests/
│   │   └── utils/
│   ├── requirements.txt
│   ├── Dockerfile
│   ├── run_dev.sh
│   └── run_dev.bat
├── frontend_flutter/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/
│   │   ├── features/
│   │   ├── models/
│   │   ├── services/
│   │   └── utils/
│   ├── pubspec.yaml
│   └── …
├── app/
│   └── storage/
│       └── user_uploads/
├── docs/
│   ├── api_endpoints.md
│   ├── database_structure.md
│   └── flow_user_upload.md
├── docker-compose.yml
└── README.md
```

## Backend (FastAPI) – key modules

- backend/app/main.py – FastAPI application factory, CORS setup, router registration (auth, photos, persons, ml, services).
- backend/app/config.py – Global configuration, storage root (e.g. smartphotosorterdb).
- backend/app/db/mongodb.py – MongoDB connection and collections (persons, photos, etc.).
- backend/app/auth/routes.py – Auth endpoints (register/login).
- backend/app/auth/service.py – Business logic for authentication and password hashing.
- backend/app/photos/routes.py – REST endpoints for photo upload, listing and download.
- backend/app/photos/service.py – File handling, persistence of photo metadata and links to persons.
- backend/app/persons/service.py – Person CRUD, attribute updates, filtering by eye/hair color and confidence.
- backend/app/persons/routes.py – Persons API:
  - create person (with optional eye_color / hair_color and confidence),
  - update person attributes,
  - list persons,
  - delete person folder,
  - filter persons by traits (POST /persons/filter/{user_id}).
- backend/app/ml/face_recognition.py – Face detection, face embeddings, training from folders, duplicate detection.
- backend/app/ml/person_indexer.py – Walks folders, indexes photos into MongoDB, links photos to persons and aggregates per‑person statistics (including attributes).
- backend/app/ml/extract_metadata.py – Extracts EXIF / metadata like dates and basic info.
- backend/app/ml/routes.py – ML endpoints:
  - start local sorting,
  - start DB indexing,
  - SSE / WebSocket progress reporting.
- backend/app/storage/ – Storage adapters (e.g. local filesystem, database storage).
- backend/app/tests/ – Backend test suite (auth, upload, face recognition, persons, persistence).
- backend/app/utils/security.py – Security helpers, JWT / password utils and related functions.

---

## Frontend (Flutter) – key modules

- frontend_flutter/lib/main.dart – Flutter entry point, app widget, theme controller setup.
- frontend_flutter/lib/core/ – App-wide theming, constants and helpers (e.g. light/dark themes, theme controller).
- frontend_flutter/lib/features/home/home_page.dart – Main screen with person/photo views and actions (training, sorting, upload).
- frontend_flutter/lib/features/home/widgets/photo_grid.dart – Grid view of photos with multi‑selection and actions.
- frontend_flutter/lib/features/home/widgets/photo_list.dart – List view of photos with actions (open, reveal, download, move to collection, delete).
- frontend_flutter/lib/features/home/widgets/training_folders_dialog.dart – Dialog for defining training folders per person (manual training data configuration).
- frontend_flutter/lib/features/navigation/filter_bottom_sheet.dart – Bottom sheet with filters by persons, eye color and hair color (uses backend attributes).
- frontend_flutter/lib/features/navigation/person_search.dart – Search dialog for selecting persons.
- frontend_flutter/lib/models/person.dart – Person model (name, photos_count, eye_color, hair_color).
- frontend_flutter/lib/services/api_service.dart – HTTP client for backend API (auth, persons, photos, ML routes).
- frontend_flutter/lib/utils/ – Utility helpers (e.g. file actions, dialogs, formatting).

---

## 🔧 Installation

### Backend 

```bash
git clone https://github.com/MatWojek/SmartPhotoSorter.git
cd SmartPhotoSorter
cd backend
python3 -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```
### Frontend (Flutter)

```bash
cd frontend_flutter
flutter pub get
flutter run -d linux    # Windows: flutter run -d windows
```

---

## Usage

### Backend (development, auto-reload)

```bash
cd backend
./run_dev.sh         # Linux / macOS
# or
./run_dev.bat           # Windows
```

### Frontend

```bash
cd frontend_flutter
flutter pub get
flutter run -d linux    # Windows: flutter run -d windows
```

Notes:
- Registration/login requires the backend to be reachable at `API_BASE_URL`.
- When logged out on desktop (Linux/macOS/Windows), "local sorting" can run without HTTP by spawning a local Python process (see `backend/tools/local_sort_cli.py`).

### Docker (optional)

```bash 
docker compose build backend
docker compose up mongo backend

```

If you get "address already in use", override host ports:

```bash
BACKEND_PORT=8001 MONGO_PORT=27019 docker compose up mongo backend
```

---

## Requirements

 - Python 3.11+ (recommended 3.11.11)
 - MongoDB
 - FastAPI + Uvicorn
 - face_recognition (dlib‑based)
 - OpenCV
 - Flutter 3+ (for the frontend)

---

## 📜 License

This project is licensed under the MIT License.

---

## 👨‍💻 Author 

Created by an enthusiastic programmer with a passion for AI-powered content.
The author is MatWojas.

---

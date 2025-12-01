# SmartPhotoSorter

SmartPhotoSorter is an AI-based photo organization tool designed to automatically categorize and sort images into meaningful folders.
Instead of spending hours manually moving files, you provide the application with a reference dataset of already sorted photos.
Using this dataset, the AI learns to recognize categories (such as family, pets, holidays, landscapes) and then applies this knowledge to classify and sort new, unsorted images.

This project aims to make photo management faster, smarter, and more intuitive.
It can be adapted for personal use (organizing family albums), professional workflows (photographers sorting thousands of shots), or specialized domains (medical imaging, research datasets, etc.).

## ✨ Features

- 📂 **Automatic Sorting** – No more manual dragging and dropping. Let the AI handle it.
- 🧠 **AI-Powered Classification** – Learns from a dataset of pre-sorted images.
- 📸 **Custom Categories** – Works with any type of photo categories (e.g., holidays, family, pets).
- ⚡ **Batch Processing** – Sorts entire folders of unsorted images at once.

## 🚀 How It Works

1. **Training Phase**  
   - Provide a dataset of images that are already sorted into category folders.  
   - The AI learns to recognize patterns and visual features for each category.  

2. **Sorting Phase**
3. 
   - Provide a folder with unsorted images.  
   - The AI analyzes each photo and moves it into the most suitable category folder.  

## 📂 Project Structure

```
SmartPhotoSorter/
├── backend/
    ├── app/
    │   ├── main.py
    │   ├── config.py
    │   ├── db/
    │   │   ├── mongodb.py
    │   │   └── collections.py
    │   ├── auth/
    │   │   ├── __init__.py
    │   │   ├── routes.py
    │   │   ├── schemas.py
    │   │   ├── service.py
    │   │   ├── hashing.py
    │   │   └── jwt_handler.py
    │   ├── users/
    │   │   ├── __init__.py
    │   │   ├── repository.py
    │   │   └── schemas.py
    │   ├── photos/
    │   │   ├── __init__.py
    │   │   ├── routes.py
    │   │   ├── service.py
    │   │   ├── schemas.py
    │   │   └── file_manager.py
    │   ├── ml/
    │   │   ├── __init__.py
    │   │   ├── face_recognition.py
    │   │   ├── extract_metadata.py
    │   │   └── person_indexer.py
    │   ├── storage/
    │   │   └── user_uploads/
    │   ├── utils/
    │   │   ├── __init__.py
    │   │   ├── file_utils.py
    │   │   ├── security.py
    │   │   └── photo_filters.py
    │   └── routes/
    │       ├── __init__.py
    │       └── index.py
    ├── requirements.txt
    ├── Dockerfile
    └── .env
├── frontend_flutter/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── api/
│   │   │   ├── auth_api.dart
│   │   │   ├── photo_api.dart
│   │   │
│   │   ├── screens/
│   │   │   ├── login_screen.dart
│   │   │   ├── register_screen.dart
│   │   │   ├── person_gallery_screen.dart
│   │   │   ├── photo_view_screen.dart
│   │   │   ├── loading_screen.dart
│   │   │
│   │   ├── widgets/
│   │   │   ├── photo_tile.dart
│   │   │   ├── person_tile.dart
│   │
│   ├── assets/
│   │   ├── icons/
│   │   ├── mock_photos/
│   │
│   ├── pubspec.yaml
│
├── docker-compose.yml
├── README.md
└── docs/
    ├── api_endpoints.md
    ├── database_structure.md
    ├── flow_user_upload.md
```

## 🔧 Installation

```bash
git clone https://github.com/yourusername/SmartPhotoSorter.git
cd SmartPhotoSorter
pip install -r requirements.txt
```

## ▶️ Usage

python src/train.py --data ./data/training
python src/sort.py --input ./data/unsorted --output ./data/

## 📌 Requirements

- Python 3.9+
- TensorFlow / PyTorch (depending on chosen framework)
- OpenCV
- scikit-learn
- numpy

## 🌍 Roadmap

- Add GUI for easy drag-and-drop sorting
- Support for cloud storage (Google Drive, OneDrive, etc.)
- Improve accuracy with transfer learning models (ResNet, EfficientNet)
- Add duplicate photo detection

## 📜 License

This project is licensed under the MIT License.

## 👨‍💻 Author 

Created by an enthusiastic programmer with a passion for AI-powered content.
The author is MatWojas.


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
│── data/
│ ├── training/ # Pre-sorted training images
│ │ ├── cats/
│ │ ├── dogs/
│ │ ├── holidays/
│ │ └── ...
│ └── unsorted/ # Folder with unsorted images
│
│── src/ # Source code
│── models/ # Trained models
│── README.md
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


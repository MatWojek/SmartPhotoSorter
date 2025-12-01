# import hashlib
# from importlib.resources import files
# import os 
# import shutil 
# import numpy

# import cv2
# import face_recognition 
# from sklearn.cluster import DBSCAN

# # TODO: Define constants
# # - Set constants for image formats to process (e.g., .jpg, .png).
# # - Define thresholds for face recognition and clustering.

# # TODO: Load training data
# # - Traverse the training folders.
# # - Extract face encodings for each person from images in their respective folders.
# # - Store the encodings and associate them with the folder/person name.

# # TODO: Train the model
# # - Use clustering (e.g., DBSCAN) or other machine learning techniques to group similar faces.
# # - Save the trained model or encodings for later use.

# # TODO: Define sorting logic
# # - Traverse the folder containing unsorted images.
# # - Detect faces in each image.
# # - Compare detected faces with the trained encodings to identify the person.
# # - Move the image to the corresponding folder based on the identified person.

# # TODO: Handle unknown faces
# # - If a face does not match any known encoding, move it to an "unknown" folder.
# # - Optionally, allow the user to manually classify unknown faces.

# # TODO: Optimize performance
# # - Use batch processing for face detection and encoding.
# # - Skip images without detectable faces to save time.

# # TODO: Error handling
# # - Handle cases where no faces are detected in an image.
# # - Handle corrupted or unsupported image files gracefully.

# # TODO: Logging
# # - Log the sorting process, including the number of images processed, skipped, or moved.
# # - Log errors for debugging purposes.

# # TODO: Testing
# # - Test the module with a variety of datasets to ensure accuracy.
# # - Validate that images are sorted into the correct folders.

# # TODO: Integrate with GUI
# # - Add a button in the GUI to trigger the face sorting process.
# # - Display progress and results in the GUI.

# # TODO: Optional enhancements
# # - Add support for incremental learning (e.g., adding new faces to the model without retraining from scratch).
# # - Allow the user to adjust clustering parameters via the GUI.
# # - Add a preview feature to show detected faces before sorting.

# class FaceSorter: 

#     def __init__(self, training_folder: str, unknown_folder: str, output_folder: str) -> None: 
#         self.training_folder = training_folder 
#         self.unknown_folder = unknown_folder 
#         self.output_folder = output_folder 
#         self.known_encodings = [] 
#         self.known_names = [] 

#         # Load training data 
#         self._load_training_data(
#             self.training_folder, 
#             self.known_encodings, 
#             self.knoSwn_names
#         )

#         # Define clustering model
#         self.clustering_model = DBSCAN(eps=0.5, min_samples=2)
#         if self.known_encodings:
#             self.clustering_model.fit(self.known_encodings)
#             self.known_clusters = self.clustering_model.labels_
#         else:
#             self.known_clusters = []

#     def _load_training_data(self, folder: str, encodings: list, names: list) -> None:
#         """ Load training data from the specified folder. """
#         for person_name in os.listdir(folder):
#             person_folder = os.path.join(folder, person_name)
#             if not os.path.isdir(person_folder):
#                 continue
#             for image_name in os.listdir(person_folder):
#                 image_path = os.path.join(person_folder, image_name)
#                 image = face_recognition.load_image_file(image_path)
#                 face_encs = face_recognition.face_encodings(image)
#                 if face_encs:
#                     encodings.append(face_encs[0])
#                     names.append(person_name)

#     def sort_faces(self, unsorted_folder: str) -> None:
#         """ Sort faces in the unsorted folder. """
#         for image_name in os.listdir(unsorted_folder):
#             image_path = os.path.join(unsorted_folder, image_name)
#             image = face_recognition.load_image_file(image_path)
#             face_locations = face_recognition.face_locations(image)
#             face_encs = face_recognition.face_encodings(image, face_locations)
#             if not face_encs:
#                 continue
#             matched = False
#             for face_enc in face_encs:
#                 distances = face_recognition.face_distance(self.known_encodings, face_enc)
#                 if len(distances) == 0:
#                     continue
#                 best_match_index = numpy.argmin(distances)
#                 if distances[best_match_index] < 0.6:
#                     person_name = self.known_names[best_match_index]
#                     output_person_folder = os.path.join(self.output_folder, person_name)
#                     os.makedirs(output_person_folder, exist_ok=True)
#                     shutil.move(image_path, os.path.join(output_person_folder, image_name))
#                     matched = True
#                     break
#             if not matched:
#                 os.makedirs(self.unknown_folder, exist_ok=True)
#                 shutil.move(image_path, os.path.join(self.unknown_folder, image_name))
#                 file_hash = hashlib.md5(image_path.encode()).hexdigest()
#                 unknown_image_path = os.path.join(self.unknown_folder, f"{file_hash}_{image_name}")
#                 shutil.move(image_path, unknown_image_path)
#                 files[file_hash] = unknown_image_path

#     def get_unknown_faces(self) -> list:
#         """ Return the list of unknown face image paths. """
#         return [files[file_hash] for file_hash in files]

#     def classify_unknown_faces(self) -> None:
#         """ Classify unknown faces using the clustering model. """
#         for file_hash, image_path in files.items():
#             image = face_recognition.load_image_file(image_path)
#             face_locations = face_recognition.face_locations(image)
#             face_encs = face_recognition.face_encodings(image, face_locations)
#             if not face_encs:
#                 continue
#             for face_enc in face_encs:
#                 cluster_label = self.clustering_model.fit_predict([face_enc])
#                 if cluster_label[0] != -1:
#                     person_name = self.known_names[cluster_label[0]]
#                     output_person_folder = os.path.join(self.output_folder, person_name)
#                     os.makedirs(output_person_folder, exist_ok=True)
#                     shutil.move(image_path, os.path.join(output_person_folder, os.path.basename(image_path)))
#                     del files[file_hash]
#                     break
#                 else:
#                     continue

#     def clear_unknown_faces(self) -> None:
#         """ Clear the unknown faces folder. """
#         for file_hash, image_path in files.items():
#             try:
#                 os.remove(image_path)
#             except Exception as e:
#                 print(f"Error deleting unknown face image {image_path}: {e}")
#         files.clear()

#     def retrain_model(self) -> None:
#         """ Retrain the clustering model with updated known encodings. """
#         self.clustering_model.fit(self.known_encodings)
#         self.known_clusters = self.clustering_model.labels_

#     def add_new_face(self, person_name: str, image_path: str) -> None:
#         """ Add a new face to the training data and retrain the model. """
#         image = face_recognition.load_image_file(image_path)
#         face_encs = face_recognition.face_encodings(image)
#         if face_encs:
#             self.known_encodings.append(face_encs[0])
#             self.known_names.append(person_name)
#             self.retrain_model()
#         else:
#             print(f"No face found in the image {image_path}.")
#             return

#     def save_model(self, model_path: str) -> None:
#         """ Save the trained model to a file. """
#         import pickle
#         with open(model_path, 'wb') as f:
#             pickle.dump({
#                 'known_encodings': self.known_encodings,
#                 'known_names': self.known_names,
#                 'clustering_model': self.clustering_model
#             }, f)

#     def load_model(self, model_path: str) -> None:
#         """ Load the trained model from a file. """
#         import pickle
#         with open(model_path, 'rb') as f:
#             data = pickle.load(f)
#             self.known_encodings = data['known_encodings']
#             self.known_names = data['known_names']
#             self.clustering_model = data['clustering_model']
#             self.known_clusters = self.clustering_model.labels_

    
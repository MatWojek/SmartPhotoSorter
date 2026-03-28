import 'api_service.dart';

class ImageService {
  static String progressWsUrl(String taskId) =>
      ApiService.progressWsUrl(taskId);
  static Uri progressSseUri(String taskId) => ApiService.progressSseUri(taskId);

  static Future<Map<String, dynamic>> startSortLocal({
    required Map<String, String> trainingFolders,
    required String unsortedFolder,
    required String outputBase,
    required String unknownFolder,
  }) {
    return ApiService.startSortLocal(
      trainingFolders: trainingFolders,
      unsortedFolder: unsortedFolder,
      outputBase: outputBase,
      unknownFolder: unknownFolder,
    );
  }

  static Future<Map<String, dynamic>> startIndexDb({
    required String userId,
    required String folder,
    Map<String, String>? trainingFolders,
  }) {
    return ApiService.startIndexDb(
      userId: userId,
      folder: folder,
      trainingFolders: trainingFolders,
    );
  }

  static Future<List<Map<String, dynamic>>> searchPhotosByPerson(
    String userId,
    String personName,
  ) {
    return ApiService.searchPhotosByPerson(userId, personName);
  }

  static String photoUrl(String userId, String photoId) {
    return ApiService.photoUrl(userId, photoId);
  }

  static Future<bool> deletePhoto(String userId, String photoId) {
    return ApiService.deletePhoto(userId, photoId);
  }

  static Future<Map<String, dynamic>> deleteBatch(
    String userId,
    List<String> photoIds,
  ) {
    return ApiService.deleteBatch(userId, photoIds);
  }

  static Future<bool> reassignPhoto(
    String userId,
    String photoId,
    String personName,
  ) {
    return ApiService.reassignPhoto(userId, photoId, personName);
  }
}

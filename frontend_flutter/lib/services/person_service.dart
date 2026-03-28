import 'api_service.dart';

class PersonService {
  static Future<Map<String, dynamic>> createPerson(String userId, String name) {
    return ApiService.createPerson(userId, name);
  }

  static Future<List<dynamic>> listPersons(String userId) {
    return ApiService.listPersons(userId);
  }

  static Future<bool> deletePersonFolder(String userId, String personName) {
    return ApiService.deletePersonFolder(userId, personName);
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const _base = 'http://127.0.0.1:8000';

  static String progressWsUrl(String taskId) => 'ws://127.0.0.1:8000/ml/progress/$taskId';
  static Uri progressSseUri(String taskId) => Uri.parse('http://127.0.0.1:8000/ml/progress-sse/$taskId');

  static Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'first_name': firstName,
        'last_name': lastName,
        'username': username,
        'email': email,
        'password': password,
      }),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw Exception(body['detail'] ?? 'Registration failed');
    }
    return body;
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$_base/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> createPerson(String userId, String name) async {
    final res = await http.post(
      Uri.parse('$_base/services/person'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'name': name}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> listPersons(String userId) async {
    final res = await http.get(Uri.parse('$_base/persons/list/$userId'));
    return jsonDecode(res.body) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> startSortLocal({
    required Map<String, String> trainingFolders,
    required String unsortedFolder,
    required String outputBase,
    required String unknownFolder,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/ml/sort-local'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'training_folders': trainingFolders,
        'unsorted_folder': unsortedFolder,
        'output_base': outputBase,
        'unknown_folder': unknownFolder,
      }),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw Exception(body['detail'] ?? 'Sort-local failed');
    }
    return body;
  }

  static Future<Map<String, dynamic>> startIndexDb({
    required String userId,
    required String folder,
    Map<String, String>? trainingFolders,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/ml/index-db'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'folder': folder,
        'training_folders': trainingFolders,
      }),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw Exception(body['detail'] ?? 'Index-DB failed');
    }
    return body;
  }

  static Future<List<Map<String, dynamic>>> searchPhotosByPerson(String userId, String personName) async {
    final q = personName.trim();
    if (q.isEmpty) return [];
    try {
      final res = await http.get(Uri.parse('$_base/photos/search/$userId/$q'));
      if (res.statusCode >= 400) return [];
      final body = jsonDecode(res.body);
      return body is List ? body.cast<Map<String, dynamic>>() : [];
    } catch (_) { return []; }
  }

  static Future<bool> deletePhoto(String userId, String photoId) async {
    final res = await http.delete(Uri.parse('$_base/photos/delete/$userId/$photoId'));
    return res.statusCode < 400;
  }

  static Future<bool> deletePersonFolder(String userId, String personName) async {
    final res = await http.delete(Uri.parse('$_base/persons/delete-folder/$userId/$personName'));
    return res.statusCode < 400;
  }

  static Future<bool> reassignPhoto(String userId, String photoId, String personName) async {
    final res = await http.post(
      Uri.parse('$_base/photos/reassign/$userId/$photoId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'person_name': personName}),
    );
    return res.statusCode < 400;
  }

  static Future<Map<String, dynamic>> deleteBatch(String userId, List<String> photoIds) async {
    final res = await http.post(
      Uri.parse('$_base/photos/delete-batch/$userId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'photo_ids': photoIds}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static String photoUrl(String userId, String photoId) => '$_base/photos/get/$userId/$photoId';
} 
  
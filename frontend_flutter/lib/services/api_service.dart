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
}
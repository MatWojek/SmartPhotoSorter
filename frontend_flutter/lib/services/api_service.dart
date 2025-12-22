import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const _base = 'http://127.0.0.1:8000'; 

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
}
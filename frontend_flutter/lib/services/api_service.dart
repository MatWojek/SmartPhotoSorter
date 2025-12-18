import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const _base = 'http://127.0.0.1:8000'; // adjust if backend runs elsewhere

  static Future<Map<String, dynamic>> register(String email, String password) async {
    final res = await http.post(
      Uri.parse('$_base/services/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
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
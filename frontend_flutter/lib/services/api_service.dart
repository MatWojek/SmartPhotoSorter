import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseFromDefine = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static String? _token;

  static Uri get _baseUri {
    if (_baseFromDefine.trim().isNotEmpty) {
      return Uri.parse(_baseFromDefine.trim());
    }
    if (kIsWeb) {
      return Uri.parse('http://localhost:8000');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return Uri.parse('http://10.0.2.2:8000');
      default:
        return Uri.parse('http://127.0.0.1:8000');
    }
  }

  static String get _base {
    final raw = _baseUri.toString();
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  static Uri _uri(String path) => Uri.parse('$_base$path');

  /// Set or clear the JWT token used for authenticated calls.
  static void setToken(String? token) {
    _token = token;
  }

  static Map<String, String> _headers([Map<String, String>? extra]) {
    final base = <String, String>{'Content-Type': 'application/json'};
    if (_token != null && _token!.isNotEmpty) {
      base['Authorization'] = 'Bearer $_token';
    }
    if (extra != null) base.addAll(extra);
    return base;
  }

  static String progressWsUrl(String taskId) {
    final scheme = _baseUri.scheme == 'https' ? 'wss' : 'ws';
    return _baseUri
        .replace(scheme: scheme, path: '/ml/progress/$taskId')
        .toString();
  }

  static Uri progressSseUri(String taskId) => _uri('/ml/progress-sse/$taskId');

  static Map<String, dynamic> _decodeMap(http.Response res) {
    final dynamic decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return {'data': decoded};
  }

  static List<dynamic> _decodeList(http.Response res) {
    final dynamic decoded = jsonDecode(res.body);
    return decoded is List ? decoded : <dynamic>[];
  }

  static void _throwIfError(
    http.Response res, [
    String fallback = 'Request failed',
  ]) {
    if (res.statusCode < 400) return;
    String message = '$fallback (HTTP ${res.statusCode})';
    try {
      final body = _decodeMap(res);
      final detail = body['detail'] ?? body['message'];
      if (detail is String && detail.trim().isNotEmpty) {
        message = detail;
      }
    } catch (_) {}
    throw Exception(message);
  }

  static Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      _uri('/auth/register'),
      headers: _headers(),
      body: jsonEncode({
        'first_name': firstName,
        'last_name': lastName,
        'username': username,
        'email': email,
        'password': password,
      }),
    );
    _throwIfError(res, 'Registration failed');
    return _decodeMap(res);
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final res = await http.post(
      _uri('/auth/login'),
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    _throwIfError(res, 'Login failed');
    return _decodeMap(res);
  }

  static Future<Map<String, dynamic>> createPerson(
    String userId,
    String name,
  ) async {
    final res = await http.post(
      _uri('/persons/create'),
      headers: _headers(),
      body: jsonEncode({'user_id': userId, 'name': name}),
    );
    _throwIfError(res, 'Create person failed');
    return _decodeMap(res);
  }

  static Future<List<dynamic>> listPersons(String userId) async {
    final res = await http.get(
      _uri('/persons/list/$userId'),
      headers: _headers({'Content-Type': 'application/json'}),
    );
    _throwIfError(res, 'List persons failed');
    return _decodeList(res);
  }

  static Future<Map<String, dynamic>> startSortLocal({
    required Map<String, String> trainingFolders,
    required String unsortedFolder,
    required String outputBase,
    required String unknownFolder,
  }) async {
    final res = await http.post(
      _uri('/ml/sort-local'),
      headers: _headers(),
      body: jsonEncode({
        'training_folders': trainingFolders,
        'unsorted_folder': unsortedFolder,
        'output_base': outputBase,
        'unknown_folder': unknownFolder,
      }),
    );
    _throwIfError(res, 'Sort-local failed');
    return _decodeMap(res);
  }

  static Future<Map<String, dynamic>> startIndexDb({
    required String userId,
    required String folder,
    Map<String, String>? trainingFolders,
  }) async {
    final res = await http.post(
      _uri('/ml/index-db'),
      headers: _headers(),
      body: jsonEncode({
        'user_id': userId,
        'folder': folder,
        'training_folders': trainingFolders,
      }),
    );
    _throwIfError(res, 'Index-DB failed');
    return _decodeMap(res);
  }

  static Future<List<Map<String, dynamic>>> searchPhotosByPerson(
    String userId,
    String personName,
  ) async {
    final q = personName.trim();
    if (q.isEmpty) return [];
    try {
      final res = await http.get(
        _uri('/photos/search/$userId/$q'),
        headers: _headers({'Content-Type': 'application/json'}),
      );
      if (res.statusCode >= 400) return [];
      final body = _decodeList(res);
      return body
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> deletePhoto(String userId, String photoId) async {
    final res = await http.delete(
      _uri('/photos/delete/$userId/$photoId'),
      headers: _headers({'Content-Type': 'application/json'}),
    );
    return res.statusCode < 400;
  }

  static Future<bool> deletePersonFolder(
    String userId,
    String personName,
  ) async {
    final res = await http.delete(
      _uri('/persons/delete-folder/$userId/$personName'),
      headers: _headers({'Content-Type': 'application/json'}),
    );
    return res.statusCode < 400;
  }

  static Future<bool> reassignPhoto(
    String userId,
    String photoId,
    String personName,
  ) async {
    final res = await http.post(
      _uri('/photos/reassign/$userId/$photoId'),
      headers: _headers(),
      body: jsonEncode({'person_name': personName}),
    );
    return res.statusCode < 400;
  }

  static Future<Map<String, dynamic>> deleteBatch(
    String userId,
    List<String> photoIds,
  ) async {
    final res = await http.post(
      _uri('/photos/delete-batch/$userId'),
      headers: _headers(),
      body: jsonEncode({'photo_ids': photoIds}),
    );
    _throwIfError(res, 'Delete batch failed');
    return _decodeMap(res);
  }

  static String photoUrl(String userId, String photoId) =>
      _uri('/photos/get/$userId/$photoId').toString();

  static Future<bool> deleteAccount(String userId) async {
    final res = await http.delete(
      _uri('/auth/delete/$userId'),
      headers: _headers({'Content-Type': 'application/json'}),
    );
    return res.statusCode < 400;
  }
}

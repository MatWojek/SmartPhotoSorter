import 'api_service.dart';

class AuthService {
  static String get baseUrl => ApiService.baseUrl;
  static void setToken(String? token) => ApiService.setToken(token);

  static Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
  }) {
    return ApiService.register(
      firstName: firstName,
      lastName: lastName,
      username: username,
      email: email,
      password: password,
    );
  }

  static Future<Map<String, dynamic>> login(
    String emailOrUsername,
    String password,
  ) {
    return ApiService.login(emailOrUsername, password);
  }

  static Future<bool> deleteAccount(String userId) {
    return ApiService.deleteAccount(userId);
  }
}

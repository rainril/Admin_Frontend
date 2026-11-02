import 'api_endpoints.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Kung web/desktop ang Flutter app mo, 127.0.0.1 ang gamitin.
  // Kung Android emulator, palitan mo ng 10.0.2.2
  static const String baseUrl = AdminApiEndpoints.baseUrl;

  // LOGIN
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Accept': 'application/json'},
      body: {
        'email': email,
        'password': password,
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      // I-save ang token at role info para "naaalala" ng app na naka-login ka
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      await prefs.setString('admin_level', data['adminLevel'] ?? '');
      await prefs.setString('first_name', data['firstName'] ?? '');
      await prefs.setString('last_name', data['lastName'] ?? '');
      await prefs.setInt('account_id', data['accountId'] ?? 0);
      await prefs.setString('email', email);

      return {
        'success': true,
        'adminLevel': data['adminLevel'],
        'firstName': data['firstName'],
        'lastName': data['lastName'],
        'accountId': data['accountId'],
        'token': data['token'],
      };
    } else {
      return {'success': false, 'message': data['message'] ?? 'Login failed'};
    }
  }

  // REGISTER
  static Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String adminLevel,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Accept': 'application/json', if (token != null) 'Authorization': 'Bearer $token'},
      body: {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'password': password,
        'adminLevel': adminLevel,
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return {
        'success': true,
        'adminLevel': data['adminLevel'],
        'firstName': data['firstName'],
        'lastName': data['lastName'],
        'accountId': data['accountId'],
        'token': data['token'],
      };
    } else {
      return {'success': false, 'message': data['message'] ?? 'Registration failed'};
    }
  }

  // LOGOUT
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null && token.isNotEmpty) {
      try {
        await http.post(
          Uri.parse('$baseUrl/logout'),
          headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 5));
      } catch (_) {
        // Always clear the browser session even when the server is offline.
      }
    }
    await _clearSavedUser(prefs);
  }

  static Future<void> _clearSavedUser(SharedPreferences prefs) async {
    await prefs.remove('token');
    await prefs.remove('admin_level');
    await prefs.remove('first_name');
    await prefs.remove('last_name');
    await prefs.remove('account_id');
    await prefs.remove('email');
  }

  /// Verifies the saved Sanctum token with the server before restoring UI state.
  /// Returns null when there is no session or the server has revoked it.
  static Future<Map<String, dynamic>?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) return null;

    final response = await http.get(
      Uri.parse('$baseUrl/user'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await prefs.setString('admin_level', data['adminLevel'] ?? '');
      await prefs.setString('first_name', data['firstName'] ?? '');
      await prefs.setString('last_name', data['lastName'] ?? '');
      await prefs.setInt('account_id', data['accountId'] ?? 0);
      await prefs.setString('email', data['email'] ?? '');
      return data;
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      await _clearSavedUser(prefs);
      return null;
    }
    throw Exception('Unable to verify the saved admin session.');
  }

  // GET CURRENT ADMIN LEVEL (owner o staff)
  static Future<String?> getAdminLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('admin_level');
  }

  // GET CURRENT ADMIN EMAIL
  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('email');
  }

  // FORGOT PASSWORD - request code
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/forgot-password'),
        headers: {'Accept': 'application/json'},
        body: {'email': email},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Something went wrong'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Unable to reach the server. Please check your connection.'};
    }
  }

  // VERIFY RESET CODE
  static Future<Map<String, dynamic>> verifyResetCode(String email, String code) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify-reset-code'),
        headers: {'Accept': 'application/json'},
        body: {
          'email': email,
          'code': code,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        String errorMsg = data['message'] ?? 'Invalid code';
        if (data['errors'] != null && data['errors']['code'] != null) {
          errorMsg = data['errors']['code'][0];
        }
        return {'success': false, 'message': errorMsg};
      }
    } catch (e) {
      return {'success': false, 'message': 'Unable to reach the server. Please check your connection.'};
    }
  }

  // RESET PASSWORD - submit code + new password
  static Future<Map<String, dynamic>> resetPassword(
      String email, String code, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reset-password'),
        headers: {'Accept': 'application/json'},
        body: {
          'email': email,
          'code': code,
          'password': password,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        String errorMsg = data['message'] ?? 'Reset failed';
        if (data['errors'] != null && data['errors']['code'] != null) {
          errorMsg = data['errors']['code'][0];
        }
        return {'success': false, 'message': errorMsg};
      }
    } catch (e) {
      return {'success': false, 'message': 'Unable to reach the server. Please check your connection.'};
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;

class SettingsService {
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  static Future<Map<String, dynamic>?> getSettings(int accountId) async {
    final response = await http.get(Uri.parse('$baseUrl/settings/$accountId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

    static Future<bool> updateSettings({
    required int accountId,
    bool? notificationsEnabled,
    bool? darkMode,
  }) async {
    final body = <String, dynamic>{};
    if (notificationsEnabled != null) {
      body['notificationsEnabled'] = notificationsEnabled;
    }
    if (darkMode != null) {
      body['darkMode'] = darkMode;
    }

    final response = await http.put(
      Uri.parse('$baseUrl/settings/$accountId'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    return response.statusCode == 200;
  }

  static Future<Map<String, dynamic>> changePassword({
    required int accountId,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/change-password'),
        headers: {'Accept': 'application/json'},
        body: {
          'accountId': accountId.toString(),
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        String errorMsg = data['message'] ?? 'Failed to change password';
        if (data['errors'] != null && data['errors']['currentPassword'] != null) {
          errorMsg = data['errors']['currentPassword'][0];
        }
        return {'success': false, 'message': errorMsg};
      }
    } catch (e) {
      return {'success': false, 'message': 'Unable to reach the server. Please check your connection.'};
    }
  }
}
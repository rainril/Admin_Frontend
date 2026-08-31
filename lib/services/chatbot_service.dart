import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatbotService {
  static const String _baseUrl = 'http://127.0.0.1:8000/api';

  /// [history] is the conversation-so-far for the active chat session
  /// (role/content pairs, oldest first), NOT including [text].
  static Future<String> sendMessage(
    String text,
    List<Map<String, String>> history,
  ) async {
    final payload = [
      ...history,
      {'role': 'user', 'content': text},
    ];

    final uri = Uri.parse('$_baseUrl/ai/chat');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'history': payload}),
    );

    if (response.statusCode != 200) {
      throw Exception('Chatbot service error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'Unknown chatbot error');
    }

    return data['reply'] as String;
  }
}
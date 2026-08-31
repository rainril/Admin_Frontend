import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_session.dart';

/// Persists chatbot conversations locally so chat history survives
/// app restarts. There is no backend endpoint for this yet — see
/// primefit-chatbot/ and Laravel's /api/ai/chat, which only takes a
/// flat message history per request and stores nothing server-side.
class ChatbotHistoryService {
  static const String _prefsKey = 'chatbot_sessions';

  static Future<List<ChatSession>> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((s) => ChatSession.fromJson(s as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveSessions(List<ChatSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(sessions.map((s) => s.toJson()).toList());
    await prefs.setString(_prefsKey, encoded);
  }
}

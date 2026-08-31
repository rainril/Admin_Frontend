class ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final DateTime time;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    DateTime? time,
  }) : time = time ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'isError': isError,
        'time': time.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        text: json['text'] as String,
        isUser: json['isUser'] as bool,
        isError: json['isError'] as bool? ?? false,
        time: DateTime.tryParse(json['time'] as String? ?? '') ?? DateTime.now(),
      );
}

class ChatSession {
  final String id;
  String title;
  final List<ChatMessage> messages;
  DateTime updatedAt;

  ChatSession({
    required this.id,
    required this.title,
    required this.messages,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'messages': messages.map((m) => m.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
        id: json['id'] as String,
        title: json['title'] as String,
        messages: (json['messages'] as List)
            .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      );
}

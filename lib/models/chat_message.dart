class ChatMessage {
  final String role; // 'user' or 'assistant'
  String content;

  ChatMessage({required this.role, required this.content});

  Map<String, String> toJson() => {
        'role': role,
        'content': content,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] ?? 'user',
      content: json['content'] ?? '',
    );
  }
}
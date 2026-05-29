import 'dart:convert';

enum IntentPriority { low, medium, high }

class ParsedIntent {
  const ParsedIntent({
    required this.title,
    required this.rawInput,
    this.note,
    this.dueAt,
    this.priority = IntentPriority.medium,
    this.tags = const [],
  });

  final String title;
  final String rawInput;
  final String? note;
  final DateTime? dueAt;
  final IntentPriority priority;
  final List<String> tags;

  factory ParsedIntent.fromJson(Map<String, dynamic> json, String rawInput) {
    return ParsedIntent(
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? (json['title'] as String).trim()
          : rawInput.trim(),
      rawInput: rawInput,
      note: json['note'] as String?,
      dueAt: DateTime.tryParse(json['dueAt'] as String? ?? ''),
      priority: _parsePriority(json['priority'] as String?),
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList(),
    );
  }

  factory ParsedIntent.fromJsonString(String content, String rawInput) {
    final normalized = content
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();
    final decoded = jsonDecode(normalized) as Map<String, dynamic>;
    return ParsedIntent.fromJson(decoded, rawInput);
  }

  static IntentPriority _parsePriority(String? value) {
    return switch (value?.toLowerCase()) {
      'low' => IntentPriority.low,
      'high' => IntentPriority.high,
      _ => IntentPriority.medium,
    };
  }
}

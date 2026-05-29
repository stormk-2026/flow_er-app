import '../../models/parsed_intent.dart';
import 'ai_service.dart';

class MockAiService implements AiService {
  const MockAiService();

  @override
  Future<ParsedIntent> parseIntent(String input) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    return ParsedIntent(
      title: input.trim().isEmpty ? 'Untitled intent' : input.trim(),
      rawInput: input,
      note: 'Mock result. Add KIMI_API_KEY to enable real parsing.',
      priority: IntentPriority.medium,
      tags: const ['mock'],
    );
  }
}

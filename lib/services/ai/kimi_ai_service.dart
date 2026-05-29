import 'package:dio/dio.dart';

import '../../models/parsed_intent.dart';
import 'ai_service.dart';

class KimiAiService implements AiService {
  const KimiAiService({
    required Dio dio,
    required String apiKey,
    this.model = 'kimi-k2-0905-preview',
  }) : _dio = dio,
       _apiKey = apiKey;

  final Dio _dio;
  final String _apiKey;
  final String model;

  @override
  Future<ParsedIntent> parseIntent(String input) async {
    if (_apiKey.isEmpty) {
      throw const AiServiceException('Missing KIMI_API_KEY.');
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/chat/completions',
        options: Options(headers: {'Authorization': 'Bearer $_apiKey'}),
        data: {
          'model': model,
          'temperature': 0.2,
          'messages': [
            {'role': 'system', 'content': _systemPrompt},
            {'role': 'user', 'content': input},
          ],
        },
      );

      final content = response.data?['choices']?[0]?['message']?['content'];
      if (content is! String || content.trim().isEmpty) {
        throw const AiServiceException('Kimi returned an empty response.');
      }

      return ParsedIntent.fromJsonString(content, input);
    } on AiServiceException {
      rethrow;
    } on DioException catch (error) {
      throw AiServiceException('Kimi request failed.', error);
    } on FormatException catch (error) {
      throw AiServiceException('Kimi response was not valid JSON.', error);
    }
  }
}

const _systemPrompt = '''
You are an intent parser for a productivity app.
Return JSON only, without Markdown.
Schema:
{
  "title": "short actionable task title",
  "note": "optional detail",
  "dueAt": "optional ISO-8601 datetime or null",
  "priority": "low | medium | high",
  "tags": ["short tags"]
}
''';

import 'package:dio/dio.dart';

import '../api/api_client.dart';

class FocusMomentService {
  const FocusMomentService();

  Dio get _dio => ApiClient.instance.dio;

  Future<String> fetchMoment({
    required DateTime startedAt,
    required int elapsedSeconds,
    required String triggerType,
  }) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/api/v1/focus/moment',
      data: {
        'started_at': startedAt.toIso8601String(),
        'elapsed_seconds': elapsedSeconds,
        'trigger_type': triggerType,
      },
    );
    final data = resp.data ?? const <String, dynamic>{};
    final text = (data['text'] ?? data['moment'] ?? data['content'])
        ?.toString()
        .trim();
    if (text == null || text.isEmpty) {
      throw const FocusMomentException('Empty focus moment response.');
    }
    return text;
  }
}

class FocusMomentException implements Exception {
  const FocusMomentException(this.message);

  final String message;

  @override
  String toString() => message;
}

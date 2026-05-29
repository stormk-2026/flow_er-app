import '../../models/parsed_intent.dart';

abstract class AiService {
  Future<ParsedIntent> parseIntent(String input);
}

class AiServiceException implements Exception {
  const AiServiceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'AiServiceException: $message';
}

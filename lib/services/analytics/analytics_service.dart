import 'package:dio/dio.dart';

import '../api/api_client.dart';

enum AnalyticsPeriod {
  all('all', '全部'),
  thirtyDays('30d', '近 30 天'),
  sevenDays('7d', '近 7 天');

  const AnalyticsPeriod(this.value, this.label);

  final String value;
  final String label;
}

class AnalyticsService {
  const AnalyticsService();

  Dio get _dio => ApiClient.instance.dio;

  Future<AnalyticsStats> fetchStats(AnalyticsPeriod period) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/api/v1/focus-sessions/stats',
      queryParameters: {'period': period.value},
    );
    return AnalyticsStats.fromJson(resp.data ?? const {});
  }

  Future<AnalyticsPortrait> fetchPortrait(AnalyticsPeriod period) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/api/v1/focus-sessions/portrait',
      queryParameters: {'period': period.value},
    );
    return AnalyticsPortrait.fromJson(resp.data ?? const {});
  }
}

class AnalyticsStats {
  const AnalyticsStats({
    required this.period,
    required this.sessionCount,
    required this.successCount,
    required this.failedCount,
    required this.duration,
    required this.intents,
    required this.soulPurity,
    required this.awarenessIndex,
  });

  final String period;
  final int sessionCount;
  final int successCount;
  final int failedCount;
  final DurationStats duration;
  final IntentStats intents;
  final ScoreStats soulPurity;
  final AwarenessStats awarenessIndex;

  factory AnalyticsStats.fromJson(Map<String, dynamic> json) {
    return AnalyticsStats(
      period: json['period']?.toString() ?? '30d',
      sessionCount: _asInt(json['session_count']),
      successCount: _asInt(json['success_count']),
      failedCount: _asInt(json['failed_count']),
      duration: DurationStats.fromJson(_asMap(json['duration'])),
      intents: IntentStats.fromJson(_asMap(json['intents'])),
      soulPurity: ScoreStats.fromJson(_asMap(json['soul_purity'])),
      awarenessIndex: AwarenessStats.fromJson(_asMap(json['awareness_index'])),
    );
  }
}

class DurationStats {
  const DurationStats({
    required this.totalHours,
    required this.longestSeconds,
    required this.averageSeconds,
    required this.activeDays,
    required this.frequencyPerWeek,
    required this.byTrigger,
    required this.byHourBucket,
  });

  final double totalHours;
  final int longestSeconds;
  final int averageSeconds;
  final int activeDays;
  final double frequencyPerWeek;
  final Map<String, int> byTrigger;
  final Map<String, int> byHourBucket;

  factory DurationStats.fromJson(Map<String, dynamic> json) {
    return DurationStats(
      totalHours: _asDouble(json['total_hours']),
      longestSeconds: _asInt(json['longest_seconds']),
      averageSeconds: _asInt(json['average_seconds']),
      activeDays: _asInt(json['active_days']),
      frequencyPerWeek: _asDouble(json['frequency_per_week']),
      byTrigger: _asIntMap(json['by_trigger']),
      byHourBucket: _asIntMap(json['by_hour_bucket']),
    );
  }
}

class IntentStats {
  const IntentStats({
    required this.total,
    required this.byCategory,
    required this.deepestIntent,
    required this.byHourBucket,
    this.inspirationPeakHour,
  });

  final int total;
  final Map<String, int> byCategory;
  final DeepestIntent? deepestIntent;
  final Map<String, int> byHourBucket;
  final String? inspirationPeakHour;

  factory IntentStats.fromJson(Map<String, dynamic> json) {
    return IntentStats(
      total: _asInt(json['total']),
      byCategory: _asIntMap(json['by_category']),
      deepestIntent: json['deepest_intent'] is Map
          ? DeepestIntent.fromJson(_asMap(json['deepest_intent']))
          : null,
      byHourBucket: _asIntMap(json['by_hour_bucket']),
      inspirationPeakHour: json['inspiration_peak_hour']?.toString(),
    );
  }
}

class DeepestIntent {
  const DeepestIntent({
    required this.id,
    required this.preview,
    required this.length,
    this.createdAt,
  });

  final String id;
  final String preview;
  final int length;
  final DateTime? createdAt;

  factory DeepestIntent.fromJson(Map<String, dynamic> json) {
    return DeepestIntent(
      id: json['id']?.toString() ?? '',
      preview: json['preview']?.toString() ?? '',
      length: _asInt(json['length']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

class ScoreStats {
  const ScoreStats({
    this.score,
    required this.factorsAvg,
    required this.trend,
    this.targetSeconds,
  });

  final int? score;
  final Map<String, double> factorsAvg;
  final List<TrendPoint> trend;
  final int? targetSeconds;

  factory ScoreStats.fromJson(Map<String, dynamic> json) {
    return ScoreStats(
      score: json['score'] == null ? null : _asInt(json['score']),
      factorsAvg: _asDoubleMap(json['factors_avg']),
      trend: _asTrend(json['trend']),
      targetSeconds: json['target_seconds'] == null
          ? null
          : _asInt(json['target_seconds']),
    );
  }
}

class AwarenessStats {
  const AwarenessStats({
    this.score,
    required this.factorsAvg,
    required this.trend,
  });

  final int? score;
  final Map<String, double> factorsAvg;
  final List<TrendPoint> trend;

  factory AwarenessStats.fromJson(Map<String, dynamic> json) {
    return AwarenessStats(
      score: json['score'] == null ? null : _asInt(json['score']),
      factorsAvg: _asDoubleMap(json['factors_avg']),
      trend: _asTrend(json['trend']),
    );
  }
}

class TrendPoint {
  const TrendPoint({this.startedAt, required this.score});

  final DateTime? startedAt;
  final double score;
}

class AnalyticsPortrait {
  const AnalyticsPortrait({this.userPortrait, this.interpretation});

  final String? userPortrait;
  final String? interpretation;

  factory AnalyticsPortrait.fromJson(Map<String, dynamic> json) {
    return AnalyticsPortrait(
      userPortrait: _nonEmpty(json['user_portrait']),
      interpretation: _nonEmpty(json['interpretation']),
    );
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
  return const {};
}

Map<String, int> _asIntMap(Object? value) {
  return _asMap(value).map((k, v) => MapEntry(k, _asInt(v)));
}

Map<String, double> _asDoubleMap(Object? value) {
  return _asMap(value).map((k, v) => MapEntry(k, _asDouble(v)));
}

List<TrendPoint> _asTrend(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map(
        (item) => TrendPoint(
          startedAt: DateTime.tryParse(item['started_at']?.toString() ?? ''),
          score: _asDouble(item['score']),
        ),
      )
      .toList(growable: false);
}

String? _nonEmpty(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

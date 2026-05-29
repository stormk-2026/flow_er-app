import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';

class FocusStats {
  const FocusStats({
    this.totalHours = 0,
    this.flowPurityPercent = 0,
    this.countedSessionCount = 0,
  });

  final double totalHours;
  final int flowPurityPercent;
  final int countedSessionCount;
}

final focusStatsProvider = Provider<FocusStats>((ref) {
  final sessions = ref.watch(focusSessionsProvider).valueOrNull ?? const [];

  final counted =
      sessions.where((s) => !s.excludedFromStats).toList(growable: false);
  if (counted.isEmpty) {
    return const FocusStats();
  }

  var totalSeconds = 0;
  var successSeconds = 0;
  for (final s in counted) {
    totalSeconds += s.durationSeconds;
    if (!s.isFailed) {
      successSeconds += s.durationSeconds;
    }
  }

  final totalHours = totalSeconds / 3600.0;
  final purity = totalSeconds == 0
      ? 0
      : ((successSeconds / totalSeconds) * 100).round().clamp(0, 100);

  return FocusStats(
    totalHours: totalHours,
    flowPurityPercent: purity,
    countedSessionCount: counted.length,
  );
});

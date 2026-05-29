import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/focus/focus_constants.dart';
import 'app_providers.dart';
import 'focus_stats_provider.dart';

class TimeRewindQuota {
  const TimeRewindQuota({this.remainingToday = FocusConstants.rewindDailyLimit});

  final int remainingToday;
}

class TimeRewindController extends Notifier<TimeRewindQuota> {
  static const _dateKey = 'time_rewind_date';
  static const _usedKey = 'time_rewind_used';

  @override
  TimeRewindQuota build() {
    _loadQuota();
    return const TimeRewindQuota();
  }

  Future<void> _loadQuota() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final savedDate = prefs.getString(_dateKey);
    var used = prefs.getInt(_usedKey) ?? 0;
    if (savedDate != today) {
      used = 0;
      await prefs.setString(_dateKey, today);
      await prefs.setInt(_usedKey, 0);
    }
    state = TimeRewindQuota(
      remainingToday: (FocusConstants.rewindDailyLimit - used)
          .clamp(0, FocusConstants.rewindDailyLimit),
    );
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  /// 返回 null 表示成功；否则为错误提示。
  Future<String?> rewindRecentFailures() async {
    if (state.remainingToday <= 0) {
      return '今日回溯次数已用尽，明日再试';
    }

    final repo = ref.read(focusSessionRepositoryProvider);
    final failures = await repo.getRewindableFailures();
    if (failures.isEmpty) {
      return '近 30 分钟内没有可回溯的失败专注';
    }

    await repo.excludeSessions(failures.map((s) => s.id));

    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final used = (prefs.getInt(_usedKey) ?? 0) + 1;
    await prefs.setString(_dateKey, today);
    await prefs.setInt(_usedKey, used);

    state = TimeRewindQuota(
      remainingToday: (FocusConstants.rewindDailyLimit - used)
          .clamp(0, FocusConstants.rewindDailyLimit),
    );

    ref.invalidate(focusSessionsProvider);
    ref.invalidate(focusStatsProvider);

    return null;
  }

  Future<int> previewRewindableCount() async {
    final failures =
        await ref.read(focusSessionRepositoryProvider).getRewindableFailures();
    return failures.length;
  }
}

final timeRewindProvider =
    NotifierProvider<TimeRewindController, TimeRewindQuota>(
  TimeRewindController.new,
);

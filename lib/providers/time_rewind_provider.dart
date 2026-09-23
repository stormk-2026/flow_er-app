import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/focus/focus_constants.dart';
import 'app_providers.dart';
import 'focus_stats_provider.dart';
import 'auth_provider.dart';

class TimeRewindQuota {
  const TimeRewindQuota({
    this.remainingToday = FocusConstants.rewindDailyLimit,
  });

  final int remainingToday;
}

class TimeRewindController extends Notifier<TimeRewindQuota> {
  int _generation = 0;
  bool _busy = false;
  Future<void> _quotaReady = Future<void>.value();

  @override
  TimeRewindQuota build() {
    final account = ref.watch(
      authProvider.select((auth) => auth.valueOrNull?.email ?? 'guest'),
    );
    final generation = ++_generation;
    ref.onDispose(() => _generation++);
    _quotaReady = _loadQuota(account, generation).catchError((Object _) {});
    return const TimeRewindQuota();
  }

  Future<void> _loadQuota(String account, int generation) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final dateKey = 'time_rewind_date_$account';
    final usedKey = 'time_rewind_used_$account';
    final savedDate = prefs.getString(dateKey);
    var used = prefs.getInt(usedKey) ?? 0;
    if (savedDate != today) {
      used = 0;
      await prefs.setString(dateKey, today);
      await prefs.setInt(usedKey, 0);
    }
    if (generation != _generation) return;
    state = TimeRewindQuota(
      remainingToday: (FocusConstants.rewindDailyLimit - used).clamp(
        0,
        FocusConstants.rewindDailyLimit,
      ),
    );
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  /// 返回 null 表示成功；否则为错误提示。
  Future<String?> rewindRecentFailures() async {
    if (_busy) return '回溯处理中，请稍候';
    _busy = true;
    final generation = _generation;
    final account = ref.read(authProvider).valueOrNull?.email ?? 'guest';
    final dateKey = 'time_rewind_date_$account';
    final usedKey = 'time_rewind_used_$account';
    final repo = ref.read(focusSessionRepositoryProvider);
    final sync = ref.read(focusSessionSyncServiceProvider);
    try {
      await _quotaReady;
      if (generation != _generation) return '账号已切换，请重新操作';
      await _loadQuota(account, generation);
      if (generation != _generation) return '账号已切换，请重新操作';
      if (state.remainingToday <= 0) {
        return '今日回溯次数已用尽，明日再试';
      }
      final failures = await repo.getRewindableFailures();
      if (generation != _generation) return '账号已切换，请重新操作';
      if (failures.isEmpty) {
        return '近 30 分钟内没有可回溯的失败专注';
      }

      await repo.excludeSessions(failures.map((s) => s.id));
      // The outbox is already durable. A slow network must not keep quota/UI
      // updates suspended across an account change.
      unawaited(sync.pushPending().catchError((Object _) {}));

      final prefs = await SharedPreferences.getInstance();
      final today = _todayKey();
      final used =
          (prefs.getString(dateKey) == today ? prefs.getInt(usedKey) ?? 0 : 0) +
          1;
      await prefs.setString(dateKey, today);
      await prefs.setInt(usedKey, used);
      if (generation != _generation) return null;
      invalidateAnalyticsProviders(ref);

      state = TimeRewindQuota(
        remainingToday: (FocusConstants.rewindDailyLimit - used).clamp(
          0,
          FocusConstants.rewindDailyLimit,
        ),
      );

      ref.invalidate(focusSessionsProvider);
      ref.invalidate(focusStatsProvider);

      return null;
    } catch (_) {
      return '回溯未完成，请重试';
    } finally {
      _busy = false;
    }
  }

  Future<int> previewRewindableCount() async {
    final failures = await ref
        .read(focusSessionRepositoryProvider)
        .getRewindableFailures();
    return failures.length;
  }
}

final timeRewindProvider =
    NotifierProvider<TimeRewindController, TimeRewindQuota>(
      TimeRewindController.new,
    );

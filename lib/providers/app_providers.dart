import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/inspiration/models/inspiration_moment.dart';
import '../models/app_database.dart';
import '../models/thought_capture_mode.dart';
import '../repositories/focus_session_repository.dart';
import '../repositories/intent_repository.dart';
import '../services/analytics/analytics_service.dart';
import '../services/focus/focus_moment_service.dart';
import '../services/sensors/focus_sensor_service.dart';
import '../services/sync/focus_session_sync_service.dart';
import '../services/sync/intent_sync_service.dart';

// Provider<AppDatabase> — 同步创建，不需要 FutureProvider
// Drift 的 LazyDatabase 内部自己处理异步初始化
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close); // ref.onDispose ≈ ViewModel.onCleared()
  return db;
});

final intentRepositoryProvider = Provider<IntentRepository>((ref) {
  return IntentRepository(ref.watch(databaseProvider));
});

final intentSyncServiceProvider = Provider<IntentSyncService>((ref) {
  return IntentSyncService(ref.watch(intentRepositoryProvider));
});

final focusSessionRepositoryProvider = Provider<FocusSessionRepository>((ref) {
  return FocusSessionRepository(ref.watch(databaseProvider));
});

final focusSessionSyncServiceProvider = Provider<FocusSessionSyncService>((
  ref,
) {
  return FocusSessionSyncService(ref.watch(focusSessionRepositoryProvider));
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return const AnalyticsService();
});

final analyticsStatsProvider =
    FutureProvider.family<AnalyticsStats, AnalyticsPeriod>((ref, period) {
      return ref.watch(analyticsServiceProvider).fetchStats(period);
    });

final analyticsPortraitProvider =
    FutureProvider.family<AnalyticsPortrait, AnalyticsPeriod>((ref, period) {
      return ref.watch(analyticsServiceProvider).fetchPortrait(period);
    });

void invalidateAnalyticsProviders(Ref ref) {
  _invalidateAnalytics(ref.invalidate);
}

void invalidateAnalyticsWidgetProviders(WidgetRef ref) {
  _invalidateAnalytics(ref.invalidate);
}

void _invalidateAnalytics(void Function(ProviderOrFamily provider) invalidate) {
  for (final period in AnalyticsPeriod.values) {
    invalidate(analyticsStatsProvider(period));
    invalidate(analyticsPortraitProvider(period));
  }
}

final focusMomentServiceProvider = Provider<FocusMomentService>((ref) {
  return const FocusMomentService();
});

final focusSessionsProvider = StreamProvider<List<FocusSession>>((ref) {
  return ref.watch(focusSessionRepositoryProvider).watchAll();
});

// StreamProvider 监听数据库变化，自动推送给 UI
// ≈ collectAsState() 监听 Room 的 Flow<List<T>>
final intentsProvider = StreamProvider<List<FlowIntent>>((ref) {
  return ref.watch(intentRepositoryProvider).watchAll();
});

/// 心笺列表：冥想页提交 → 本地库 → 此处监听并转成随机样式卡片。
final inspirationMomentsProvider =
    Provider<AsyncValue<List<InspirationMoment>>>((ref) {
      return ref.watch(intentsProvider).whenData(InspirationMoment.buildFeed);
    });

final intentControllerProvider = AsyncNotifierProvider<IntentController, void>(
  IntentController.new,
);

class IntentController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> saveJournal({
    required ThoughtCaptureMode mode,
    required String quickText,
    required String title,
    required String body,
    List<String> imagePaths = const [],
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final intent = await ref
          .read(intentRepositoryProvider)
          .saveJournal(
            mode: mode,
            quickText: quickText,
            title: title,
            body: body,
            imagePaths: imagePaths,
          );
      if (intent != null) {
        await ref.read(intentSyncServiceProvider).pushIntent(intent);
        invalidateAnalyticsProviders(ref);
      }
    });
  }

  Future<void> updateJournal({
    required FlowIntent intent,
    required String title,
    required String body,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final updated = await ref
          .read(intentRepositoryProvider)
          .updateJournal(localId: intent.id, title: title, body: body);
      if (updated != null) {
        await ref.read(intentSyncServiceProvider).updateIntent(updated);
        invalidateAnalyticsProviders(ref);
      }
    });
  }

  Future<void> deleteJournal(FlowIntent intent) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(intentSyncServiceProvider).deleteIntent(intent);
      invalidateAnalyticsProviders(ref);
    });
  }
}

final focusSensorServiceProvider = Provider<FocusSensorService>((ref) {
  return FocusSensorService();
});

final focusStateProvider = StreamProvider<UserFocusState>((ref) {
  return ref.watch(focusSensorServiceProvider).watchFocusState();
});

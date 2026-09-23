import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/inspiration/models/inspiration_moment.dart';
import '../models/app_database.dart';
import '../models/thought_capture_mode.dart';
import '../repositories/focus_session_repository.dart';
import '../repositories/intent_repository.dart';
import '../services/analytics/analytics_service.dart';
import '../services/audio/app_audio_service.dart';
import '../services/focus/focus_moment_service.dart';
import '../services/sensors/focus_sensor_service.dart';
import '../services/sync/focus_session_sync_service.dart';
import '../services/sync/intent_sync_service.dart';
import '../services/uploads/image_upload_service.dart';
import 'settings_provider.dart';
import 'auth_provider.dart';

// Provider<AppDatabase> — 同步创建，不需要 FutureProvider
// Drift 的 LazyDatabase 内部自己处理异步初始化
final databaseProvider = Provider<AppDatabase>((ref) {
  final account =
      ref.watch(authProvider.select((value) => value.valueOrNull?.email)) ??
      'guest';
  final db = AppDatabase(account: account);
  ref.onDispose(db.close); // ref.onDispose ≈ ViewModel.onCleared()
  return db;
});

final intentRepositoryProvider = Provider<IntentRepository>((ref) {
  return IntentRepository(ref.watch(databaseProvider));
});

final intentSyncServiceProvider = Provider<IntentSyncService>((ref) {
  return IntentSyncService(
    ref.watch(intentRepositoryProvider),
    account: ref.watch(
      authProvider.select((value) => value.valueOrNull?.email),
    ),
  );
});

final focusSessionRepositoryProvider = Provider<FocusSessionRepository>((ref) {
  return FocusSessionRepository(ref.watch(databaseProvider));
});

final focusSessionSyncServiceProvider = Provider<FocusSessionSyncService>((
  ref,
) {
  return FocusSessionSyncService(
    ref.watch(focusSessionRepositoryProvider),
    account: ref.watch(
      authProvider.select((value) => value.valueOrNull?.email),
    ),
  );
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return const AnalyticsService();
});

final appAudioServiceProvider = Provider<AppAudioService>((ref) {
  final service = AppAudioService();
  ref.onDispose(service.dispose);
  return service;
});

final analyticsStatsProvider =
    FutureProvider.family<AnalyticsStats, AnalyticsPeriod>((ref, period) {
      ref.watch(authProvider.select((value) => value.valueOrNull?.email));
      return ref.watch(analyticsServiceProvider).fetchStats(period);
    });

final analyticsPortraitProvider =
    FutureProvider.family<AnalyticsPortrait, AnalyticsPeriod>((ref, period) {
      ref.watch(authProvider.select((value) => value.valueOrNull?.email));
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

final imageUploadServiceProvider = Provider<ImageUploadService>((ref) {
  return const ImageUploadService();
});

final focusSessionsProvider = StreamProvider<List<FocusSession>>((ref) {
  return ref.watch(focusSessionRepositoryProvider).watchAll();
});

// StreamProvider 监听数据库变化，自动推送给 UI
// ≈ collectAsState() 监听 Room 的 Flow<List<T>>
final intentsProvider = StreamProvider<List<FlowIntent>>((ref) {
  return ref.watch(intentRepositoryProvider).watchAll();
});

final pendingIntentCountProvider = StreamProvider<int>(
  (ref) => ref.watch(intentRepositoryProvider).watchPendingCount(),
);

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
    final repository = ref.read(intentRepositoryProvider);
    final syncService = ref.read(intentSyncServiceProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final attachments = imagePaths;
      final intent = await repository.saveJournal(
        mode: mode,
        quickText: quickText,
        title: title,
        body: body,
        imagePaths: attachments,
      );
      if (intent != null) {
        // Local persistence completes independently of cloud/AI latency.
        unawaited(_pushAndRefresh(syncService, intent));
        await ref
            .read(appAudioServiceProvider)
            .setEnabled(ref.read(settingsProvider).soundEnabled);
        unawaited(ref.read(appAudioServiceProvider).playIntentSent());
        invalidateAnalyticsProviders(ref);
      }
    });
  }

  Future<void> deleteJournal(FlowIntent intent) async {
    final service = ref.read(intentSyncServiceProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await service.deleteIntent(intent);
      invalidateAnalyticsProviders(ref);
    });
  }

  Future<void> _refreshGeneratedComment(IntentSyncService syncService) async {
    const delays = [
      Duration(seconds: 2),
      Duration(seconds: 5),
      Duration(seconds: 10),
    ];

    for (final delay in delays) {
      await Future<void>.delayed(delay);
      await syncService.refreshSnapshot();
    }
  }

  Future<void> _pushAndRefresh(
    IntentSyncService service,
    FlowIntent intent,
  ) async {
    try {
      await service.pushIntent(intent);
      await _refreshGeneratedComment(service);
    } catch (_) {
      // The local record stays available for a later sync attempt.
    }
  }
}

final focusSensorServiceProvider = Provider<FocusSensorService>((ref) {
  return FocusSensorService();
});

final focusStateProvider = StreamProvider<UserFocusState>((ref) {
  return ref.watch(focusSensorServiceProvider).watchFocusState();
});

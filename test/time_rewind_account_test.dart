import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flow_er/models/app_database.dart';
import 'package:flow_er/providers/app_providers.dart';
import 'package:flow_er/providers/auth_provider.dart';
import 'package:flow_er/providers/time_rewind_provider.dart';
import 'package:flow_er/repositories/focus_session_repository.dart';
import 'package:flow_er/services/sync/focus_session_sync_service.dart';

class _Auth extends AuthController {
  @override
  Future<AuthSession?> build() async =>
      const AuthSession(email: 'a@example.com', nickname: 'A');
  void switchToB() => state = const AsyncData(
    AuthSession(email: 'b@example.com', nickname: 'B'),
  );
}

class _SlowRepository extends FocusSessionRepository {
  _SlowRepository(super.db);
  final reached = Completer<void>();
  final resume = Completer<void>();
  @override
  Future<int> excludeSessions(Iterable<int> ids) async {
    final count = await super.excludeSessions(ids);
    reached.complete();
    await resume.future;
    return count;
  }
}

class _NoNetwork extends FocusSessionSyncService {
  _NoNetwork(super.repo);
  @override
  Future<void> pushPending() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'rewind completing after account change charges only the original account',
    () async {
      SharedPreferences.setMockInitialValues({});
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = _SlowRepository(db);
      final auth = _Auth();
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => auth),
          focusSessionRepositoryProvider.overrideWithValue(repo),
          focusSessionSyncServiceProvider.overrideWithValue(_NoNetwork(repo)),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      await container.read(authProvider.future);
      final now = DateTime.now();
      await repo.recordSession(
        startedAt: now.subtract(const Duration(seconds: 10)),
        endedAt: now,
        triggerType: 'tap',
      );
      final controller = container.read(timeRewindProvider.notifier);
      final pending = controller.rewindRecentFailures();
      await repo.reached.future;
      expect(await controller.rewindRecentFailures(), '回溯处理中，请稍候');
      auth.switchToB();
      container.read(timeRewindProvider); // Rebuild using B's isolated quota.
      repo.resume.complete();
      expect(await pending, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('time_rewind_used_a@example.com'), 1);
      expect(prefs.getInt('time_rewind_used_b@example.com') ?? 0, 0);
      expect((await repo.watchAll().first).single.excludedFromStats, isTrue);
    },
  );
}

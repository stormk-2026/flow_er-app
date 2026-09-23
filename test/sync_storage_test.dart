import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:flow_er/models/app_database.dart';
import 'package:flow_er/models/thought_capture_mode.dart';
import 'package:flow_er/repositories/intent_repository.dart';
import 'package:flow_er/repositories/focus_session_repository.dart';

void main() {
  test(
    'lost upload acknowledgement merges by client ID without duplicates',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = IntentRepository(db);
      final row = (await repo.saveJournal(
        mode: ThoughtCaptureMode.quick,
        quickText: 'new local text',
        title: '',
        body: '',
      ))!;
      await repo.upsertFromServer({
        'id': 'server-1',
        'client_id': row.clientId,
        'title': 'stale title',
        'raw_input': 'stale text',
        'attachments': ['https://example.test/stale.jpg'],
        'updated_at': '2000-01-01T00:00:00Z',
      });
      final rows = await repo.watchAll().first;
      expect(rows, hasLength(1));
      expect(rows.single.id, row.id);
      expect(rows.single.serverId, 'server-1');
      expect(rows.single.rawInput, 'new local text');
      expect(rows.single.attachments, '[]');
    },
  );
  test(
    'focus restore links a lost acknowledgement without undoing offline rewind',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = FocusSessionRepository(db);
      final row = await repo.recordSession(
        startedAt: DateTime(2026),
        endedAt: DateTime(2026).add(const Duration(seconds: 10)),
        triggerType: 'tap',
      );
      await repo.excludeSessions([row.id]);
      await repo.upsertFromServer({
        'id': 'server-1',
        'client_id': row.clientId,
        'started_at': row.startedAt.toIso8601String(),
        'ended_at': row.endedAt.toIso8601String(),
        'duration_seconds': 10,
        'trigger_type': 'tap',
        'is_failed': true,
        'excluded_from_stats': false,
      });
      final rows = await repo.watchAll().first;
      expect(rows, hasLength(1));
      expect(rows.single.serverId, 'server-1');
      expect(rows.single.excludedFromStats, isTrue);
      expect(rows.single.syncDirty, isTrue);
    },
  );
  test(
    'Accounts have distinct files and never adopt the legacy shared file',
    () {
      expect(
        accountDatabaseName('a@example.com'),
        isNot(accountDatabaseName('b@example.com')),
      );
      expect(accountDatabaseName('a@example.com'), isNot('flow_er.sqlite'));
      expect(
        accountDatabaseName('A@example.com'),
        accountDatabaseName('a@example.com'),
      );
    },
  );
  test(
    'Device IDs differ; delete is durable, hidden and cannot be resurrected',
    () async {
      final a = AppDatabase.forTesting(NativeDatabase.memory());
      final b = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(a.close);
      addTearDown(b.close);
      final ra = IntentRepository(a), rb = IntentRepository(b);
      Future<FlowIntent?> save(IntentRepository r) => r.saveJournal(
        mode: ThoughtCaptureMode.quick,
        quickText: 'test',
        title: '',
        body: '',
      );
      final first = (await save(ra))!, second = (await save(rb))!;
      expect(first.id, second.id);
      expect(first.clientId, isNot(second.clientId));
      await ra.updateServerId(localId: first.id, serverId: 'server-a');
      await ra.markDeleted(first.id);
      expect(await ra.watchAll().first, isEmpty);
      expect(await ra.getPendingDeletes(), hasLength(1));
      await ra.upsertFromServer({
        'id': 'server-a',
        'client_id': first.clientId,
        'raw_input': 'remote',
        'updated_at': '2099-01-01T00:00:00Z',
      });
      expect(await ra.watchAll().first, isEmpty);
      expect(await rb.watchAll().first, hasLength(1));
    },
  );
  test(
    'Offline rewind remains dirty until its own state is acknowledged',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = FocusSessionRepository(db);
      final row = await repo.recordSession(
        startedAt: DateTime(2026),
        endedAt: DateTime(2026).add(const Duration(seconds: 10)),
        triggerType: 'tap',
      );
      await repo.excludeSessions([row.id]);
      await repo.markSynced(row, 'server-a');
      expect(await repo.getPendingSync(), hasLength(1));
      final latest = (await repo.getPendingSync()).single;
      expect(latest.excludedFromStats, isTrue);
      await repo.markSynced(latest, 'server-a');
      expect(await repo.getPendingSync(), isEmpty);
    },
  );
}

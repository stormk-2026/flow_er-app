import 'package:drift/drift.dart';

import '../core/focus/focus_constants.dart';
import '../models/app_database.dart';
import '../core/record_id.dart';

class FocusSessionRepository {
  const FocusSessionRepository(this._db);

  final AppDatabase _db;

  Future<FocusSession?> findLocal(int id) => (_db.select(
    _db.focusSessions,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<List<FocusSession>> watchAll() {
    return (_db.select(
      _db.focusSessions,
    )..orderBy([(t) => OrderingTerm.desc(t.startedAt)])).watch();
  }

  Future<FocusSession> recordSession({
    required DateTime startedAt,
    required DateTime endedAt,
    required String triggerType,
    int? durationSecondsOverride,
  }) async {
    final duration =
        durationSecondsOverride ?? endedAt.difference(startedAt).inSeconds;
    final isFailed = duration < FocusConstants.minSuccessSeconds;

    final id = await _db
        .into(_db.focusSessions)
        .insert(
          FocusSessionsCompanion.insert(
            clientId: Value(newRecordId()),
            startedAt: startedAt,
            endedAt: endedAt,
            durationSeconds: duration,
            triggerType: triggerType,
            isFailed: isFailed,
          ),
        );
    return (_db.select(
      _db.focusSessions,
    )..where((t) => t.id.equals(id))).getSingle();
  }

  Future<List<FocusSession>> getPendingSync() {
    return (_db.select(
      _db.focusSessions,
    )..where((t) => t.serverId.isNull() | t.syncDirty.equals(true))).get();
  }

  Future<void> updateServerId({
    required int localId,
    required String serverId,
  }) {
    return (_db.update(_db.focusSessions)..where((t) => t.id.equals(localId)))
        .write(FocusSessionsCompanion(serverId: Value(serverId)));
  }

  /// 近 30 分钟内、失败且尚未排除的专注。
  Future<List<FocusSession>> getRewindableFailures() {
    final since = DateTime.now().subtract(FocusConstants.rewindWindow);
    return (_db.select(_db.focusSessions)
          ..where(
            (t) =>
                t.isFailed.equals(true) &
                t.excludedFromStats.equals(false) &
                t.endedAt.isBiggerOrEqualValue(since),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.endedAt)]))
        .get();
  }

  Future<int> excludeSessions(Iterable<int> ids) async {
    var count = 0;
    for (final id in ids) {
      count +=
          await (_db.update(
            _db.focusSessions,
          )..where((t) => t.id.equals(id))).write(
            const FocusSessionsCompanion(
              excludedFromStats: Value(true),
              syncDirty: Value(true),
            ),
          );
    }
    return count;
  }

  Future<void> markSynced(FocusSession sent, String serverId) async {
    // Do not acknowledge a newer local rewind using an older upload response.
    await (_db.update(_db.focusSessions)..where(
          (t) =>
              t.id.equals(sent.id) &
              t.excludedFromStats.equals(sent.excludedFromStats),
        ))
        .write(
          FocusSessionsCompanion(
            serverId: Value(serverId),
            syncDirty: const Value(false),
          ),
        );
  }

  Future<void> upsertFromServer(Map<String, dynamic> item) =>
      _db.transaction(() => _upsertFromServer(item));

  Future<void> _upsertFromServer(Map<String, dynamic> item) async {
    final serverId = item['id'] as String;
    final clientId = item['client_id'] as String?;
    final existing =
        await (_db.select(_db.focusSessions)..where(
              (t) =>
                  t.serverId.equals(serverId) |
                  (clientId == null
                      ? const Constant(false)
                      : t.clientId.equals(clientId)),
            ))
            .getSingleOrNull();
    if (existing?.syncDirty == true) {
      await updateServerId(localId: existing!.id, serverId: serverId);
      return;
    }
    final row = FocusSessionsCompanion.insert(
      clientId: Value(item['client_id'] as String? ?? serverId),
      serverId: Value(serverId),
      syncDirty: const Value(false),
      startedAt: DateTime.parse(item['started_at'] as String).toLocal(),
      endedAt: DateTime.parse(item['ended_at'] as String).toLocal(),
      durationSeconds: item['duration_seconds'] as int,
      triggerType: item['trigger_type'] as String,
      isFailed: item['is_failed'] as bool,
      excludedFromStats: Value(item['excluded_from_stats'] as bool),
    );
    if (existing == null) {
      await _db.into(_db.focusSessions).insert(row);
    } else {
      await (_db.update(
        _db.focusSessions,
      )..where((t) => t.id.equals(existing.id))).write(row);
    }
  }
}

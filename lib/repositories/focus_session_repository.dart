import 'package:drift/drift.dart';

import '../core/focus/focus_constants.dart';
import '../models/app_database.dart';

class FocusSessionRepository {
  const FocusSessionRepository(this._db);

  final AppDatabase _db;

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
    )..where((t) => t.serverId.isNull())).get();
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
            const FocusSessionsCompanion(excludedFromStats: Value(true)),
          );
    }
    return count;
  }
}

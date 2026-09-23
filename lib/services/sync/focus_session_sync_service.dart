import 'package:dio/dio.dart';

import '../../models/app_database.dart';
import '../../repositories/focus_session_repository.dart';
import '../api/api_client.dart';
import 'sync_queue.dart';

class FocusSessionSyncService {
  FocusSessionSyncService(this._repo, {this.account});
  final SyncQueue _queue = SyncQueue();
  final String? account;
  Future<Options> _options() => ApiClient.instance.accountOptions(account);

  final FocusSessionRepository _repo;
  Dio get _dio => ApiClient.instance.dio;

  Future<void> pushPending() => _queue.run(_pushPending);

  Future<void> _pushPending() async {
    final pending = await _repo.getPendingSync();
    if (pending.isEmpty) return;
    await _pushSessions(pending);
  }

  Future<void> pushSession(FocusSession session) {
    return pushSessions([session]);
  }

  Future<void> pushSessions(List<FocusSession> sessions) =>
      _queue.run(() => _pushSessions(sessions));

  Future<void> _pushSessions(List<FocusSession> sessions) async {
    final current = <FocusSession>[];
    for (final requested in sessions) {
      final row = await _repo.findLocal(requested.id);
      if (row != null) current.add(row);
    }
    final unsynced = current
        .where((session) => session.serverId == null || session.syncDirty)
        .toList(growable: false);
    if (unsynced.isEmpty) return;
    if (unsynced.length > 100) {
      for (var start = 0; start < unsynced.length; start += 100) {
        final end = (start + 100).clamp(0, unsynced.length);
        await _pushSessions(unsynced.sublist(start, end));
      }
      return;
    }

    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/focus-sessions/batch',
        options: await _options(),
        data: {'items': unsynced.map(_toPayload).toList()},
      );

      final idMap = resp.data?['id_map'] as Map<String, dynamic>?;
      if (idMap == null) return;
      for (final session in unsynced) {
        final serverId = idMap['${session.id}']?.toString();
        if (serverId == null || serverId.isEmpty) continue;
        await _repo.updateServerId(localId: session.id, serverId: serverId);
        final update = await _dio.patch<Map<String, dynamic>>(
          '/api/v1/focus-sessions/batch',
          options: await _options(),
          data: {
            'items': [
              {
                'id': serverId,
                'excluded_from_stats': session.excludedFromStats,
              },
            ],
          },
        );
        if ((update.data?['updated_ids'] as List? ?? []).contains(serverId)) {
          await _repo.markSynced(session, serverId);
        }
      }
    } catch (_) {
      // 保留本地 pending，下次登录或启动后补传。
    }
  }

  Map<String, dynamic> _toPayload(FocusSession session) {
    return {
      'local_id': session.id,
      'client_id': session.clientId,
      'started_at': session.startedAt.toUtc().toIso8601String(),
      'ended_at': session.endedAt.toUtc().toIso8601String(),
      'duration_seconds': session.durationSeconds,
      'trigger_type': session.triggerType,
      'is_failed': session.isFailed,
      'excluded_from_stats': session.excludedFromStats,
      'created_at': session.endedAt.toIso8601String(),
      'updated_at': session.endedAt.toIso8601String(),
    };
  }

  Future<void> syncOnLogin() => _queue.run(() async {
    await _pushPending();
    try {
      String? cursor;
      final seenCursors = <String>{};
      do {
        final response = await _dio.get<Map<String, dynamic>>(
          '/api/v1/focus-sessions',
          options: await _options(),
          queryParameters: {'limit': 100, 'after': ?cursor},
        );
        for (final item in (response.data?['items'] as List? ?? [])) {
          await _repo.upsertFromServer(Map<String, dynamic>.from(item as Map));
        }
        cursor = response.data?['next_cursor'] as String?;
        if (cursor != null && !seenCursors.add(cursor)) {
          throw StateError('Repeated sync cursor');
        }
      } while (cursor != null);
    } catch (_) {
      /* local records remain usable */
    }
  });
}

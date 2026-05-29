import 'package:dio/dio.dart';

import '../../models/app_database.dart';
import '../../repositories/focus_session_repository.dart';
import '../api/api_client.dart';

class FocusSessionSyncService {
  const FocusSessionSyncService(this._repo);

  final FocusSessionRepository _repo;
  Dio get _dio => ApiClient.instance.dio;

  Future<void> pushPending() async {
    final pending = await _repo.getPendingSync();
    if (pending.isEmpty) return;
    await pushSessions(pending);
  }

  Future<void> pushSession(FocusSession session) {
    return pushSessions([session]);
  }

  Future<void> pushSessions(List<FocusSession> sessions) async {
    final unsynced = sessions
        .where((session) => session.serverId == null)
        .toList(growable: false);
    if (unsynced.isEmpty) return;

    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/focus-sessions/batch',
        data: {'items': unsynced.map(_toPayload).toList()},
      );

      final idMap = resp.data?['id_map'] as Map<String, dynamic>?;
      if (idMap == null) return;
      for (final session in unsynced) {
        final serverId = idMap['${session.id}']?.toString();
        if (serverId == null || serverId.isEmpty) continue;
        await _repo.updateServerId(localId: session.id, serverId: serverId);
      }
    } on DioException {
      // 保留本地 pending，下次登录或启动后补传。
    }
  }

  Map<String, dynamic> _toPayload(FocusSession session) {
    return {
      'local_id': session.id,
      'started_at': session.startedAt.toIso8601String(),
      'ended_at': session.endedAt.toIso8601String(),
      'duration_seconds': session.durationSeconds,
      'trigger_type': session.triggerType,
      'is_failed': session.isFailed,
      'excluded_from_stats': session.excludedFromStats,
      'created_at': session.endedAt.toIso8601String(),
      'updated_at': session.endedAt.toIso8601String(),
    };
  }
}

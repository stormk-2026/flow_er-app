import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/app_database.dart';
import '../../repositories/intent_repository.dart';
import '../api/api_client.dart';
import '../uploads/image_upload_service.dart';
import 'sync_queue.dart';

const _intentLastSyncedAtKey = 'intent_last_synced_at';

/// 登录后调 [syncOnLogin] 把远端数据拉到本地。
/// 本地新增后调 [pushIntent] 推送到远端，再用后端打标结果刷新本地。
class IntentSyncService {
  IntentSyncService(
    this._repo, {
    this.account,
    Dio? dio,
    Future<Options> Function()? optionsProvider,
    ImageUploadService? uploads,
  }) : _client = dio,
       _optionsProvider = optionsProvider,
       _uploads = uploads ?? const ImageUploadService();

  final SyncQueue _queue = SyncQueue();
  final Dio? _client;
  final Future<Options> Function()? _optionsProvider;
  final ImageUploadService _uploads;

  final String? account;
  Future<Options> _options() =>
      _optionsProvider?.call() ?? ApiClient.instance.accountOptions(account);
  String get _checkpointKey => '${_intentLastSyncedAtKey}_v2_$account';

  final IntentRepository _repo;
  Dio get _dio => _client ?? ApiClient.instance.dio;

  /// 登录后全量拉取远端心笺，合并到本地（以 serverId 去重）。
  Future<void> syncOnLogin() => refreshSnapshot();

  /// 首次不带 since 全量拉取；之后带 since 增量拉取。
  Future<void> pullAll() =>
      _queue.run(() => _pull(useSince: true, updateCheckpoint: true));

  /// 用于刷新异步生成的字段（如 ai_comment）。
  ///
  /// 与写入共用串行队列；完整分页处理后才推进同步游标。
  Future<void> refreshSnapshot() => _queue.run(() async {
    await _pushPending();
    await _pull(useSince: true, updateCheckpoint: true);
  });

  Future<void> _pull({
    required bool useSince,
    required bool updateCheckpoint,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final since = useSince ? prefs.getString(_checkpointKey) : null;
      String? cursor;
      String? serverTime;
      final seenCursors = <String>{};
      do {
        final resp = await _dio.get<Map<String, dynamic>>(
          '/api/v1/intents',
          options: await _options(),
          queryParameters: {'since': ?since, 'cursor': ?cursor, 'limit': 100},
        );
        final items = (resp.data?['items'] as List?) ?? [];
        for (final item in items.cast<Map<String, dynamic>>()) {
          if (_isTombstone(item)) {
            await _repo.deleteByServerId(item['id'] as String);
          } else {
            await _repo.upsertFromServer(item);
          }
        }

        serverTime = resp.data?['server_time'] as String?;
        cursor = resp.data?['next_cursor'] as String?;
        if (cursor != null && !seenCursors.add(cursor)) {
          throw StateError('Repeated sync cursor');
        }
      } while (cursor != null);
      if (updateCheckpoint && serverTime != null && serverTime.isNotEmpty) {
        await prefs.setString(_checkpointKey, serverTime);
      }
    } catch (_) {
      // 同步失败不影响本地使用
    }
  }

  Future<void> pushPending() => _queue.run(_pushPending);

  Future<void> _pushPending() async {
    for (final deleted in await _repo.getPendingDeletes()) {
      await _pushDelete(deleted);
    }
    final pending = await _repo.getPendingSync();
    for (final intent in pending) {
      if (!intent.pendingDelete) await _pushIntent(intent);
    }
  }

  /// 把本地一条记录推送到后端，成功后回写 serverId。
  Future<void> pushIntent(FlowIntent intent) =>
      _queue.run(() => _pushIntent(intent));

  Future<void> _pushIntent(FlowIntent requested) async {
    try {
      // Queued input may be stale after another retry or an immediate local delete.
      final intent = await _repo.findLocal(requested.id);
      if (intent == null || intent.pendingDelete || intent.serverId != null) {
        return;
      }
      final tags = _decodeList(intent.tags);
      final options = await _options();
      final attachments = await _uploads.uploadImages(
        _decodeList(intent.attachments).cast<String>(),
        options: options,
        onProgress: (paths) => _repo.updateAttachments(intent.id, paths),
      );
      await _repo.updateAttachments(intent.id, attachments);

      final current = await _repo.findLocal(intent.id);
      if (current == null || current.pendingDelete) return;
      await _options(); // Do not start another request after this account signed out.

      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/intents/batch',
        options: options,
        data: {
          'items': [
            {
              'local_id': intent.id,
              'client_id': intent.clientId,
              'title': intent.title,
              'raw_input': intent.rawInput,
              'note': intent.note,
              'due_at': intent.dueAt?.toIso8601String(),
              'priority': intent.priority,
              'tags': tags,
              'attachments': attachments,
              'status': intent.status,
              'created_at': intent.createdAt.toIso8601String(),
              'updated_at': intent.updatedAt.toIso8601String(),
            },
          ],
        },
      );

      // 后端返回 id_map: { "local_id": "server_uuid" }
      final idMap = resp.data?['id_map'] as Map<String, dynamic>?;
      final serverId = idMap?['${intent.id}'] as String?;
      if (serverId != null) {
        await _repo.updateServerId(localId: intent.id, serverId: serverId);
        final serverItem = _findCreatedItem(resp.data, serverId);
        if (serverItem != null && _isTombstone(serverItem)) {
          await _repo.deleteByServerId(serverId);
        } else if (serverItem != null) {
          await _repo.upsertFromServer(serverItem);
        } else {
          await _pull(useSince: true, updateCheckpoint: true);
        }
      }
    } catch (_) {
      // 推送失败静默，下次登录 syncOnLogin 会补齐
    }
  }

  Future<void> deleteIntent(FlowIntent intent) async {
    await _repo.markDeleted(intent.id);
    await _queue.run(() => _pushDelete(intent));
  }

  Future<void> _pushDelete(FlowIntent intent) async {
    try {
      final response = await _dio.delete<void>(
        '/api/v1/intents/by-client/${intent.clientId}',
        options: await _options(),
      );
      if (response.statusCode == 204) await _repo.deleteLocal(intent.id);
    } on DioException {
      // A missing route (old backend) is not an acknowledged durable tombstone.
      // Retain the outbox unless the v2 server explicitly acknowledges deletion.
    } catch (_) {
      // Durable tombstone stays hidden locally until acknowledged.
    }
  }

  Map<String, dynamic>? _findCreatedItem(
    Map<String, dynamic>? data,
    String serverId,
  ) {
    final candidates = [
      data?['items'],
      data?['created'],
      data?['intents'],
      data?['data'],
    ];
    for (final candidate in candidates) {
      if (candidate is List) {
        for (final item in candidate) {
          if (item is Map<String, dynamic> && item['id'] == serverId) {
            return item;
          }
        }
      }
    }
    return null;
  }

  List<dynamic> _decodeList(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded;
    } catch (_) {}
    return const [];
  }

  bool _isTombstone(Map<String, dynamic> item) {
    return item['id'] is String &&
        item['deleted_at'] != null &&
        !item.containsKey('raw_input');
  }
}

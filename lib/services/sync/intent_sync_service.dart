import 'dart:convert';

import 'package:dio/dio.dart';

import '../../models/app_database.dart';
import '../../repositories/intent_repository.dart';
import '../api/api_client.dart';

/// 登录后调 [syncOnLogin] 把远端数据拉到本地。
/// 本地新增后调 [pushIntent] 推送到远端，再用后端打标结果刷新本地。
class IntentSyncService {
  const IntentSyncService(this._repo);

  final IntentRepository _repo;
  Dio get _dio => ApiClient.instance.dio;

  /// 登录后全量拉取远端心笺，合并到本地（以 serverId 去重）。
  Future<void> syncOnLogin() async {
    await pushPending();
    await pullAll();
  }

  Future<void> pullAll() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/api/v1/intents');
      final items = (resp.data?['items'] as List?) ?? [];
      for (final item in items.cast<Map<String, dynamic>>()) {
        await _repo.upsertFromServer(item);
      }
    } on DioException {
      // 同步失败不影响本地使用
    }
  }

  Future<void> pushPending() async {
    final pending = await _repo.getPendingSync();
    for (final intent in pending) {
      await pushIntent(intent);
    }
  }

  /// 把本地一条记录推送到后端，成功后回写 serverId。
  Future<void> pushIntent(FlowIntent intent) async {
    try {
      final tags = _decodeList(intent.tags);
      final attachments = _decodeList(intent.attachments);

      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/intents/batch',
        data: {
          'items': [
            {
              'local_id': intent.id,
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
        if (serverItem != null) {
          await _repo.upsertFromServer(serverItem);
          await _repo.deleteLocal(intent.id);
        } else {
          await pullAll();
        }
      }
    } on DioException {
      // 推送失败静默，下次登录 syncOnLogin 会补齐
    }
  }

  Future<void> updateIntent(FlowIntent intent) async {
    final serverId = intent.serverId;
    if (serverId == null) {
      await pushIntent(intent);
      return;
    }

    try {
      final tags = _decodeList(intent.tags);
      final attachments = _decodeList(intent.attachments);
      final resp = await _dio.patch<Map<String, dynamic>>(
        '/api/v1/intents/$serverId',
        data: {
          'title': intent.title,
          'raw_input': intent.rawInput,
          'note': intent.note,
          'due_at': intent.dueAt?.toIso8601String(),
          'priority': intent.priority,
          'tags': tags,
          'attachments': attachments,
          'status': intent.status,
          'updated_at': intent.updatedAt.toIso8601String(),
        },
      );
      final item = _extractIntent(resp.data, serverId);
      if (item != null) {
        await _repo.upsertFromServer(item);
      } else {
        await pullAll();
      }
    } on DioException {
      // 本地已更新，后续同步时会以本地数据继续展示。
    }
  }

  Future<void> deleteIntent(FlowIntent intent) async {
    final serverId = intent.serverId;
    await _repo.deleteLocal(intent.id);
    if (serverId == null) return;

    try {
      await _dio.delete<void>('/api/v1/intents/$serverId');
    } on DioException {
      // 删除失败时不恢复本地卡片，避免用户操作后又闪回。
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

  Map<String, dynamic>? _extractIntent(
    Map<String, dynamic>? data,
    String serverId,
  ) {
    if (data == null) return null;
    if (data['id'] == serverId) return data;
    final item = data['item'];
    if (item is Map<String, dynamic> && item['id'] == serverId) return item;
    final intent = data['intent'];
    if (intent is Map<String, dynamic> && intent['id'] == serverId) {
      return intent;
    }
    return _findCreatedItem(data, serverId);
  }

  List<dynamic> _decodeList(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded;
    } catch (_) {}
    return const [];
  }
}

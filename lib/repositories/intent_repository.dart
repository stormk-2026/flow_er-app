import 'dart:convert';

import 'package:drift/drift.dart';

import '../models/app_database.dart';
import '../models/parsed_intent.dart';
import '../models/thought_capture_mode.dart';
import '../core/record_id.dart';

class IntentRepository {
  const IntentRepository(this._db);

  final AppDatabase _db;

  Future<FlowIntent?> findLocal(int id) => (_db.select(
    _db.flowIntents,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  // watch() 返回 Stream，和 Room DAO 的 Flow<List<T>> 完全一样
  Stream<List<FlowIntent>> watchAll() {
    return (_db.select(_db.flowIntents)
          ..where((t) => t.pendingDelete.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<List<FlowIntent>> getPendingSync() {
    return (_db.select(
      _db.flowIntents,
    )..where((t) => t.serverId.isNull())).get();
  }

  Stream<int> watchPendingCount() => _db
      .select(_db.flowIntents)
      .watch()
      .map(
        (rows) =>
            rows.where((r) => r.serverId == null || r.pendingDelete).length,
      );

  Future<FlowIntent> saveParsed(ParsedIntent parsed) async {
    final now = DateTime.now();
    final id = await _db
        .into(_db.flowIntents)
        .insert(
          FlowIntentsCompanion.insert(
            clientId: Value(newRecordId()),
            title: parsed.title,
            rawInput: parsed.rawInput,
            note: Value(parsed.note),
            dueAt: Value(parsed.dueAt),
            priority: Value(parsed.priority.name),
            tags: Value(jsonEncode(parsed.tags)),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (_db.select(
      _db.flowIntents,
    )..where((t) => t.id.equals(id))).getSingle();
  }

  Future<FlowIntent?> saveJournal({
    required ThoughtCaptureMode mode,
    required String quickText,
    required String title,
    required String body,
    List<String> imagePaths = const [],
  }) async {
    final now = DateTime.now();
    late final String resolvedTitle;
    late final String rawInput;
    String? note;

    if (mode == ThoughtCaptureMode.quick) {
      final text = quickText.trim();
      if (text.isEmpty) return null;
      resolvedTitle = text.length > 48 ? '${text.substring(0, 48)}…' : text;
      rawInput = text;
    } else {
      final t = title.trim();
      final b = body.trim();
      if (t.isEmpty && b.isEmpty && imagePaths.isEmpty) return null;
      resolvedTitle = t.isNotEmpty
          ? t
          : (b.length > 32
                ? '${b.substring(0, 32)}…'
                : b.isNotEmpty
                ? b
                : '心笺');
      rawInput = [t, b].where((s) => s.isNotEmpty).join('\n');
      note = b.isNotEmpty ? b : null;
    }

    final id = await _db
        .into(_db.flowIntents)
        .insert(
          FlowIntentsCompanion.insert(
            clientId: Value(newRecordId()),
            title: resolvedTitle,
            rawInput: rawInput,
            note: Value(note),
            tags: Value(jsonEncode(const <String>[])),
            attachments: Value(jsonEncode(imagePaths)),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (_db.select(
      _db.flowIntents,
    )..where((t) => t.id.equals(id))).getSingle();
  }

  /// 从服务端数据 upsert：有 serverId 则更新，否则插入。
  Future<void> upsertFromServer(Map<String, dynamic> item) =>
      _db.transaction(() => _upsertFromServer(item));

  Future<void> _upsertFromServer(Map<String, dynamic> item) async {
    final serverId = item['id'] as String?;
    if (serverId == null) return;

    final clientId = item['client_id'] as String?;
    final existing =
        await (_db.select(_db.flowIntents)..where(
              (t) =>
                  t.serverId.equals(serverId) |
                  (clientId == null
                      ? const Constant(false)
                      : t.clientId.equals(clientId)),
            ))
            .getSingleOrNull();
    if (existing?.pendingDelete == true) return;

    final createdAt = item['created_at'] != null
        ? DateTime.tryParse(item['created_at'] as String) ?? DateTime.now()
        : DateTime.now();
    final updatedAt = item['updated_at'] != null
        ? DateTime.tryParse(item['updated_at'] as String) ?? DateTime.now()
        : DateTime.now();
    final aiComment = _stringField(item, const ['ai_comment', 'aiComment']);

    final companion = FlowIntentsCompanion(
      clientId: Value((item['client_id'] as String?) ?? serverId),
      serverId: Value(serverId),
      title: Value((item['title'] as String?) ?? ''),
      rawInput: Value((item['raw_input'] as String?) ?? ''),
      note: Value(item['note'] as String?),
      dueAt: Value(
        item['due_at'] != null
            ? DateTime.tryParse(item['due_at'] as String)
            : null,
      ),
      priority: Value((item['priority'] as String?) ?? 'medium'),
      tags: Value(jsonEncode(item['tags'] ?? [])),
      attachments: Value(jsonEncode(item['attachments'] ?? [])),
      aiComment: item.containsKey('ai_comment') || item.containsKey('aiComment')
          ? Value(aiComment)
          : const Value.absent(),
      status: Value((item['status'] as String?) ?? 'open'),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );

    if (existing == null) {
      await _db.into(_db.flowIntents).insert(companion);
    } else {
      // An older response may carry a fresh signed URL, but must not roll back
      // the journal text or an AI result. Equal versions may refresh URL expiry.
      if (!updatedAt.isBefore(existing.updatedAt)) {
        await (_db.update(
          _db.flowIntents,
        )..where((t) => t.id.equals(existing.id))).write(companion);
      } else if (existing.serverId == null) {
        await updateServerId(localId: existing.id, serverId: serverId);
      }
    }
  }

  /// 本地记录推送成功后回写 serverId。
  Future<void> updateServerId({
    required int localId,
    required String serverId,
  }) {
    return (_db.update(_db.flowIntents)..where((t) => t.id.equals(localId)))
        .write(FlowIntentsCompanion(serverId: Value(serverId)));
  }

  Future<void> deleteLocal(int localId) {
    return (_db.delete(
      _db.flowIntents,
    )..where((t) => t.id.equals(localId))).go();
  }

  Future<List<FlowIntent>> getPendingDeletes() => (_db.select(
    _db.flowIntents,
  )..where((t) => t.pendingDelete.equals(true))).get();

  Future<void> markDeleted(int id) =>
      (_db.update(_db.flowIntents)..where((t) => t.id.equals(id))).write(
        const FlowIntentsCompanion(pendingDelete: Value(true)),
      );

  Future<void> updateAttachments(int id, List<String> paths) =>
      (_db.update(_db.flowIntents)..where((t) => t.id.equals(id))).write(
        FlowIntentsCompanion(attachments: Value(jsonEncode(paths))),
      );

  Future<void> deleteByServerId(String serverId) {
    return (_db.delete(
      _db.flowIntents,
    )..where((t) => t.serverId.equals(serverId))).go();
  }

  String? _stringField(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final value = item[key];
      if (value is String) return value;
    }
    return null;
  }
}

import 'dart:convert';

import 'package:drift/drift.dart';

import '../models/app_database.dart';
import '../models/parsed_intent.dart';
import '../models/thought_capture_mode.dart';

class IntentRepository {
  const IntentRepository(this._db);

  final AppDatabase _db;

  // watch() 返回 Stream，和 Room DAO 的 Flow<List<T>> 完全一样
  Stream<List<FlowIntent>> watchAll() {
    return (_db.select(
      _db.flowIntents,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();
  }

  Future<List<FlowIntent>> getPendingSync() {
    return (_db.select(
      _db.flowIntents,
    )..where((t) => t.serverId.isNull())).get();
  }

  Future<FlowIntent> saveParsed(ParsedIntent parsed) async {
    final now = DateTime.now();
    final id = await _db
        .into(_db.flowIntents)
        .insert(
          FlowIntentsCompanion.insert(
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
  Future<void> upsertFromServer(Map<String, dynamic> item) async {
    final serverId = item['id'] as String?;
    if (serverId == null) return;

    final existing = await (_db.select(
      _db.flowIntents,
    )..where((t) => t.serverId.equals(serverId))).getSingleOrNull();

    final createdAt = item['created_at'] != null
        ? DateTime.tryParse(item['created_at'] as String) ?? DateTime.now()
        : DateTime.now();
    final updatedAt = item['updated_at'] != null
        ? DateTime.tryParse(item['updated_at'] as String) ?? DateTime.now()
        : DateTime.now();
    final aiComment = _stringField(item, const ['ai_comment', 'aiComment']);

    final companion = FlowIntentsCompanion(
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
      // 以 updated_at 较新的为准
      final hasNewAiComment =
          aiComment != null &&
          aiComment.trim().isNotEmpty &&
          aiComment != existing.aiComment;
      if (updatedAt.isAfter(existing.updatedAt) || hasNewAiComment) {
        await (_db.update(
          _db.flowIntents,
        )..where((t) => t.serverId.equals(serverId))).write(companion);
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

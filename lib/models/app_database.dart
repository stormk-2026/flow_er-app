import 'dart:io';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

// Drift 的 Table 定义 ≈ Android Room 的 @Entity
// 每个字段对应数据库的一列，类型由 Dart 类型推断
class FlowIntents extends Table {
  TextColumn get clientId => text().withDefault(const Constant(''))();
  BoolColumn get pendingDelete =>
      boolean().withDefault(const Constant(false))();
  IntColumn get id => integer().autoIncrement()();
  TextColumn get serverId => text().nullable()(); // 后端 UUID
  TextColumn get title => text()();
  TextColumn get rawInput => text()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get dueAt => dateTime().nullable()();
  TextColumn get priority => text().withDefault(const Constant('medium'))();
  TextColumn get tags => text().withDefault(const Constant('[]'))();
  TextColumn get attachments => text().withDefault(const Constant('[]'))();
  TextColumn get aiComment => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('open'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

class FocusSessions extends Table {
  TextColumn get clientId => text().withDefault(const Constant(''))();
  BoolColumn get syncDirty => boolean().withDefault(const Constant(true))();
  IntColumn get id => integer().autoIncrement()();
  TextColumn get serverId => text().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime()();
  IntColumn get durationSeconds => integer()();
  TextColumn get triggerType => text()();
  BoolColumn get isFailed => boolean()();
  BoolColumn get excludedFromStats =>
      boolean().withDefault(const Constant(false))();
}

// @DriftDatabase ≈ @Database in Room — 声明数据库包含哪些表
@DriftDatabase(tables: [FlowIntents, FocusSessions])
class AppDatabase extends _$AppDatabase {
  AppDatabase({String account = 'guest'}) : super(_openConnection(account));
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(focusSessions);
      }
      if (from < 3) {
        await migrator.addColumn(flowIntents, flowIntents.attachments);
      }
      if (from < 4) {
        await migrator.addColumn(flowIntents, flowIntents.serverId);
      }
      if (from < 5) {
        await migrator.addColumn(focusSessions, focusSessions.serverId);
      }
      if (from < 6) {
        await migrator.addColumn(flowIntents, flowIntents.aiComment);
      }
      if (from < 7) {
        await migrator.addColumn(flowIntents, flowIntents.clientId);
        await migrator.addColumn(flowIntents, flowIntents.pendingDelete);
        await migrator.addColumn(focusSessions, focusSessions.clientId);
        await migrator.addColumn(focusSessions, focusSessions.syncDirty);
      }
    },
  );
}

String accountDatabaseName(String account) =>
    'flow_er_v2_${base64Url.encode(utf8.encode(account.trim().toLowerCase())).replaceAll('=', '')}.sqlite';

LazyDatabase _openConnection(String account) {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    // Never automatically adopt the legacy shared database: its owner is unknown.
    final file = File(p.join(dir.path, accountDatabaseName(account)));
    return NativeDatabase.createInBackground(file);
  });
}

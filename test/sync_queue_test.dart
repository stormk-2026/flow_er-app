import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flow_er/models/app_database.dart';
import 'package:flow_er/models/thought_capture_mode.dart';
import 'package:flow_er/repositories/intent_repository.dart';
import 'package:flow_er/services/sync/intent_sync_service.dart';
import 'package:flow_er/services/sync/sync_queue.dart';
import 'package:flow_er/services/uploads/image_upload_service.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final FutureOr<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object data, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(data),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

class _Uploads extends ImageUploadService {
  _Uploads(this.upload);
  final Future<String> Function(String) upload;
  @override
  Future<String> uploadImage(File file, {Options? options}) =>
      upload(file.path);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('queue is serial and recovers after a failed operation', () async {
    final queue = SyncQueue();
    final gate = Completer<void>();
    final events = <String>[];
    final first = queue.run(() async {
      events.add('first');
      await gate.future;
      throw StateError('offline');
    });
    final assertion = expectLater(first, throwsStateError);
    final second = queue.run(() async {
      events.add('second');
      return 42;
    });
    await Future<void>.delayed(Duration.zero);
    expect(events, ['first']);
    gate.complete();
    await assertion;
    expect(await second, 42);
    expect(events, ['first', 'second']);
  });

  late AppDatabase db;
  late IntentRepository repo;
  late Dio dio;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = IntentRepository(db);
    dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  });
  tearDown(() async {
    dio.close();
    await db.close();
  });

  Future<FlowIntent> save([List<String> images = const []]) async =>
      (await repo.saveJournal(
        mode: ThoughtCaptureMode.expanded,
        quickText: '',
        title: 'test',
        body: 'body',
        imagePaths: images,
      ))!;
  IntentSyncService service({ImageUploadService? uploads}) => IntentSyncService(
    repo,
    account: 'a@example.com',
    dio: dio,
    optionsProvider: () async => Options(),
    uploads: uploads,
  );

  test(
    'an asynchronous delete acceptance is not a durable acknowledgement',
    () async {
      final row = await save();
      dio.httpClientAdapter = _Adapter((_) => _json({}, 202));
      await service().deleteIntent(row);
      expect(await repo.getPendingDeletes(), hasLength(1));
    },
  );

  test(
    'server tombstone returned on upload removes the stale local journal',
    () async {
      final row = await save();
      dio.httpClientAdapter = _Adapter(
        (_) => _json({
          'id_map': {'${row.id}': 'server-1'},
          'items': [
            {
              'id': 'server-1',
              'client_id': row.clientId,
              'deleted_at': '2026-01-01T00:00:00Z',
            },
          ],
        }),
      );
      await service().pushIntent(row);
      expect(await repo.findLocal(row.id), isNull);
    },
  );

  test('concurrent retries of one journal produce only one POST', () async {
    final row = await save();
    var posts = 0;
    dio.httpClientAdapter = _Adapter((request) {
      if (request.method == 'POST') {
        posts++;
        return _json({
          'id_map': {'${row.id}': 'server-1'},
          'items': [
            {
              'id': 'server-1',
              'client_id': row.clientId,
              'updated_at': row.updatedAt.toIso8601String(),
            },
          ],
        });
      }
      return _json({'items': []});
    });
    final sync = service();
    await Future.wait([
      sync.pushIntent(row),
      sync.pushIntent(row),
      sync.pushPending(),
    ]);
    expect(posts, 1);
    expect(await repo.watchAll().first, hasLength(1));
    expect((await repo.findLocal(row.id))!.serverId, 'server-1');
  });

  test(
    '404 from an old delete route retains the hidden deletion outbox',
    () async {
      final row = await save();
      dio.httpClientAdapter = _Adapter(
        (_) => _json({'detail': 'Not Found'}, 404),
      );
      await service().deleteIntent(row);
      expect(await repo.watchAll().first, isEmpty);
      expect(await repo.getPendingDeletes(), hasLength(1));
    },
  );

  test(
    'deletion during upload does not submit or resurrect the journal',
    () async {
      final started = Completer<void>(), finish = Completer<String>();
      final row = await save(['/first.jpg']);
      var posts = 0;
      dio.httpClientAdapter = _Adapter((request) {
        if (request.method == 'POST') posts++;
        return _json({}, request.method == 'DELETE' ? 204 : 200);
      });
      final sync = service(
        uploads: _Uploads((_) {
          started.complete();
          return finish.future;
        }),
      );
      final push = sync.pushIntent(row);
      await started.future;
      // Marking a deletion is immediate, even while the network queue is busy.
      final deletion = sync.deleteIntent(row);
      await repo.watchAll().firstWhere((rows) => rows.isEmpty);
      finish.complete('https://example.test/first.jpg');
      await Future.wait([push, deletion]);
      expect(posts, 0);
      expect(await repo.findLocal(row.id), isNull);
    },
  );

  test('a partial upload is persisted and not repeated on retry', () async {
    final row = await save(['/first.jpg', '/second.jpg']);
    final calls = <String>[];
    var failSecond = true;
    final sync = service(
      uploads: _Uploads((path) async {
        calls.add(path);
        if (path == '/second.jpg' && failSecond) throw StateError('offline');
        return 'https://example.test$path';
      }),
    );
    dio.httpClientAdapter = _Adapter(
      (_) => _json({
        'id_map': {'${row.id}': 'server-1'},
        'items': [
          {
            'id': 'server-1',
            'client_id': row.clientId,
            'updated_at': row.updatedAt.toIso8601String(),
            'attachments': [
              'https://example.test/first.jpg',
              'https://example.test/second.jpg',
            ],
          },
        ],
      }),
    );
    await sync.pushIntent(row);
    expect(jsonDecode((await repo.findLocal(row.id))!.attachments), [
      'https://example.test/first.jpg',
      '/second.jpg',
    ]);
    failSecond = false;
    await sync.pushIntent(row);
    expect(calls, ['/first.jpg', '/second.jpg', '/second.jpg']);
    expect((await repo.findLocal(row.id))!.serverId, 'server-1');
  });

  test(
    'repeated pagination cursor aborts without advancing checkpoint',
    () async {
      var requests = 0;
      dio.httpClientAdapter = _Adapter((_) {
        requests++;
        return _json({
          'items': [],
          'next_cursor': 'same',
          'server_time': 'future',
        });
      });
      await service().pullAll();
      expect(requests, 2);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('intent_last_synced_at_v2_a@example.com'), isNull);
    },
  );
}

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flow_er/features/settings/privacy_page.dart';
import 'package:flow_er/providers/auth_provider.dart';
import 'package:flow_er/repositories/auth_repository.dart';
import 'package:flow_er/services/api/api_client.dart';

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

ResponseBody _json(Object value, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(value),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

class _SignedInAuth extends AuthController {
  @override
  Future<AuthSession?> build() async =>
      const AuthSession(email: 'b@example.com', nickname: 'B');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('公开隐私政策入口在登录前可见', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(const MaterialApp(home: PrivacyNoticePage()));
    expect(find.text('查看公开版隐私政策（英文）'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
  });

  testWidgets('隐私页不再显示开关；撤回授权须确认且可以取消', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final client = ApiClient.instance.dio;
    final originalAdapter = client.httpClientAdapter;
    final writes = <Object?>[];
    client.httpClientAdapter = _Adapter((request) {
      if (request.method == 'PUT') {
        writes.add(request.data);
        return _json({}, 204);
      }
      return _json({'ai_consent': true});
    });
    addTearDown(() => client.httpClientAdapter = originalAdapter);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith(_SignedInAuth.new)],
        child: const MaterialApp(home: PrivacyPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SwitchListTile), findsNothing);
    await tester.scrollUntilVisible(
      find.text('查看公开版隐私政策（英文）'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('查看公开版隐私政策（英文）'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('撤回 AI 授权'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('撤回 AI 授权'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('撤回 AI 授权'));
    await tester.pumpAndSettle();
    expect(find.text('撤回 AI 授权？'), findsOneWidget);
    await tester.tap(find.text('保留授权'));
    await tester.pumpAndSettle();
    expect(writes, isEmpty);
    await tester.tap(find.text('撤回 AI 授权'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('撤回授权'));
    await tester.pumpAndSettle();
    expect(writes, [
      {'enabled': false},
    ]);
    expect(find.text('尚未授权'), findsOneWidget);
    expect(find.text('阅读并授权 AI 回响'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('注销账号'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('注销前需验证当前登录邮箱'), findsOneWidget);
    expect(find.textContaining('b@example.com'), findsNothing);
    expect(privacyText, contains('gg5605568@gmail.com'));
    expect(privacyText, contains('7 天期限轮换'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final previousConsent in [false, true]) {
    for (final optIn in [false, true]) {
      test(
        'existing=$previousConsent opt-in=$optIn: only explicit new consent is written before session',
        () async {
          final calls = <String>[];
          final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
          dio.httpClientAdapter = _Adapter((request) async {
            calls.add(request.path);
            expect(await ApiClient.instance.getToken(), isNull);
            if (request.path.endsWith('verify-code')) {
              return _json({
                'token': 'verified-token',
                'is_new_user': false,
                'user': {
                  'email': 'b@example.com',
                  'nickname': 'B',
                  'ai_consent': previousConsent,
                },
              });
            }
            expect(request.path, '/api/v1/auth/ai-consent');
            expect(request.data, {'enabled': true});
            expect(request.extra['fixedToken'], 'verified-token');
            expect(request.headers['Authorization'], 'Bearer verified-token');
            return _json({}, 204);
          });
          final result = await AuthRepository(
            dio: dio,
          ).verifyCode(email: 'b@example.com', code: '123456', enableAi: optIn);
          expect(calls.length, optIn && !previousConsent ? 2 : 1);
          expect(result.aiConsentSaveFailed, isFalse);
          expect(await ApiClient.instance.storedAccount(), 'b@example.com');
          expect(await ApiClient.instance.getToken(), 'verified-token');
          dio.close();
        },
      );
    }
  }

  test(
    'consent failure reports separately without retrying the consumed login code',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
      dio.httpClientAdapter = _Adapter((request) {
        if (request.path.endsWith('verify-code')) {
          return _json({
            'token': 'verified-token',
            'is_new_user': true,
            'user': {
              'email': 'b@example.com',
              'nickname': '',
              'ai_consent': false,
            },
          });
        }
        return _json({'detail': 'unavailable'}, 503);
      });
      final result = await AuthRepository(
        dio: dio,
      ).verifyCode(email: 'b@example.com', code: '123456', enableAi: true);
      expect(result.aiConsentSaveFailed, isTrue);
      expect(result.isNewUser, isTrue);
      expect(await ApiClient.instance.storedAccount(), 'b@example.com');
      dio.close();
    },
  );

  test('invalid email code never sends consent or creates a session', () async {
    final paths = <String>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
    dio.httpClientAdapter = _Adapter((request) {
      paths.add(request.path);
      return _json({}, 400);
    });
    await expectLater(
      AuthRepository(
        dio: dio,
      ).verifyCode(email: 'b@example.com', code: '123456', enableAi: true),
      throwsA(isA<DioException>()),
    );
    expect(paths, ['/api/v1/auth/verify-code']);
    expect(await ApiClient.instance.getToken(), isNull);
    dio.close();
  });
}

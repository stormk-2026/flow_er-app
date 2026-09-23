import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flow_er/features/auth/auth_page.dart';
import 'package:flow_er/core/i18n/ui_text.dart';
import 'package:flow_er/providers/auth_provider.dart';
import 'package:flow_er/repositories/auth_repository.dart';

class _FakeEmailAuth extends AuthController {
  final sent = <String>[];
  String? verifiedEmail;
  String? verifiedCode;
  bool? requestedAi;
  @override
  Future<AuthSession?> build() async => null;
  @override
  Future<String?> sendCode(String email) async {
    sent.add(email);
    return null;
  }

  @override
  Future<VerifyResult> verifyCode({
    required String email,
    required String code,
    bool enableAi = false,
  }) async {
    verifiedEmail = email;
    verifiedCode = code;
    requestedAi = enableAi;
    return VerifyResult(
      token: 'test',
      isNewUser: true,
      email: email,
      nickname: '',
    );
  }
}

void main() {
  testWidgets('login language toggle exposes English before sign-in', (
    tester,
  ) async {
    UiText.english = false;
    addTearDown(() => UiText.english = false);
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith(_FakeEmailAuth.new)],
        child: const MaterialApp(home: AuthPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Send verification code'), findsOneWidget);
    expect(find.text('Privacy Notice'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('邮箱格式校验、发送、冷却和新用户昵称流程', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = _FakeEmailAuth();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith(() => auth)],
        child: const MaterialApp(home: AuthPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('验证邮箱后自动注册或登录'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.textContaining('同意后开启'), findsNothing);
    expect(find.textContaining('Kimi'), findsNothing);
    expect(find.textContaining('Moonshot'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), '12345');
    await tester.tap(find.byKey(const ValueKey('privacy-consent')));
    await tester.pump();
    await tester.tap(find.text('获取验证码'));
    await tester.pump();
    expect(find.text('请输入正确的邮箱'), findsOneWidget);
    expect(auth.sent, isEmpty);
    await tester.enterText(find.byType(TextField), 'Tester@QQ.com');
    await tester.tap(find.text('获取验证码'));
    await tester.pump();
    expect(auth.sent, isEmpty);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('请先阅读并同意隐私说明和 AI 回响功能说明'), findsOneWidget);
    expect(
      tester
          .widget<Checkbox>(find.byKey(const ValueKey('privacy-consent')))
          .value,
      isFalse,
    );
    await tester.tap(find.byKey(const ValueKey('privacy-consent')));
    await tester.pump();
    await tester.tap(find.text('获取验证码'));
    await tester.pumpAndSettle();
    expect(auth.sent, ['tester@qq.com']);
    expect(find.textContaining('tester@qq.com'), findsOneWidget);
    expect(find.textContaining('s 后可重新发送'), findsOneWidget);
    final codeField = tester.widget<TextField>(find.byType(TextField));
    expect(find.text('输入 6 位验证码'), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      expect(find.byKey(ValueKey('otp-cell-$i')), findsOneWidget);
    }
    expect(codeField.textAlign, TextAlign.center);
    expect(codeField.autofillHints, contains(AutofillHints.oneTimeCode));
    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.text('确认'));
    await tester.pump();
    expect(auth.verifiedCode, isNull);
    await tester.enterText(find.byType(TextField), '135790');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(auth.verifiedEmail, 'tester@qq.com');
    expect(auth.verifiedCode, '135790');
    expect(auth.requestedAi, isTrue);
    expect(find.text('进入流境'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('合并同意后才传递授权；取消勾选及更换邮箱都会禁用按钮', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = _FakeEmailAuth();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith(() => auth)],
        child: const MaterialApp(home: AuthPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'a@example.com');
    await tester.tap(find.byKey(const ValueKey('privacy-consent')));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey('privacy-consent')));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('privacy-consent')));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'b@example.com');
    await tester.pump();
    expect(
      tester
          .widget<Checkbox>(find.byKey(const ValueKey('privacy-consent')))
          .value,
      isFalse,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('privacy-consent')));
    await tester.pump();
    await tester.tap(find.text('获取验证码'));
    await tester.pumpAndSettle();
    expect(auth.requestedAi, isNull);
    await tester.enterText(find.byType(TextField), '135790');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(auth.verifiedEmail, 'b@example.com');
    expect(auth.requestedAi, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('小屏可滚动阅读隐私说明，不触发登录或隐式同意', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = _FakeEmailAuth();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith(() => auth)],
        child: const MaterialApp(home: AuthPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('《隐私说明》'));
    await tester.tap(find.text('《隐私说明》'));
    await tester.pumpAndSettle();
    expect(find.textContaining('流境隐私说明（'), findsOneWidget);
    expect(
      find.textContaining('隐私与数据问题联系邮箱：gg5605568@gmail.com'),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('《AI 回响功能说明》'));
    await tester.tap(find.text('《AI 回响功能说明》'));
    await tester.pumpAndSettle();
    expect(find.textContaining('第三方大语言模型（LLM）'), findsOneWidget);
    expect(
      find.textContaining('服务提供方与数据接收方：Moonshot AI（月之暗面）'),
      findsOneWidget,
    );
    expect(find.textContaining('Kimi'), findsNothing);
    expect(
      find.textContaining('隐私与数据问题联系邮箱：gg5605568@gmail.com'),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Checkbox>(find.byKey(const ValueKey('privacy-consent')))
          .value,
      isFalse,
    );
    await tester.ensureVisible(find.text('获取验证码'));
    expect(tester.takeException(), isNull);
    expect(auth.sent, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
}

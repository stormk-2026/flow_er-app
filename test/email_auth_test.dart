import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flow_er/features/auth/auth_page.dart';
import 'package:flow_er/providers/auth_provider.dart';
import 'package:flow_er/repositories/auth_repository.dart';

class _FakeEmailAuth extends AuthController {
  final sent = <String>[];
  String? verifiedEmail;
  String? verifiedCode;
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
  }) async {
    verifiedEmail = email;
    verifiedCode = code;
    return VerifyResult(
      token: 'test',
      isNewUser: true,
      email: email,
      nickname: '',
    );
  }
}

void main() {
  testWidgets('邮箱格式校验、发送、冷却和新用户昵称流程', (tester) async {
    final auth = _FakeEmailAuth();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith(() => auth)],
        child: const MaterialApp(home: AuthPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('验证邮箱后自动注册或登录'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '12345');
    await tester.tap(find.text('获取验证码'));
    await tester.pump();
    expect(find.text('请输入正确的邮箱'), findsOneWidget);
    expect(auth.sent, isEmpty);
    await tester.enterText(find.byType(TextField), 'Tester@QQ.com');
    await tester.tap(find.text('获取验证码'));
    await tester.pumpAndSettle();
    expect(auth.sent, ['tester@qq.com']);
    expect(find.textContaining('tester@qq.com'), findsOneWidget);
    expect(find.textContaining('s 后可重新发送'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.text('确认'));
    await tester.pump();
    expect(auth.verifiedCode, isNull);
    await tester.enterText(find.byType(TextField), '135790');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(auth.verifiedEmail, 'tester@qq.com');
    expect(auth.verifiedCode, '135790');
    expect(find.text('进入流境'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

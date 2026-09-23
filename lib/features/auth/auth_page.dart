import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/auth_repository.dart';
import 'widgets/email_code_input.dart';
import 'widgets/auth_consent_section.dart';

// 三阶段：填邮箱 → 填验证码 → 新用户留昵称
enum _AuthStep { email, code, nickname }

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage>
    with SingleTickerProviderStateMixin {
  _AuthStep _step = _AuthStep.email;

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _nicknameController = TextEditingController();

  bool _loading = false;
  bool _privacyAccepted = false;
  int _countdown = 0;
  Timer? _resendTimer;
  String? _sentEmail;

  // 淡入动画
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _nicknameController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _goStep(_AuthStep next) {
    setState(() => _step = next);
    _fadeCtrl.forward(from: 0);
  }

  // 第一步：发送验证码
  Future<void> _submitEmail() async {
    if (_loading) return;
    final email = _emailController.text.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) ||
        email.length > 254) {
      _showSnack('请输入正确的邮箱');
      return;
    }
    if (!_privacyAccepted) {
      _showSnack('请先阅读并同意隐私说明和 AI 回响功能说明');
      return;
    }
    setState(() => _loading = true);
    final error = await ref.read(authProvider.notifier).sendCode(email);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      _showSnack(error);
      return;
    }
    _sentEmail = email;
    _codeController.clear();
    setState(() => _countdown = 60);
    _tickCountdown();
    _goStep(_AuthStep.code);
  }

  // 第二步：验证码确认
  Future<void> _submitCode() async {
    if (_loading) return;
    final code = _codeController.text.trim();
    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      _showSnack('请输入 6 位邮箱验证码');
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await ref
          .read(authProvider.notifier)
          .verifyCode(
            email: _sentEmail!,
            code: code,
            enableAi: _privacyAccepted,
          );
      if (!mounted) return;
      setState(() => _loading = false);
      if (result.aiConsentSaveFailed) {
        _showSnack('邮箱验证成功，但 AI 授权未能确认。请在「设置 → 隐私与数据」中检查并重试。');
      }
      if (result.isNewUser) {
        _goStep(_AuthStep.nickname);
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnack(authErrorMessage(e));
    }
  }

  // 第三步：设置昵称
  Future<void> _submitNickname() async {
    if (_loading) return;
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      _showSnack('请留下一个称呼');
      return;
    }
    setState(() => _loading = true);
    final error = await ref
        .read(authProvider.notifier)
        .setNickname(email: _sentEmail!, nickname: nickname);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      _showSnack(error);
      return;
    }
    Navigator.of(context).pop();
  }

  void _tickCountdown() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _countdown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _countdown = 0);
        return;
      }
      setState(() => _countdown--);
    });
  }

  Future<void> _resendCode() async {
    if (_countdown > 0 || _loading || _sentEmail == null) return;
    setState(() => _loading = true);
    final error = await ref.read(authProvider.notifier).sendCode(_sentEmail!);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      _showSnack(error);
      return;
    }
    _codeController.clear();
    setState(() => _countdown = 60);
    _tickCountdown();
    _showSnack('验证码已重新发送，请查看邮箱');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: AppColors.navIcon,
          onPressed: _loading
              ? null
              : () {
                  if (_step == _AuthStep.code) {
                    _goStep(_AuthStep.email);
                  } else if (_step == _AuthStep.nickname) {
                    _goStep(_AuthStep.code);
                  } else {
                    Navigator.of(context).pop();
                  }
                },
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
            child: switch (_step) {
              _AuthStep.email => _EmailStep(
                controller: _emailController,
                loading: _loading,
                onSubmit: _submitEmail,
                privacyAccepted: _privacyAccepted,
                onPrivacyChanged: (value) =>
                    setState(() => _privacyAccepted = value),
                onEmailChanged: (_) => setState(() {
                  _privacyAccepted = false;
                }),
              ),
              _AuthStep.code => _CodeStep(
                email: _sentEmail!,
                controller: _codeController,
                countdown: _countdown,
                loading: _loading,
                onSubmit: _submitCode,
                onResend: _resendCode,
              ),
              _AuthStep.nickname => _NicknameStep(
                controller: _nicknameController,
                loading: _loading,
                onSubmit: _submitNickname,
              ),
            },
          ),
        ),
      ),
    );
  }
}

// ─── 第一步：邮箱 ────────────────────────────────────────────────────────────

class _EmailStep extends StatelessWidget {
  const _EmailStep({
    required this.controller,
    required this.loading,
    required this.onSubmit,
    required this.privacyAccepted,
    required this.onPrivacyChanged,
    required this.onEmailChanged,
  });

  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSubmit;
  final bool privacyAccepted;
  final ValueChanged<bool> onPrivacyChanged;
  final ValueChanged<String> onEmailChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        _Header(title: '入静', subtitle: '以邮箱为门，\n无需记忆，无需繁礼。'),
        const SizedBox(height: 40),
        TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: const [AutofillHints.email],
          enabled: !loading,
          inputFormatters: [LengthLimitingTextInputFormatter(254)],
          style: GoogleFonts.notoSansSc(fontSize: 16),
          decoration: _inputDecoration('邮箱地址，例如 name@qq.com'),
          onSubmitted: (_) => onSubmit(),
          onChanged: onEmailChanged,
        ),
        const SizedBox(height: 20),
        AuthConsentSection(
          privacyAccepted: privacyAccepted,
          enabled: !loading,
          onPrivacyChanged: onPrivacyChanged,
        ),
        const SizedBox(height: 24),
        _PrimaryButton(
          label: '获取验证码',
          loading: loading,
          onPressed: privacyAccepted ? onSubmit : null,
        ),
        const SizedBox(height: 20),
        Text(
          '验证邮箱后自动注册或登录，无需设置密码',
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSansSc(
            fontSize: 12,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

// ─── 第二步：验证码 ────────────────────────────────────────────────────────────

class _CodeStep extends StatelessWidget {
  const _CodeStep({
    required this.email,
    required this.controller,
    required this.countdown,
    required this.loading,
    required this.onSubmit,
    required this.onResend,
  });

  final String email;
  final TextEditingController controller;
  final int countdown;
  final bool loading;
  final VoidCallback onSubmit;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final canResend = countdown == 0 && !loading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        _Header(title: '验证', subtitle: '验证码已发送至\n$email\n5 分钟内有效，未收到请检查垃圾邮件'),
        const SizedBox(height: 40),
        EmailCodeInput(
          controller: controller,
          enabled: !loading,
          onSubmitted: onSubmit,
        ),
        const SizedBox(height: 32),
        _PrimaryButton(label: '确认', loading: loading, onPressed: onSubmit),
        const SizedBox(height: 20),
        Center(
          child: GestureDetector(
            onTap: canResend ? onResend : null,
            child: Text(
              canResend ? '重新发送' : '${countdown}s 后可重新发送',
              style: GoogleFonts.notoSansSc(
                fontSize: 13,
                color: canResend
                    ? const Color(0xFF516356)
                    : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 第三步：昵称（仅新用户）─────────────────────────────────────────────────

class _NicknameStep extends StatelessWidget {
  const _NicknameStep({
    required this.controller,
    required this.loading,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        _Header(title: '相逢', subtitle: '如何称呼你？\n一两个字即可，无需多言。'),
        const SizedBox(height: 40),
        TextField(
          controller: controller,
          autofocus: true,
          maxLength: 6,
          enabled: !loading,
          style: GoogleFonts.notoSansSc(fontSize: 16),
          decoration: _inputDecoration('一个你喜欢的称呼').copyWith(counterText: ''),
          onSubmitted: (_) => onSubmit(),
        ),
        const SizedBox(height: 32),
        _PrimaryButton(label: '进入流境', loading: loading, onPressed: onSubmit),
      ],
    );
  }
}

// ─── 共用组件 ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSerifSc(
            fontSize: 32,
            fontWeight: FontWeight.w500,
            letterSpacing: 6,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSansSc(
            fontSize: 13,
            height: 1.9,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF516356),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(label, style: GoogleFonts.notoSansSc(fontSize: 15)),
    );
  }
}

InputDecoration _inputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    // Explicit spacing keeps the hint from inheriting the OTP digit spacing.
    hintStyle: GoogleFonts.notoSansSc(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.5,
      letterSpacing: 0.3,
      color: AppColors.textMuted,
    ),
    filled: true,
    fillColor: AppColors.surface,
    counterText: '',
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppColors.divider),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppColors.divider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFF737873)),
    ),
  );
}

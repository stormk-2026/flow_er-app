import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flow_er/core/theme/app_colors.dart';
import 'package:flow_er/core/theme/day_night_theme.dart';
import 'package:flow_er/features/auth/auth_page.dart';
import 'package:flow_er/features/shell/main_scaffold.dart';
import 'package:flow_er/features/shell/widgets/guest_shell_blur_overlay.dart';
import 'package:flow_er/providers/auth_provider.dart';
import 'package:flow_er/providers/settings_provider.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(() => appThemeMode = AppThemeMode.system);

  for (final mode in [AppThemeMode.dark, AppThemeMode.light]) {
    testWidgets('${mode.name}: guest glass covers header and safe areas', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 852);
      tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
      addTearDown(tester.view.reset);
      appThemeMode = mode;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_GuestAuth.new),
            settingsProvider.overrideWith(() => _FixedSettings(mode)),
          ],
          child: const MaterialApp(home: MainScaffold()),
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      final surface = find.byKey(const ValueKey('guest-glass-surface'));
      expect(tester.getRect(surface), const Rect.fromLTWH(0, 0, 393, 852));
      expect(
        tester.widget<ColoredBox>(surface).color,
        mode == AppThemeMode.dark
            ? const Color(0xFF1A1D19).withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.28),
      );
      expect(find.text('轻触，入静'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('轻触，入静'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AuthPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('Full-screen glass blocks taps on underlying content', (
    tester,
  ) async {
    var backgroundTaps = 0;
    var loginTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => backgroundTaps++,
                child: const SizedBox.expand(),
              ),
              GuestShellBlurOverlay(onLoginTap: () => loginTaps++),
            ],
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(10, 10));
    await tester.tapAt(const Offset(10, 590));
    expect(backgroundTaps, 0);
    expect(loginTaps, 0);
    await tester.tap(find.text('轻触，入静'));
    expect(loginTaps, 1);
    expect(backgroundTaps, 0);
  });
}

class _GuestAuth extends AuthController {
  @override
  Future<AuthSession?> build() async => null;
}

class _FixedSettings extends SettingsController {
  _FixedSettings(this.mode);
  final AppThemeMode mode;

  @override
  AppSettings build() => AppSettings(themeMode: mode, soundEnabled: false);
}

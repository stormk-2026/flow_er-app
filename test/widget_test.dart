import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flow_er/features/shell/main_scaffold.dart';
import 'package:flow_er/features/shell/widgets/flow_app_bar.dart';
import 'package:flow_er/main.dart';
import 'package:flow_er/providers/app_providers.dart';
import 'package:flow_er/providers/auth_provider.dart';
import 'package:flow_er/services/analytics/analytics_service.dart';
import 'package:flow_er/core/theme/app_colors.dart';
import 'package:flow_er/core/theme/day_night_theme.dart';
import 'package:flow_er/providers/settings_provider.dart';
import 'package:flow_er/services/audio/app_audio_service.dart';

void main() {
  for (final mode in [AppThemeMode.dark, AppThemeMode.light]) {
    testWidgets(
      '${mode.name}: meditation glass is edge-to-edge and mute retains waveform',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(393, 852);
        tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
        addTearDown(tester.view.reset);
        appThemeMode = mode;
        addTearDown(() => appThemeMode = AppThemeMode.system);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(_LoggedInAuth.new),
              settingsProvider.overrideWith(() => _FocusSettings(mode)),
              appAudioServiceProvider.overrideWithValue(_SilentTestAudio()),
              analyticsServiceProvider.overrideWithValue(
                _FakeAnalyticsService(),
              ),
            ],
            child: const MaterialApp(home: MainScaffold()),
          ),
        );
        await tester.pump(const Duration(seconds: 2));
        for (var i = 0; i < 3; i++) {
          await tester.tapAt(const Offset(196, 400));
          await tester.pump(const Duration(milliseconds: 60));
        }
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();
        final surface = find.byKey(const ValueKey('focus-glass-surface'));
        expect(tester.getRect(surface), const Rect.fromLTWH(0, 0, 393, 852));
        expect(
          tester.widget<ColoredBox>(surface).color,
          AppColors.surface.withValues(
            alpha: mode == AppThemeMode.dark ? 0.55 : 0.15,
          ),
        );
        expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
        expect(find.byIcon(Icons.volume_off_rounded), findsNothing);
        final mute = find.byTooltip('静音');
        expect(tester.getRect(mute).top, greaterThanOrEqualTo(59));
        await tester.tap(mute);
        await tester.pump();
        expect(
          find.byKey(const ValueKey('flow-sound-mute-slash')),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
        await tester.tap(find.byTooltip('开启声音'));
        await tester.pump();
        expect(
          find.byKey(const ValueKey('flow-sound-mute-slash')),
          findsNothing,
        );
        for (var i = 0; i < 3; i++) {
          await tester.tapAt(const Offset(196, 400));
          await tester.pump(const Duration(milliseconds: 60));
        }
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(milliseconds: 600));
        expect(surface, findsNothing);
        expect(
          tester.getRect(find.byType(FlowAppBar)).top,
          greaterThanOrEqualTo(59),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('流境 splash navigates to main', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FlowJingApp()));

    expect(find.text('流  境'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('请入静'), findsOneWidget);
  });

  testWidgets('Guest hides focus hint and side tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: MainScaffold())),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.textContaining('请入静'), findsOneWidget);
    expect(find.textContaining('连续轻击'), findsNothing);
    expect(find.text('心笺'), findsNothing);
    expect(find.byIcon(Icons.tune_rounded), findsNothing);
  });

  testWidgets('Logged-in user can switch tabs', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_LoggedInAuth.new),
          analyticsServiceProvider.overrideWithValue(_FakeAnalyticsService()),
        ],
        child: const MaterialApp(home: MainScaffold()),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.byKey(const Key('nav_inspiration')));
    await tester.pump();
    expect(find.text('心笺'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav_analytics')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('总时长'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Flow app bar fits narrow widths', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 320, child: FlowAppBar(nickname: '很长很长的名字')),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('流'), findsOneWidget);
    expect(find.text('境'), findsOneWidget);
  });
}

class _FocusSettings extends SettingsController {
  _FocusSettings(this.mode);
  final AppThemeMode mode;
  @override
  AppSettings build() => AppSettings(themeMode: mode);
}

class _SilentTestAudio implements AppAudioService {
  bool _muted = false;
  @override
  Future<void> setEnabled(bool enabled) async {}
  @override
  Future<void> playCenterDotTap() async {}
  @override
  Future<void> enterFlow() async {}
  @override
  Future<void> exitFlow() async {}
  @override
  Future<void> endFlowSilently() async {}
  @override
  Future<bool> toggleFlowMuted() async => _muted = !_muted;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAnalyticsService extends AnalyticsService {
  @override
  Future<AnalyticsStats> fetchStats(AnalyticsPeriod period) async {
    return const AnalyticsStats(
      period: '30d',
      sessionCount: 1,
      successCount: 1,
      failedCount: 0,
      duration: DurationStats(
        totalHours: 0.5,
        longestSeconds: 1800,
        averageSeconds: 1800,
        activeDays: 1,
        frequencyPerWeek: 1,
        byTrigger: {'triple_tap': 1, 'flip_phone': 0},
        byHourBucket: {'清晨': 1},
      ),
      intents: IntentStats(
        total: 1,
        byCategory: {'巧思': 1, '体悟': 0, '心绪': 0, '纪事': 0, '摘录': 0},
        deepestIntent: null,
        byHourBucket: {'清晨': 1},
        inspirationPeakHour: '清晨',
      ),
      soulPurity: ScoreStats(
        score: 80,
        factorsAvg: {
          'duration_score': 50,
          'completion_score': 25,
          'density_score': 5,
        },
        trend: [],
        targetSeconds: 1500,
      ),
      awarenessIndex: AwarenessStats(
        score: 60,
        factorsAvg: {
          'count_score': 20,
          'depth_score': 20,
          'diversity_score': 20,
          'mood_bonus_rate': 0,
        },
        trend: [],
      ),
    );
  }

  @override
  Future<AnalyticsPortrait> fetchPortrait(AnalyticsPeriod period) async {
    return const AnalyticsPortrait(
      userPortrait: '沉静',
      interpretation: '稳定地回到当下',
    );
  }
}

class _LoggedInAuth extends AuthController {
  @override
  Future<AuthSession?> build() async =>
      const AuthSession(email: 'zen@example.com', nickname: '测试');
}

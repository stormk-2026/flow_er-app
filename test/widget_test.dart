import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flow_er/features/shell/main_scaffold.dart';
import 'package:flow_er/features/shell/widgets/flow_app_bar.dart';
import 'package:flow_er/main.dart';
import 'package:flow_er/providers/app_providers.dart';
import 'package:flow_er/providers/auth_provider.dart';
import 'package:flow_er/services/analytics/analytics_service.dart';

void main() {
  testWidgets('流境 splash navigates to main', (WidgetTester tester) async {
    await tester.pumpWidget(const FlowJingApp());

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
      const AuthSession(phone: 'zen', nickname: '测试');
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flow_er/features/inspiration/models/inspiration_moment.dart';
import 'package:flow_er/core/i18n/ui_text.dart';
import 'package:flow_er/features/inspiration/widgets/inspiration_moment_card.dart';
import 'package:flow_er/models/app_database.dart';
import 'package:flow_er/features/inspiration/inspiration_flow_page.dart';
import 'package:flow_er/providers/app_providers.dart';
import 'package:flow_er/services/sync/intent_sync_service.dart';

InspirationMoment moment({String? comment, int id = 1}) =>
    InspirationMoment.fromFlowIntent(
      FlowIntent(
        clientId: 'test-id',
        pendingDelete: false,
        id: id,
        title: '',
        rawInput: '慢下来，听见这一刻。',
        priority: 'medium',
        tags: '["体悟"]',
        attachments: '[]',
        status: 'open',
        aiComment: comment,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );

Widget fixture(
  InspirationMoment value, {
  VoidCallback? onDelete,
  bool reduceMotion = false,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(
      body: Center(
        child: SizedBox(
          width: 300,
          child: InspirationMomentCard(moment: value, onDelete: onDelete),
        ),
      ),
    ),
  ),
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('English chrome leaves journal and AI reflection untouched', (
    tester,
  ) async {
    UiText.english = true;
    addTearDown(() => UiText.english = false);
    await tester.pumpWidget(fixture(moment(comment: '此刻不必匆忙。')));
    await tester.pumpAndSettle();
    expect(find.text('慢下来，听见这一刻。'), findsWidgets);
    await tester.tap(find.byIcon(Icons.swap_horiz_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Reflection'), findsOneWidget);
    expect(find.text('此刻不必匆忙。'), findsOneWidget);
  });

  testWidgets('Corner belongs to rotating face on both front and back', (
    tester,
  ) async {
    await tester.pumpWidget(fixture(moment(comment: '此刻不必匆忙。')));
    await tester.pumpAndSettle();
    final corner = find.byKey(const ValueKey('echo-ready'));
    for (var side = 0; side < 2; side++) {
      await tester.tap(find.byIcon(Icons.swap_horiz_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 130));
      final transforms = tester.widgetList<Transform>(
        find.ancestor(of: corner, matching: find.byType(Transform)),
      );
      expect(
        transforms.any((t) => t.transform.storage[2].abs() > 0.01),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(corner, findsOneWidget);
    }
  });

  testWidgets(
    'Feed refreshes only while visible and stops once comment arrives',
    (tester) async {
      final sync = _FakeSync();
      final values = StateProvider<List<InspirationMoment>>(
        (ref) => [moment()],
      );
      final container = ProviderContainer(
        overrides: [
          intentSyncServiceProvider.overrideWithValue(sync),
          inspirationMomentsProvider.overrideWith(
            (ref) => AsyncData(ref.watch(values)),
          ),
        ],
      );
      addTearDown(container.dispose);
      Widget page(bool active) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: InspirationFlowPage(isActive: active)),
        ),
      );
      await tester.pumpWidget(page(false));
      await tester.pump(const Duration(seconds: 6));
      expect(sync.calls, 0);
      await tester.pumpWidget(page(true));
      await tester.pump(const Duration(milliseconds: 1));
      expect(sync.calls, 1);
      await tester.pump(const Duration(seconds: 5));
      expect(sync.calls, 2);
      container.read(values.notifier).state = [moment(comment: '回响已到')];
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      expect(sync.calls, 2);
      await tester.pumpWidget(page(false));
      await tester.pump(const Duration(seconds: 6));
      expect(sync.calls, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Feed stops polling in background and resumes on foreground', (
    tester,
  ) async {
    final sync = _FakeSync();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          intentSyncServiceProvider.overrideWithValue(sync),
          inspirationMomentsProvider.overrideWith(
            (ref) => AsyncData([moment()]),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: InspirationFlowPage())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    expect(sync.calls, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 10));
    expect(sync.calls, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 1));
    expect(sync.calls, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Pending card cannot flip; arriving comment enables flip', (
    tester,
  ) async {
    await tester.pumpWidget(fixture(moment()));
    expect(find.byKey(const ValueKey('echo-pending')), findsOneWidget);
    final card = find.byType(InspirationMomentCard);
    await tester.tap(card);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(card);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('回响'), findsNothing);

    await tester.pumpWidget(fixture(moment(comment: '此刻不必匆忙。')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('echo-ready')), findsOneWidget);
    await tester.tap(find.byIcon(Icons.swap_horiz_rounded));
    await tester.pumpAndSettle();
    expect(find.text('此刻不必匆忙。'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.swap_horiz_rounded));
    await tester.pumpAndSettle();
    expect(find.text('回响'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Long press opens delete overlay, blank tap dismisses, button invokes callback',
    (tester) async {
      var deleted = 0;
      await tester.pumpWidget(fixture(moment(), onDelete: () => deleted++));
      expect(find.byType(PopupMenuButton), findsNothing);
      await tester.longPress(find.byType(InspirationMomentCard));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
      expect(deleted, 0);
      final overlay = find.byKey(const ValueKey('delete-overlay'));
      await tester.tapAt(tester.getTopLeft(overlay) + const Offset(12, 40));
      await tester.pumpAndSettle();
      expect(overlay, findsNothing);
      await tester.longPress(find.byType(InspirationMomentCard));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除心笺'));
      await tester.pumpAndSettle();
      expect(deleted, 1);
      expect(overlay, findsNothing);
    },
  );

  testWidgets(
    'Delete works from back; outside tap dismisses without deleting',
    (tester) async {
      var deleted = 0;
      await tester.pumpWidget(
        fixture(moment(comment: '此刻不必匆忙。'), onDelete: () => deleted++),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.swap_horiz_rounded));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('此刻不必匆忙。'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('delete-overlay')), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('delete-overlay')), findsNothing);
      expect(deleted, 0);
    },
  );

  testWidgets('Reduced motion settles and replacing card resets the back', (
    tester,
  ) async {
    await tester.pumpWidget(
      fixture(moment(comment: '回响一'), reduceMotion: true),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.tap(find.byIcon(Icons.swap_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.pumpWidget(fixture(moment(id: 2), reduceMotion: true));
    await tester.pumpAndSettle();
    expect(find.text('回响一'), findsNothing);
    expect(find.byKey(const ValueKey('echo-pending')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeSync implements IntentSyncService {
  int calls = 0;

  @override
  Future<void> refreshSnapshot() async {
    calls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

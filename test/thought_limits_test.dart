import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flow_er/features/state/widgets/thought_capture_overlay.dart';

void main() {
  testWidgets('Diary input enforces quick, title and body limits', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ThoughtCaptureOverlay(onDismiss: () {}, onSubmitting: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).maxLength, 2000);
    await tester.enterText(find.byType(TextField), '字' * 2001);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text.length,
      2000,
    );
    await tester.tap(find.text('展笺'));
    await tester.pumpAndSettle();
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields.map((f) => f.maxLength), [100, 2000]);
    await tester.enterText(find.byType(TextField).first, '题' * 101);
    expect(fields.first.controller!.text.length, 100);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

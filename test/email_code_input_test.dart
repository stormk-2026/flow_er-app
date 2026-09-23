import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flow_er/core/theme/day_night_theme.dart';
import 'package:flow_er/features/auth/widgets/email_code_input.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(() => appThemeMode = AppThemeMode.system);

  for (final mode in [AppThemeMode.dark, AppThemeMode.light]) {
    testWidgets(
      '${mode.name}: six equal cells, centered hint and native editing',
      (tester) async {
        appThemeMode = mode;
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 700);
        addTearDown(tester.view.reset);
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        var submitted = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: EmailCodeInput(
                  controller: controller,
                  enabled: true,
                  onSubmitted: () => submitted = true,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final first = tester.getRect(find.byKey(const ValueKey('otp-cell-0')));
        for (var i = 0; i < 6; i++) {
          final cell = tester.getRect(find.byKey(ValueKey('otp-cell-$i')));
          expect(cell.width, closeTo(first.width, 0.01));
          expect(cell.left, closeTo(first.left + i * (first.width + 8), 0.01));
        }
        expect(tester.getCenter(find.text('输入 6 位验证码')).dx, 160);
        await tester.enterText(find.byType(TextField), '12a345678');
        await tester.pump();
        expect(controller.text, '123456');
        for (var i = 0; i < 6; i++) {
          expect(
            find.descendant(
              of: find.byKey(ValueKey('otp-cell-$i')),
              matching: find.text('${i + 1}'),
            ),
            findsOneWidget,
          );
        }
        // Deleting, replacing and autofill use the same native editing value.
        await tester.enterText(find.byType(TextField), '12');
        await tester.pump();
        expect(find.text('·'), findsNWidgets(4));
        await tester.enterText(find.byType(TextField), '654321');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        expect(submitted, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flow_er/core/theme/day_night_theme.dart';
import 'package:flow_er/core/widgets/glass_dialog.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    // Optional local visual QA; no system-font dependency in normal tests.
    if (const bool.fromEnvironment('GLASS_PREVIEW')) {
      final icons = await File(
        '/Users/stormg/developer/tools/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ).readAsBytes();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(icons)))).load();
      final bytes = await File(
        '/System/Library/Fonts/STHeiti Light.ttc',
      ).readAsBytes();
      const paths = [
        'assets/NotoSerifSC-Medium.ttf',
        'assets/NotoSansSC-Regular.ttf',
        'assets/NotoSansSC-Medium.ttf',
      ];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (message) async {
            final name = utf8.decode(
              message!.buffer.asUint8List(
                message.offsetInBytes,
                message.lengthInBytes,
              ),
            );
            if (name == 'AssetManifest.bin') {
              return const StandardMessageCodec().encodeMessage({
                for (final path in paths)
                  path: [
                    {'asset': path},
                  ],
              });
            }
            if (paths.contains(name)) return ByteData.sublistView(bytes);
            return null;
          });
      await GoogleFonts.pendingFonts([
        GoogleFonts.notoSerifSc(fontWeight: FontWeight.w500),
        GoogleFonts.notoSansSc(),
        GoogleFonts.notoSansSc(fontWeight: FontWeight.w500),
      ]);
    }
  });

  setUp(() => appThemeMode = AppThemeMode.light);
  tearDown(() => appThemeMode = AppThemeMode.system);

  Future<void> open(
    WidgetTester tester, {
    ValueChanged<bool?>? onResult,
    bool info = false,
    String? message,
    double scale = 1,
    bool reduceMotion = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduceMotion,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE0E9DF), Color(0xFFF4EBDF)],
              ),
            ),
            child: Center(
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    final result = await showGlassDialog(
                      context: context,
                      title: info ? '沉淀' : '删除心笺',
                      message: message ?? '这条心笺及背面的回响将从列表中移除。\n确定要删除吗？',
                      confirmLabel: info ? '知道了' : '删除心笺',
                      cancelLabel: info ? null : '取消',
                      destructive: !info,
                      icon: info
                          ? Icons.history_rounded
                          : Icons.delete_outline_rounded,
                    );
                    onResult?.call(result);
                  },
                  child: const Text('打开弹窗'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开弹窗'));
    await tester.pumpAndSettle();
  }

  testWidgets('Glass confirmation preserves cancel and confirm results', (
    tester,
  ) async {
    bool? result;
    await open(tester, onResult: (v) => result = v);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.byKey(const ValueKey('glass-dialog-cancel')));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    await tester.tap(find.text('打开弹窗'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('glass-dialog-confirm')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('Outside tap and system back never confirm', (tester) async {
    bool? result = true;
    await open(tester, onResult: (v) => result = v);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(result, isNull);
    result = true;
    await tester.tap(find.text('打开弹窗'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('Narrow screen, large text and long content remain scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(
      tester,
      scale: 2,
      message: List.filled(8, '慢慢来，让心绪沉淀下来。').join('\n'),
    );
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -1800),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('glass-dialog-confirm')),
    );
    await tester.tap(find.byKey(const ValueKey('glass-dialog-confirm')));
    await tester.pumpAndSettle();
    expect(find.byType(GlassDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Night help dialog has one action and supports reduced motion', (
    tester,
  ) async {
    appThemeMode = AppThemeMode.dark;
    await open(tester, info: true, reduceMotion: true);
    expect(find.byKey(const ValueKey('glass-dialog-cancel')), findsNothing);
    expect(find.text('知道了'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    expect(find.byType(GlassDialog), findsNothing);
  });

  if (const bool.fromEnvironment('GLASS_PREVIEW')) {
    testWidgets('Local visual preview', (tester) async {
      final previousShadows = debugDisableShadows;
      debugDisableShadows = false;
      try {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await open(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('/private/tmp/flow-er-glass-light.png'),
        );
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        appThemeMode = AppThemeMode.dark;
        await open(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('/private/tmp/flow-er-glass-dark.png'),
        );
      } finally {
        debugDisableShadows = previousShadows;
      }
    });
  }
}

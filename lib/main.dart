import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/day_night_theme.dart';
import 'core/i18n/ui_text.dart';
import 'features/splash/splash_page.dart';
import 'providers/settings_provider.dart';

void main() {
  runApp(const ProviderScope(child: FlowJingApp()));
}

class FlowJingApp extends ConsumerStatefulWidget {
  const FlowJingApp({super.key});

  @override
  ConsumerState<FlowJingApp> createState() => _FlowJingAppState();
}

class _FlowJingAppState extends ConsumerState<FlowJingApp> {
  Timer? _themeTimer;
  AppThemeMode? _scheduledThemeMode;

  @override
  void initState() {
    super.initState();
    _scheduleThemeRefresh();
  }

  @override
  void dispose() {
    _themeTimer?.cancel();
    super.dispose();
  }

  void _scheduleThemeRefresh() {
    _themeTimer?.cancel();
    _scheduledThemeMode = appThemeMode;
    if (appThemeMode != AppThemeMode.system) return;
    _themeTimer = Timer(durationUntilNextThemeBoundary(), () {
      if (!mounted) return;
      setState(() {});
      _scheduleThemeRefresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    UiText.english = settings.language == AppLanguage.english;
    final themeMode = settings.themeMode;
    appThemeMode = themeMode;
    if (_scheduledThemeMode != themeMode) {
      _scheduleThemeRefresh();
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '流境'.tr,
      locale: settings.language == AppLanguage.english
          ? const Locale('en')
          : const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.navIcon,
          surface: AppColors.background,
          brightness: isNightTheme ? Brightness.dark : Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const SplashPage(),
    );
  }
}

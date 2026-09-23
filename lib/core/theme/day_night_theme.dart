import 'package:flow_er/core/i18n/ui_text.dart';

enum AppThemeMode {
  system,
  light,
  dark;

  String get label => switch (this) {
    AppThemeMode.system => '自动'.tr,
    AppThemeMode.light => '日间'.tr,
    AppThemeMode.dark => '夜间'.tr,
  };
}

AppThemeMode appThemeMode = AppThemeMode.system;

bool get isNightTheme {
  switch (appThemeMode) {
    case AppThemeMode.light:
      return false;
    case AppThemeMode.dark:
      return true;
    case AppThemeMode.system:
      break;
  }
  final hour = DateTime.now().hour;
  return hour < 6 || hour >= 18;
}

Duration durationUntilNextThemeBoundary() {
  final now = DateTime.now();
  final next = now.hour < 6
      ? DateTime(now.year, now.month, now.day, 6)
      : now.hour < 18
      ? DateTime(now.year, now.month, now.day, 18)
      : DateTime(now.year, now.month, now.day + 1, 6);
  return next.difference(now);
}

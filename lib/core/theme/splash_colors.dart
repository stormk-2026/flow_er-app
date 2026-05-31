import 'package:flutter/material.dart';

import 'day_night_theme.dart';

abstract final class SplashColors {
  static bool get _night => isNightTheme;

  static Color get backgroundTop =>
      _night ? const Color(0xFF0E100E) : const Color(0xFFFAFAF8);
  static Color get backgroundBottom =>
      _night ? const Color(0xFF171A16) : const Color(0xFFF2F2F0);

  static Color get coreCircle =>
      _night ? const Color(0xFFC4C8BC) : const Color(0xFF737873);
  static Color get ripple =>
      _night ? const Color(0xFFAAB6A4) : const Color(0xFF516356);

  static Color get title =>
      _night ? const Color(0xFFEDECE4) : const Color(0xFF3D3D3D);
  static Color get divider =>
      _night ? const Color(0xFF4A5148) : const Color(0xFFD8D8D4);
  static Color get quote =>
      _night ? const Color(0xFFA7AAA1) : const Color(0xFF8A8A86);
  static Color get brand =>
      _night ? const Color(0xFFB8BDB1) : const Color(0xFF9A9A96);
}

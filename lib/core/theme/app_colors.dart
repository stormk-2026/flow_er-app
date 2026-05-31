import 'package:flutter/material.dart';

import 'day_night_theme.dart';

abstract final class AppColors {
  static bool get _night => isNightTheme;

  static Color get background =>
      _night ? const Color(0xFF101210) : const Color(0xFFF7F7F5);
  static Color get surface =>
      _night ? const Color(0xFF1A1D19) : const Color(0xFFFFFFFF);
  static Color get card =>
      _night ? const Color(0xFF171A16) : const Color(0xFFFAFAF8);

  static Color get textPrimary =>
      _night ? const Color(0xFFE8E7DF) : const Color(0xFF2D2D2D);
  static Color get textSecondary =>
      _night ? const Color(0xFFB8B7AD) : const Color(0xFF8E8E8E);
  static Color get textMuted =>
      _night ? const Color(0xFF777B71) : const Color(0xFFB0B0AA);

  static Color get accent =>
      _night ? const Color(0xFF334238) : const Color(0xFFE8DDD8);
  static Color get accentSoft =>
      _night ? const Color(0xFF202920) : const Color(0xFFF3EBE7);
  static Color get divider =>
      _night ? const Color(0xFF2B3029) : const Color(0xFFE8E8E4);
  static Color get primaryAction =>
      _night ? const Color(0xFF9FB3A4) : const Color(0xFF516356);
  static Color get glassSurface =>
      _night ? const Color(0xFF1A1D19).withValues(alpha: 0.68) : surface;
  static Color get glassBorder => _night
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.white.withValues(alpha: 0.55);
  static List<Color> get statGradient => _night
      ? const [Color(0xFF1D251F), Color(0xFF24221F)]
      : const [Color(0xFFEDF2EF), Color(0xFFE8DDD8)];

  static Color get navCapsule =>
      _night ? const Color(0x66181C18) : const Color(0xE6FFFFFF);
  static Color get navIcon =>
      _night ? const Color(0xFF9FA59A) : const Color(0xFF6B6B66);
  static Color get navActive =>
      _night ? const Color(0xFFEDECE4) : const Color(0xFF4A4A46);
}

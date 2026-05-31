import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/day_night_theme.dart';

class AppSettings {
  const AppSettings({
    this.sensorFocusEnabled = false,
    this.soundEnabled = true,
    this.themeMode = AppThemeMode.system,
  });

  /// 扣置手机触发心流；默认关闭，仅三击触发。
  final bool sensorFocusEnabled;

  /// 全局声音开关；关闭后所有声效与心流白噪音都静音。
  final bool soundEnabled;

  /// 外观模式；默认自动按本机时间切换。
  final AppThemeMode themeMode;

  AppSettings copyWith({
    bool? sensorFocusEnabled,
    bool? soundEnabled,
    AppThemeMode? themeMode,
  }) {
    return AppSettings(
      sensorFocusEnabled: sensorFocusEnabled ?? this.sensorFocusEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class SettingsController extends Notifier<AppSettings> {
  static const _sensorKey = 'sensor_focus_enabled';
  static const _soundKey = 'sound_enabled';
  static const _themeModeKey = 'theme_mode';

  @override
  AppSettings build() {
    _loadFromDisk();
    return const AppSettings();
  }

  Future<void> _loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final sensorEnabled = prefs.getBool(_sensorKey) ?? false;
    final soundEnabled = prefs.getBool(_soundKey) ?? true;
    final themeMode = AppThemeMode.values.firstWhere(
      (mode) => mode.name == prefs.getString(_themeModeKey),
      orElse: () => AppThemeMode.system,
    );
    appThemeMode = themeMode;
    state = AppSettings(
      sensorFocusEnabled: sensorEnabled,
      soundEnabled: soundEnabled,
      themeMode: themeMode,
    );
  }

  Future<void> setSensorFocusEnabled(bool enabled) async {
    state = state.copyWith(sensorFocusEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sensorKey, enabled);
  }

  Future<void> setSoundEnabled(bool enabled) async {
    state = state.copyWith(soundEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundKey, enabled);
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    appThemeMode = mode;
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

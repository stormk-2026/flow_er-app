import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  const AppSettings({this.sensorFocusEnabled = false});

  /// 扣置手机触发心流；默认关闭，仅三击触发。
  final bool sensorFocusEnabled;

  AppSettings copyWith({bool? sensorFocusEnabled}) {
    return AppSettings(
      sensorFocusEnabled: sensorFocusEnabled ?? this.sensorFocusEnabled,
    );
  }
}

class SettingsController extends Notifier<AppSettings> {
  static const _sensorKey = 'sensor_focus_enabled';

  @override
  AppSettings build() {
    _loadFromDisk();
    return const AppSettings();
  }

  Future<void> _loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_sensorKey) ?? false;
    state = AppSettings(sensorFocusEnabled: enabled);
  }

  Future<void> setSensorFocusEnabled(bool enabled) async {
    state = state.copyWith(sensorFocusEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sensorKey, enabled);
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

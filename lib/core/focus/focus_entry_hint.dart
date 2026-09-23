import 'package:flow_er/core/i18n/ui_text.dart';

/// 中间页进入专注的引导文案。
abstract final class FocusEntryHint {
  static String build({required bool sensorFocusEnabled}) {
    if (sensorFocusEnabled) {
      return '连续轻击三下，或将手机扣置桌面\n进入专注'.tr;
    }
    return '连续轻击三下，进入专注'.tr;
  }
}

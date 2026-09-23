import 'package:flow_er/core/i18n/ui_text.dart';
import 'dart:math';

/// 中间页问候文案：按系统时间问安 + 登录态区分。
abstract final class HomeGreeting {
  static const _dailyTips = [
    '静心思考',
    '留白片刻',
    '慢行从容',
    '少言深听',
    '观息如一',
    '放下执念',
    '专注一事',
    '安住当下',
  ];

  /// 按当前小时返回问安语。
  static String timeSalutation([DateTime? now]) {
    final hour = (now ?? DateTime.now()).hour;
    if (hour >= 5 && hour < 11) return '早上好'.tr;
    if (hour >= 11 && hour < 13) return '中午好'.tr;
    if (hour >= 13 && hour < 18) return '下午好'.tr;
    if (hour >= 18 && hour < 23) return '晚上好'.tr;
    return '夜深了'.tr;
  }

  /// Mock：AI 今日宜（后续接 Kimi）。
  static String mockDailyTip({int? seed}) {
    final r = Random(seed ?? DateTime.now().millisecondsSinceEpoch);
    return _dailyTips[r.nextInt(_dailyTips.length)].tr;
  }

  /// 未登录遮罩文案：「夜深了，请入静，方得天地。」（问安随系统时间）
  static String guestInvite([DateTime? now]) {
    return UiText.english
        ? '${timeSalutation(now)}. Take a moment to settle in.'
        : '${timeSalutation(now)}，请入静，方得天地。';
  }

  /// 未登录：见 [guestInvite]；已登录：「晚上好，昵称。今日宜：静心思考。」
  static String build({
    String? nickname,
    required String dailyTip,
    DateTime? now,
  }) {
    if (nickname == null || nickname.trim().isEmpty) {
      return guestInvite(now);
    }

    final salutation = timeSalutation(now);

    return UiText.english
        ? '$salutation, ${nickname.trim()}. For today: $dailyTip.'
        : '$salutation，${nickname.trim()}。今日宜：$dailyTip。';
  }
}

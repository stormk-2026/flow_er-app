import 'package:flow_er/core/i18n/ui_text.dart';
import 'focus_constants.dart';

/// 时光回溯说明与禅意文案。
abstract final class TimeRewindCopy {
  static String get title => '时光回溯'.tr;

  static String get intro =>
      '近 30 分钟内，因打扰而中断的专注会记入统计，可能拉低你的总时长观感与心流纯度。\n\n时光回溯可将这些「失败专注」从沉淀数据中抹去，仿佛未曾发生——每日限用三次。'
          .tr;

  static String get zenLine => '覆水难收，然心可拾——不留痕迹于榜册，只留清明于当下。'.tr;

  static String remainingSubtitle(int remaining) => UiText.english
      ? '$remaining / ${FocusConstants.rewindDailyLimit} left today · Failed sessions from the last 30 minutes only'
      : '今日剩余 $remaining / ${FocusConstants.rewindDailyLimit} 次 · 仅作用于近 30 分钟内的失败专注';

  static String confirmMessage(int count) => UiText.english
      ? 'Rewind $count failed focus sessions from the last 30 minutes? They will no longer count toward total time or focus quality.'
      : '将回溯近 30 分钟内的 $count 次失败专注，不计入总时长与心流纯度。是否继续？';
}

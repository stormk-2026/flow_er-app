/// 专注统计与时光回溯的约定。
abstract final class FocusConstants {
  /// 低于此时长视为「失败专注」（秒）。
  static const int minSuccessSeconds = 180;

  /// 可回溯的失败专注时间窗。
  static const Duration rewindWindow = Duration(minutes: 30);

  /// 每日回溯次数上限。
  static const int rewindDailyLimit = 3;
}

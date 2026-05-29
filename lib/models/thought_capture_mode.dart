/// 记录想法：快记（一语） / 展笺（标题+正文+图）
enum ThoughtCaptureMode {
  quick,
  expanded,
}

extension ThoughtCaptureModeLabel on ThoughtCaptureMode {
  String get label => switch (this) {
        ThoughtCaptureMode.quick => '快记',
        ThoughtCaptureMode.expanded => '展笺',
      };
}

class AppSettings {
  const AppSettings({
    required this.showFloatingBall,
    required this.noteFilePath,
    this.startDay1,
    this.startDay2,
  });

  /// 是否显示悬浮球。
  final bool showFloatingBall;

  /// 笔记 txt 文件的绝对路径。
  final String noteFilePath;

  /// 练功起始日期，用于计算天数与年数。
  final DateTime? startDay1;

  /// 累计起始日期，用于计算“第 X 天”。
  final DateTime? startDay2;

  static const AppSettings empty = AppSettings(
    showFloatingBall: true,
    noteFilePath: '',
  );

  AppSettings copyWith({
    bool? showFloatingBall,
    String? noteFilePath,
    DateTime? startDay1,
    DateTime? startDay2,
  }) {
    return AppSettings(
      showFloatingBall: showFloatingBall ?? this.showFloatingBall,
      noteFilePath: noteFilePath ?? this.noteFilePath,
      startDay1: startDay1 ?? this.startDay1,
      startDay2: startDay2 ?? this.startDay2,
    );
  }
}

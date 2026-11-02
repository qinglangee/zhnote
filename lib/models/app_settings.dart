class AppSettings {
  const AppSettings({
    required this.showFloatingBall,
    required this.noteFilePath,
    this.floatingBallOpacity = 1.0,
    this.floatingBallSize = 64.0,
    this.startDay1,
    this.startDay2,
  });

  /// 是否显示悬浮球。
  final bool showFloatingBall;

  /// 悬浮球不透明度，取值 0.05 - 1.0。
  final double floatingBallOpacity;

  /// 悬浮球大小（逻辑像素/DP），取值 5 - 96。
  final double floatingBallSize;

  /// 笔记 txt 文件的绝对路径。
  final String noteFilePath;

  /// 练功起始日期，用于计算天数与年数。
  final DateTime? startDay1;

  /// 累计起始日期，用于计算“第 X 天”。
  final DateTime? startDay2;

  static const AppSettings empty = AppSettings(
    showFloatingBall: true,
    noteFilePath: '',
    floatingBallOpacity: 1.0,
    floatingBallSize: 64.0,
  );

  AppSettings copyWith({
    bool? showFloatingBall,
    String? noteFilePath,
    double? floatingBallOpacity,
    double? floatingBallSize,
    DateTime? startDay1,
    DateTime? startDay2,
  }) {
    return AppSettings(
      showFloatingBall: showFloatingBall ?? this.showFloatingBall,
      noteFilePath: noteFilePath ?? this.noteFilePath,
      floatingBallOpacity: floatingBallOpacity ?? this.floatingBallOpacity,
      floatingBallSize: floatingBallSize ?? this.floatingBallSize,
      startDay1: startDay1 ?? this.startDay1,
      startDay2: startDay2 ?? this.startDay2,
    );
  }
}

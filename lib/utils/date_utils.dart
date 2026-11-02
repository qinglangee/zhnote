const List<String> _weekdayLabels = <String>[
  '周一',
  '周二',
  '周三',
  '周四',
  '周五',
  '周六',
  '周日',
];

/// 格式化为 yyyy-MM-dd。
String dateKey(DateTime date) {
  final String year = date.year.toString().padLeft(4, '0');
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// 返回中文星期，例如“周一”。
String weekdayLabel(DateTime date) => _weekdayLabels[date.weekday - 1];

/// 格式化为 “yyyy-MM-dd 周X”。
String dateWithWeekday(DateTime date) => '${dateKey(date)} ${weekdayLabel(date)}';

/// 格式化为 HH:mm。
String timeLabel(DateTime time) {
  final String hour = time.hour.toString().padLeft(2, '0');
  final String minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

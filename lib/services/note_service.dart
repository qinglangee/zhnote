import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../models/app_settings.dart';
import '../utils/date_utils.dart';

/// 保存笔记时可以直接展示给用户的错误。
class NoteSaveException implements Exception {
  const NoteSaveException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NoteService {
  static const String dailyLine = '## daily daily';

  static final RegExp _headerPattern = RegExp(r'^\*\*\* (\d{4}-\d{2}-\d{2}) ');

  /// 把一条笔记追加到 [date] 对应的日期块中。
  ///
  /// 若日期块不存在，则新建一个完整的日期块，并按日期顺序插入到已有块之间；
  /// 日期晚于所有已有块时追加到文件末尾。
  Future<void> appendNote({
    required DateTime date,
    required String text,
    required AppSettings settings,
    DateTime? now,
  }) async {
    final String path = settings.noteFilePath.trim();
    if (path.isEmpty) {
      throw const NoteSaveException('还没有设置笔记文件位置，请先在设置中设置笔记文件位置。');
    }

    final DateTime? startDay1 = settings.startDay1;
    final DateTime? startDay2 = settings.startDay2;
    if (startDay1 == null || startDay2 == null) {
      throw const NoteSaveException('还没有设置 startDay1 / startDay2，请先在设置中完成设置。');
    }

    final String noteText = text.replaceAll('\r\n', '\n').trim();
    if (noteText.isEmpty) {
      throw const NoteSaveException('笔记内容不能为空。');
    }

    final File file = File(path);
    String original = '';
    if (await file.exists()) {
      try {
        original = await file.readAsString(encoding: utf8);
      } on FileSystemException catch (error) {
        throw NoteSaveException('读取笔记文件失败：${error.message}');
      } on FormatException {
        throw const NoteSaveException('笔记文件不是有效的 UTF-8 文本。');
      }
    }

    final String eol = original.contains('\r\n') ? '\r\n' : '\n';
    final String normalized = original.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final List<String> lines = normalized.split('\n');
    final List<String> noteLines = noteText.split('\n');
    final DateTime clock = now ?? DateTime.now();
    final String header = '*** ${dateWithWeekday(date)}';
    final String firstNoteLine = '${timeLabel(clock)} ${noteLines.first}';

    final int headerIndex = lines.indexWhere((String line) => line.trimRight() == header);
    if (headerIndex >= 0) {
      _insertIntoExistingBlock(
        lines: lines,
        headerIndex: headerIndex,
        dailyLine: dailyLine,
        noteLines: <String>[firstNoteLine, ...noteLines.skip(1)],
      );
    } else {
      final List<String> block = <String>[
        header,
        firstNoteLine,
        ...noteLines.skip(1),
        '',
        dailyLine,
        _luckNumbersLine(Random()),
        _dayCountLine(startDay1, date),
        _totalDaysLine(startDay2, date),
      ];
      final int? insertIndex = _findBlockInsertIndex(lines, date);
      if (insertIndex == null) {
        _appendNewBlock(lines: lines, block: block);
      } else {
        _insertBlockAt(lines: lines, index: insertIndex, block: block);
      }
    }

    String result = lines.join('\n');
    if (!result.endsWith('\n')) {
      result += '\n';
    }
    if (eol == '\r\n') {
      result = result.replaceAll('\n', '\r\n');
    }

    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(result, encoding: utf8, flush: true);
    } on FileSystemException catch (error) {
      throw NoteSaveException('写入笔记文件失败：${error.message}');
    }
  }

  /// 在已有日期块中插入笔记：位于 `## daily daily` 上方，
  /// 且保留 daily 行上方原有空行（空行始终在笔记内容之下）。
  void _insertIntoExistingBlock({
    required List<String> lines,
    required int headerIndex,
    required String dailyLine,
    required List<String> noteLines,
  }) {
    int blockEnd = lines.length;
    for (int i = headerIndex + 1; i < lines.length; i++) {
      if (lines[i].startsWith('*** ')) {
        blockEnd = i;
        break;
      }
    }

    int insertIndex = blockEnd;
    for (int i = headerIndex + 1; i < blockEnd; i++) {
      if (lines[i].trimRight() == dailyLine) {
        insertIndex = i;
        break;
      }
    }

    while (insertIndex > headerIndex + 1 && lines[insertIndex - 1].trim().isEmpty) {
      insertIndex--;
    }

    for (int i = 0; i < noteLines.length; i++) {
      lines.insert(insertIndex + i, noteLines[i]);
    }
  }

  /// 返回新日期块应插入的行号：第一个日期晚于 [date] 的块。
  ///
  /// 没有符合条件的块时返回 null，表示追加到文件末尾。
  int? _findBlockInsertIndex(List<String> lines, DateTime date) {
    final DateTime target = DateTime.utc(date.year, date.month, date.day);
    for (int i = 0; i < lines.length; i++) {
      final RegExpMatch? match = _headerPattern.firstMatch(lines[i]);
      if (match == null) {
        continue;
      }
      final DateTime? blockDate = DateTime.tryParse(match.group(1)!);
      if (blockDate == null) {
        continue;
      }
      final DateTime normalized = DateTime.utc(blockDate.year, blockDate.month, blockDate.day);
      if (normalized.isAfter(target)) {
        return i;
      }
    }
    return null;
  }

  /// 在 [index] 处插入日期块，并保证块与前后内容之间有空行分隔。
  void _insertBlockAt({
    required List<String> lines,
    required int index,
    required List<String> block,
  }) {
    final List<String> toInsert = <String>[];
    if (index > 0 && lines[index - 1].trim().isNotEmpty) {
      toInsert.add('');
    }
    toInsert.addAll(block);
    toInsert.add('');
    lines.insertAll(index, toInsert);
  }

  void _appendNewBlock({required List<String> lines, required List<String> block}) {
    while (lines.isNotEmpty && lines.last.trim().isEmpty) {
      lines.removeLast();
    }
    if (lines.isNotEmpty) {
      lines.add('');
    }
    lines.addAll(block);
  }

  String _luckNumbersLine(Random random) {
    final int luck1 = 100 + random.nextInt(900);
    final int luck2 = 10000 + random.nextInt(90000);
    return '今日幸运数字 $luck1 $luck2';
  }

  String _dayCountLine(DateTime startDay1, DateTime date) {
    final int days = _daysBetween(startDay1, date);
    final int years = _yearsOver(startDay1, date);
    return '又是没练功的一天 $days 超 $years 年了';
  }

  String _totalDaysLine(DateTime startDay2, DateTime date) {
    return '第 ${_daysBetween(startDay2, date)} 天';
  }

  /// 只按年月日计算两个日期的天数差。
  int _daysBetween(DateTime start, DateTime end) {
    final DateTime a = DateTime.utc(start.year, start.month, start.day);
    final DateTime b = DateTime.utc(end.year, end.month, end.day);
    return b.difference(a).inDays;
  }

  /// 计算 [end] 相对 [start] 已经满多少年。
  int _yearsOver(DateTime start, DateTime end) {
    final DateTime b = DateTime.utc(end.year, end.month, end.day);
    int years = end.year - start.year;
    if (years <= 0) {
      return 0;
    }
    final DateTime anniversary = DateTime.utc(start.year + years, start.month, start.day);
    if (anniversary.isAfter(b)) {
      years -= 1;
    }
    return years < 0 ? 0 : years;
  }
}

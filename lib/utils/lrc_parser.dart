/// LRC 歌词解析器
class LrcParser {
  /// 解析 LRC 格式歌词，返回按时间排序的歌词行列表
  /// 格式: [mm:ss.xx]歌词内容
  static List<LrcLine> parse(String lrcText) {
    final lines = <LrcLine>[];
    final regex = RegExp(r'\[(\d+):(\d+)([.:]\d+)?\](.*)');

    for (final rawLine in lrcText.split('\n')) {
      final match = regex.firstMatch(rawLine.trim());
      if (match == null) continue;

      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final msStr = match.group(3)?.replaceAll(RegExp(r'[.:]'), '') ?? '0';
      final milliseconds = int.parse(msStr.padRight(3, '0').substring(0, 3));

      final timestamp = Duration(
        minutes: minutes,
        seconds: seconds,
        milliseconds: milliseconds,
      );

      final text = match.group(4)?.trim() ?? '';
      // 跳过空歌词行和时间标签行
      if (text.isEmpty) continue;

      lines.add(LrcLine(timestamp: timestamp, text: text));
    }

    // 按时间排序
    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }

  /// 根据当前播放位置找到当前歌词行索引
  /// 返回 -1 表示还没到第一行
  static int findCurrentLine(List<LrcLine> lines, Duration position) {
    if (lines.isEmpty) return -1;

    // 二分查找：找最后一个 timestamp <= position 的行
    int left = 0, right = lines.length - 1;
    int result = -1;

    while (left <= right) {
      final mid = (left + right) ~/ 2;
      if (lines[mid].timestamp <= position) {
        result = mid;
        left = mid + 1;
      } else {
        right = mid - 1;
      }
    }

    return result;
  }

  /// 获取当前歌词文本
  static String? getCurrentText(List<LrcLine> lines, Duration position) {
    final idx = findCurrentLine(lines, position);
    if (idx < 0) return null;
    return lines[idx].text;
  }
}

/// 单行歌词
class LrcLine {
  final Duration timestamp;
  final String text;

  const LrcLine({required this.timestamp, required this.text});
}

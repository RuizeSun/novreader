/// 章节解析工具
/// 使用用户提供的正则表达式对 txt 内容进行分章节。
/// 正则表达式来源于任务描述：
/// ^(?:(.+[ 　]+)|())(第[一二三四五六七八九十零〇百千万两0123456789]+[章卷]|卷[一二三四五六七八九十零〇百千万两0123456789]+|chap(?:ter)\.?|vol(?:ume)?\.?|book|bk)(?:[ 　]+(?:\S.*)?)?[ 　]*

final RegExp _chapterReg = RegExp(
  r'^(?:(.+[ \u3000]+)|())(第[一二三四五六七八九十零〇百千万两0123456789]+[章卷]|卷[一二三四五六七八九十零〇百千万两0123456789]+|chap(?:ter)\.?|vol(?:ume)?\.?|book|bk)(?:[ \u3000]+(?:\S.*)?)?[ \u3000]*$',
  multiLine: true,
);

/// 将全文按章节拆分，返回每个章节的完整文本（包括章节标题及其内容）。
/// 返回的列表顺序与文本中出现的顺序一致。如果未匹配到任何章节标题，
/// 则返回仅包含原始全文的单一章节。
List<String> splitIntoChapters(String content) {
  final matches = _chapterReg.allMatches(content).toList();
  if (matches.isEmpty) {
    // 若未匹配到章节，返回整篇作为唯一章节
    return [content];
  }

  final List<String> chapters = [];
  for (int i = 0; i < matches.length; i++) {
    final start = matches[i].start;
    final end = (i + 1 < matches.length)
        ? matches[i + 1].start
        : content.length;
    // 包含章节标题及其后面的所有内容
    final chapterText = content.substring(start, end).trim();
    chapters.add(chapterText);
  }
  return chapters;
}

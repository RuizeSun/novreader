/// 章节解析工具
/// 使用用户提供的正则表达式对 txt 内容进行分章节。
/// 正则表达式来源于任务描述：
/// ^(?:(.+[ 　]+)|())(第[一二三四五六七八九十零〇百千万两0123456789]+[章卷]|卷[一二三四五六七八九十零〇百千万两0123456789]+|chap(?:ter)\.?|vol(?:ume)?\.?|book|bk)(?:[ 　]+(?:\S.*)?)?[ 　]*

final RegExp _chapterReg = RegExp(
  r'^(?:(.+[ \u3000]+)|())(第[一二三四五六七八九十零〇百千万两0123456789]+[章卷]|卷[一二三四五六七八九十零〇百千万两0123456789]+|chap(?:ter)\.?|vol(?:ume)?\.?|book|bk)(?:[ \u3000]+(?:\S.*)?)?[ \u3000]*$',
  multiLine: true,
);

/// 将全文按章节拆分，返回章节标题列表（每个标题对应后面的内容）
/// 返回的列表顺序与文本中出现的顺序一致。
List<String> splitIntoChapters(String content) {
  final matches = _chapterReg.allMatches(content);
  if (matches.isEmpty) {
    // 若未匹配到章节，返回整篇作为唯一章节
    return [content];
  }
  final List<String> chapters = [];
  for (final m in matches) {
    // 章节标题为匹配的整行文本（去除前后空白）
    final title = m.group(0)!.trim();
    chapters.add(title);
  }
  return chapters;
}

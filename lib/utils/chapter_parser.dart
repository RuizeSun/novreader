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
/// 则按大小自动切分伪章节，避免阅读页对整个大文件一次性分页导致卡死。
List<String> splitIntoChapters(String content) {
  // 若内容为空，直接返回空
  if (content.isEmpty) return [];

  final matches = _chapterReg.allMatches(content).toList();
  if (matches.isEmpty) {
    // 若未匹配到章节，按大小自动切分伪章节
    // 阈值：超过 100KB 的文件才需要切分
    const int chunkThreshold = 100 * 1024; // 100KB（按字符计，中文字符 1 char ~ 3 bytes）
    const int chunkSize = 50 * 1024; // 每 50KB 一切

    if (content.length <= chunkThreshold) {
      return [content];
    }

    final List<String> chunks = [];
    int start = 0;
    while (start < content.length) {
      int end = start + chunkSize;
      if (end > content.length) end = content.length;

      // 尽量在换行符处断切，避免断在行中间
      if (end < content.length) {
        final newlinePos = content.lastIndexOf('\n', end);
        if (newlinePos > start + chunkSize ~/ 2) {
          // 如果后半段有换行符，在换行符处切
          end = newlinePos + 1; // 包含换行符，使阅读页标题提取能拿到行内容
        } else {
          // 没有合适换行符，尝试句号/句尾
          final sentenceEnd = content.lastIndexOf(RegExp(r'[。！？\n]'), end);
          if (sentenceEnd > start + chunkSize ~/ 2) {
            end = sentenceEnd + 1;
          }
        }
      }

      final chunk = content.substring(start, end).trim();
      if (chunk.isNotEmpty) {
        chunks.add(chunk);
      }
      start = end;
    }

    // 如果切分后只有一个块且内容不多，直接返回
    if (chunks.length <= 1) {
      return [content];
    }

    return chunks;
  }

  final List<String> chapters = [];
  int lastEnd = 0; // 用于处理前置内容

  // 处理第一章之前可能存在的引言或无章节标题内容
  if (matches.first.start > 0) {
    final preChapterText = content.substring(0, matches.first.start).trim();
    if (preChapterText.isNotEmpty) {
      chapters.add(preChapterText);
    }
  }

  for (int i = 0; i < matches.length; i++) {
    final start = matches[i].start;
    final end = (i + 1 < matches.length)
        ? matches[i + 1].start
        : content.length;
    // 包含章节标题及其后面的所有内容
    final chapterText = content.substring(start, end).trim();
    chapters.add(chapterText);
    lastEnd = end;
  }

  // 处理所有章节之后可能存在的跋或后记内容
  if (lastEnd < content.length) {
    final postChapterText = content.substring(lastEnd, content.length).trim();
    if (postChapterText.isNotEmpty) {
      chapters.add(postChapterText);
    }
  }

  return chapters;
}

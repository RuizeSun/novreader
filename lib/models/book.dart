import 'dart:convert';

/// 书籍模型，保存在本地持久化（SharedPreferences）
class Book {
  final String id; // uuid
  final String title; // 书名
  final String filePath; // 本地复制后的完整路径
  final int? bangumiSubjectId; // 可为空，关联的 Bangumi subject id
  // 阅读进度（单位：像素偏移），用于在阅读页面恢复滚动位置
  final double? readingProgress;

  Book({
    required this.id,
    required this.title,
    required this.filePath,
    this.bangumiSubjectId,
    this.readingProgress,
  });

  factory Book.fromJson(Map<String, dynamic> json) => Book(
    id: json['id'] as String,
    title: json['title'] as String,
    filePath: json['filePath'] as String,
    bangumiSubjectId: json['bangumiSubjectId'] as int?,
    readingProgress: (json['readingProgress'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'filePath': filePath,
    'bangumiSubjectId': bangumiSubjectId,
    'readingProgress': readingProgress,
  };

  Book copyWith({
    String? id,
    String? title,
    String? filePath,
    int? bangumiSubjectId,
    double? readingProgress,
  }) => Book(
    id: id ?? this.id,
    title: title ?? this.title,
    filePath: filePath ?? this.filePath,
    bangumiSubjectId: bangumiSubjectId ?? this.bangumiSubjectId,
    readingProgress: readingProgress ?? this.readingProgress,
  );
}

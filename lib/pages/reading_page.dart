import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // for compute
import '../models/book.dart';
import '../utils/chapter_parser.dart';
import '../services/book_repository.dart';

/// 阅读页面，展示书籍内容并支持章节导航。
class ReadingPage extends StatefulWidget {
  final Book book;
  const ReadingPage({Key? key, required this.book}) : super(key: key);

  @override
  State<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends State<ReadingPage> {
  late Future<String> _contentFuture;
  List<String> _chapters = [];
  int _selectedChapter = 0;
  String _currentText = '';
  final ScrollController _scrollController = ScrollController();
  final BookRepository _repo = BookRepository();

  @override
  void initState() {
    super.initState();
    _contentFuture = _loadContent();
    // Listen to scroll changes to persist reading progress.
    _scrollController.addListener(_onScroll);
  }

  // Load the full text content of the book. We also attempt to split it into
  // chapters using the existing `splitIntoChapters` utility. If chapters are
  // detected, we keep the first chapter's content for initial display; otherwise
  // we display the whole text.
  // Helper for compute isolate.
  static Future<String> _readFile(String path) async =>
      File(path).readAsString();

  Future<String> _loadContent() async {
    // Use compute to avoid blocking the UI thread for large files.
    final content = await compute(_readFile, widget.book.filePath);
    _chapters = splitIntoChapters(content);
    _currentText = content;
    // Restore previous scroll offset if any.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final offset = widget.book.readingProgress ?? 0.0;
      if (offset > 0 && _scrollController.hasClients) {
        _scrollController.jumpTo(offset);
      }
    });
    return content;
  }

  void _selectChapter(int index) {
    setState(() {
      _selectedChapter = index;
      _currentText = _chapters[index];
    });
    // When switching chapters, reset scroll position and persist.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
        _saveProgress(0);
      }
    });
  }

  // Persist the current scroll offset to the book model.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    _saveProgress(offset);
  }

  void _saveProgress(double offset) async {
    final updated = widget.book.copyWith(readingProgress: offset);
    await _repo.updateBook(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.book.title)),
      body: FutureBuilder<String>(
        future: _contentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('加载失败: ${snapshot.error}'));
          }
          // Simple reading view: display the full text content. If chapter
          // navigation is desired in the future, a drawer or side panel can be
          // added, but the primary goal is to show the book's text.
          return SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: Text(
              _currentText,
              style: const TextStyle(fontSize: 16, height: 1.6),
            ),
          );
        },
      ),
    );
  }
}

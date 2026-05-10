import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
// 假設這些路徑與你的專案一致
import '../models/book.dart';
import '../utils/chapter_parser.dart';
import '../services/book_repository.dart';

/// 閱讀頁面：支持動態精確分頁、章節跳轉（目錄）與進度保存。
class ReadingPage extends StatefulWidget {
  final Book book;
  const ReadingPage({Key? key, required this.book}) : super(key: key);

  @override
  State<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends State<ReadingPage> {
  late Future<void> _initTask;
  final BookRepository _repo = BookRepository();
  late PageController _pageController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // 內容相關
  List<String> _chapters = [];
  List<String> _chapterTitles = []; // 目錄標題
  int _selectedChapter = 0;
  List<String> _pages = [];
  int _currentPage = 0;

  // 狀態鎖
  bool _isLoadingChapter = false;
  bool _isAnimating = false;

  // 進度保存防抖
  Timer? _saveTimer;

  // 字體樣式
  final TextStyle _textStyle = const TextStyle(
    fontSize: 18,
    height: 1.6,
    color: Colors.black87,
    fontFamily: 'Roboto',
  );

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initTask = _initializeReader();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  /// 初始化閱讀器
  Future<void> _initializeReader() async {
    try {
      final String fullContent = await compute(_readFile, widget.book.filePath);
      // 使用你的工具類解析章節
      final List<String> parsedChapters = splitIntoChapters(fullContent);

      _chapters = parsedChapters.isEmpty ? [fullContent] : parsedChapters;

      // 提取目錄標題（取每章前 20 個字或第一行）
      _chapterTitles = _chapters.map((content) {
        String firstLine = content.trim().split('\n').first;
        if (firstLine.length > 25) return '${firstLine.substring(0, 22)}...';
        return firstLine.isEmpty ? "無標題章節" : firstLine;
      }).toList();

      // 恢復上次閱讀的章節（這裡假設 book 模型中有存儲 chapterIndex）
      // 如果沒有，預設為 0
      _selectedChapter = 0;

      await _initialPagination();
    } catch (e) {
      debugPrint('加載失敗: $e');
      final errorMsg = _formatErrorMessage(e);
      _chapters = [errorMsg];
      _chapterTitles = ['錯誤'];
      _paginateStatic(errorMsg);
    }
  }

  static Future<String> _readFile(String path) async =>
      File(path).readAsString();

  /// 格式化錯誤訊息，顯示具體的錯誤類型和原因
  String _formatErrorMessage(Object e) {
    final String errorType = e.runtimeType.toString();
    final String errorMsg = e.toString();

    // 提取錯誤類型名稱（去掉 "Exception" 或 "Error" 後綴以更簡潔）
    String readableType = errorType;
    if (readableType.endsWith('Exception')) {
      readableType = readableType.substring(0, readableType.length - 9);
    } else if (readableType.endsWith('Error')) {
      readableType = readableType.substring(0, readableType.length - 5);
    }

    // 針對常見的文件操作錯誤提供更友好的說明
    if (e is PathNotFoundException) {
      return '加载失败：无法打开文件\n路径：${e.path}\n——OSError: ${e.message}';
    } else if (e is FileSystemException) {
      return '加载失败：文件系统错误\n路径：${e.path}\n——OSError: ${e.message}';
    } else if (e is FormatException) {
      return '加载失败：文件格式错误\n——FormatException: ${e.message}';
    }

    // 通用錯誤格式
    return '加载失败：$readableType\n——$errorMsg';
  }

  /// 初始分頁
  Future<void> _initialPagination() async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    // 扣除 UI 佔用高度
    final double availableHeight =
        size.height - kToolbarHeight - padding.top - 60;
    final double availableWidth = size.width - 32;

    _performPagination(
      _chapters[_selectedChapter],
      availableWidth,
      availableHeight,
    );

    final savedPage = widget.book.readingProgress?.toInt() ?? 0;
    _currentPage = savedPage.clamp(
      0,
      _pages.isNotEmpty ? _pages.length - 1 : 0,
    );

    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentPage);
      }
    });
  }

  /// 核心分頁算法
  void _performPagination(String text, double width, double height) {
    if (text.isEmpty) {
      _pages = ['無內容'];
      return;
    }

    final List<String> result = [];
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      // 估算最大行數以優化效能
      maxLines: (height / (_textStyle.fontSize! * _textStyle.height!)).floor(),
    );

    int start = 0;
    while (start < text.length) {
      int end = start + 2000; // 預取一段長度
      if (end > text.length) end = text.length;

      textPainter.text = TextSpan(
        text: text.substring(start, end),
        style: _textStyle,
      );
      textPainter.layout(maxWidth: width);

      final TextPosition pos = textPainter.getPositionForOffset(
        Offset(width, height),
      );
      int count = pos.offset;

      if (count <= 0) count = 1;

      result.add(text.substring(start, start + count));
      start += count;
    }
    _pages = result;
  }

  /// 切換章節（供目錄跳轉與翻頁使用）
  void _selectChapter(int index, {bool jumpToLast = false}) async {
    if (index < 0 || index >= _chapters.length || _isLoadingChapter) return;

    setState(() => _isLoadingChapter = true);

    // 如果目錄打開著，先關閉目錄
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }

    // 延遲一點點確保 UI 渲染（如果從 Drawer 跳轉需要時間關閉選單）
    await Future.delayed(const Duration(milliseconds: 100));

    // 獲取容器尺寸
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final double availableHeight =
        size.height - kToolbarHeight - padding.top - 60;
    final double availableWidth = size.width - 32;

    _performPagination(_chapters[index], availableWidth, availableHeight);

    final targetPage = jumpToLast ? (_pages.length - 1) : 0;

    setState(() {
      _selectedChapter = index;
      _currentPage = targetPage;
      _isLoadingChapter = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(targetPage);
      }
      _isAnimating = false;
    });
  }

  void _paginateStatic(String msg) {
    setState(() {
      _pages = [msg];
      _currentPage = 0;
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
    _debounceSaveProgress(index.toDouble());
  }

  void _debounceSaveProgress(double page) {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), () async {
      // 這裡可以同時保存 _selectedChapter
      final updated = widget.book.copyWith(readingProgress: page);
      await _repo.updateBook(updated);
    });
  }

  void _goPrev() {
    if (_isAnimating || _isLoadingChapter) return;
    if (_currentPage > 0) {
      _isAnimating = true;
      _pageController
          .previousPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          )
          .then((_) => _isAnimating = false);
    } else if (_selectedChapter > 0) {
      _selectChapter(_selectedChapter - 1, jumpToLast: true);
    }
  }

  void _goNext() {
    if (_isAnimating || _isLoadingChapter) return;
    if (_currentPage < _pages.length - 1) {
      _isAnimating = true;
      _pageController
          .nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          )
          .then((_) => _isAnimating = false);
    } else if (_selectedChapter < _chapters.length - 1) {
      _selectChapter(_selectedChapter + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F5D1),
      appBar: AppBar(
        title: Text(widget.book.title, style: const TextStyle(fontSize: 16)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            tooltip: '目录',
          ),
          Center(child: Text('第 ${_selectedChapter + 1} 章 ')),
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: _goPrev),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: _goNext),
        ],
      ),
      // --- 新增目錄 Drawer ---
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFFE6E6B8)),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.book, size: 40, color: Colors.brown),
                    const SizedBox(height: 10),
                    Text(
                      widget.book.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '共 ${_chapters.length} 章',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _chapterTitles.length,
                itemBuilder: (context, index) {
                  bool isSelected = _selectedChapter == index;
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: isSelected
                          ? Colors.brown
                          : Colors.grey[300],
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    title: Text(
                      _chapterTitles[index],
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected ? Colors.brown : Colors.black87,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onTap: () => _selectChapter(index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // --- 內容區域 ---
      body: FutureBuilder(
        future: _initTask,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_isLoadingChapter) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }

          return Column(
            children: [
              Expanded(
                child: Listener(
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent) {
                      if (event.scrollDelta.dy > 50)
                        _goNext();
                      else if (event.scrollDelta.dy < -50)
                        _goPrev();
                    }
                  },
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _pages.length,
                    physics: _isLoadingChapter
                        ? const NeverScrollableScrollPhysics()
                        : const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: SelectableText(_pages[index], style: _textStyle),
                      );
                    },
                  ),
                ),
              ),
              // 底部狀態欄
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 10.0,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.03),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '章節進度: ${_currentPage + 1} / ${_pages.length}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '全書: ${((_selectedChapter / _chapters.length) * 100).toStringAsFixed(1)}%',
                      style: TextStyle(color: Colors.grey[700], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

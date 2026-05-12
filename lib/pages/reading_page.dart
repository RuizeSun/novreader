import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:novriidaa_reader/providers/theme_provider.dart';
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
  String _currentChapterTitle = ''; // 当前章节标题（不含正文）
  String _currentChapterBody = ''; // 当前章节正文（不含标题行）

  // 狀態鎖
  bool _isLoadingChapter = false;
  bool _isAnimating = false;

  // 進度保存防抖
  Timer? _saveTimer;

  // 文字樣式將根據 ThemeProvider 中的閱讀設定動態生成
  ThemeProvider? _themeProvider;
  TextStyle get _textStyle => TextStyle(
    fontSize: _themeProvider?.readingFontSize ?? 18,
    height: _themeProvider?.readingLineHeight ?? 1.6,
    color: Colors.black87,
    fontFamily: 'Roboto',
  );

  // 用於檢測佈局尺寸變化
  double _lastLayoutWidth = 0;
  double _lastLayoutHeight = 0;

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

      // 提取第一章的标题和正文
      _extractChapterTitleAndBody(_selectedChapter);

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

    // 分頁由 LayoutBuilder 在首次佈局時處理
    // 此處僅恢復閱讀進度
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

  /// 二分查找：在 [targetLines] 行内容纳的最多字符数
  /// 适用于每页固定行数的场景，比 getPositionForOffset 更精确。
  int _binarySearchLineBreak(
    String text,
    double width, {
    required int targetLines,
  }) {
    int low = 0;
    int high = text.length;

    while (low < high) {
      final int mid = (low + high + 1) ~/ 2;
      final tp = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(text: text.substring(0, mid), style: _textStyle),
      );
      tp.layout(maxWidth: width);
      if (tp.computeLineMetrics().length <= targetLines) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }

  /// 核心分頁算法
  /// 使用 computeLineMetrics() + 二分查找替代旧的 getPositionForOffset 方案，
  /// 避免 TextPainter 与 SelectableText 渲染差异和行尾截断问题。
  void _performPagination(String text, double width, double height) {
    if (text.isEmpty) {
      _pages = ['無內容'];
      return;
    }

    final double lineHeight = _textStyle.fontSize! * _textStyle.height!;
    final int maxLines = ((height - 8) / lineHeight).floor();
    if (maxLines <= 0) {
      _pages = [text];
      return;
    }

    final List<String> result = [];

    int start = 0;
    while (start < text.length) {
      int end = start + 2000;
      if (end > text.length) end = text.length;

      // 不设 maxLines，让 TextPainter 完整布局文字，再用 computeLineMetrics 判断
      final textPainter = TextPainter(textDirection: TextDirection.ltr);
      textPainter.text = TextSpan(
        text: text.substring(start, end),
        style: _textStyle,
      );
      // 与 SelectableText 使用完全一致的宽度，消除渲染偏差
      textPainter.layout(maxWidth: width);

      final lineMetrics = textPainter.computeLineMetrics();

      int count;
      if (lineMetrics.length <= maxLines) {
        // 全部文本刚好能在一页内显示
        count = text.substring(start, end).length;
      } else {
        // 二分查找精确的行断点
        count = _binarySearchLineBreak(
          text.substring(start, end),
          width,
          targetLines: maxLines,
        );
      }

      if (count <= 0) count = 1;
      result.add(text.substring(start, start + count));
      start += count;
    }
    _pages = result;
  }

  /// 从章节内容中提取标题行和正文
  void _extractChapterTitleAndBody(int index) {
    if (index < 0 || index >= _chapters.length) return;
    final String content = _chapters[index];
    final List<String> lines = content.trim().split('\n');
    _currentChapterTitle = lines.isNotEmpty ? lines.first : '';
    _currentChapterBody = lines.length > 1 ? lines.sublist(1).join('\n') : '';
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

    // 提取标题和正文
    _extractChapterTitleAndBody(index);

    // 使用 LayoutBuilder 已捕獲的佈局尺寸，確保與窗口自適應邏輯一致
    _performPagination(
      _currentChapterBody,
      _lastLayoutWidth > 0
          ? _lastLayoutWidth
          : (MediaQuery.of(context).size.width - 32),
      _lastLayoutHeight > 0
          ? _lastLayoutHeight
          : (MediaQuery.of(context).size.height -
                kToolbarHeight -
                MediaQuery.of(context).padding.top -
                60),
    );

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
    if (_currentPage < _displayPageCount - 1) {
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

  // Build the page view, supporting optional double‑column layout based on ThemeProvider settings.
  Widget _buildPageView(BoxConstraints constraints, ThemeProvider provider) {
    // 判斷是否啟用雙欄以及螢幕寬度是否達到觸發阈值。
    final bool useDoubleColumn =
        provider.doubleColumnEnabled &&
        constraints.maxWidth >= provider.doubleColumnTriggerWidth;

    // 计算最大行数，防止 SelectableText 渲染溢出
    // 使用与 _performPagination 一致的 8px 安全余量
    final double textHeight =
        constraints.maxHeight -
        16.0 -
        (_currentChapterTitle.isNotEmpty
            ? (provider.readingTitleFontSize + 12.0)
            : 0);
    final int maxLines =
        ((textHeight - 8) / (_textStyle.fontSize! * _textStyle.height!))
            .floor();

    if (useDoubleColumn) {
      // 双栏实现：每页显示两个连续的分页项，左右各一栏
      final int pageCount = (_pages.length + 1) ~/ 2;
      return PageView.builder(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        itemCount: pageCount,
        physics: _isLoadingChapter
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final int leftIndex = index * 2;
          final int rightIndex = index * 2 + 1;
          final String leftText = leftIndex < _pages.length
              ? _pages[leftIndex]
              : '';
          final String rightText = rightIndex < _pages.length
              ? _pages[rightIndex]
              : '';
          // 仅在每章首页显示章节标题
          final bool isFirstPage = index == 0;
          final String chapterTitle = isFirstPage ? _currentChapterTitle : '';
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (chapterTitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      chapterTitle,
                      style: TextStyle(
                        fontSize: provider.readingTitleFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: SelectableText(
                            leftText,
                            style: _textStyle,
                            maxLines: maxLines,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: SelectableText(
                            rightText,
                            style: _textStyle,
                            maxLines: maxLines,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    // 單欄默認實現。
    return PageView.builder(
      controller: _pageController,
      onPageChanged: _onPageChanged,
      itemCount: _pages.length,
      physics: _isLoadingChapter
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        // 仅在每章首页显示章节标题
        final bool isFirstPage = index == 0;
        final String chapterTitle = isFirstPage ? _currentChapterTitle : '';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (chapterTitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    chapterTitle,
                    style: TextStyle(
                      fontSize: provider.readingTitleFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
              Expanded(
                child: SelectableText(
                  _pages[index],
                  style: _textStyle,
                  maxLines: maxLines,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    // 保存 provider 以供 _textStyle getter 使用
    _themeProvider = themeProvider;
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
                        fontSize: themeProvider.readingTitleFontSize,
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double availableWidth = constraints.maxWidth - 32;
                    final double availableHeight = constraints.maxHeight;

                    // 檢測尺寸變化，重新分頁以適應新窗口大小
                    if (availableWidth != _lastLayoutWidth ||
                        availableHeight != _lastLayoutHeight) {
                      _lastLayoutWidth = availableWidth;
                      _lastLayoutHeight = availableHeight;
                      if (_chapters.isNotEmpty) {
                        final bool useDoubleColumn =
                            themeProvider.doubleColumnEnabled &&
                            constraints.maxWidth >=
                                themeProvider.doubleColumnTriggerWidth;
                        // 统一减去垂直 padding（16px）和标题高度
                        double adjustedHeight = availableHeight;
                        adjustedHeight -=
                            16.0; // Column 垂直 padding（8px top + 8px bottom）
                        if (_currentChapterTitle.isNotEmpty) {
                          adjustedHeight -=
                              (themeProvider.readingTitleFontSize + 12.0);
                        }
                        // 双栏模式下用列宽重新分页，每页文字正好填满一栏高度
                        final double paginateWidth = useDoubleColumn
                            ? (availableWidth - 16) / 2
                            : availableWidth;
                        _performPagination(
                          _currentChapterBody,
                          paginateWidth,
                          adjustedHeight,
                        );
                        // 在下一幀更新 UI 並修正當前頁碼
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          final int maxPage = useDoubleColumn
                              ? ((_pages.length + 1) ~/ 2) - 1
                              : _pages.length - 1;
                          final clampedPage = _currentPage.clamp(0, maxPage);
                          if (clampedPage != _currentPage) {
                            _currentPage = clampedPage;
                            if (_pageController.hasClients) {
                              _pageController.jumpToPage(clampedPage);
                            }
                          }
                          setState(() {});
                        });
                      }
                    }

                    return Listener(
                      onPointerSignal: (event) {
                        if (event is PointerScrollEvent) {
                          if (event.scrollDelta.dy > 50)
                            _goNext();
                          else if (event.scrollDelta.dy < -50)
                            _goPrev();
                        }
                      },
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          // Detect overscroll at the end of a chapter to auto‑switch to the next chapter.
                          if (notification is OverscrollNotification &&
                              notification.overscroll > 0 &&
                              _selectedChapter < _chapters.length - 1 &&
                              !_isLoadingChapter) {
                            // Jump to the next chapter when user scrolls past the last page.
                            _selectChapter(_selectedChapter + 1);
                            return true;
                          }
                          return false;
                        },
                        child: _buildPageView(constraints, themeProvider),
                      ),
                    );
                  },
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
                      '章節進度: ${_currentPage + 1} / ${_displayPageCount}',
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

  /// 双栏模式下每页显示的子页数
  int get _doubleColumnSubPages => 2;

  /// 当前显示模式下的有效页数
  int get _displayPageCount {
    final bool useDoubleColumn =
        _themeProvider?.doubleColumnEnabled == true &&
        _lastLayoutWidth + 32 >=
            (_themeProvider?.doubleColumnTriggerWidth ?? 800);
    if (useDoubleColumn) {
      return (_pages.length + _doubleColumnSubPages - 1) ~/
          _doubleColumnSubPages;
    }
    return _pages.length;
  }
}

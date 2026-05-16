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
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

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
    color: _themeProvider?.readingFontColor ?? Colors.black87,
    fontFamily: 'Roboto',
  );

  // 分页安全边距：补偿 TextPainter 浮点行高与 Flutter 引擎子像素对齐之间的累积误差。
  // 行距越小（如 1.2），误差越明显，保留约 1 行高的余量可完全消除溢出。
  static const double _kPageHeightSafetyMargin = 4.0;

  // 标题真实渲染高度（通过 GlobalKey postFrame 测量，比 TextPainter 估算更准确）。
  // 初始值用 -1 标记"尚未测量"，首次渲染首页标题后触发重新分页。
  final GlobalKey _titleKey = GlobalKey();
  double _measuredTitleHeight = -1;

  // 用於檢測佈局尺寸變化
  double _lastLayoutWidth = 0;
  double _lastLayoutHeight = 0;
  // 用於檢測文字樣式變化（字體大小、行距）
  double _cachedFontSize = 0;
  double _cachedLineHeight = 0;
  // 用于检测标题字体大小变化，触发重新测量
  double _cachedTitleFontSize = 0;

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

  /// 统一的分页入口：优先使用 postFrame 真实测量的标题高度，
  /// 降级时用 TextPainter 估算，两者都比直接用 fontSize 更准确。
  void _paginateWithTitle({
    required double availableWidth,
    required double availableHeight,
    bool useDoubleColumn = false,
  }) {
    double titleHeight = 0.0;
    if (_currentChapterTitle.isNotEmpty) {
      if (_measuredTitleHeight > 0) {
        // 优先：使用 postFrame 读取的真实渲染高度（最准确）
        titleHeight = _measuredTitleHeight;
      } else {
        // 降级：用 TextPainter 估算（首次渲染前使用）
        final tp = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
            text: _currentChapterTitle,
            style: TextStyle(
              fontSize: _themeProvider?.readingTitleFontSize ?? 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
            ),
          ),
        )..layout(maxWidth: availableWidth);
        titleHeight = tp.height + 12.0;
      }
    }

    // 与渲染侧完全对称的高度扣减：
    //   16 = vertical padding (8 top + 8 bottom)
    //   8  = _performPagination 内部 (height - 8) 的那个 8
    //   _kPageHeightSafetyMargin = 浮点行高累积误差补偿
    final double adjustedHeight =
        availableHeight - 16.0 - 8.0 - titleHeight - _kPageHeightSafetyMargin;

    final double paginateWidth = useDoubleColumn
        ? (availableWidth - 16) / 2
        : availableWidth;

    _performPagination(_currentChapterBody, paginateWidth, adjustedHeight);
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
    final int maxLines = ((height - 8 - _kPageHeightSafetyMargin) / lineHeight)
        .floor();
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
    // 切换章节时重置标题测量值，等待新章节首页渲染后重新测量
    _measuredTitleHeight = -1;

    // 使用 LayoutBuilder 已捕獲的佈局尺寸，確保與窗口自適應邏輯一致
    final double w = _lastLayoutWidth > 0
        ? _lastLayoutWidth
        : (MediaQuery.of(context).size.width - 32);
    final double h = _lastLayoutHeight > 0
        ? _lastLayoutHeight
        : (MediaQuery.of(context).size.height -
              kToolbarHeight -
              MediaQuery.of(context).padding.top -
              60);
    final bool useDoubleColumn =
        (_themeProvider?.doubleColumnEnabled ?? false) &&
        (w + 32) >= (_themeProvider?.doubleColumnTriggerWidth ?? 800);
    _paginateWithTitle(
      availableWidth: w,
      availableHeight: h,
      useDoubleColumn: useDoubleColumn,
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
    final bool useDoubleColumn =
        provider.doubleColumnEnabled &&
        constraints.maxWidth >= provider.doubleColumnTriggerWidth;

    // ── 章节标题 Widget ────────────────────────────────────────────────────
    // 挂 GlobalKey 以便 postFrame 读取真实渲染高度（含 strut/字体度量），
    // 比 TextPainter 估算更准确，用于下一次分页。
    Widget _buildTitle() => Padding(
      key: _titleKey,
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        _currentChapterTitle,
        style: TextStyle(
          fontSize: provider.readingTitleFontSize,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
          fontFamily: 'Roboto',
        ),
      ),
    );

    // ── 正文 Widget ────────────────────────────────────────────────────────
    // 核心修复：不再用 maxLines 限制行数（那依赖对标题高度的预测，始终有误差）。
    // 改为：
    //   1. 用 Expanded 让正文区占满 Column 剩余空间（标题自然占位，不用计算）
    //   2. 用 ClipRect 裁剪，彻底防止内容溢出触发 RenderFlex overflow 异常
    //   3. 分页算法侧用 _measuredTitleHeight（postFrame 真实测量值）而非估算值
    Widget _buildTextBlock(String text) => ClipRect(
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(text, style: _textStyle, overflow: TextOverflow.clip),
      ),
    );

    if (useDoubleColumn) {
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
          final bool isFirstPage = index == 0;

          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                if (isFirstPage && _currentChapterTitle.isNotEmpty)
                  _buildTitle(),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildTextBlock(leftText)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextBlock(rightText)),
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
        final bool isFirstPage = index == 0;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
              if (isFirstPage && _currentChapterTitle.isNotEmpty) _buildTitle(),
              Expanded(child: _buildTextBlock(_pages[index])),
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
    // 根据背景亮度动态决定前景色（文字、图标）
    final bool isBgDark =
        ThemeData.estimateBrightnessForColor(
          themeProvider.readingBackgroundColor,
        ) ==
        Brightness.dark;
    final Color appBarForeground = isBgDark ? Colors.white : Colors.black87;
    return Scaffold(
      key: _scaffoldKey,
      // 使用可配置的阅读背景颜色，默认保持原有颜色
      backgroundColor: themeProvider.readingBackgroundColor,
      appBar: AppBar(
        title: Text(widget.book.title, style: const TextStyle(fontSize: 16)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: appBarForeground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showReadingSettings(context),
            tooltip: '阅读设置',
          ),
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

                    // 檢測尺寸或文字樣式變化，重新分頁
                    final double curTitleFontSize =
                        themeProvider.readingTitleFontSize;
                    if (availableWidth != _lastLayoutWidth ||
                        availableHeight != _lastLayoutHeight ||
                        _textStyle.fontSize != _cachedFontSize ||
                        _textStyle.height != _cachedLineHeight ||
                        curTitleFontSize != _cachedTitleFontSize) {
                      _lastLayoutWidth = availableWidth;
                      _lastLayoutHeight = availableHeight;
                      // 标题字体变化时，重置测量值，等待 postFrame 重新测量
                      if (curTitleFontSize != _cachedTitleFontSize) {
                        _measuredTitleHeight = -1;
                        _cachedTitleFontSize = curTitleFontSize;
                      }
                      if (_chapters.isNotEmpty) {
                        final bool useDoubleColumn =
                            themeProvider.doubleColumnEnabled &&
                            constraints.maxWidth >=
                                themeProvider.doubleColumnTriggerWidth;
                        // 更新緩存的文字樣式參數
                        _cachedFontSize = _textStyle.fontSize!;
                        _cachedLineHeight = _textStyle.height!;
                        // 统一调用 _paginateWithTitle，内部使用 _measuredTitleHeight
                        _paginateWithTitle(
                          availableWidth: availableWidth,
                          availableHeight: availableHeight,
                          useDoubleColumn: useDoubleColumn,
                        );
                        // postFrame：读取标题真实高度，若与本次分页用的值不同则重新分页
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          // 读取标题真实渲染高度
                          final titleBox =
                              _titleKey.currentContext?.findRenderObject()
                                  as RenderBox?;
                          if (titleBox != null) {
                            final realHeight = titleBox.size.height;
                            if ((realHeight - _measuredTitleHeight).abs() >
                                0.5) {
                              _measuredTitleHeight = realHeight;
                              // 用真实高度重新分页
                              _paginateWithTitle(
                                availableWidth: availableWidth,
                                availableHeight: availableHeight,
                                useDoubleColumn: useDoubleColumn,
                              );
                            }
                          }
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

  /// 显示阅读设置 BottomSheet
  void _showReadingSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.3,
              maxChildSize: 0.85,
              expand: false,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 拖拽指示条
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const Text(
                        '阅读设置',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 字体大小
                      // 字体大小
                      ListTile(
                        title: const Text('字体大小'),
                        subtitle: Slider.adaptive(
                          min: 12,
                          max: 30,
                          divisions: 18,
                          value: themeProvider.readingFontSize,
                          label:
                              '${themeProvider.readingFontSize.toStringAsFixed(0)}',
                          onChanged: (v) => themeProvider.setReadingFontSize(v),
                        ),
                      ),
                      // 背景颜色设置（预设 + 自定义）
                      ListTile(
                        title: const Text('背景颜色'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 预设颜色块
                            Wrap(
                              spacing: 8,
                              children:
                                  [
                                        Colors.white,
                                        const Color(0xFFF5F5D1),
                                        const Color(0xFFE0E0E0),
                                        const Color(0xFFB0B0B0),
                                        Colors.black,
                                      ]
                                      .map(
                                        (c) => GestureDetector(
                                          onTap: () => themeProvider
                                              .setReadingBackgroundColor(c),
                                          child: Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: c,
                                              border: Border.all(
                                                color:
                                                    themeProvider
                                                            .readingBackgroundColor ==
                                                        c
                                                    ? Colors.blueAccent
                                                    : Colors.transparent,
                                                width: 2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                            ),
                            const SizedBox(height: 8),
                            // 自定义颜色按钮
                            ElevatedButton(
                              onPressed: () => _showBackgroundColorPicker(
                                context,
                                themeProvider,
                              ),
                              child: const Text('自定义颜色'),
                            ),
                          ],
                        ),
                      ),
                      // 字体颜色设置（预设 + 自定义）
                      ListTile(
                        title: const Text('字体颜色'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              children:
                                  [
                                        Colors.black,
                                        Colors.white,
                                        Colors.red,
                                        Colors.green,
                                        Colors.blue,
                                      ]
                                      .map(
                                        (c) => GestureDetector(
                                          onTap: () => themeProvider
                                              .setReadingFontColor(c),
                                          child: Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: c,
                                              border: Border.all(
                                                color:
                                                    themeProvider
                                                            .readingFontColor ==
                                                        c
                                                    ? Colors.blueAccent
                                                    : Colors.transparent,
                                                width: 2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () =>
                                  _showFontColorPicker(context, themeProvider),
                              child: const Text('自定义颜色'),
                            ),
                          ],
                        ),
                      ),
                      // 章节标题大小
                      ListTile(
                        title: const Text('章节标题大小'),
                        subtitle: Slider.adaptive(
                          min: 12,
                          max: 30,
                          divisions: 18,
                          value: themeProvider.readingTitleFontSize,
                          label:
                              '${themeProvider.readingTitleFontSize.toStringAsFixed(0)}',
                          onChanged: (v) =>
                              themeProvider.setReadingTitleFontSize(v),
                        ),
                      ),
                      // 行距
                      ListTile(
                        title: const Text('行距'),
                        subtitle: Slider.adaptive(
                          min: 1.0,
                          max: 2.5,
                          divisions: 15,
                          value: themeProvider.readingLineHeight,
                          label: themeProvider.readingLineHeight
                              .toStringAsFixed(2),
                          onChanged: (v) =>
                              themeProvider.setReadingLineHeight(v),
                        ),
                      ),
                      // 段距
                      ListTile(
                        title: const Text('段距（空行数）'),
                        subtitle: Slider.adaptive(
                          min: 0,
                          max: 5,
                          divisions: 5,
                          value: themeProvider.readingParagraphSpacing,
                          label:
                              '${themeProvider.readingParagraphSpacing.toInt()}',
                          onChanged: (v) =>
                              themeProvider.setReadingParagraphSpacing(v),
                        ),
                      ),
                      const Divider(),
                      // 双栏开关
                      SwitchListTile(
                        title: const Text('双栏布局'),
                        value: themeProvider.doubleColumnEnabled,
                        onChanged: (v) =>
                            themeProvider.setDoubleColumnEnabled(v),
                      ),
                      // 双栏触发宽度
                      ListTile(
                        title: const Text('双栏触发宽度 (px)'),
                        subtitle: Slider.adaptive(
                          min: 600,
                          max: 1200,
                          divisions: 12,
                          value: themeProvider.doubleColumnTriggerWidth,
                          label:
                              '${themeProvider.doubleColumnTriggerWidth.toInt()}',
                          onChanged: (v) =>
                              themeProvider.setDoubleColumnTriggerWidth(v),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // 显示自定义背景颜色选择器
  void _showBackgroundColorPicker(
    BuildContext context,
    ThemeProvider themeProvider,
  ) {
    Color pickerColor = themeProvider.readingBackgroundColor;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('选择背景颜色'),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: pickerColor,
              onColorChanged: (color) => pickerColor = color,
            ),
          ),
          actions: [
            TextButton(
              child: const Text('取消'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('确定'),
              onPressed: () {
                themeProvider.setReadingBackgroundColor(pickerColor);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // 显示自定义字体颜色选择器
  void _showFontColorPicker(BuildContext context, ThemeProvider themeProvider) {
    Color pickerColor = themeProvider.readingFontColor;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('选择字体颜色'),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: pickerColor,
              onColorChanged: (color) => pickerColor = color,
            ),
          ),
          actions: [
            TextButton(
              child: const Text('取消'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('确定'),
              onPressed: () {
                themeProvider.setReadingFontColor(pickerColor);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
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

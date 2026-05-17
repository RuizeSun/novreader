import 'package:flutter/material.dart';
import 'dart:ui'; // 导入以使用 ImageFilter
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/subject.dart';
import '../models/related_person.dart';
import '../models/related_character.dart';
import '../models/book.dart';
import '../models/source_rule.dart';
import '../services/bangumi_service.dart';
import '../services/source_rule_engine.dart';
import '../services/book_repository.dart';
import '../providers/source_provider.dart';
import '../pages/reading_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

// 阅读选项枚举，放在文件顶部，供 _startReading 使用
enum ReadingChoice { reDownload, localRead, addAndRead, cancel }

class SubjectDetailPage extends StatefulWidget {
  final int subjectId;
  final Subject? initialSubject;

  const SubjectDetailPage({
    Key? key,
    required this.subjectId,
    this.initialSubject,
  }) : super(key: key);

  @override
  State<SubjectDetailPage> createState() => _SubjectDetailPageState();
}

class _SubjectDetailPageState extends State<SubjectDetailPage> {
  final BangumiService _bangumiService = BangumiService();
  late Subject _subject;
  bool _isLoading = true;
  String? _error;
  bool _isSummaryExpanded = false;
  bool _isPersonsExpanded = false;
  bool _isCharactersExpanded = false;
  List<RelatedPerson> _persons = [];
  List<RelatedCharacter> _characters = [];
  bool _isPersonsLoading = true;
  bool _isCharactersLoading = true;
  String? _personsError;
  String? _charactersError;

  // 获取相关状态
  bool _isDownloading = false;
  String _downloadStatus = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialSubject != null) {
      _subject = widget.initialSubject!;
      _isLoading = false;
      _loadFullDetails();
      _loadRelatedData();
    } else {
      _fetchSubject();
      _loadRelatedData();
    }
  }

  Future<void> _loadRelatedData() async {
    try {
      final persons = await _bangumiService.getSubjectPersons(widget.subjectId);
      final characters = await _bangumiService.getSubjectCharacters(
        widget.subjectId,
      );
      if (!mounted) return;
      setState(() {
        _persons = persons;
        _characters = characters;
        _isPersonsLoading = false;
        _isCharactersLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _personsError = e.toString();
        _charactersError = e.toString();
        _isPersonsLoading = false;
        _isCharactersLoading = false;
      });
    }
  }

  Future<void> _fetchSubject() async {
    try {
      final subject = await _bangumiService.getSubject(widget.subjectId);
      if (!mounted) return;
      setState(() {
        _subject = subject;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFullDetails() async {
    try {
      final subject = await _bangumiService.getSubject(widget.subjectId);
      if (!mounted) return;
      setState(() {
        _subject = subject;
      });
    } catch (e) {
      // 静默失败，使用初始数据
    }
  }

  /// 开始阅读：先检查本地数据，若存在则弹出选择对话框，否则执行获取流程
  Future<void> _startReading() async {
    // 1. 检查本地是否有已存储的书籍
    final bookRepo = BookRepository();
    final allBooks = await bookRepo.loadBooks();
    Book? existingBook;
    try {
      final matches = allBooks
          .where((b) => b.bangumiSubjectId == widget.subjectId)
          .toList();
      for (final book in matches) {
        if (await File(book.filePath).exists()) {
          existingBook = book;
          break;
        }
      }
    } catch (_) {}

    // 2. 如果本地已有数据，弹出选择对话框
    if (existingBook != null) {
      final choice = await showDialog<ReadingChoice>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('本地已有书籍'),
          content: const Text('该书籍在本地已有存储，请选择操作：'),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(ReadingChoice.reDownload),
              child: const Text('重新获取并阅读'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(ReadingChoice.localRead),
              child: const Text('进入阅读（本地）'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(ReadingChoice.cancel),
              child: const Text('退出'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(ReadingChoice.addAndRead),
              child: const Text('加入书架并阅读'),
            ),
          ],
        ),
      );

      if (choice == null || !mounted) return;

      switch (choice) {
        case ReadingChoice.reDownload:
          // 删除旧文件和旧记录，继续执行下面的获取流程
          try {
            await File(existingBook.filePath).delete();
          } catch (_) {}
          await bookRepo.removeBook(existingBook.id);
          break;
        case ReadingChoice.localRead:
          // 直接阅读本地文件
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReadingPage(book: existingBook!),
            ),
          );
          return;
        case ReadingChoice.addAndRead:
          // 将书籍加入书架（isOnShelf=true），然后阅读
          if (!existingBook!.isOnShelf) {
            final updated = existingBook.copyWith(isOnShelf: true);
            await bookRepo.updateBook(updated);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReadingPage(book: updated),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReadingPage(book: existingBook!),
              ),
            );
          }
          return;
        case ReadingChoice.cancel:
          return;
      }
    }

    // 3. 选择要使用的来源规则
    final sourceProvider = context.read<SourceProvider>();
    final sources = sourceProvider.sources;

    if (sources.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先在设置中导入来源规则')));
      return;
    }

    // 选择要使用的来源规则
    SourceRule? selectedRule;
    if (sources.length == 1) {
      selectedRule = sources.first;
    } else {
      // 多个来源时弹出选择对话框
      selectedRule = await showDialog<SourceRule>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('选择获取来源'),
          children: sources.map((source) {
            return SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(source),
              child: ListTile(
                title: Text(source.name),
                subtitle: Text(source.meta.targetDomain),
                leading: const Icon(Icons.source),
              ),
            );
          }).toList(),
        ),
      );
    }

    if (selectedRule == null || !mounted) return;

    // 获取小说名称作为搜索关键词
    final keyword = _subject.nameCn.isNotEmpty
        ? _subject.nameCn
        : _subject.name;

    // 开始获取
    setState(() {
      _isDownloading = true;
      _downloadStatus = '正在搜索 "$keyword" ...';
    });

    try {
      final engine = SourceRuleEngine(selectedRule);

      setState(() {
        _downloadStatus = '阶段 1/4：正在搜索书籍...';
      });

      final bytes = await engine.execute(keyword: keyword);

      setState(() {
        _downloadStatus = '正在保存文件...';
      });

      // 保存 TXT 文件到本地
      final filePath = await SourceRuleEngine.saveToFile(bytes, keyword);

      // 创建 Book 记录，isOnShelf: false 表示不显示在书架中
      final book = Book(
        id: const Uuid().v4(),
        title: keyword,
        filePath: filePath,
        bangumiSubjectId: widget.subjectId,
        readingProgress: 0,
        isOnShelf: false,
      );

      // 存入仓库（但不显示在书架，需用户选择"加入书架并阅读"后才显示）
      await bookRepo.addBook(book);

      if (!mounted) return;

      setState(() {
        _isDownloading = false;
        _downloadStatus = '';
      });

      // 无论成功还是失败，都先关闭进度遮罩，确保返回时界面正常
      setState(() {
        _isDownloading = false;
        _downloadStatus = "";
      });

      if (!mounted) return;

      // 跳转到阅读页面
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ReadingPage(book: book)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _downloadStatus = "";
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("获取失败: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('加载中...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && widget.initialSubject == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('错误')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text('加载失败: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _fetchSubject, child: const Text('重试')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    _buildScoreRow(),
                    _buildTags(),
                    _buildSummary(),
                    _buildInfoBox(),
                    _buildPersonsSection(),
                    _buildCharactersSection(),
                    const SizedBox(height: 100), // 为底部按钮留出空间
                  ],
                ),
              ),
            ],
          ),
          // 获取进度遮罩
          if (_isDownloading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(32),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          _downloadStatus,
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomSheet: _isDownloading ? null : _buildBottomBar(),
    );
  }

  // ── 下方各 Widget 保持不变 ──

  Widget _buildPersonsSection() {
    if (_isPersonsLoading) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_personsError != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text('人物信息加载失败: $_personsError'),
      );
    }

    if (_persons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '相关人物',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              int columns = (constraints.maxWidth / 200).floor();
              if (columns < 1) columns = 1;
              final int itemsPerRow = columns;
              final int rowCount = (_persons.length / itemsPerRow).ceil();
              final bool showExpandButton = rowCount > 2;

              return Column(
                children: [
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                      childAspectRatio: 4,
                    ),
                    itemCount: _isPersonsExpanded || !showExpandButton
                        ? _persons.length
                        : itemsPerRow * 2,
                    itemBuilder: (context, index) {
                      final person = _persons[index];
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: person.images.medium,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.person, size: 40),
                          ),
                        ),
                        title: Text(person.name),
                        trailing: Text(person.relation),
                      );
                    },
                  ),
                  if (showExpandButton)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                      child: InkWell(
                        key: ValueKey<bool>(_isPersonsExpanded),
                        onTap: () {
                          setState(() {
                            _isPersonsExpanded = !_isPersonsExpanded;
                          });
                        },
                        child: Text(
                          _isPersonsExpanded ? '收起' : '展开',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCharactersSection() {
    if (_isCharactersLoading) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_charactersError != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text('角色信息加载失败: $_charactersError'),
      );
    }

    if (_characters.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '相关角色',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              int columns = (constraints.maxWidth / 180).floor();
              if (columns < 2) columns = 2;
              final int itemsPerRow = columns;
              final int rowCount = (_characters.length / itemsPerRow).ceil();
              final bool showExpandButton = rowCount > 2;

              return Column(
                children: [
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 0.5,
                      crossAxisSpacing: 1,
                      childAspectRatio: 2.8,
                    ),
                    itemCount: _isCharactersExpanded || !showExpandButton
                        ? _characters.length
                        : itemsPerRow * 2,
                    itemBuilder: (context, index) {
                      final character = _characters[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: character.images.medium,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.person, size: 40),
                          ),
                        ),
                        title: Text(character.name),
                        trailing: Text(character.relation),
                        onTap: () async {
                          final go = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('前往角色主页'),
                              content: const Text('是否打开 Bangumi 角色页面？'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('取消'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text('确定'),
                                ),
                              ],
                            ),
                          );
                          if (go == true) {
                            final url = Uri.parse(
                              'https://bgm.tv/character/${character.id}',
                            );
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url);
                            }
                          }
                        },
                      );
                    },
                  ),
                  if (showExpandButton)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                      child: InkWell(
                        key: ValueKey<bool>(_isCharactersExpanded),
                        onTap: () {
                          setState(() {
                            _isCharactersExpanded = !_isCharactersExpanded;
                          });
                        },
                        child: Text(
                          _isCharactersExpanded ? '收起' : '展开',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      // 为返回按钮添加高斯模糊背景以提升可读性
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3), // 稍微加深遮罩
                shape: BoxShape.circle,
              ),
              child: const BackButton(color: Colors.white),
            ),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: _subject.images.large.replaceFirst(
                'https://lain.bgm.tv/pic',
                'https://lain.bgm.tv/r/400/pic',
              ),
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorWidget: (context, url, error) =>
                  const Icon(Icons.image, size: 48),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                ),
              ),
            ),
          ],
        ),
        title: Text(
          _subject.nameCn.isNotEmpty ? _subject.nameCn : _subject.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(offset: Offset(0, 1), blurRadius: 3)],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'subject-${_subject.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: (_subject.images.common ?? _subject.images.medium)
                    .replaceFirst(
                      'https://lain.bgm.tv/pic',
                      'https://lain.bgm.tv/r/400/pic',
                    ),
                width: 100,
                height: 140,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) =>
                    const Icon(Icons.image, size: 48),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _subject.nameCn.isNotEmpty ? _subject.nameCn : _subject.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_subject.nameCn.isNotEmpty &&
                    _subject.nameCn != _subject.name)
                  Text(
                    _subject.name,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                const SizedBox(height: 8),
                if (_subject.date != null)
                  Text(
                    '发售日: ${_subject.date}',
                    style: const TextStyle(fontSize: 13),
                  ),
                const SizedBox(height: 4),
                if (_subject.rank != 0)
                  Text(
                    '排名: #${_subject.rank}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: _buildScoreItem(
                '评分',
                _subject.rating.score.toString(),
                Icons.star,
              ),
            ),
            Expanded(
              child: _buildScoreItem(
                '评价数',
                _subject.rating.count.toString(),
                Icons.people,
              ),
            ),
            Expanded(
              child: _buildScoreItem(
                '收藏',
                _subject.collectionsCount.toString(),
                Icons.favorite,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.orange),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildTags() {
    if (_subject.tags.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '标签',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _subject.tags.take(10).map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    if (_subject.summary.isEmpty) return const SizedBox.shrink();
    final cleanSummary = _subject.summary
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '简介',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () =>
                setState(() => _isSummaryExpanded = !_isSummaryExpanded),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cleanSummary,
                  maxLines: _isSummaryExpanded ? null : 4,
                  overflow: _isSummaryExpanded ? null : TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
                if (!_isSummaryExpanded)
                  const Text(
                    '展开',
                    style: TextStyle(color: Colors.blue, fontSize: 13),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox() {
    if (_subject.infobox == null || _subject.infobox!.isEmpty)
      return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '详细信息',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._subject.infobox!.map((info) {
            final key = info['key'] ?? '';
            final value = _parseInfoValue(info['value']);
            if (key.isEmpty || value.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      '$key: ',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ),
                  Expanded(
                    child: Text(value, style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  String _parseInfoValue(dynamic value) {
    if (value is String) return value;
    if (value is List) {
      return value
          .map((v) {
            if (v is Map) return v['v'] ?? v['value'] ?? '';
            return v.toString();
          })
          .join('、');
    }
    return value?.toString() ?? '';
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _startReading,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          child: const Text(
            '开始阅读',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

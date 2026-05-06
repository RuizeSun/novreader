import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/subject.dart';
import '../models/related_person.dart';
import '../models/related_character.dart';
import '../services/bangumi_service.dart';
import 'package:url_launcher/url_launcher.dart';

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
  List<RelatedPerson> _persons = [];
  List<RelatedCharacter> _characters = [];
  bool _isPersonsLoading = true;
  bool _isCharactersLoading = true;
  String? _personsError;
  String? _charactersError;

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
      setState(() {
        _persons = persons;
        _characters = characters;
        _isPersonsLoading = false;
        _isCharactersLoading = false;
      });
    } catch (e) {
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
      setState(() {
        _subject = subject;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFullDetails() async {
    try {
      final subject = await _bangumiService.getSubject(widget.subjectId);
      setState(() {
        _subject = subject;
      });
    } catch (e) {
      // 静默失败，使用初始数据
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
      body: CustomScrollView(
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
      bottomSheet: _buildBottomBar(),
    );
  }

  Widget _buildPersonsSection() {
    if (_isPersonsLoading) {
      // Show a compact loading indicator for the persons section
      return Padding(
        padding: const EdgeInsets.all(8.0),
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
      // Further reduce outer padding for the persons section
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
              // Determine number of columns based on available width.
              int columns = (constraints.maxWidth / 200).floor();
              if (columns < 1) columns = 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  // Reduce spacing between grid items for a tighter layout
                  // Tighter spacing between grid items
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                  childAspectRatio: 4,
                ),
                itemCount: _persons.length,
                itemBuilder: (context, index) {
                  final person = _persons[index];
                  return ListTile(
                    // Make the list tile more compact
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
                    // Removed subtitle displaying career (e.g., "producer", "mangaka")
                    trailing: Text(person.relation),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCharactersSection() {
    if (_isCharactersLoading) {
      // Show a compact loading indicator for the characters section
      return Padding(
        padding: const EdgeInsets.all(8.0),
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
      // Further reduce outer padding for the characters section
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
              // Ensure at least two columns on typical mobile widths.
              int columns = (constraints.maxWidth / 180).floor();
              if (columns < 2) columns = 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  // Reduce spacing for a tighter layout.
                  // Tighter spacing between character grid items
                  mainAxisSpacing: 0.5,
                  crossAxisSpacing: 1,
                  // Adjust aspect ratio for a more flat and compact tile.
                  childAspectRatio: 2.8,
                ),
                itemCount: _characters.length,
                itemBuilder: (context, index) {
                  final character = _characters[index];
                  return ListTile(
                    // Reduce padding to make the grid more compact on mobile.
                    // Reduce padding inside each character tile for a more compact layout
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
                    // Removed subtitle (character.summary) to keep each item compact.
                    trailing: Text(character.relation),
                    onTap: () async {
                      final go = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('前往角色主页'),
                          content: const Text('是否打开 Bangumi 角色页面？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('取消'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
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
    // Use Expanded for each score item to avoid overflow on narrow screens.
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
          onPressed: () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('阅读功能暂未开放')));
          },
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

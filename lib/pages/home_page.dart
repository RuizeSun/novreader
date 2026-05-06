import 'package:flutter/material.dart';
import 'package:novriidaa_reader/models/subject.dart';
import 'package:novriidaa_reader/services/bangumi_service.dart';
import 'package:novriidaa_reader/widgets/subject_card.dart';
import 'package:novriidaa_reader/widgets/search_bar.dart';
import 'package:novriidaa_reader/pages/search_page.dart';
import 'package:novriidaa_reader/pages/subject_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final BangumiService _bangumiService = BangumiService();
  final ScrollController _scrollController = ScrollController();

  List<Subject> _subjects = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  int _offset = 0;
  static const int _limit = 30;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadTrendingBooks();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadTrendingBooks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await _bangumiService.fetchTrendingBooks();
      setState(() {
        _subjects = results;
        _hasMore = results.length >= _limit;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载失败: $e';
        _isLoading = false;
        _subjects = [];
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    _offset += _limit;

    try {
      final results = await _bangumiService.searchSubjects(
        keyword: '小说',
        limit: _limit,
        offset: _offset,
        sort: 'heat',
        tag: ['小说'],
      );
      setState(() {
        _subjects.addAll(results);
        _hasMore = results.length >= _limit;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _offset -= _limit;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _offset = 0;
      _hasMore = true;
    });
    await _loadTrendingBooks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NovReader'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          SearchBarWidget(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchPage()),
              );
            },
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTrendingBooks,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_subjects.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              '暂无书籍',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.6,
        ),
        itemCount: _subjects.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < _subjects.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: SubjectCard(
                subject: _subjects[index],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SubjectDetailPage(
                        subjectId: _subjects[index].id,
                        initialSubject: _subjects[index],
                      ),
                    ),
                  );
                },
              ),
            );
          } else {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('没有更多了', style: TextStyle(color: Colors.grey)),
              ),
            );
          }
        },
      ),
    );
  }
}

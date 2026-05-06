import 'package:flutter/material.dart';
import 'package:novriidaa_reader/models/subject.dart';
import 'package:novriidaa_reader/services/bangumi_service.dart';
import 'package:novriidaa_reader/widgets/subject_card.dart';
import 'package:novriidaa_reader/pages/subject_detail_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final BangumiService _bangumiService = BangumiService();
  final ScrollController _scrollController = ScrollController();

  List<Subject> _subjects = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  int _offset = 0;
  static const int _limit = 30;
  String _currentKeyword = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore &&
        _currentKeyword.isNotEmpty) {
      _loadMore();
    }
  }

  Future<void> _search() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _offset = 0;
      _hasMore = true;
      _currentKeyword = keyword;
    });

    try {
      final results = await _bangumiService.searchSubjects(
        keyword: keyword,
        limit: _limit,
        offset: _offset,
        tag: ['小说'],
      );
      setState(() {
        _subjects = results;
        _hasMore = results.length >= _limit;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '搜索失败: $e';
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
        keyword: _currentKeyword,
        limit: _limit,
        offset: _offset,
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
    if (_currentKeyword.isEmpty) return;
    setState(() {
      _offset = 0;
      _hasMore = true;
    });
    await _search();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('搜索'), elevation: 0),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索小说、作者...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _subjects = [];
                            _error = null;
                          });
                        },
                      )
                    : null,
              ),
              onSubmitted: (value) => _search(),
              textInputAction: TextInputAction.search,
            ),
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
            ElevatedButton(onPressed: _search, child: const Text('重试')),
          ],
        ),
      );
    }

    if (_subjects.isEmpty && !_isLoading && _currentKeyword.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              '输入关键词搜索小说',
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
        padding: const EdgeInsets.symmetric(horizontal: 8),
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

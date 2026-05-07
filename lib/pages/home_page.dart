import 'package:flutter/material.dart';
import 'package:novriidaa_reader/models/subject.dart';
import 'package:novriidaa_reader/services/bangumi_service.dart';
import 'package:novriidaa_reader/widgets/subject_card.dart';
import 'package:novriidaa_reader/widgets/search_bar.dart';
import 'package:novriidaa_reader/pages/search_page.dart';
import 'package:novriidaa_reader/pages/subject_detail_page.dart';
import 'package:provider/provider.dart';
import 'package:novriidaa_reader/providers/user_provider.dart';

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
  // 分页页码，初始为 1
  int _currentPage = 1;
  // 每次请求的数量。增大此值可以在首次加载时填满屏幕，随后通过滚动继续加载。
  static const int _limit = 50;

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
      // 使用爬虫方式获取热门书籍，确保首次加载能够填满屏幕
      final results = await _bangumiService.fetchTrendingBooksScrape(
        limit: _limit,
        page: _currentPage,
      );
      if (!mounted) return;
      setState(() {
        _subjects = results;
        _hasMore = results.length >= _limit;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
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

    // 翻到下一页
    _currentPage += 1;

    try {
      final results = await _bangumiService.fetchTrendingBooksScrape(
        limit: _limit,
        page: _currentPage,
      );
      if (!mounted) return;
      setState(() {
        _subjects.addAll(results);
        _hasMore = results.length >= _limit;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _currentPage -= 1; // 回滚页码
      });
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      // 重置分页为第一页并重新加载
      _currentPage = 1;
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
        // 将账号按钮放在标题右侧的最右边，设置图标放在其左侧
        actions: [
          // 设置入口图标（左侧）
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
          // 账号按钮（头像或登录图标）
          Consumer<UserProvider>(
            builder: (context, userProvider, child) {
              return IconButton(
                icon: userProvider.isLoggedIn
                    ? CircleAvatar(
                        radius: 12,
                        backgroundImage: NetworkImage(
                          userProvider.currentUser?.avatar.large ?? '',
                        ),
                      )
                    : const Icon(Icons.login),
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
              );
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

# RecommendPage (`lib/pages/recommend_page.dart`)

## 文件概述

`HomePage` 是应用的首页，展示 **热门书籍**（小说）列表。页面使用 `StatefulWidget`，在 `initState` 中请求数据并在滚动到底部时自动加载更多，实现类似信息流的无限滚动效果。

## 关键类 & 方法

```dart
class HomePage extends StatefulWidget {}

class _HomePageState extends State<HomePage> {
  final BangumiService _bangumiService = BangumiService();
  final ScrollController _scrollController = ScrollController();
  List<Subject> _subjects = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  int _offset = 0;
  // 每次请求的数量。增大此值可以在首次加载时填满屏幕，随后通过滚动继续加载。
  static const int _limit = 50;

  /// 初始加载，使用自定义的 `limit`（默认 50）确保首次渲染能够填满屏幕。
  void _loadTrendingBooks();   // 初始加载
  void _loadMore();            // 滚动到底部时加载更多
  Future<void> _refresh();    // 下拉刷新
}
```

## 页面跳转（已更新）

- **搜索** – 点击搜索栏跳转到 `SearchPage`（`Navigator.push`）。
- **详情** – 点击 `SubjectCard` 跳转到 `SubjectDetailPage`（`Navigator.push` 并传入 `subjectId` 与 `initialSubject`）。
    - **设置** – 已从推荐页顶部移除，设置功能通过底部导航栏的 “设置” 标签页访问。
- **登录** – 头像或登录图标使用 `Navigator.pushNamed(context, '/login')`。

## 网络请求

`_loadTrendingBooks` 调用 `BangumiService.fetchTrendingBooks()`，返回 `List<Subject>`。
`_loadMore` 调用 `BangumiService.searchSubjects`，使用 `keyword: '小说'`、`sort: 'heat'`、`tag: ['小说']`。

## 状态管理

页面内部使用本地 `State` 管理加载状态 (`_isLoading`、`_hasMore`、`_error`)。登录状态通过 `Provider<UserProvider>` 在 `AppBar` 中读取。

## UI 组件

- `SearchBarWidget` – 位于页面顶部，点击后进入搜索页。
- `SubjectCard` – 自定义卡片组件，展示封面、标题等信息，点击后进入详情页。

## 错误处理 & 加载状态

- 网络请求使用 `try/catch` 捕获异常，错误信息保存在 `_error` 并在 UI 中展示重试按钮。
- 加载中显示 `CircularProgressIndicator`，列表底部若还有更多则显示加载指示器，否则显示 “没有更多了”。

## 示例代码片段

```dart
// 首页 AppBar 中的设置按钮
IconButton(
  icon: const Icon(Icons.settings),
  onPressed: () => Navigator.pushNamed(context, '/settings'),
);
```

# SearchPage (`lib/pages/search_page.dart`)

## 文件概述

提供关键字搜索功能，用户可以输入小说或作者名称进行搜索，结果以网格形式展示。

## 关键类 & 方法

```dart
class SearchPage extends StatefulWidget {}

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

  Future<void> _search();   // 发起搜索
  Future<void> _loadMore(); // 滚动加载更多
  Future<void> _refresh();  // 下拉刷新
}
```

## 页面跳转

搜索结果中的每个 `SubjectCard` 与 **HomePage** 相同，点击后使用 `Navigator.push` 打开 `SubjectDetailPage`。

## 网络请求

`_search` 调用 `BangumiService.searchSubjects`，传入用户输入的 `keyword`、`limit`、`offset`、`tag: ['小说']`。
`_loadMore` 在滚动到底部且已有关键字时继续请求下一页数据。

## 状态管理

同样使用本地 `State` 管理加载、错误、分页状态。搜索框的内容通过 `_searchController` 控制。

## UI 组件

- `TextField` – 输入关键字，`onSubmitted` 触发 `_search`。
- `GridView.builder` – 展示搜索结果，使用 `SubjectCard`。
- `RefreshIndicator` – 支持下拉刷新。

## 错误处理 & 加载状态

- `_error` 为 `null` 时显示内容；不为 `null` 时展示错误图标、文字以及 “重试” 按钮。
- 当列表为空且未加载时，展示 “输入关键词搜索小说”。

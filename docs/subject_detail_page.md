# SubjectDetailPage (`lib/pages/subject_detail_page.dart`)

## 文件概述

展示单本小说的 **详细信息**，包括封面、标题、评分、标签、简介、人物、角色等。页面使用 `CustomScrollView` 与多个自定义子组件组织信息。

## 关键类 & 方法

```dart
class SubjectDetailPage extends StatefulWidget {
  final int subjectId;
  final Subject? initialSubject;
}

class _SubjectDetailState extends State<SubjectDetailPage> {
  final BangumiService _bangumiService = BangumiService();
  late Subject _subject;
  bool _isLoading = true;
  String? _error;
  // 展开/收起状态
  bool _isSummaryExpanded = false;
  bool _isPersonsExpanded = false;
  bool _isCharactersExpanded = false;
  // 关联人物/角色数据
  List<RelatedPerson> _persons = [];
  List<RelatedCharacter> _characters = [];
  // 加载方法
  Future<void> _fetchSubject();
  Future<void> _loadRelatedData();
  Future<void> _loadFullDetails();
}
```

## 页面跳转

- **返回** – `SliverAppBar` 的左上角返回按钮使用 `Navigator.pop`（自定义高斯模糊背景）。
- **角色外链** – 在角色列表中点击会弹出确认对话框，若确认则使用 `url_launcher` 打开 Bangumi 角色页面。

## 网络请求

- `BangumiService.getSubject(subjectId)` – 获取主体信息。
- `BangumiService.getSubjectPersons(subjectId)` – 获取关联人物列表。
- `BangumiService.getSubjectCharacters(subjectId)` – 获取关联角色列表。

## 状态管理

页面内部维护多个加载状态 (`_isLoading`、`_isPersonsLoading`、`_isCharactersLoading`) 与错误信息 (`_error`、`_personsError`、`_charactersError`).

## UI 组件

- **AppBar** – 使用 `SliverAppBar`，背景为封面图片并添加渐变遮罩。
- **Header** – 展示封面、标题、发售日、排名等基本信息。
- **ScoreRow** – 评分、评价数、收藏数的三列展示。
- **Tags** – 使用 `Wrap` 展示最多 10 个标签。
- **Summary** – 可展开/收起的简介文本。
- **InfoBox** – 通过 `infobox` 动态渲染键值对信息。
- **Persons / Characters Section** – 网格列表，支持展开/收起按钮，使用 `CachedNetworkImage` 加载头像。
- **BottomBar** – “开始阅读”按钮（目前仅展示提示）。

## 错误处理 & 加载状态

- 主体加载错误会显示错误页面并提供 “重试” 按钮。
- 人物/角色加载错误会在对应区域显示文字提示。
- 列表底部若还有更多数据会显示 `CircularProgressIndicator`，否则显示 “没有更多了”。

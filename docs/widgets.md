# UI 组件 (`lib/widgets/`)

项目中自定义的可复用组件主要有以下几个。

## SubjectCard (`subject_card.dart`)

展示单个 `Subject` 的封面、标题、评分等信息，接受 `subject` 与 `onTap` 回调。

```dart
class SubjectCard extends StatelessWidget {
  final Subject subject;
  final VoidCallback onTap;
}
```

在列表或网格中使用 `GestureDetector` 包裹，实现点击跳转到 `SubjectDetailPage`。

## SearchBarWidget (`search_bar.dart`)

位于首页顶部的搜索入口，点击后使用 `Navigator.push` 打开 `SearchPage`。

## SettingsCategoryPage (`settings_category_page.dart`)

通用的子页面容器，接受 `title` 与 `child`，在宽屏时作为右侧详情区使用，在窄屏时作为独立页面展示。

## 其他组件

- `SearchBarWidget` – 简单的搜索框 UI。
- `SubjectCard` – 复用的卡片 UI，内部使用 `CachedNetworkImage` 加载封面。

所有组件均遵循 **无状态**（Stateless）或 **局部状态**（Stateful）原则，便于在页面中直接使用。

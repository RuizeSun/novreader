# SettingsPage (`lib/pages/settings_page.dart`)

## 文件概述

提供 **外观** 与 **关于** 两个设置分类的页面。根据屏幕宽度自动切换双栏布局（宽屏）或单列列表（窄屏）。

## 关键类 & 方法

```dart
class SettingsPage extends StatefulWidget {}

class _SettingsPageState extends State<SettingsPage> {
  final List<String> _categories = const ['外观', '关于'];
  int _selectedIndex = 0;
  Widget _buildDetail(BuildContext context, ThemeProvider themeProvider);
  Widget _buildAppearance(BuildContext context, ThemeProvider themeProvider);
  Widget _buildAbout(BuildContext context);
}
```

## 页面跳转

- **外观** – 直接在右侧详情区展示主题切换 UI。
- **关于** – 展示 `PackageInfo`（版本号）并提供 “关于” 对话框。
- **窄屏** – 点击列表项使用 `Navigator.push` 打开 `SettingsCategoryPage`，该页面仅渲染对应子 UI。

## 状态管理

使用 `Provider<ThemeProvider>` 获取主题状态 (`isDarkMode`、`primaryColor`、`followSystemAccent`) 并在 UI 中实时响应。

## UI 组件

- **左侧导航** – `ListView.builder` 列出分类，选中项高亮。
- **外观设置** – 包含深色模式开关、系统强调色开关、主题色选择（预设颜色圆点）以及自定义十六进制颜色输入对话框。
- **关于** – 使用 `PackageInfo.fromPlatform()` 获取版本信息，点击后弹出 `showAboutDialog`。

## 错误处理 & 加载状态

- `PackageInfo.fromPlatform()` 通过 `FutureBuilder` 异步加载，加载期间显示空容器。

# ThemeProvider (`lib/providers/theme_provider.dart`)

## 文件概述

负责 **主题模式**（深色/浅色）与 **主色调** 的全局状态管理，并将选择持久化到 `SharedPreferences`，供应用启动时读取。

## 关键属性 & 方法

```dart
class ThemeProvider with ChangeNotifier {
  static const String _prefsKey = 'isDarkMode';
  static const String _colorKey = 'primaryColor';
  static const String _followSystemKey = 'followSystemAccent';

  bool _isDarkMode = false;
  Color _primaryColor = const Color(0xFF6C63FF);
  bool _followSystemAccent = false;

  ThemeProvider(); // 构造函数会调用 _loadTheme()

  Future<void> _loadTheme();
  Future<void> toggleTheme();
  Future<void> setPrimaryColor(Color color);
  Future<void> setFollowSystemAccent(bool follow);
  ThemeMode get themeMode;
  ThemeData get lightTheme;
  ThemeData get darkTheme;
}
```

## 持久化实现

- **读取** – `_loadTheme` 使用 `SharedPreferences.getInstance()` 读取 `isDarkMode`、`primaryColor`、`followSystemAccent` 的值。
- **写入** – `toggleTheme`、`setPrimaryColor`、`setFollowSystemAccent` 在修改状态后立即写入 `SharedPreferences` 并调用 `notifyListeners()`，确保 UI 实时更新。

## 与 UI 的交互

- `SettingsPage` 通过 `Provider.of<ThemeProvider>(context)` 获取实例，控制深色模式开关、主题色选择等 UI。
- `MaterialApp`（在 `app.dart` 中）使用 `themeMode: context.watch<ThemeProvider>().themeMode` 动态切换主题。

## 示例代码

```dart
Switch(
  value: themeProvider.isDarkMode,
  onChanged: (_) => themeProvider.toggleTheme(),
);
```

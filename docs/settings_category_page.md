# SettingsCategoryPage (`lib/pages/settings_category_page.dart`)

## 文件概述

通用的设置子页面容器，用于在点击左侧分类后展示对应的设置内容。宽屏时作为右侧详情区使用，窄屏时作为独立页面展示。

## 关键类 & 方法

```dart
class SettingsCategoryPage extends StatelessWidget {
  const SettingsCategoryPage({
    Key? key,
    required this.title,
    required this.child,
  }) : super(key: key);

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), elevation: 0),
      body: child,
    );
  }
}
```

## 使用场景

在 `SettingsPage` 中左侧列表点击后，如果屏幕宽度不足（<600），会使用 `Navigator.push` 打开此页面并传入对应的 `title` 与 `child`（外观或关于 UI）。

## 页面跳转

- 通过 `Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsCategoryPage(...)))` 打开。
- 返回使用系统返回按钮或 `AppBar` 左侧返回键。

import 'package:flutter/material.dart';

/// 通用的设置子页面，用于在点击分类后展示对应的设置内容。
/// 传入 [title] 作为 AppBar 标题，传入 [child] 渲染具体的设置 UI。
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

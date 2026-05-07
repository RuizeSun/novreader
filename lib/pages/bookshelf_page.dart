import 'package:flutter/material.dart';

/// 书架占位页面，仅展示文字说明。
class BookshelfPage extends StatelessWidget {
  const BookshelfPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('书架'), elevation: 0),
      body: const Center(child: Text('书架占位页', style: TextStyle(fontSize: 18))),
    );
  }
}

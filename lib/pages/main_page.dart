import 'package:flutter/material.dart';
import 'package:novriidaa_reader/pages/recommend_page.dart';
import 'package:novriidaa_reader/pages/bookshelf_page.dart';
import 'package:novriidaa_reader/pages/settings_page.dart';

/// 主页面，包含底部导航栏，切换 推荐、书架、设置 三个子页面。
class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  static const List<Widget> _pages = <Widget>[
    RecommendPage(),
    BookshelfPage(),
    SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 使用 IndexedStack 保持子页面的状态，防止在切换底部导航栏时重新创建页面，
    // 从而避免 RecommendPage 在每次切换时重新请求数据。
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '推荐'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: '书架'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        onTap: _onItemTapped,
      ),
    );
  }
}

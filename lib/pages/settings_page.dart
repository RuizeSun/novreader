import 'package:flutter/material.dart';
import 'package:novriidaa_reader/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:novriidaa_reader/pages/settings_category_page.dart';
import 'package:novriidaa_reader/pages/settings/appearance_settings.dart';
import 'package:novriidaa_reader/pages/settings/reading_settings.dart';
import 'package:novriidaa_reader/pages/settings/about_settings.dart';
import 'package:novriidaa_reader/pages/settings/source_management_settings.dart';

/// 设置页面实现响应式双栏布局，并加入主题色选择功能。
class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // 分类列表，新增 "阅读页设置" 项目。
  final List<String> _categories = const ['外观', '阅读页设置', '来源管理', '关于'];
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置'), elevation: 0),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // 宽屏（>=600）使用双栏布局，窄屏使用单列 ListView。
          if (constraints.maxWidth >= 600) {
            return Row(
              children: [
                // 左侧导航栏
                SizedBox(
                  width: 200,
                  child: ListView.builder(
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final selected = index == _selectedIndex;
                      return ListTile(
                        title: Text(_categories[index]),
                        selected: selected,
                        onTap: () => setState(() => _selectedIndex = index),
                      );
                    },
                  ),
                ),
                const VerticalDivider(width: 1),
                // 右侧详情区，根据选中的分类展示对应内容
                Expanded(child: _buildDetail(context)),
              ],
            );
          }
          // 窄屏（手机）展示分类列表，点击后进入对应的子页面
          return ListView.builder(
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(_categories[index]),
                onTap: () {
                  // 根据分类跳转到对应的设置子页面
                  Widget child;
                  switch (_categories[index]) {
                    case '外观':
                      child = const AppearanceSettings();
                      break;
                    case '阅读页设置':
                      child = const ReadingSettings();
                      break;
                    case '来源管理':
                      child = const SourceManagementSettings();
                      break;
                    case '关于':
                      child = const AboutSettings();
                      break;
                    default:
                      child = const SizedBox.shrink();
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SettingsCategoryPage(
                        title: _categories[index],
                        child: child,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  /// 根据当前选中的分类返回对应的设置 UI。
  Widget _buildDetail(BuildContext context) {
    switch (_categories[_selectedIndex]) {
      case '外观':
        return const AppearanceSettings();
      case '阅读页设置':
        return const ReadingSettings();
      case '来源管理':
        return const SourceManagementSettings();
      case '关于':
        return const AboutSettings();
      default:
        return const SizedBox.shrink();
    }
  }
}

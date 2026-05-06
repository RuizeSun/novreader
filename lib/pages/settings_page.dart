import 'package:flutter/material.dart';
import 'package:novriidaa_reader/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:novriidaa_reader/pages/settings_category_page.dart';

/// 设置页面实现响应式双栏布局，并加入主题色选择功能。
class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // 分类列表，当前仅包含外观和关于两项，可自行扩展。
  final List<String> _categories = const ['外观', '关于'];
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('设置'), elevation: 0),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // 宽屏（>=600）使用双栏布局，窄屏使用单列 ListView。
          if (constraints.maxWidth >= 600) {
            return Row(
              children: [
                // 左侧导航栏
                // 左侧导航栏使用固定宽度的 Container 包裹 ListView，
                // 并开启 shrinkWrap 以避免在高度受限时出现 overflow。
                // 左侧导航栏使用 Flexible + ConstrainedBox，最大宽度 200，
                // 当可用宽度不足时会自动收缩，避免 Row 整体水平溢出。
                // 左侧导航栏使用固定宽度并占满可用高度，防止在高度受限时出现 bottom overflow。
                // 左侧导航栏使用固定宽度的 SizedBox 包裹 ListView，
                // 让 ListView 自动填满可用高度并支持滚动，避免 shrinkWrap 导致的高度溢出。
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
                Expanded(child: _buildDetail(context, themeProvider)),
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
                      child = _buildAppearance(context, themeProvider);
                      break;
                    case '关于':
                      child = _buildAbout(context);
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
  Widget _buildDetail(BuildContext context, ThemeProvider themeProvider) {
    switch (_categories[_selectedIndex]) {
      case '外观':
        return _buildAppearance(context, themeProvider);
      case '关于':
        return _buildAbout(context);
      default:
        return const SizedBox.shrink();
    }
  }

  /// 外观设置，包括深色模式切换和主题色选择。
  Widget _buildAppearance(BuildContext context, ThemeProvider themeProvider) {
    // 预设的主题颜色选项，可自行增删。
    final List<Color> colorOptions = const [
      Color(0xFF6C63FF), // 默认蓝色
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
    ];
    // 使用 SingleChildScrollView 包裹 Column，防止在高度受限的设备上出现 overflow。
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('深色模式'),
              subtitle: const Text('切换应用主题'),
              trailing: Switch(
                value: themeProvider.isDarkMode,
                onChanged: (_) => themeProvider.toggleTheme(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // 跟随系统强调色开关
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SwitchListTile(
              title: const Text('跟随系统强调色'),
              value: themeProvider.followSystemAccent,
              onChanged: (value) => themeProvider.setFollowSystemAccent(value),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Text(
              '主题色',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          // 使用水平滚动的 SingleChildScrollView 包裹颜色选项，防止在宽度受限时出现水平溢出。
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: colorOptions.map((color) {
                  final bool isSelected =
                      themeProvider.primaryColor.value == color.value &&
                      !themeProvider.followSystemAccent;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () => themeProvider.setPrimaryColor(color),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.black, width: 2)
                              : null,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 自定义颜色按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: () async {
                final controller = TextEditingController();
                final result = await showDialog<String>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('输入十六进制颜色值'),
                    content: TextField(
                      controller: controller,
                      decoration: const InputDecoration(hintText: '#RRGGBB'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context).pop(controller.text),
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                );
                if (result != null && result.isNotEmpty) {
                  try {
                    final hex = result.replaceAll('#', '');
                    final color = Color(int.parse('FF$hex', radix: 16));
                    await themeProvider.setPrimaryColor(color);
                  } catch (_) {
                    // ignore invalid input
                  }
                }
              },
              child: const Text('自定义颜色'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// 关于信息卡片，保持原有实现。
  Widget _buildAbout(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version ?? '1.0.0';
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于'),
            subtitle: Text('NovReader v$version'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'NovReader',
                applicationVersion: version,
                applicationIcon: const FlutterLogo(),
                children: const [
                  Text('基于 Bangumi API 构建的小说阅读器'),
                  SizedBox(height: 8),
                  Text(
                    'API: https://bangumi.github.io/api/',
                    style: TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:novriidaa_reader/providers/theme_provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

/// 外观设置页面，原本在 SettingsPage 的 _buildAppearance 方法中实现。
/// 现在抽离为独立的可复用组件。
class AppearanceSettings extends StatelessWidget {
  const AppearanceSettings({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
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
                  onChanged: (value) =>
                      themeProvider.setFollowSystemAccent(value),
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
                  onPressed: () =>
                      _showPrimaryColorPicker(context, themeProvider),
                  child: const Text('自定义颜色'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 新增的颜色选择器方法，使用 BlockPicker 进行色盘选色
  void _showPrimaryColorPicker(
    BuildContext context,
    ThemeProvider themeProvider,
  ) {
    Color pickerColor = themeProvider.primaryColor;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('选择主题颜色'),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: pickerColor,
            onColorChanged: (color) => pickerColor = color,
          ),
        ),
        actions: [
          TextButton(
            child: const Text('取消'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('确定'),
            onPressed: () {
              themeProvider.setPrimaryColor(pickerColor);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

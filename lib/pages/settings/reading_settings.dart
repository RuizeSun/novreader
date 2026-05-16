import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import 'package:novriidaa_reader/providers/theme_provider.dart';

/// 阅读页设置，原本在 SettingsPage 的 _buildReadingSettings 方法中实现。
/// 现在抽离为独立组件，供 Settings 页面和阅读页底部弹窗共用。
class ReadingSettings extends StatelessWidget {
  const ReadingSettings({Key? key}) : super(key: key);

  // 与原实现相同的颜色选择弹窗帮助函数
  void _showColorPicker(
    BuildContext context,
    ThemeProvider themeProvider, {
    required bool isBackground,
  }) {
    Color pickerColor = isBackground
        ? themeProvider.readingBackgroundColor
        : themeProvider.readingFontColor;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isBackground ? '选择背景颜色' : '选择字体颜色'),
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
                if (isBackground) {
                  themeProvider.setReadingBackgroundColor(pickerColor);
                } else {
                  themeProvider.setReadingFontColor(pickerColor);
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 字体大小
              ListTile(
                title: const Text('字体大小'),
                subtitle: Slider.adaptive(
                  min: 12,
                  max: 30,
                  divisions: 18,
                  value: themeProvider.readingFontSize,
                  label: '${themeProvider.readingFontSize.toStringAsFixed(0)}',
                  onChanged: (v) => themeProvider.setReadingFontSize(v),
                ),
              ),
              // 章节标题大小
              ListTile(
                title: const Text('章节标题大小'),
                subtitle: Slider.adaptive(
                  min: 12,
                  max: 30,
                  divisions: 18,
                  value: themeProvider.readingTitleFontSize,
                  label:
                      '${themeProvider.readingTitleFontSize.toStringAsFixed(0)}',
                  onChanged: (v) => themeProvider.setReadingTitleFontSize(v),
                ),
              ),
              // 行距
              ListTile(
                title: const Text('行距'),
                subtitle: Slider.adaptive(
                  min: 1.0,
                  max: 2.5,
                  divisions: 15,
                  value: themeProvider.readingLineHeight,
                  label: themeProvider.readingLineHeight.toStringAsFixed(2),
                  onChanged: (v) => themeProvider.setReadingLineHeight(v),
                ),
              ),
              // 段距（通过额外空行实现）
              ListTile(
                title: const Text('段距（空行数）'),
                subtitle: Slider.adaptive(
                  min: 0,
                  max: 5,
                  divisions: 5,
                  value: themeProvider.readingParagraphSpacing,
                  label: '${themeProvider.readingParagraphSpacing.toInt()}',
                  onChanged: (v) => themeProvider.setReadingParagraphSpacing(v),
                ),
              ),
              // 双栏开关
              SwitchListTile(
                title: const Text('双栏布局'),
                value: themeProvider.doubleColumnEnabled,
                onChanged: (v) => themeProvider.setDoubleColumnEnabled(v),
              ),
              // 双栏触发宽度（仅在启用双栏布局时显示）
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                switchInCurve: Curves.fastOutSlowIn,
                switchOutCurve: Curves.fastOutSlowIn,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final curved = CurvedAnimation(
                    parent: animation,
                    curve: Curves.fastOutSlowIn,
                  );
                  return FadeTransition(opacity: curved, child: child);
                },
                child: themeProvider.doubleColumnEnabled
                    ? ListTile(
                        key: const ValueKey('doubleColumnTrigger'),
                        title: const Text('双栏触发宽度 (px)'),
                        subtitle: Slider.adaptive(
                          min: 600,
                          max: 1200,
                          divisions: 12,
                          value: themeProvider.doubleColumnTriggerWidth,
                          label:
                              '${themeProvider.doubleColumnTriggerWidth.toInt()}',
                          onChanged: (v) =>
                              themeProvider.setDoubleColumnTriggerWidth(v),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('empty')),
              ),
              // 背景颜色设置（预设颜色 + 自定义）
              ListTile(
                title: const Text('背景颜色'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      children:
                          [
                                Colors.white,
                                const Color(0xFFF5F5D1),
                                const Color(0xFFE0E0E0),
                                const Color(0xFFB0B0B0),
                                Colors.black,
                              ]
                              .map(
                                (c) => GestureDetector(
                                  onTap: () => themeProvider
                                      .setReadingBackgroundColor(c),
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: c,
                                      border: Border.all(
                                        color:
                                            themeProvider
                                                    .readingBackgroundColor ==
                                                c
                                            ? Colors.blueAccent
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _showColorPicker(
                        context,
                        themeProvider,
                        isBackground: true,
                      ),
                      child: const Text('自定义颜色'),
                    ),
                  ],
                ),
              ),
              // 字体颜色设置（预设颜色 + 自定义）
              ListTile(
                title: const Text('字体颜色'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      children:
                          [
                                Colors.black,
                                Colors.white,
                                Colors.red,
                                Colors.green,
                                Colors.blue,
                              ]
                              .map(
                                (c) => GestureDetector(
                                  onTap: () =>
                                      themeProvider.setReadingFontColor(c),
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: c,
                                      border: Border.all(
                                        color:
                                            themeProvider.readingFontColor == c
                                            ? Colors.blueAccent
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _showColorPicker(
                        context,
                        themeProvider,
                        isBackground: false,
                      ),
                      child: const Text('自定义颜色'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

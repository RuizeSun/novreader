import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:novriidaa_reader/providers/source_provider.dart';
import 'package:novriidaa_reader/models/source_rule.dart';

/// 来源管理页面，支持导入、删除 JSON 来源规则文件
class SourceManagementSettings extends StatefulWidget {
  const SourceManagementSettings({Key? key}) : super(key: key);

  @override
  State<SourceManagementSettings> createState() =>
      _SourceManagementSettingsState();
}

class _SourceManagementSettingsState extends State<SourceManagementSettings> {
  @override
  void initState() {
    super.initState();
    // 页面初始化时加载来源列表
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SourceProvider>().loadSources();
    });
  }

  Future<void> _importSource() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      String content;

      if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('无法读取文件内容')));
        }
        return;
      }

      final Map<String, dynamic> jsonData =
          json.decode(content) as Map<String, dynamic>;
      final source = SourceRule.fromJson(jsonData);

      if (source.id.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('无效的来源规则：缺少 id 字段')));
        }
        return;
      }

      await context.read<SourceProvider>().addSource(source);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('成功导入来源规则：${source.name}')));
      }
    } on FormatException {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('文件格式无效，请选择正确的 JSON 文件')));
      }
    } catch (e) {
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMsg)));
      }
    }
  }

  Future<void> _deleteSource(SourceRule source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除来源规则 "${source.name}" (${source.id}) 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<SourceProvider>().removeSource(source.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已删除来源规则：${source.name}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SourceProvider>(
      builder: (context, sourceProvider, child) {
        return Column(
          children: [
            // 导入按钮区域
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: sourceProvider.isLoading ? null : _importSource,
                  icon: const Icon(Icons.file_upload),
                  label: const Text('导入来源规则 (JSON)'),
                ),
              ),
            ),
            const Divider(height: 1),
            // 来源列表
            Expanded(
              child: sourceProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : sourceProvider.sources.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.source_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            '暂无来源规则',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '点击上方按钮导入 JSON 来源文件',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: sourceProvider.sources.length,
                      itemBuilder: (context, index) {
                        final source = sourceProvider.sources[index];
                        return _buildSourceCard(context, source);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSourceCard(BuildContext context, SourceRule source) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '版本: ${source.version}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _deleteSource(source),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: '删除',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              source.description,
              style: theme.textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              '作者: ${source.author}',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              'ID: ${source.id}',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            if (source.meta.targetDomain.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '目标域名: ${source.meta.targetDomain}',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
            if (source.meta.supportedFormats.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '支持格式: ${source.meta.supportedFormats.join(", ")}',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

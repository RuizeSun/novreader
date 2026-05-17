import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:novriidaa_reader/providers/source_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novriidaa_reader/models/source_rule.dart';

/// 来源管理页面，支持导入、删除 JSON 来源规则文件
class SourceManagementSettings extends StatefulWidget {
  const SourceManagementSettings({Key? key}) : super(key: key);

  @override
  State<SourceManagementSettings> createState() =>
      _SourceManagementSettingsState();
}

class _SourceManagementSettingsState extends State<SourceManagementSettings> {
  // 是否已同意免责声明，默认 false
  bool _hasAgreement = false;
  @override
  void initState() {
    super.initState();
    // 页面初始化时检查用户是否已同意免责声明
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAgreement());
  }

  /// 检查用户是否已同意免责声明，若未同意则弹出对话框。
  Future<void> _checkAgreement() async {
    final prefs = await SharedPreferences.getInstance();
    final agreed = prefs.getBool('source_management_agreed') ?? false;
    if (!agreed) {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('免责声明'),
          content: const SingleChildScrollView(
            child: Text(
              '本功能运行于您的设备，所有网络请求均由您的设备直接发起，本软件不提供任何中转、代理、缓存或内容分发服务。您需要自行配置指向您拥有合法访问权限的服务器（包括但不限于个人NAS、私有云、您租用的云服务器、自建主机等）的访问规则。\n\n您知悉并同意，若您配置的规则指向不属于您拥有合法访问权限的第三方服务器，则您可能面临包括但不限于设备感染病毒、木马、勒索软件，个人数据被窃取或篡改，账号凭证泄露等严重安全风险。因访问此类未经授权的第三方服务器而导致的任何直接或间接损失（包括但不限于设备损坏、数据丢失、隐私泄露、财产损失），本软件开发者不承担任何法律责任。即使访问的是您拥有合法权限的服务器，本软件亦不对该服务器的安全性、内容完整性及潜在恶意代码作任何明示或暗示的担保。您使用本软件获取的任何内容，其合法性、授权状态及潜在侵权风险均由您自行承担。禁止配置指向您没有合法访问权限的第三方服务器的规则。权利人如认为本软件被用于侵权，请通过 Github 仓库的 Issue 功能联系开发者，我们将在核实后采取合理措施。',
            ),
          ),
          actions: [
            TextButton(
              child: const Text('不同意'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('同意'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );
      if (result == true) {
        await prefs.setBool('source_management_agreed', true);
        if (mounted) {
          setState(() {
            _hasAgreement = true;
          });
          context.read<SourceProvider>().loadSources();
        }
      } else {
        // 不同意则保持未同意状态，若在双栏模式下不进行页面跳转
        if (mounted) {
          setState(() {
            _hasAgreement = false;
          });
        }
      }
    } else {
      // 已同意，直接加载来源列表
      if (mounted) {
        setState(() {
          _hasAgreement = true;
        });
        context.read<SourceProvider>().loadSources();
      }
    }
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
        // 若未同意免责声明，则在双栏模式下直接展示提示，阻止操作。
        if (!_hasAgreement) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('请先阅读并同意免责声明后才能使用来源管理。'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _checkAgreement,
                  child: const Text('阅读并同意'),
                ),
              ],
            ),
          );
        }
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

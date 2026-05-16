import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 关于页面，原本在 SettingsPage 的 _buildAbout 方法中实现。
class AboutSettings extends StatelessWidget {
  const AboutSettings({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                children: const [Text('一个简单有趣的小说阅读器')],
              );
            },
          ),
        );
      },
    );
  }
}

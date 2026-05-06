import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:novriidaa_reader/providers/user_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// 登录/账号页面
///
/// - 未登录时展示 Access Token 说明、输入框以及登录按钮。
/// - 已登录时展示用户头像、ID、昵称以及退出登录按钮。
class LoginPage extends StatelessWidget {
  const LoginPage({Key? key}) : super(key: key);

  // 打开 Access Token 说明页面的帮助链接
  void _launchHelpUrl() async {
    const url = 'https://next.bgm.tv/demo/access-token';
    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final TextEditingController _controller = TextEditingController(
      text: userProvider.accessToken ?? '',
    );

    return Scaffold(
      appBar: AppBar(title: const Text('账号')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: userProvider.isLoggedIn
            ? _buildLoggedIn(context, userProvider)
            : _buildLoginForm(context, userProvider, _controller),
      ),
    );
  }

  Widget _buildLoginForm(
    BuildContext context,
    UserProvider userProvider,
    TextEditingController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Access Token 是用于调用 Bangumi API 的凭证。\n'
          '如果你还没有，请前往以下链接了解并申请：',
          style: TextStyle(fontSize: 16),
        ),
        TextButton.icon(
          onPressed: _launchHelpUrl,
          icon: const Icon(Icons.open_in_browser),
          label: const Text('Access Token 说明'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Access Token',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () async {
            final token = controller.text.trim();
            if (token.isNotEmpty) {
              try {
                await userProvider.login(token);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('登录成功')));
                // 登录成功后刷新页面显示用户信息
                (context as Element).reassemble();
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('登录失败: $e')));
              }
            }
          },
          child: const Text('登录'),
        ),
      ],
    );
  }

  Widget _buildLoggedIn(BuildContext context, UserProvider userProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage(
              userProvider.currentUser?.avatar.large ?? '',
            ),
          ),
          title: Text(userProvider.currentUser?.nickname ?? ''),
          subtitle: Text('ID: ${userProvider.currentUser?.username ?? ''}'),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () async {
            await userProvider.logout();
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('已退出登录')));
            (context as Element).reassemble();
          },
          child: const Text('退出登录'),
        ),
      ],
    );
  }
}

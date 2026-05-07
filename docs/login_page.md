# LoginPage (`lib/pages/login_page.dart`)

## 文件概述

实现 **Access Token** 登录与退出功能。未登录时展示说明、输入框与登录按钮，登录后展示用户头像、昵称、ID 与退出按钮。

## 关键类 & 方法

```dart
class LoginPage extends StatelessWidget {}

void _launchHelpUrl(); // 打开 Access Token 说明页面
Widget _buildLoginForm(BuildContext context, UserProvider userProvider, TextEditingController controller);
Widget _buildLoggedIn(BuildContext context, UserProvider userProvider);
```

## 页面跳转

- **帮助链接** – 使用 `url_launcher` 打开 `https://next.bgm.tv/demo/access-token`。
- **登录成功** – 调用 `UserProvider.login(token)`，成功后通过 `ScaffoldMessenger` 提示并使用 `(context as Element).reassemble()` 刷新页面。
- **退出登录** – 调用 `UserProvider.logout()`，同样刷新页面。

## 状态管理

通过 `Provider<UserProvider>` 读取 `isLoggedIn`、`accessToken`、`currentUser`。

## UI 组件

- **说明文字** – `Text` 组件说明 Access Token 的作用。
- **链接按钮** – `TextButton.icon` 打开帮助页面。
- **输入框** – `TextField` 绑定 `TextEditingController`，默认填充已保存的 token。
- **登录/退出按钮** – `ElevatedButton` 调用相应 Provider 方法。

## 错误处理 & 加载状态

登录失败时捕获异常并通过 `SnackBar` 显示错误信息。

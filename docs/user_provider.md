# UserProvider (`lib/providers/user_provider.dart`)

## 文件概述

管理 **登录状态**、**Access Token** 与 **当前用户信息**。敏感信息存储在 `flutter_secure_storage`，非敏感信息存储在 `SharedPreferences`，并在应用启动时加载。

## 关键属性 & 方法

```dart
class UserProvider with ChangeNotifier {
  static const String _prefsKey = 'accessToken';
  static const String _secureTokenKey = 'secureAccessToken';
  static const String _userPrefsKey = 'currentUser';

  String? _accessToken;
  User? _currentUser;

  UserProvider(); // 调用 _loadUser()

  Future<void> _loadUser();
  Future<void> login(String token);
  Future<void> logout();
  Future<void> refreshUser();
}
```

## 加载流程

1. 从 `FlutterSecureStorage` 读取 `secureAccessToken`（敏感）。
2. 从 `SharedPreferences` 读取 `currentUser`（JSON），解析为 `User` 实例。
3. 若 token 存在，调用 `BangumiService().setAccessToken(token)` 同步到 Service。

## 登录流程

- 调用 `BangumiService.getCurrentUser()` 获取用户信息。
- 将 token 写入安全存储，用户信息写入 `SharedPreferences`。
- 更新全局 `TokenHolder.accessToken`，并触发 `notifyListeners()`。

## 退出流程

- 删除 `SharedPreferences` 中的用户信息。
- 删除安全存储中的 token。
- 将 `TokenHolder.accessToken` 设为 `null` 并触发 `notifyListeners()`。

## 与 UI 的交互

- `LoginPage` 通过 `Provider.of<UserProvider>(context)` 调用 `login` / `logout`。
- 其他页面（如 `HomePage`）通过 `userProvider.isLoggedIn` 判断是否展示头像或登录按钮。

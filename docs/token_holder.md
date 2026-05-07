# TokenHolder (`lib/services/token_holder.dart`)

## 文件概述

一个简单的 **全局变量** 用于在不通过依赖注入的情况下快速获取当前的 Access Token。

## 实现

```dart
class TokenHolder {
  static String? accessToken;
}
```

## 使用场景

- `BangumiService` 在构造时会读取 `TokenHolder.accessToken` 并在每次请求前注入到 `ApiClient`。
- `UserProvider.login` 与 `UserProvider.logout` 会同步更新此变量，以保证后续网络请求使用最新的 token。

# BangumiService (`lib/services/bangumi_service.dart`)

> **注意**：`BangumiService` 位于 `lib/services/bangumi_service.dart`，是项目中所有网络请求的核心封装。

## 主要职责

封装对 **Bangumi API** 的 HTTP 调用，提供获取热门书籍、搜索、获取详情、人物、角色等功能。内部使用 `ApiClient`（基于 `dio`）发送请求，并在需要时注入 `accessToken`。

## 常用方法（示例）

```dart
Future<List<Subject>> fetchTrendingBooks();
Future<List<Subject>> searchSubjects({
  required String keyword,
  int limit = 30,
  int offset = 0,
  String sort = 'heat',
  List<String> tag = const [],
});
Future<Subject> getSubject(int id);
Future<List<RelatedPerson>> getSubjectPersons(int id);
Future<List<RelatedCharacter>> getSubjectCharacters(int id);
Future<User> getCurrentUser();
void setAccessToken(String? token);
```

## 与 Provider 的关联

- `UserProvider.login` 与 `UserProvider.refreshUser` 会调用 `BangumiService.setAccessToken` 同步 token。
- 页面在需要请求时直接实例化 `BangumiService`（如 `HomePage`、`SearchPage`、`SubjectDetailPage`）。

## 错误处理

所有方法均使用 `try/catch` 包裹，抛出异常后由调用方捕获并在 UI 中展示错误信息。

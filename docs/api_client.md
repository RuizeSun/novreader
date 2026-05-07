# ApiClient (`lib/services/api_client.dart`)

> **说明**：项目使用 `dio` 作为底层 HTTP 客户端，`ApiClient` 对其进行统一配置（baseUrl、拦截器、错误处理）。

## 关键配置

```dart
class ApiClient {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.bgm.tv',
    connectTimeout: 5000,
    receiveTimeout: 3000,
    headers: {'User-Agent': 'NovReader/1.0'},
  ));

  // 可选的拦截器，用于统一添加 token、日志等
  void addAuthToken(String token) {
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      options.headers['Authorization'] = 'Bearer $token';
      return handler.next(options);
    }));
  }
}
```

## 与 Service 的关系

`BangumiService` 持有 `ApiClient` 实例，通过 `apiClient._dio.get('/v0/subjects/$id')` 等方式发起请求。

## 错误统一处理

`ApiClient` 在拦截器中捕获 `DioError`，可统一转换为业务异常抛出。

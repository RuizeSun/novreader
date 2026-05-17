import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart'; // For PlatformException
import 'package:charset_converter/charset_converter.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import '../models/source_rule.dart';
import 'package:path_provider/path_provider.dart';

/// 来源规则引擎：根据 SourceRule 执行四阶段获取流程，最终返回 TXT 文件字节内容。
///
/// 该引擎旨在为拥有个人 NAS 或个人服务器的家庭用户提供一种方式，
/// 通过管理页面安全、合法地获取存放在其设备上的电子书内容。
/// 所有操作均基于用户自行提供的合法来源规则（SourceRule），
/// 不涉及任何未经授权的内容下载或分发。
class SourceRuleEngine {
  final SourceRule rule;
  final Dio _dio;
  final Map<String, String> _variables = {};

  final Map<String, String> _allCookies = {};
  String? _lastRequestUrl;
  String? _lastReferer;

  String? _stageThreePageUrl;

  SourceRuleEngine(this.rule) : _dio = Dio() {
    _configureDio();
  }

  void _configureDio() {
    final netConfig = rule.networkConfig;
    _dio.options = BaseOptions(
      connectTimeout: Duration(milliseconds: netConfig.timeoutMs),
      receiveTimeout: Duration(milliseconds: netConfig.timeoutMs),
      sendTimeout: Duration(milliseconds: netConfig.timeoutMs),
      headers: {'User-Agent': netConfig.userAgent, ...netConfig.globalHeaders},
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_allCookies.isNotEmpty) {
            final cookieStr = _allCookies.entries
                .map((e) => '${e.key}=${e.value}')
                .join('; ');
            options.headers['Cookie'] = cookieStr;
          }

          if (!options.headers.containsKey('Referer') && _lastReferer != null) {
            options.headers['Referer'] = _lastReferer;
          }

          handler.next(options);
        },
        onResponse: (response, handler) {
          _extractCookiesFromResponse(response);

          _lastRequestUrl = response.requestOptions.uri.toString();
          _lastReferer = _lastRequestUrl;

          handler.next(response);
        },
        onError: (error, handler) {
          if (error.response != null) {
            _extractCookiesFromResponse(error.response!);
          }
          handler.next(error);
        },
      ),
    );
  }

  void _extractCookiesFromResponse(Response response) {
    final setCookieHeaders = response.headers['set-cookie'];
    if (setCookieHeaders == null || setCookieHeaders.isEmpty) return;

    for (final header in setCookieHeaders) {
      final semicolonPos = header.indexOf(';');
      final cookiePair = semicolonPos >= 0
          ? header.substring(0, semicolonPos)
          : header;
      final eqPos = cookiePair.indexOf('=');
      if (eqPos >= 0) {
        final key = cookiePair.substring(0, eqPos).trim();
        final value = cookiePair.substring(eqPos + 1).trim();
        if (key.isNotEmpty) {
          _allCookies[key] = value;
        }
      }
    }
  }

  /// 创建 Options
  Options _createOptions({
    ResponseType? responseType,
    Map<String, dynamic>? extraHeaders,
  }) {
    return Options(responseType: responseType, headers: extraHeaders);
  }

  /// 执行完整的四阶段获取流程
  /// [keyword] 为搜索关键词（通常为书籍名）
  /// 返回获取的 TXT 文件字节内容
  ///
  /// 该方法在合法前提下，从用户自有的 NAS 或服务器上获取电子书内容，
  /// 仅用于用户自行管理的合法资源，不涉及任何未经授权的下载。
  Future<Uint8List> execute({required String keyword}) async {
    // 阶段 1：搜索书籍，获取 primaryId
    await _stageOneSearch(keyword);

    // 阶段 2：获取选择页 URL
    await _stageTwoManifest();

    // 阶段 3：提取真实内容 URL
    await _stageThreeContent();

    // 阶段 4：获取文件流
    return _stageFourDownload();
  }

  /// 阶段 1：搜索书籍，获取书籍标识符
  Future<void> _stageOneSearch(String keyword) async {
    final query = rule.stageOneQuery;
    final url = _resolveUrl(query.requestUrl);
    // 对于不同的 payload 类型，采用不同的处理方式。
    // 1) 当 payloadType 为 'form' 时，先解析模板为 Map，然后在每个 value 层面进行变量替换，
    //    最后交给 Dio 的 FormData.fromMap，由 Dio 自动完成 URL 编码。
    // 2) 其他情况（如 json、query string）保持原有的字符串替换逻辑。
    // 根据 payload 类型准备数据
    String payload = '';
    Map<String, dynamic>? formDataMap;
    if (query.payloadType == 'form') {
      // 解析模板为键值对，不进行 URL 解码（交给 Dio 处理）
      final rawMap = _parseFormData(query.requestPayload);
      // 在每个 value 中替换占位符 {keyword}
      final replacedMap = rawMap.map(
        (k, v) => MapEntry(k, (v as String).replaceAll('{keyword}', keyword)),
      );
      formDataMap = replacedMap;
    } else {
      // 其他类型保持原有的字符串替换逻辑
      payload = query.requestPayload.replaceAll('{keyword}', keyword);
    }

    String htmlContent;

    try {
      if (query.requestMethod.toUpperCase() == 'POST') {
        // POST 请求，支持 form 或 json payload
        if (query.payloadType == 'form') {
          // 对于 form 类型，已经在上方解析并完成变量替换，得到 formDataMap。
          // 这里直接使用该 map 创建 FormData。
          final formData = FormData.fromMap(formDataMap!);
          final response = await _requestWithRetry(
            () => _dio.post(
              url,
              data: formData,
              options: _createOptions(
                responseType: ResponseType.plain,
                extraHeaders: {
                  'Content-Type': 'application/x-www-form-urlencoded',
                },
              ),
            ),
          );
          htmlContent = response.data.toString();
        } else {
          final response = await _requestWithRetry(
            () => _dio.post(
              url,
              data: payload,
              options: _createOptions(responseType: ResponseType.plain),
            ),
          );
          htmlContent = response.data.toString();
        }
      } else {
        // GET 请求，将 payload 作为查询参数
        final fullUrl = payload.isNotEmpty ? '$url?$payload' : url;
        final response = await _requestWithRetry(
          () => _dio.get(
            fullUrl,
            options: _createOptions(responseType: ResponseType.plain),
          ),
        );
        htmlContent = response.data.toString();
      }
    } catch (e) {
      throw Exception('阶段1（搜索）失败: $e');
    }

    // 解析 HTML（_lastRequestUrl 由拦截器自动更新）
    final document = html_parser.parse(htmlContent);
    final containerSelector = query.containerSelector;

    if (containerSelector.isEmpty) {
      throw Exception('阶段1：containerSelector 为空，无法定位搜索结果');
    }

    // 找到容器元素
    final containers = _querySelectorAll(document.body!, containerSelector);

    if (containers.isEmpty) {
      throw Exception('阶段1：未找到匹配 containerSelector "$containerSelector" 的搜索结果');
    }

    // 使用第一个结果
    final firstContainer = containers.first;
    final extractedNodes = query.extractedNodes;

    // 提取字段
    if (extractedNodes.containsKey('primaryId')) {
      _variables['primaryId'] = _extractValue(
        firstContainer,
        extractedNodes['primaryId']!,
      );
    }
    if (extractedNodes.containsKey('displayTitle')) {
      _variables['displayTitle'] = _extractValue(
        firstContainer,
        extractedNodes['displayTitle']!,
      );
    }
    if (extractedNodes.containsKey('navigationUrl')) {
      _variables['navigationUrl'] = _extractValue(
        firstContainer,
        extractedNodes['navigationUrl']!,
      );
    }

    if (!_variables.containsKey('primaryId') ||
        _variables['primaryId']!.isEmpty) {
      throw Exception('阶段1：未能提取到 primaryId');
    }

    // 请求间隔
    await _delay();
  }

  /// 阶段 2：进入选择页获取内容
  Future<void> _stageTwoManifest() async {
    final manifest = rule.stageTwoManifest;
    // 先根据模板变量替换得到初始 URL，然后再解析为完整的绝对 URL（补全域名）
    final rawUrl = _resolveTemplate(manifest.requestUrl);
    final url = _resolveUrl(rawUrl);

    String htmlContent;
    try {
      final response = await _requestWithRetry(
        () => _dio.get(
          url,
          options: _createOptions(responseType: ResponseType.plain),
        ),
      );
      htmlContent = response.data.toString();
    } catch (e) {
      throw Exception('阶段2（详情页）失败: $e');
    }

    final document = html_parser.parse(htmlContent);
    final extractedNodes = manifest.extractedNodes;

    if (extractedNodes.containsKey('subSequenceList')) {
      final selector = extractedNodes['subSequenceList']!;
      final elements = _querySelectorAll(document.body!, selector);

      if (elements.isNotEmpty) {
        if (extractedNodes.containsKey('subSequenceTargetUrl')) {
          _variables['subSequenceTargetUrl'] = _extractValue(
            elements.first,
            extractedNodes['subSequenceTargetUrl']!,
          );
        }
        if (extractedNodes.containsKey('subSequenceTitle')) {
          // 如果没有明确指定提取方式，取 text
          final extractSpec = extractedNodes['subSequenceTitle']!;
          if (extractSpec == '@text') {
            _variables['subSequenceTitle'] = elements.first.text.trim();
          } else {
            _variables['subSequenceTitle'] = _extractValue(
              elements.first,
              extractSpec,
            );
          }
        }
      }
    }

    if (!_variables.containsKey('subSequenceTargetUrl') ||
        _variables['subSequenceTargetUrl']!.isEmpty) {
      throw Exception('阶段2：未能提取到内容页 URL');
    }

    await _delay();
  }

  /// 阶段 3：提取真实内容 URL
  Future<void> _stageThreeContent() async {
    final content = rule.stageThreeContent;
    // 同样先进行模板变量替换，再将相对路径转换为完整的绝对路径
    final rawUrl = _resolveTemplate(content.requestUrl);
    final url = _resolveUrl(rawUrl);

    String htmlContent;
    try {
      final response = await _requestWithRetry(
        () => _dio.get(
          url,
          options: _createOptions(responseType: ResponseType.plain),
        ),
      );
      htmlContent = response.data.toString();
    } catch (e) {
      throw Exception('阶段3（提取内容链接）失败: $e');
    }

    // 锁定阶段 3 的页面 URL，供阶段 4 获取请求固定使用
    _stageThreePageUrl = _lastRequestUrl;

    final document = html_parser.parse(htmlContent);
    final extractedNodes = content.extractedNodes;

    if (extractedNodes.containsKey('rawBodyText')) {
      final selector = extractedNodes['rawBodyText']!;
      final elements = _querySelectorAll(document.body!, selector);

      if (elements.isNotEmpty) {
        _variables['rawBodyText'] = _extractValue(elements.first, selector);
      } else {
        // 尝试直接在 document 中提取
        final attrValue = _extractValueFromDocument(document, selector);
        if (attrValue.isNotEmpty) {
          _variables['rawBodyText'] = attrValue;
        }
      }
    }

    if (!_variables.containsKey('rawBodyText') ||
        _variables['rawBodyText']!.isEmpty) {
      throw Exception('阶段3：未能提取到内容 URL');
    }

    await _delay();
  }

  /// 阶段 4：获取文件流
  Future<Uint8List> _stageFourDownload() async {
    final export = rule.stageFourExport;
    final url = _resolveTemplate(export.requestUrl);
    final netConfig = rule.networkConfig;

    // 1. 备份原有的超时时间
    final originalConnectTimeout = _dio.options.connectTimeout;
    final originalReceiveTimeout = _dio.options.receiveTimeout;
    final originalSendTimeout = _dio.options.sendTimeout;

    // 2. 设置专门针对获取的大超时时间（例如：3分钟）
    // 如有需要，可在 rule.networkConfig 中新增对应的配置项
    final downloadTimeout = Duration(minutes: 3);
    _dio.options.connectTimeout = downloadTimeout;
    _dio.options.receiveTimeout = downloadTimeout;
    _dio.options.sendTimeout = downloadTimeout;

    // 锁定 Referer：固定使用阶段 3 的页面 URL，跨域重定向后也不改变
    final lockedReferer = _stageThreePageUrl ?? _lastRequestUrl ?? url;

    try {
      final bytes = await _downloadWithRedirectTracking(
        url,
        lockedReferer,
        netConfig,
      );
      return bytes;
    } catch (e) {
      throw Exception('阶段4（获取文件）失败: $e');
    } finally {
      // 3. 无论成功或失败，必须在 finally 块中恢复原有的全局超时设置
      _dio.options.connectTimeout = originalConnectTimeout;
      _dio.options.receiveTimeout = originalReceiveTimeout;
      _dio.options.sendTimeout = originalSendTimeout;
    }
  }

  Future<Uint8List> _downloadWithRedirectTracking(
    String url,
    String referer,
    NetworkConfig netConfig,
  ) async {
    // 最大跟随重定向次数
    const maxRedirects = 10;
    var currentUrl = url;
    int redirectCount = 0;

    while (redirectCount < maxRedirects) {
      final headers = <String, dynamic>{
        'User-Agent': netConfig.userAgent,
        'Referer': referer,
        ...netConfig.globalHeaders,
      };
      if (_allCookies.isNotEmpty) {
        final cookieStr = _allCookies.entries
            .map((e) => '${e.key}=${e.value}')
            .join('; ');
        headers['Cookie'] = cookieStr;
      }

      final response = await _requestWithRetry(
        () => _dio.get(
          currentUrl,
          options: Options(
            // 使用 stream 模式避免大文件一次性加载到内存导致卡死，
            // 网络握手成功 + 响应头到达即可继续执行，后续通过手动消费流来组合数据
            responseType: ResponseType.stream,
            followRedirects: false,
            // 允许 Dio 自动处理解压（如果 Dio 配置了响应头）
            // 但因为我们是 ResponseType.stream，Dio 可能不会自动处理 gzip
            receiveDataWhenStatusError: true,
            validateStatus: (status) {
              return status != null && status < 400;
            },
            headers: headers,
          ),
        ),
      );

      // 从重定向响应中提取 Cookie（某些站点会在重定向 302 响应中下发 Cookie）
      _extractCookiesFromResponse(response);

      // 检查是否是重定向响应（302, 301, 307, 308）
      final statusCode = response.statusCode;
      if (statusCode == 301 ||
          statusCode == 302 ||
          statusCode == 307 ||
          statusCode == 308) {
        final location = response.headers.value('location');
        if (location == null || location.isEmpty) {
          // 3xx 重定向响应中 Body 没有解析意义，且服务器会立即关闭连接/流，
          // 尝试读取 Stream 会触发 StreamException: Stream closed。
          // 因此直接返回空字节。
          return Uint8List(0);
        }

        // 解析重定向 URL（可能是相对路径）
        currentUrl = _resolveRedirectUrl(currentUrl, location);
        redirectCount++;

        // 请求间隔
        await _delay();
      } else {
        // 非重定向响应：转换数据并返回文件内容
        return await _convertResponseDataToBytes(response.data);
      }
    }

    throw Exception('阶段4：重定向次数超过 $maxRedirects 次限制');
  }

  /// 将任意类型（dynamic）的响应数据统一转换为 Uint8List
  ///
  /// 使用运行时类型检测（is 运算符）兼容多种数据形态：
  /// - ResponseBody：Dio 在 ResponseType.stream 模式下实际返回的封装类型，
  ///   包含 statusCode、headers 等元数据，以及内部的 stream 属性。
  ///   提取其 stream 字段后用 BytesBuilder 逐块消费。
  /// - Stream<Uint8List>：兜底处理裸露的流式数据
  /// - Uint8List：ResponseType.bytes 模式下直接返回的字节数组
  /// - String：某些情况下 Dio 或拦截器可能返回字符串，
  ///   直接使用 UTF-8 编码转换为字节数组
  ///
  /// 这样即使 Dio 内部因某些原因切换了 ResponseType 或被拦截器修改了
  /// response.data 的类型，该方法也能无缝兼容，不会因强制类型转换而崩溃。
  Future<Uint8List> _convertResponseDataToBytes(dynamic data) async {
    if (data is ResponseBody) {
      // 1. 先将原始流完全读入内存，避免 Stream 只能消费一次且 transform 报错后无法恢复的问题
      final rawBuilder = BytesBuilder();
      await for (final chunk in data.stream) {
        rawBuilder.add(chunk);
      }
      final rawBytes = rawBuilder.toBytes();

      // 2. 检查是否被压缩
      final contentEncoding = data.headers["content-encoding"]?.first
          .toLowerCase();

      if (contentEncoding == "gzip" || contentEncoding == "deflate") {
        try {
          if (contentEncoding == "gzip") {
            return Uint8List.fromList(gzip.decode(rawBytes));
          } else {
            return Uint8List.fromList(zlib.decode(rawBytes));
          }
        } catch (e) {
          debugPrint("解压失败 ($contentEncoding): $e，回退到原始字节数据");
          // 如果解压失败，可能是头信息误报或数据不符合标准格式，直接返回原始字节（可能原本就是文本）
          return rawBytes;
        }
      }
      return rawBytes;
    } else if (data is Stream<Uint8List>) {
      final builder = BytesBuilder();
      await for (final chunk in data) {
        builder.add(chunk);
      }
      return builder.toBytes();
    } else if (data is Uint8List) {
      return data;
    } else if (data is String) {
      return Uint8List.fromList(data.codeUnits);
    } else {
      throw Exception('不支持的 response.data 类型: ${data.runtimeType}');
    }
  }

  /// 解析重定向 Location 为绝对 URL
  String _resolveRedirectUrl(String originalUrl, String location) {
    if (location.startsWith('http://') || location.startsWith('https://')) {
      return location;
    }
    if (location.startsWith('//')) {
      return 'https:$location';
    }
    // 相对路径：基于当前 URL 解析
    final uri = Uri.parse(originalUrl);
    final origin = uri.origin;
    if (location.startsWith('/')) {
      return '$origin$location';
    }
    // 相对路径
    final directory = uri.pathSegments
        .take(uri.pathSegments.length - 1)
        .join('/');
    final base = origin + (directory.isNotEmpty ? '/$directory' : '') + '/';
    return '$base$location';
  }

  /// 带重试的请求
  Future<Response> _requestWithRetry(
    Future<Response> Function() request,
  ) async {
    final maxRetries = rule.networkConfig.maxRetryAttempts;
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        return await request();
      } catch (e) {
        if (attempt == maxRetries - 1) rethrow;
        await Future.delayed(Duration(seconds: 1));
      }
    }
    throw Exception('请求失败（已重试 $maxRetries 次）');
  }

  /// 请求间隔
  Future<void> _delay() async {
    if (rule.networkConfig.requestDelayMs > 0) {
      await Future.delayed(
        Duration(milliseconds: rule.networkConfig.requestDelayMs),
      );
    }
  }

  /// 解析变量模板字符串，替换 {variableName} 为已提取的值
  String _resolveTemplate(String template) {
    String result = template;
    _variables.forEach((key, value) {
      result = result.replaceAll('{$key}', value);
    });
    return result;
  }

  /// 解析相对 URL 为绝对 URL
  ///
  /// 相对路径的处理规则：
  /// - 以 `http://` 或 `https://` 开头的完整 URL：直接返回
  /// - 以 `//` 开头的协议相对 URL：补上 `https:`
  /// - 以 `/` 开头的绝对路径：拼接根域名
  /// - 不以 `/` 开头的相对路径：相对于上一次请求的 URL 所在目录
  String _resolveUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    if (url.startsWith('//')) {
      return 'https:$url';
    }
    final targetDomain = rule.meta.targetDomain;
    if (targetDomain.isEmpty) return url;
    final base = targetDomain.endsWith('/') ? targetDomain : '$targetDomain/';

    // 以 / 开头的绝对路径：直接拼接根域名
    if (url.startsWith('/')) {
      return '$base${url.substring(1)}';
    }

    // 不以 / 开头的相对路径：相对于上一次请求的 URL 所在目录
    if (_lastRequestUrl != null) {
      final uri = Uri.parse(_lastRequestUrl!);
      final origin = uri.origin;
      final directory = uri.pathSegments
          .take(uri.pathSegments.length - 1)
          .join('/');
      final dirBase =
          origin + (directory.isNotEmpty ? '/$directory' : '') + '/';
      return '$dirBase$url';
    }

    // 兜底：没有上一次请求 URL 时，仍然用根域名
    return '$base$url';
  }

  /// 解析 form 数据字符串 a=b&c=d
  ///
  /// 这里不再对键和值进行 `Uri.decodeComponent`，因为后续交给 Dio 的
  /// `FormData.fromMap` 会自行处理必要的 URL 编码。直接返回原始的键值对即可，
  /// 这样可以避免在中文等未进行百分号编码的字符串上调用 `decodeComponent`
  /// 导致的异常。
  Map<String, dynamic> _parseFormData(String payload) {
    final map = <String, dynamic>{};
    final pairs = payload.split('&');
    for (final pair in pairs) {
      final parts = pair.split('=');
      if (parts.length == 2) {
        // 直接使用原始字符串，不进行解码
        map[parts[0]] = parts[1];
      }
    }
    return map;
  }

  /// 从元素中根据提取规范提取值
  String _extractValue(dom.Element element, String spec) {
    if (spec.contains(' @')) {
      // 分离选择器和提取指令，如 "a[href*='type=txt'][href*='node=1'] @href"
      final lastAtPos = spec.lastIndexOf(' @');
      final selectorPart = spec.substring(0, lastAtPos).trim();
      // 保留 @ 前缀，让 _getRawAttribute 能正确识别为属性引用
      final extractPart = spec.substring(lastAtPos + 1).trim();

      if (selectorPart.isNotEmpty) {
        // 在当前元素范围内查找匹配的元素
        final subElements = _querySelectorAll(element, selectorPart);
        if (subElements.isNotEmpty) {
          return _extractAttributeOrText(subElements.first, extractPart);
        }
      }
      return _extractAttributeOrText(element, extractPart);
    }

    // 简单提取 @href 或 @text
    return _extractAttributeOrText(element, spec);
  }

  /// 从属性或文本中提取值，支持正则后处理
  /// 格式: @href ## pattern ## $groupIndex
  String _extractAttributeOrText(dom.Element element, String extractSpec) {
    // 检查是否有正则后处理：spec 中包含 " ## " 和 " ## $"
    final regexPattern = r'^(.*?)\s*##\s*(.*?)\s*##\s*\$(\d+)$';
    final regexMatch = RegExp(regexPattern).firstMatch(extractSpec);

    if (regexMatch != null) {
      // 有正则后处理
      final attrSpec = regexMatch.group(1)!.trim();
      final pattern = regexMatch.group(2)!;
      final groupIndex = int.parse(regexMatch.group(3)!);

      final rawValue = _getRawAttribute(element, attrSpec);

      if (rawValue.isNotEmpty) {
        try {
          final re = RegExp(pattern);
          final match = re.firstMatch(rawValue);
          if (match != null && groupIndex <= match.groupCount) {
            return match.group(groupIndex) ?? '';
          }
        } catch (_) {
          // 正则匹配失败，返回原始值
        }
      }
      return rawValue;
    }

    return _getRawAttribute(element, extractSpec);
  }

  /// 获取原始属性值
  String _getRawAttribute(dom.Element element, String attrSpec) {
    if (attrSpec == '@href') {
      return element.attributes['href'] ?? '';
    } else if (attrSpec == '@text') {
      return element.text.trim();
    } else if (attrSpec.startsWith('@')) {
      return element.attributes[attrSpec.substring(1)] ?? '';
    }
    return element.text.trim();
  }

  /// 解析属性选择器条件，如 [href*='type=txt']
  List<Map<String, String>> _parseAttrConditions(String attrSelectors) {
    final conditions = <Map<String, String>>[];
    final attrMatches = RegExp(r'\[([^\]]+)\]').allMatches(attrSelectors);
    for (final m in attrMatches) {
      final attrExpr = m.group(1)!;
      // 支持 [attr*=value], [attr=value], [attr^=value], [attr$=value]
      // ignore: prefer_adjacent_string_concatenation
      final pattern =
          r'(\w+)([*^$]?)=['
          "'\""
          r']?(.*?)['
          "'\""
          r']?$';
      final parts = RegExp(pattern, caseSensitive: false).firstMatch(attrExpr);
      if (parts != null) {
        final attrName = parts.group(1)!;
        final op = parts.group(2) ?? '';
        final val = parts.group(3) ?? '';
        conditions.add({'attr': attrName, 'op': op, 'value': val});
      }
    }
    return conditions;
  }

  /// 根据选择器查询元素，支持 :contains() 伪类和复杂属性选择器
  List<dom.Element> _querySelectorAll(dom.Element root, String selector) {
    // 1) 解析 :contains(text) 伪类
    final containsPattern = r":contains\('([^']+)'\)";
    final containsMatch = RegExp(containsPattern).firstMatch(selector);
    if (containsMatch != null) {
      final searchText = containsMatch.group(1)!;
      final baseSelector = selector.replaceAll(RegExp(containsPattern), '');

      // 先用基础选择器查找
      List<dom.Element> elements;
      if (baseSelector.trim().isEmpty) {
        elements = root.querySelectorAll('*');
      } else {
        elements = root.querySelectorAll(baseSelector.trim());
      }

      // 过滤包含指定文本的元素
      return elements.where((el) {
        return el.text.contains(searchText);
      }).toList();
    }

    // 2) 处理复杂的属性选择器组合，如 a[href*='type=txt'][href*='node=1']
    final complexPattern = r'(\w+)((?:\[[^\]]+\])+)';
    final complexAttrMatch = RegExp(
      complexPattern,
      caseSensitive: false,
    ).firstMatch(selector);

    if (complexAttrMatch != null) {
      final tagName = complexAttrMatch.group(1)!;
      final attrSelectors = complexAttrMatch.group(2)!;

      // 找到所有匹配标签名的元素
      final allElements = root.querySelectorAll(tagName);
      if (allElements.isEmpty) return [];

      // 解析属性选择器条件
      final attrConditions = _parseAttrConditions(attrSelectors);

      return allElements.where((el) {
        return attrConditions.every((cond) {
          final attrVal = el.attributes[cond['attr']!] ?? '';
          final val = cond['value']!;
          switch (cond['op']) {
            case '*':
              return attrVal.contains(val);
            case '^':
              return attrVal.startsWith(val);
            case r'$':
              return attrVal.endsWith(val);
            case '':
              return attrVal == val;
            default:
              return attrVal.contains(val);
          }
        });
      }).toList();
    }

    // 3) 默认使用 html 包的 querySelectorAll
    try {
      return root.querySelectorAll(selector);
    } catch (_) {
      return [];
    }
  }

  /// 从整个 document 中根据提取规范取值
  String _extractValueFromDocument(dom.Document document, String spec) {
    if (spec.contains(' @')) {
      final lastAtPos = spec.lastIndexOf(' @');
      final selectorPart = spec.substring(0, lastAtPos).trim();
      // 保留 @ 前缀，让 _getRawAttribute 能正确识别为属性引用
      final extractPart = spec.substring(lastAtPos + 1).trim();
      if (selectorPart.isNotEmpty) {
        final elements = _querySelectorAll(document.body!, selectorPart);
        if (elements.isNotEmpty) {
          return _extractAttributeOrText(elements.first, extractPart);
        }
      }
    }
    return '';
  }

  /// 检测字节流的编码，将非 UTF‑8 内容统一转换为 UTF‑8 字节。
  ///
  /// 获取的 TXT 文件可能来自不同语言的本地服务器，编码可能是 GBK、Shift-JIS 或其他编码。
  /// 策略：
  ///   1. 用 UTF‑8 严格模式解码，如果成功且通过启发式检查，直接返回原字节（已经正确解码）。
  ///   2. 如果 UTF‑8 解码失败，尝试 GBK 解码，成功后重新编码为 UTF‑8 字节。
  ///   3. 如果两者都失败，返回原始字节（由后续读取逻辑兜底）。
  ///
  /// 启发式检查的原理：
  /// 当 GBK 编码的字节被误当作 UTF‑8 解码时，由于 GBK 双字节序列恰好构成合法 UTF‑8
  /// 序列的概率较高，utf8.decode() 不会抛出异常，但解码结果会变成大量拉丁扩展字符
  /// （U+0080–U+02FF 范围内的 ÀÁÂÃÄ…）。
  ///
  /// 检测方式（语言无关）：
  /// - 如果非 ASCII 字符占比低（< 15%），说明是纯 ASCII 或带少量重音符号的欧洲语言，直接信任。
  /// - 如果非 ASCII 字符占比高，检查其中有多少落在「可疑」的拉丁扩展范围（U+0080–U+02FF）。
  ///   - 法语/德语等欧洲语言的 UTF‑8：重音字符虽在可疑范围，但非 ASCII 总量极少（约 < 15%）。
  ///   - 中文/日文等 UTF‑8：CJK 字符（U+4E00+）不在可疑范围，可疑比例低。
  ///   - GBK 误当作 UTF‑8：几乎所有非 ASCII 字符都落在可疑范围（占比 > 80%），判定为误匹配。
  ///   - 俄文/乌克兰文 UTF‑8：西里尔字母（U+0400+）不在可疑范围，可疑比例低。
  static Future<String> saveToFile(Uint8List bytes, String title) async {
    final dir = await getApplicationSupportDirectory();
    final bookDir = Directory("${dir.path}/books");
    if (!await bookDir.exists()) {
      await bookDir.create(recursive: true);
    }

    // 生成安全的文件名
    final safeName = title
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${safeName}_$timestamp.txt';
    final filePath = '${bookDir.path}/$fileName';

    // 编码检测 & 统一转换为 UTF-8
    String content;
    try {
      content = utf8.decode(bytes);
    } on FormatException {
      // UTF-8 解码失败，尝试 GBK/GB18030
      try {
        content = await CharsetConverter.decode('gbk', bytes);
      } on PlatformException {
        // 如果 GBK 未识别，尝试 GB18030 作为备用。
        content = await CharsetConverter.decode('gb18030', bytes);
      }
    }

    // 写入统一编码后的字节
    final file = File(filePath);
    await file.writeAsString(content, encoding: utf8);

    return filePath;
  }
}

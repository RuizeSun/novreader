import 'dart:convert';

/// 来源规则模型，对应 JSON 来源文件格式
class SourceRule {
  final String schema;
  final String id;
  final String name;
  final String version;
  final String author;
  final String description;
  final SourceMeta meta;
  final NetworkConfig networkConfig;
  final StageQuery stageOneQuery;
  final StageManifest stageTwoManifest;
  final StageContent stageThreeContent;
  final StageExport stageFourExport;

  SourceRule({
    required this.schema,
    required this.id,
    required this.name,
    required this.version,
    required this.author,
    required this.description,
    required this.meta,
    required this.networkConfig,
    required this.stageOneQuery,
    required this.stageTwoManifest,
    required this.stageThreeContent,
    required this.stageFourExport,
  });

  factory SourceRule.fromJson(Map<String, dynamic> json) => SourceRule(
    schema: json['\$schema'] as String? ?? '',
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    version: json['version'] as String? ?? '',
    author: json['author'] as String? ?? '',
    description: json['description'] as String? ?? '',
    meta: json['meta'] != null
        ? SourceMeta.fromJson(json['meta'] as Map<String, dynamic>)
        : SourceMeta.empty(),
    networkConfig: json['networkConfig'] != null
        ? NetworkConfig.fromJson(json['networkConfig'] as Map<String, dynamic>)
        : NetworkConfig.empty(),
    stageOneQuery: json['stageOneQuery'] != null
        ? StageQuery.fromJson(json['stageOneQuery'] as Map<String, dynamic>)
        : StageQuery.empty(),
    stageTwoManifest: json['stageTwoManifest'] != null
        ? StageManifest.fromJson(
            json['stageTwoManifest'] as Map<String, dynamic>,
          )
        : StageManifest.empty(),
    stageThreeContent: json['stageThreeContent'] != null
        ? StageContent.fromJson(
            json['stageThreeContent'] as Map<String, dynamic>,
          )
        : StageContent.empty(),
    stageFourExport: json['stageFourExport'] != null
        ? StageExport.fromJson(json['stageFourExport'] as Map<String, dynamic>)
        : StageExport.empty(),
  );

  Map<String, dynamic> toJson() => {
    '\$schema': schema,
    'id': id,
    'name': name,
    'version': version,
    'author': author,
    'description': description,
    'meta': meta.toJson(),
    'networkConfig': networkConfig.toJson(),
    'stageOneQuery': stageOneQuery.toJson(),
    'stageTwoManifest': stageTwoManifest.toJson(),
    'stageThreeContent': stageThreeContent.toJson(),
    'stageFourExport': stageFourExport.toJson(),
  };
}

/// 元信息：目标域名、内容类型、支持格式、是否需要凭证
class SourceMeta {
  final String targetDomain;
  final String contentType;
  final List<String> supportedFormats;
  final bool credentialRequired;

  SourceMeta({
    required this.targetDomain,
    required this.contentType,
    required this.supportedFormats,
    required this.credentialRequired,
  });

  factory SourceMeta.fromJson(Map<String, dynamic> json) => SourceMeta(
    targetDomain: json['targetDomain'] as String? ?? '',
    contentType: json['contentType'] as String? ?? '',
    supportedFormats:
        (json['supportedFormats'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [],
    credentialRequired: json['credentialRequired'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'targetDomain': targetDomain,
    'contentType': contentType,
    'supportedFormats': supportedFormats,
    'credentialRequired': credentialRequired,
  };

  factory SourceMeta.empty() => SourceMeta(
    targetDomain: '',
    contentType: '',
    supportedFormats: [],
    credentialRequired: false,
  );
}

/// 网络配置：UA、超时、重试等
class NetworkConfig {
  final String userAgent;
  final int timeoutMs;
  final bool allowInsecureConnection;
  final int maxRetryAttempts;
  final int requestDelayMs;
  final Map<String, String> globalHeaders;

  NetworkConfig({
    required this.userAgent,
    required this.timeoutMs,
    required this.allowInsecureConnection,
    required this.maxRetryAttempts,
    required this.requestDelayMs,
    required this.globalHeaders,
  });

  factory NetworkConfig.fromJson(Map<String, dynamic> json) => NetworkConfig(
    userAgent: json['userAgent'] as String? ?? '',
    timeoutMs: json['timeoutMs'] as int? ?? 15000,
    allowInsecureConnection: json['allowInsecureConnection'] as bool? ?? false,
    maxRetryAttempts: json['maxRetryAttempts'] as int? ?? 3,
    requestDelayMs: json['requestDelayMs'] as int? ?? 1000,
    globalHeaders: json['globalHeaders'] != null
        ? Map<String, String>.from(
            json['globalHeaders'] as Map<String, dynamic>,
          )
        : {},
  );

  Map<String, dynamic> toJson() => {
    'userAgent': userAgent,
    'timeoutMs': timeoutMs,
    'allowInsecureConnection': allowInsecureConnection,
    'maxRetryAttempts': maxRetryAttempts,
    'requestDelayMs': requestDelayMs,
    'globalHeaders': globalHeaders,
  };

  factory NetworkConfig.empty() => NetworkConfig(
    userAgent: '',
    timeoutMs: 15000,
    allowInsecureConnection: false,
    maxRetryAttempts: 3,
    requestDelayMs: 1000,
    globalHeaders: {},
  );
}

/// 第一阶段查询配置（搜索）
class StageQuery {
  final String comment;
  final String requestMethod;
  final String requestUrl;
  final int initialPageIndex;
  final String payloadType;
  final String requestPayload;
  final String containerSelector;
  final Map<String, String> extractedNodes;

  StageQuery({
    required this.comment,
    required this.requestMethod,
    required this.requestUrl,
    required this.initialPageIndex,
    required this.payloadType,
    required this.requestPayload,
    required this.containerSelector,
    required this.extractedNodes,
  });

  factory StageQuery.fromJson(Map<String, dynamic> json) => StageQuery(
    comment: json['comment'] as String? ?? '',
    requestMethod: json['requestMethod'] as String? ?? 'GET',
    requestUrl: json['requestUrl'] as String? ?? '',
    initialPageIndex: json['initialPageIndex'] as int? ?? 1,
    payloadType: json['payloadType'] as String? ?? '',
    requestPayload: json['requestPayload'] as String? ?? '',
    containerSelector: json['containerSelector'] as String? ?? '',
    extractedNodes: json['extractedNodes'] != null
        ? Map<String, String>.from(
            json['extractedNodes'] as Map<String, dynamic>,
          )
        : {},
  );

  Map<String, dynamic> toJson() => {
    'comment': comment,
    'requestMethod': requestMethod,
    'requestUrl': requestUrl,
    'initialPageIndex': initialPageIndex,
    'payloadType': payloadType,
    'requestPayload': requestPayload,
    'containerSelector': containerSelector,
    'extractedNodes': extractedNodes,
  };

  factory StageQuery.empty() => StageQuery(
    comment: '',
    requestMethod: 'GET',
    requestUrl: '',
    initialPageIndex: 1,
    payloadType: '',
    requestPayload: '',
    containerSelector: '',
    extractedNodes: {},
  );
}

/// 第二阶段配置（详情页清单）
class StageManifest {
  final String comment;
  final String requestMethod;
  final String requestUrl;
  final String payloadType;
  final Map<String, String> extractedNodes;

  StageManifest({
    required this.comment,
    required this.requestMethod,
    required this.requestUrl,
    required this.payloadType,
    required this.extractedNodes,
  });

  factory StageManifest.fromJson(Map<String, dynamic> json) => StageManifest(
    comment: json['comment'] as String? ?? '',
    requestMethod: json['requestMethod'] as String? ?? 'GET',
    requestUrl: json['requestUrl'] as String? ?? '',
    payloadType: json['payloadType'] as String? ?? '',
    extractedNodes: json['extractedNodes'] != null
        ? Map<String, String>.from(
            json['extractedNodes'] as Map<String, dynamic>,
          )
        : {},
  );

  Map<String, dynamic> toJson() => {
    'comment': comment,
    'requestMethod': requestMethod,
    'requestUrl': requestUrl,
    'payloadType': payloadType,
    'extractedNodes': extractedNodes,
  };

  factory StageManifest.empty() => StageManifest(
    comment: '',
    requestMethod: 'GET',
    requestUrl: '',
    payloadType: '',
    extractedNodes: {},
  );
}

/// 第三阶段配置（内容提取）
class StageContent {
  final String comment;
  final String requestMethod;
  final String requestUrl;
  final String payloadType;
  final Map<String, String> extractedNodes;
  final List<String> sanitizePipelines;

  StageContent({
    required this.comment,
    required this.requestMethod,
    required this.requestUrl,
    required this.payloadType,
    required this.extractedNodes,
    required this.sanitizePipelines,
  });

  factory StageContent.fromJson(Map<String, dynamic> json) => StageContent(
    comment: json['comment'] as String? ?? '',
    requestMethod: json['requestMethod'] as String? ?? 'GET',
    requestUrl: json['requestUrl'] as String? ?? '',
    payloadType: json['payloadType'] as String? ?? '',
    extractedNodes: json['extractedNodes'] != null
        ? Map<String, String>.from(
            json['extractedNodes'] as Map<String, dynamic>,
          )
        : {},
    sanitizePipelines:
        (json['sanitizePipelines'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [],
  );

  Map<String, dynamic> toJson() => {
    'comment': comment,
    'requestMethod': requestMethod,
    'requestUrl': requestUrl,
    'payloadType': payloadType,
    'extractedNodes': extractedNodes,
    'sanitizePipelines': sanitizePipelines,
  };

  factory StageContent.empty() => StageContent(
    comment: '',
    requestMethod: 'GET',
    requestUrl: '',
    payloadType: '',
    extractedNodes: {},
    sanitizePipelines: [],
  );
}

/// 第四阶段导出配置
class StageExport {
  final String comment;
  final String executionAction;
  final String requestUrl;
  final String payloadType;

  StageExport({
    required this.comment,
    required this.executionAction,
    required this.requestUrl,
    required this.payloadType,
  });

  factory StageExport.fromJson(Map<String, dynamic> json) => StageExport(
    comment: json['comment'] as String? ?? '',
    executionAction: json['executionAction'] as String? ?? '',
    requestUrl: json['requestUrl'] as String? ?? '',
    payloadType: json['payloadType'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'comment': comment,
    'executionAction': executionAction,
    'requestUrl': requestUrl,
    'payloadType': payloadType,
  };

  factory StageExport.empty() => StageExport(
    comment: '',
    executionAction: '',
    requestUrl: '',
    payloadType: '',
  );
}

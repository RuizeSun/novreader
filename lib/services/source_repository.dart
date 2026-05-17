import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/source_rule.dart';

/// 来源规则持久化服务，使用 SharedPreferences 存储 JSON 字符串数组
class SourceRepository {
  static const _key = 'source_rules';

  /// 读取所有已保存的来源规则
  Future<List<SourceRule>> loadSources() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    final List<dynamic> list = json.decode(jsonStr) as List<dynamic>;
    return list
        .map((e) => SourceRule.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 保存来源规则列表
  Future<void> _saveSources(List<SourceRule> sources) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = json.encode(sources.map((s) => s.toJson()).toList());
    await prefs.setString(_key, jsonStr);
  }

  /// 添加一条来源规则，如果 id 重复则抛出异常
  Future<void> addSource(SourceRule source) async {
    final sources = await loadSources();
    if (sources.any((s) => s.id == source.id)) {
      throw Exception('来源规则 ID "${source.id}" 已存在，无法重复添加');
    }
    sources.add(source);
    await _saveSources(sources);
  }

  /// 根据 id 删除一条来源规则
  Future<void> removeSource(String id) async {
    final sources = await loadSources();
    sources.removeWhere((s) => s.id == id);
    await _saveSources(sources);
  }

  /// 根据 id 查找来源规则
  Future<SourceRule?> getSource(String id) async {
    final sources = await loadSources();
    try {
      return sources.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}

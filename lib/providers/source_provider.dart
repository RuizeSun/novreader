import 'package:flutter/foundation.dart';
import '../models/source_rule.dart';
import '../services/source_repository.dart';

/// 来源规则状态管理，监听来源列表变化并自动通知 UI 更新
class SourceProvider with ChangeNotifier {
  final SourceRepository _repository = SourceRepository();
  List<SourceRule> _sources = [];
  bool _isLoading = false;

  List<SourceRule> get sources => List.unmodifiable(_sources);
  bool get isLoading => _isLoading;

  /// 初始化加载来源规则列表
  Future<void> loadSources() async {
    _isLoading = true;
    notifyListeners();

    try {
      _sources = await _repository.loadSources();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 导入一条来源规则，如果 id 重复则抛出异常
  Future<void> addSource(SourceRule source) async {
    await _repository.addSource(source);
    _sources = await _repository.loadSources();
    notifyListeners();
  }

  /// 根据 id 删除一条来源规则
  Future<void> removeSource(String id) async {
    await _repository.removeSource(id);
    _sources = await _repository.loadSources();
    notifyListeners();
  }

  /// 根据 id 查找来源规则
  SourceRule? getSource(String id) {
    try {
      return _sources.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}

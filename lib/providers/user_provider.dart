import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/bangumi_service.dart';
import '../services/token_holder.dart';

class UserProvider with ChangeNotifier {
  static const String _prefsKey =
      'accessToken'; // used for SharedPreferences (user data)
  static const String _secureTokenKey =
      'secureAccessToken'; // key for secure storage
  static const String _userPrefsKey = 'currentUser';

  String? _accessToken;
  User? _currentUser;

  String? get accessToken => _accessToken;
  User? get currentUser => _currentUser;

  bool get isLoggedIn => _accessToken != null && _currentUser != null;

  UserProvider() {
    _loadUser();
  }

  Future<void> _loadUser() async {
    // Load token securely
    final secureStorage = const FlutterSecureStorage();
    final token = await secureStorage.read(key: _secureTokenKey);

    // Load other user data from SharedPreferences (non-sensitive)
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userPrefsKey);

    if (token != null) {
      _accessToken = token;
      // 同步 token 到 BangumiService
      BangumiService().setAccessToken(_accessToken);
    }

    if (userData != null) {
      try {
        final Map<String, dynamic> json = jsonDecode(userData);
        _currentUser = User.fromJson(json);
      } catch (e) {
        // 解析失败，忽略
      }
    }

    notifyListeners();
  }

  Future<void> login(String token) async {
    final bangumiService = BangumiService();
    bangumiService.setAccessToken(token);
    // 同步到全局 TokenHolder
    TokenHolder.accessToken = token;

    try {
      final user = await bangumiService.getCurrentUser();
      final prefs = await SharedPreferences.getInstance();

      _accessToken = token;
      _currentUser = user;

      // Store token securely
      final secureStorage = const FlutterSecureStorage();
      await secureStorage.write(key: _secureTokenKey, value: token);
      await prefs.setString(_userPrefsKey, jsonEncode(user.toJson()));

      notifyListeners();
    } catch (e) {
      // 登录失败，清除状态
      await logout();
      rethrow;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = null;
    _currentUser = null;

    // 移除保存在 SharedPreferences 中的非敏感用户信息
    await prefs.remove(_userPrefsKey);

    // 从安全存储中删除访问令牌
    final secureStorage = const FlutterSecureStorage();
    await secureStorage.delete(key: _secureTokenKey);

    // 清除全局 TokenHolder
    TokenHolder.accessToken = null;

    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (!isLoggedIn) return;

    try {
      final bangumiService = BangumiService();
      bangumiService.setAccessToken(_accessToken);
      final user = await bangumiService.getCurrentUser();

      _currentUser = user;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userPrefsKey, jsonEncode(user.toJson()));

      notifyListeners();
    } catch (e) {
      // 刷新失败，保持原状态
    }
  }
}

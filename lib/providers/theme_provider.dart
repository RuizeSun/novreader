import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const String _prefsKey = 'isDarkMode';
  static const String _colorKey = 'primaryColor';
  static const String _followSystemKey = 'followSystemAccent';

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  // 新增主色调字段，默认使用蓝色
  // 默认主色调为蓝色
  Color _primaryColor = const Color(0xFF6C63FF);
  bool _followSystemAccent = false;
  Color get primaryColor => _primaryColor;
  bool get followSystemAccent => _followSystemAccent;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_prefsKey) ?? false;
    final int? colorValue = prefs.getInt(_colorKey);
    if (colorValue != null) {
      _primaryColor = Color(colorValue);
    }
    _followSystemAccent = prefs.getBool(_followSystemKey) ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, _isDarkMode);
    await prefs.setInt(_colorKey, _primaryColor.value);
    await prefs.setBool(_followSystemKey, _followSystemAccent);
    notifyListeners();
  }

  /// 设置主题主色并持久化
  Future<void> setPrimaryColor(Color color) async {
    _primaryColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_colorKey, color.value);
    // 关闭跟随系统的选项，因为用户手动选择了颜色
    _followSystemAccent = false;
    await prefs.setBool(_followSystemKey, _followSystemAccent);
    notifyListeners();
  }

  /// 设置是否跟随系统强调色
  Future<void> setFollowSystemAccent(bool follow) async {
    _followSystemAccent = follow;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_followSystemKey, follow);
    notifyListeners();
  }

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    primaryColor: _followSystemAccent ? Colors.blue : _primaryColor,
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    appBarTheme: AppBarTheme(
      backgroundColor: _followSystemAccent ? Colors.blue : _primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: _followSystemAccent ? Colors.blue : _primaryColor,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
    ),
  );

  ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    primaryColor: _followSystemAccent ? Colors.blue : _primaryColor,
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF1E1E1E),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1E1E1E),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: const Color(0xFF1E1E1E),
      selectedItemColor: _followSystemAccent ? Colors.blue : _primaryColor,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
    ),
  );
}

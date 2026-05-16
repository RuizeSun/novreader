import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const String _prefsKey = 'isDarkMode';
  static const String _colorKey = 'primaryColor';
  static const String _followSystemKey = 'followSystemAccent';
  static const String _titleDisplayKey = 'showChineseTitle';
  // 新增阅读页设置的持久化键
  static const String _fontSizeKey = 'readingFontSize';
  static const String _titleFontSizeKey = 'readingTitleFontSize';
  static const String _lineHeightKey = 'readingLineHeight';
  static const String _paragraphSpacingKey = 'readingParagraphSpacing';
  static const String _doubleColumnEnabledKey = 'readingDoubleColumnEnabled';
  static const String _doubleColumnTriggerKey =
      'readingDoubleColumnTriggerWidth';
  // 新增阅读页背景颜色持久化键
  static const String _readingBgColorKey = 'readingBackgroundColor';
  // 新增阅读页字体颜色持久化键
  static const String _readingFontColorKey = 'readingFontColor';

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  // 新增主色调字段，默认使用蓝色
  // 默认主色调为蓝色
  Color _primaryColor = const Color(0xFF6C63FF);
  bool _followSystemAccent = false;
  // 是否在卡片上默认显示中文标题，默认 true
  // 阅读页默认设置
  double _fontSize = 18.0; // 与原始 _textStyle.fontSize 相同
  double _titleFontSize = 16.0;
  double _lineHeight = 1.6;
  double _paragraphSpacing = 0.0; // 通过在文本中插入空行实现
  bool _doubleColumnEnabled = false;
  double _doubleColumnTriggerWidth = 800.0; // 默认宽度阈值
  // 背景颜色，默认白色
  Color _readingBackgroundColor = Colors.white;
  // 字体颜色，默认黑色（与之前的硬编码保持一致）
  Color _readingFontColor = Colors.black87;
  bool _showChineseTitle = true;
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
    _showChineseTitle = prefs.getBool(_titleDisplayKey) ?? true;
    // 读取阅读页设置，若不存在则使用默认值
    _fontSize = prefs.getDouble(_fontSizeKey) ?? 18.0;
    _titleFontSize = prefs.getDouble(_titleFontSizeKey) ?? 16.0;
    _lineHeight = prefs.getDouble(_lineHeightKey) ?? 1.6;
    _paragraphSpacing = prefs.getDouble(_paragraphSpacingKey) ?? 0.0;
    _doubleColumnEnabled = prefs.getBool(_doubleColumnEnabledKey) ?? false;
    _doubleColumnTriggerWidth =
        prefs.getDouble(_doubleColumnTriggerKey) ?? 800.0;
    // 读取阅读页背景颜色，若不存在则使用默认白色
    final int? bgColorValue = prefs.getInt(_readingBgColorKey);
    if (bgColorValue != null) {
      _readingBackgroundColor = Color(bgColorValue);
    }
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

  /// 设置是否在卡片上默认显示中文标题并持久化
  Future<void> setShowChineseTitle(bool show) async {
    _showChineseTitle = show;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_titleDisplayKey, show);
    notifyListeners();
  }

  bool get showChineseTitle => _showChineseTitle;

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

  // ---------- 阅读页设置相关 API ----------
  double get readingFontSize => _fontSize;
  double get readingTitleFontSize => _titleFontSize;
  double get readingLineHeight => _lineHeight;
  double get readingParagraphSpacing => _paragraphSpacing;
  bool get doubleColumnEnabled => _doubleColumnEnabled;
  double get doubleColumnTriggerWidth => _doubleColumnTriggerWidth;
  Color get readingBackgroundColor => _readingBackgroundColor;
  Color get readingFontColor => _readingFontColor;

  Future<void> setReadingFontSize(double size) async {
    _fontSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, size);
    notifyListeners();
  }

  Future<void> setReadingTitleFontSize(double size) async {
    _titleFontSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_titleFontSizeKey, size);
    notifyListeners();
  }

  Future<void> setReadingLineHeight(double height) async {
    _lineHeight = height;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_lineHeightKey, height);
    notifyListeners();
  }

  Future<void> setReadingParagraphSpacing(double spacing) async {
    _paragraphSpacing = spacing;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_paragraphSpacingKey, spacing);
    notifyListeners();
  }

  Future<void> setDoubleColumnEnabled(bool enabled) async {
    _doubleColumnEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_doubleColumnEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> setDoubleColumnTriggerWidth(double width) async {
    _doubleColumnTriggerWidth = width;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_doubleColumnTriggerKey, width);
    notifyListeners();
  }

  // 设置阅读页背景颜色并持久化
  Future<void> setReadingBackgroundColor(Color color) async {
    _readingBackgroundColor = color;
    // 若背景为暗色且当前字体颜色也暗，则自动切换为白色以保证可读性
    final brightness = ThemeData.estimateBrightnessForColor(color);
    if (brightness == Brightness.dark) {
      // 判断当前字体颜色亮度，若也是暗色则改为白色
      final fontBrightness = ThemeData.estimateBrightnessForColor(
        _readingFontColor,
      );
      if (fontBrightness != Brightness.light) {
        _readingFontColor = Colors.white;
        final prefsFont = await SharedPreferences.getInstance();
        await prefsFont.setInt(_readingFontColorKey, _readingFontColor.value);
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_readingBgColorKey, color.value);
    notifyListeners();
  }

  // 设置阅读页字体颜色并持久化
  Future<void> setReadingFontColor(Color color) async {
    _readingFontColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_readingFontColorKey, color.value);
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

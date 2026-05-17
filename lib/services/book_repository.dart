import 'dart:convert';
import 'package:flutter/foundation.dart'; // for ValueNotifier
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book.dart';

/// 本地持久化书籍列表，使用 SharedPreferences 保存 JSON 字符串
class BookRepository {
  static const _key = 'bookshelf_books';

  /// A notifier that broadcasts changes to the book list.
  /// Listeners can rebuild UI when books are added, updated, or removed.
  static final ValueNotifier<void> notifier = ValueNotifier(null);

  /// 读取所有已保存的书籍
  Future<List<Book>> loadBooks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    final List<dynamic> list = json.decode(jsonStr) as List<dynamic>;
    return list.map((e) => Book.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 保存书籍列表
  Future<void> _saveBooks(List<Book> books) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = json.encode(books.map((b) => b.toJson()).toList());
    await prefs.setString(_key, jsonStr);
  }

  /// 添加一本书
  Future<void> addBook(Book book) async {
    final books = await loadBooks();
    books.add(book);
    await _saveBooks(books);
    // Notify listeners that the book list has changed.
    notifier.value = null;
  }

  /// 更新已有书籍（根据 id）
  Future<void> updateBook(Book book) async {
    final books = await loadBooks();
    final index = books.indexWhere((b) => b.id == book.id);
    if (index != -1) {
      books[index] = book;
      await _saveBooks(books);
      // Notify listeners about the update.
      notifier.value = null;
    }
  }

  /// 删除一本书
  Future<void> removeBook(String id) async {
    final books = await loadBooks();
    books.removeWhere((b) => b.id == id);
    await _saveBooks(books);
    // Notify listeners about the removal.
    notifier.value = null;
  }
}

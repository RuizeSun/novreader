import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart'; // For PlatformException
import 'package:charset_converter/charset_converter.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/book.dart';
import '../services/book_repository.dart';
import 'reading_page.dart';

/// 书架页面，实现导入 txt、关联 Bangumi、阅读功能。
class BookshelfPage extends StatefulWidget {
  const BookshelfPage({Key? key}) : super(key: key);

  @override
  State<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends State<BookshelfPage> {
  final BookRepository _repo = BookRepository();
  List<Book> _books = [];

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    final books = await _repo.loadBooks();
    setState(() => _books = books);
  }

  /// 导入本地 txt 文件并保存到应用文档目录
  Future<void> _importTxt() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );
    if (result == null || result.files.isEmpty) return;

    final pickedFile = result.files.single;
    final file = File(pickedFile.path!);
    final bytes = await file.readAsBytes();

    // Try UTF-8 first, fallback to GBK (or GB18030) using charset_converter
    // The charset_converter plugin may not recognize the name "gbk" on some platforms.
    // We attempt to decode with "gbk" first, and if that throws a PlatformException,
    // we fall back to the more widely supported "gb18030" which is a superset of GBK.
    String content;
    try {
      content = utf8.decode(bytes);
    } on FormatException {
      // UTF-8 decoding failed, try GBK/GB18030
      try {
        content = await CharsetConverter.decode('gbk', bytes);
      } on PlatformException {
        // If GBK is not recognized, try GB18030 as a fallback.
        content = await CharsetConverter.decode('gb18030', bytes);
      }
    }

    // Save as UTF-8 in app documents directory
    final appDir = await getApplicationDocumentsDirectory();
    final destPath =
        '${appDir.path}/${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
    await File(destPath).writeAsString(content, encoding: utf8);

    final book = Book(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: file.uri.pathSegments.last,
      filePath: destPath,
    );
    await _repo.addBook(book);
    await _loadBooks();
  }

  /// 关联 Bangumi 书目（简化实现：仅弹出输入框获取 subjectId）
  Future<void> _linkBangumi(Book book) async {
    final controller = TextEditingController();
    final subjectIdStr = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('输入 Bangumi Subject ID'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (subjectIdStr == null || subjectIdStr.isEmpty) return;
    final updated = book.copyWith(bangumiSubjectId: int.tryParse(subjectIdStr));
    await _repo.updateBook(updated);
    await _loadBooks();
  }

  /// 删除书籍
  Future<void> _deleteBook(String id) async {
    await _repo.removeBook(id);
    await _loadBooks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('书架'), elevation: 0),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importTxt,
        label: const Text('导入 txt'),
        icon: const Icon(Icons.upload_file),
      ),
      body: _books.isEmpty
          ? const Center(child: Text('暂无书籍，点击右下角导入'))
          : ListView.builder(
              itemCount: _books.length,
              itemBuilder: (c, i) {
                final book = _books[i];
                return ListTile(
                  title: Text(book.title),
                  subtitle: book.bangumiSubjectId != null
                      ? Text('Bangumi ID: ${book.bangumiSubjectId}')
                      : const Text('未关联 Bangumi'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.link),
                        tooltip: '关联 Bangumi',
                        onPressed: () => _linkBangumi(book),
                      ),
                      IconButton(
                        icon: const Icon(Icons.book),
                        tooltip: '阅读',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReadingPage(book: book),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: '删除',
                        onPressed: () => _deleteBook(book.id),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

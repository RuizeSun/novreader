import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart'; // For PlatformException
import 'package:charset_converter/charset_converter.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/book.dart';
import '../services/book_repository.dart';
import '../services/bangumi_service.dart';
import '../models/subject.dart';
import '../widgets/subject_card.dart';
import '../widgets/bookshelf_item_card.dart';
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

  // Listener to refresh the shelf when the repository notifies changes.
  void _onRepositoryChanged() {
    // Fire and forget; errors are handled inside _loadBooks.
    _loadBooks();
  }

  @override
  void initState() {
    super.initState();
    // Initial load.
    _loadBooks();
    // Subscribe to repository changes.
    BookRepository.notifier.addListener(_onRepositoryChanged);
  }

  @override
  void dispose() {
    // Clean up the listener to avoid memory leaks.
    BookRepository.notifier.removeListener(_onRepositoryChanged);
    super.dispose();
  }

  Future<void> _loadBooks() async {
    final allBooks = await _repo.loadBooks();
    // 只显示已加入书架（isOnShelf == true）的书籍
    setState(() => _books = allBooks.where((b) => b.isOnShelf).toList());
  }

  /// 导入本地 txt 文件并保存到适当的应用支持目录（跨平台）
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

    // Determine appropriate storage directory based on platform
    Future<Directory> _getStorageDirectory() async {
      if (Platform.isAndroid) {
        // Prefer external storage directory on Android for user-accessible files
        final externalDir = await getExternalStorageDirectory();
        // Fallback to application support directory if external is unavailable
        return externalDir ?? await getApplicationSupportDirectory();
      }
      // For iOS, Windows, macOS, Linux and others, use application support directory
      return await getApplicationSupportDirectory();
    }

    final appDir = await _getStorageDirectory();
    final destPath =
        '${appDir.path}/${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
    await File(destPath).writeAsString(content, encoding: utf8);

    final book = Book(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: file.uri.pathSegments.last,
      filePath: destPath,
      isOnShelf: true, // 本地导入的书籍默认加入书架
    );
    await _repo.addBook(book);
    await _loadBooks();
  }

  /// 关联 Bangumi 书目（通过搜索书名并选择）
  Future<void> _searchAndLinkBangumi(Book book) async {
    final controller = TextEditingController();
    List<Subject> results = [];
    bool isLoading = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setState) {
          Future<void> _performSearch() async {
            final keyword = controller.text.trim();
            if (keyword.isEmpty) return;
            setState(() {
              isLoading = true;
              error = null;
            });
            try {
              final subjects = await BangumiService().searchSubjects(
                keyword: keyword,
                limit: 30,
                tag: ['小说'],
              );
              setState(() {
                results = subjects;
              });
            } catch (e) {
              setState(() {
                error = e.toString();
              });
            } finally {
              setState(() {
                isLoading = false;
              });
            }
          }

          return AlertDialog(
            title: const Text('搜索 Bangumi 书籍'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(hintText: '输入书名关键词'),
                    onSubmitted: (_) => _performSearch(),
                  ),
                  const SizedBox(height: 8),
                  if (isLoading)
                    const Center(child: CircularProgressIndicator()),
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  if (!isLoading && results.isNotEmpty)
                    SizedBox(
                      height: 300,
                      child: GridView.builder(
                        shrinkWrap: true,
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 200,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 0.6,
                            ),
                        itemCount: results.length,
                        itemBuilder: (c, i) {
                          final sub = results[i];
                          return BookshelfItemCard(
                            subject: sub,
                            onTap: () async {
                              final updated = book.copyWith(
                                bangumiSubjectId: sub.id,
                              );
                              await _repo.updateBook(updated);
                              await _loadBooks();
                              Navigator.of(c).pop();
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(c).pop(),
                child: const Text('取消'),
              ),
            ],
          );
        },
      ),
    );
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
                if (book.bangumiSubjectId != null) {
                  return FutureBuilder<Subject>(
                    future: BangumiService().getSubjectCached(
                      book.bangumiSubjectId!,
                    ),
                    builder: (c, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const ListTile(title: Text('加载中...'));
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return ListTile(
                          title: Text(book.title),
                          subtitle: const Text('获取封面失败'),
                        );
                      }
                      final sub = snapshot.data!;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BookshelfItemCard(
                            subject: sub,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ReadingPage(book: book),
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.link),
                                tooltip: '重新关联 Bangumi',
                                onPressed: () => _searchAndLinkBangumi(book),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                tooltip: '删除',
                                onPressed: () => _deleteBook(book.id),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                } else {
                  return ListTile(
                    title: Text(book.title),
                    subtitle: const Text('未关联 Bangumi'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.link),
                          tooltip: '关联 Bangumi',
                          onPressed: () => _searchAndLinkBangumi(book),
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
                }
              },
            ),
    );
  }
}

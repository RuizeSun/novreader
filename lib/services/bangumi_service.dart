import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import '../models/subject.dart';
import '../models/related_person.dart';
import '../models/related_character.dart';
import 'api_client.dart';

class BangumiService {
  final ApiClient _apiClient = ApiClient();

  Future<List<Subject>> searchSubjects({
    required String keyword,
    int limit = 30,
    int offset = 0,
    String sort = 'match',
    List<int>? type,
    List<String>? tag,
  }) async {
    try {
      final response = await _apiClient.post(
        '/v0/search/subjects',
        data: {
          'keyword': keyword,
          'sort': sort,
          'limit': limit,
          'offset': offset,
          if (type != null) 'filter': {'type': type},
          if (tag != null && tag.isNotEmpty) 'filter': {'tag': tag},
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = response.data;
        final List<dynamic> data = responseData['data'] ?? [];
        return data.map((json) => Subject.fromJson(json)).toList();
      } else {
        throw Exception('搜索失败: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Subject> getSubject(int subjectId) async {
    try {
      final response = await _apiClient.get('/v0/subjects/$subjectId');
      if (response.statusCode == 200) {
        return Subject.fromJson(response.data);
      } else {
        throw Exception('获取条目失败: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// 获取与条目相关的所有人物（如作者、声优）
  Future<List<RelatedPerson>> getSubjectPersons(int subjectId) async {
    try {
      final response = await _apiClient.get('/v0/subjects/$subjectId/persons');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => RelatedPerson.fromJson(json)).toList();
      } else {
        throw Exception('获取人物信息失败: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// 获取与条目相关的所有角色
  Future<List<RelatedCharacter>> getSubjectCharacters(int subjectId) async {
    try {
      final response = await _apiClient.get(
        '/v0/subjects/$subjectId/characters',
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => RelatedCharacter.fromJson(json)).toList();
      } else {
        throw Exception('获取角色信息失败: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// 使用官方 API 获取热门书籍（按热度排序）
  Future<List<Subject>> fetchTrendingBooks() async {
    try {
      // 调用搜索接口，使用空关键字、热度排序，并限定类型为书籍（type = 1）且标签为“小说”
      final results = await searchSubjects(
        keyword: '',
        limit: 30,
        offset: 0,
        sort: 'heat',
        type: [1],
        tag: ['小说'],
      );
      return results;
    } catch (e) {
      rethrow;
    }
  }
}

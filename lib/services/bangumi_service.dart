import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import '../models/subject.dart';
import '../models/related_person.dart' hide Images;
import '../models/related_character.dart';
import '../models/user.dart';
import 'api_client.dart';
import 'token_holder.dart';

class BangumiService {
  final ApiClient _apiClient = ApiClient();

  /// 设置访问令牌
  void setAccessToken(String? token) {
    TokenHolder.accessToken = token;
  }

  /// 获取当前访问令牌
  String? getAccessToken() {
    return TokenHolder.accessToken;
  }

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
  ///
  /// `limit` 参数决定一次请求返回的条目数量，默认 30。页面可以通过传入更大的 `limit`
  /// 来在首次加载时填满屏幕，从而实现信息流的效果。
  Future<List<Subject>> fetchTrendingBooks({int limit = 30}) async {
    try {
      // 调用搜索接口，使用空关键字、热度排序，并限定类型为书籍（type = 1）且标签为“小说”
      final results = await searchSubjects(
        keyword: '',
        limit: limit,
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

  /// 使用爬虫方式获取热门书籍（按热度排序）
  ///
  /// 该方法直接请求 Bangumi 书籍浏览页面 `https://bgm.tv/book/browser/?sort=trends`
  /// 并解析返回的 HTML，提取每本书的关键字段，返回 `Subject` 列表。
  ///
  /// - `limit`：单页返回的最大条目数，默认 30。
  /// - `page`：分页页码，默认 1。页面通过 `?page=n` 参数切换。
  ///
  /// 只会填充 `Subject` 中我们在 UI 中使用的字段，其余使用默认/空值。
  Future<List<Subject>> fetchTrendingBooksScrape({
    int limit = 30,
    int page = 1,
  }) async {
    try {
      // 直接请求网页，使用 Dio 获取原始 HTML 内容
      final response = await Dio().get(
        'https://bgm.tv/book/browser/?sort=trends&page=$page',
      );
      if (response.statusCode == 200) {
        // 解析 HTML
        final document = html_parser.parse(response.data);
        // 选取列表项，每个 <li id="item_XXXX">
        final elements = document.querySelectorAll('#browserItemList > li');
        final List<Subject> results = [];
        for (final element in elements) {
          if (results.length >= limit) break;
          // id
          final idAttr = element.id; // e.g., item_573423
          final id = int.tryParse(idAttr.replaceAll('item_', '')) ?? 0;
          // 标题和中文标题
          final titleElem = element.querySelector('h3 a.l');
          final title = titleElem?.text.trim() ?? '';
          final nameCnElem = element.querySelector('h3 small.grey');
          final nameCn = nameCnElem?.text.trim() ?? '';
          // 封面图片
          var cover = '';
          final imgElem = element.querySelector('a.subjectCover img');
          if (imgElem != null) {
            cover = imgElem.attributes['src'] ?? '';
            if (cover.startsWith('//')) {
              cover = 'https:$cover';
            }
          }
          // 排名
          int rank = 0;
          final rankElem = element.querySelector('span.rank');
          if (rankElem != null) {
            final rankText = rankElem.text; // 包含 "Rank" 与数字
            final match = RegExp(r'\d+').firstMatch(rankText);
            if (match != null) rank = int.parse(match.group(0)!);
          }
          // 简介信息（日期、作者、出版社等）
          final infoElem = element.querySelector('p.info.tip');
          final info = infoElem?.text.trim() ?? '';
          // 评分分数
          int score = 0;
          final scoreElem = element.querySelector('p.rateInfo small.fade');
          if (scoreElem != null) {
            score = double.tryParse(scoreElem.text.trim())?.round() ?? 0;
          }
          // 评分人数
          int ratingCount = 0;
          final countElem = element.querySelector('p.rateInfo span.tip_j');
          if (countElem != null) {
            final countMatch = RegExp(r'\d+').firstMatch(countElem.text);
            if (countMatch != null)
              ratingCount = int.parse(countMatch.group(0)!);
          }
          // 构造 Subject（仅填充必要字段）
          final subject = Subject(
            id: id,
            name: title,
            nameCn: nameCn,
            type: 1,
            images: Images(
              small: cover,
              grid: cover,
              large: cover,
              medium: cover,
              common: cover,
            ),
            summary: info,
            rating: Rating(count: ratingCount, score: score, distribution: {}),
            rank: rank,
            popularity: 0,
            collectionsCount: 0,
            tags: [],
            platform: '',
            nsfw: 0,
          );
          results.add(subject);
        }
        return results;
      } else {
        throw Exception('Failed to fetch page: \${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// 获取当前用户信息
  Future<User> getCurrentUser() async {
    try {
      final response = await _apiClient.get('/v0/me');
      if (response.statusCode == 200) {
        return User.fromJson(response.data);
      } else {
        throw Exception('获取用户信息失败: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}

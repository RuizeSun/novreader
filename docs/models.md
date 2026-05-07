# 数据模型 (`lib/models/`)

项目的核心数据模型位于 `lib/models/`，以下列出关键模型及其主要字段（省略次要字段）。

## Subject (`subject.dart`)

```dart
class Subject {
  final int id;
  final String name;
  final String nameCn;
  final Images images; // large、medium、common 等 URL
  final Rating rating; // score、count
  final List<String> tags;
  final String summary;
  final List<Map<String, dynamic>>? infobox;
  final int rank;
  final String? date;
  // 其他字段省略
}
```

## User (`user.dart`)

```dart
class User {
  final String username;
  final String nickname;
  final Avatar avatar; // large、medium、small
  // 其他字段省略
}
```

## RelatedPerson (`related_person.dart`)

```dart
class RelatedPerson {
  final String name;
  final String relation; // 与作品的关系，如 "主角"、"配角"
  final Images images;
}
```

## RelatedCharacter (`related_character.dart`)

```dart
class RelatedCharacter {
  final String name;
  final String relation;
  final Images images;
}
```

## 其他模型

- `Images` – 包含 `large`、`medium`、`common` 等 URL 字段。
- `Rating` – 包含 `score`（double）与 `count`（int）。
- `Avatar` – 与 `Images` 类似，用于用户头像。

这些模型均实现 `fromJson` / `toJson`，用于与 Bangumi API 的响应进行序列化/反序列化。

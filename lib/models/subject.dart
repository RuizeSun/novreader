class Subject {
  Subject({
    required this.id,
    required this.name,
    required this.nameCn,
    required this.type,
    required this.images,
    required this.summary,
    required this.rating,
    required this.rank,
    required this.popularity,
    required this.collectionsCount,
    required this.tags,
    required this.platform,
    required this.nsfw,
    this.date,
    this.infobox,
  });

  int id;
  String name;
  String nameCn;
  int type;
  Images images;
  String summary;
  Rating rating;
  int rank;
  int popularity;
  int collectionsCount;
  List<String> tags;
  String platform;
  int nsfw;
  String? date;
  List<dynamic>? infobox;

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
    id: json["id"] ?? 0,
    name: json["name"] ?? '',
    nameCn: json["name_cn"] ?? '',
    type: json["type"] ?? 0,
    images: json["images"] != null
        ? Images.fromJson(json["images"])
        : Images.empty(),
    summary: json["summary"] ?? '',
    rating: json["rating"] != null
        ? Rating.fromJson(json["rating"])
        : Rating.empty(),
    rank: json["rank"] ?? 0,
    popularity: json["popularity"] ?? 0,
    collectionsCount: json["collection"] != null
        ? (json["collection"]["collect"] ?? 0) as int
        : 0,
    tags: json["tags"] != null
        ? List<String>.from(
            (json["tags"] as List).map(
              (x) => x is String ? x : (x["name"] ?? ''),
            ),
          )
        : [],
    platform: json["platform"] ?? '',
    nsfw: json["nsfw"] == true ? 1 : 0,
    date: json["date"],
    infobox: json["infobox"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "name_cn": nameCn,
    "type": type,
    "images": images.toJson(),
    "summary": summary,
    "rating": rating.toJson(),
    "rank": rank,
    "popularity": popularity,
    "collections_count": collectionsCount,
    "tags": List<dynamic>.from(tags.map((x) => x)),
    "platform": platform,
    "nsfw": nsfw,
    "date": date,
    "infobox": infobox,
  };

  static List<Subject> fromJsonList(List<dynamic> jsonList) =>
      jsonList.map((json) => Subject.fromJson(json)).toList();
}

class Images {
  Images({
    required this.small,
    required this.grid,
    required this.large,
    required this.medium,
    required this.common,
  });

  String small;
  String grid;
  String large;
  String medium;
  String common;

  factory Images.fromJson(Map<String, dynamic> json) => Images(
    small: json["small"] ?? '',
    grid: json["grid"] ?? '',
    large: json["large"] ?? '',
    medium: json["medium"] ?? '',
    common: json["common"] ?? '',
  );

  factory Images.empty() =>
      Images(small: '', grid: '', large: '', medium: '', common: '');

  Map<String, dynamic> toJson() => {
    "small": small,
    "grid": grid,
    "large": large,
    "medium": medium,
    "common": common,
  };
}

class Rating {
  Rating({
    required this.count,
    required this.score,
    required this.distribution,
  });

  int count;
  int score;
  Map<String, int> distribution;

  factory Rating.fromJson(Map<String, dynamic> json) => Rating(
    count: json["total"] ?? json["count"] ?? 0,
    score: (json["score"] ?? 0).round(),
    distribution: json["distribution"] != null
        ? Map.from(
            json["distribution"],
          ).map((k, v) => MapEntry<String, int>(k.toString(), v as int))
        : {},
  );

  factory Rating.empty() => Rating(count: 0, score: 0, distribution: {});

  Map<String, dynamic> toJson() => {
    "count": count,
    "score": score,
    "distribution": Map.from(
      distribution,
    ).map((k, v) => MapEntry<String, dynamic>(k, v)),
  };
}

class RelatedPerson {
  final int id;
  final String name;
  final int type;
  final List<String> career;
  final Images images;
  final String relation;
  final String eps;

  RelatedPerson({
    required this.id,
    required this.name,
    required this.type,
    required this.career,
    required this.images,
    required this.relation,
    required this.eps,
  });

  factory RelatedPerson.fromJson(Map<String, dynamic> json) => RelatedPerson(
    id: json["id"] ?? 0,
    name: json["name"] ?? '',
    type: json["type"] ?? 0,
    career: (json["career"] as List?)?.map((e) => e.toString()).toList() ?? [],
    images: json["images"] != null
        ? Images.fromJson(json["images"])
        : Images.empty(),
    relation: json["relation"] ?? '',
    eps: json["eps"] ?? '',
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "type": type,
    "career": career,
    "images": images.toJson(),
    "relation": relation,
    "eps": eps,
  };
}

class Images {
  final String small;
  final String grid;
  final String large;
  final String medium;
  final String common;

  Images({
    required this.small,
    required this.grid,
    required this.large,
    required this.medium,
    required this.common,
  });

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

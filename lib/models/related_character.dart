import '../models/related_person.dart';

class RelatedCharacter {
  final int id;
  final String name;
  final String summary;
  final int type;
  final Images images;
  final String relation;
  final List<RelatedPerson> actors;

  RelatedCharacter({
    required this.id,
    required this.name,
    required this.summary,
    required this.type,
    required this.images,
    required this.relation,
    required this.actors,
  });

  factory RelatedCharacter.fromJson(Map<String, dynamic> json) =>
      RelatedCharacter(
        id: json["id"] ?? 0,
        name: json["name"] ?? '',
        summary: json["summary"] ?? '',
        type: json["type"] ?? 0,
        images: json["images"] != null
            ? Images.fromJson(json["images"])
            : Images.empty(),
        relation: json["relation"] ?? '',
        actors:
            (json["actors"] as List?)
                ?.map((e) => RelatedPerson.fromJson(e))
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "summary": summary,
    "type": type,
    "images": images.toJson(),
    "relation": relation,
    "actors": actors.map((e) => e.toJson()).toList(),
  };
}

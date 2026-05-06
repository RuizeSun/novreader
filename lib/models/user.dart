class User {
  final int id;
  final String username;
  final String nickname;
  final Avatar avatar;
  final String sign;
  final int userGroup;

  User({
    required this.id,
    required this.username,
    required this.nickname,
    required this.avatar,
    required this.sign,
    required this.userGroup,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json["id"] ?? 0,
    username: json["username"] ?? '',
    nickname: json["nickname"] ?? '',
    avatar: json["avatar"] != null
        ? Avatar.fromJson(json["avatar"])
        : Avatar.empty(),
    sign: json["sign"] ?? '',
    userGroup: json["user_group"] ?? 1,
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "username": username,
    "nickname": nickname,
    "avatar": avatar.toJson(),
    "sign": sign,
    "user_group": userGroup,
  };
}

class Avatar {
  final String large;
  final String medium;
  final String small;

  Avatar({required this.large, required this.medium, required this.small});

  factory Avatar.fromJson(Map<String, dynamic> json) => Avatar(
    large: json["large"] ?? '',
    medium: json["medium"] ?? '',
    small: json["small"] ?? '',
  );

  factory Avatar.empty() => Avatar(large: '', medium: '', small: '');

  Map<String, dynamic> toJson() => {
    "large": large,
    "medium": medium,
    "small": small,
  };
}

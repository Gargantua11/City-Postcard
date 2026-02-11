class User {
  final String id;
  final String username;
  final String? avatar;
  final String accessToken;
  final String? refreshToken;
  final String tokenType;
  final int expiresInSeconds;

  User({
    required this.id,
    required this.username,
    this.avatar,
    required this.accessToken,
    this.refreshToken,
    required this.tokenType,
    required this.expiresInSeconds,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      avatar: json['avatar'],
      accessToken: json['accessToken'] ?? json['token'] ?? '',
      refreshToken: json['refreshToken'],
      tokenType: json['tokenType'] ?? 'Bearer',
      expiresInSeconds: json['expiresInSeconds'] ?? 1800,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'avatar': avatar,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'tokenType': tokenType,
      'expiresInSeconds': expiresInSeconds,
    };
  }
}

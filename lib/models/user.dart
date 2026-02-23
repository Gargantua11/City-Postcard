class User {
  final String id;
  final String username;
  final String? avatar;
  final String? phone;
  final String? cityName;
  final String? cityCode;
  final String accessToken;
  final String? refreshToken;
  final String tokenType;
  final int expiresInSeconds;

  User({
    required this.id,
    required this.username,
    this.avatar,
    this.phone,
    this.cityName,
    this.cityCode,
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
      phone: json['phone']?.toString(),
      cityName: json['cityName'] ?? json['city'],
      cityCode: json['cityCode']?.toString(),
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
      'phone': phone,
      'cityName': cityName,
      'cityCode': cityCode,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'tokenType': tokenType,
      'expiresInSeconds': expiresInSeconds,
    };
  }

  User copyWith({
    String? id,
    String? username,
    String? avatar,
    String? phone,
    String? cityName,
    String? cityCode,
    String? accessToken,
    String? refreshToken,
    String? tokenType,
    int? expiresInSeconds,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      avatar: avatar ?? this.avatar,
      phone: phone ?? this.phone,
      cityName: cityName ?? this.cityName,
      cityCode: cityCode ?? this.cityCode,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      tokenType: tokenType ?? this.tokenType,
      expiresInSeconds: expiresInSeconds ?? this.expiresInSeconds,
    );
  }
}

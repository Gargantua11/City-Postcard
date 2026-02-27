import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class StorageService {
  static const String _userKey = 'user';
  static const String _tokenKey = 'token';
  static const String _home3dPreviewEnabledKey = 'home_3d_preview_enabled';
  static const String _profileCityNameKey = 'profile_city_name';
  static const String _profileCityCodeKey = 'profile_city_code';
  static const String _profileNicknameKey = 'profile_nickname';
  static const String _profileAvatarKey = 'profile_avatar';
  static const String _profilePhoneKey = 'profile_phone';
  static const String _profilePasswordKey = 'profile_password';
  static const String _editedPostcardsKey = 'edited_postcards';
  static const String _discussionPostsCacheKey = 'discussion_posts_cache_v1';
  static const String _discussionLocalPostsKey = 'discussion_local_posts_v1';
  static const String _targetCleanupDoneKey =
      'cleanup_postcard_avatar_discussion_done_v1';

  // 保存用户信息
  Future<void> saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedToken = _normalizeAccessToken(user.accessToken);
    final normalizedUser = user.copyWith(accessToken: normalizedToken);
    await prefs.setString(_userKey, jsonEncode(normalizedUser.toJson()));
    await prefs.setString(_tokenKey, normalizedToken);
  }

  // 获取用户信息
  Future<User?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      return User.fromJson(jsonDecode(userJson));
    }
    return null;
  }

  // 获取token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final fromTokenKey = prefs.getString(_tokenKey)?.trim() ?? '';
    if (fromTokenKey.isNotEmpty) {
      return _normalizeAccessToken(fromTokenKey);
    }

    final userJson = prefs.getString(_userKey)?.trim() ?? '';
    if (userJson.isEmpty) return null;
    try {
      final decoded = jsonDecode(userJson);
      if (decoded is Map<String, dynamic>) {
        final token = decoded['accessToken']?.toString().trim() ?? '';
        if (token.isNotEmpty) {
          final normalized = _normalizeAccessToken(token);
          await prefs.setString(_tokenKey, normalized);
          return normalized;
        }
      }
      if (decoded is Map) {
        final token = decoded['accessToken']?.toString().trim() ?? '';
        if (token.isNotEmpty) {
          final normalized = _normalizeAccessToken(token);
          await prefs.setString(_tokenKey, normalized);
          return normalized;
        }
      }
    } catch (_) {}
    return null;
  }

  // 清除用户信息
  Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_tokenKey);
  }

  // 检查是否已登录
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.trim().isNotEmpty;
  }

  String _normalizeAccessToken(String raw) {
    final token = raw.trim();
    if (token.isEmpty) return '';
    return token.replaceFirst(RegExp(r'^Bearer\s+', caseSensitive: false), '');
  }

  Future<void> saveProfileCity({
    required String cityName,
    required String cityCode,
  }) async {
    final normalizedName = cityName.trim();
    final normalizedCode = cityCode.trim();
    if (normalizedName.isEmpty || normalizedCode.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileCityNameKey, normalizedName);
    await prefs.setString(_profileCityCodeKey, normalizedCode);

    final user = await getUser();
    if (user != null) {
      await saveUser(
        user.copyWith(cityName: normalizedName, cityCode: normalizedCode),
      );
    }
  }

  Future<void> saveProfileCityNameOnly(String cityName) async {
    final normalizedName = cityName.trim();
    if (normalizedName.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileCityNameKey, normalizedName);

    final user = await getUser();
    if (user != null) {
      await saveUser(user.copyWith(cityName: normalizedName));
    }
  }

  Future<void> clearProfileCityCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileCityCodeKey);

    final user = await getUser();
    if (user != null) {
      await saveUser(user.copyWith(cityCode: null));
    }
  }

  Future<String?> getProfileCityName() async {
    final user = await getUser();
    final fromUser = user?.cityName?.trim();
    if (fromUser != null && fromUser.isNotEmpty) {
      return fromUser;
    }

    final prefs = await SharedPreferences.getInstance();
    final fromPrefs = prefs.getString(_profileCityNameKey)?.trim();
    if (fromPrefs == null || fromPrefs.isEmpty) return null;
    return fromPrefs;
  }

  Future<String?> getProfileCityCode() async {
    final user = await getUser();
    final fromUser = user?.cityCode?.trim();
    if (fromUser != null && fromUser.isNotEmpty) {
      return fromUser;
    }

    final prefs = await SharedPreferences.getInstance();
    final fromPrefs = prefs.getString(_profileCityCodeKey)?.trim();
    if (fromPrefs == null || fromPrefs.isEmpty) return null;
    return fromPrefs;
  }

  Future<void> saveProfileNickname(String nickname) async {
    final normalized = nickname.trim();
    if (normalized.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileNicknameKey, normalized);

    final user = await getUser();
    if (user != null) {
      await saveUser(user.copyWith(username: normalized));
    }
  }

  Future<String?> getProfileNickname() async {
    final prefs = await SharedPreferences.getInstance();
    final fromPrefs = prefs.getString(_profileNicknameKey)?.trim();
    if (fromPrefs != null && fromPrefs.isNotEmpty) {
      return fromPrefs;
    }

    final user = await getUser();
    final fromUser = user?.username.trim();
    if (fromUser == null || fromUser.isEmpty) return null;
    return fromUser;
  }

  Future<void> saveProfileAvatar(String? avatarSource) async {
    final normalized = avatarSource?.trim() ?? '';
    final prefs = await SharedPreferences.getInstance();

    if (normalized.isEmpty) {
      await prefs.remove(_profileAvatarKey);
    } else {
      await prefs.setString(_profileAvatarKey, normalized);
    }

    final user = await getUser();
    if (user != null) {
      await saveUser(user.copyWith(avatar: normalized));
    }
  }

  Future<String?> getProfileAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final fromPrefs = prefs.getString(_profileAvatarKey)?.trim();
    if (fromPrefs != null && fromPrefs.isNotEmpty) {
      return fromPrefs;
    }

    final user = await getUser();
    final fromUser = user?.avatar?.trim();
    if (fromUser == null || fromUser.isEmpty) return null;
    return fromUser;
  }

  Future<void> saveProfilePhone(String phone) async {
    final normalized = phone.trim();
    if (normalized.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profilePhoneKey, normalized);

    final user = await getUser();
    if (user != null) {
      await saveUser(user.copyWith(phone: normalized));
    }
  }

  Future<String?> getProfilePhone() async {
    final prefs = await SharedPreferences.getInstance();
    final fromPrefs = prefs.getString(_profilePhoneKey)?.trim();
    if (fromPrefs != null && fromPrefs.isNotEmpty) {
      return fromPrefs;
    }

    final user = await getUser();
    final fromUser = user?.phone?.trim();
    if (fromUser == null || fromUser.isEmpty) return null;
    return fromUser;
  }

  Future<void> saveProfilePassword(String password) async {
    final normalized = password.trim();
    if (normalized.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profilePasswordKey, normalized);
  }

  Future<String?> getProfilePassword() async {
    final prefs = await SharedPreferences.getInstance();
    final password = prefs.getString(_profilePasswordKey)?.trim();
    if (password == null || password.isEmpty) return null;
    return password;
  }

  Future<void> saveHome3dPreviewEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_home3dPreviewEnabledKey, enabled);
  }

  Future<bool?> getHome3dPreviewEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_home3dPreviewEnabledKey)) {
      return null;
    }
    return prefs.getBool(_home3dPreviewEnabledKey);
  }

  Future<void> clearPostcardAvatarDiscussionLocalData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_editedPostcardsKey);
    await prefs.remove(_discussionPostsCacheKey);
    await prefs.remove(_discussionLocalPostsKey);
    await prefs.remove(_profileAvatarKey);

    final user = await getUser();
    if (user != null) {
      await saveUser(user.copyWith(avatar: ''));
    }
  }

  Future<void> clearPostcardAvatarDiscussionLocalDataOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_targetCleanupDoneKey) == true) {
      return;
    }

    await clearPostcardAvatarDiscussionLocalData();
    await prefs.setBool(_targetCleanupDoneKey, true);
  }
}

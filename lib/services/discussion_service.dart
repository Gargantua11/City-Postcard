import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/postcard_element_layer.dart';
import 'backend_api_client.dart';

class DiscussionFetchResult {
  final List<DiscussionPost> posts;
  final bool isOffline;
  final String? notice;

  const DiscussionFetchResult({
    required this.posts,
    required this.isOffline,
    this.notice,
  });
}

class DiscussionPost {
  static const List<String> _layerPayloadKeys = <String>[
    'elements',
    'layers',
    'elementList',
    'layerList',
    'elementVOList',
    'layerVOList',
    'postcardElementVOList',
    'postcardElements',
    'postcardElementList',
    'elementsJson',
    'layersJson',
    'postcardElementsJson',
    'postcardElementJson',
    'elementJson',
    'layerJson',
    'elementsData',
    'layersData',
  ];

  static const List<String> _layerContainerKeys = <String>[
    'data',
    'postcard',
    'postcardInfo',
    'postcardDetail',
    'postcardDto',
    'postcardVO',
    'postcardVo',
    'detail',
    'card',
    'record',
    'item',
  ];

  static const List<String> _imageUrlKeys = <String>[
    'imageUrl',
    'image',
    'url',
    'coverUrl',
    'postcardUrl',
    'postcardImageUrl',
    'postcardImage',
    'coverImage',
    'thumbnail',
    'thumbUrl',
    'imagePath',
    'coverPath',
  ];

  static const List<String> _imageKeyKeys = <String>[
    'imageKey',
    'key',
    'objectKey',
    'fileKey',
    'coverKey',
    'imageObjectKey',
    'path',
  ];

  final int id;
  final String username;
  final String? avatar;
  final String imageUrl;
  final List<PostcardElementLayer> layers;
  final DateTime createdAt;
  final String address;
  final int likeCount;
  final int commentCount;
  final String hotComment;

  const DiscussionPost({
    required this.id,
    required this.username,
    this.avatar,
    required this.imageUrl,
    this.layers = const <PostcardElementLayer>[],
    required this.createdAt,
    required this.address,
    required this.likeCount,
    required this.commentCount,
    required this.hotComment,
  });

  factory DiscussionPost.fromJson(Map<String, dynamic> json) {
    final hotComment = _extractHotComment(json);

    return DiscussionPost(
      id:
          BackendApiClient.readInt(json, const [
            'postcardId',
            'cardId',
            'id',
            'postId',
          ]) ??
          0,
      username: _extractUsername(json) ?? '匿名用户',
      avatar: BackendApiClient.readString(json, const ['avatar', 'avatarUrl']),
      imageUrl: _extractImageSource(json),
      layers: _extractLayers(json),
      createdAt: _parseDateTime(
        BackendApiClient.readString(json, const [
              'createdAt',
              'createTime',
              'publishTime',
              'time',
            ]) ??
            '',
      ),
      address:
          BackendApiClient.readString(json, const [
            'address',
            'location',
            'cityName',
          ]) ??
          '未知地点',
      likeCount:
          BackendApiClient.readInt(json, const [
            'likeCount',
            'likes',
            'likeNum',
          ]) ??
          0,
      commentCount:
          BackendApiClient.readInt(json, const [
            'commentCount',
            'comments',
            'commentNum',
          ]) ??
          0,
      hotComment: hotComment,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'username': username,
      'avatar': avatar,
      'imageUrl': imageUrl,
      if (layers.isNotEmpty)
        'layers': layers.map((item) => item.toJson()).toList(growable: false),
      'createdAt': createdAt.toIso8601String(),
      'address': address,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'hotComment': hotComment,
    };
  }

  static String _extractHotComment(Map<String, dynamic> json) {
    final rawHotComment = json['hotComment'];
    if (rawHotComment is String) {
      final text = _normalizeHotCommentText(rawHotComment);
      if (text.isNotEmpty) {
        return text;
      }
    }

    final nested = BackendApiClient.asMap(rawHotComment);
    if (nested != null) {
      final nestedContent = BackendApiClient.readString(nested, const [
        'content',
        'commentContent',
        'text',
      ]);
      if (nestedContent != null && nestedContent.isNotEmpty) {
        return _normalizeHotCommentText(nestedContent);
      }
    }

    if (rawHotComment is List) {
      for (final entry in rawHotComment) {
        final entryMap = BackendApiClient.asMap(entry);
        if (entryMap == null) continue;
        final entryContent = BackendApiClient.readString(entryMap, const [
          'content',
          'commentContent',
          'text',
        ]);
        if (entryContent != null && entryContent.isNotEmpty) {
          return _normalizeHotCommentText(entryContent);
        }
      }
    }

    final direct = BackendApiClient.readString(json, const [
      'hotCommentContent',
    ]);
    if (direct != null && direct.isNotEmpty) {
      return _normalizeHotCommentText(direct);
    }

    return '';
  }

  static List<PostcardElementLayer> _extractLayers(Map<String, dynamic> json) {
    final layers = <PostcardElementLayer>[];
    final fingerprints = <String>{};

    void append(List<PostcardElementLayer> incoming) {
      _appendUniqueLayers(layers, fingerprints, incoming);
    }

    append(_parseLayerList(json));

    for (final key in _layerContainerKeys) {
      append(_parseLayerList(json[key]));
      append(_parseLayerList(_decodeDynamicJson(json[key])));
    }

    for (final entry in json.entries) {
      final key = entry.key.trim().toLowerCase();
      if (!(key.contains('element') || key.contains('layer'))) {
        continue;
      }
      append(_parseLayerList(entry.value));
    }

    return layers;
  }

  static String _extractImageSource(Map<String, dynamic> json) {
    final directUrl = _normalizeImageSource(_readImageUrlCandidate(json));
    if (directUrl.isNotEmpty) {
      return directUrl;
    }

    final directKey = _normalizeImageSource(_readImageKeyCandidate(json));
    if (directKey.isNotEmpty) {
      return directKey;
    }

    for (final key in _layerContainerKeys) {
      final nestedMap = BackendApiClient.asMap(json[key]);
      if (nestedMap != null) {
        final nestedImage = _extractImageSource(nestedMap);
        if (nestedImage.isNotEmpty) {
          return nestedImage;
        }
      }

      final decoded = _decodeDynamicJson(json[key]);
      final decodedMap = BackendApiClient.asMap(decoded);
      if (decodedMap != null) {
        final decodedImage = _extractImageSource(decodedMap);
        if (decodedImage.isNotEmpty) {
          return decodedImage;
        }
      }
    }

    return '';
  }

  static List<PostcardElementLayer> _parseLayerList(dynamic raw) {
    if (raw == null) return const <PostcardElementLayer>[];

    final source = _decodeDynamicJsonDeep(raw);
    if (source == null) return const <PostcardElementLayer>[];
    if (source is String && source.trim().isEmpty) {
      return const <PostcardElementLayer>[];
    }

    if (source is Map<String, dynamic>) {
      final layers = <PostcardElementLayer>[];
      final fingerprints = <String>{};

      for (final key in _layerPayloadKeys) {
        _appendUniqueLayers(layers, fingerprints, _parseLayerList(source[key]));
      }

      for (final entry in source.entries) {
        final key = entry.key.trim().toLowerCase();
        if (!(key.contains('element') || key.contains('layer'))) {
          continue;
        }
        _appendUniqueLayers(layers, fingerprints, _parseLayerList(entry.value));
      }
      if (layers.isNotEmpty) {
        return layers;
      }

      if (_looksLikeLayerMap(source)) {
        final layer = PostcardElementLayer.fromJson(
          source,
          fallbackId: 'discussion_layer_single',
        );
        if (_isRenderableLayer(layer)) {
          _appendUniqueLayers(layers, fingerprints, <PostcardElementLayer>[
            layer,
          ]);
        }
      }

      return layers;
    }
    if (source is Map) {
      final casted = <String, dynamic>{};
      for (final entry in source.entries) {
        final key = entry.key?.toString().trim() ?? '';
        if (key.isEmpty) continue;
        casted[key] = entry.value;
      }
      return _parseLayerList(casted);
    }
    if (source is! List) return const <PostcardElementLayer>[];

    final layers = <PostcardElementLayer>[];
    final fingerprints = <String>{};
    for (var i = 0; i < source.length; i++) {
      final item = _decodeDynamicJsonDeep(source[i]);
      final itemMap = BackendApiClient.asMap(item);
      if (itemMap == null) {
        continue;
      }

      if (!_looksLikeLayerMap(itemMap)) {
        _appendUniqueLayers(layers, fingerprints, _parseLayerList(itemMap));
        continue;
      }

      final layer = PostcardElementLayer.fromJson(
        itemMap,
        fallbackId: 'discussion_layer_$i',
      );
      if (_isRenderableLayer(layer)) {
        _appendUniqueLayers(layers, fingerprints, <PostcardElementLayer>[
          layer,
        ]);
      }
    }
    return layers;
  }

  static void _appendUniqueLayers(
    List<PostcardElementLayer> target,
    Set<String> fingerprints,
    Iterable<PostcardElementLayer> incoming,
  ) {
    for (final layer in incoming) {
      final fingerprint = _layerFingerprint(layer);
      if (!fingerprints.add(fingerprint)) {
        continue;
      }
      target.add(layer);
    }
  }

  static String _layerFingerprint(PostcardElementLayer layer) {
    return [
      layer.id,
      layer.normalizedType,
      layer.elementKey.trim(),
      layer.assetPath.trim(),
      layer.text?.trim() ?? '',
      layer.x.toString(),
      layer.y.toString(),
      layer.zIndex.toString(),
    ].join('|');
  }

  static dynamic _decodeDynamicJson(dynamic raw) {
    if (raw is! String) return raw;
    final text = raw.trim();
    if (text.isEmpty) return raw;

    try {
      return jsonDecode(text);
    } catch (_) {
      if (text.contains(r'\"')) {
        final unescaped = text.replaceAll(r'\"', '"').replaceAll(r'\\/', '/');
        try {
          return jsonDecode(unescaped);
        } catch (_) {}
      }
      return raw;
    }
  }

  static dynamic _decodeDynamicJsonDeep(dynamic raw) {
    dynamic current = raw;
    for (var i = 0; i < 3; i++) {
      final decoded = _decodeDynamicJson(current);
      if (decoded == current) {
        break;
      }
      current = decoded;
    }
    return current;
  }

  static bool _isRenderableLayer(PostcardElementLayer layer) {
    if (layer.isText) {
      return layer.normalizedText.trim().isNotEmpty;
    }

    if (layer.assetPath.trim().isNotEmpty) {
      return true;
    }

    if (layer.elementKey.trim().isNotEmpty) {
      return true;
    }

    return false;
  }

  static bool _looksLikeLayerMap(Map<String, dynamic> map) {
    bool hasAny(Iterable<String> keys) {
      for (final key in keys) {
        if (map.containsKey(key)) {
          return true;
        }
      }
      return false;
    }

    final hasAssetIdentity = hasAny(const <String>[
      'assetPath',
      'asset_path',
      'assetUrl',
      'asset_url',
      'elementPath',
      'element_path',
      'resourcePath',
      'resource_path',
      'materialPath',
      'material_path',
      'elementKey',
      'element_key',
      'elementCode',
      'element_code',
      'elementName',
      'materialKey',
      'material_key',
      'materialCode',
      'material_code',
    ]);
    if (hasAssetIdentity) {
      return true;
    }

    final hasLayerType = hasAny(const <String>[
      'type',
      'layerType',
      'layer_type',
      'elementType',
      'element_type',
    ]);

    final hasTransform = hasAny(const <String>[
      'x',
      'y',
      'left',
      'top',
      'positionX',
      'position_x',
      'positionY',
      'position_y',
      'scale',
      'rotation2d',
      'rotation_2d',
      'rotation',
      'angle',
      'zIndex',
      'z_index',
      'z',
      'is3dEnabled',
      'is_3d_enabled',
      'rotateX',
      'rotate_x',
      'rotateY',
      'rotate_y',
    ]);

    final hasTextIdentity = hasAny(const <String>[
      'text',
      'textContent',
      'text_content',
      'style',
      'box',
    ]);
    if (hasTextIdentity && (hasTransform || hasLayerType)) {
      return true;
    }

    if (hasLayerType && hasTransform) {
      return true;
    }

    return false;
  }

  static String? _readImageUrlCandidate(Map<String, dynamic> json) {
    return BackendApiClient.readString(json, _imageUrlKeys);
  }

  static String? _readImageKeyCandidate(Map<String, dynamic> json) {
    return BackendApiClient.readString(json, _imageKeyKeys);
  }

  static String _normalizeImageSource(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return '';
    if (_looksLikeApiEndpointValue(text)) return '';
    return text;
  }

  static bool _looksLikeApiEndpointValue(String source) {
    final text = source.trim();
    if (text.isEmpty) return false;

    String path;
    if (text.startsWith('/')) {
      path = text;
    } else {
      final uri = Uri.tryParse(text);
      if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
        return false;
      }
      path = uri.path;
    }

    final normalizedPath = path.trim().toLowerCase().replaceFirst(
      RegExp(r'/+$'),
      '',
    );
    if (normalizedPath.isEmpty) return false;
    if (_looksLikeImagePath(normalizedPath)) return false;
    if (normalizedPath.endsWith('/me/avatar')) return true;

    for (final prefix in const <String>[
      '/postcard/',
      '/discussion/',
      '/map/',
      '/oss/',
      '/me/',
      '/auth/',
      '/comment/',
      '/favorite/',
    ]) {
      if (normalizedPath.startsWith(prefix)) {
        return true;
      }
    }
    return false;
  }

  static bool _looksLikeImagePath(String path) {
    return RegExp(
      r'\.(jpg|jpeg|png|webp|gif|bmp|svg|avif)(\?.*)?$',
      caseSensitive: false,
    ).hasMatch(path);
  }

  static String _normalizeHotCommentText(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';

    final jsonLikeMap = _tryParseMapFromJsonText(text);
    if (jsonLikeMap != null) {
      final nested = BackendApiClient.readString(jsonLikeMap, const [
        'content',
        'commentContent',
        'text',
      ]);
      if (nested != null && nested.trim().isNotEmpty) {
        return nested.trim();
      }
    }

    final mapLikeField = _extractFieldFromMapLikeText(text, const [
      'content',
      'commentContent',
      'text',
    ]);
    if (mapLikeField != null && mapLikeField.isNotEmpty) {
      return mapLikeField;
    }

    return text;
  }

  static Map<String, dynamic>? _tryParseMapFromJsonText(String text) {
    if (!(text.startsWith('{') && text.endsWith('}'))) {
      return null;
    }

    try {
      final decoded = jsonDecode(text);
      return BackendApiClient.asMap(decoded);
    } catch (_) {
      return null;
    }
  }

  static String? _extractFieldFromMapLikeText(
    String raw,
    List<String> fieldNames,
  ) {
    if (!(raw.startsWith('{') && raw.endsWith('}'))) {
      return null;
    }

    for (final field in fieldNames) {
      final pattern = RegExp(
        '${RegExp.escape(field)}\\s*:\\s*(.+?)(?=,\\s*[A-Za-z_][A-Za-z0-9_]*\\s*:|\\s*\\}\$)',
        dotAll: true,
      );
      final match = pattern.firstMatch(raw);
      if (match == null) continue;

      final value = _stripWrappingQuotes((match.group(1) ?? '').trim());
      if (value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  static String _stripWrappingQuotes(String text) {
    if (text.length >= 2) {
      final first = text[0];
      final last = text[text.length - 1];
      final wrappedByDoubleQuote = first == '"' && last == '"';
      final wrappedBySingleQuote = first == '\'' && last == '\'';
      if (wrappedByDoubleQuote || wrappedBySingleQuote) {
        return text.substring(1, text.length - 1).trim();
      }
    }
    return text;
  }

  static String? _extractUsername(Map<String, dynamic> json) {
    final directNickname = BackendApiClient.readString(json, const [
      'nickname',
      'nickName',
      'userNickname',
      'displayName',
    ]);
    if (directNickname != null && directNickname.isNotEmpty) {
      return directNickname;
    }

    final directUsername = BackendApiClient.readString(json, const [
      'username',
      'userName',
    ]);
    if (directUsername != null &&
        directUsername.isNotEmpty &&
        !_looksLikePhone(directUsername)) {
      return directUsername;
    }

    final nestedUser = BackendApiClient.asMap(
      json['user'] ?? json['author'] ?? json['publisher'],
    );
    final nestedNickname = BackendApiClient.readString(nestedUser, const [
      'nickname',
      'nickName',
      'userNickname',
      'displayName',
    ]);
    if (nestedNickname != null && nestedNickname.isNotEmpty) {
      return nestedNickname;
    }

    final nestedUsername = BackendApiClient.readString(nestedUser, const [
      'username',
      'userName',
    ]);
    if (nestedUsername != null &&
        nestedUsername.isNotEmpty &&
        !_looksLikePhone(nestedUsername)) {
      return nestedUsername;
    }

    return null;
  }

  static bool _looksLikePhone(String value) {
    final digits = value.trim().replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length == 11;
  }

  static DateTime _parseDateTime(String raw) {
    if (raw.trim().isEmpty) {
      return DateTime.now();
    }

    DateTime? parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed;

    parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (parsed != null) return parsed;

    return DateTime.now();
  }
}

class DiscussionService {
  static const String _postsCacheKey = 'discussion_posts_cache_v1';
  static const String _localPostsKey = 'discussion_local_posts_v1';
  static const String _defaultHotComment = '分享一张明信片';
  static const String _postcardCreateEndpoint = '/postcard/create';

  DiscussionService({BackendApiClient? apiClient})
    : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;

  Future<void> publishPost({
    required String username,
    required String imageUrl,
    required String address,
    String hotComment = '',
    String? avatar,
    String? cityName,
    String? cityCode,
    String? provinceName,
    double? latitude,
    double? longitude,
    List<PostcardElementLayer> layers = const <PostcardElementLayer>[],
  }) async {
    final source = imageUrl.trim();
    if (source.isEmpty) {
      throw ArgumentError('图片地址不能为空');
    }

    final normalizedUsername = username.trim().isEmpty ? '我' : username.trim();
    final normalizedAddress = address.trim();
    final resolvedAddress = normalizedAddress.isEmpty
        ? '未知地点'
        : normalizedAddress;
    final normalizedCityName = cityName?.trim();
    final normalizedCityCode = cityCode?.trim();
    final normalizedProvinceName = provinceName?.trim();
    final normalizedCityCodeValue = _normalizeCityCodeValue(normalizedCityCode);
    final trimmedHotComment = hotComment.trim();
    final normalizedHotComment = trimmedHotComment.isEmpty
        ? _defaultHotComment
        : trimmedHotComment;
    final imageKey = _normalizeImageKeyCandidate(source);
    final elements = _buildElementPayload(layers);
    final title = normalizedCityName != null && normalizedCityName.isNotEmpty
        ? '$normalizedCityName 明信片'
        : (normalizedProvinceName != null && normalizedProvinceName.isNotEmpty
              ? '$normalizedProvinceName 明信片'
              : '我的明信片');

    final fullPayload = _compactPayload(<String, dynamic>{
      'title': title,
      'content': normalizedHotComment,
      'imageUrl': source,
      if (imageKey != null) 'imageKey': imageKey,
      'address': resolvedAddress,
      'cityName': normalizedCityName,
      'cityCode': normalizedCityCodeValue,
      'provinceName': normalizedProvinceName,
      'latitude': latitude,
      'longitude': longitude,
      if (elements.isNotEmpty) 'elements': elements,
    });

    final fullPayloadWithAliases = _compactPayload(<String, dynamic>{
      ...fullPayload,
      if (imageKey != null) 'key': imageKey,
      if (imageKey != null) 'objectKey': imageKey,
    });

    final corePayload = _compactPayload(<String, dynamic>{
      'title': title,
      'content': normalizedHotComment,
      'imageUrl': source,
      if (imageKey != null) 'imageKey': imageKey,
      'address': resolvedAddress,
      'cityCode': normalizedCityCodeValue,
      'cityName': normalizedCityName,
      'provinceName': normalizedProvinceName,
      if (elements.isNotEmpty) 'elements': elements,
    });

    final minimalPayload = _compactPayload(<String, dynamic>{
      if (imageKey != null) 'imageKey': imageKey,
      'imageUrl': source,
      'address': resolvedAddress,
      'cityCode': normalizedCityCodeValue,
      'content': normalizedHotComment,
      if (elements.isNotEmpty) 'elements': elements,
    });

    final attempts = <Map<String, dynamic>>[
      fullPayload,
      fullPayloadWithAliases,
      corePayload,
      minimalPayload,
    ];

    final triedPayloads = <String>{};
    BackendApiException? lastBackendError;
    for (final payload in attempts) {
      if (payload.isEmpty) continue;
      final fingerprint = jsonEncode(payload);
      if (!triedPayloads.add(fingerprint)) continue;

      try {
        await _apiClient.post(
          _postcardCreateEndpoint,
          body: payload,
          requireAuth: true,
        );
        return;
      } on BackendApiException catch (e) {
        lastBackendError = e;
        continue;
      } catch (_) {
        continue;
      }
    }

    if (elements.isNotEmpty) {
      throw lastBackendError ?? const BackendApiException('发布失败，请重试');
    }

    // Keep posting usable when backend publish API is unavailable.
    await publishLocalPost(
      username: normalizedUsername,
      avatar: avatar,
      imageUrl: source,
      address: resolvedAddress,
      hotComment: normalizedHotComment,
    );
  }

  List<Map<String, dynamic>> _buildElementPayload(
    List<PostcardElementLayer> layers,
  ) {
    if (layers.isEmpty) return const <Map<String, dynamic>>[];
    return layers
        .map((item) {
          final json = Map<String, dynamic>.from(item.toJson());
          // Keep the API field aligned with the current contract.
          if (item.isAsset) {
            json['type'] = 'asset';
          }
          return json;
        })
        .toList(growable: false);
  }

  Map<String, dynamic> _compactPayload(Map<String, dynamic> payload) {
    payload.removeWhere((key, value) {
      if (value == null) return true;
      if (value is String && value.trim().isEmpty) return true;
      if (value is List && value.isEmpty) return true;
      return false;
    });
    return payload;
  }

  dynamic _normalizeCityCodeValue(String? cityCode) {
    final text = cityCode?.trim() ?? '';
    if (text.isEmpty) return null;
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return int.tryParse(digits) ?? digits;
  }

  String? _normalizeImageKeyCandidate(String imageUrl) {
    final text = imageUrl.trim();
    if (text.isEmpty) return null;
    if (_looksLikeLocalPath(text) || text.startsWith('assets/')) {
      return null;
    }

    if (text.startsWith('http://') || text.startsWith('https://')) {
      final uri = Uri.tryParse(text);
      if (uri == null || uri.pathSegments.isEmpty) return null;
      final segments = uri.pathSegments
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
      if (segments.isEmpty) return null;
      return segments.join('/');
    }

    return text.replaceFirst(RegExp(r'^/+'), '');
  }

  bool _looksLikeLocalPath(String value) {
    if (value.startsWith('file://')) return true;
    if (RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(value)) return true;
    for (final prefix in const <String>[
      '/storage/',
      '/sdcard/',
      '/data/',
      '/var/',
      '/private/var/',
      '/tmp/',
      '/home/',
      '/Users/',
      '/mnt/',
      '/proc/',
      '/system/',
    ]) {
      if (value.startsWith(prefix)) return true;
    }
    return false;
  }

  Future<void> publishLocalPost({
    required String username,
    required String imageUrl,
    required String address,
    String hotComment = '',
    String? avatar,
  }) async {
    final source = imageUrl.trim();
    if (source.isEmpty) {
      throw ArgumentError('图片地址不能为空');
    }

    final avatarText = avatar?.trim();
    final normalizedAvatar = avatarText == null || avatarText.isEmpty
        ? null
        : avatarText;

    final now = DateTime.now();
    final post = DiscussionPost(
      id: now.microsecondsSinceEpoch,
      username: username.trim().isEmpty ? '我' : username.trim(),
      avatar: normalizedAvatar,
      imageUrl: source,
      createdAt: now,
      address: address.trim().isEmpty ? '未知地点' : address.trim(),
      likeCount: 0,
      commentCount: 0,
      hotComment: hotComment.trim(),
    );

    final localPosts = List<DiscussionPost>.from(await _readLocalPosts());
    localPosts.insert(0, post);
    await _saveLocalPosts(localPosts);
  }

  Future<DiscussionFetchResult> fetchPostsWithOfflineFallback({
    DateTime? lastTime,
  }) async {
    final localPosts = await _readLocalPosts();

    try {
      final onlinePosts = await _fetchPostsOnline(lastTime: lastTime);
      await _savePostsCache(onlinePosts);
      return DiscussionFetchResult(
        posts: _mergePosts(onlinePosts, localPosts),
        isOffline: false,
      );
    } on BackendApiException catch (e) {
      final cachedPosts = await _readPostsCache();
      if (cachedPosts.isNotEmpty) {
        return DiscussionFetchResult(
          posts: _mergePosts(cachedPosts, localPosts),
          isOffline: true,
          notice: e.isUnauthorized ? '登录状态已失效，已展示本地缓存内容' : '网络异常，已展示离线缓存内容',
        );
      }

      return DiscussionFetchResult(
        posts: _mergePosts(_buildOfflineSeedPosts(), localPosts),
        isOffline: true,
        notice: e.isUnauthorized ? '登录状态已失效，已展示本地离线内容' : '网络异常，已展示离线示例内容',
      );
    } catch (_) {
      final cachedPosts = await _readPostsCache();
      if (cachedPosts.isNotEmpty) {
        return DiscussionFetchResult(
          posts: _mergePosts(cachedPosts, localPosts),
          isOffline: true,
          notice: '网络异常，已展示离线缓存内容',
        );
      }

      return DiscussionFetchResult(
        posts: _mergePosts(_buildOfflineSeedPosts(), localPosts),
        isOffline: true,
        notice: '网络异常，已展示离线示例内容',
      );
    }
  }

  Future<List<DiscussionPost>> fetchPosts({DateTime? lastTime}) async {
    final result = await fetchPostsWithOfflineFallback(lastTime: lastTime);
    return result.posts;
  }

  Future<DiscussionPost> fetchPostDetail(int postId) async {
    if (postId <= 0) {
      throw ArgumentError('postId must be greater than 0');
    }

    final body = await _apiClient.get('/postcard/$postId', requireAuth: true);
    final candidates = _collectDetailCandidates(body);

    DiscussionPost? bestPost;
    var bestScore = -1;
    var bestLayerCount = -1;
    var bestHasImage = false;
    for (final candidate in candidates) {
      final parsed = DiscussionPost.fromJson(candidate);
      final score = _scoreDetailCandidate(parsed, candidate, postId: postId);
      final hasImage = parsed.imageUrl.trim().isNotEmpty;
      final shouldReplace =
          score > bestScore ||
          (score == bestScore &&
              (parsed.layers.length > bestLayerCount ||
                  (parsed.layers.length == bestLayerCount &&
                      hasImage &&
                      !bestHasImage)));
      if (shouldReplace) {
        bestScore = score;
        bestLayerCount = parsed.layers.length;
        bestHasImage = hasImage;
        bestPost = parsed;
      }
    }

    if (bestPost == null) {
      throw const BackendApiException('明信片详情解析失败');
    }

    return _withPostId(bestPost, postId);
  }

  DiscussionPost _withPostId(DiscussionPost post, int fallbackId) {
    if (post.id > 0) {
      return post;
    }

    return DiscussionPost(
      id: fallbackId,
      username: post.username,
      avatar: post.avatar,
      imageUrl: post.imageUrl,
      layers: post.layers,
      createdAt: post.createdAt,
      address: post.address,
      likeCount: post.likeCount,
      commentCount: post.commentCount,
      hotComment: post.hotComment,
    );
  }

  List<Map<String, dynamic>> _collectDetailCandidates(
    Map<String, dynamic> body,
  ) {
    final candidates = <Map<String, dynamic>>[];
    final fingerprints = <String>{};

    void addMapCandidate(Map<String, dynamic> map) {
      final fingerprint = _candidateFingerprint(map);
      if (!fingerprints.add(fingerprint)) {
        return;
      }
      candidates.add(map);
    }

    void collect(dynamic raw, {int depth = 0}) {
      if (raw == null || depth > 4) {
        return;
      }

      final decoded = _decodeJsonIfNeeded(raw);
      final map = BackendApiClient.asMap(decoded);
      if (map != null) {
        addMapCandidate(map);
        for (final key in const <String>[
          'data',
          'result',
          'record',
          'item',
          'postcard',
          'postcardInfo',
          'postcardDetail',
          'postcardDto',
          'card',
          'records',
          'list',
          'content',
        ]) {
          if (map.containsKey(key)) {
            collect(map[key], depth: depth + 1);
          }
        }
        return;
      }

      if (decoded is List) {
        final limit = decoded.length > 3 ? 3 : decoded.length;
        for (var i = 0; i < limit; i++) {
          collect(decoded[i], depth: depth + 1);
        }
      }
    }

    final roots = <dynamic>[
      body,
      BackendApiClient.extractData(body),
      body['data'],
      body['result'],
      body['record'],
      body['item'],
      body['postcard'],
      body['postcardInfo'],
      body['postcardDetail'],
      body['postcardDto'],
      body['card'],
      body['records'],
      body['list'],
      body['content'],
    ];
    for (final root in roots) {
      collect(root);
    }

    return candidates;
  }

  String _candidateFingerprint(Map<String, dynamic> map) {
    try {
      return jsonEncode(map);
    } catch (_) {
      return map.toString();
    }
  }

  dynamic _decodeJsonIfNeeded(dynamic raw) {
    if (raw is! String) {
      return raw;
    }

    dynamic current = raw.trim();
    if (current is! String || current.isEmpty) {
      return raw;
    }

    for (var i = 0; i < 3; i++) {
      if (current is! String) {
        break;
      }

      final text = current.trim();
      if (text.isEmpty) {
        return raw;
      }

      dynamic decoded;
      try {
        decoded = jsonDecode(text);
      } catch (_) {
        if (text.contains(r'\"')) {
          final unescaped = text.replaceAll(r'\"', '"').replaceAll(r'\\/', '/');
          try {
            decoded = jsonDecode(unescaped);
          } catch (_) {
            break;
          }
        } else {
          break;
        }
      }

      if (decoded == current) {
        break;
      }
      current = decoded;
    }

    return current;
  }

  int _scoreDetailCandidate(
    DiscussionPost post,
    Map<String, dynamic> raw, {
    required int postId,
  }) {
    var score = 0;
    if (post.id > 0) {
      score += 2;
    }
    if (post.id == postId) {
      score += 2;
    }
    if (post.imageUrl.trim().isNotEmpty) {
      score += 6;
    }
    if (post.layers.isNotEmpty) {
      score += 24;
    }
    if (post.username.trim().isNotEmpty) {
      score += 1;
    }
    if (post.address.trim().isNotEmpty) {
      score += 1;
    }

    final hasLayerHint =
        const <String>[
          'elements',
          'layers',
          'elementList',
          'layerList',
          'postcardElements',
          'postcardElementList',
        ].any(raw.containsKey) ||
        raw.keys.any((key) {
          final normalized = key.trim().toLowerCase();
          return normalized.contains('element') || normalized.contains('layer');
        });
    if (hasLayerHint) {
      score += 8;
    }

    return score;
  }

  Future<List<DiscussionPost>> _fetchPostsOnline({DateTime? lastTime}) async {
    final safeTime = lastTime ?? DateTime.now();
    final formatted = DateFormat('yyyy-MM-dd HH:mm:ss').format(safeTime);

    final body = await _apiClient.get(
      '/discussion/postcards',
      queryParameters: <String, String>{'lastTime': formatted},
      requireAuth: true,
    );

    final data = BackendApiClient.extractData(body);
    final records = BackendApiClient.extractList(data);

    final posts = <DiscussionPost>[];
    for (final item in records) {
      final map = BackendApiClient.asMap(item);
      if (map == null) continue;
      posts.add(DiscussionPost.fromJson(map));
    }

    posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return posts;
  }

  Future<void> _savePostsCache(List<DiscussionPost> posts) async {
    if (posts.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(posts.map((post) => post.toJson()).toList());
    await prefs.setString(_postsCacheKey, encoded);
  }

  Future<void> _saveLocalPosts(List<DiscussionPost> posts) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(posts.map((post) => post.toJson()).toList());
    await prefs.setString(_localPostsKey, encoded);
  }

  Future<List<DiscussionPost>> _readLocalPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localPostsKey);
    if (raw == null || raw.trim().isEmpty) {
      return <DiscussionPost>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      final posts = <DiscussionPost>[];
      for (final item in decoded) {
        final map = BackendApiClient.asMap(item);
        if (map == null) continue;
        posts.add(DiscussionPost.fromJson(map));
      }
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return posts;
    } catch (_) {
      return <DiscussionPost>[];
    }
  }

  List<DiscussionPost> _mergePosts(
    List<DiscussionPost> primary,
    List<DiscussionPost> secondary,
  ) {
    if (secondary.isEmpty) return primary;

    final merged = <DiscussionPost>[...primary];
    final existingIds = merged.map((item) => item.id).toSet();

    for (final post in secondary) {
      if (existingIds.contains(post.id)) continue;
      merged.add(post);
    }

    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  Future<List<DiscussionPost>> _readPostsCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_postsCacheKey);
    if (raw == null || raw.trim().isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      final posts = <DiscussionPost>[];
      for (final item in decoded) {
        final map = BackendApiClient.asMap(item);
        if (map == null) continue;
        posts.add(DiscussionPost.fromJson(map));
      }
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return posts;
    } catch (_) {
      return const [];
    }
  }

  List<DiscussionPost> _buildOfflineSeedPosts() {
    final now = DateTime.now();
    return <DiscussionPost>[
      DiscussionPost(
        id: 9001,
        username: '离线用户A',
        imageUrl: '',
        createdAt: now.subtract(const Duration(minutes: 20)),
        address: '北京',
        likeCount: 18,
        commentCount: 6,
        hotComment: '这张明信片氛围感很强',
      ),
      DiscussionPost(
        id: 9002,
        username: '离线用户B',
        imageUrl: '',
        createdAt: now.subtract(const Duration(hours: 2)),
        address: '上海',
        likeCount: 12,
        commentCount: 3,
        hotComment: '配色很舒服',
      ),
      DiscussionPost(
        id: 9003,
        username: '离线用户C',
        imageUrl: '',
        createdAt: now.subtract(const Duration(hours: 5)),
        address: '成都',
        likeCount: 9,
        commentCount: 2,
        hotComment: '',
      ),
    ];
  }
}

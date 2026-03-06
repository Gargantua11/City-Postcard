import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_oss_aliyun/flutter_oss_aliyun.dart';

import 'backend_api_client.dart';

class AvatarUploadService {
  static const String _configuredOssEndpoint = String.fromEnvironment(
    'OSS_ENDPOINT',
  );
  static const String _configuredOssBucketName = String.fromEnvironment(
    'OSS_BUCKET_NAME',
  );

  AvatarUploadService({BackendApiClient? apiClient})
    : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;

  static String? _cachedOssEndpoint;
  static String? _cachedBucketName;
  static final Map<String, _CachedSignedUrl> _signedGetUrlCache =
      <String, _CachedSignedUrl>{};

  static bool isRenderableImageSource(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return false;
    if (_looksLikeAvatarApiEndpointValue(trimmed)) return false;
    if (_looksLikeAssetOrLocal(trimmed)) return true;
    if (_looksLikeRelativeApiPath(trimmed)) return true;
    return _isHttpSource(trimmed);
  }

  static bool isLikelyAvatarApiEndpoint(String source) {
    return _looksLikeAvatarApiEndpointValue(source.trim());
  }

  Future<String> uploadAvatarAndSync(String filePath) async {
    final normalizedPath = filePath.trim();
    if (normalizedPath.isEmpty) {
      throw const BackendApiException('avatar file path cannot be empty');
    }

    final file = File(normalizedPath);
    if (!file.existsSync()) {
      throw const BackendApiException('avatar file does not exist');
    }

    return _uploadAvatarViaOssDirect(file);
  }

  Future<String> _uploadAvatarViaOssDirect(File file) async {
    final objectKey = _normalizeObjectKeyWithHints(
      await _requestAvatarObjectKey(file),
    );
    final context = await _resolveOssUploadContext();
    _initClient(endpoint: context.endpoint, bucketName: context.bucketName);

    try {
      // Do not force object ACL here. Some STS policies allow PutObject but
      // forbid setting x-oss-object-acl, which causes 403 on upload.
      await Client().putObjectFile(file, fileKey: objectKey);
    } catch (error) {
      throw BackendApiException(_buildOssUploadFailureMessage(error));
    }

    final updateBody = await _syncAvatarKeyToBackend(objectKey);

    final updatedAvatar = _extractAvatarSource(updateBody);
    if (updatedAvatar != null && updatedAvatar.isNotEmpty) {
      return normalizeAvatarStorageSource(
        updatedAvatar,
        endpoint: context.endpoint,
        bucketName: context.bucketName,
      );
    }

    return normalizeAvatarStorageSource(
      objectKey,
      endpoint: context.endpoint,
      bucketName: context.bucketName,
    );
  }

  String _buildOssUploadFailureMessage(Object error) {
    final text = error.toString();
    if (text.contains('Http status error [403]') ||
        text.toLowerCase().contains('status error [403]')) {
      return 'oss upload forbidden (403): check sts policy for PutObject.';
    }
    if (text.contains('Http status error [401]') ||
        text.toLowerCase().contains('status error [401]')) {
      return 'oss sts token expired or invalid (401).';
    }
    if (text.toLowerCase().contains('socket') ||
        text.toLowerCase().contains('timed out') ||
        text.toLowerCase().contains('network')) {
      return 'oss upload network error.';
    }
    return 'oss upload failed.';
  }

  Future<Map<String, dynamic>> _syncAvatarKeyToBackend(String objectKey) async {
    final bodies = <Map<String, dynamic>>[
      <String, dynamic>{'key': objectKey},
      <String, dynamic>{'avatar': objectKey},
      <String, dynamic>{'avatarKey': objectKey},
      <String, dynamic>{'objectKey': objectKey},
      <String, dynamic>{'fileKey': objectKey},
      <String, dynamic>{'path': objectKey},
      <String, dynamic>{'url': objectKey},
      <String, dynamic>{'avatarUrl': objectKey},
    ];

    BackendApiException? backendError;
    for (final body in bodies) {
      try {
        return await _apiClient.put(
          '/me/avatar',
          body: body,
          requireAuth: true,
        );
      } on BackendApiException catch (e) {
        backendError = e;
      }
    }

    if (backendError != null) throw backendError;
    throw const BackendApiException('cannot sync avatar key to backend');
  }

  Future<String> resolveAvatarDisplaySource(
    String source, {
    bool preferSignedUrl = true,
    int signedUrlExpireSeconds = 3600,
  }) async {
    final rawSource = source.trim();
    if (rawSource.isEmpty) return '';
    if (_looksLikeAvatarApiEndpointValue(rawSource)) return '';
    if (_looksLikeRelativeApiPath(rawSource)) {
      return _toAbsoluteApiUrl(rawSource);
    }
    if (_looksLikeAssetOrLocal(rawSource) || _isHttpSource(rawSource)) {
      return rawSource;
    }

    final normalizedStorageSource = normalizeAvatarStorageSource(rawSource);
    if (normalizedStorageSource.isEmpty) return '';

    _OssUploadContext? context;
    try {
      context = await _resolveOssUploadContext();
      _initClient(endpoint: context.endpoint, bucketName: context.bucketName);

      if (preferSignedUrl) {
        final signedUrl = await _buildSignedGetUrlWithStsV1(
          source: normalizedStorageSource,
          endpoint: context.endpoint,
          bucketName: context.bucketName,
          expireSeconds: signedUrlExpireSeconds,
        );
        if (signedUrl.isNotEmpty) {
          return signedUrl;
        }

        try {
          final signedByPlugin = await Client().getSignedUrl(
            normalizedStorageSource,
            expireSeconds: signedUrlExpireSeconds,
          );
          final text = signedByPlugin.trim();
          if (text.isNotEmpty) return text;
        } catch (_) {}
      }

      return normalizeAvatarSource(
        normalizedStorageSource,
        endpoint: context.endpoint,
        bucketName: context.bucketName,
      );
    } catch (_) {
      return normalizeAvatarSource(
        normalizedStorageSource,
        endpoint: context?.endpoint,
        bucketName: context?.bucketName,
      );
    }
  }

  static String normalizeAvatarStorageSource(
    String source, {
    String? endpoint,
    String? bucketName,
  }) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return '';
    if (_looksLikeAvatarApiEndpointValue(trimmed)) return '';
    if (_looksLikeRelativeApiPath(trimmed)) return trimmed;
    if (_looksLikeAssetOrLocal(trimmed)) return trimmed;

    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
      final host = _normalizeEndpointHost(uri.host);
      final inferredContext = _inferOssContextFromHost(host);
      if (inferredContext != null) {
        _cachedOssEndpoint = inferredContext.endpoint;
        _cachedBucketName = inferredContext.bucketName;
      }

      final normalizedEndpoint = _normalizeEndpointHost(
        _firstNonEmpty(<String?>[
          endpoint,
          _cachedOssEndpoint,
          _configuredOssEndpoint,
        ]),
      );
      final normalizedBucket = _firstNonEmpty(<String?>[
        bucketName,
        _cachedBucketName,
        _configuredOssBucketName,
      ]).trim();
      final keyFromUrl = _extractObjectKeyFromUriPath(
        uri,
        bucketName: normalizedBucket.isEmpty
            ? inferredContext?.bucketName
            : normalizedBucket,
      );

      final canNormalizeToObjectKey =
          keyFromUrl.isNotEmpty &&
          (inferredContext != null ||
              (normalizedEndpoint.isNotEmpty && normalizedBucket.isNotEmpty));
      if (_looksLikeSignedUrl(uri)) {
        return canNormalizeToObjectKey ? keyFromUrl : trimmed;
      }

      final hostMatchesBucket =
          normalizedBucket.isNotEmpty &&
          (host == normalizedBucket || host.startsWith('$normalizedBucket.'));
      final hostMatchesEndpoint =
          normalizedEndpoint.isNotEmpty &&
          (host == normalizedEndpoint || host.endsWith('.$normalizedEndpoint'));

      if (keyFromUrl.isNotEmpty &&
          (hostMatchesBucket ||
              hostMatchesEndpoint ||
              inferredContext != null)) {
        return keyFromUrl;
      }
      return trimmed;
    }

    return trimmed.replaceFirst(RegExp(r'^/+'), '');
  }

  static String normalizeAvatarSource(
    String source, {
    String? endpoint,
    String? bucketName,
  }) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return '';
    if (_looksLikeAvatarApiEndpointValue(trimmed)) return '';

    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
      return trimmed;
    }
    if (_looksLikeRelativeApiPath(trimmed)) {
      return _toAbsoluteApiUrl(trimmed);
    }
    if (_looksLikeAssetOrLocal(trimmed)) {
      return trimmed;
    }

    final normalizedKey = trimmed.replaceFirst(RegExp(r'^/+'), '');
    final normalizedEndpoint = _normalizeEndpointHost(
      _firstNonEmpty(<String?>[
        endpoint,
        _cachedOssEndpoint,
        _configuredOssEndpoint,
      ]),
    );
    final normalizedBucket = _firstNonEmpty(<String?>[
      bucketName,
      _cachedBucketName,
      _configuredOssBucketName,
    ]).trim();
    if (normalizedEndpoint.isEmpty || normalizedBucket.isEmpty) {
      return '';
    }
    return 'https://$normalizedBucket.$normalizedEndpoint/$normalizedKey';
  }

  Future<String> _requestAvatarObjectKey(File file) async {
    final extension = _readFileExtension(file.path);
    final fileSize = file.lengthSync();

    final bodies = <Map<String, dynamic>?>[
      if (extension != null)
        <String, dynamic>{'ext': extension, 'size': fileSize},
      <String, dynamic>{'size': fileSize},
      if (extension != null) <String, dynamic>{'ext': extension},
      null,
    ];
    final queryCandidates = <Map<String, String>>[
      if (extension != null)
        <String, String>{'ext': extension, 'size': '$fileSize'},
      <String, String>{'size': '$fileSize'},
      if (extension != null) <String, String>{'ext': extension},
    ];

    BackendApiException? backendError;
    for (final body in bodies) {
      try {
        final response = await _apiClient.post(
          '/me/avatar/key',
          body: body,
          requireAuth: true,
        );
        final key = _extractObjectKey(response);
        if (key != null && key.isNotEmpty) {
          return key;
        }
      } on BackendApiException catch (e) {
        backendError = e;
      }
    }

    for (final query in queryCandidates) {
      try {
        final response = await _apiClient.get(
          '/me/avatar/key',
          queryParameters: query,
          requireAuth: true,
        );
        final key = _extractObjectKey(response);
        if (key != null && key.isNotEmpty) {
          return key;
        }
      } on BackendApiException catch (e) {
        backendError = e;
      }
    }

    if (backendError != null) throw backendError;
    throw const BackendApiException('cannot get avatar object key');
  }

  Future<_OssUploadContext> _resolveOssUploadContext() async {
    final cachedEndpoint = _cachedOssEndpoint?.trim() ?? '';
    final cachedBucket = _cachedBucketName?.trim() ?? '';
    if (cachedEndpoint.isNotEmpty && cachedBucket.isNotEmpty) {
      return _OssUploadContext(
        endpoint: cachedEndpoint,
        bucketName: cachedBucket,
      );
    }

    final stsBody = await _requestOssSts();
    final endpointFromSts = _readDeepString(stsBody, const <String>[
      'ossEndpoint',
      'endpoint',
      'ossHost',
      'host',
      'domain',
    ]);
    final bucketFromSts = _readDeepString(stsBody, const <String>[
      'bucketName',
      'bucket',
      'ossBucketName',
      'bucket_name',
    ]);

    final configuredEndpoint = _configuredOssEndpoint.trim();
    final configuredBucket = _configuredOssBucketName.trim();

    var endpoint = _normalizeEndpointHost(
      endpointFromSts?.trim().isNotEmpty == true
          ? endpointFromSts!
          : configuredEndpoint,
    );
    var bucketName =
        (bucketFromSts?.trim().isNotEmpty == true
                ? bucketFromSts!
                : configuredBucket)
            .trim();

    if (bucketName.isEmpty && endpoint.contains('.oss-')) {
      bucketName = endpoint.split('.').first;
    }
    if (bucketName.isNotEmpty && endpoint.startsWith('$bucketName.')) {
      endpoint = endpoint.substring(bucketName.length + 1);
    }

    if (endpoint.isEmpty || bucketName.isEmpty) {
      throw const BackendApiException(
        'missing oss endpoint or bucketName from /oss/sts response',
      );
    }

    _cachedOssEndpoint = endpoint;
    _cachedBucketName = bucketName;
    return _OssUploadContext(endpoint: endpoint, bucketName: bucketName);
  }

  void _initClient({required String endpoint, required String bucketName}) {
    Client.init(
      ossEndpoint: endpoint,
      bucketName: bucketName,
      tokenGetter: _fetchStsTokenJson,
    );
  }

  Future<String> _fetchStsTokenJson() async {
    final stsBody = await _requestOssSts();
    final tokenMap = _extractStsToken(stsBody);
    return jsonEncode(tokenMap);
  }

  Future<String> _buildSignedGetUrlWithStsV1({
    required String source,
    required String endpoint,
    required String bucketName,
    required int expireSeconds,
  }) async {
    final objectKey = _normalizeObjectKeyForSigning(
      source,
      bucketName: bucketName,
      endpoint: endpoint,
    );
    if (objectKey.isEmpty) return '';

    final cacheKey = _buildSignedUrlCacheKey(
      endpoint: endpoint,
      bucketName: bucketName,
      objectKey: objectKey,
    );
    final nowEpochSeconds =
        DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final cached = _signedGetUrlCache[cacheKey];
    if (cached != null && cached.expiresEpochSeconds > nowEpochSeconds + 30) {
      return cached.url;
    }

    try {
      final stsBody = await _requestOssSts();
      final credential = _extractStsCredential(stsBody);
      final expires = _buildSignedUrlExpires(expireSeconds);
      final stringToSignRawToken = _buildStringToSignForGet(
        bucketName: bucketName,
        objectKey: objectKey,
        expires: expires,
        securityToken: credential.securityToken,
      );
      final signatureRawToken = _signStsString(
        stringToSignRawToken,
        accessKeySecret: credential.accessKeySecret,
      );

      final uri =
          Uri.https('$bucketName.$endpoint', '/$objectKey', <String, String>{
            'OSSAccessKeyId': credential.accessKeyId,
            'Expires': '$expires',
            'Signature': signatureRawToken,
            'security-token': credential.securityToken,
          });
      final signedUrl = uri.toString();
      _signedGetUrlCache[cacheKey] = _CachedSignedUrl(
        url: signedUrl,
        expiresEpochSeconds: expires,
      );
      return signedUrl;
    } catch (_) {
      return '';
    }
  }

  String _buildSignedUrlCacheKey({
    required String endpoint,
    required String bucketName,
    required String objectKey,
  }) {
    final normalizedEndpoint = endpoint.trim().toLowerCase();
    final normalizedBucket = bucketName.trim().toLowerCase();
    final normalizedObjectKey = objectKey.trim();
    return '$normalizedBucket@$normalizedEndpoint/$normalizedObjectKey';
  }

  _OssStsCredential _extractStsCredential(Map<String, dynamic> body) {
    final tokenMap = _extractStsToken(body);
    final accessKeyId = tokenMap['AccessKeyId']?.toString().trim() ?? '';
    final accessKeySecret =
        tokenMap['AccessKeySecret']?.toString().trim() ?? '';
    final securityToken = tokenMap['SecurityToken']?.toString().trim() ?? '';
    if (accessKeyId.isEmpty ||
        accessKeySecret.isEmpty ||
        securityToken.isEmpty) {
      throw const BackendApiException('invalid /oss/sts response');
    }
    return _OssStsCredential(
      accessKeyId: accessKeyId,
      accessKeySecret: accessKeySecret,
      securityToken: securityToken,
    );
  }

  int _buildSignedUrlExpires(int expireSeconds) {
    final normalized = expireSeconds <= 0
        ? 3600
        : (expireSeconds > 7 * 24 * 3600 ? 7 * 24 * 3600 : expireSeconds);
    final nowSeconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    return nowSeconds + normalized;
  }

  String _buildStringToSignForGet({
    required String bucketName,
    required String objectKey,
    required int expires,
    required String securityToken,
  }) {
    return 'GET\n\n\n$expires\n/$bucketName/$objectKey?security-token=$securityToken';
  }

  String _signStsString(
    String stringToSign, {
    required String accessKeySecret,
  }) {
    final hmac = Hmac(sha1, utf8.encode(accessKeySecret));
    final digest = hmac.convert(utf8.encode(stringToSign));
    return base64Encode(digest.bytes);
  }

  String _normalizeObjectKeyForSigning(
    String source, {
    required String bucketName,
    required String endpoint,
  }) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return '';

    final normalized = normalizeAvatarStorageSource(
      trimmed,
      endpoint: endpoint,
      bucketName: bucketName,
    ).trim();
    if (normalized.isEmpty) return '';
    if (_looksLikeRelativeApiPath(normalized) ||
        _looksLikeAssetOrLocal(normalized)) {
      return '';
    }

    final normalizedUri = Uri.tryParse(normalized);
    if (normalizedUri != null &&
        (normalizedUri.isScheme('http') || normalizedUri.isScheme('https'))) {
      return _extractObjectKeyFromUriPath(
        normalizedUri,
        bucketName: bucketName,
      ).replaceFirst(RegExp(r'^/+'), '');
    }

    return normalized.replaceFirst(RegExp(r'^/+'), '');
  }

  Future<Map<String, dynamic>> _requestOssSts() async {
    BackendApiException? backendError;
    for (final request in <Future<Map<String, dynamic>> Function()>[
      () => _apiClient.post('/oss/sts', requireAuth: true),
      () => _apiClient.get('/oss/sts', requireAuth: true),
      () => _apiClient.post('/oss/sts/token', requireAuth: true),
      () => _apiClient.get('/oss/sts/token', requireAuth: true),
    ]) {
      try {
        return await request();
      } on BackendApiException catch (e) {
        backendError = e;
      }
    }

    if (backendError != null) throw backendError;
    throw const BackendApiException('cannot get sts credentials');
  }

  Map<String, dynamic> _extractStsToken(Map<String, dynamic> body) {
    final accessKeyId = _readDeepString(body, const <String>[
      'AccessKeyId',
      'accessKeyId',
      'accessKey',
    ]);
    final accessKeySecret = _readDeepString(body, const <String>[
      'AccessKeySecret',
      'accessKeySecret',
      'accessSecret',
    ]);
    final securityToken = _readDeepString(body, const <String>[
      'SecurityToken',
      'securityToken',
      'security_token',
      'stsToken',
    ]);
    final expirationValue = _readDeepValue(body, const <String>[
      'Expiration',
      'expiration',
      'expireAt',
      'expiresAt',
      'expiredTime',
    ]);

    final expiration = _normalizeExpiration(expirationValue);
    if (accessKeyId == null ||
        accessKeySecret == null ||
        securityToken == null ||
        expiration == null) {
      throw const BackendApiException('invalid /oss/sts response');
    }

    return <String, dynamic>{
      'AccessKeyId': accessKeyId,
      'AccessKeySecret': accessKeySecret,
      'SecurityToken': securityToken,
      'Expiration': expiration,
    };
  }

  static bool _looksLikeAssetOrLocal(String source) {
    if (source.startsWith('assets/')) return true;
    if (source.startsWith('file://')) return true;
    final windowsPath = RegExp(r'^[a-zA-Z]:[\\/]');
    if (windowsPath.hasMatch(source)) return true;

    return _looksLikeUnixLocalPath(source);
  }

  static bool _looksLikeUnixLocalPath(String source) {
    if (!source.startsWith('/')) return false;
    final localPrefixes = const <String>[
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
    ];
    for (final prefix in localPrefixes) {
      if (source.startsWith(prefix)) {
        return true;
      }
    }
    return false;
  }

  static bool _looksLikeRelativeApiPath(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return false;
    if (!trimmed.startsWith('/')) return false;
    if (trimmed.startsWith('//')) return false;
    return !_looksLikeUnixLocalPath(trimmed);
  }

  static bool _looksLikeAvatarApiEndpointValue(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return false;

    if (_looksLikeRelativeApiPath(trimmed)) {
      final normalized = trimmed.replaceFirst(RegExp(r'/+$'), '');
      return normalized.endsWith('/me/avatar');
    }

    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
      final normalizedPath = uri.path.trim().replaceFirst(RegExp(r'/+$'), '');
      if (normalizedPath.isEmpty) return false;
      return normalizedPath.endsWith('/me/avatar');
    }

    return false;
  }

  static String _toAbsoluteApiUrl(String relativePath) {
    final base = BackendApiClient.baseUrl.trim().replaceFirst(
      RegExp(r'/+$'),
      '',
    );
    final path = relativePath.trim();
    if (base.isEmpty) return path;
    return '$base$path';
  }

  static bool _isHttpSource(String source) {
    final uri = Uri.tryParse(source);
    return uri != null && (uri.isScheme('http') || uri.isScheme('https'));
  }

  static bool _looksLikeSignedUrl(Uri uri) {
    if (uri.queryParameters.isEmpty) return false;

    final keys = uri.queryParameters.keys
        .map((item) => item.trim().toLowerCase())
        .toSet();

    for (final signatureKey in const <String>[
      'x-oss-signature',
      'x-oss-credential',
      'x-oss-security-token',
      'x-oss-date',
      'x-oss-expires',
      'ossaccesskeyid',
      'signature',
      'expires',
      'security-token',
      'token',
    ]) {
      if (keys.contains(signatureKey)) {
        return true;
      }
    }

    return false;
  }

  static String _normalizeEndpointHost(String raw) {
    var endpoint = raw.trim();
    if (endpoint.isEmpty) return '';

    final uri = Uri.tryParse(endpoint);
    if (uri != null &&
        (uri.isScheme('http') || uri.isScheme('https')) &&
        uri.host.trim().isNotEmpty) {
      endpoint = uri.host.trim();
    } else {
      endpoint = endpoint
          .replaceFirst(RegExp(r'^https?://', caseSensitive: false), '')
          .split('/')
          .first
          .trim();
    }

    return endpoint
        .replaceFirst(RegExp(r'^/+'), '')
        .replaceFirst(RegExp(r'/+$'), '');
  }

  String? _extractObjectKey(Map<String, dynamic> body) {
    final data = BackendApiClient.extractData(body);
    if (data is String || data is num) {
      final text = data.toString().trim();
      if (text.isNotEmpty && !_looksLikeAvatarApiEndpointValue(text)) {
        return text.replaceFirst(RegExp(r'^/+'), '');
      }
    }

    final raw = _readDeepValue(body, const <String>[
      'key',
      'objectKey',
      'fileKey',
      'path',
      'value',
      'avatarKey',
    ]);
    if (raw == null) return null;

    final text = raw.toString().trim();
    if (text.isEmpty || _looksLikeAvatarApiEndpointValue(text)) return null;
    return text.replaceFirst(RegExp(r'^/+'), '');
  }

  String? _extractAvatarSource(Map<String, dynamic> body) {
    final data = BackendApiClient.extractData(body);
    if (data is String || data is num) {
      final text = data.toString().trim();
      if (text.isNotEmpty && !_looksLikeAvatarApiEndpointValue(text)) {
        return text;
      }
    }

    final raw = _readDeepValue(body, const <String>[
      'avatarUrl',
      'url',
      'avatar',
      'avatarKey',
      'value',
      'key',
      'objectKey',
      'fileKey',
    ]);
    if (raw == null) return null;

    final text = raw.toString().trim();
    if (text.isEmpty || _looksLikeAvatarApiEndpointValue(text)) return null;
    return text;
  }

  String? _normalizeExpiration(dynamic raw) {
    if (raw == null) return null;

    if (raw is num) {
      final millis = raw > 1000000000000 ? raw.toInt() : raw.toInt() * 1000;
      return DateTime.fromMillisecondsSinceEpoch(
        millis,
        isUtc: true,
      ).toIso8601String();
    }

    final text = raw.toString().trim();
    if (text.isEmpty) return null;

    final directParsed = DateTime.tryParse(text);
    if (directParsed != null) {
      return directParsed.toUtc().toIso8601String();
    }

    final numberValue = int.tryParse(text);
    if (numberValue != null) {
      final millis = numberValue > 1000000000000
          ? numberValue
          : numberValue * 1000;
      return DateTime.fromMillisecondsSinceEpoch(
        millis,
        isUtc: true,
      ).toIso8601String();
    }

    return null;
  }

  dynamic _readDeepValue(dynamic raw, List<String> keys) {
    final normalizedKeys = keys
        .map((item) => item.toLowerCase())
        .toList(growable: false);

    dynamic visit(dynamic node) {
      if (node == null) return null;

      final map = BackendApiClient.asMap(node);
      if (map != null) {
        for (final key in normalizedKeys) {
          for (final entry in map.entries) {
            if (entry.key.toLowerCase() == key) {
              return entry.value;
            }
          }
        }
        for (final value in map.values) {
          final candidate = visit(value);
          if (candidate != null) return candidate;
        }
      }

      if (node is List) {
        for (final value in node) {
          final candidate = visit(value);
          if (candidate != null) return candidate;
        }
      }

      return null;
    }

    return visit(raw);
  }

  String? _readDeepString(dynamic raw, List<String> keys) {
    final value = _readDeepValue(raw, keys);
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return text;
  }

  String? _readFileExtension(String path) {
    final filename = path.split(Platform.pathSeparator).last.trim();
    final dotIndex = filename.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == filename.length - 1) {
      return null;
    }
    final extension = filename.substring(dotIndex + 1).trim();
    if (extension.isEmpty) return null;
    return extension.toLowerCase();
  }

  String _normalizeObjectKeyWithHints(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';

    final uri = Uri.tryParse(text);
    if (uri != null &&
        (uri.isScheme('http') || uri.isScheme('https')) &&
        uri.host.trim().isNotEmpty) {
      final inferred = _inferOssContextFromHost(uri.host.trim());
      if (inferred != null) {
        _cachedOssEndpoint = inferred.endpoint;
        _cachedBucketName = inferred.bucketName;
      }

      final keyFromPath = _extractObjectKeyFromUriPath(
        uri,
        bucketName: inferred?.bucketName,
      );
      if (keyFromPath.isNotEmpty) {
        return keyFromPath;
      }
    }

    return text.replaceFirst(RegExp(r'^/+'), '');
  }

  static String _firstNonEmpty(Iterable<String?> candidates) {
    for (final candidate in candidates) {
      final text = candidate?.trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static _OssUploadContext? _inferOssContextFromHost(String hostText) {
    final host = _normalizeEndpointHost(hostText);
    if (host.isEmpty) return null;

    var bucketName = '';
    var endpoint = '';
    final parts = host.split('.');
    if (parts.length >= 3 && parts[1].startsWith('oss-')) {
      bucketName = parts.first;
      endpoint = parts.sublist(1).join('.');
    } else if (host.contains('.oss-')) {
      bucketName = host.split('.').first;
      endpoint = host.substring(bucketName.length + 1);
    }

    if (bucketName.isEmpty || endpoint.isEmpty) {
      return null;
    }
    return _OssUploadContext(endpoint: endpoint, bucketName: bucketName);
  }

  static String _extractObjectKeyFromUriPath(Uri uri, {String? bucketName}) {
    final segments = uri.pathSegments
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (segments.isEmpty) return '';

    final normalizedBucket = bucketName?.trim() ?? '';
    if (normalizedBucket.isNotEmpty &&
        segments.length > 1 &&
        segments.first.toLowerCase() == normalizedBucket.toLowerCase()) {
      return segments.skip(1).join('/');
    }
    return segments.join('/');
  }
}

class _OssUploadContext {
  const _OssUploadContext({required this.endpoint, required this.bucketName});

  final String endpoint;
  final String bucketName;
}

class _OssStsCredential {
  const _OssStsCredential({
    required this.accessKeyId,
    required this.accessKeySecret,
    required this.securityToken,
  });

  final String accessKeyId;
  final String accessKeySecret;
  final String securityToken;
}

class _CachedSignedUrl {
  const _CachedSignedUrl({
    required this.url,
    required this.expiresEpochSeconds,
  });

  final String url;
  final int expiresEpochSeconds;
}

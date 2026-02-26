import 'dart:convert';
import 'dart:io';

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

  String? _ossEndpoint;
  String? _bucketName;

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

    await Client().putObjectFile(
      file,
      fileKey: objectKey,
      option: const PutRequestOption(aclModel: AclMode.publicRead),
    );

    final updateBody = await _syncAvatarKeyToBackend(objectKey);

    final updatedAvatar = _extractAvatarSource(updateBody);
    if (updatedAvatar != null && updatedAvatar.isNotEmpty) {
      return normalizeAvatarStorageSource(
        updatedAvatar,
        endpoint: context.endpoint,
        bucketName: context.bucketName,
      );
    }

    try {
      final avatarBody = await _apiClient.get('/me/avatar', requireAuth: true);
      final avatarFromGet = _extractAvatarSource(avatarBody);
      if (avatarFromGet != null && avatarFromGet.isNotEmpty) {
        return normalizeAvatarStorageSource(
          avatarFromGet,
          endpoint: context.endpoint,
          bucketName: context.bucketName,
        );
      }
    } catch (_) {}

    return normalizeAvatarStorageSource(
      objectKey,
      endpoint: context.endpoint,
      bucketName: context.bucketName,
    );
  }

  Future<Map<String, dynamic>> _syncAvatarKeyToBackend(String objectKey) async {
    final bodies = <Map<String, dynamic>>[
      <String, dynamic>{'key': objectKey},
      <String, dynamic>{'avatar': objectKey},
      <String, dynamic>{'avatarKey': objectKey},
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
    final normalizedStorageSource = normalizeAvatarStorageSource(source);
    if (normalizedStorageSource.isEmpty) return '';
    if (_looksLikeAssetOrLocal(normalizedStorageSource) ||
        _isHttpSource(normalizedStorageSource)) {
      return normalizedStorageSource;
    }

    try {
      final context = await _resolveOssUploadContext();
      _initClient(endpoint: context.endpoint, bucketName: context.bucketName);

      if (preferSignedUrl) {
        try {
          final signedUrl = await Client().getSignedUrl(
            normalizedStorageSource,
            expireSeconds: signedUrlExpireSeconds,
          );
          final text = signedUrl.trim();
          if (text.isNotEmpty) return text;
        } catch (_) {}
      }

      return normalizeAvatarSource(
        normalizedStorageSource,
        endpoint: context.endpoint,
        bucketName: context.bucketName,
      );
    } catch (_) {
      return normalizeAvatarSource(normalizedStorageSource);
    }
  }

  static String normalizeAvatarStorageSource(
    String source, {
    String? endpoint,
    String? bucketName,
  }) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return '';
    if (_looksLikeAssetOrLocal(trimmed)) return trimmed;

    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
      final normalizedEndpoint = _normalizeEndpointHost(
        endpoint ?? _configuredOssEndpoint,
      );
      final normalizedBucket = (bucketName ?? _configuredOssBucketName).trim();
      final host = _normalizeEndpointHost(uri.host);
      final keyFromUrl = uri.path.replaceFirst(RegExp(r'^/+'), '');

      final hostMatchesBucket =
          normalizedBucket.isNotEmpty &&
          (host == normalizedBucket || host.startsWith('$normalizedBucket.'));
      final hostMatchesEndpoint =
          normalizedEndpoint.isNotEmpty &&
          (host == normalizedEndpoint || host.endsWith('.$normalizedEndpoint'));
      final looksLikeOssHost = host.contains('.oss-') || host.contains('-oss-');

      if (keyFromUrl.isNotEmpty &&
          (hostMatchesBucket || hostMatchesEndpoint || looksLikeOssHost)) {
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

    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
      return trimmed;
    }
    if (_looksLikeAssetOrLocal(trimmed)) {
      return trimmed;
    }

    final normalizedKey = trimmed.replaceFirst(RegExp(r'^/+'), '');
    final normalizedEndpoint = _normalizeEndpointHost(
      endpoint ?? _configuredOssEndpoint,
    );
    final normalizedBucket = (bucketName ?? _configuredOssBucketName).trim();
    if (normalizedEndpoint.isEmpty || normalizedBucket.isEmpty) {
      return normalizedKey;
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
    final cachedEndpoint = _ossEndpoint?.trim() ?? '';
    final cachedBucket = _bucketName?.trim() ?? '';
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

    _ossEndpoint = endpoint;
    _bucketName = bucketName;
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
    if (source.startsWith('/')) return true;
    final windowsPath = RegExp(r'^[a-zA-Z]:[\\/]');
    return windowsPath.hasMatch(source);
  }

  static bool _isHttpSource(String source) {
    final uri = Uri.tryParse(source);
    return uri != null && (uri.isScheme('http') || uri.isScheme('https'));
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
      if (text.isNotEmpty) {
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
    if (text.isEmpty) return null;
    return text.replaceFirst(RegExp(r'^/+'), '');
  }

  String? _extractAvatarSource(Map<String, dynamic> body) {
    final data = BackendApiClient.extractData(body);
    if (data is String || data is num) {
      final text = data.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }

    final raw = _readDeepValue(body, const <String>[
      'url',
      'avatar',
      'avatarUrl',
      'value',
      'key',
      'objectKey',
      'fileKey',
    ]);
    if (raw == null) return null;

    final text = raw.toString().trim();
    if (text.isEmpty) return null;
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
    final normalizedKeys = keys.map((item) => item.toLowerCase()).toSet();

    dynamic visit(dynamic node) {
      if (node == null) return null;

      final map = BackendApiClient.asMap(node);
      if (map != null) {
        for (final entry in map.entries) {
          if (normalizedKeys.contains(entry.key.toLowerCase())) {
            return entry.value;
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
      final host = _normalizeEndpointHost(uri.host.trim());
      var bucket = '';
      var endpoint = host;

      final parts = host.split('.');
      if (parts.length >= 3 && parts[1].startsWith('oss-')) {
        bucket = parts.first;
        endpoint = parts.sublist(1).join('.');
      } else if (host.contains('.oss-')) {
        bucket = host.split('.').first;
        endpoint = host.substring(bucket.length + 1);
      }

      if (bucket.isNotEmpty && endpoint.isNotEmpty) {
        _bucketName ??= bucket;
        _ossEndpoint ??= endpoint;
      }

      final keyFromPath = uri.path.replaceFirst(RegExp(r'^/+'), '');
      if (keyFromPath.isNotEmpty) {
        return keyFromPath;
      }
    }

    return text.replaceFirst(RegExp(r'^/+'), '');
  }
}

class _OssUploadContext {
  const _OssUploadContext({required this.endpoint, required this.bucketName});

  final String endpoint;
  final String bucketName;
}

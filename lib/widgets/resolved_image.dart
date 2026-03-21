import 'package:flutter/material.dart';

import '../services/avatar_upload_service.dart';
import '../services/backend_api_client.dart';
import '../services/storage_service.dart';
import 'local_file_image_provider_stub.dart'
    if (dart.library.io) 'local_file_image_provider_io.dart';

class ResolvedImage extends StatefulWidget {
  const ResolvedImage({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.filterQuality = FilterQuality.high,
    this.fallbackBuilder,
    this.loadingBuilder,
  });

  final String source;
  final BoxFit fit;
  final FilterQuality filterQuality;
  final WidgetBuilder? fallbackBuilder;
  final WidgetBuilder? loadingBuilder;

  @override
  State<ResolvedImage> createState() => _ResolvedImageState();
}

class _ResolvedImageState extends State<ResolvedImage> {
  final AvatarUploadService _avatarUploadService = AvatarUploadService();
  final StorageService _storageService = StorageService();

  late Future<_ResolvedImagePayload> _payloadFuture;

  @override
  void initState() {
    super.initState();
    _payloadFuture = _resolvePayload(widget.source);
  }

  @override
  void didUpdateWidget(covariant ResolvedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source.trim() != widget.source.trim()) {
      _payloadFuture = _resolvePayload(widget.source);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ResolvedImagePayload>(
      future: _payloadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildLoading(context);
        }

        final payload = snapshot.data;
        if (payload == null || payload.source.isEmpty) {
          return _buildFallback(context);
        }

        if (payload.sourceType == _ImageSourceType.asset) {
          return Image.asset(
            payload.source,
            fit: widget.fit,
            filterQuality: widget.filterQuality,
            errorBuilder: (_, _, _) => _buildFallback(context),
          );
        }

        if (payload.sourceType == _ImageSourceType.network) {
          return Image.network(
            payload.source,
            fit: widget.fit,
            filterQuality: widget.filterQuality,
            headers: payload.headers,
            errorBuilder: (_, error, stackTrace) {
              debugPrint(
                'ResolvedImage network load failed. '
                'raw="${widget.source}" resolved="${payload.source}" '
                'headers=${payload.headers?.keys.toList()} error=$error',
              );
              return _buildFallback(context);
            },
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return _buildLoading(context);
            },
          );
        }

        final provider = buildLocalFileImageProvider(payload.source);
        if (provider == null) {
          return _buildFallback(context);
        }
        return Image(
          image: provider,
          fit: widget.fit,
          filterQuality: widget.filterQuality,
          errorBuilder: (_, error, stackTrace) {
            debugPrint(
              'ResolvedImage local load failed. '
              'raw="${widget.source}" local="${payload.source}" error=$error',
            );
            return _buildFallback(context);
          },
        );
      },
    );
  }

  Future<_ResolvedImagePayload> _resolvePayload(String rawSource) async {
    final source = rawSource.trim();
    if (source.isEmpty) {
      return const _ResolvedImagePayload.empty();
    }

    if (_isAssetSource(source)) {
      return _ResolvedImagePayload.asset(source);
    }

    final localPath = _resolveLocalPath(source);
    if (localPath != null) {
      return _ResolvedImagePayload.local(localPath);
    }

    if (_isHttpSource(source)) {
      final signedOrOriginal = await _resolveSignedOssIfNeeded(source);
      return _ResolvedImagePayload.network(
        signedOrOriginal,
        headers: await _resolveAuthHeadersIfNeeded(signedOrOriginal),
      );
    }

    if (_looksLikeRelativeHttpPath(source)) {
      final absolute = _toAbsoluteApiUrl(source);
      return _ResolvedImagePayload.network(
        absolute,
        headers: await _resolveAuthHeadersIfNeeded(absolute),
      );
    }

    final resolvedByOss = await _resolveViaOssOrAvatar(source);
    if (_isHttpSource(resolvedByOss)) {
      return _ResolvedImagePayload.network(
        resolvedByOss,
        headers: await _resolveAuthHeadersIfNeeded(resolvedByOss),
      );
    }
    if (_looksLikeRelativeHttpPath(resolvedByOss)) {
      final absolute = _toAbsoluteApiUrl(resolvedByOss);
      return _ResolvedImagePayload.network(
        absolute,
        headers: await _resolveAuthHeadersIfNeeded(absolute),
      );
    }
    if (_looksLikeRelativeResourceKey(resolvedByOss)) {
      final relativePath = _toRelativeResourcePath(resolvedByOss);
      final absolute = _toAbsoluteApiUrl(relativePath);
      return _ResolvedImagePayload.network(
        absolute,
        headers: await _resolveAuthHeadersIfNeeded(absolute),
      );
    }
    if (_looksLikeRelativeResourceKey(source)) {
      final relativePath = _toRelativeResourcePath(source);
      final absolute = _toAbsoluteApiUrl(relativePath);
      return _ResolvedImagePayload.network(
        absolute,
        headers: await _resolveAuthHeadersIfNeeded(absolute),
      );
    }

    return const _ResolvedImagePayload.empty();
  }

  Future<String> _resolveSignedOssIfNeeded(String source) async {
    final text = source.trim();
    final uri = Uri.tryParse(text);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return text;
    }
    if (!_looksLikeOssHost(uri.host) || _looksLikeSignedUrl(uri)) {
      return text;
    }

    final resolved = await _resolveViaOssOrAvatar(text);
    if (_isHttpSource(resolved.trim())) {
      return resolved.trim();
    }
    return text;
  }

  Future<String> _resolveViaOssOrAvatar(String source) async {
    final storageSource = AvatarUploadService.normalizeAvatarStorageSource(
      source,
    );
    final sourceForResolve = storageSource.trim().isEmpty
        ? source
        : storageSource;

    try {
      final resolved = await _avatarUploadService.resolveAvatarDisplaySource(
        sourceForResolve,
        preferSignedUrl: true,
      );
      final normalized = resolved.trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    } catch (_) {}

    final fallback = AvatarUploadService.normalizeAvatarSource(source);
    if (fallback.trim().isNotEmpty) {
      return fallback.trim();
    }
    return source;
  }

  Future<Map<String, String>?> _resolveAuthHeadersIfNeeded(
    String source,
  ) async {
    if (!_isBackendApiUrl(source)) {
      return null;
    }
    final token = await _storageService.getToken();
    final normalizedToken = token?.trim() ?? '';
    if (normalizedToken.isEmpty) {
      return null;
    }
    return <String, String>{'Authorization': 'Bearer $normalizedToken'};
  }

  bool _isBackendApiUrl(String source) {
    final uri = Uri.tryParse(source.trim());
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return false;
    }

    final baseUri = Uri.tryParse(BackendApiClient.baseUrl.trim());
    if (baseUri == null || baseUri.host.trim().isEmpty) {
      return false;
    }
    return uri.host.toLowerCase() == baseUri.host.toLowerCase();
  }

  static bool _looksLikeOssHost(String host) {
    final normalizedHost = host.trim().toLowerCase();
    if (normalizedHost.isEmpty) return false;
    return normalizedHost.contains('.oss-');
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

  Widget _buildFallback(BuildContext context) {
    final builder = widget.fallbackBuilder;
    if (builder != null) {
      return builder(context);
    }
    return const SizedBox.shrink();
  }

  Widget _buildLoading(BuildContext context) {
    final builder = widget.loadingBuilder;
    if (builder != null) {
      return builder(context);
    }
    return _buildFallback(context);
  }

  static bool _isAssetSource(String source) {
    return source.startsWith('assets/');
  }

  static bool _isHttpSource(String source) {
    final uri = Uri.tryParse(source.trim());
    return uri != null && (uri.isScheme('http') || uri.isScheme('https'));
  }

  static String? _resolveLocalPath(String source) {
    if (source.startsWith('file://')) {
      final fileUri = Uri.tryParse(source);
      if (fileUri == null || !fileUri.isScheme('file')) return null;
      try {
        return fileUri.toFilePath();
      } catch (_) {
        return null;
      }
    }

    final windowsPath = RegExp(r'^[a-zA-Z]:[\\/]');
    if (windowsPath.hasMatch(source) || _looksLikeUnixLocalPath(source)) {
      return source;
    }
    return null;
  }

  static bool _looksLikeRelativeHttpPath(String source) {
    if (!source.startsWith('/')) return false;
    if (source.startsWith('//')) return false;
    return !_looksLikeUnixLocalPath(source);
  }

  static bool _looksLikeRelativeResourceKey(String source) {
    final text = source.trim();
    if (text.isEmpty) return false;
    if (text.startsWith('/')) return false;
    if (_isHttpSource(text) || _isAssetSource(text)) return false;
    if (_resolveLocalPath(text) != null) return false;

    final normalized = text.replaceAll('\\', '/');
    final likelyImagePath =
        normalized.contains('/') && _looksLikeImagePath(normalized);
    if (likelyImagePath) {
      return true;
    }

    if (normalized.startsWith('postcards/') ||
        normalized.startsWith('uploads/') ||
        normalized.startsWith('images/')) {
      return true;
    }
    return false;
  }

  static bool _looksLikeImagePath(String source) {
    return RegExp(
      r'\.(jpg|jpeg|png|webp|gif|bmp|svg|avif)(\?.*)?$',
      caseSensitive: false,
    ).hasMatch(source);
  }

  static String _toRelativeResourcePath(String source) {
    final normalized = source
        .trim()
        .replaceAll('\\', '/')
        .replaceFirst(RegExp(r'^/+'), '');
    return '/$normalized';
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

  static String _toAbsoluteApiUrl(String relativePath) {
    final base = BackendApiClient.baseUrl.trim().replaceFirst(
      RegExp(r'/+$'),
      '',
    );
    final path = relativePath.trim();
    if (base.isEmpty) return path;
    return '$base$path';
  }
}

enum _ImageSourceType { asset, network, local }

class _ResolvedImagePayload {
  const _ResolvedImagePayload._(this.sourceType, this.source, {this.headers});

  const _ResolvedImagePayload.empty() : this._(_ImageSourceType.local, '');

  factory _ResolvedImagePayload.asset(String source) {
    return _ResolvedImagePayload._(_ImageSourceType.asset, source);
  }

  factory _ResolvedImagePayload.network(
    String source, {
    Map<String, String>? headers,
  }) {
    return _ResolvedImagePayload._(
      _ImageSourceType.network,
      source,
      headers: headers,
    );
  }

  factory _ResolvedImagePayload.local(String source) {
    return _ResolvedImagePayload._(_ImageSourceType.local, source);
  }

  final _ImageSourceType sourceType;
  final String source;
  final Map<String, String>? headers;
}

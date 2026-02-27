import 'package:flutter/material.dart';

import '../services/backend_api_client.dart';
import 'local_file_image_provider_stub.dart'
    if (dart.library.io) 'local_file_image_provider_io.dart';

class ResolvedImage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final normalizedSource = source.trim();
    if (normalizedSource.isEmpty) {
      return _buildFallback(context);
    }

    if (_isAssetSource(normalizedSource)) {
      return Image.asset(
        normalizedSource,
        fit: fit,
        filterQuality: filterQuality,
        errorBuilder: (_, _, _) => _buildFallback(context),
      );
    }

    final uri = Uri.tryParse(normalizedSource);
    if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
      return Image.network(
        normalizedSource,
        fit: fit,
        filterQuality: filterQuality,
        errorBuilder: (_, _, _) => _buildFallback(context),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _buildLoading(context);
        },
      );
    }

    if (_looksLikeRelativeHttpPath(normalizedSource)) {
      final absoluteSource = _toAbsoluteApiUrl(normalizedSource);
      return Image.network(
        absoluteSource,
        fit: fit,
        filterQuality: filterQuality,
        errorBuilder: (_, _, _) => _buildFallback(context),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _buildLoading(context);
        },
      );
    }

    final localPath = _resolveLocalPath(normalizedSource);
    if (localPath == null) {
      return _buildFallback(context);
    }

    final provider = buildLocalFileImageProvider(localPath);
    if (provider == null) {
      return _buildFallback(context);
    }

    return Image(
      image: provider,
      fit: fit,
      filterQuality: filterQuality,
      errorBuilder: (_, _, _) => _buildFallback(context),
    );
  }

  Widget _buildFallback(BuildContext context) {
    final builder = fallbackBuilder;
    if (builder != null) {
      return builder(context);
    }
    return const SizedBox.shrink();
  }

  Widget _buildLoading(BuildContext context) {
    final builder = loadingBuilder;
    if (builder != null) {
      return builder(context);
    }
    return _buildFallback(context);
  }

  static bool _isAssetSource(String source) {
    return source.startsWith('assets/');
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
    final normalized = source.trim().replaceFirst(RegExp(r'/+$'), '');
    if (normalized.endsWith('/me/avatar')) return false;
    return !_looksLikeUnixLocalPath(source);
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

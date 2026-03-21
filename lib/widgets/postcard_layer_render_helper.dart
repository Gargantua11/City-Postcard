import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/postcard_element_layer.dart';
import 'resolved_image.dart';

Size measurePostcardLayerSize(
  PostcardElementLayer layer, {
  required double previewWidth,
  required double previewHeight,
}) {
  if (layer.isAsset) {
    final rawScale = layer.scale <= 0 ? 1.0 : layer.scale;
    final itemSize = (previewWidth * 0.22 * rawScale).clamp(
      20.0,
      previewWidth * 0.45,
    );
    return Size(itemSize.toDouble(), itemSize.toDouble());
  }

  return _measureTextLayerSize(
    layer,
    previewWidth: previewWidth,
    previewHeight: previewHeight,
  );
}

Offset resolvePostcardLayerOffset(
  PostcardElementLayer layer, {
  required double previewWidth,
  required double previewHeight,
}) {
  if (_looksLikeNormalizedPosition(layer)) {
    final normalizedX = layer.x.clamp(0.0, 1.0);
    final normalizedY = layer.y.clamp(0.0, 1.0);
    final dx = (normalizedX - 0.5) * previewWidth;
    final dy = (normalizedY - 0.5) * previewHeight;
    return Offset(dx, dy);
  }

  final useFallbackOffset = layer.x == 0 && layer.y == 0;
  if (!useFallbackOffset) {
    return Offset(layer.x, layer.y);
  }

  final fallbackX = ((layer.zIndex % 4) - 1.5) * (previewWidth * 0.16);
  final fallbackY = (((layer.zIndex ~/ 4) % 3) - 1.0) * (previewHeight * 0.14);
  return Offset(fallbackX, fallbackY);
}

bool _looksLikeNormalizedPosition(PostcardElementLayer layer) {
  final x = layer.x;
  final y = layer.y;
  final isZero = x.abs() < 0.0001 && y.abs() < 0.0001;
  if (isZero) return false;
  final xInRange = x >= -0.05 && x <= 1.05;
  final yInRange = y >= -0.05 && y <= 1.05;
  return xInRange && yInRange;
}

Widget buildPostcardLayerVisual(
  PostcardElementLayer layer, {
  required double previewWidth,
  required double previewHeight,
  bool silentAssetError = false,
}) {
  if (layer.isText) {
    return _buildTextLayerVisual(
      layer,
      previewWidth: previewWidth,
      previewHeight: previewHeight,
    );
  }

  final candidates = _buildAssetSourceCandidates(layer);
  if (candidates.isEmpty) {
    return silentAssetError
        ? const SizedBox.shrink()
        : _buildAssetLoadFailure();
  }
  return _buildAssetVisualWithFallback(
    candidates,
    index: 0,
    silentAssetError: silentAssetError,
  );
}

List<String> _buildAssetSourceCandidates(PostcardElementLayer layer) {
  final candidates = <String>[];
  final seen = <String>{};

  void add(String raw) {
    final source = raw.trim();
    if (source.isEmpty) return;
    if (!seen.add(source)) return;
    candidates.add(source);
  }

  add(layer.assetPath);

  final key = layer.elementKey.trim();
  if (key.isEmpty) return candidates;

  final normalizedKey = key.replaceAll('\\', '/');
  final isPathLike = normalizedKey.contains('/') || normalizedKey.contains('.');
  if (isPathLike) {
    add(normalizedKey);
    return candidates;
  }

  add('assets/images/add_elements/$normalizedKey.png');
  add('postcards/elements/$normalizedKey.png');
  return candidates;
}

Widget _buildAssetVisualWithFallback(
  List<String> candidates, {
  required int index,
  required bool silentAssetError,
}) {
  if (index >= candidates.length) {
    return silentAssetError
        ? const SizedBox.shrink()
        : _buildAssetLoadFailure();
  }

  return ResolvedImage(
    source: candidates[index],
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
    fallbackBuilder: (_) => _buildAssetVisualWithFallback(
      candidates,
      index: index + 1,
      silentAssetError: silentAssetError,
    ),
    loadingBuilder: (_) => const SizedBox.shrink(),
  );
}

Widget _buildAssetLoadFailure() {
  return Container(
    decoration: BoxDecoration(
      color: const Color(0xFFE5E5E5),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFC8C8C8)),
    ),
    alignment: Alignment.center,
    child: const Icon(Icons.image_not_supported, size: 18),
  );
}

String resolveLayerLabel(PostcardElementLayer layer) {
  if (layer.isText) {
    final text = layer.text?.trim() ?? '';
    if (text.isEmpty) return 'text';
    if (text.length <= 8) return text;
    return '${text.substring(0, 8)}...';
  }

  final key = layer.elementKey.trim();
  if (key.isNotEmpty) return key;
  final path = layer.assetPath.trim();
  if (path.isEmpty) return 'asset';
  var filename = path;
  final slash = filename.lastIndexOf('/');
  if (slash >= 0 && slash + 1 < filename.length) {
    filename = filename.substring(slash + 1);
  }
  final dot = filename.lastIndexOf('.');
  if (dot > 0) filename = filename.substring(0, dot);
  return filename.isEmpty ? 'asset' : filename;
}

Size _measureTextLayerSize(
  PostcardElementLayer layer, {
  required double previewWidth,
  required double previewHeight,
}) {
  final style = layer.resolvedStyle;
  final box = layer.resolvedBox;
  final rawScale = layer.scale <= 0 ? 1.0 : layer.scale;
  final fontSize = (style.fontSize * rawScale).clamp(10.0, 72.0).toDouble();
  final maxWidth = ((box.maxWidth ?? previewWidth * 0.7) * rawScale).clamp(
    60.0,
    previewWidth * 0.95,
  );
  final padding = (box.padding * rawScale).clamp(0.0, 32.0).toDouble();

  final textStyle = TextStyle(
    fontFamily: style.fontFamily.trim().isEmpty ? null : style.fontFamily,
    fontSize: fontSize,
    fontWeight: _parseFontWeight(style.fontWeight),
    fontStyle: _parseFontStyle(style.fontStyle),
    color: parseFlexibleColor(style.color, Colors.white),
    height: style.lineHeight > 0 ? style.lineHeight : 1.2,
    letterSpacing: style.letterSpacing * rawScale,
  );
  final text = layer.normalizedText;

  final painter = TextPainter(
    text: TextSpan(text: text, style: textStyle),
    textAlign: _parseTextAlign(style.align),
    textDirection: TextDirection.ltr,
    maxLines: 6,
    ellipsis: '...',
  );
  painter.layout(maxWidth: math.max(1, maxWidth - padding * 2));

  final width = (painter.width + padding * 2).clamp(40.0, maxWidth).toDouble();
  final minHeight = fontSize + padding * 2;
  final maxHeight = previewHeight * 0.82;
  final height = (painter.height + padding * 2).clamp(minHeight, maxHeight);
  return Size(width, height.toDouble());
}

Widget _buildTextLayerVisual(
  PostcardElementLayer layer, {
  required double previewWidth,
  required double previewHeight,
}) {
  final style = layer.resolvedStyle;
  final box = layer.resolvedBox;
  final size = _measureTextLayerSize(
    layer,
    previewWidth: previewWidth,
    previewHeight: previewHeight,
  );
  final rawScale = layer.scale <= 0 ? 1.0 : layer.scale;
  final padding = (box.padding * rawScale).clamp(0.0, 32.0).toDouble();

  return Container(
    width: size.width,
    height: size.height,
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: parseFlexibleColor(
        box.backgroundColor,
        const Color.fromRGBO(0, 0, 0, 0.25),
      ),
      borderRadius: BorderRadius.circular(
        (box.borderRadius * rawScale).clamp(0.0, 48.0).toDouble(),
      ),
    ),
    child: Align(
      alignment: _parseTextAlign(style.align) == TextAlign.left
          ? Alignment.centerLeft
          : (_parseTextAlign(style.align) == TextAlign.right
                ? Alignment.centerRight
                : Alignment.center),
      child: Text(
        layer.normalizedText,
        maxLines: 6,
        overflow: TextOverflow.ellipsis,
        textAlign: _parseTextAlign(style.align),
        style: TextStyle(
          fontFamily: style.fontFamily.trim().isEmpty ? null : style.fontFamily,
          fontSize: (style.fontSize * rawScale).clamp(10.0, 72.0).toDouble(),
          fontWeight: _parseFontWeight(style.fontWeight),
          fontStyle: _parseFontStyle(style.fontStyle),
          color: parseFlexibleColor(style.color, Colors.white),
          height: style.lineHeight > 0 ? style.lineHeight : 1.2,
          letterSpacing: style.letterSpacing * rawScale,
        ),
      ),
    ),
  );
}

TextAlign _parseTextAlign(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'left':
      return TextAlign.left;
    case 'right':
      return TextAlign.right;
    case 'justify':
      return TextAlign.justify;
    default:
      return TextAlign.center;
  }
}

FontWeight _parseFontWeight(String? raw) {
  final text = raw?.trim().toLowerCase() ?? '';
  if (text == 'normal') return FontWeight.w400;
  if (text == 'bold') return FontWeight.w700;

  final number = int.tryParse(text);
  switch (number) {
    case 100:
      return FontWeight.w100;
    case 200:
      return FontWeight.w200;
    case 300:
      return FontWeight.w300;
    case 400:
      return FontWeight.w400;
    case 500:
      return FontWeight.w500;
    case 600:
      return FontWeight.w600;
    case 700:
      return FontWeight.w700;
    case 800:
      return FontWeight.w800;
    case 900:
      return FontWeight.w900;
    default:
      return FontWeight.w600;
  }
}

FontStyle _parseFontStyle(String? raw) {
  final text = raw?.trim().toLowerCase() ?? '';
  if (text == 'italic') return FontStyle.italic;
  return FontStyle.normal;
}

Color parseFlexibleColor(String? raw, Color fallback) {
  final text = raw?.trim() ?? '';
  if (text.isEmpty) return fallback;

  if (text.startsWith('#')) {
    final hex = text.substring(1);
    if (hex.length == 3) {
      final expanded = hex.split('').map((c) => '$c$c').join();
      final value = int.tryParse('FF$expanded', radix: 16);
      if (value != null) return Color(value);
    } else if (hex.length == 6) {
      final value = int.tryParse('FF$hex', radix: 16);
      if (value != null) return Color(value);
    } else if (hex.length == 8) {
      final value = int.tryParse(hex, radix: 16);
      if (value != null) return Color(value);
    }
  }

  final rgbaMatch = RegExp(
    r'^rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*(?:,\s*([\d.]+)\s*)?\)$',
    caseSensitive: false,
  ).firstMatch(text);
  if (rgbaMatch != null) {
    final r = double.tryParse(rgbaMatch.group(1) ?? '');
    final g = double.tryParse(rgbaMatch.group(2) ?? '');
    final b = double.tryParse(rgbaMatch.group(3) ?? '');
    final alphaRaw = double.tryParse(rgbaMatch.group(4) ?? '');
    if (r != null && g != null && b != null) {
      final alpha = alphaRaw == null
          ? 1.0
          : (alphaRaw > 1 ? alphaRaw / 255 : alphaRaw);
      return Color.fromRGBO(
        r.clamp(0, 255).round(),
        g.clamp(0, 255).round(),
        b.clamp(0, 255).round(),
        alpha.clamp(0.0, 1.0),
      );
    }
  }

  return fallback;
}

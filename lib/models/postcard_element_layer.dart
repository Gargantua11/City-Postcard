import 'dart:convert';

class PostcardTextLayerStyle {
  final String fontFamily;
  final double fontSize;
  final String fontWeight;
  final String fontStyle;
  final String color;
  final String align;
  final double lineHeight;
  final double letterSpacing;

  const PostcardTextLayerStyle({
    this.fontFamily = 'PingFang SC',
    this.fontSize = 24,
    this.fontWeight = '600',
    this.fontStyle = 'normal',
    this.color = '#FFFFFF',
    this.align = 'center',
    this.lineHeight = 1.5,
    this.letterSpacing = 1,
  });

  PostcardTextLayerStyle copyWith({
    String? fontFamily,
    double? fontSize,
    String? fontWeight,
    String? fontStyle,
    String? color,
    String? align,
    double? lineHeight,
    double? letterSpacing,
  }) {
    return PostcardTextLayerStyle(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      fontStyle: _normalizeFontStyle(fontStyle ?? this.fontStyle),
      color: color ?? this.color,
      align: _normalizeTextAlign(align ?? this.align),
      lineHeight: lineHeight ?? this.lineHeight,
      letterSpacing: letterSpacing ?? this.letterSpacing,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'fontWeight': fontWeight,
      'fontStyle': fontStyle,
      'color': color,
      'align': align,
      'lineHeight': lineHeight,
      'letterSpacing': letterSpacing,
    };
  }

  factory PostcardTextLayerStyle.fromJson(Map<String, dynamic> json) {
    return PostcardTextLayerStyle(
      fontFamily:
          _toTrimmedString(json['fontFamily']) ??
          _toTrimmedString(json['font']) ??
          'PingFang SC',
      fontSize: _toDouble(json['fontSize']) ?? 24,
      fontWeight:
          _toTrimmedString(json['fontWeight']) ??
          _toTrimmedString(json['weight']) ??
          '600',
      fontStyle: _normalizeFontStyle(
        _toTrimmedString(json['fontStyle']) ??
            _toTrimmedString(json['style']) ??
            (_toBool(json['italic']) == true ? 'italic' : null),
      ),
      color: _toTrimmedString(json['color']) ?? '#FFFFFF',
      align: _normalizeTextAlign(json['align']),
      lineHeight: _toDouble(json['lineHeight']) ?? 1.5,
      letterSpacing: _toDouble(json['letterSpacing']) ?? 1,
    );
  }
}

class PostcardTextLayerBox {
  final double? maxWidth;
  final double padding;
  final String? backgroundColor;
  final double borderRadius;

  const PostcardTextLayerBox({
    this.maxWidth = 300,
    this.padding = 10,
    this.backgroundColor = 'rgba(0,0,0,0.25)',
    this.borderRadius = 8,
  });

  PostcardTextLayerBox copyWith({
    double? maxWidth,
    bool clearMaxWidth = false,
    double? padding,
    String? backgroundColor,
    bool clearBackgroundColor = false,
    double? borderRadius,
  }) {
    return PostcardTextLayerBox(
      maxWidth: clearMaxWidth ? null : (maxWidth ?? this.maxWidth),
      padding: padding ?? this.padding,
      backgroundColor: clearBackgroundColor
          ? null
          : (backgroundColor ?? this.backgroundColor),
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (maxWidth != null) 'maxWidth': maxWidth,
      'padding': padding,
      if (backgroundColor != null && backgroundColor!.trim().isNotEmpty)
        'backgroundColor': backgroundColor!.trim(),
      'borderRadius': borderRadius,
    };
  }

  factory PostcardTextLayerBox.fromJson(Map<String, dynamic> json) {
    return PostcardTextLayerBox(
      maxWidth: _toDouble(json['maxWidth']),
      padding: _toDouble(json['padding']) ?? 10,
      backgroundColor:
          _toTrimmedString(json['backgroundColor']) ??
          _toTrimmedString(json['bgColor']) ??
          'rgba(0,0,0,0.25)',
      borderRadius: _toDouble(json['borderRadius']) ?? 8,
    );
  }
}

class PostcardElementLayer {
  final String id;
  final String type;
  final String elementKey;
  final String assetPath;
  final String? text;
  final PostcardTextLayerStyle? style;
  final PostcardTextLayerBox? box;
  final double x;
  final double y;
  final double scale;
  final double rotation2d;
  final int zIndex;
  final bool is3dEnabled;
  final double rotateX;
  final double rotateY;
  final double rotationSpeed;
  final String rotationAxis;
  final String rotationDirection;
  final double perspective;
  final String? speedLevel;

  const PostcardElementLayer({
    required this.id,
    this.type = 'asset',
    this.elementKey = '',
    this.assetPath = '',
    this.text,
    this.style,
    this.box,
    this.x = 0,
    this.y = 0,
    this.scale = 1,
    this.rotation2d = 0,
    this.zIndex = 0,
    this.is3dEnabled = false,
    this.rotateX = 0,
    this.rotateY = 0,
    this.rotationSpeed = 1,
    this.rotationAxis = 'vertical',
    this.rotationDirection = 'clockwise',
    this.perspective = 0.001,
    this.speedLevel,
  });

  bool get isText => _normalizeLayerType(type) == 'text';

  bool get isAsset => !isText;

  String get normalizedType => _normalizeLayerType(type);

  String get normalizedText {
    final value = text?.trim() ?? '';
    if (value.isNotEmpty) return value;
    return 'Text';
  }

  PostcardTextLayerStyle get resolvedStyle {
    return style ?? const PostcardTextLayerStyle();
  }

  PostcardTextLayerBox get resolvedBox {
    return box ?? const PostcardTextLayerBox();
  }

  PostcardElementLayer copyWith({
    String? id,
    String? type,
    String? elementKey,
    String? assetPath,
    String? text,
    PostcardTextLayerStyle? style,
    PostcardTextLayerBox? box,
    double? x,
    double? y,
    double? scale,
    double? rotation2d,
    int? zIndex,
    bool? is3dEnabled,
    double? rotateX,
    double? rotateY,
    double? rotationSpeed,
    String? rotationAxis,
    String? rotationDirection,
    double? perspective,
    String? speedLevel,
    bool clearSpeedLevel = false,
    bool clearText = false,
    bool clearStyle = false,
    bool clearBox = false,
  }) {
    final nextType = _normalizeLayerType(type ?? this.type);
    return PostcardElementLayer(
      id: id ?? this.id,
      type: nextType,
      elementKey: elementKey ?? this.elementKey,
      assetPath: assetPath ?? this.assetPath,
      text: clearText ? null : (text ?? this.text),
      style: clearStyle ? null : (style ?? this.style),
      box: clearBox ? null : (box ?? this.box),
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation2d: rotation2d ?? this.rotation2d,
      zIndex: zIndex ?? this.zIndex,
      is3dEnabled: nextType == 'text'
          ? false
          : (is3dEnabled ?? this.is3dEnabled),
      rotateX: rotateX ?? this.rotateX,
      rotateY: rotateY ?? this.rotateY,
      rotationSpeed: rotationSpeed ?? this.rotationSpeed,
      rotationAxis: _normalizeAxis(rotationAxis ?? this.rotationAxis),
      rotationDirection: _normalizeDirection(
        rotationDirection ?? this.rotationDirection,
      ),
      perspective: perspective ?? this.perspective,
      speedLevel: clearSpeedLevel ? null : (speedLevel ?? this.speedLevel),
    );
  }

  Map<String, dynamic> toJson() {
    final layerType = normalizedType;
    final textValue = text?.trim() ?? '';
    return {
      'id': id,
      'type': layerType,
      if (elementKey.trim().isNotEmpty) 'elementKey': elementKey.trim(),
      if (assetPath.trim().isNotEmpty) 'assetPath': assetPath.trim(),
      if (textValue.isNotEmpty) 'text': textValue,
      'x': x,
      'y': y,
      'scale': scale,
      'rotation2d': rotation2d,
      'zIndex': zIndex,
      if (layerType == 'asset') 'is3dEnabled': is3dEnabled,
      if (layerType == 'asset') 'rotateX': rotateX,
      if (layerType == 'asset') 'rotateY': rotateY,
      if (layerType == 'asset') 'rotationSpeed': rotationSpeed,
      if (layerType == 'asset') 'rotationAxis': rotationAxis,
      if (layerType == 'asset') 'rotationDirection': rotationDirection,
      if (layerType == 'asset') 'perspective': perspective,
      if (layerType == 'asset' &&
          speedLevel != null &&
          speedLevel!.trim().isNotEmpty)
        'speedLevel': speedLevel!.trim(),
      if (style != null) 'style': style!.toJson(),
      if (box != null) 'box': box!.toJson(),
    };
  }

  factory PostcardElementLayer.fromJson(
    Map<String, dynamic> json, {
    String? fallbackId,
  }) {
    final id =
        _toTrimmedString(json['id']) ??
        _toTrimmedString(json['layerId']) ??
        _toTrimmedString(json['layer_id']) ??
        _toTrimmedString(json['uuid']) ??
        fallbackId ??
        'layer_legacy';
    final type = _normalizeLayerType(
      _toTrimmedString(json['type']) ??
          _toTrimmedString(json['layerType']) ??
          _toTrimmedString(json['layer_type']) ??
          _toTrimmedString(json['elementType']) ??
          _toTrimmedString(json['element_type']) ??
          (json.containsKey('text') || json.containsKey('style')
              ? 'text'
              : 'asset'),
    );
    final elementKey =
        _toTrimmedString(json['elementKey']) ??
        _toTrimmedString(json['element_key']) ??
        _toTrimmedString(json['key']) ??
        _toTrimmedString(json['elementCode']) ??
        _toTrimmedString(json['element_code']) ??
        _toTrimmedString(json['elementName']) ??
        _toTrimmedString(json['materialKey']) ??
        _toTrimmedString(json['material_key']) ??
        _toTrimmedString(json['materialCode']) ??
        _toTrimmedString(json['material_code']) ??
        _toTrimmedString(json['resourceKey']) ??
        _toTrimmedString(json['resource_key']) ??
        _toTrimmedString(json['assetKey']) ??
        _toTrimmedString(json['asset_key']) ??
        '';
    final assetPath = _resolveAssetPath(json, elementKey);
    final text =
        _toTrimmedString(json['text']) ??
        _toTrimmedString(json['content']) ??
        _toTrimmedString(json['textContent']) ??
        _toTrimmedString(json['text_content']) ??
        _toTrimmedString(json['contentText']) ??
        _toTrimmedString(json['content_text']) ??
        _toTrimmedString(json['value']);
    final speedLevel =
        _toTrimmedString(json['speedLevel']) ??
        _toTrimmedString(json['speed_level']);
    final styleMap =
        _toMap(json['style']) ??
        _toMap(json['styleJson']) ??
        _toMap(json['style_json']) ??
        _toMap(json['styleConfig']) ??
        _toMap(json['style_config']);
    final boxMap =
        _toMap(json['box']) ??
        _toMap(json['boxJson']) ??
        _toMap(json['box_json']) ??
        _toMap(json['textBox']) ??
        _toMap(json['text_box']);

    return PostcardElementLayer(
      id: id,
      type: type,
      elementKey: elementKey,
      assetPath: assetPath,
      text: text,
      style: styleMap == null
          ? (type == 'text' ? const PostcardTextLayerStyle() : null)
          : PostcardTextLayerStyle.fromJson(styleMap),
      box: boxMap == null
          ? (type == 'text' ? const PostcardTextLayerBox() : null)
          : PostcardTextLayerBox.fromJson(boxMap),
      x:
          _toDouble(
            json['x'] ??
                json['left'] ??
                json['positionX'] ??
                json['position_x'] ??
                json['offsetX'] ??
                json['offset_x'] ??
                json['tx'],
          ) ??
          0,
      y:
          _toDouble(
            json['y'] ??
                json['top'] ??
                json['positionY'] ??
                json['position_y'] ??
                json['offsetY'] ??
                json['offset_y'] ??
                json['ty'],
          ) ??
          0,
      scale: _toDouble(json['scale'] ?? json['ratio'] ?? json['zoom']) ?? 1,
      rotation2d:
          _toDouble(
            json['rotation2d'] ??
                json['rotation_2d'] ??
                json['rotation'] ??
                json['angle'] ??
                json['rotate'],
          ) ??
          0,
      zIndex:
          _toInt(
            json['zIndex'] ??
                json['z'] ??
                json['z_index'] ??
                json['layerIndex'] ??
                json['layer_index'] ??
                json['index'],
          ) ??
          0,
      is3dEnabled: type == 'text'
          ? false
          : (_toBool(
                  json['is3dEnabled'] ??
                      json['enable3d'] ??
                      json['is3D'] ??
                      json['is_3d_enabled'] ??
                      json['enable_3d'],
                ) ??
                false),
      rotateX: _toDouble(json['rotateX'] ?? json['rotate_x']) ?? 0,
      rotateY: _toDouble(json['rotateY'] ?? json['rotate_y']) ?? 0,
      rotationSpeed:
          _toDouble(
            json['rotationSpeed'] ?? json['rotation_speed'] ?? json['speed'],
          ) ??
          _speedValueFromLevel(speedLevel) ??
          1,
      rotationAxis: _normalizeAxis(
        json['rotationAxis'] ?? json['rotation_axis'],
      ),
      rotationDirection: _normalizeDirection(
        json['rotationDirection'] ?? json['rotation_direction'],
      ),
      perspective:
          _toDouble(json['perspective'] ?? json['perspective_value']) ?? 0.001,
      speedLevel: speedLevel,
    );
  }
}

String _normalizeLayerType(dynamic raw) {
  final value = raw?.toString().trim().toLowerCase() ?? '';
  if (value == 'text') return 'text';
  return 'asset';
}

String _normalizeDirection(dynamic raw) {
  final value = raw?.toString().trim().toLowerCase() ?? '';
  if (value == 'counterclockwise') return 'counterclockwise';
  return 'clockwise';
}

String _normalizeAxis(dynamic raw) {
  final value = raw?.toString().trim().toLowerCase() ?? '';
  if (value == 'horizontal') return 'horizontal';
  return 'vertical';
}

String _normalizeTextAlign(dynamic raw) {
  final value = raw?.toString().trim().toLowerCase() ?? '';
  if (value == 'left' ||
      value == 'right' ||
      value == 'center' ||
      value == 'justify') {
    return value;
  }
  return 'center';
}

String _normalizeFontStyle(dynamic raw) {
  final value = raw?.toString().trim().toLowerCase() ?? '';
  if (value == 'italic') return 'italic';
  return 'normal';
}

double? _speedValueFromLevel(String? level) {
  switch (level?.toLowerCase()) {
    case 'low':
      return 0.6;
    case 'medium':
      return 1.0;
    case 'high':
      return 1.6;
    default:
      return null;
  }
}

String? _toTrimmedString(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  return text;
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value.toString());
}

bool? _toBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase() ?? '';
  if (text.isEmpty) return null;
  if (text == 'true' || text == '1') return true;
  if (text == 'false' || text == '0') return false;
  return null;
}

Map<String, dynamic>? _toMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    try {
      return value.cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    try {
      final decoded = jsonDecode(trimmed);
      return _toMap(decoded);
    } catch (_) {
      return null;
    }
  }
  return null;
}

String _resolveAssetPath(Map<String, dynamic> json, String elementKey) {
  final direct =
      _toTrimmedString(json['assetPath']) ??
      _toTrimmedString(json['asset_path']) ??
      _toTrimmedString(json['assetUrl']) ??
      _toTrimmedString(json['asset_url']) ??
      _toTrimmedString(json['elementPath']) ??
      _toTrimmedString(json['element_path']) ??
      _toTrimmedString(json['resourcePath']) ??
      _toTrimmedString(json['resource_path']) ??
      _toTrimmedString(json['resourceKey']) ??
      _toTrimmedString(json['resource_key']) ??
      _toTrimmedString(json['materialPath']) ??
      _toTrimmedString(json['material_path']) ??
      _toTrimmedString(json['imageUrl']) ??
      _toTrimmedString(json['image_url']) ??
      _toTrimmedString(json['image']) ??
      _toTrimmedString(json['url']) ??
      _toTrimmedString(json['uri']) ??
      _toTrimmedString(json['path']) ??
      _toTrimmedString(json['objectKey']) ??
      _toTrimmedString(json['object_key']) ??
      _toTrimmedString(json['fileKey']) ??
      _toTrimmedString(json['file_key']) ??
      '';
  if (direct.isNotEmpty) {
    return direct;
  }

  final normalizedKey = elementKey.trim();
  if (normalizedKey.isEmpty) {
    return '';
  }

  if (normalizedKey.contains('/') ||
      normalizedKey.contains('\\') ||
      normalizedKey.contains('.')) {
    return normalizedKey;
  }

  if (RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(normalizedKey)) {
    return 'postcards/elements/$normalizedKey.png';
  }
  return '';
}

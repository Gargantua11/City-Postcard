class PostcardElementLayer {
  final String id;
  final String elementKey;
  final String assetPath;
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
    required this.elementKey,
    required this.assetPath,
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

  PostcardElementLayer copyWith({
    String? id,
    String? elementKey,
    String? assetPath,
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
  }) {
    return PostcardElementLayer(
      id: id ?? this.id,
      elementKey: elementKey ?? this.elementKey,
      assetPath: assetPath ?? this.assetPath,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation2d: rotation2d ?? this.rotation2d,
      zIndex: zIndex ?? this.zIndex,
      is3dEnabled: is3dEnabled ?? this.is3dEnabled,
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
    return {
      'id': id,
      'elementKey': elementKey,
      'assetPath': assetPath,
      'x': x,
      'y': y,
      'scale': scale,
      'rotation2d': rotation2d,
      'zIndex': zIndex,
      'is3dEnabled': is3dEnabled,
      'rotateX': rotateX,
      'rotateY': rotateY,
      'rotationSpeed': rotationSpeed,
      'rotationAxis': rotationAxis,
      'rotationDirection': rotationDirection,
      'perspective': perspective,
      if (speedLevel != null && speedLevel!.trim().isNotEmpty)
        'speedLevel': speedLevel!.trim(),
    };
  }

  factory PostcardElementLayer.fromJson(
    Map<String, dynamic> json, {
    String? fallbackId,
  }) {
    final id = _toTrimmedString(json['id']) ?? fallbackId ?? 'layer_legacy';
    final elementKey = _toTrimmedString(json['elementKey']) ?? '';
    final assetPath = _toTrimmedString(json['assetPath']) ?? '';
    final speedLevel = _toTrimmedString(json['speedLevel']);

    return PostcardElementLayer(
      id: id,
      elementKey: elementKey,
      assetPath: assetPath,
      x: _toDouble(json['x']) ?? 0,
      y: _toDouble(json['y']) ?? 0,
      scale: _toDouble(json['scale']) ?? 1,
      rotation2d: _toDouble(json['rotation2d']) ?? 0,
      zIndex: _toInt(json['zIndex']) ?? 0,
      is3dEnabled: _toBool(json['is3dEnabled']) ?? false,
      rotateX: _toDouble(json['rotateX']) ?? 0,
      rotateY: _toDouble(json['rotateY']) ?? 0,
      rotationSpeed:
          _toDouble(json['rotationSpeed']) ??
          _speedValueFromLevel(speedLevel) ??
          1,
      rotationAxis: _normalizeAxis(json['rotationAxis']),
      rotationDirection: _normalizeDirection(json['rotationDirection']),
      perspective: _toDouble(json['perspective']) ?? 0.001,
      speedLevel: speedLevel,
    );
  }
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

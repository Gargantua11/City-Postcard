import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/postcard_element_layer.dart';

class EditedPostcard {
  final String draftId;
  final String imageUrl;
  final DateTime editedAt;
  final bool isPublished;
  final bool isDraft;
  final double? latitude;
  final double? longitude;
  final String? cityName;
  final String? cityCode;
  final String? provinceName;
  final List<PostcardElementLayer> layers;

  const EditedPostcard({
    required this.draftId,
    required this.imageUrl,
    required this.editedAt,
    this.isPublished = false,
    this.isDraft = false,
    this.latitude,
    this.longitude,
    this.cityName,
    this.cityCode,
    this.provinceName,
    this.layers = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'draftId': draftId,
      'imageUrl': imageUrl,
      'editedAt': editedAt.toIso8601String(),
      'isPublished': isPublished,
      'isDraft': isDraft,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (cityName != null && cityName!.trim().isNotEmpty)
        'cityName': cityName!.trim(),
      if (cityCode != null && cityCode!.trim().isNotEmpty)
        'cityCode': cityCode!.trim(),
      if (provinceName != null && provinceName!.trim().isNotEmpty)
        'provinceName': provinceName!.trim(),
      if (layers.isNotEmpty)
        'layers': layers.map((item) => item.toJson()).toList(growable: false),
    };
  }

  factory EditedPostcard.fromJson(Map<String, dynamic> json) {
    final rawTime = json['editedAt']?.toString() ?? '';
    final parsedTime = DateTime.tryParse(rawTime);
    final editedAt = parsedTime ?? DateTime.now();
    final imageUrl = json['imageUrl']?.toString() ?? '';
    final draftId = _toDraftId(
      raw: json['draftId'],
      editedAt: editedAt,
      imageUrl: imageUrl,
    );
    return EditedPostcard(
      draftId: draftId,
      imageUrl: imageUrl,
      editedAt: editedAt,
      isPublished: _toBool(json['isPublished']) ?? false,
      isDraft: _toBool(json['isDraft']) ?? false,
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      cityName: _toNullableTrimmedString(json['cityName']),
      cityCode: _toNullableCodeString(json['cityCode']),
      provinceName: _toNullableTrimmedString(json['provinceName']),
      layers: _toElementLayers(json['layers']),
    );
  }
}

class EditedPostcardService {
  static const String _storageKey = 'edited_postcards';

  Future<List<EditedPostcard>> getEditedPostcards() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      final postcards = <EditedPostcard>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          postcards.add(EditedPostcard.fromJson(item));
        } else if (item is Map) {
          postcards.add(EditedPostcard.fromJson(item.cast<String, dynamic>()));
        }
      }

      postcards.sort((a, b) => b.editedAt.compareTo(a.editedAt));
      return postcards;
    } catch (_) {
      return [];
    }
  }

  Future<List<EditedPostcard>> getDraftPostcards() async {
    final postcards = await getEditedPostcards();
    return postcards
        .where((item) => item.isDraft && !item.isPublished)
        .toList(growable: false);
  }

  Future<void> addEditedPostcard(
    String imageUrl, {
    double? latitude,
    double? longitude,
    String? cityName,
    String? cityCode,
    String? provinceName,
    List<PostcardElementLayer>? layers,
  }) async {
    final postcards = await getEditedPostcards();
    postcards.insert(
      0,
      EditedPostcard(
        draftId: _createDraftId(),
        imageUrl: imageUrl.trim(),
        editedAt: DateTime.now(),
        isPublished: false,
        isDraft: false,
        latitude: latitude,
        longitude: longitude,
        cityName: cityName?.trim(),
        cityCode: _toNullableCodeString(cityCode),
        provinceName: provinceName?.trim(),
        layers: List<PostcardElementLayer>.from(layers ?? const []),
      ),
    );
    await _savePostcards(postcards);
  }

  Future<String> saveDraftPostcard({
    String? draftId,
    required String imageUrl,
    double? latitude,
    double? longitude,
    String? cityName,
    String? cityCode,
    String? provinceName,
    List<PostcardElementLayer>? layers,
  }) async {
    final postcards = await getEditedPostcards();
    final normalizedId = draftId?.trim() ?? '';
    final targetId = normalizedId.isEmpty ? _createDraftId() : normalizedId;
    final updateIndex = normalizedId.isEmpty
        ? -1
        : postcards.indexWhere((item) => item.draftId == normalizedId);

    if (updateIndex >= 0) {
      postcards.removeAt(updateIndex);
    }

    postcards.insert(
      0,
      EditedPostcard(
        draftId: targetId,
        imageUrl: imageUrl.trim(),
        editedAt: DateTime.now(),
        isPublished: false,
        isDraft: true,
        latitude: latitude,
        longitude: longitude,
        cityName: cityName?.trim(),
        cityCode: _toNullableCodeString(cityCode),
        provinceName: provinceName?.trim(),
        layers: List<PostcardElementLayer>.from(layers ?? const []),
      ),
    );

    await _savePostcards(postcards);
    return targetId;
  }

  Future<bool> deleteEditedPostcardAt(int index) async {
    final postcards = await getEditedPostcards();
    if (index < 0 || index >= postcards.length) {
      return false;
    }
    postcards.removeAt(index);
    await _savePostcards(postcards);
    return true;
  }

  Future<bool> markPostcardPublished(String draftId) async {
    final normalizedId = draftId.trim();
    if (normalizedId.isEmpty) return false;

    final postcards = await getEditedPostcards();
    final index = postcards.indexWhere((item) => item.draftId == normalizedId);
    if (index < 0) return false;

    final target = postcards[index];
    if (target.isPublished) return true;

    postcards[index] = EditedPostcard(
      draftId: target.draftId,
      imageUrl: target.imageUrl,
      editedAt: target.editedAt,
      isPublished: true,
      isDraft: false,
      latitude: target.latitude,
      longitude: target.longitude,
      cityName: target.cityName,
      cityCode: target.cityCode,
      provinceName: target.provinceName,
      layers: target.layers,
    );

    await _savePostcards(postcards);
    return true;
  }

  String _createDraftId() {
    final micros = DateTime.now().microsecondsSinceEpoch;
    return 'draft_$micros';
  }

  Future<void> _savePostcards(List<EditedPostcard> postcards) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(postcards.map((item) => item.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString());
}

String? _toNullableTrimmedString(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  return text;
}

String? _toNullableCodeString(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return digits;
}

String _toDraftId({
  required dynamic raw,
  required DateTime editedAt,
  required String imageUrl,
}) {
  final text = raw?.toString().trim() ?? '';
  if (text.isNotEmpty) return text;

  final safeUrl = imageUrl.trim().isEmpty ? 'empty' : imageUrl.trim();
  return 'legacy_${editedAt.microsecondsSinceEpoch}_$safeUrl';
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

List<PostcardElementLayer> _toElementLayers(dynamic value) {
  if (value is! List) return const [];

  final layers = <PostcardElementLayer>[];
  for (var i = 0; i < value.length; i++) {
    final item = value[i];
    if (item is Map<String, dynamic>) {
      layers.add(
        PostcardElementLayer.fromJson(item, fallbackId: 'legacy_layer_$i'),
      );
      continue;
    }
    if (item is Map) {
      layers.add(
        PostcardElementLayer.fromJson(
          item.cast<String, dynamic>(),
          fallbackId: 'legacy_layer_$i',
        ),
      );
    }
  }
  return layers;
}

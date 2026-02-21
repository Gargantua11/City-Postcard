import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class EditedPostcard {
  final String imageUrl;
  final DateTime editedAt;
  final double? latitude;
  final double? longitude;
  final String? cityName;
  final String? provinceName;

  const EditedPostcard({
    required this.imageUrl,
    required this.editedAt,
    this.latitude,
    this.longitude,
    this.cityName,
    this.provinceName,
  });

  Map<String, dynamic> toJson() {
    return {
      'imageUrl': imageUrl,
      'editedAt': editedAt.toIso8601String(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (cityName != null && cityName!.trim().isNotEmpty)
        'cityName': cityName!.trim(),
      if (provinceName != null && provinceName!.trim().isNotEmpty)
        'provinceName': provinceName!.trim(),
    };
  }

  factory EditedPostcard.fromJson(Map<String, dynamic> json) {
    final rawTime = json['editedAt']?.toString() ?? '';
    final parsedTime = DateTime.tryParse(rawTime);
    return EditedPostcard(
      imageUrl: json['imageUrl']?.toString() ?? '',
      editedAt: parsedTime ?? DateTime.now(),
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      cityName: _toNullableTrimmedString(json['cityName']),
      provinceName: _toNullableTrimmedString(json['provinceName']),
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

  Future<void> addEditedPostcard(
    String imageUrl, {
    double? latitude,
    double? longitude,
    String? cityName,
    String? provinceName,
  }) async {
    final postcards = await getEditedPostcards();
    postcards.insert(
      0,
      EditedPostcard(
        imageUrl: imageUrl.trim(),
        editedAt: DateTime.now(),
        latitude: latitude,
        longitude: longitude,
        cityName: cityName?.trim(),
        provinceName: provinceName?.trim(),
      ),
    );
    await _savePostcards(postcards);
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

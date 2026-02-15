import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class EditedPostcard {
  final String imageUrl;
  final DateTime editedAt;

  const EditedPostcard({
    required this.imageUrl,
    required this.editedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'imageUrl': imageUrl,
      'editedAt': editedAt.toIso8601String(),
    };
  }

  factory EditedPostcard.fromJson(Map<String, dynamic> json) {
    final rawTime = json['editedAt']?.toString() ?? '';
    final parsedTime = DateTime.tryParse(rawTime);
    return EditedPostcard(
      imageUrl: json['imageUrl']?.toString() ?? '',
      editedAt: parsedTime ?? DateTime.now(),
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
          postcards.add(
            EditedPostcard.fromJson(item.cast<String, dynamic>()),
          );
        }
      }

      postcards.sort((a, b) => b.editedAt.compareTo(a.editedAt));
      return postcards;
    } catch (_) {
      return [];
    }
  }

  Future<void> addEditedPostcard(String imageUrl) async {
    final postcards = await getEditedPostcards();
    postcards.insert(
      0,
      EditedPostcard(imageUrl: imageUrl.trim(), editedAt: DateTime.now()),
    );
    await _savePostcards(postcards);
  }

  Future<void> _savePostcards(List<EditedPostcard> postcards) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      postcards.map((item) => item.toJson()).toList(),
    );
    await prefs.setString(_storageKey, encoded);
  }
}

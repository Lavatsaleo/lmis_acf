import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:lmis_acf/models/box_models.dart';

class BoxStore {
  static const _boxesKey = "boxes_v2";
  static const _uidCounterKey = "box_uid_counter_v1"; // last used number; default 0

  static Future<List<BoxItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_boxesKey);
    if (raw == null || raw.trim().isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final out = <BoxItem>[];

      for (final e in decoded) {
        try {
          out.add(BoxItem.fromJson(e as Map<String, dynamic>));
        } catch (_) {
          // Skip any old/invalid records
        }
      }

      if (out.isEmpty && decoded.isNotEmpty) {
        await prefs.remove(_boxesKey);
      }

      return out;
    } catch (_) {
      await prefs.remove(_boxesKey);
      return [];
    }
  }

  static Future<void> save(List<BoxItem> boxes) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(boxes.map((b) => b.toJson()).toList());
    await prefs.setString(_boxesKey, raw);
  }

  /// Preview next number without committing (no gaps if user cancels).
  static Future<int> peekNextNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUsed = prefs.getInt(_uidCounterKey) ?? 0;
    return lastUsed + 1;
  }

  /// Commit next number as used.
  static Future<void> commitNumber(int used) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_uidCounterKey, used);
  }

  static String formatBoxUid(int n) {
    final suffix = n.toString().padLeft(3, '0');
    return "AAH-KE-ISL-$suffix";
  }
}

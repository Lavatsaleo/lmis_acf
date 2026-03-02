import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight shipment (manifest) cache using SharedPreferences.
///
/// Why SharedPreferences?
/// - avoids adding new Isar collections (no code-gen required)
/// - good enough for a small list of open manifests + their box UID lists
class ShipmentCacheStore {
  static const _kList = 'cache.shipments.list';
  static const _kDetailPrefix = 'cache.shipments.detail.'; // + shipmentId
  static const _kReceivedPrefix = 'cache.shipments.received.'; // + shipmentId

  Future<void> saveShipmentList(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kList, jsonEncode(list));
  }

  Future<List<Map<String, dynamic>>> readShipmentList() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kList);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        // Guard: older app versions cached already-received manifests.
        // Hide them by default so clinicians don't see a long list.
        return decoded
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .where((m) => (m['status'] ?? '').toString().toUpperCase() != 'RECEIVED')
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  /// Remove a manifest from the cached list (used after completion).
  Future<void> removeFromList(String shipmentId) async {
    final id = shipmentId.trim();
    if (id.isEmpty) return;
    final list = await readShipmentList();
    final filtered = list.where((m) => (m['id'] ?? '').toString() != id).toList();
    await saveShipmentList(filtered);
  }

  Future<void> saveShipmentDetail(String shipmentId, Map<String, dynamic> detail) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_kDetailPrefix$shipmentId', jsonEncode(detail));
  }

  Future<Map<String, dynamic>?> readShipmentDetail(String shipmentId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_kDetailPrefix$shipmentId');
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {}
    return null;
  }

  Future<List<String>> readReceivedBoxUids(String shipmentId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_kReceivedPrefix$shipmentId');
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return const [];
  }

  Future<void> addReceivedBoxUids(String shipmentId, List<String> boxUids) async {
    final current = (await readReceivedBoxUids(shipmentId)).toSet();
    for (final u in boxUids) {
      final s = u.trim();
      if (s.isNotEmpty) current.add(s);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_kReceivedPrefix$shipmentId', jsonEncode(current.toList()));
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kList);
    // details are per-shipment and will remain; keep for now.
  }
}

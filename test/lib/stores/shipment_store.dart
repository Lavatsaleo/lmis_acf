import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:lmis_acf/models/shipment_models.dart';

class ShipmentStore {
  static const _shipmentsKey = "shipments_v1";
  static const _shipmentCounterKey = "shipment_counter_v1"; // last used

  static Future<List<Shipment>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_shipmentsKey);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => Shipment.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      await prefs.remove(_shipmentsKey);
      return [];
    }
  }

  static Future<void> save(List<Shipment> shipments) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(shipments.map((s) => s.toJson()).toList());
    await prefs.setString(_shipmentsKey, raw);
  }

  static Future<int> peekNextShipmentNo() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_shipmentCounterKey) ?? 0;
    return last + 1;
  }

  static Future<void> commitShipmentNo(int used) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_shipmentCounterKey, used);
  }

  static String formatShipmentId(DateTime now, int n) {
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final suffix = n.toString().padLeft(3, '0');
    return "SHIP-$y$m$d-$suffix";
  }
}

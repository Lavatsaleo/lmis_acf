import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lmis_acf/core/colors.dart';
import 'package:lmis_acf/models/box_models.dart';

String statusText(BoxStatus s) {
  switch (s) {
    case BoxStatus.inWarehouse:
      return "In Warehouse";
    case BoxStatus.inTransit:
      return "In Transit";
    case BoxStatus.receivedAtFacility:
      return "Received at Facility";
  }
}

Color statusColor(BoxStatus s) {
  switch (s) {
    case BoxStatus.inWarehouse:
      return acfBlue;
    case BoxStatus.inTransit:
      return Colors.orange;
    case BoxStatus.receivedAtFacility:
      return acfGreen;
  }
}

Map<String, dynamic> parsePayload(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.map((k, v) => MapEntry(k.toString(), v));
  } catch (_) {}
  return {};
}

String? extractBoxUidFromPayload(String raw) {
  final parsed = parsePayload(raw);
  final uid = parsed["boxUid"];
  if (uid is String && uid.trim().isNotEmpty) return uid.trim();
  return null;
}

String formatDate(DateTime d) {
  final mm = d.month.toString().padLeft(2, "0");
  final dd = d.day.toString().padLeft(2, "0");
  return "${d.year}-$mm-$dd";
}

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'growth_models.dart';

/// Loads WHO growth reference datasets from assets and caches them in memory.
class GrowthLoader {
  GrowthLoader._();
  static final GrowthLoader instance = GrowthLoader._();

  final Map<String, GrowthDataset> _cache = {};

  static String _assetFor(GrowthRefKey key) {
    final sex = key.sex == GrowthSex.male ? 'boys' : 'girls';
    final type = key.type == GrowthRefType.wfl ? 'wfl' : 'wfh';
    return 'assets/growth/${type}_$sex.json';
  }

  Future<GrowthDataset> load(GrowthRefKey key) async {
    final asset = _assetFor(key);
    final cached = _cache[asset];
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(asset);
    final list = (jsonDecode(raw) as List).cast<dynamic>();
    final rows = list.map((e) => GrowthRow.fromJson((e as Map).cast<String, dynamic>())).toList();
    // Ensure sorted by x.
    rows.sort((a, b) => a.x.compareTo(b.x));
    final ds = GrowthDataset(rows);
    _cache[asset] = ds;
    return ds;
  }
}

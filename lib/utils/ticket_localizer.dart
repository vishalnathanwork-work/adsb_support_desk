import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';

import '../models/localized_preset.dart';

/// Caches presets in memory so we don't refetch on every ticket render.
class TicketLocalizer {
  static final TicketLocalizer _instance = TicketLocalizer._();
  factory TicketLocalizer() => _instance;
  TicketLocalizer._();

  List<LocalizedPreset> _productTypes = [];
  Map<String, List<LocalizedPreset>> _issues = {};
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final db = FirebaseFirestore.instance;
      final ptSnap = await db.collection('presets').doc('product_types').get();
      final piSnap = await db.collection('presets').doc('product_issues').get();

      if (ptSnap.exists) {
        final items = ptSnap.data()!['items'];
        if (items is List) {
          _productTypes = items.map(LocalizedPreset.fromJson).toList();
        }
      }
      if (piSnap.exists) {
        final items = piSnap.data()!['items'];
        if (items is Map) {
          items.forEach((key, value) {
            if (value is List) {
              _issues[key.toString()] =
                  value.map(LocalizedPreset.fromJson).toList();
            }
          });
        }
      }
      _loaded = true;
    } catch (e) {
      print('TicketLocalizer._ensureLoaded error: $e');
    }
  }

  /// Call once at app start to warm the cache.
  Future<void> preload() => _ensureLoaded();

  /// Translate a canonical product type (English) into the given locale.
  String productType(String en, Locale locale) {
    for (final p in _productTypes) {
      if (p.en == en) return p.localized(locale);
    }
    return en; // fall back
  }

  /// Translate a canonical product issue (English) into the given locale.
  String productIssue(String en, Locale locale) {
    for (final list in _issues.values) {
      for (final p in list) {
        if (p.en == en) return p.localized(locale);
      }
    }
    return en;
  }
}
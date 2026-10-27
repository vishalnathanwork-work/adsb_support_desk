import 'dart:ui';

/// A preset item (product type, issue, root cause, solution) that
/// carries both English and Malay translations.
///
/// Backward-compatible: legacy Firestore documents that stored plain
/// strings will be parsed with `en == ms == rawString`.
class LocalizedPreset {
  final String key; // stable id, e.g. "barrier"
  final String en;  // English display value
  final String ms;  // Malay display value

  const LocalizedPreset({
    required this.key,
    required this.en,
    required this.ms,
  });

  /// Returns the string matching the active app locale,
  /// falling back to English if Malay is empty.
  String localized(Locale locale) {
    if (locale.languageCode == 'ms' && ms.trim().isNotEmpty) {
      return ms;
    }
    return en;
  }

  /// Parse either the new object format OR a legacy plain string.
  factory LocalizedPreset.fromJson(dynamic raw) {
    if (raw is String) {
      final key = _slugify(raw);
      return LocalizedPreset(key: key, en: raw, ms: raw);
    }
    if (raw is Map) {
      final key = (raw['key'] ?? '').toString();
      final en = (raw['en'] ?? '').toString();
      final ms = (raw['ms'] ?? '').toString();
      return LocalizedPreset(
        key: key.isEmpty ? _slugify(en) : key,
        en: en.isEmpty ? key : en,
        ms: ms.isEmpty ? en : ms,
      );
    }
    return const LocalizedPreset(key: '', en: '', ms: '');
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'en': en,
    'ms': ms,
  };

  /// Canonical value saved on tickets (English).
  String get canonical => en;

  static String _slugify(String s) {
    return s
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }
}
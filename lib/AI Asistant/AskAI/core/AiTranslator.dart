import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import 'ai_core.dart';

/// =======================================================================
///  🌐 AI TRANSLATOR — local language ⇄ English (on-device, Google ML Kit)
///
///   Question:  "આજે કેટલો સ્ટોક ઉમેરાયો?"  → "How much stock was added today?"
///              (engines work on English + original keywords together)
///   Answer:    English answer → selected language (Gujarati / Hindi)
///
///  • Works offline after a one-time model download (~30 MB per language).
///  • Item names, customer names, barcodes and numbers are protected — they
///    are never translated ("Temple Ring" stays "Temple Ring").
///  • Records (list rows) are not rebuilt, so tapping a voucher still works.
///
///  pubspec:  flutter pub add google_mlkit_translation
///  File: Ask AI/core/ai_translator.dart
/// =======================================================================
class AiTranslator {
  /// 'en' / 'gu' / 'hi'
  static const Map<String, String> names = {'en': 'English', 'gu': 'ગુજરાતી', 'hi': 'हिंदी'};

  static TranslateLanguage _lang(String code) =>
      code == 'gu' ? TranslateLanguage.gujarati : (code == 'hi' ? TranslateLanguage.hindi : TranslateLanguage.english);

  static final Map<String, OnDeviceTranslator> _tr = {};
  static final Map<String, String> _cache = {};

  /// translated follow-up chip → original English question
  static final Map<String, String> _orig = {};

  /// Names that must never be translated (items, customers)
  static List<String> _protect = [];
  static void setProtected(Iterable<String> list) {
    _protect = list.map((e) => e.trim()).where((e) => e.length >= 3).toSet().toList()
      ..sort((a, b) => b.length - a.length);
  }

  static OnDeviceTranslator _get(String from, String to) =>
      _tr.putIfAbsent('$from>$to', () => OnDeviceTranslator(sourceLanguage: _lang(from), targetLanguage: _lang(to)));

  static void dispose() {
    for (final t in _tr.values) {
      t.close();
    }
    _tr.clear();
  }

  // ---------------------------------------------------------------------
  //  MODEL
  // ---------------------------------------------------------------------
  static final _models = OnDeviceTranslatorModelManager();

  static Future<bool> isReady(String code) async {
    if (code == 'en') return true;
    try {
      return await _models.isModelDownloaded(_lang(code).bcpCode);
    } catch (_) {
      return false;
    }
  }

  /// One-time download (needs internet once)
  static Future<bool> ensureModel(String code) async {
    if (await isReady(code)) return true;
    try {
      return await _models.downloadModel(_lang(code).bcpCode, isWifiRequired: false);
    } catch (e) {
      debugPrint('🌐 Model download failed ($code): $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------
  //  QUESTION → ENGLISH
  // ---------------------------------------------------------------------
  static String? scriptOf(String s) {
    if (RegExp(r'[઀-૿]').hasMatch(s)) return 'gu';
    if (RegExp(r'[ऀ-ॿ]').hasMatch(s)) return 'hi';
    return null;
  }

  /// Gujarati / Hindi script → English.  Returns null if nothing to translate
  /// (English / Gujlish typed in Latin letters is already understood).
  static Future<String?> toEnglish(String q) async {
    final src = scriptOf(q);
    if (src == null) return null;
    if (!await isReady(src)) {
      ensureModel(src); // background — next question will use it
      return null;
    }
    final en = await _translate(q, src, 'en');
    return (en == null || en.trim().isEmpty) ? null : en.trim();
  }

  /// Original follow-up (English) for a translated chip
  static String originalOf(String shown) => _orig[shown] ?? shown;

  // ---------------------------------------------------------------------
  //  ANSWER → SELECTED LANGUAGE
  // ---------------------------------------------------------------------
  static Future<AiAnswer> answer(AiAnswer a, String to) async {
    if (to == 'en' || !await isReady(to)) return a;
    Future<String> t(String s) async => (await translate(s, to)) ?? s;

    final text = await t(a.text);
    final speech = a.speech == a.text ? text : await t(a.speech);
    final stats = <AiStat>[for (final s in a.stats) AiStat(await t(s.label), s.value)];
    final sections = <AiSection>[for (final s in a.sections) AiSection(await t(s.title), s.rows)];
    final follow = <String>[];
    for (final f in a.followUps) {
      final tf = await t(f);
      _orig[tf] = f;
      follow.add(tf);
    }
    return AiAnswer(
      text: text,
      speech: speech,
      stats: stats,
      sections: sections,
      items: a.items,
      // dynamic: works whether AiAnswer field is String or String?
      itemsTitle: await _opt(a.itemsTitle, to) as dynamic,
      filterLabel: await _opt(a.filterLabel, to) as dynamic,
      followUps: follow,
      period: a.period,
    );
  }

  static Future<String?> _opt(Object? v, String to) async {
    final s = v?.toString();
    if (s == null || s.isEmpty) return s;
    return (await translate(s, to)) ?? s;
  }

  /// English → to (line by line, names / codes / numbers protected)
  static Future<String?> translate(String s, String to) async {
    if (to == 'en' || s.trim().isEmpty) return s;
    final key = '$to|$s';
    final hit = _cache[key];
    if (hit != null) return hit;
    if (!await isReady(to)) return null;
    final out = <String>[];
    for (final line in s.split('\n')) {
      out.add(line.trim().isEmpty ? line : (await _translate(line, 'en', to) ?? line));
    }
    final r = out.join('\n');
    _cache[key] = r;
    return r;
  }

  static Future<String?> _translate(String line, String from, String to) async {
    // leading bullets / emoji ("• ", "📅 ") stay outside translation
    final lead = RegExp(r'^[^A-Za-z0-9ऀ-ॿ઀-૿"]*').firstMatch(line)?[0] ?? '';
    var body = line.substring(lead.length);
    if (body.trim().isEmpty) return line;

    // 🔒 protect names, codes, dates, numbers+units, quoted text
    final keep = <String>[];
    String hold(String v) {
      keep.add(v);
      return ' ${88800 + keep.length} ';
    }

    if (from == 'en') {
      for (final n in _protect) {
        body = body.replaceAllMapped(RegExp(RegExp.escape(n), caseSensitive: false), (m) => hold(m[0]!));
      }
      body = body.replaceAllMapped(RegExp(r'"[^"]{1,60}"'), (m) => hold(m[0]!));
      body = body.replaceAllMapped(RegExp(r'\b\d{1,2}-\d{1,2}-\d{4}\b'), (m) => hold(m[0]!));
      body = body.replaceAllMapped(RegExp(r'\b[A-Z]{1,6}-?\d+[A-Z0-9-]*\b'), (m) => hold(m[0]!));
      body = body.replaceAllMapped(
          RegExp(r'₹\s?[\d,]+(?:\.\d+)?|[\d,]*\d(?:\.\d+)?\s?(?:g|pcs|%)(?![A-Za-z])'), (m) => hold(m[0]!));
    }

    String res;
    try {
      res = await _get(from, to).translateText(body);
    } catch (e) {
      debugPrint('🌐 translate fail: $e');
      return null;
    }

    // local digits → 0-9, then put protected parts back
    const gu = '૦૧૨૩૪૫૬૭૮૯', hi = '०१२३४५६७८९';
    for (var i = 0; i < 10; i++) {
      res = res.replaceAll(gu[i], '$i').replaceAll(hi[i], '$i');
    }
    for (var i = keep.length; i >= 1; i--) {
      final tag = '${88800 + i}';
      if (!res.contains(tag)) return from == 'en' ? null : res; // placeholder lost → keep English
      res = res.replaceAll(tag, keep[i - 1]);
    }
    return '$lead${res.replaceAll(RegExp(r' {2,}'), ' ').trim()}';
  }
}

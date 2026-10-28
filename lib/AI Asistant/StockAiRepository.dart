import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../Api_Constant/ApiConstants.dart';
import '../../Api_Constant/api_helper.dart';
import 'AskAI/stock_ai_models.dart';

/// =======================================================================
///  ⚡ STOCK AI REPOSITORY — FAST (5000+ items)
///
///  Why it was slow:
///   • 24 items per page → 5000 items = ~210 API calls
///   • every call showed (and hid) the full-screen loader → "loading again
///     and again"
///   • Ask AI, voice dictionary and screen-opener each loaded it again
///
///  Now:
///   1) ⚡ PHONE CACHE — last stock list is saved on the phone. Opening Ask AI
///      shows it instantly, and fresh data loads quietly in the background.
///   2) 📦 BIG PAGES — asks the server for 500 items per page (if the backend
///      allows `per_page`, 5000 items = ~10 calls instead of 210).
///   3) 🚀 8 pages at a time, no loader popup (showLoading: false).
///   4) 🔁 ONE LOAD ONLY — if 3 places ask together, they share one download.
///   5) 🧵 JSON parsing on a background isolate (no UI freeze).
///
///  File: Ask AI/stock_ai_repository.dart
/// =======================================================================
class StockAiRepository {
  static List<StockItem>? _cache;
  static DateTime? _cachedAt;
  static Future<List<StockItem>>? _inflight;
  static bool _refreshing = false;

  /// Memory cache life (same app session)
  static const Duration _fresh = Duration(minutes: 10);

  /// Phone cache life (used instantly, then refreshed in background)
  static const Duration _diskMaxAge = Duration(hours: 24);

  /// Items per page asked from the server (backend may ignore it)
  static const int _perPage = 500;

  /// Pages downloaded at the same time
  static const int _parallel = 8;

  static const String _file = 'ask_ai_stock_cache.json';

  /// Fires when a background refresh brings new data (screen can rebuild)
  static final ValueNotifier<int> updated = ValueNotifier<int>(0);

  static DateTime? get lastUpdated => _cachedAt;

  static Future<List<StockItem>> loadAll({
    bool force = false,
    void Function(int done, int total)? onProgress,
  }) {
    // 1) memory
    if (!force && _cache != null && _cachedAt != null && DateTime.now().difference(_cachedAt!) < _fresh) {
      return Future.value(_cache!);
    }
    // 2) already downloading → share it
    if (_inflight != null) return _inflight!;

    _inflight = _load(force: force, onProgress: onProgress).whenComplete(() => _inflight = null);
    return _inflight!;
  }

  static Future<List<StockItem>> _load({
    required bool force,
    void Function(int done, int total)? onProgress,
  }) async {
    // 3) phone cache → instant, then quiet refresh
    if (!force) {
      final disk = await _readDisk();
      if (disk != null) {
        _cache = disk.items;
        _cachedAt = disk.savedAt;
        onProgress?.call(1, 1);
        if (DateTime.now().difference(disk.savedAt) > const Duration(minutes: 2)) {
          _refreshInBackground();
        }
        return disk.items;
      }
    }
    // 4) network
    final fresh = await _download(onProgress: onProgress);
    return fresh;
  }

  static void _refreshInBackground() {
    if (_refreshing) return;
    _refreshing = true;
    _download().then((_) {
      updated.value++;
    }).catchError((e) {
      debugPrint('⚡ stock background refresh failed: $e');
    }).whenComplete(() => _refreshing = false);
  }

  static Future<List<StockItem>> _download({void Function(int done, int total)? onProgress}) async {
    final sw = Stopwatch()..start();
    final first = await _fetchPage(1);
    final raws = <Map<String, dynamic>>[...first.raw];
    final lastPage = first.lastPage;
    onProgress?.call(1, lastPage);

    var done = 1;
    for (var p = 2; p <= lastPage; p += _parallel) {
      final batch = [for (var i = p; i < p + _parallel && i <= lastPage; i++) _fetchPage(i)];
      final results = await Future.wait(batch);
      for (final r in results) {
        raws.addAll(r.raw);
      }
      done += batch.length;
      onProgress?.call(done, lastPage);
    }

    // duplicate ID hatavo (page vacche data badlay to)
    final seen = <String>{};
    final uniqueRaw = raws.where((e) => seen.add((e['id'] ?? e.hashCode).toString())).toList();
    final items = uniqueRaw.map((e) => StockItem.fromJson(e)).toList();

    _cache = items;
    _cachedAt = DateTime.now();
    debugPrint('⚡ Stock loaded: ${items.length} items, $lastPage pages, ${sw.elapsedMilliseconds} ms');
    unawaited(_writeDisk(uniqueRaw));
    return items;
  }

  static void clearCache() {
    _cache = null;
    _cachedAt = null;
    _deleteDisk();
  }

  // ---------------------------------------------------------------------
  //  NETWORK
  // ---------------------------------------------------------------------
  static Future<_Page> _fetchPage(int page) async {
    // 👉 ADJUST: Stock Gallery list nu constant (StockGalleryScreen ma je che te j)
    final response = await ApiHelper().getRequest(
      '${ApiConstants.stock_gallery}?page=$page&per_page=$_perPage&limit=$_perPage',
      showLoading: false, // 🔥 no loader popup for every page
      receiveTimeout: const Duration(seconds: 60),
    );

    dynamic body = response?.data;
    if (body is String) body = await compute<String, dynamic>(StockAiRepository.decodeJson, body);
    if (body is! Map || body['success'] == false) {
      throw Exception(body is Map ? (body['message'] ?? 'Stock load failed') : 'Stock load failed');
    }

    final raw = (body['data'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final pg = body['pagination'] as Map?;
    final lastPage = int.tryParse(pg?['last_page']?.toString() ?? '') ?? 1;
    return _Page(raw, lastPage);
  }

  // ---------------------------------------------------------------------
  //  PHONE CACHE
  // ---------------------------------------------------------------------
  static Future<File> _cacheFile() async => File('${(await getApplicationDocumentsDirectory()).path}/$_file');

  static Future<({List<StockItem> items, DateTime savedAt})?> _readDisk() async {
    try {
      final f = await _cacheFile();
      if (!await f.exists()) return null;
      final text = await f.readAsString();
      final data = await compute<String, dynamic>(StockAiRepository.decodeJson, text);
      if (data is! Map) return null;
      final savedAt = DateTime.tryParse(data['saved_at']?.toString() ?? '');
      if (savedAt == null || DateTime.now().difference(savedAt) > _diskMaxAge) return null;
      final list = (data['items'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => StockItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (list.isEmpty) return null;
      debugPrint('⚡ Stock from phone cache: ${list.length} items (saved $savedAt)');
      return (items: list, savedAt: savedAt);
    } catch (e) {
      debugPrint('⚡ stock cache read failed: $e');
      return null;
    }
  }

  static Future<void> _writeDisk(List<Map<String, dynamic>> raw) async {
    try {
      final text = await compute<Map<String, dynamic>, String>(StockAiRepository.encodeJson, {'saved_at': DateTime.now().toIso8601String(), 'items': raw});
      final f = await _cacheFile();
      await f.writeAsString(text, flush: true);
    } catch (e) {
      debugPrint('⚡ stock cache write failed: $e');
    }
  }

  /// JSON work on a background isolate (static → allowed in compute)
  static dynamic decodeJson(String s) => jsonDecode(s);
  static String encodeJson(Map<String, dynamic> m) => jsonEncode(m);

  static Future<void> _deleteDisk() async {
    try {
      final f = await _cacheFile();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}

class _Page {
  final List<Map<String, dynamic>> raw;
  final int lastPage;
  _Page(this.raw, this.lastPage);
}
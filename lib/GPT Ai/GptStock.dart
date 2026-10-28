import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../Api_Constant/ApiConstants.dart';
import '../../Api_Constant/api_helper.dart';

/// =======================================================================
///  📦 GPT STOCK — the GPT screen's OWN stock loader
///
///  Why: the older stock loader showed the full-screen loader for each page,
///  so the loader stayed stuck after the Stock Gallery API finished.
///  This one:
///   • never shows the loader popup (showLoading: false)
///   • 500 per page, 6 pages at a time
///   • every page has a time limit → it can never hang forever
///   • one download shared by everyone, memory cache for 10 minutes
///   • does NOT touch your Ask AI stock files
///
///  File: Ask AI GPT/GptStock.dart
/// =======================================================================
class GptItem {
  final String id, item, label;
  final double gross, net;
  final bool sold, photo;
  final DateTime? addedOn, soldOn;

  GptItem({
    required this.id,
    required this.item,
    required this.label,
    required this.gross,
    required this.net,
    required this.sold,
    required this.photo,
    this.addedOn,
    this.soldOn,
  });

  int? get ageDays {
    if (addedOn == null) return null;
    return ((sold && soldOn != null) ? soldOn! : DateTime.now()).difference(addedOn!).inDays;
  }

  static double _d(dynamic v) => double.tryParse('${v ?? ''}'.replaceAll(',', '')) ?? 0;

  static DateTime? _date(Map j, List<String> keys) {
    for (final k in keys) {
      final s = '${j[k] ?? ''}'.trim();
      if (s.isEmpty || s == '-' || s == 'null') continue;
      final d = DateTime.tryParse(s);
      if (d != null) return d;
      final m = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})').firstMatch(s);
      if (m != null) return DateTime(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
    }
    return null;
  }

  factory GptItem.fromJson(Map j) {
    final status = '${j['stock_status'] ?? ''}'.toLowerCase();
    final s = j['is_sold'];
    final img = '${j['image_url'] ?? ''}'.trim();
    return GptItem(
      id: '${j['id'] ?? ''}',
      item: '${j['item_name'] ?? '-'}'.trim(),
      label: '${j['label_code'] ?? j['qr_code'] ?? '-'}'.trim(),
      gross: _d(j['gross_weight']),
      net: _d(j['net_weight']),
      sold: s == 1 || s == true || '$s' == '1' || status.contains('out') || status.contains('sold'),
      photo: img.isNotEmpty && img != 'null',
      addedOn: _date(j, const ['created_at', 'label_date', 'stock_date', 'purchase_date', 'inward_date', 'date']),
      soldOn: _date(j, const ['sold_at', 'sold_date', 'sale_date', 'invoice_date']),
    );
  }
}

class GptStock {
  GptStock._();

  /// JSON decode on a background isolate (must be a static function)
  static dynamic _decode(String s) => jsonDecode(s);

  static List<GptItem>? _cache;
  static DateTime? _at;
  static Future<List<GptItem>>? _inflight;

  /// Screen listens to this to show "Stock ready · 5,234 pcs"
  static final ValueNotifier<String> status = ValueNotifier<String>('');

  static const int _perPage = 500;
  static const int _parallel = 6;
  static const Duration _pageLimit = Duration(seconds: 45);

  static bool get ready => _cache != null;
  static int get count => _cache?.length ?? 0;

  static Future<List<GptItem>> load({bool force = false}) {
    if (!force && _cache != null && _at != null && DateTime.now().difference(_at!) < const Duration(minutes: 10)) {
      return Future.value(_cache!);
    }
    if (_inflight != null) return _inflight!;
    _inflight = _download().whenComplete(() => _inflight = null);
    return _inflight!;
  }

  /// Never throws — on a problem returns the last data (or empty)
  static Future<List<GptItem>> safe() async {
    try {
      return await load();
    } catch (e) {
      debugPrint('GptStock: $e');
      return _cache ?? const [];
    }
  }

  static Future<List<GptItem>> _download() async {
    status.value = 'Loading stock…';
    try {
      final first = await _page(1);
      final raws = <Map>[...first.rows];
      final last = first.last.clamp(1, 400);
      for (var p = 2; p <= last; p += _parallel) {
        final batch = [for (var i = p; i < p + _parallel && i <= last; i++) _page(i)];
        for (final r in await Future.wait(batch)) {
          raws.addAll(r.rows);
        }
        status.value = 'Loading stock… ${(p + _parallel - 1).clamp(1, last)}/$last';
      }
      final seen = <String>{};
      final items = raws.where((e) => seen.add('${e['id'] ?? e.hashCode}')).map(GptItem.fromJson).toList();
      _cache = items;
      _at = DateTime.now();
      status.value = 'Stock ready · ${items.length} pcs';
      return items;
    } catch (e) {
      status.value = _cache == null ? 'Stock not loaded — tap to retry' : 'Stock ready · ${_cache!.length} pcs';
      rethrow;
    }
  }

  static Future<({List<Map> rows, int last})> _page(int page) async {
    final res = await ApiHelper()
        .getRequest(
      '${ApiConstants.stock_gallery}?page=$page&per_page=$_perPage&limit=$_perPage',
      showLoading: false, // 🔥 no loader popup
      receiveTimeout: _pageLimit,
    )
        .timeout(_pageLimit + const Duration(seconds: 5));
    dynamic body = res?.data;
    if (body is String) body = await compute<String, dynamic>(_decode, body);
    if (body is! Map) throw Exception('Stock load failed');
    final d = body['data'];
    final List list = d is List ? d : (d is Map && d['data'] is List ? d['data'] as List : const []);
    final pg = (body['pagination'] ?? (d is Map ? d : null)) as Map?;
    final last = int.tryParse('${pg?['last_page'] ?? ''}') ?? 1;
    return (rows: list.whereType<Map>().toList(), last: last);
  }
}

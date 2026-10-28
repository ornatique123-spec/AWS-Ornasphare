import 'dart:convert';

import 'package:intl/intl.dart';

import '../../Api_Constant/ApiConstants.dart';
import '../../Api_Constant/api_helper.dart';
import 'GptStock.dart';

/// =======================================================================
///  🧰 GPT TOOLS — the ONLY way ChatGPT gets numbers
///
///  ChatGPT never guesses figures. It picks a tool, the app runs it on
///  YOUR data (same APIs as the app), and ChatGPT writes the answer in
///  the user's language.
///
///  Tools: search_stock · stock_summary · top_items · barcode_history ·
///         sales_list · approvals_list · returns_list · voucher_items
///
///  Read-only: nothing is created, edited or deleted.
///  File: Ask AI GPT/GptTools.dart
/// =======================================================================
class GptTools {
  GptTools._();

  static final DateFormat _ymd = DateFormat('yyyy-MM-dd');
  static final DateFormat _dmy = DateFormat('dd-MM-yyyy');

  // ---------------------------------------------------------------------
  //  DEFINITIONS (what ChatGPT sees)
  // ---------------------------------------------------------------------
  static Map<String, dynamic> _fn(String name, String desc, Map<String, dynamic> props, [List<String> req = const []]) => {
    'type': 'function',
    'function': {
      'name': name,
      'description': desc,
      'parameters': {'type': 'object', 'properties': props, 'required': req},
    },
  };

  static const Map<String, dynamic> _dateArg = {'type': 'string', 'description': 'yyyy-mm-dd'};

  static List<Map<String, dynamic>> get definitions => [
    _fn('search_stock', 'Find stock pieces (labels). Filter by item name text, net weight range, sold / in stock, photo.', {
      'text': {'type': 'string', 'description': 'item name or label code words, e.g. "temple ring"'},
      'min_net': {'type': 'number'},
      'max_net': {'type': 'number'},
      'status': {'type': 'string', 'enum': ['in_stock', 'sold', 'all']},
      'with_photo': {'type': 'boolean', 'description': 'true = only with photo, false = only without photo'},
      'sort': {'type': 'string', 'enum': ['heaviest', 'lightest', 'newest', 'oldest']},
      'limit': {'type': 'integer', 'description': 'max rows, default 30'},
    }),
    _fn('stock_summary', 'Totals of the whole stock: pieces and net weight in stock / sold, top item names.', {}),
    _fn('top_items', 'Item names ranked by count or weight, for sold pieces (optionally in a date range) or for stock.', {
      'status': {'type': 'string', 'enum': ['sold', 'in_stock']},
      'by': {'type': 'string', 'enum': ['count', 'weight']},
      'from': _dateArg,
      'to': _dateArg,
      'limit': {'type': 'integer'},
    }),
    _fn('barcode_history', 'Full history of one barcode / label code (where it is now, approvals, sales, returns).', {
      'code': {'type': 'string', 'description': 'e.g. BR8'},
    }, ['code']),
    _fn('sales_list', 'Sale bills in a date range (optionally one customer). Returns bills and totals.', {
      'from': _dateArg,
      'to': _dateArg,
      'customer': {'type': 'string'},
    }, ['from', 'to']),
    _fn('approvals_list', 'Approval vouchers issued in a date range (optionally one customer).', {
      'from': _dateArg,
      'to': _dateArg,
      'customer': {'type': 'string'},
    }, ['from', 'to']),
    _fn('returns_list', 'Return vouchers in a date range (optionally one customer).', {
      'from': _dateArg,
      'to': _dateArg,
      'customer': {'type': 'string'},
    }, ['from', 'to']),
    _fn('voucher_items', 'Item rows of one voucher (use the id from a list tool).', {
      'type': {'type': 'string', 'enum': ['sale', 'approval', 'return']},
      'id': {'type': 'string'},
    }, ['type', 'id']),
  ];

  // ---------------------------------------------------------------------
  //  RUN
  // ---------------------------------------------------------------------
  static Future<String> run(String name, String argsJson) async {
    Map<String, dynamic> a = {};
    try {
      a = Map<String, dynamic>.from(jsonDecode(argsJson.isEmpty ? '{}' : argsJson));
    } catch (_) {}
    try {
      final r = switch (name) {
        'search_stock' => await _searchStock(a),
        'stock_summary' => await _stockSummary(),
        'top_items' => await _topItems(a),
        'barcode_history' => await _barcode(a),
        'sales_list' => await _list(ApiConstants.Sale_Summary_report, a, sale: true),
        'approvals_list' => await _list(ApiConstants.Approval_list, a, dateKeys: const ['approval_date', 'date']),
        'returns_list' => await _list(ApiConstants.return_list, a, dateKeys: const ['return_date', 'date']),
        'voucher_items' => await _voucherItems(a),
        _ => {'error': 'unknown tool $name'},
      };
      return _clip(jsonEncode(r));
    } catch (e) {
      return jsonEncode({'error': e.toString()});
    }
  }

  /// keep tool output small (cheaper + faster)
  static String _clip(String s) => s.length <= 14000 ? s : '${s.substring(0, 14000)}…(cut)';

  static double _n(dynamic v) => double.tryParse('${v ?? ''}'.replaceAll(',', '').replaceAll('₹', '')) ?? 0;
  static String _w(double v) => v.toStringAsFixed(3);

  // ---------------- STOCK ----------------
  static Future<Map<String, dynamic>> _searchStock(Map<String, dynamic> a) async {
    final all = await GptStock.safe();
    if (all.isEmpty) return {'error': 'stock data not available right now'};
    final text = (a['text'] ?? '').toString().toLowerCase().trim();
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final status = (a['status'] ?? 'in_stock').toString();
    final minN = a['min_net'] == null ? null : _n(a['min_net']);
    final maxN = a['max_net'] == null ? null : _n(a['max_net']);
    final photo = a['with_photo'];
    var list = all.where((s) {
      if (status == 'in_stock' && s.sold) return false;
      if (status == 'sold' && !s.sold) return false;
      if (minN != null && s.net < minN) return false;
      if (maxN != null && s.net > maxN) return false;
      if (photo == true && !s.photo) return false;
      if (photo == false && s.photo) return false;
      if (words.isNotEmpty) {
        final hay = '${s.item} ${s.label}'.toLowerCase();
        if (!words.every(hay.contains)) return false;
      }
      return true;
    }).toList();
    switch (a['sort']) {
      case 'heaviest':
        list.sort((x, y) => y.net.compareTo(x.net));
        break;
      case 'lightest':
        list.sort((x, y) => x.net.compareTo(y.net));
        break;
      case 'oldest':
        list.sort((x, y) => (x.addedOn ?? DateTime(2100)).compareTo(y.addedOn ?? DateTime(2100)));
        break;
      case 'newest':
        list.sort((x, y) => (y.addedOn ?? DateTime(1900)).compareTo(x.addedOn ?? DateTime(1900)));
        break;
    }
    final limit = (a['limit'] is num ? (a['limit'] as num).toInt() : 30).clamp(1, 80);
    return {
      'count': list.length,
      'total_net_g': _w(list.fold<double>(0, (t, s) => t + s.net)),
      'total_gross_g': _w(list.fold<double>(0, (t, s) => t + s.gross)),
      'rows': list
          .take(limit)
          .map((s) => {
        'label': s.label,
        'item': s.item,
        'gross_g': _w(s.gross),
        'net_g': _w(s.net),
        'status': s.sold ? 'sold' : 'in stock',
        'photo': s.photo,
        if (s.ageDays != null) 'age_days': s.ageDays,
      })
          .toList(),
      if (list.length > limit) 'note': 'showing $limit of ${list.length}',
    };
  }

  static Future<Map<String, dynamic>> _stockSummary() async {
    final all = await GptStock.safe();
    final inS = all.where((s) => !s.sold).toList();
    final sold = all.where((s) => s.sold).toList();
    final groups = <String, List<double>>{};
    for (final s in inS) {
      final g = groups.putIfAbsent(s.item, () => [0, 0]);
      g[0] += 1;
      g[1] += s.net;
    }
    final top = groups.entries.toList()..sort((x, y) => y.value[0].compareTo(x.value[0]));
    return {
      'in_stock_pieces': inS.length,
      'in_stock_net_g': _w(inS.fold<double>(0, (t, s) => t + s.net)),
      'sold_pieces': sold.length,
      'sold_net_g': _w(sold.fold<double>(0, (t, s) => t + s.net)),
      'without_photo_in_stock': inS.where((s) => !s.photo).length,
      'top_items_in_stock': top.take(15).map((e) => {'item': e.key, 'pieces': e.value[0].toInt(), 'net_g': _w(e.value[1])}).toList(),
    };
  }

  static Future<Map<String, dynamic>> _topItems(Map<String, dynamic> a) async {
    final all = await GptStock.safe();
    final sold = (a['status'] ?? 'sold') == 'sold';
    final from = DateTime.tryParse('${a['from'] ?? ''}');
    final to = DateTime.tryParse('${a['to'] ?? ''}');
    final byW = a['by'] == 'weight';
    final rows = all.where((s) {
      if (s.sold != sold) return false;
      if (sold && (from != null || to != null)) {
        final d = s.soldOn;
        if (d == null) return false;
        if (from != null && d.isBefore(from)) return false;
        if (to != null && d.isAfter(to.add(const Duration(days: 1)))) return false;
      }
      return true;
    });
    final g = <String, List<double>>{};
    for (final s in rows) {
      final e = g.putIfAbsent(s.item, () => [0, 0]);
      e[0] += 1;
      e[1] += s.net;
    }
    final list = g.entries.toList()..sort((x, y) => (byW ? y.value[1].compareTo(x.value[1]) : y.value[0].compareTo(x.value[0])));
    final limit = (a['limit'] is num ? (a['limit'] as num).toInt() : 10).clamp(1, 40);
    return {
      'status': sold ? 'sold' : 'in_stock',
      if (sold && from == null && to == null) 'note': 'all time (no dates given)',
      if (sold && (from != null || to != null) && rows.isEmpty) 'note': 'no sold date in stock data for this range',
      'items': list.take(limit).map((e) => {'item': e.key, 'pieces': e.value[0].toInt(), 'net_g': _w(e.value[1])}).toList(),
    };
  }

  static Future<Map<String, dynamic>> _barcode(Map<String, dynamic> a) async {
    final code = '${a['code'] ?? ''}'.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final res = await ApiHelper().getRequest('${ApiConstants.Barcode_report}?code=$code', showLoading: false);
    final body = res?.data is String ? jsonDecode(res!.data) : res?.data;
    final list = (body is Map ? body['data'] : null) as List? ?? const [];
    final exact = list.whereType<Map>().where((e) => '${e['label_code'] ?? e['barcode']}'.toUpperCase() == code).toList();
    if (list.isEmpty) return {'found': false, 'code': code};
    return {'found': true, 'data': exact.isNotEmpty ? exact.first : list.first};
  }

  // ---------------- VOUCHERS ----------------
  static String _customerOf(Map m) {
    final c = m['customer'];
    if (c is Map) return '${c['name'] ?? ''}';
    return '${m['customer_name'] ?? c ?? m['party_name'] ?? ''}';
  }

  static DateTime? _parseDate(dynamic v) {
    final s = '${v ?? ''}'.trim();
    if (s.isEmpty) return null;
    final d = DateTime.tryParse(s.length >= 10 ? s.substring(0, 10) : s);
    if (d != null) return d;
    final m = RegExp(r'(\d{1,2})[-/](\d{1,2})[-/](\d{4})').firstMatch(s);
    return m == null ? null : DateTime(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
  }

  static List<Map> _rows(dynamic body) {
    if (body is String) body = jsonDecode(body);
    if (body is List) return body.whereType<Map>().toList();
    if (body is Map) {
      final d = body['data'];
      if (d is List) return d.whereType<Map>().toList();
      if (d is Map && d['data'] is List) return (d['data'] as List).whereType<Map>().toList();
    }
    return const [];
  }

  static Future<Map<String, dynamic>> _list(String endpoint, Map<String, dynamic> a,
      {bool sale = false, List<String> dateKeys = const ['date']}) async {
    final from = DateTime.tryParse('${a['from'] ?? ''}') ?? DateTime.now();
    final to = DateTime.tryParse('${a['to'] ?? ''}') ?? DateTime.now();
    final cust = '${a['customer'] ?? ''}'.trim().toLowerCase();
    final url = sale
        ? '$endpoint?columns=voucher_no,date,customer,qty_pcs,gross_weight,net_weight,net_total'
        '&from_date=${_ymd.format(from)}&to_date=${_ymd.format(to)}'
        : endpoint;
    final res = await ApiHelper().getRequest(url, showLoading: false, receiveTimeout: const Duration(seconds: 40));
    var rows = _rows(res?.data);
    rows = rows.where((r) {
      if (!sale) {
        DateTime? d;
        for (final k in dateKeys) {
          d ??= _parseDate(r[k]);
        }
        if (d == null) return false;
        final day = DateTime(d.year, d.month, d.day);
        if (day.isBefore(DateTime(from.year, from.month, from.day)) || day.isAfter(DateTime(to.year, to.month, to.day))) {
          return false;
        }
      }
      if (cust.isNotEmpty && !_customerOf(r).toLowerCase().contains(cust)) return false;
      return true;
    }).toList();

    // totals of every number column we can see
    final totals = <String, double>{};
    for (final r in rows) {
      r.forEach((k, v) {
        final key = '$k';
        if (RegExp(r'(weight|wt|amount|total|qty|pcs|items)', caseSensitive: false).hasMatch(key) && v is! Map && v is! List) {
          final d = double.tryParse('$v'.replaceAll(',', ''));
          if (d != null) totals[key] = (totals[key] ?? 0) + d;
        }
      });
    }
    return {
      'from': _dmy.format(from),
      'to': _dmy.format(to),
      if (cust.isNotEmpty) 'customer_filter': cust,
      'vouchers': rows.length,
      'totals': totals.map((k, v) => MapEntry(k, double.parse(v.toStringAsFixed(3)))),
      'rows': rows.take(60).map((r) {
        final m = <String, dynamic>{};
        r.forEach((k, v) {
          if (v is Map || v is List) return;
          m['$k'] = v;
        });
        m['customer'] = _customerOf(r);
        return m;
      }).toList(),
      if (rows.length > 60) 'note': 'showing 60 of ${rows.length}',
    };
  }

  static Future<Map<String, dynamic>> _voucherItems(Map<String, dynamic> a) async {
    final id = '${a['id'] ?? ''}';
    final url = switch (a['type']) {
      'sale' => '${ApiConstants.Sale_Summary_report}/$id/details?columns=label,item_name,qty_pcs,gross_weight,'
          'net_weight,metal_rate,metal_amount,labour_rate,labour_amount,other_amount,net_total',
      'approval' => '${ApiConstants.Approval_dailog_list}/$id',
      _ => '${ApiConstants.returns_vouchar}/$id',
    };
    final res = await ApiHelper().getRequest(url, showLoading: false, receiveTimeout: const Duration(seconds: 40));
    dynamic body = res?.data;
    if (body is String) body = jsonDecode(body);
    dynamic d = body is Map ? body['data'] : body;
    if (d is List && d.isNotEmpty && d.first is Map && (d.first as Map).containsKey('items')) d = d.first;
    List items = const [];
    if (d is Map) {
      for (final k in const ['items', 'details', 'item_details', 'rows']) {
        if (d[k] is List) {
          items = d[k] as List;
          break;
        }
      }
    } else if (d is List) {
      items = d;
    }
    return {
      'type': a['type'],
      'id': id,
      'items': items.whereType<Map>().take(80).map((r) {
        final m = <String, dynamic>{};
        r.forEach((k, v) {
          if (v is Map) {
            // nested item → keep its name
            if (v['item_name'] != null) m['item_name'] ??= v['item_name'];
            return;
          }
          if (v is List) return;
          m['$k'] = v;
        });
        return m;
      }).toList(),
    };
  }
}

import '../../../Api_Constant/ApiConstants.dart';
import '../../../Api_Constant/api_helper.dart';
import '../AskAI/core/ai_core.dart';

/// =======================================================================
///  📦 STOCK POSITION AI
///  API: GET reports/stock-position
///   → item × stock_type (Finished / Raw Material / Customer Received /
///     Repair) × customer : qty, gross, less, net, fine, labour, other
///
///  Udaharan:
///   • "Temple Ring"  / "bracelet ni position"   → item ni badhi vigat
///   • "badha kada wala"                          → Kada + Modern Kada + kada test
///   • "raw material" / "finished stock"          → e type na badha item
///   • "customer received" / "D test no maal"     → customer no maal
///   • "stock position" / "total"                 → aakho saransh
///  File: Ask AI/StockPosition/StockPositionAi.dart
/// =======================================================================
class StockPositionAi {
  static List<_Row>? _cache;
  static DateTime? _at;

  /// Chip vagar pan aa shabdo hoy to stock position j
  static const List<String> _trigger = [
    'stock position', 'position', 'raw material', 'kacho maal', 'kacho mal', 'finished', 'taiyar maal',
    'customer received', 'customer no maal', 'customer nu maal', 'grahak no maal', 'repair', 'fine weight',
    'less weight',
  ];

  static const Map<String, String> _typeWords = {
    'raw': 'raw_material', 'kacho': 'raw_material', 'kachu': 'raw_material',
    'finished': 'finished_item', 'finish': 'finished_item', 'taiyar': 'finished_item', 'tayar': 'finished_item',
    'customer received': 'customer_received', 'customer': 'customer_received', 'grahak': 'customer_received',
    'repair': 'repair', 'ripair': 'repair', 'scrap': 'scrap',
  };

  static Future<List<_Row>> _load({bool force = false}) async {
    if (!force && _cache != null && _at != null && DateTime.now().difference(_at!) < const Duration(minutes: 5)) {
      return _cache!;
    }
    final res = await ApiHelper().getRequest(ApiConstants.Stock_Position_report);
    final body = res?.data;
    if (body is! Map || body['success'] == false) {
      throw Exception(body is Map ? (body['message'] ?? 'Stock position load failed') : 'Stock position load failed');
    }
    _cache = (body['data'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => _Row.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    _at = DateTime.now();
    return _cache!;
  }

  static void clearCache() => _cache = null;

  /// [force] = "Stock Position" chip select che → badhu ahi j
  /// null = aa sawal stock position no nathi (bijo module javab aape)
  static Future<AiAnswer?> handle(String raw, {bool force = false}) async {
    final t = ' ${_norm(raw)} ';
    final bool asked = _trigger.any((w) => t.contains(' $w'));
    if (!force && !asked) return null;

    List<_Row> all;
    try {
      all = await _load(force: t.contains(' refresh'));
    } catch (e) {
      return AiAnswer(text: 'Stock position load na thayu.\n$e', speech: 'Stock position load na thayu.');
    }
    if (all.isEmpty) return const AiAnswer(text: 'Stock position ma koi data nathi.');

    // ---------- filter ----------
    final type = _detectType(t);
    final customers = all.where((r) => r.customerId != null).map((r) => r.customer).toSet().toList();
    final customer = _bestName(t, customers);
    final items = all.map((r) => r.item).toSet().toList();
    final bool groupMode = _has(t, ['badha', 'badhi', 'all', 'wala', 'vala', 'jeva', 'type na']);
    final List<String> itemHits = _matchItems(t, items, group: groupMode);

    if (itemHits.isNotEmpty) {
      final rows = all.where((r) => itemHits.contains(r.item)).toList();
      return itemHits.length == 1 ? _itemAnswer(itemHits.first, rows, all) : _groupAnswer(itemHits, rows, t);
    }
    if (customer != null) return _customerAnswer(customer, all.where((r) => r.customer == customer).toList());
    if (type != null) return _typeAnswer(type, all.where((r) => r.type == type).toList());
    if (force || _has(t, ['stock position', 'total', 'kul', 'saransh', 'summary', 'position'])) {
      return _summary(all);
    }
    return null;
  }

  // =====================================================================
  //  ANSWERS
  // =====================================================================

  /// Ek item (category) ni badhi vigat
  static AiAnswer _itemAnswer(String item, List<_Row> rows, List<_Row> all) {
    final t = _Tot.of(rows);
    final byType = _groupBy(rows, (r) => r.typeName);
    final cust = rows.where((r) => r.customerId != null).toList()..sort((a, b) => b.net.compareTo(a.net));
    final maxNet = rows.isEmpty ? 1.0 : rows.map((r) => r.net).reduce((a, b) => a > b ? a : b);
    final share = _Tot.of(all).net == 0 ? 0 : t.net / _Tot.of(all).net * 100;

    final parts = byType.entries.map((e) {
      final x = _Tot.of(e.value);
      return '${e.key} ${x.pcs} pcs · ${g(x.net)} g';
    }).join(' | ');

    return AiAnswer(
      text: '$item — kul ${t.pcs} pcs, net ${g(t.net)} g (fine ${g(t.fine)} g).\n$parts.'
          '${cust.isNotEmpty ? '\nCustomer no maal: ${cust.map((c) => c.customer).toSet().length} customer, ${g(_Tot.of(cust).net)} g.' : ''}'
          '\nAakha stock no ${share.toStringAsFixed(1)}%.',
      speech: '$item, kul ${t.pcs} piece, ${g(t.net).replaceAll(',', '')} gram net.',
      stats: _stats(t),
      sections: [
        AiSection(
          'Stock type mujab',
          byType.entries.map((e) {
            final x = _Tot.of(e.value);
            return AiRow(
              '${_icon(e.value.first.type)} ${e.key}',
              '${g(x.net)} g',
              sub: '${x.pcs} pcs · gross ${g(x.gross)} · less ${g(x.less)} · fine ${g(x.fine)}'
                  '${x.labour + x.other > 0 ? ' · ₹${g0(x.labour + x.other)}' : ''}',
              bar: t.net == 0 ? 0 : x.net / t.net,
            );
          }).toList(),
        ),
        if (cust.isNotEmpty)
          AiSection(
            'Customer Received (customer mujab)',
            cust
                .map((c) => AiRow(
              '👤 ${c.customer}',
              '${g(c.net)} g',
              sub: '${c.pcs} pcs · fine ${g(c.fine)} · ${_date(c.createdAt)}',
              bar: c.net / maxNet,
              askOnTap: '${c.customer} no maal',
            ))
                .toList(),
          ),
      ],
      items: rows.map(_record).toList(),
      itemsTitle: '$item — badhi entry',
      filterLabel: item,
      followUps: [
        if (rows.any((r) => r.type == 'raw_material')) 'Raw material stock position',
        if (cust.isNotEmpty) 'Customer received stock',
        'Stock position total',
      ],
    );
  }

  /// "badha kada wala" → ghana item sathe
  static AiAnswer _groupAnswer(List<String> names, List<_Row> rows, String t) {
    final tot = _Tot.of(rows);
    final byItem = _groupBy(rows, (r) => r.item).entries.toList()
      ..sort((a, b) => _Tot.of(b.value).net.compareTo(_Tot.of(a.value).net));
    final maxNet = byItem.isEmpty ? 1.0 : _Tot.of(byItem.first.value).net;
    return AiAnswer(
      text: '${names.length} item male che — kul ${tot.pcs} pcs, net ${g(tot.net)} g (fine ${g(tot.fine)} g).',
      speech: '${names.length} item, kul ${g(tot.net).replaceAll(',', '')} gram.',
      stats: _stats(tot),
      sections: [
        AiSection(
          'Item mujab',
          byItem.map((e) {
            final x = _Tot.of(e.value);
            final types = e.value.map((r) => r.typeName).toSet().join(', ');
            return AiRow(e.key, '${g(x.net)} g',
                sub: '${x.pcs} pcs · $types', bar: maxNet == 0 ? 0 : x.net / maxNet, askOnTap: e.key);
          }).toList(),
        ),
        _typeSection(rows),
      ],
      items: rows.map(_record).toList(),
      itemsTitle: 'Badhi entry',
      followUps: byItem.take(3).map((e) => e.key).toList(),
    );
  }

  static AiAnswer _typeAnswer(String type, List<_Row> rows) {
    final name = rows.isNotEmpty ? rows.first.typeName : type;
    if (rows.isEmpty) return AiAnswer(text: '$name ma koi stock nathi.');
    final tot = _Tot.of(rows);
    final byItem = _groupBy(rows, (r) => r.item).entries.toList()
      ..sort((a, b) => _Tot.of(b.value).net.compareTo(_Tot.of(a.value).net));
    final maxNet = _Tot.of(byItem.first.value).net;
    return AiAnswer(
      text: '$name: ${byItem.length} item, ${tot.pcs} pcs, net ${g(tot.net)} g (fine ${g(tot.fine)} g). '
          'Sauthi vadhu ${byItem.first.key} — ${g(_Tot.of(byItem.first.value).net)} g.',
      speech: '$name ma ${byItem.length} item, ${g(tot.net).replaceAll(',', '')} gram.',
      stats: _stats(tot),
      sections: [
        AiSection(
          '$name — item mujab',
          byItem.map((e) {
            final x = _Tot.of(e.value);
            return AiRow(e.key, '${g(x.net)} g',
                sub: '${x.pcs} pcs · fine ${g(x.fine)}'
                    '${type == 'customer_received' ? ' · ${e.value.map((r) => r.customer).toSet().join(', ')}' : ''}',
                bar: maxNet == 0 ? 0 : x.net / maxNet,
                askOnTap: e.key);
          }).toList(),
        ),
        if (type == 'customer_received') _customerSection(rows),
      ],
      items: rows.map(_record).toList(),
      itemsTitle: '$name — entry',
      followUps: ['Stock position total', if (type != 'raw_material') 'Raw material', if (type != 'finished_item') 'Finished stock'],
    );
  }

  static AiAnswer _customerAnswer(String customer, List<_Row> rows) {
    final tot = _Tot.of(rows);
    return AiAnswer(
      text: '$customer no maal (Customer Received): ${rows.length} entry, ${tot.pcs} pcs, '
          'net ${g(tot.net)} g, fine ${g(tot.fine)} g.\n'
          '${rows.map((r) => '${r.item} ${g(r.net)} g').join(', ')}.',
      speech: '$customer no ${g(tot.net).replaceAll(',', '')} gram maal che.',
      stats: _stats(tot),
      sections: [
        AiSection(
          'Item mujab',
          rows
              .map((r) => AiRow(r.item, '${g(r.net)} g',
              sub: '${r.pcs} pcs · fine ${g(r.fine)} · ${_date(r.createdAt)}', askOnTap: r.item))
              .toList(),
        ),
      ],
      items: rows.map(_record).toList(),
      itemsTitle: '$customer — entry',
      filterLabel: customer,
      followUps: ['Customer received stock', 'Stock position total'],
    );
  }

  static AiAnswer _summary(List<_Row> all) {
    final tot = _Tot.of(all);
    final byItem = _groupBy(all, (r) => r.item).entries.toList()
      ..sort((a, b) => _Tot.of(b.value).net.compareTo(_Tot.of(a.value).net));
    final maxNet = byItem.isEmpty ? 1.0 : _Tot.of(byItem.first.value).net;
    return AiAnswer(
      text: 'Stock position: ${byItem.length} item, ${tot.pcs} pcs, net ${g(tot.net)} g (fine ${g(tot.fine)} g). '
          'Sauthi vadhu ${byItem.first.key} — ${g(_Tot.of(byItem.first.value).net)} g.\n'
          'Koi pan item nu naam bolo — enu badhu batavish.',
      speech: 'Kul ${byItem.length} item, ${g(tot.net).replaceAll(',', '')} gram net.',
      stats: _stats(tot),
      sections: [
        _typeSection(all),
        AiSection(
          'Item mujab (vadhu weight pehla)',
          byItem.map((e) {
            final x = _Tot.of(e.value);
            return AiRow(e.key, '${g(x.net)} g',
                sub: '${x.pcs} pcs · ${e.value.map((r) => r.typeName).toSet().join(', ')}',
                bar: maxNet == 0 ? 0 : x.net / maxNet,
                askOnTap: e.key);
          }).toList(),
        ),
        _customerSection(all.where((r) => r.customerId != null).toList()),
      ],
      followUps: ['Raw material', 'Finished stock', 'Customer received stock', if (byItem.isNotEmpty) byItem.first.key],
    );
  }

  // =====================================================================
  //  HELPERS
  // =====================================================================

  static AiSection _typeSection(List<_Row> rows) {
    final t = _Tot.of(rows);
    final g0m = _groupBy(rows, (r) => r.typeName);
    return AiSection(
      'Stock type mujab',
      g0m.entries.map((e) {
        final x = _Tot.of(e.value);
        return AiRow('${_icon(e.value.first.type)} ${e.key}', '${g(x.net)} g',
            sub: '${e.value.map((r) => r.item).toSet().length} item · ${x.pcs} pcs · fine ${g(x.fine)}',
            bar: t.net == 0 ? 0 : x.net / t.net,
            askOnTap: e.key);
      }).toList(),
    );
  }

  static AiSection _customerSection(List<_Row> rows) {
    final byC = _groupBy(rows, (r) => r.customer).entries.toList()
      ..sort((a, b) => _Tot.of(b.value).net.compareTo(_Tot.of(a.value).net));
    final maxNet = byC.isEmpty ? 1.0 : _Tot.of(byC.first.value).net;
    return AiSection(
      'Customer no maal',
      byC.map((e) {
        final x = _Tot.of(e.value);
        return AiRow('👤 ${e.key}', '${g(x.net)} g',
            sub: '${e.value.map((r) => r.item).join(', ')} · fine ${g(x.fine)}',
            bar: maxNet == 0 ? 0 : x.net / maxNet,
            askOnTap: '${e.key} no maal');
      }).toList(),
    );
  }

  static List<AiStat> _stats(_Tot t) => [
    AiStat('Pcs', '${t.pcs}'),
    AiStat('Gross', '${g(t.gross)} g'),
    if (t.less > 0) AiStat('Less', '${g(t.less)} g'),
    AiStat('Net', '${g(t.net)} g'),
    AiStat('Fine', '${g(t.fine)} g'),
    if (t.labour > 0) AiStat('Labour', '₹${g0(t.labour)}'),
    if (t.other > 0) AiStat('Other', '₹${g0(t.other)}'),
  ];

  static AiRecord _record(_Row r) => AiRecord(
    title: r.item,
    subtitle: '${r.typeName}${r.customerId != null ? ' · ${r.customer}' : ''} · ${_date(r.createdAt)}',
    value: '${g(r.net)} g',
    badge: '${r.pcs} pcs',
    badgeGood: r.type != 'repair',
    details: [
      AiStat('Item', r.item),
      AiStat('Stock Type', r.typeName),
      if (r.customerId != null) AiStat('Customer', r.customer),
      AiStat('Qty', '${r.pcs} pcs'),
      AiStat('Gross', '${g(r.gross)} g'),
      AiStat('Less', '${g(r.less)} g'),
      AiStat('Net', '${g(r.net)} g'),
      AiStat('Fine', '${g(r.fine)} g'),
      AiStat('Labour', '₹${g0(r.labour)}'),
      AiStat('Other', '₹${g0(r.other)}'),
      AiStat('Date', _date(r.createdAt)),
    ],
  );

  static String _icon(String type) {
    switch (type) {
      case 'finished_item':
        return '💎';
      case 'raw_material':
        return '🧱';
      case 'customer_received':
        return '👤';
      case 'repair':
        return '🔧';
      default:
        return '📦';
    }
  }

  static String? _detectType(String t) {
    final keys = _typeWords.keys.toList()..sort((a, b) => b.length - a.length);
    for (final k in keys) {
      if (t.contains(' $k')) return _typeWords[k];
    }
    return null;
  }

  /// Item naam: pura naam pehla ("modern kada"), "badha … wala" hoy to shabd thi badha
  static List<String> _matchItems(String t, List<String> items, {required bool group}) {
    final full = items.where((n) {
      final k = _norm(n);
      return k.length >= 2 && t.contains(' $k ');
    }).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    if (full.isNotEmpty && !group) {
      final best = full.first;
      // "Ring test" ane "Ring Test" bey hoy to bey
      return items.where((n) => _norm(n) == _norm(best)).toList();
    }
    const stop = {
      'stock', 'position', 'item', 'badha', 'badhi', 'wala', 'vala', 'all', 'maal', 'mal', 'ni', 'nu', 'no', 'na',
      'che', 'batav', 'raw', 'material', 'finished', 'customer', 'received', 'repair', 'kul', 'total', 'test',
    };
    final tokens = t.trim().split(' ').where((w) => w.length >= 3 && !stop.contains(w)).toSet();
    if (tokens.isEmpty) return full;
    final hits = items.where((n) => _norm(n).split(' ').any(tokens.contains)).toList();
    return hits.isNotEmpty ? hits : full;
  }

  static String? _bestName(String t, List<String> names) {
    String? best;
    for (final n in names) {
      final k = _norm(n);
      if (k.length >= 3 && t.contains(' $k ') && (best == null || n.length > best.length)) best = n;
    }
    return best;
  }

  static bool _has(String t, List<String> w) => w.any((x) => t.contains(' $x'));

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9઀-૿\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  static Map<String, List<_Row>> _groupBy(List<_Row> l, String Function(_Row) k) {
    final m = <String, List<_Row>>{};
    for (final r in l) {
      m.putIfAbsent(k(r), () => []).add(r);
    }
    return m;
  }

  static String g(double v) {
    final s = v.toStringAsFixed(3);
    return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  static String g0(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  static String _date(DateTime? d) =>
      d == null ? '-' : '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
}

class _Row {
  final int? itemId;
  final String item;
  final String type;
  final String typeName;
  final int? customerId;
  final String customer;
  final int pcs;
  final double gross, less, net, fine, labour, other;
  final DateTime? createdAt;

  _Row({
    this.itemId,
    required this.item,
    required this.type,
    required this.typeName,
    this.customerId,
    required this.customer,
    required this.pcs,
    required this.gross,
    required this.less,
    required this.net,
    required this.fine,
    required this.labour,
    required this.other,
    this.createdAt,
  });

  factory _Row.fromJson(Map<String, dynamic> j) {
    double d(String k) => double.tryParse(j[k]?.toString() ?? '') ?? 0;
    return _Row(
      itemId: int.tryParse(j['item_id']?.toString() ?? ''),
      item: (j['item_name'] ?? '-').toString().trim(),
      type: (j['stock_type'] ?? '').toString(),
      typeName: (j['stock_type_name'] ?? j['stock_type'] ?? '-').toString(),
      customerId: int.tryParse(j['customer_id']?.toString() ?? ''),
      customer: (j['customer_name'] ?? '-').toString(),
      pcs: (double.tryParse(j['qty_pcs']?.toString() ?? '') ?? 0).round(),
      gross: d('gross_weight'),
      less: d('less_weight'),
      net: d('net_weight'),
      fine: d('fine_weight'),
      labour: d('labour_amount'),
      other: d('other_amount'),
      createdAt: DateTime.tryParse(j['created_at']?.toString() ?? ''),
    );
  }
}

class _Tot {
  int pcs = 0;
  double gross = 0, less = 0, net = 0, fine = 0, labour = 0, other = 0;

  static _Tot of(Iterable<_Row> l) {
    final t = _Tot();
    for (final r in l) {
      t.pcs += r.pcs;
      t.gross += r.gross;
      t.less += r.less;
      t.net += r.net;
      t.fine += r.fine;
      t.labour += r.labour;
      t.other += r.other;
    }
    return t;
  }
}
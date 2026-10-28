import '../../../Api_Constant/ApiConstants.dart';
import '../../../Api_Constant/api_helper.dart';
import '../../VoucherDetails.dart';
import '../core/AiDateRange.dart';
import '../core/ai_core.dart';

/// =======================================================================
///  📅 DATE AI — "aaje ketlo stock umerayo?" / "kale ketlu vechayu?"
///
///   • "aje ketlo stock umerayo"          → aaje umerayelo stock (item mujab)
///   • "parmdivase ketla label banya"     → parmdivase no navo stock
///   • "kale ketlu vechayu" / "कल कितना बिका" / "yesterday sale"
///   • "aa athvadiye ketlo maal aavyo" / "aa mahine nu vechan"
///   • "12-10-2026 nu sale" / "12 october ma ketlu vechayu"
///
///  Stock umerayo  → stock-gallery (created_at / label_date …)
///                   na hoy to reports/stock-position (created_at)
///  Vechayu        → reports/sales-summary?from_date=&to_date=
///  File: Ask AI/Date/DateAi.dart
/// =======================================================================
class DateAi {
  // ---- shabdo (AiDateWords.normalize pachhi na latin) ----
  static const List<String> _addWords = [
    'umerayo', 'umeryo', 'umerya', 'umeraya', 'umeryu', 'umerayu', 'umera', 'umrayo', 'umeriyo', 'umero', 'umeri',
    'aavyo', 'aavya', 'aavyu', 'avyo', 'avya', 'avyu', 'aaya', 'aya', 'aaye', 'added', 'add', 'inward', 'jama',
    'navo', 'nava', 'navu', 'navi', 'new', 'banyo', 'banya', 'banyu', 'bana', 'bane', 'label banya', 'label banyo',
    'label bana', 'label', 'labels', 'joda', 'jode', 'jodyo', 'jodya', 'entry', 'entri', 'create', 'created',
    'taiyar', 'tayar', 'ready', 'stock in', 'aayo', 'ayo',
  ];
  static const List<String> _sellWords = [
    'vechayu', 'vechayo', 'vechaya', 'vechai', 'vechay', 'vechan', 'vechanu', 'vechyu', 'vechya', 'vechi', 'vecha',
    'sale', 'sales', 'sell', 'sold', 'selling', 'bikri', 'bika', 'bike', 'biki', 'becha', 'beche', 'vikri',
    'bill', 'bills', 'invoice', 'vakrai', 'vechel', 'vechayel',
  ];
  static const List<String> _stockWords = ['stock', 'maal', 'mal', 'item', 'items', 'piece', 'pcs', 'nang', 'label'];

  /// null = aa date no sawal nathi (bijo module javab aape)
  /// [moduleId] = upar kayo chip select che ('stock' / 'sales' / …)
  static Future<AiAnswer?> handle(String raw, {String? moduleId}) async {
    final period = AiDateWords.parse(raw);
    if (period == null) return null;
    final t = ' ${AiDateWords.normalize(raw)} ';
    bool has(List<String> w) => w.any((x) => t.contains(' $x '));

    // approval / worker loss / job work na sawal e module j aape
    if (has(const ['approval', 'aproval', 'apruval', 'worker', 'karigar', 'loss', 'ghat', 'job', 'jobwork', 'ledger',
      'return', 'retun'])) {
      return null;
    }
    final sell = has(_sellWords);
    final add = has(_addWords);
    final stock = has(_stockWords);

    if (sell && !add) return _sales(period, raw);
    if (add || (stock && moduleId != 'sales')) return _stockAdded(period, raw);
    if (moduleId == 'sales') return _sales(period, raw);
    if (moduleId == 'stock') return _stockAdded(period, raw);
    return null; // approval / worker loss → e module potani rite
  }

  /// Mic na alternates mathi sacho andaj pasand karva (vadhu = vadhu sacho)
  static int relevance(String raw) {
    final t = ' ${AiDateWords.normalize(raw)} ';
    var s = 0;
    if (AiDateWords.parse(raw) != null) s += 2;
    if (_addWords.any((x) => t.contains(' $x '))) s += 1;
    if (_sellWords.any((x) => t.contains(' $x '))) s += 1;
    if (_stockWords.any((x) => t.contains(' $x '))) s += 1;
    return s;
  }

  // =====================================================================
  //  📦 STOCK UMERAYO
  // =====================================================================
  static List<_Stk>? _stock;
  static String _stockSource = '';
  static DateTime? _stockAt;

  static Future<AiAnswer> _stockAdded(AiDateRange p, String raw) async {
    List<_Stk> all;
    try {
      all = await _loadStock();
    } catch (e) {
      return AiAnswer(text: 'Stock load na thayo.\n$e', speech: 'Stock load na thayo.');
    }
    if (all.isEmpty) {
      return const AiAnswer(
        text: '⚠️ Stock ma tarikh (date) j nathi aavti — etle "aaje ketlo umerayo" gani shakato nathi.\n'
            'Backend ma stock-gallery API na darek item ma "created_at" (label banyu te tarikh) umero, '
            'pachhi aa sawal sacho javab aapse.',
        speech: 'Stock ma tarikh nathi aavti, backend ma created at umero.',
      );
    }

    final t = ' ${AiDateWords.normalize(raw)} ';
    // item nu naam bolya hoy to e j ("aaje ketli ring umerai")
    final names = all.map((e) => e.item).toSet();
    final hitNames = names.where((n) {
      final k = n.toLowerCase().trim();
      if (k.length < 3) return false;
      if (t.contains(' $k ')) return true;
      return k.split(RegExp(r'\s+')).any((w) => w.length >= 4 && t.contains(' $w '));
    }).toSet();

    final inP = all.where((e) => p.contains(e.date) && (hitNames.isEmpty || hitNames.contains(e.item))).toList()
      ..sort((a, b) => b.date!.compareTo(a.date!));
    final prevP = p.previous;
    final prev = all.where((e) => prevP.contains(e.date) && (hitNames.isEmpty || hitNames.contains(e.item)));
    final what = hitNames.isEmpty ? 'stock' : hitNames.join(', ');

    if (inP.isEmpty) {
      final older = all.where((e) => e.date != null && e.date!.isBefore(p.from)).toList()
        ..sort((a, b) => b.date!.compareTo(a.date!));
      String last = '';
      if (older.isNotEmpty) {
        final d = older.first.date!;
        final same = older.where((e) => _sameDay(e.date!, d));
        last = '\nChhello $what ${AiDateRange.fmt(d)} e umerayo hato — ${_pcs(same)} pcs, ${g(_net(same))} g.';
      }
      return AiAnswer(
        text: '📅 ${p.title}: koi navo $what umerayo nathi.$last',
        speech: '${p.label} koi navo $what umerayo nathi.',
        filterLabel: '📅 ${p.title}',
        followUps: _followAdd(p),
      );
    }

    final pcs = _pcs(inP), net = _net(inP), gross = _gross(inP);
    final prevPcs = _pcs(prev);
    final diff = pcs - prevPcs;
    final cmp = prevPcs == 0 && diff == 0
        ? ''
        : ' (${prevP.label} karta ${diff >= 0 ? '+' : ''}$diff pcs)';

    final byItem = _group(inP, (e) => e.item).entries.toList()
      ..sort((a, b) => _net(b.value).compareTo(_net(a.value)));
    final maxNet = byItem.isEmpty ? 1.0 : _net(byItem.first.value);

    final timeSecs = _timeSections<_Stk>(
      p,
      inP,
          (e) => e.date,
          (l) => _net(l),
          (l) => '${_pcs(l)} pcs',
          (l) => 'net ${g(_net(l))} g',
          (when) => '$when ketlo stock umerayo',
    );

    return AiAnswer(
      text: '📅 ${p.title} ${_pcs(inP)} pcs $what umerayo$cmp.\n'
          '${_bestMonthLine(p, inP, (e) => e.date, (l) => _net(l), (l) => '${_pcs(l)} pcs, ${g(_net(l))} g')}'
          'Net ${g(net)} g · gross ${g(gross)} g · ${byItem.length} item.\n'
          'Sauthi vadhu ${byItem.first.key} — ${_pcs(byItem.first.value)} pcs, ${g(_net(byItem.first.value))} g.'
          '${_stockSource == 'position' ? '\n(Stock Position ni entry tarikh mujab)' : ''}',
      speech: '${p.label} $pcs piece $what umerayo, ${g(net).replaceAll(',', '')} gram net.',
      stats: [
        AiStat('Pcs', '$pcs'),
        AiStat('Net', '${g(net)} g'),
        AiStat('Gross', '${g(gross)} g'),
        AiStat('Item', '${byItem.length}'),
        if (prevPcs > 0 || diff != 0) AiStat(prevP.label, '$prevPcs pcs'),
      ],
      sections: [
        AiSection(
          'Item mujab (${p.label})',
          byItem
              .map((e) => AiRow(
            e.key,
            '${g(_net(e.value))} g',
            sub: '${_pcs(e.value)} pcs · gross ${g(_gross(e.value))} g',
            bar: maxNet == 0 ? 0 : _net(e.value) / maxNet,
            askOnTap: '${p.label} ${e.key} ketla umerayo',
          ))
              .toList(),
        ),
        ...timeSecs,
      ],
      items: inP.map((e) => e.record()).toList(),
      itemsTitle: '${p.label} umerayela',
      filterLabel: '📅 ${p.title}${hitNames.isEmpty ? '' : ' · $what'}',
      followUps: _followAdd(p),
    );
  }

  static List<String> _followAdd(AiDateRange p) => [
    if (p.key != 'today') 'Aaje ketlo stock umerayo',
    if (p.key != 'yesterday') 'Kale ketlo stock umerayo',
    '${p.label} ketlu vechayu',
    if (p.key != 'this_week') 'Aa athvadiye ketlo stock umerayo',
    if (p.key != 'this_month') 'Aa mahine ketlo stock umerayo',
  ];

  /// 1) stock-gallery ma tarikh hoy to e (darek label alag)
  /// 2) nahi to stock-position na created_at
  static Future<List<_Stk>> _loadStock() async {
    if (_stock != null && _stockAt != null && DateTime.now().difference(_stockAt!) < const Duration(minutes: 5)) {
      return _stock!;
    }
    final gallery = await _loadGallery();
    if (gallery.isNotEmpty) {
      _stockSource = 'gallery';
      _stock = gallery;
    } else {
      _stockSource = 'position';
      _stock = await _loadPosition();
    }
    _stockAt = DateTime.now();
    return _stock!;
  }

  static const List<String> _dateKeys = [
    'created_at', 'label_created_at', 'label_date', 'stock_date', 'purchase_date', 'inward_date', 'date', 'added_on',
  ];

  static Future<List<_Stk>> _loadGallery() async {
    Future<Map?> page(int p) async {
      final res = await ApiHelper().getRequest('${ApiConstants.stock_gallery}?page=$p&per_page=200');
      final b = res?.data;
      return b is Map ? b : null;
    }

    final first = await page(1);
    if (first == null || first['success'] == false) return [];
    final rows = <Map>[...(first['data'] as List? ?? const []).whereType<Map>()];
    // pehla page ma j tarikh nathi → aakhu load karvu nakamu
    if (!rows.any((r) => _dateKeys.any((k) => _date(r[k]) != null))) return [];

    final pg = first['pagination'] is Map ? first['pagination'] as Map : const {};
    final last = int.tryParse(pg['last_page']?.toString() ?? '1') ?? 1;
    for (var p = 2; p <= last; p += 6) {
      final batch = await Future.wait([
        for (var i = p; i < p + 6 && i <= last; i++) page(i),
      ]);
      for (final b in batch) {
        rows.addAll((b?['data'] as List? ?? const []).whereType<Map>());
      }
    }
    return rows.map((r) {
      DateTime? d;
      for (final k in _dateKeys) {
        d ??= _date(r[k]);
      }
      return _Stk(
        item: (r['item_name'] ?? '-').toString().trim(),
        code: (r['label_code'] ?? r['barcode'] ?? '').toString(),
        pcs: 1,
        net: _d(r['net_weight']),
        gross: _d(r['gross_weight']),
        date: d,
        image: r['image_url']?.toString(),
        sold: r['is_sold'] == true || r['is_sold']?.toString() == '1' || r['stock_status']?.toString() == 'sold',
      );
    }).where((e) => e.date != null).toList();
  }

  static Future<List<_Stk>> _loadPosition() async {
    final res = await ApiHelper().getRequest(ApiConstants.Stock_Position_report);
    final b = res?.data;
    if (b is! Map || b['success'] == false) return [];
    return (b['data'] as List? ?? const [])
        .whereType<Map>()
        .where((r) => (r['stock_type'] ?? '').toString() != 'customer_received')
        .map((r) => _Stk(
      item: (r['item_name'] ?? '-').toString().trim(),
      code: (r['stock_type_name'] ?? '').toString(),
      pcs: (double.tryParse(r['qty_pcs']?.toString() ?? '') ?? 0).round(),
      net: _d(r['net_weight']),
      gross: _d(r['gross_weight']),
      date: _date(r['created_at']),
    ))
        .where((e) => e.date != null)
        .toList();
  }

  // =====================================================================
  //  🧾 VECHAYU (sales-summary)
  // =====================================================================
  static Future<AiAnswer> _sales(AiDateRange p, String raw) async {
    List<Map> rows;
    try {
      rows = await _loadSales(p);
    } catch (e) {
      return AiAnswer(text: 'Sale load na thayu.\n$e', speech: 'Sale load na thayu.');
    }
    // server filter na kare to pan ahi tarikh thi gali lo
    rows = rows.where((r) {
      final d = _date(r['date'] ?? r['sale_date'] ?? r['created_at']);
      return d == null || p.contains(d);
    }).toList();

    final prevP = p.previous;
    int prevCount = 0;
    double prevAmt = 0;
    try {
      final pr = (await _loadSales(prevP)).where((r) {
        final d = _date(r['date'] ?? r['sale_date'] ?? r['created_at']);
        return d == null || prevP.contains(d);
      });
      prevCount = pr.length;
      prevAmt = pr.fold(0.0, (a, r) => a + _d(r['net_total']));
    } catch (_) {}

    if (rows.isEmpty) {
      return AiAnswer(
        text: '📅 ${p.title}: koi sale thayu nathi.'
            '${prevCount > 0 ? '\n${prevP.label}: $prevCount bill, ₹${g0(prevAmt)}.' : ''}',
        speech: '${p.label} koi sale thayu nathi.',
        filterLabel: '📅 ${p.title}',
        followUps: _followSale(p),
      );
    }

    double sum(String k) => rows.fold(0.0, (a, r) => a + _d(r[k]));
    final pcs = sum('qty_pcs').round();
    final net = sum('net_weight'), fine = sum('fine_weight'), amt = sum('net_total');
    String cust(Map r) => (r['customer'] ?? r['customer_name'] ?? '-').toString();

    final byCust = <String, List<Map>>{};
    for (final r in rows) {
      byCust.putIfAbsent(cust(r), () => []).add(r);
    }
    final cs = byCust.entries.toList()
      ..sort((a, b) => b.value.fold(0.0, (x, r) => x + _d(r['net_total'])).compareTo(
          a.value.fold(0.0, (x, r) => x + _d(r['net_total']))));
    final maxAmt = cs.isEmpty ? 1.0 : cs.first.value.fold(0.0, (x, r) => x + _d(r['net_total']));
    final diff = amt - prevAmt;

    return AiAnswer(
      text: '📅 ${p.title} ${rows.length} bill — $pcs pcs, net ${g(net)} g, ₹${g0(amt)}.'
          '${_bestMonthLine(p, rows, (r) => _date(r['date'] ?? r['sale_date'] ?? r['created_at']), (l) => l.fold(0.0, (x, r) => x + _d(r['net_total'])), (l) => '₹${g0(l.fold(0.0, (x, r) => x + _d(r['net_total'])))}', prefix: '\n')}'
          '${prevCount > 0 || prevAmt > 0 ? '\n${prevP.label} karta ${diff >= 0 ? '+' : '-'}₹${g0(diff.abs())}.' : ''}\n'
          'Bill par tap karo — puri detail khulse.',
      speech: '${p.label} ${rows.length} bill, $pcs piece, ${g(net).replaceAll(',', '')} gram vechayu.',
      stats: [
        AiStat('Bill', '${rows.length}'),
        AiStat('Pcs', '$pcs'),
        AiStat('Net', '${g(net)} g'),
        if (fine > 0) AiStat('Fine', '${g(fine)} g'),
        AiStat('Rakam', '₹${g0(amt)}'),
        if (prevCount > 0) AiStat(prevP.label, '$prevCount bill'),
      ],
      sections: [
        ..._timeSections<Map>(
          p,
          rows,
              (r) => _date(r['date'] ?? r['sale_date'] ?? r['created_at']),
              (l) => l.fold(0.0, (x, r) => x + _d(r['net_total'])),
              (l) => '₹${g0(l.fold(0.0, (x, r) => x + _d(r['net_total'])))}',
              (l) => '${l.length} bill · ${g(l.fold(0.0, (x, r) => x + _d(r['net_weight'])))} g',
              (when) => '$when ketlu vechayu',
        ),
        AiSection(
          'Customer mujab',
          cs.map((e) {
            final a = e.value.fold(0.0, (x, r) => x + _d(r['net_total']));
            final n = e.value.fold(0.0, (x, r) => x + _d(r['net_weight']));
            return AiRow('👤 ${e.key}', '₹${g0(a)}',
                sub: '${e.value.length} bill · ${g(n)} g', bar: maxAmt == 0 ? 0 : a / maxAmt);
          }).toList(),
        ),
      ],
      items: rows.map((r) => _saleRecord(r, cust(r))).toList(),
      itemsTitle: '${p.label} na bill',
      filterLabel: '📅 ${p.title}',
      followUps: _followSale(p),
    );
  }

  static List<String> _followSale(AiDateRange p) => [
    if (p.key != 'today') 'Aaje ketlu vechayu',
    if (p.key != 'yesterday') 'Kale ketlu vechayu',
    if (p.key != 'dby') 'Parmdivase ketlu vechayu',
    '${p.label} ketlo stock umerayo',
    if (p.key != 'this_month') 'Aa mahine ketlu vechayu',
  ];

  static final Map<String, List<Map>> _salesCache = {};

  static Future<List<Map>> _loadSales(AiDateRange p) async {
    final key = '${p.apiFrom}_${p.apiTo}';
    if (_salesCache.containsKey(key) && p.key != 'today') return _salesCache[key]!;
    final url = Uri.parse(ApiConstants.Sale_Summary_report)
        .replace(queryParameters: {'from_date': p.apiFrom, 'to_date': p.apiTo}).toString();
    final res = await ApiHelper().getRequest(url);
    final b = res?.data;
    if (b is! Map || b['success'] == false) {
      throw Exception(b is Map ? (b['message'] ?? 'Sale summary load failed') : 'Sale summary load failed');
    }
    final rows = (b['data'] as List? ?? const []).whereType<Map>().toList();
    _salesCache[key] = rows;
    return rows;
  }

  static AiRecord _saleRecord(Map r, String customer) {
    final vno = (r['voucher_no'] ?? r['invoice_no'] ?? r['bill_no'] ?? '-').toString();
    final d = _date(r['date'] ?? r['sale_date'] ?? r['created_at']);
    final id = (r['id'] ?? r['voucher_id'] ?? r['sales_summary_id'] ?? r['sale_id'])?.toString() ?? '';
    final rec = AiRecord(
      title: '🧾 $vno',
      subtitle: '$customer${d != null ? ' · ${AiDateRange.fmt(d)}' : ''}',
      value: '₹${g0(_d(r['net_total']))}',
      badge: '${g(_d(r['net_weight']))} g',
      badgeGood: true,
      details: [
        AiStat('Voucher', vno),
        AiStat('Customer', customer),
        if (d != null) AiStat('Date', AiDateRange.fmt(d)),
        AiStat('Pcs', '${_d(r['qty_pcs']).round()}'),
        AiStat('Gross', '${g(_d(r['gross_weight']))} g'),
        AiStat('Net', '${g(_d(r['net_weight']))} g'),
        AiStat('Fine', '${g(_d(r['fine_weight']))} g'),
        AiStat('Rakam', '₹${g0(_d(r['net_total']))}'),
      ],
    );
    if (id.isEmpty) return rec;
    return VoucherDetails.attachVoucher(
      rec,
      VoucherRef(
        module: 'sales',
        id: id,
        voucherNo: vno,
        info: [
          MapEntry('Customer', customer),
          if (d != null) MapEntry('Date', AiDateRange.fmt(d)),
        ],
      ),
    );
  }

  // =====================================================================
  //  HELPERS
  // =====================================================================
  static void clearCache() {
    _stock = null;
    _salesCache.clear();
  }

  // =====================================================================
  //  📆 SAMAY MUJAB: divas / mahina / varsh
  //   • 31 divas sudhi      → Divas mujab
  //   • vadhu               → Mahina mujab (january … september, khali mahina pan)
  //   • 1 varsh thi vadhu   → Varsh mujab pan
  // =====================================================================
  static List<AiSection> _timeSections<T>(
      AiDateRange p,
      List<T> rows,
      DateTime? Function(T) dateOf,
      double Function(List<T>) val,
      String Function(List<T>) valText,
      String Function(List<T>) sub,
      String Function(String when) ask,
      ) {
    final dated = rows.where((r) => dateOf(r) != null).toList();
    if (dated.isEmpty) return const [];
    final out = <AiSection>[];

    if (p.spanDays <= 31) {
      final byDay = <String, List<T>>{};
      for (final r in dated..sort((a, b) => dateOf(a)!.compareTo(dateOf(b)!))) {
        byDay.putIfAbsent(AiDateRange.fmt(dateOf(r)!), () => []).add(r);
      }
      if (byDay.length > 1) {
        final mx = byDay.values.map(val).fold(0.0, (a, b) => a > b ? a : b);
        out.add(AiSection(
          'Divas mujab',
          byDay.entries
              .map((e) => AiRow(e.key, valText(e.value),
              sub: sub(e.value), bar: mx == 0 ? 0 : val(e.value) / mx, askOnTap: ask(e.key)))
              .toList(),
        ));
      }
      return out;
    }

    // ---- varsh mujab ----
    if (p.from.year != p.to.year) {
      final byY = <int, List<T>>{for (var y = p.from.year; y <= p.to.year; y++) y: <T>[]};
      for (final r in dated) {
        byY[dateOf(r)!.year]?.add(r);
      }
      final mx = byY.values.map(val).fold(0.0, (a, b) => a > b ? a : b);
      out.add(AiSection(
        'Varsh mujab',
        byY.entries
            .map((e) => AiRow('📅 ${e.key}', valText(e.value),
            sub: e.value.isEmpty ? 'kai nathi' : sub(e.value),
            bar: mx == 0 ? 0 : val(e.value) / mx,
            askOnTap: ask('${e.key}')))
            .toList(),
      ));
    }

    // ---- mahina mujab (khali mahina pan batavo) ----
    final byM = <String, List<T>>{};
    final firstOf = <String, DateTime>{};
    for (var d = DateTime(p.from.year, p.from.month, 1);
    !d.isAfter(p.to);
    d = DateTime(d.year, d.month + 1, 1)) {
      final k = AiDateWords.monthLabel(d);
      byM[k] = <T>[];
      firstOf[k] = d;
    }
    for (final r in dated) {
      byM[AiDateWords.monthLabel(dateOf(r)!)]?.add(r);
    }
    if (byM.length > 1) {
      final mx = byM.values.map(val).fold(0.0, (a, b) => a > b ? a : b);
      out.add(AiSection(
        'Mahina mujab',
        byM.entries
            .map((e) => AiRow(e.key, valText(e.value),
            sub: e.value.isEmpty ? 'kai nathi' : sub(e.value),
            bar: mx == 0 ? 0 : val(e.value) / mx,
            askOnTap: ask(AiDateWords.monthAsk(firstOf[e.key]!))))
            .toList(),
      ));
    }
    return out;
  }

  /// "Sauthi saro mahino: Aug 2026 — ₹4,50,000" (lamba samay mate j)
  static String _bestMonthLine<T>(
      AiDateRange p,
      List<T> rows,
      DateTime? Function(T) dateOf,
      double Function(List<T>) val,
      String Function(List<T>) text, {
        String prefix = '',
      }) {
    if (p.spanDays <= 31) return '';
    final byM = <String, List<T>>{};
    for (final r in rows) {
      final d = dateOf(r);
      if (d != null) byM.putIfAbsent(AiDateWords.monthLabel(d), () => []).add(r);
    }
    if (byM.length < 2) return '';
    final best = byM.entries.reduce((a, b) => val(a.value) >= val(b.value) ? a : b);
    return '${prefix}Sauthi saro mahino ${best.key} — ${text(best.value)}.\n';
  }

  static int _pcs(Iterable<_Stk> l) => l.fold(0, (a, e) => a + e.pcs);
  static double _net(Iterable<_Stk> l) => l.fold(0.0, (a, e) => a + e.net);
  static double _gross(Iterable<_Stk> l) => l.fold(0.0, (a, e) => a + e.gross);

  static Map<String, List<T>> _group<T>(List<T> l, String Function(T) k) {
    final m = <String, List<T>>{};
    for (final e in l) {
      m.putIfAbsent(k(e), () => []).add(e);
    }
    return m;
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  static double _d(dynamic v) => double.tryParse(v?.toString().replaceAll(',', '') ?? '') ?? 0;

  /// "2026-10-15 10:22:00" / "2026-10-15T.." / "15-10-2026" / "15/10/2026"
  static DateTime? _date(dynamic v) {
    final s = v?.toString().trim() ?? '';
    if (s.isEmpty || s == 'null') return null;
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso.isUtc ? iso.toLocal() : iso;
    final m = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})').firstMatch(s);
    if (m != null) return DateTime(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
    return null;
  }

  static String g(double v) {
    final s = v.toStringAsFixed(3);
    return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  static String g0(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}

class _Stk {
  final String item;
  final String code;
  final int pcs;
  final double net, gross;
  final DateTime? date;
  final String? image;
  final bool sold;

  _Stk({
    required this.item,
    required this.code,
    required this.pcs,
    required this.net,
    required this.gross,
    required this.date,
    this.image,
    this.sold = false,
  });

  AiRecord record() => AiRecord(
    title: code.isNotEmpty && pcs == 1 ? '$code · $item' : item,
    subtitle: '${date != null ? AiDateRange.fmt(date!) : '-'}${pcs > 1 ? ' · $code' : ''}',
    value: '${DateAi.g(net)} g',
    badge: pcs == 1 ? (sold ? 'Vechayo' : 'Stock ma') : '$pcs pcs',
    badgeGood: !sold,
    imageUrl: (image == null || image!.isEmpty || image == 'null') ? null : image,
    details: [
      AiStat('Item', item),
      if (code.isNotEmpty) AiStat(pcs == 1 ? 'Barcode' : 'Type', code),
      AiStat('Pcs', '$pcs'),
      AiStat('Net', '${DateAi.g(net)} g'),
      AiStat('Gross', '${DateAi.g(gross)} g'),
      if (date != null) AiStat('Umerayo', AiDateRange.fmt(date!)),
    ],
  );
}

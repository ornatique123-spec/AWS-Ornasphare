import 'dart:math';

import '../core/ai_core.dart';
import 'sales_ai_models.dart';

/// =======================================================================
///  SALES AI ENGINE
///  Udaharan:
///   • "aaje nu vechan" / "gaya mahina nu total" / "chhela 7 divas"
///   • "kaya customer e sauthi vadhare kharidyu" / "top 5 party amount ma"
///   • "Divya nu vechan" / "Dishank e aa mahine shu lidhu"
///   • "aa mahina vs gaya mahina" / "vechan vadhyu ke ghatyu"
///   • "mahina wise vechan" / "roj nu vechan" / "kaya divas vadhare vechan thay"
///   • "sauthi motu bill" / "PT-SL-008 batav"
///   • "kone vadhare bill banavya" (staff)
///   • "amount vagar na bill" / "30 divas thi kon customer nathi aavya"
///   • "average labour rate" / "average purity"
/// =======================================================================

enum SalesIntent {
  help,
  voucher,
  customerDetail,
  topCustomers,
  compare,
  trend,
  weekday,
  biggestBill,
  smallestBill,
  staff,
  unpriced,
  inactive,
  averages,
  summary,
  unknown,
}

enum SalesMetric { weight, fine, amount, labour, qty, bills }

class SalesQuery {
  SalesIntent intent = SalesIntent.unknown;
  AiPeriod? period;
  String? customer;
  List<String> customerOptions = [];
  String? staff;
  double? minW;
  double? maxW;
  SalesMetric metric = SalesMetric.weight;
  bool metricExplicit = false;
  int? limit;
  int? days;
  String? voucherKey;
  String trendUnit = 'auto';

  @override
  String toString() =>
      'SalesQuery($intent period=$period cust=$customer staff=$staff w=$minW-$maxW metric=$metric limit=$limit days=$days v=$voucherKey unit=$trendUnit)';
}

class _Tot {
  int bills = 0, pcs = 0, unpriced = 0;
  double gross = 0, net = 0, fine = 0, metal = 0, labour = 0, otherAmt = 0, total = 0;
  final Set<String> customers = {};
  final Set<String> dates = {};

  void add(SaleVoucher v) {
    bills++;
    pcs += v.qty;
    gross += v.gross;
    net += v.net;
    fine += v.fine;
    metal += v.metalAmount;
    labour += v.labourAmount;
    otherAmt += v.otherAmount;
    total += v.netTotal;
    if (v.isUnpriced) unpriced++;
    customers.add(v.customer);
    dates.add(AiFmt.date(v.date));
  }

  static _Tot of(Iterable<SaleVoucher> l) {
    final t = _Tot();
    for (final v in l) {
      t.add(v);
    }
    return t;
  }

  double metric(SalesMetric m) {
    switch (m) {
      case SalesMetric.weight:
        return net;
      case SalesMetric.fine:
        return fine;
      case SalesMetric.amount:
        return total;
      case SalesMetric.labour:
        return labour;
      case SalesMetric.qty:
        return pcs.toDouble();
      case SalesMetric.bills:
        return bills.toDouble();
    }
  }
}

class SalesAiEngine {
  final List<SaleVoucher> all;
  late final List<String> customers;
  late final List<String> staffNames;
  late final Map<String, SaleVoucher> _byVoucher;
  final DateTime? loadedFrom;
  SalesQuery? _last;

  SalesAiEngine(this.all, {this.loadedFrom}) {
    all.sort((a, b) => b.date.compareTo(a.date)); // navu pehla
    customers = all.map((e) => e.customer).where((e) => e != '-').toSet().toList()..sort();
    staffNames = all.map((e) => e.createdBy).where((e) => e != '-').toSet().toList()..sort();
    _byVoucher = {for (final v in all) v.voucherKey: v};
  }

  static const List<String> suggestions = [
    'Sales today',
    'This month vs last month',
    'Top 5 customers',
    'Month wise sales',
    'Which day has the most sales?',
    'Biggest bill',
    'Customers not seen in 30 days',
    'Bills without amount',
    'Average labour rate',
    'Who created the most bills?',
  ];

  // =====================================================================
  //  PUBLIC
  // =====================================================================

  AiAnswer ask(String raw) {
    if (all.isEmpty) {
      return const AiAnswer(
        text: 'No sales data found. Please refresh and try again.',
        speech: 'No sales data found.',
      );
    }
    final q = parse(raw);
    _last = q;
    switch (q.intent) {
      case SalesIntent.help:
        return helpAnswer();
      case SalesIntent.voucher:
        return _voucher(q);
      case SalesIntent.customerDetail:
        return _customer(q);
      case SalesIntent.topCustomers:
        return _topCustomers(q);
      case SalesIntent.compare:
        return _compare(q);
      case SalesIntent.trend:
        return _trend(q);
      case SalesIntent.weekday:
        return _weekday(q);
      case SalesIntent.biggestBill:
        return _bills(q, biggest: true);
      case SalesIntent.smallestBill:
        return _bills(q, biggest: false);
      case SalesIntent.staff:
        return _staff(q);
      case SalesIntent.unpriced:
        return _unpriced(q);
      case SalesIntent.inactive:
        return _inactive(q);
      case SalesIntent.averages:
        return _averages(q);
      case SalesIntent.summary:
        return _summary(q);
      case SalesIntent.unknown:
        return _unknown(raw);
    }
  }

  AiAnswer helpAnswer() => const AiAnswer(
    text: 'You can ask about sales like this:\n'
        '• Time: "sales today", "last month", "last 7 days", "September"\n'
        '• Customer: "top 5 customers", "Divya sales", "customers not seen in 30 days"\n'
        '• Compare: "this month vs last month", "did sales go up or down"\n'
        '• Trend: "month wise", "daily sales", "which day has the most sales"\n'
        '• Bills: "biggest bill", "PT-SL-008", "bills without amount"\n'
        '• Other: "average labour rate", "who created the most bills"\n'
        'Add "by amount" or "by fine" to change the measure.',
    speech: 'You can ask about today\'s sales, top customers, month comparison, the biggest bill, '
        'or customers who have not come back.',
    followUps: ['Sales today', 'Top 5 customers', 'This month vs last month'],
  );

  // =====================================================================
  //  PARSER
  // =====================================================================

  static const _stop = {
    'the', 'and', 'nu', 'na', 'ni', 'no', 'ne', 'e', 'ma', 'thi', 'che', 'chhe', 'bill', 'sale', 'vechan',
    'customer', 'party', 'grahak', 'total', 'kul', 'ketlu', 'ketla', 'batav', 'mane', 'aa', 'gaya', 'mahina',
    'mahine', 'aaje', 'kale', 'divas', 'top', 'shu', 'su', 'kon', 'kone', 'amount', 'rupiya', 'gram', 'fine',
    'labour', 'test', 'patel', 'admin', 'soni', 'shah', 'bhai', 'ben', 'vs', 'karta', 'vadhare', 'sauthi',
    'ochhu', 'nathi', 'aavya', 'lidhu', 'sales', 'bills', 'customers', 'today', 'yesterday', 'this', 'last',
    'month', 'week', 'year', 'days', 'day', 'which', 'who', 'most', 'least', 'biggest', 'smallest', 'without',
    'average', 'rate', 'created', 'show', 'how', 'much', 'many', 'not', 'seen', 'since', 'wise', 'daily',
    'weekly', 'monthly', 'with', 'for', 'all', 'has', 'have', 'did', 'what', 'weight', 'pieces', 'compare',
    'versus',
  };

  SalesQuery parse(String raw) {
    final q = SalesQuery();
    final t = AiText.normalize(raw);
    bool has(List<String> w) => AiText.has(t, w);

    // ---------- voucher no (1–3 token jodi ne) ----------
    final toks = t.split(' ');
    outer:
    for (var size = 1; size <= 4; size++) {
      for (var i = 0; i + size <= toks.length; i++) {
        final key = toks.sublist(i, i + size).join().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
        if (key.length >= 4 && _byVoucher.containsKey(key)) {
          q.voucherKey = key;
          break outer;
        }
      }
    }

    q.period = AiPeriodParser.parse(t);

    final dm = RegExp(r'(\d+)\s*(divas|din|days|day)').firstMatch(t);
    if (dm != null) q.days = int.parse(dm[1]!);
    final mm = RegExp(r'(\d+)\s*(mahina|mahino|months|month)').firstMatch(t);
    if (mm != null) q.days = int.parse(mm[1]!) * 30;

    final lm = RegExp(r'\b(top|first|pehla|pela)\s*(\d+)').firstMatch(t);
    final lm2 = RegExp(r'\b(\d+)\s*(customer|party|grahak|bill|voucher)').firstMatch(t);
    if (lm != null) {
      q.limit = int.parse(lm[2]!);
    } else if (lm2 != null) {
      q.limit = int.parse(lm2[1]!);
    }

    final w = AiText.weightRange(t);
    q.minW = w.min;
    q.maxW = w.max;

    // ---------- metric ----------
    if (has(['labour', 'majuri', 'making', 'ghadaman', 'ghadamn', 'mazduri'])) {
      q.metric = SalesMetric.labour;
      q.metricExplicit = true;
    } else if (has(['rupiya', 'amount', 'rs ', 'paisa', 'kimat', 'vakro', 'revenue', 'value', 'income', 'aavak'])) {
      q.metric = SalesMetric.amount;
      q.metricExplicit = true;
    } else if (has(['fine', 'shudh', 'fain', 'pure'])) {
      q.metric = SalesMetric.fine;
      q.metricExplicit = true;
    } else if (has(['piece', 'pcs', 'nang', 'qty', 'quantity'])) {
      q.metric = SalesMetric.qty;
      q.metricExplicit = true;
    } else if (has(['ketla bill', 'bill count', 'vadhare bill', 'vadhu bill', 'number of bill', 'kitne bill'])) {
      q.metric = SalesMetric.bills;
      q.metricExplicit = true;
    } else if (has(['weight', 'vajan', 'gram', 'net'])) {
      q.metricExplicit = true;
    }

    // ---------- customer / staff ----------
    final cust = _matchNames(t, customers);
    if (cust.length == 1) {
      q.customer = cust.first;
    } else if (cust.length > 1) {
      q.customerOptions = cust;
    }
    final st = _matchNames(t, staffNames);
    if (st.length == 1 && st.first != q.customer) q.staff = st.first;

    // ---------- context (agla sawal no customer / period) ----------
    final prev = _last;
    if (prev != null) {
      if (q.customer == null &&
          q.customerOptions.isEmpty &&
          prev.customer != null &&
          has(['ena', 'eno', 'eni', 'ene', 'tena', 'teno', 'aa customer', 'aa party', 'same customer', 'ema'])) {
        q.customer = prev.customer;
      }
      if (q.period == null && prev.period != null && has(['ema', 'aa samay', 'e samay', 'ej samay', 'same period', 'tyare'])) {
        q.period = prev.period;
      }
    }

    q.intent = _intent(t, q);

    // "aa mahina vs gaya mahina" -> chalu samay sathe sarkhamni
    if (q.intent == SalesIntent.compare) {
      final n = DateTime.now();
      final today = DateTime(n.year, n.month, n.day);
      if (has(['aa varsh', 'this year', 'is saal', 'aa saal', 'chalu varsh'])) {
        q.period = AiPeriod(DateTime(today.year, 1, 1), today, 'This year ${today.year}', PeriodKind.year);
      } else if (has(['aa athvadi', 'this week', 'is hafte', 'aa week'])) {
        q.period = AiPeriod(today.subtract(Duration(days: today.weekday - 1)), today, 'This week', PeriodKind.week);
      } else if (has(['aa mahin', 'this month', 'is mahine', 'chalu mahin'])) {
        q.period = AiPeriod(DateTime(today.year, today.month, 1), today,
            'This month (${AiPeriodParser.monthName(today.month)})', PeriodKind.month);
      } else if (has(['aaje', 'today'])) {
        q.period = AiPeriod(today, today, 'Today', PeriodKind.day);
      }
    }

    if (has(['mahina wise', 'month wise', 'monthly', 'mahine mahine', 'mahina pramane', 'mahina mujab'])) {
      q.trendUnit = 'month';
    } else if (has(['week wise', 'athvadiya wise', 'weekly', 'athvadiye athvadiye'])) {
      q.trendUnit = 'week';
    } else if (has(['divas wise', 'day wise', 'daily', 'roj', 'roje', 'date wise', 'divase divase', 'tarikh'])) {
      q.trendUnit = 'day';
    }
    return q;
  }

  /// Customer / staff naam sodhe — pura naam pehla, nahi to shabd thi
  List<String> _matchNames(String t, List<String> names) {
    final s = ' $t ';
    final full = names.where((n) {
      final ln = AiText.normalize(n);
      return ln.length >= 3 && s.contains(' $ln ');
    }).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    if (full.isNotEmpty) {
      // "Dishank Patel 123" ane "Dishank" banne match thay to lambu (vadhu specific) j
      final best = full.first;
      final rest = full.where((n) => n.length == best.length).toList();
      return rest.length == 1 ? [best] : rest;
    }

    final tokens = t.split(' ').where((w) => w.length >= 3 && !_stop.contains(w)).toSet();
    if (tokens.isEmpty) return [];
    final scored = <String, int>{};
    for (final n in names) {
      final nt = AiText.normalize(n).split(' ').where((w) => w.length >= 3 && !_stop.contains(w));
      final hit = nt.where(tokens.contains).length;
      if (hit > 0) scored[n] = hit;
    }
    if (scored.isEmpty) return [];
    final top = scored.values.reduce(max);
    final best = scored.entries.where((e) => e.value == top).map((e) => e.key).toList()..sort();
    // "Dishank" bolya ane "Dishank" naam no customer hoy to e j
    final exact = best.where((n) => AiText.normalize(n).split(' ').length == top).toList();
    if (exact.length == 1) return exact;
    return best;
  }

  SalesIntent _intent(String t, SalesQuery q) {
    bool has(List<String> w) => AiText.has(t, w);

    if (has(['help', 'madad', 'shu puchi', 'su puchi', 'what can', 'kya puch'])) return SalesIntent.help;
    if (q.voucherKey != null) return SalesIntent.voucher;

    if (has(['amount nathi', 'rate nathi', '0 amount', 'zero', 'rupiya nathi', 'kimat nathi', 'amount vagar',
      'vagar amount', 'unpriced', 'amount baki', 'baki amount', 'pending', '0 rupiya', 'amount vina', 'bina amount',
      'without amount', 'no amount', 'zero amount', 'amount missing'])) {
      return SalesIntent.unpriced;
    }
    if (has(['aavya nathi', 'nathi aavya', 'aavyo nathi', 'aavi nathi', 'nathi aavyo', 'inactive', 'gayab',
      'kharidi nathi', 'kharidyu nathi', 'lidhu nathi', 'follow up', 'followup', 'bandh', 'nahi aaye',
      'nahi aya', 'missing customer', 'dekhaya nathi', 'not seen', 'not come', 'not bought', 'not visited',
      'did not come', "haven't", 'have not'])) {
      return SalesIntent.inactive;
    }
    if (has(['compare', 'sarkhamni', 'tulna', 'vs ', 'versus', 'vadhyu', 'ghatyu', 'vadhyo', 'ghatyo', 'farak',
      'growth', 'increase', 'decrease', 'karta ', 'mukable', 'mukabale', 'badha ke', 'badhi ke'])) {
      return SalesIntent.compare;
    }
    if (has(['kaya divas', 'kayo divas', 'kaya var', 'kayo var', 'weekday', 'var ma', 'day of week', 'kaun se din',
      'konse din', 'kaya vare', 'kayo din', 'somvar', 'ravivar', 'which day', 'best day', 'day has'])) {
      return SalesIntent.weekday;
    }
    if (has(['trend', 'mahina wise', 'month wise', 'monthly', 'divas wise', 'day wise', 'daily', 'roj nu', 'roj ',
      'roje', 'date wise', 'week wise', 'weekly', 'athvadiya wise', 'graph', 'chart', 'mahine mahine',
      'divase divase', 'mahina pramane', 'mahina mujab', 'daily sales'])) {
      return SalesIntent.trend;
    }
    if (has(['staff', 'salesman', 'user wise', 'created', 'banavya', 'banavyu', 'banavel', 'employee',
      'karmachari', 'kisne', 'operator', 'created by', 'most bills']) ||
        (q.staff != null && q.customer == null)) {
      return SalesIntent.staff;
    }
    if (has(['motu bill', 'moto bill', 'mota bill', 'moti bill', 'biggest', 'largest', 'highest', 'max bill',
      'bhare bill', 'top bill', 'sauthi motu', 'sauthi moto', 'big bill', 'bada bill', 'sabse bada'])) {
      return SalesIntent.biggestBill;
    }
    if (has(['nanu bill', 'nana bill', 'nano bill', 'smallest', 'lowest', 'min bill', 'chhotu bill', 'chota bill',
      'sabse chhota'])) {
      return SalesIntent.smallestBill;
    }
    if (has(['average', 'avg', 'sarasari', 'labour rate', 'purity', 'touch', 'waste', 'ghat', 'rate ketlo',
      'rate su', 'rate shu', 'majuri rate', 'per gram', 'gram dith'])) {
      return SalesIntent.averages;
    }
    if (q.customer != null) return SalesIntent.customerDetail;
    if (has(['customer', 'grahak', 'party', 'client', 'kharid', 'kon e', 'kone vadhare', 'kone sauthi',
      'buyer', 'vepari', 'customers', 'top customers', 'who bought'])) {
      return SalesIntent.topCustomers;
    }
    if (q.customerOptions.isNotEmpty) return SalesIntent.customerDetail;
    if (q.period != null ||
        q.minW != null ||
        q.maxW != null ||
        has(['vechan', 'vechay', 'vechyu', 'sale', 'sales', 'bills', 'how much', 'how many', 'total', 'kul', 'ketlu', 'ketla', 'summary', 'report', 'hisab',
          'dhandho', 'business', 'bikri', 'bill', 'kitna', 'fine', 'labour', 'amount', 'majuri'])) {
      return SalesIntent.summary;
    }
    return SalesIntent.unknown;
  }

  // =====================================================================
  //  HELPERS
  // =====================================================================

  List<SaleVoucher> _base(SalesQuery q, {bool usePeriod = true, AiPeriod? period}) {
    final p = period ?? (usePeriod ? q.period : null);
    return all.where((v) {
      if (p != null && !p.contains(v.date)) return false;
      if (q.customer != null && v.customer != q.customer) return false;
      if (q.staff != null && v.createdBy != q.staff) return false;
      if (q.minW != null && v.net < q.minW!) return false;
      if (q.maxW != null && v.net > q.maxW!) return false;
      return true;
    }).toList();
  }

  String _periodLabel(SalesQuery q) {
    if (q.period != null) return q.period!.label;
    final f = loadedFrom ?? (all.isEmpty ? null : all.map((e) => e.date).reduce((a, b) => a.isBefore(b) ? a : b));
    return f == null ? 'All time' : 'All data (since ${AiFmt.date(f)})';
  }

  String _filterLabel(SalesQuery q, {AiPeriod? period}) {
    final parts = <String>[period?.label ?? _periodLabel(q)];
    if (q.customer != null) parts.add(q.customer!);
    if (q.staff != null) parts.add('Staff: ${q.staff}');
    if (q.minW != null && q.maxW != null) {
      parts.add('Bills of ${AiFmt.g(q.minW!)}–${AiFmt.g(q.maxW!)} g');
    } else if (q.minW != null) {
      parts.add('Bills above ${AiFmt.g(q.minW!)} g');
    } else if (q.maxW != null) {
      parts.add('Bills up to ${AiFmt.g(q.maxW!)} g');
    }
    return parts.join(' · ');
  }

  String _mName(SalesMetric m) => const {
    SalesMetric.weight: 'Net weight',
    SalesMetric.fine: 'Fine',
    SalesMetric.amount: 'Amount',
    SalesMetric.labour: 'Labour',
    SalesMetric.qty: 'Pieces',
    SalesMetric.bills: 'Bills',
  }[m]!;

  String _mFmt(SalesMetric m, double v) {
    switch (m) {
      case SalesMetric.weight:
      case SalesMetric.fine:
        return '${AiFmt.g(v)} g';
      case SalesMetric.amount:
      case SalesMetric.labour:
        return AiFmt.inr(v);
      case SalesMetric.qty:
        return '${v.round()} pcs';
      case SalesMetric.bills:
        return '${v.round()} bill${v.round() == 1 ? '' : 's'}';
    }
  }

  String _mSpeak(SalesMetric m, double v) {
    switch (m) {
      case SalesMetric.weight:
      case SalesMetric.fine:
        return '${AiFmt.g(v).replaceAll(',', '')} grams';
      case SalesMetric.amount:
      case SalesMetric.labour:
        return AiFmt.spokenInr(v);
      case SalesMetric.qty:
        return '${v.round()} pieces';
      case SalesMetric.bills:
        return '${v.round()} bills';
    }
  }

  double _mVal(SaleVoucher v, SalesMetric m) {
    switch (m) {
      case SalesMetric.weight:
        return v.net;
      case SalesMetric.fine:
        return v.fine;
      case SalesMetric.amount:
        return v.netTotal;
      case SalesMetric.labour:
        return v.labourAmount;
      case SalesMetric.qty:
        return v.qty.toDouble();
      case SalesMetric.bills:
        return 1;
    }
  }

  List<AiStat> _totStats(_Tot t) => [
    AiStat('Bills', '${t.bills}'),
    AiStat('Customers', '${t.customers.length}'),
    AiStat('Pieces', '${t.pcs}'),
    AiStat('Net wt', '${AiFmt.g(t.net)} g'),
    AiStat('Fine', '${AiFmt.g(t.fine)} g'),
    AiStat('Metal', AiFmt.inr(t.metal)),
    AiStat('Labour', AiFmt.inr(t.labour)),
    if (t.otherAmt > 0) AiStat('Other ₹', AiFmt.inr(t.otherAmt)),
    AiStat('Total amount', AiFmt.inr(t.total)),
  ];

  Map<String, List<SaleVoucher>> _groupBy(List<SaleVoucher> l, String Function(SaleVoucher) key) {
    final m = <String, List<SaleVoucher>>{};
    for (final v in l) {
      m.putIfAbsent(key(v), () => []).add(v);
    }
    return m;
  }

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  List<AiRecord> _rec(Iterable<SaleVoucher> l, [int maxN = 100]) =>
      l.take(maxN).map((e) => e.toRecord()).toList();

  AiAnswer _empty(SalesQuery q) {
    final last = q.customer != null ? all.where((v) => v.customer == q.customer).toList() : <SaleVoucher>[];
    final extra = last.isNotEmpty
        ? ' ${q.customer} last bought on ${AiFmt.date(last.first.date)} '
        '(${_today.difference(last.first.date).inDays} days ago).'
        : '';
    return AiAnswer(
      text: '${_filterLabel(q)} — no bills found.$extra',
      speech: 'No bills found.',
      filterLabel: _filterLabel(q),
      period: q.period,
      followUps: ['Sales this month', 'Sales last month', 'Top 5 customers'],
    );
  }

  // =====================================================================
  //  ANSWERS
  // =====================================================================

  AiAnswer _summary(SalesQuery q) {
    final list = _base(q);
    if (list.isEmpty) return _empty(q);
    final t = _Tot.of(list);
    final label = _filterLabel(q);

    var text = '${_periodLabel(q)}: ${t.bills} bills to ${t.customers.length} customers — '
        '${t.pcs} pcs, net ${AiFmt.g(t.net)} g, fine ${AiFmt.g(t.fine)} g.\n'
        'Total amount ${AiFmt.inr(t.total)} (metal ${AiFmt.inr(t.metal)}, labour ${AiFmt.inr(t.labour)}).';
    var speech = '${_periodLabel(q)}: ${t.bills} bills, net ${AiFmt.g(t.net).replaceAll(',', '')} grams, '
        'total ${AiFmt.spokenInr(t.total)}.';

    if (q.period != null) {
      final prev = q.period!.previous();
      final pt = _Tot.of(_base(q, period: prev));
      if (pt.bills > 0) {
        text += '\nVs ${prev.label}: weight ${AiFmt.change(t.net, pt.net)}, amount ${AiFmt.change(t.total, pt.total)}.';
        speech += ' Compared to the previous period, weight is ${AiFmt.change(t.net, pt.net).replaceAll('%', ' percent')}.';
      }
    }
    if (t.unpriced > 0) {
      text += '\n⚠️ ${t.unpriced} bills have weight but 0 amount.';
    }

    final byCust = _groupBy(list, (v) => v.customer).entries.toList()
      ..sort((a, b) => _Tot.of(b.value).net.compareTo(_Tot.of(a.value).net));
    final maxNet = byCust.isEmpty ? 1.0 : max(1.0, _Tot.of(byCust.first.value).net);

    return AiAnswer(
      text: text,
      speech: speech,
      stats: [
        ..._totStats(t),
        AiStat('Avg bill', '${AiFmt.g(t.net / t.bills)} g'),
      ],
      sections: [
        AiSection(
          'Top customers (weight)',
          byCust.take(5).map((e) {
            final ct = _Tot.of(e.value);
            return AiRow(e.key, '${AiFmt.g(ct.net)} g',
                sub: '${ct.bills} bills · ${AiFmt.inr(ct.total)}', bar: ct.net / maxNet, askOnTap: '${e.key} sales');
          }).toList(),
        ),
      ],
      items: _rec(list),
      itemsTitle: 'Bills (newest first)',
      filterLabel: label,
      period: q.period,
      followUps: [
        if (q.period == null) 'Sales this month',
        if (q.period != null) 'Compare ${q.period!.label} vs previous',
        'Top 5 customers',
        'Month wise sales',
      ],
    );
  }

  AiAnswer _voucher(SalesQuery q) {
    final v = _byVoucher[q.voucherKey]!;
    return AiAnswer(
      text: '${v.voucherNo} · ${v.customer} · ${AiFmt.date(v.date)}\n'
          '${v.qty} pcs, net ${AiFmt.g(v.net)} g, fine ${AiFmt.g(v.fine)} g, total ${AiFmt.inr(v.netTotal, decimals: 2)}.'
          '${v.isUnpriced ? '\n⚠️ This bill has 0 amount.' : ''}',
      speech: 'Bill of ${v.customer}, ${AiFmt.g(v.net).replaceAll(',', '')} grams, ${AiFmt.spokenInr(v.netTotal)}.',
      stats: v.toRecord().details,
      items: [v.toRecord()],
      itemsTitle: 'Bill',
      followUps: ['${v.customer} sales', 'All bills of ${v.customer}'],
    );
  }

  AiAnswer _customer(SalesQuery q) {
    if (q.customer == null) {
      return AiAnswer(
        text: 'There are ${q.customerOptions.length} customers with this name. Which one?',
        speech: 'There are ${q.customerOptions.length} customers with this name. Which one do you mean?',
        followUps: q.customerOptions.take(6).map((c) => '$c sales').toList(),
      );
    }
    final name = q.customer!;
    final list = _base(q);
    if (list.isEmpty) return _empty(q);
    final t = _Tot.of(list);
    final allMine = all.where((v) => v.customer == name).toList(); // navu pehla
    final lastDate = allMine.first.date;
    final daysAgo = _today.difference(lastDate).inDays;

    // visit gap
    final dates = allMine.map((e) => DateTime(e.date.year, e.date.month, e.date.day)).toSet().toList()..sort();
    String? gapTxt;
    if (dates.length >= 2) {
      final gap = dates.last.difference(dates.first).inDays / (dates.length - 1);
      gapTxt = 'usually buys every ${gap.round()} days';
    }

    // rank among customers in same period
    final ranking = _groupBy(_base(SalesQuery()..period = q.period), (v) => v.customer)
        .map((k, v) => MapEntry(k, _Tot.of(v).net))
        .entries
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final rank = ranking.indexWhere((e) => e.key == name) + 1;
    final share = ranking.isEmpty ? 0.0 : t.net / max(1.0, ranking.fold(0.0, (a, e) => a + e.value));

    // monthly breakdown (chhela 6 mahina)
    final months = <AiRow>[];
    final mineGrouped = _groupBy(allMine, (v) => '${v.date.year}-${v.date.month.toString().padLeft(2, '0')}');
    final keys = mineGrouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final maxM = keys.isEmpty ? 1.0 : keys.map((k) => _Tot.of(mineGrouped[k]!).net).reduce(max);
    for (final k in keys.take(6)) {
      final mt = _Tot.of(mineGrouped[k]!);
      final p = k.split('-');
      months.add(AiRow('${AiPeriodParser.monthName(int.parse(p[1]))} ${p[0]}', '${AiFmt.g(mt.net)} g',
          sub: '${mt.bills} bills · ${AiFmt.inr(mt.total)}', bar: maxM == 0 ? 0 : mt.net / maxM));
    }

    final text = '$name (${_periodLabel(q)}): ${t.bills} bills, ${t.pcs} pcs, net ${AiFmt.g(t.net)} g, '
        'fine ${AiFmt.g(t.fine)} g, total ${AiFmt.inr(t.total)}.\n'
        '${rank > 0 ? 'Rank #$rank among customers (${AiFmt.pct(share)} share). ' : ''}'
        'Last purchase ${AiFmt.date(lastDate)} — $daysAgo days ago'
        '${gapTxt != null ? ', $gapTxt' : ''}.'
        '${t.unpriced > 0 ? '\n⚠️ ${t.unpriced} bills have 0 amount.' : ''}';

    return AiAnswer(
      text: text,
      speech: '$name bought ${AiFmt.g(t.net).replaceAll(',', '')} grams in ${t.bills} bills, '
          '${AiFmt.spokenInr(t.total)}. Last purchase $daysAgo days ago.',
      stats: [
        AiStat('Bills', '${t.bills}'),
        AiStat('Pieces', '${t.pcs}'),
        AiStat('Net wt', '${AiFmt.g(t.net)} g'),
        AiStat('Fine', '${AiFmt.g(t.fine)} g'),
        AiStat('Labour', AiFmt.inr(t.labour)),
        AiStat('Total', AiFmt.inr(t.total)),
        if (rank > 0) AiStat('Rank', '#$rank'),
        AiStat('Last visit', '$daysAgo days ago'),
      ],
      sections: [AiSection('By month ($name)', months)],
      items: _rec(list),
      itemsTitle: 'Bills of $name',
      filterLabel: _filterLabel(q),
      period: q.period,
      followUps: [
        '$name this month vs last month',
        if (q.period == null) '$name sales this month',
        'Top 5 customers',
      ],
    );
  }

  AiAnswer _topCustomers(SalesQuery q) {
    final list = _base(q);
    if (list.isEmpty) return _empty(q);
    final m = q.metric;
    final groups = _groupBy(list, (v) => v.customer)
        .map((k, v) => MapEntry(k, (tot: _Tot.of(v), last: v.map((e) => e.date).reduce((a, b) => a.isAfter(b) ? a : b))))
        .entries
        .toList()
      ..sort((a, b) => b.value.tot.metric(m).compareTo(a.value.tot.metric(m)));

    final total = groups.fold(0.0, (a, e) => a + e.value.tot.metric(m));
    if (total == 0) {
      return AiAnswer(
        text: '${_periodLabel(q)}: ${_mName(m).toLowerCase()} is 0. Try "top customers by weight".',
        followUps: ['Top customers by weight', 'Top customers by amount'],
      );
    }
    final top = groups.first;
    final top3 = groups.take(3).fold(0.0, (a, e) => a + e.value.tot.metric(m));
    final n = q.limit ?? 15;

    final text = '${_periodLabel(q)} — top customer by ${_mName(m).toLowerCase()}: ${top.key} — '
        '${_mFmt(m, top.value.tot.metric(m))} (${AiFmt.pct(top.value.tot.metric(m) / total)} share, '
        '${top.value.tot.bills} bills).\n'
        '${groups.length > 3 ? 'Top 3 customers = ${AiFmt.pct(top3 / total)} of sales. ' : ''}'
        '${groups.length} customers in total.';

    return AiAnswer(
      text: text,
      speech: '${top.key} bought the most, ${_mSpeak(m, top.value.tot.metric(m))}.'
          '${groups.length > 1 ? ' Second is ${groups[1].key}.' : ''}',
      stats: [
        AiStat('Customers', '${groups.length}'),
        AiStat('Total ${_mName(m).toLowerCase()}', _mFmt(m, total)),
        AiStat('No. 1', top.key),
        if (groups.length > 3) AiStat('Top 3 share', AiFmt.pct(top3 / total)),
      ],
      sections: [
        AiSection(
          'Top customers — by ${_mName(m).toLowerCase()}',
          groups.take(n).toList().asMap().entries.map((e) {
            final r = e.value;
            final tt = r.value.tot;
            return AiRow(
              '${e.key + 1}. ${r.key}',
              _mFmt(m, tt.metric(m)),
              sub: '${tt.bills} bills · ${AiFmt.g(tt.net)} g · ${AiFmt.inr(tt.total)} · last ${AiFmt.shortDate(r.value.last)}',
              bar: tt.metric(m) / top.value.tot.metric(m),
              askOnTap: '${r.key} sales',
            );
          }).toList(),
        ),
      ],
      filterLabel: _filterLabel(q),
      period: q.period,
      followUps: [
        if (m != SalesMetric.amount) 'Top customers by amount',
        if (m != SalesMetric.weight) 'Top customers by weight',
        if (m != SalesMetric.labour) 'Top customers by labour',
        'Customers not seen in 30 days',
      ],
    );
  }

  AiAnswer _compare(SalesQuery q) {
    final today = _today;
    final cur = q.period ??
        AiPeriod(DateTime(today.year, today.month, 1), today,
            'This month (${AiPeriodParser.monthName(today.month)})', PeriodKind.month);
    final prev = cur.previous();
    final a = _Tot.of(_base(q, period: cur));
    final b = _Tot.of(_base(q, period: prev));

    if (a.bills == 0 && b.bills == 0) {
      return AiAnswer(
          text: 'No bills in ${cur.label} or ${prev.label}.', speech: 'No bills in either period.', period: cur);
    }

    AiRow row(String name, double x, double y, String Function(double) f) {
      final ch = AiFmt.change(x, y);
      final up = x >= y;
      return AiRow(name, '${f(x)}  vs  ${f(y)}',
          sub: '${up ? '▲' : '▼'} $ch', bar: max(x, y) == 0 ? 0 : x / max(x, y));
    }

    String gfmt(double v) => '${AiFmt.g(v)} g';
    String ifmt(double v) => AiFmt.inr(v);
    String nfmt(double v) => '${v.round()}';

    final wCh = AiFmt.change(a.net, b.net);
    final aCh = AiFmt.change(a.total, b.total);
    final up = a.net >= b.net;

    // customer mujab sauthi vadhu farak
    final ca = _groupBy(_base(q, period: cur), (v) => v.customer).map((k, v) => MapEntry(k, _Tot.of(v).net));
    final cb = _groupBy(_base(q, period: prev), (v) => v.customer).map((k, v) => MapEntry(k, _Tot.of(v).net));
    final allC = {...ca.keys, ...cb.keys};
    final diffs = allC.map((c) => (name: c, now: ca[c] ?? 0.0, before: cb[c] ?? 0.0)).toList()
      ..sort((x, y) => (y.now - y.before).abs().compareTo((x.now - x.before).abs()));
    final maxDiff = diffs.isEmpty ? 1.0 : max(1.0, (diffs.first.now - diffs.first.before).abs());

    final text = '${cur.label}: net ${AiFmt.g(a.net)} g, ${AiFmt.inr(a.total)} (${a.bills} bills)\n'
        '${prev.label}: net ${AiFmt.g(b.net)} g, ${AiFmt.inr(b.total)} (${b.bills} bills)\n'
        'Weight $wCh ${up ? 'up 📈' : 'down 📉'}, amount $aCh.'
        '${diffs.isNotEmpty ? ' Biggest change: ${diffs.first.name} (${diffs.first.now >= diffs.first.before ? '+' : '-'}${AiFmt.g((diffs.first.now - diffs.first.before).abs())} g).' : ''}';

    return AiAnswer(
      text: text,
      speech: 'Compared to the previous period, sales weight went ${up ? 'up' : 'down'} '
          '${wCh.replaceAll('%', ' percent')}, and amount changed ${aCh.replaceAll('%', ' percent')}.',
      stats: [
        AiStat('Weight', wCh),
        AiStat('Amount', aCh),
        AiStat('Bills', AiFmt.change(a.bills.toDouble(), b.bills.toDouble())),
        AiStat('Customers', '${a.customers.length} vs ${b.customers.length}'),
      ],
      sections: [
        AiSection('${cur.label} vs ${prev.label}', [
          row('Bills', a.bills.toDouble(), b.bills.toDouble(), nfmt),
          row('Pieces', a.pcs.toDouble(), b.pcs.toDouble(), nfmt),
          row('Net weight', a.net, b.net, gfmt),
          row('Fine', a.fine, b.fine, gfmt),
          row('Labour', a.labour, b.labour, ifmt),
          row('Total amount', a.total, b.total, ifmt),
        ]),
        if (q.customer == null && diffs.isNotEmpty)
          AiSection(
            'Change by customer (weight)',
            diffs.take(8).map((d) {
              final delta = d.now - d.before;
              return AiRow(d.name, '${delta >= 0 ? '▲ +' : '▼ -'}${AiFmt.g(delta.abs())} g',
                  sub: '${AiFmt.g(d.now)} g vs ${AiFmt.g(d.before)} g', bar: delta.abs() / maxDiff,
                  askOnTap: '${d.name} sales');
            }).toList(),
          ),
      ],
      filterLabel: _filterLabel(q, period: cur),
      period: cur,
      followUps: ['Month wise sales', 'Top 5 customers', 'This year vs last year'],
    );
  }

  AiAnswer _trend(SalesQuery q) {
    final today = _today;
    var unit = q.trendUnit;
    var period = q.period;
    if (unit == 'auto') {
      unit = period == null ? 'month' : (period.days > 62 ? 'month' : (period.days > 21 ? 'week' : 'day'));
    }
    period ??= unit == 'day'
        ? AiPeriod(today.subtract(const Duration(days: 29)), today, 'Last 30 days', PeriodKind.custom)
        : unit == 'week'
        ? AiPeriod(today.subtract(const Duration(days: 83)), today, 'Last 12 weeks', PeriodKind.custom)
        : AiPeriod(DateTime(today.year, today.month - 11, 1), today, 'Last 12 months', PeriodKind.custom);

    final list = _base(q, period: period);
    final m = q.metric;

    // bucket keys sorted chronologically, khali bucket pan batavvi
    final buckets = <String, _Tot>{};
    final labels = <String, String>{};
    DateTime cursor;
    if (unit == 'month') {
      cursor = DateTime(period.from.year, period.from.month, 1);
      while (!cursor.isAfter(period.to)) {
        final k = '${cursor.year}-${cursor.month.toString().padLeft(2, '0')}';
        buckets[k] = _Tot();
        labels[k] = '${AiPeriodParser.monthName(cursor.month).substring(0, 3)} ${cursor.year}';
        cursor = DateTime(cursor.year, cursor.month + 1, 1);
      }
    } else if (unit == 'week') {
      cursor = period.from.subtract(Duration(days: period.from.weekday - 1));
      while (!cursor.isAfter(period.to)) {
        final k = AiFmt.date(cursor);
        buckets[k] = _Tot();
        labels[k] = 'Week of ${AiFmt.shortDate(cursor)}';
        cursor = cursor.add(const Duration(days: 7));
      }
    } else {
      cursor = period.from;
      while (!cursor.isAfter(period.to)) {
        final k = AiFmt.date(cursor);
        buckets[k] = _Tot();
        labels[k] = '${AiFmt.shortDate(cursor)} (${AiFmt.weekdays[cursor.weekday - 1].substring(0, 3)})';
        cursor = cursor.add(const Duration(days: 1));
      }
    }
    String keyOf(DateTime d) {
      if (unit == 'month') return '${d.year}-${d.month.toString().padLeft(2, '0')}';
      if (unit == 'week') return AiFmt.date(d.subtract(Duration(days: d.weekday - 1)));
      return AiFmt.date(d);
    }

    for (final v in list) {
      buckets[keyOf(v.date)]?.add(v);
    }

    final entries = buckets.entries.toList();
    final vals = entries.map((e) => e.value.metric(m)).toList();
    final maxV = vals.isEmpty ? 0.0 : vals.reduce(max);
    final active = entries.where((e) => e.value.bills > 0).toList();
    if (active.isEmpty) return _empty(q..period = period);

    final best = active.reduce((a, b) => a.value.metric(m) >= b.value.metric(m) ? a : b);
    final sum = vals.fold(0.0, (a, b) => a + b);
    final avg = sum / entries.length;
    final unitName = unit == 'month' ? 'month' : unit == 'week' ? 'week' : 'day';

    String lastVsPrev = '';
    if (entries.length >= 2) {
      final l = entries[entries.length - 1].value.metric(m);
      final p = entries[entries.length - 2].value.metric(m);
      lastVsPrev = ' Latest $unitName vs previous: ${AiFmt.change(l, p)}.';
    }

    // day trend ma khali divas ghana hoy to fakt active batavo
    final showEntries = unit == 'day' && entries.length > 31 ? active : entries;

    return AiAnswer(
      text: '${period.label} — ${_mName(m).toLowerCase()} by $unitName.\n'
          'Best: ${labels[best.key]} (${_mFmt(m, best.value.metric(m))}, ${best.value.bills} bills). '
          'Average per $unitName ${_mFmt(m, avg)}.$lastVsPrev',
      speech: 'The best $unitName was ${labels[best.key]!.split(' (').first}, ${_mSpeak(m, best.value.metric(m))}.',
      stats: [
        AiStat('Total', _mFmt(m, sum)),
        AiStat('Avg / $unitName', _mFmt(m, avg)),
        AiStat('Best', labels[best.key]!.split(' (').first),
        AiStat('Active ${unitName}s', '${active.length}/${entries.length}'),
      ],
      sections: [
        AiSection(
          '${_mName(m)} — by $unitName',
          showEntries.reversed.map((e) {
            final tt = e.value;
            return AiRow(labels[e.key]!, _mFmt(m, tt.metric(m)),
                sub: tt.bills == 0 ? 'No bills' : '${tt.bills} bills · ${AiFmt.g(tt.net)} g · ${AiFmt.inr(tt.total)}',
                bar: maxV == 0 ? 0 : tt.metric(m) / maxV);
          }).toList(),
        ),
      ],
      filterLabel: _filterLabel(q, period: period),
      period: period,
      followUps: [
        if (unit != 'month') 'Month wise sales',
        if (unit != 'day') 'Daily sales',
        if (m != SalesMetric.amount) 'Month wise amount',
        'Which day has the most sales?',
      ],
    );
  }

  AiAnswer _weekday(SalesQuery q) {
    final list = _base(q);
    if (list.isEmpty) return _empty(q);
    final m = q.metric;
    final tots = List.generate(7, (_) => _Tot());
    for (final v in list) {
      tots[v.date.weekday - 1].add(v);
    }
    // average per active date (ek var j vechan thayu hoy evo divas)
    final avg = List.generate(7, (i) => tots[i].dates.isEmpty ? 0.0 : tots[i].metric(m) / tots[i].dates.length);
    final maxA = avg.reduce(max);
    var bestI = 0;
    for (var i = 1; i < 7; i++) {
      if (avg[i] > avg[bestI]) bestI = i;
    }
    final quiet = <int>[for (var i = 0; i < 7; i++) if (tots[i].bills == 0) i];

    return AiAnswer(
      text: '${_periodLabel(q)}: ${AiFmt.weekdays[bestI]} is the best day — '
          'average ${_mFmt(m, avg[bestI])} (${tots[bestI].bills} bills).'
          '${quiet.isNotEmpty ? ' No sales on ${quiet.map((i) => AiFmt.weekdays[i]).join(', ')}.' : ''}',
      speech: '${AiFmt.weekdays[bestI]} has the most sales.',
      sections: [
        AiSection(
          '${_mName(m)} — by weekday (average)',
          List.generate(7, (i) => AiRow(
            AiFmt.weekdays[i],
            _mFmt(m, avg[i]),
            sub: '${tots[i].bills} bills · ${tots[i].dates.length} days · total ${_mFmt(m, tots[i].metric(m))}',
            bar: maxA == 0 ? 0 : avg[i] / maxA,
          )),
        ),
      ],
      filterLabel: _filterLabel(q),
      period: q.period,
      followUps: ['Daily sales', 'Month wise sales'],
    );
  }

  AiAnswer _bills(SalesQuery q, {required bool biggest}) {
    final list = _base(q);
    if (list.isEmpty) return _empty(q);
    final m = q.metricExplicit
        ? q.metric
        : (list.any((v) => v.netTotal > 0) ? SalesMetric.amount : SalesMetric.weight);
    final sorted = list.where((v) => biggest || _mVal(v, m) > 0).toList()
      ..sort((a, b) => biggest ? _mVal(b, m).compareTo(_mVal(a, m)) : _mVal(a, m).compareTo(_mVal(b, m)));
    if (sorted.isEmpty) return _empty(q);
    final f = sorted.first;
    final n = q.limit ?? 10;
    return AiAnswer(
      text: '${_periodLabel(q)} — ${biggest ? 'biggest' : 'smallest'} bill (by ${_mName(m).toLowerCase()}): '
          '${f.voucherNo} — ${f.customer}, ${AiFmt.date(f.date)}, ${_mFmt(m, _mVal(f, m))} '
          '(${AiFmt.g(f.net)} g, ${AiFmt.inr(f.netTotal)}).',
      speech: 'The ${biggest ? 'biggest' : 'smallest'} bill is of ${f.customer}, ${_mSpeak(m, _mVal(f, m))}.',
      items: _rec(sorted, n),
      itemsTitle: 'Top $n bills — ${_mName(m)}',
      filterLabel: _filterLabel(q),
      period: q.period,
      followUps: [
        if (m != SalesMetric.weight) 'Biggest bill by weight',
        if (m != SalesMetric.amount) 'Biggest bill by amount',
        'Top 5 customers',
      ],
    );
  }

  AiAnswer _staff(SalesQuery q) {
    final list = _base(q);
    if (list.isEmpty) return _empty(q);
    if (q.staff != null) {
      final t = _Tot.of(list);
      return AiAnswer(
        text: '${q.staff} created ${t.bills} bills (${_periodLabel(q)}) — ${t.customers.length} customers, '
            'net ${AiFmt.g(t.net)} g, total ${AiFmt.inr(t.total)}.',
        speech: '${q.staff} created ${t.bills} bills.',
        stats: _totStats(t),
        items: _rec(list),
        itemsTitle: 'Bills by ${q.staff}',
        filterLabel: _filterLabel(q),
        period: q.period,
      );
    }
    final groups = _groupBy(list, (v) => v.createdBy).map((k, v) => MapEntry(k, _Tot.of(v))).entries.toList()
      ..sort((a, b) => b.value.bills.compareTo(a.value.bills));
    final maxB = groups.first.value.bills;
    return AiAnswer(
      text: '${_periodLabel(q)}: ${groups.first.key} created the most bills — ${groups.first.value.bills} bills '
          '(${AiFmt.g(groups.first.value.net)} g).',
      speech: '${groups.first.key} created the most bills, ${groups.first.value.bills} bills.',
      sections: [
        AiSection(
          'By staff',
          groups
              .map((e) => AiRow(e.key, '${e.value.bills} bills',
              sub: '${AiFmt.g(e.value.net)} g · ${AiFmt.inr(e.value.total)} · ${e.value.customers.length} customers',
              bar: e.value.bills / maxB,
              askOnTap: 'Bills created by ${e.key}'))
              .toList(),
        ),
      ],
      filterLabel: _filterLabel(q),
      period: q.period,
    );
  }

  AiAnswer _unpriced(SalesQuery q) {
    final list = _base(q).where((v) => v.isUnpriced).toList();
    if (list.isEmpty) {
      return AiAnswer(
          text: '${_periodLabel(q)}: every bill has an amount. 👍',
          speech: 'Every bill has an amount.',
          filterLabel: _filterLabel(q),
          period: q.period);
    }
    final t = _Tot.of(list);
    final byC = _groupBy(list, (v) => v.customer).map((k, v) => MapEntry(k, _Tot.of(v))).entries.toList()
      ..sort((a, b) => b.value.net.compareTo(a.value.net));
    return AiAnswer(
      text: '${_periodLabel(q)}: ${list.length} bills have weight but 0 amount — '
          'total ${AiFmt.g(t.net)} g (fine ${AiFmt.g(t.fine)} g).\n'
          'Most are for ${byC.first.key} (${byC.first.value.bills} bills). Please check rate / labour.',
      speech: '${list.length} bills have no amount, ${AiFmt.g(t.net).replaceAll(',', '')} grams in total.',
      stats: [
        AiStat('Bills', '${list.length}'),
        AiStat('Net wt', '${AiFmt.g(t.net)} g'),
        AiStat('Fine', '${AiFmt.g(t.fine)} g'),
        AiStat('Customers', '${byC.length}'),
      ],
      sections: [
        AiSection(
            'By customer',
            byC
                .map((e) => AiRow(e.key, '${e.value.bills} bills',
                sub: '${AiFmt.g(e.value.net)} g', bar: e.value.net / byC.first.value.net))
                .toList()),
      ],
      items: _rec(list),
      itemsTitle: 'Bills with 0 amount',
      filterLabel: _filterLabel(q),
      period: q.period,
    );
  }

  AiAnswer _inactive(SalesQuery q) {
    final days = q.days ?? 30;
    final cutoff = _today.subtract(Duration(days: days));
    final byC = _groupBy(all, (v) => v.customer);
    final rows = byC.entries
        .map((e) {
      final lastD = e.value.map((v) => v.date).reduce((a, b) => a.isAfter(b) ? a : b);
      return (name: e.key, last: lastD, tot: _Tot.of(e.value));
    })
        .where((x) => x.last.isBefore(cutoff))
        .toList()
      ..sort((a, b) => b.tot.net.compareTo(a.tot.net)); // moto customer pehla

    if (rows.isEmpty) {
      return AiAnswer(
          text: 'Every customer has bought in the last $days days. 👍',
          speech: 'Every customer has bought in the last $days days.');
    }
    final maxNet = max(1.0, rows.first.tot.net);
    return AiAnswer(
      text: '${rows.length} customers have not bought in over $days days.\n'
          'Most important: ${rows.first.name} — ${_today.difference(rows.first.last).inDays} days, '
          'bought ${AiFmt.g(rows.first.tot.net)} g before. Give them a follow-up call.',
      speech: '${rows.length} customers have not bought in $days days. The most important is ${rows.first.name}.',
      stats: [
        AiStat('Customers', '${rows.length}'),
        AiStat('Bought before', '${AiFmt.g(rows.fold(0.0, (a, r) => a + r.tot.net))} g'),
      ],
      sections: [
        AiSection(
          'Not seen in $days+ days (biggest customers first)',
          rows
              .map((r) => AiRow(
            r.name,
            '${_today.difference(r.last).inDays} days',
            sub: 'Last ${AiFmt.date(r.last)} · total ${AiFmt.g(r.tot.net)} g · ${r.tot.bills} bills',
            bar: r.tot.net / maxNet,
            askOnTap: '${r.name} sales',
          ))
              .toList(),
        ),
      ],
      followUps: [
        if (days != 60) 'Customers not seen in 60 days',
        if (days != 15) 'Customers not seen in 15 days',
        'Top 5 customers',
      ],
    );
  }

  AiAnswer _averages(SalesQuery q) {
    final list = _base(q);
    if (list.isEmpty) return _empty(q);
    final t = _Tot.of(list);
    final withPurity = list.where((v) => v.purity > 0 && v.net > 0).toList();
    final pNet = withPurity.fold(0.0, (a, v) => a + v.net);
    final avgPurity = pNet == 0 ? 0.0 : withPurity.fold(0.0, (a, v) => a + v.purity * v.net) / pNet;
    final withWaste = list.where((v) => v.waste > 0 && v.net > 0).toList();
    final wNet = withWaste.fold(0.0, (a, v) => a + v.net);
    final avgWaste = wNet == 0 ? 0.0 : withWaste.fold(0.0, (a, v) => a + v.waste * v.net) / wNet;
    final labourList = list.where((v) => v.labourAmount > 0 && v.net > 0).toList();
    final lNet = labourList.fold(0.0, (a, v) => a + v.net);
    final avgLabour = lNet == 0 ? 0.0 : labourList.fold(0.0, (a, v) => a + v.labourAmount) / lNet;
    final metalList = list.where((v) => v.metalAmount > 0 && v.fine > 0).toList();
    final mFine = metalList.fold(0.0, (a, v) => a + v.fine);
    final avgMetal = mFine == 0 ? 0.0 : metalList.fold(0.0, (a, v) => a + v.metalAmount) / mFine;

    final byC = _groupBy(labourList, (v) => v.customer).entries.map((e) {
      final n = e.value.fold(0.0, (a, v) => a + v.net);
      final l = e.value.fold(0.0, (a, v) => a + v.labourAmount);
      return (name: e.key, rate: n == 0 ? 0.0 : l / n, net: n);
    }).toList()
      ..sort((a, b) => b.rate.compareTo(a.rate));
    final maxR = byC.isEmpty ? 1.0 : max(1.0, byC.first.rate);

    return AiAnswer(
      text: '${_periodLabel(q)} average: labour ₹${AiFmt.g(avgLabour)}/g, purity ${AiFmt.g(avgPurity)}%, '
          'waste ${AiFmt.g(avgWaste)}%, metal rate ₹${AiFmt.g(avgMetal)}/g fine. '
          'Average bill: ${AiFmt.g(t.net / t.bills)} g and ${AiFmt.inr(t.total / t.bills)}.'
          '${labourList.length < list.length ? ' (${list.length - labourList.length} bills with 0 labour are not counted.)' : ''}',
      speech: 'Average labour is ${AiFmt.g(avgLabour)} rupees per gram, purity ${AiFmt.g(avgPurity)} percent.',
      stats: [
        AiStat('Labour/g', '₹${AiFmt.g(avgLabour)}'),
        AiStat('Purity', '${AiFmt.g(avgPurity)}%'),
        AiStat('Waste', '${AiFmt.g(avgWaste)}%'),
        AiStat('Metal/g', '₹${AiFmt.g(avgMetal)}'),
        AiStat('Avg bill wt', '${AiFmt.g(t.net / t.bills)} g'),
        AiStat('Avg bill ₹', AiFmt.inr(t.total / t.bills)),
        AiStat('Pcs/bill', (t.pcs / t.bills).toStringAsFixed(1)),
      ],
      sections: [
        if (byC.isNotEmpty)
          AiSection(
            'Labour rate by customer (₹/g)',
            byC
                .map((c) => AiRow(c.name, '₹${AiFmt.g(c.rate)}',
                sub: 'on ${AiFmt.g(c.net)} g', bar: c.rate / maxR, askOnTap: '${c.name} sales'))
                .toList(),
          ),
      ],
      filterLabel: _filterLabel(q),
      period: q.period,
      followUps: ['Bills without amount', 'Top customers by labour'],
    );
  }

  AiAnswer _unknown(String raw) => AiAnswer(
    text: 'Sorry, I did not understand "$raw" for sales. Try asking:',
    speech: 'Sorry, I did not understand. Please ask again.',
    followUps: suggestions.take(6).toList(),
  );
}
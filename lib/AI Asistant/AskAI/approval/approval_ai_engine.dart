import 'dart:math';

import '../core/ai_core.dart';
import 'approval_ai_models.dart';

/// =======================================================================
///  APPROVAL AI ENGINE (Approval Outstanding)
///  Udaharan:
///   • "ketla approval baki che" / "approval summary"
///   • "kona pase sauthi vadhare maal che" / "top 5 customer approval ma"
///   • "Dishank pase ketlo maal che"
///   • "15 divas thi juna approval" / "sauthi juno approval"
///   • "kone follow up karvu" (vadhu maal + vadhu juno = pehla)
///   • "partial approval" / "open approval" / "khali approval"
///   • "aa mahine na approval" / "mahina wise approval"
///   • "sauthi motu approval" / "approval 1789194519" / "kone vadhare approval banavya"
/// =======================================================================

enum ApprovalIntent {
  help,
  voucher,
  customerDetail,
  topCustomers,
  aging,
  followUp,
  open,
  partial,
  empty,
  staff,
  biggest,
  trend,
  summary,
  unknown,
}

enum ApprovalMetric { weight, fine, pcs, amount, count }

class ApprovalQuery {
  ApprovalIntent intent = ApprovalIntent.unknown;
  AiPeriod? period;
  String? customer;
  List<String> customerOptions = [];
  String? staff;
  double? minW;
  double? maxW;
  int? days;
  int? limit;
  ApprovalMetric metric = ApprovalMetric.weight;
  String? statusFilter; // open / partial
  String? voucherKey;

  @override
  String toString() =>
      'ApprovalQuery($intent period=$period cust=$customer staff=$staff days=$days status=$statusFilter v=$voucherKey metric=$metric)';
}

class _Tot {
  int count = 0, pcs = 0, open = 0, partial = 0, empty = 0;
  double net = 0, gross = 0, fine = 0, amount = 0;
  int oldest = 0;
  double ageSum = 0;
  final Set<String> customers = {};

  void add(ApprovalEntry a) {
    count++;
    pcs += a.pendingPcs;
    net += a.net;
    gross += a.gross;
    fine += a.fine;
    amount += a.amount;
    if (a.isOpen) open++;
    if (a.isPartial) partial++;
    if (a.isEmpty) empty++;
    oldest = max(oldest, a.ageDays);
    ageSum += a.ageDays * a.net;
    customers.add(a.customer);
  }

  /// Weight pramane average age (bhare approval vadhu gane)
  double get avgAge => net == 0 ? 0 : ageSum / net;

  static _Tot of(Iterable<ApprovalEntry> l) {
    final t = _Tot();
    for (final a in l) {
      t.add(a);
    }
    return t;
  }

  double metric(ApprovalMetric m) {
    switch (m) {
      case ApprovalMetric.weight:
        return net;
      case ApprovalMetric.fine:
        return fine;
      case ApprovalMetric.pcs:
        return pcs.toDouble();
      case ApprovalMetric.amount:
        return amount;
      case ApprovalMetric.count:
        return count.toDouble();
    }
  }
}

class ApprovalAiEngine {
  final List<ApprovalEntry> all;
  late final List<String> customers;
  late final List<String> staffNames;
  late final Map<String, ApprovalEntry> _byKey;
  ApprovalQuery? _last;

  ApprovalAiEngine(this.all) {
    all.sort((a, b) => b.date.compareTo(a.date));
    customers = all.map((e) => e.customer).where((e) => e != '-').toSet().toList()..sort();
    staffNames = all.map((e) => e.createdBy).where((e) => e != '-').toSet().toList()..sort();
    _byKey = {for (final a in all) a.key: a};
  }

  /// Khali approval gananathi bahar (sachu baki maal j)
  List<ApprovalEntry> get live => all.where((a) => !a.isEmpty).toList();

  static const List<String> suggestions = [
    'How many approvals are pending?',
    'Who has the most goods on approval?',
    'Approvals older than 15 days',
    'Whom should I follow up with?',
    'Partial approvals',
    'Biggest approval',
    'Empty approvals',
    'Month wise approvals',
  ];

  // =====================================================================
  //  PUBLIC
  // =====================================================================

  AiAnswer ask(String raw) {
    if (all.isEmpty) {
      return const AiAnswer(text: 'No approvals are pending. 👍', speech: 'No approvals are pending.');
    }
    final q = parse(raw);
    _last = q;
    switch (q.intent) {
      case ApprovalIntent.help:
        return helpAnswer();
      case ApprovalIntent.voucher:
        return _voucher(q);
      case ApprovalIntent.customerDetail:
        return _customer(q);
      case ApprovalIntent.topCustomers:
        return _topCustomers(q);
      case ApprovalIntent.aging:
        return _aging(q);
      case ApprovalIntent.followUp:
        return _followUp(q);
      case ApprovalIntent.open:
        return _byStatus(q, 'open');
      case ApprovalIntent.partial:
        return _byStatus(q, 'partial');
      case ApprovalIntent.empty:
        return _empty(q);
      case ApprovalIntent.staff:
        return _staff(q);
      case ApprovalIntent.biggest:
        return _biggest(q);
      case ApprovalIntent.trend:
        return _trend(q);
      case ApprovalIntent.summary:
        return _summary(q);
      case ApprovalIntent.unknown:
        return _unknown(raw);
    }
  }

  AiAnswer helpAnswer() => const AiAnswer(
    text: 'You can ask about approvals like this:\n'
        '• "How many approvals are pending?", "Approval summary"\n'
        '• "Who has the most goods on approval?", "How much does Dishank have?"\n'
        '• "Approvals older than 15 days", "Whom should I follow up with?"\n'
        '• "Partial approvals", "Open approvals", "Empty approvals"\n'
        '• "This month\'s approvals", "Month wise approvals"\n'
        '• "Biggest approval", "Approval 1789194519"',
    speech: 'You can ask about pending approvals, who has the goods, old approvals, or whom to follow up with.',
    followUps: ['How many approvals are pending?', 'Who has the most goods on approval?', 'Whom should I follow up with?'],
  );

  // =====================================================================
  //  PARSER
  // =====================================================================

  static const Set<String> _stop = {
    'the', 'and', 'nu', 'na', 'ni', 'no', 'ne', 'ma', 'thi', 'che', 'chhe', 'approval', 'approvals',
    'aprooval', 'customer', 'party', 'grahak', 'pase', 'maal', 'mal', 'ketlo', 'ketla', 'ketlu',
    'batav', 'mane', 'aa', 'gaya', 'mahina', 'mahine', 'divas', 'top', 'shu', 'kon', 'kona', 'kone',
    'open', 'partial', 'baki', 'pending', 'juna', 'juno', 'test', 'patel', 'admin', 'soni', 'bhai',
    'ben', 'sauthi', 'vadhare', 'motu', 'moto', 'khali', 'follow', 'karvu', 'gram', 'fine', 'amount',
    'qa', 'postman', 'demo',
    // English
    'how', 'many', 'much', 'does', 'have', 'has', 'with', 'who', 'whom', 'most', 'goods', 'stock', 'show',
    'pieces', 'piece', 'days', 'day', 'older', 'than', 'old', 'should', 'biggest', 'empty',
    'customers', 'month', 'wise', 'created', 'by', 'are', 'for', 'what', 'which', 'this', 'last', 'summary',
  };

  ApprovalQuery parse(String raw) {
    final q = ApprovalQuery();
    final t = AiText.normalize(raw);
    bool has(List<String> w) => AiText.has(t, w);

    // ---------- approval no: aakho athva chhella 4+ ank ----------
    final toks = t.split(' ');
    outer:
    for (var size = 1; size <= 3; size++) {
      for (var i = 0; i + size <= toks.length; i++) {
        final key = toks.sublist(i, i + size).join().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
        if (key.length >= 6 && _byKey.containsKey(key)) {
          q.voucherKey = key;
          break outer;
        }
      }
    }
    if (q.voucherKey == null) {
      for (final m in RegExp(r'\d{4,}').allMatches(t.replaceAll(' ', ''))) {
        if (RegExp(r'^(19|20)\d\d$').hasMatch(m[0]!)) continue; // varsh, approval no nahi
        final hits = all.where((a) => a.digits.endsWith(m[0]!)).toList();
        if (hits.length == 1) {
          q.voucherKey = hits.first.key;
          break;
        }
      }
    }

    q.period = AiPeriodParser.parse(t);

    final dm = RegExp(r'(\d+)\s*(divas|din|days|day)').firstMatch(t);
    if (dm != null) q.days = int.parse(dm[1]!);
    final mm = RegExp(r'(\d+)\s*(mahina|mahino|months|month)').firstMatch(t);
    if (mm != null) q.days = int.parse(mm[1]!) * 30;
    // "15 divas thi juna" = umar, period nahi
    if (q.days != null && !has(['chhela', 'chela', 'last', 'pichhle'])) q.period = null;

    final lm = RegExp(r'\b(top|first|pehla|pela)\s*(\d+)').firstMatch(t) ??
        RegExp(r'\b(\d+)\s*(customer|party|approval)').firstMatch(t);
    if (lm != null) q.limit = int.tryParse(lm[2]!) ?? int.tryParse(lm[1]!);

    final w = AiText.weightRange(t);
    q.minW = w.min;
    q.maxW = w.max;

    if (has(['fine', 'shudh', 'fain'])) {
      q.metric = ApprovalMetric.fine;
    } else if (has(['amount', 'rupiya', 'labour', 'majuri', 'kimat', 'value'])) {
      q.metric = ApprovalMetric.amount;
    } else if (has(['piece', 'pcs', 'nang', 'qty'])) {
      q.metric = ApprovalMetric.pcs;
    } else if (has(['ketla approval', 'approval count', 'vadhare approval', 'vadhu approval'])) {
      q.metric = ApprovalMetric.count;
    }

    if (has(['partial', 'aadhu', 'adhu', 'thodu', 'parshiyal'])) q.statusFilter = 'partial';
    if (has(['open approval', 'open che', 'pura baki', 'aakhu baki', 'khulla'])) q.statusFilter = 'open';

    final c = _matchNames(t, customers);
    if (c.length == 1) {
      q.customer = c.first;
    } else if (c.length > 1) {
      q.customerOptions = c;
    }
    final st = _matchNames(t, staffNames);
    if (st.length == 1 && st.first != q.customer) q.staff = st.first;

    final prev = _last;
    if (prev != null &&
        q.customer == null &&
        q.customerOptions.isEmpty &&
        prev.customer != null &&
        has(['ena', 'eno', 'eni', 'tena', 'aa customer', 'aa party', 'same customer'])) {
      q.customer = prev.customer;
    }

    q.intent = _intent(t, q);
    return q;
  }

  /// Customer / staff naam sodhe — pura naam pehla ("Dishank Patel 258"),
  /// nahi to shabd thi ("dishank"). 1 result = pakku, vadhu = user ne puchvu.
  List<String> _matchNames(String t, List<String> names) {
    final s = ' $t ';
    final full = names.where((n) {
      final ln = AiText.normalize(n);
      return ln.length >= 3 && s.contains(' $ln ');
    }).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    if (full.isNotEmpty) {
      final best = full.first;
      final same = full.where((n) => n.length == best.length).toList();
      return same.length == 1 ? [best] : same;
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
    final exact = best.where((n) => AiText.normalize(n).split(' ').length == top).toList();
    if (exact.length == 1) return exact;
    return best;
  }

  ApprovalIntent _intent(String t, ApprovalQuery q) {
    bool has(List<String> w) => AiText.has(t, w);

    if (has(['help', 'madad', 'shu puchi', 'su puchi', 'what can', 'what should i ask'])) return ApprovalIntent.help;
    if (q.voucherKey != null) return ApprovalIntent.voucher;

    if (has(['khali', 'empty', '0 piece', 'zero', 'bandh karva', 'close karva', 'nakama', 'kai baki nathi'])) {
      return ApprovalIntent.empty;
    }
    if (has(['follow', 'call', 'phone', 'yaad', 'reminder', 'risk', 'jokham', 'priority', 'pehla kone',
      'kone pehla', 'ugharani', 'paachhu mangav', 'pachhu mangav', 'return mangav', 'mangavvu'])) {
      return ApprovalIntent.followUp;
    }
    if (has(['juna', 'juno', 'juni', 'junu', 'old', 'purana', 'purane', 'ghana divas', 'lamba samay',
      'aging', 'ageing', 'divas thi', 'din se', 'days old', 'mahina thi', 'older than', 'oldest'])) {
      return ApprovalIntent.aging;
    }
    if (has(['mahina wise', 'month wise', 'monthly', 'trend', 'mahine mahine', 'mahina pramane'])) {
      return ApprovalIntent.trend;
    }
    if (q.customer == null &&
        has(['staff', 'banavya', 'banavyu', 'banavel', 'created', 'employee', 'aapya', 'issue karya',
          'kisne', 'operator'])) {
      return ApprovalIntent.staff;
    }
    if (q.staff != null && q.customer == null) return ApprovalIntent.staff;
    if (has(['motu', 'moto', 'mota', 'biggest', 'largest', 'bhare', 'sauthi vadhu maal vala', 'top approval'])) {
      return ApprovalIntent.biggest;
    }
    if (q.customer != null) return ApprovalIntent.customerDetail;
    if (has(['kona pase', 'kone pase', 'kon pase', 'customer', 'party', 'grahak', 'kiske paas', 'pase sauthi',
      'sauthi vadhare maal', 'vadhu maal', 'who has', 'most goods', 'top customers'])) {
      return ApprovalIntent.topCustomers;
    }
    if (q.customerOptions.isNotEmpty) return ApprovalIntent.customerDetail;
    if (q.statusFilter == 'partial') return ApprovalIntent.partial;
    if (q.statusFilter == 'open') return ApprovalIntent.open;
    if (q.period != null ||
        q.minW != null ||
        q.maxW != null ||
        has(['approval', 'baki', 'pending', 'outstanding', 'maal', 'ketla', 'ketlo', 'total', 'kul', 'summary',
          'jangad', 'memo', 'hisab', 'how many', 'how much'])) {
      return ApprovalIntent.summary;
    }
    return ApprovalIntent.unknown;
  }

  // =====================================================================
  //  HELPERS
  // =====================================================================

  List<ApprovalEntry> _base(ApprovalQuery q, {bool includeEmpty = false}) => all.where((a) {
    if (!includeEmpty && a.isEmpty) return false;
    if (q.period != null && !q.period!.contains(a.date)) return false;
    if (q.customer != null && a.customer != q.customer) return false;
    if (q.staff != null && a.createdBy != q.staff) return false;
    if (q.statusFilter != null && a.status != q.statusFilter) return false;
    if (q.minW != null && a.net < q.minW!) return false;
    if (q.maxW != null && a.net > q.maxW!) return false;
    return true;
  }).toList();

  String _filterLabel(ApprovalQuery q) {
    final parts = <String>[q.period?.label ?? 'All pending approvals'];
    if (q.customer != null) parts.add(q.customer!);
    if (q.staff != null) parts.add('Staff: ${q.staff}');
    if (q.statusFilter != null) parts.add(q.statusFilter == 'open' ? 'Open' : 'Partial');
    if (q.minW != null && q.maxW != null) {
      parts.add('${AiFmt.g(q.minW!)}–${AiFmt.g(q.maxW!)} g');
    } else if (q.minW != null) {
      parts.add('${AiFmt.g(q.minW!)} g+');
    } else if (q.maxW != null) {
      parts.add('up to ${AiFmt.g(q.maxW!)} g');
    }
    return parts.join(' · ');
  }

  String _mName(ApprovalMetric m) => const {
    ApprovalMetric.weight: 'Net weight',
    ApprovalMetric.fine: 'Fine',
    ApprovalMetric.pcs: 'Pieces',
    ApprovalMetric.amount: 'Amount',
    ApprovalMetric.count: 'Approval',
  }[m]!;

  String _mFmt(ApprovalMetric m, double v) {
    switch (m) {
      case ApprovalMetric.weight:
      case ApprovalMetric.fine:
        return '${AiFmt.g(v)} g';
      case ApprovalMetric.pcs:
        return '${v.round()} pcs';
      case ApprovalMetric.amount:
        return AiFmt.inr(v);
      case ApprovalMetric.count:
        return '${v.round()} approval${v.round() == 1 ? '' : 's'}';
    }
  }

  String _gSpeak(double v) => '${AiFmt.g(v).replaceAll(',', '')} grams';

  Map<String, List<ApprovalEntry>> _groupBy(List<ApprovalEntry> l, String Function(ApprovalEntry) key) {
    final m = <String, List<ApprovalEntry>>{};
    for (final a in l) {
      m.putIfAbsent(key(a), () => []).add(a);
    }
    return m;
  }

  List<AiRecord> _rec(Iterable<ApprovalEntry> l, [int n = 100]) => l.take(n).map((e) => e.toRecord()).toList();

  AiSection _agingSection(List<ApprovalEntry> l) {
    const labels = ['0–7 days', '8–15 days', '16–30 days', '31–60 days', '60+ days'];
    final b = List.generate(5, (_) => _Tot());
    for (final a in l) {
      final d = a.ageDays;
      b[d <= 7 ? 0 : d <= 15 ? 1 : d <= 30 ? 2 : d <= 60 ? 3 : 4].add(a);
    }
    final total = max(1.0, l.fold(0.0, (s, a) => s + a.net));
    return AiSection(
      'Pending since (by weight)',
      List.generate(5, (i) => AiRow(labels[i], '${AiFmt.g(b[i].net)} g',
          sub: '${b[i].count} approvals · ${b[i].pcs} pcs', bar: b[i].net / total)),
    );
  }

  AiSection _customerSection(List<ApprovalEntry> l, ApprovalMetric m, {int n = 15, String? title}) {
    final g = _groupBy(l, (a) => a.customer).map((k, v) => MapEntry(k, _Tot.of(v))).entries.toList()
      ..sort((a, b) => b.value.metric(m).compareTo(a.value.metric(m)));
    final top = g.isEmpty ? 1.0 : max(1.0, g.first.value.metric(m));
    return AiSection(
      title ?? 'By customer (${_mName(m)})',
      g.take(n).map((e) {
        final t = e.value;
        return AiRow(e.key, _mFmt(m, t.metric(m)),
            sub: '${t.count} approvals · ${t.pcs} pcs · ${AiFmt.g(t.net)} g · oldest ${t.oldest} days',
            bar: t.metric(m) / top,
            askOnTap: 'How much does ${e.key} have');
      }).toList(),
    );
  }

  AiAnswer _none(ApprovalQuery q) => AiAnswer(
    text: '${_filterLabel(q)} — no pending approvals. 👍',
    speech: 'There are no pending approvals.',
    filterLabel: _filterLabel(q),
    followUps: ['How many approvals are pending?', 'Who has the most goods on approval?'],
  );

  // =====================================================================
  //  ANSWERS
  // =====================================================================

  AiAnswer _summary(ApprovalQuery q) {
    final l = _base(q);
    if (l.isEmpty) return _none(q);
    final t = _Tot.of(l);
    final old30 = l.where((a) => a.ageDays > 30).toList();
    final o30 = _Tot.of(old30);
    final emptyCount = _base(q, includeEmpty: true).where((a) => a.isEmpty).length;
    final oldest = l.reduce((a, b) => a.ageDays >= b.ageDays ? a : b);

    var text = '${_filterLabel(q)}: ${t.count} approvals pending with ${t.customers.length} customers — '
        '${t.pcs} pcs, net ${AiFmt.g(t.net)} g (fine ${AiFmt.g(t.fine)} g)'
        '${t.amount > 0 ? ', amount ${AiFmt.inr(t.amount)}' : ''}.\n'
        '${t.open} open · ${t.partial} partial · pending for ${t.avgAge.round()} days on average.';
    if (old30.isNotEmpty) {
      text += '\n⚠️ ${old30.length} approvals are older than 30 days (${AiFmt.g(o30.net)} g). '
          'Oldest: ${oldest.customer}, ${oldest.ageDays} days.';
    }
    if (emptyCount > 0) text += '\n🧹 $emptyCount approvals have 0 pieces left — please close them.';

    return AiAnswer(
      text: text,
      speech: '${t.count} approvals are pending with ${t.customers.length} customers, ${_gSpeak(t.net)} in total.'
          '${old30.isNotEmpty ? ' ${old30.length} are older than 30 days.' : ''}',
      stats: [
        AiStat('Approvals', '${t.count}'),
        AiStat('Customers', '${t.customers.length}'),
        AiStat('Pieces', '${t.pcs}'),
        AiStat('Net wt', '${AiFmt.g(t.net)} g'),
        AiStat('Fine', '${AiFmt.g(t.fine)} g'),
        if (t.amount > 0) AiStat('Amount', AiFmt.inr(t.amount)),
        AiStat('Open / Partial', '${t.open} / ${t.partial}'),
        AiStat('Avg age', '${t.avgAge.round()} days'),
        AiStat('30+ days', '${old30.length}'),
      ],
      sections: [_customerSection(l, ApprovalMetric.weight, n: 6, title: 'Who has the most goods'), _agingSection(l)],
      items: _rec(l),
      itemsTitle: 'Pending approvals (newest first)',
      filterLabel: _filterLabel(q),
      period: q.period,
      followUps: ['Whom should I follow up with?', 'Approvals older than 15 days', 'Partial approvals'],
    );
  }

  AiAnswer _voucher(ApprovalQuery q) {
    final a = _byKey[q.voucherKey]!;
    return AiAnswer(
      text: '${a.approvalNo} · ${a.customer}\n'
          'Issued on ${AiFmt.date(a.date)} (${a.ageDays} days ago) · ${a.statusLabel}.\n'
          'Pending: ${a.pendingPcs} pcs, net ${AiFmt.g(a.net)} g'
          '${a.amount > 0 ? ', ${AiFmt.inr(a.amount)}' : ''}.'
          '${a.isEmpty ? '\n🧹 Nothing is left in this approval — please close it.' : ''}',
      speech: '${a.customer} has ${a.pendingPcs} pieces, ${_gSpeak(a.net)}, for ${a.ageDays} days.',
      stats: a.toRecord().details,
      items: [a.toRecord()],
      itemsTitle: 'Approval',
      followUps: ['How much does ${a.customer} have', 'Whom should I follow up with?'],
    );
  }

  AiAnswer _customer(ApprovalQuery q) {
    if (q.customer == null) {
      return AiAnswer(
        text: 'There are ${q.customerOptions.length} customers with this name. Which one?',
        speech: 'There are ${q.customerOptions.length} customers with this name. Which one do you mean?',
        followUps: q.customerOptions.take(6).map((c) => 'How much does $c have').toList(),
      );
    }
    final name = q.customer!;
    final l = _base(q);
    if (l.isEmpty) return _none(q);
    final t = _Tot.of(l);
    final allLive = live;
    final totalNet = max(1.0, allLive.fold(0.0, (s, a) => s + a.net));
    final rank = (_groupBy(allLive, (a) => a.customer).map((k, v) => MapEntry(k, _Tot.of(v).net)).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)))
        .indexWhere((e) => e.key == name) +
        1;
    final oldest = l.reduce((a, b) => a.ageDays >= b.ageDays ? a : b);

    return AiAnswer(
      text: '$name has ${t.count} pending approval${t.count == 1 ? '' : 's'} — ${t.pcs} pcs, net ${AiFmt.g(t.net)} g '
          '(fine ${AiFmt.g(t.fine)} g)${t.amount > 0 ? ', ${AiFmt.inr(t.amount)}' : ''}.\n'
          'That is ${AiFmt.pct(t.net / totalNet)} of all pending goods${rank > 0 ? ' (rank #$rank)' : ''}. '
          'Oldest: ${oldest.approvalNo.length > 8 ? '…${oldest.approvalNo.substring(oldest.approvalNo.length - 6)}' : oldest.approvalNo}, '
          '${oldest.ageDays} days (${AiFmt.g(oldest.net)} g).',
      speech: '$name has ${t.pcs} pieces, ${_gSpeak(t.net)}, in ${t.count} approvals. '
          'The oldest is ${oldest.ageDays} days old.',
      stats: [
        AiStat('Approvals', '${t.count}'),
        AiStat('Pieces', '${t.pcs}'),
        AiStat('Net wt', '${AiFmt.g(t.net)} g'),
        AiStat('Fine', '${AiFmt.g(t.fine)} g'),
        if (t.amount > 0) AiStat('Amount', AiFmt.inr(t.amount)),
        AiStat('Share', AiFmt.pct(t.net / totalNet)),
        AiStat('Oldest', '${t.oldest} days'),
        AiStat('Open / Partial', '${t.open} / ${t.partial}'),
      ],
      sections: [_agingSection(l)],
      items: _rec(l),
      itemsTitle: 'Approvals of $name',
      filterLabel: _filterLabel(q),
      period: q.period,
      followUps: ['Whom should I follow up with?', 'Who has the most goods on approval?'],
    );
  }

  AiAnswer _topCustomers(ApprovalQuery q) {
    final l = _base(q);
    if (l.isEmpty) return _none(q);
    final m = q.metric;
    final g = _groupBy(l, (a) => a.customer).map((k, v) => MapEntry(k, _Tot.of(v))).entries.toList()
      ..sort((a, b) => b.value.metric(m).compareTo(a.value.metric(m)));
    final total = g.fold(0.0, (s, e) => s + e.value.metric(m));
    if (total == 0) {
      return AiAnswer(
        text: 'Everything is 0 by ${_mName(m).toLowerCase()}. Try by weight: "Who has the most goods on approval?"',
        followUps: ['Who has the most goods on approval?'],
      );
    }
    final top = g.first;
    final top3 = g.take(3).fold(0.0, (s, e) => s + e.value.metric(m));
    return AiAnswer(
      text: '${top.key} has the most — ${_mFmt(m, top.value.metric(m))} '
          '(${AiFmt.pct(top.value.metric(m) / total)} share, ${top.value.count} approvals, '
          'oldest ${top.value.oldest} days).\n'
          '${g.length > 3 ? 'The top 3 customers hold ${AiFmt.pct(top3 / total)} of the goods. ' : ''}'
          '${g.length} customers have pending approvals in total.',
      speech: '${top.key} has the most, ${m == ApprovalMetric.weight ? _gSpeak(top.value.net) : _mFmt(m, top.value.metric(m))}.',
      stats: [
        AiStat('Customers', '${g.length}'),
        AiStat('Total ${_mName(m).toLowerCase()}', _mFmt(m, total)),
        AiStat('No. 1', top.key),
        if (g.length > 3) AiStat('Top 3 share', AiFmt.pct(top3 / total)),
      ],
      sections: [_customerSection(l, m, n: q.limit ?? 15)],
      filterLabel: _filterLabel(q),
      period: q.period,
      followUps: ['Whom should I follow up with?', 'Top customers by pieces', 'Approvals older than 15 days'],
    );
  }

  AiAnswer _aging(ApprovalQuery q) {
    final l = _base(q);
    if (l.isEmpty) return _none(q);
    final days = q.days ?? 15;
    final old = l.where((a) => a.ageDays >= days).toList()..sort((a, b) => b.ageDays.compareTo(a.ageDays));
    final t = _Tot.of(old);
    final tl = _Tot.of(l);
    if (old.isEmpty) {
      return AiAnswer(
        text: 'No approval is older than $days days. The oldest is ${tl.oldest} days. 👍',
        speech: 'No approval is older than $days days.',
        sections: [_agingSection(l)],
        filterLabel: _filterLabel(q),
      );
    }
    final f = old.first;
    return AiAnswer(
      text: '${old.length} approvals are older than $days days — ${t.customers.length} customers, '
          '${t.pcs} pcs, ${AiFmt.g(t.net)} g (${AiFmt.pct(t.net / max(1.0, tl.net))} of all pending goods).\n'
          'Oldest: ${f.customer} — ${f.ageDays} days (${AiFmt.g(f.net)} g, ${AiFmt.date(f.date)}).',
      speech: '${old.length} approvals are older than $days days, ${_gSpeak(t.net)}. '
          'The oldest is with ${f.customer}, ${f.ageDays} days.',
      stats: [
        AiStat('$days+ days', '${old.length}'),
        AiStat('Pieces', '${t.pcs}'),
        AiStat('Net wt', '${AiFmt.g(t.net)} g'),
        AiStat('Customers', '${t.customers.length}'),
        AiStat('Oldest', '${f.ageDays} days'),
      ],
      sections: [
        _agingSection(l),
        _customerSection(old, ApprovalMetric.weight, title: 'Older than $days days — by customer'),
      ],
      items: _rec(old),
      itemsTitle: 'Old approvals (oldest first)',
      filterLabel: _filterLabel(q),
      followUps: [
        if (days != 30) 'Approvals older than 30 days',
        if (days != 60) 'Approvals older than 60 days',
        'Whom should I follow up with?',
      ],
    );
  }

  AiAnswer _followUp(ApprovalQuery q) {
    final l = _base(q);
    if (l.isEmpty) return _none(q);
    final g = _groupBy(l, (a) => a.customer).entries.map((e) {
      final t = _Tot.of(e.value);
      final risk = e.value.fold(0.0, (s, a) => s + a.risk);
      return (name: e.key, tot: t, risk: risk);
    }).toList()
      ..sort((a, b) => b.risk.compareTo(a.risk));
    final maxR = max(1.0, g.first.risk);
    final n = q.limit ?? 10;
    final top = g.take(min(3, g.length)).map((e) => e.name).join(', ');

    return AiAnswer(
      text: 'Call these first: $top.\n'
          'Ranked by goods × days pending — ${g.first.name} has ${AiFmt.g(g.first.tot.net)} g, '
          'oldest ${g.first.tot.oldest} days.',
      speech: 'Call ${g.first.name} first. ${g.length > 1 ? 'Then ${g[1].name}.' : ''}',
      sections: [
        AiSection(
          'Follow-up priority',
          g.take(n).toList().asMap().entries.map((e) {
            final r = e.value;
            final level = r.risk / maxR;
            return AiRow(
              '${level > 0.5 ? '🔴' : level > 0.15 ? '🟠' : '🟢'} ${e.key + 1}. ${r.name}',
              '${AiFmt.g(r.tot.net)} g',
              sub: '${r.tot.count} approvals · ${r.tot.pcs} pcs · oldest ${r.tot.oldest} days · avg ${r.tot.avgAge.round()} days',
              bar: level,
              askOnTap: 'How much does ${r.name} have',
            );
          }).toList(),
        ),
      ],
      filterLabel: _filterLabel(q),
      followUps: ['Approvals older than 15 days', 'Who has the most goods on approval?'],
    );
  }

  AiAnswer _byStatus(ApprovalQuery q, String status) {
    q.statusFilter = status;
    final l = _base(q);
    if (l.isEmpty) return _none(q);
    final t = _Tot.of(l);
    final other = _Tot.of(_base(ApprovalQuery()
      ..period = q.period
      ..customer = q.customer
      ..statusFilter = status == 'open' ? 'partial' : 'open'));
    final meaning = status == 'partial'
        ? 'some goods returned or sold, the rest is still with the customer'
        : 'nothing has come back yet';
    return AiAnswer(
      text: '${t.count} ${status == 'open' ? 'open' : 'partial'} approvals ($meaning) — '
          '${t.customers.length} customers, ${t.pcs} pcs, ${AiFmt.g(t.net)} g pending.\n'
          'Pending for ${t.avgAge.round()} days on average. '
          '${status == 'open' ? 'Partial' : 'Open'}: ${other.count} approvals, ${AiFmt.g(other.net)} g.',
      speech: '${t.count} $status approvals, ${_gSpeak(t.net)} pending.',
      stats: [
        AiStat('Approvals', '${t.count}'),
        AiStat('Pieces', '${t.pcs}'),
        AiStat('Net wt', '${AiFmt.g(t.net)} g'),
        AiStat('Oldest', '${t.oldest} days'),
      ],
      sections: [_customerSection(l, ApprovalMetric.weight, n: 8)],
      items: _rec(l),
      itemsTitle: '${status == 'open' ? 'Open' : 'Partial'} approvals',
      filterLabel: _filterLabel(q),
      period: q.period,
      followUps: [status == 'open' ? 'Partial approvals' : 'Open approvals', 'Whom should I follow up with?'],
    );
  }

  AiAnswer _empty(ApprovalQuery q) {
    final l = _base(q, includeEmpty: true).where((a) => a.isEmpty).toList();
    return AiAnswer(
      text: l.isEmpty
          ? 'No empty approvals. 👍'
          : '${l.length} approvals have 0 pieces left but are still marked "${l.first.statusLabel}".\n'
          'Close them to keep the report clean.',
      speech: l.isEmpty ? 'There are no empty approvals.' : '${l.length} approvals are empty. Please close them.',
      items: _rec(l),
      itemsTitle: 'Empty approvals',
      filterLabel: _filterLabel(q),
    );
  }

  AiAnswer _staff(ApprovalQuery q) {
    final l = _base(q);
    if (l.isEmpty) return _none(q);
    if (q.staff != null) {
      final t = _Tot.of(l);
      return AiAnswer(
        text: '${q.staff} has ${t.count} pending approvals — ${t.customers.length} customers, ${AiFmt.g(t.net)} g.',
        speech: '${q.staff} has ${t.count} pending approvals.',
        items: _rec(l),
        itemsTitle: 'Approvals by ${q.staff}',
        filterLabel: _filterLabel(q),
      );
    }
    final g = _groupBy(l, (a) => a.createdBy).map((k, v) => MapEntry(k, _Tot.of(v))).entries.toList()
      ..sort((a, b) => b.value.net.compareTo(a.value.net));
    final top = max(1.0, g.first.value.net);
    return AiAnswer(
      text: '${g.first.key} created the most pending approvals — ${g.first.value.count} approvals, '
          '${AiFmt.g(g.first.value.net)} g.',
      speech: '${g.first.key} created the most pending approvals.',
      sections: [
        AiSection(
          'Pending by staff',
          g
              .map((e) => AiRow(e.key, '${AiFmt.g(e.value.net)} g',
              sub: '${e.value.count} approvals · ${e.value.customers.length} customers · oldest ${e.value.oldest} days',
              bar: e.value.net / top,
              askOnTap: 'Approvals created by ${e.key}'))
              .toList(),
        ),
      ],
      filterLabel: _filterLabel(q),
    );
  }

  AiAnswer _biggest(ApprovalQuery q) {
    final l = _base(q);
    if (l.isEmpty) return _none(q);
    final m = q.metric == ApprovalMetric.count ? ApprovalMetric.weight : q.metric;
    double v(ApprovalEntry a) => _Tot.of([a]).metric(m);
    final s = [...l]..sort((a, b) => v(b).compareTo(v(a)));
    final f = s.first;
    return AiAnswer(
      text: 'Biggest approval (by ${_mName(m).toLowerCase()}): ${f.customer} — ${_mFmt(m, v(f))}, '
          '${f.pendingPcs} pcs, ${f.ageDays} days (${AiFmt.date(f.date)}).',
      speech: 'The biggest approval is with ${f.customer}, ${_gSpeak(f.net)}.',
      items: _rec(s, q.limit ?? 10),
      itemsTitle: 'Biggest approvals',
      filterLabel: _filterLabel(q),
      followUps: ['How much does ${f.customer} have', 'Whom should I follow up with?'],
    );
  }

  AiAnswer _trend(ApprovalQuery q) {
    final l = _base(q);
    if (l.isEmpty) return _none(q);
    final g = _groupBy(l, (a) => '${a.date.year}-${a.date.month.toString().padLeft(2, '0')}');
    final keys = g.keys.toList()..sort((a, b) => b.compareTo(a));
    final tots = {for (final k in keys) k: _Tot.of(g[k]!)};
    final top = tots.values.map((t) => t.net).reduce(max);
    String label(String k) {
      final p = k.split('-');
      return '${AiPeriodParser.monthName(int.parse(p[1]))} ${p[0]}';
    }

    final best = keys.reduce((a, b) => tots[a]!.net >= tots[b]!.net ? a : b);
    return AiAnswer(
      text: 'Pending approvals by month: ${label(best)} has the most — '
          '${tots[best]!.count} approvals, ${AiFmt.g(tots[best]!.net)} g.',
      speech: '${label(best)} has the most pending approvals.',
      sections: [
        AiSection(
          'Pending goods by month',
          keys
              .map((k) => AiRow(label(k), '${AiFmt.g(tots[k]!.net)} g',
              sub: '${tots[k]!.count} approvals · ${tots[k]!.pcs} pcs · ${tots[k]!.customers.length} customers',
              bar: top == 0 ? 0 : tots[k]!.net / top))
              .toList(),
        ),
      ],
      filterLabel: _filterLabel(q),
      followUps: ['Approvals older than 15 days', 'Whom should I follow up with?'],
    );
  }

  AiAnswer _unknown(String raw) => AiAnswer(
    text: 'Sorry, I did not understand "$raw" for approvals. Try asking:',
    speech: 'Sorry, I did not understand. Please ask again.',
    followUps: suggestions.take(6).toList(),
  );
}

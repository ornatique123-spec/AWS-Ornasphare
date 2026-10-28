import 'dart:async';

import 'package:intl/intl.dart';

import '../../../Api_Constant/ApiConstants.dart';
import '../../../Api_Constant/api_helper.dart';
import '../../VoucherDetails.dart';
import '../core/ai_core.dart';

/// =======================================================================
///  🛠️ JOB WORK AI — job work ISSUE + RECEIVE (worker wise)
///
///  APIs (no loader popup):
///   • GET jobwork-issues                       → issue vouchers
///       voucher_no · created_at · job_worker{name} · production_step{name}
///       gross_wt_sum · net_wt_sum · items[{ item{item_name}, qty_pcs }]
///   • GET jobwork-receive?from=YYYY-MM-DD&to=… → receive tracking
///       voucher_no · voucher_date · jobworker_name · production_step_name
///       issue_net_wt · receive_net_wt · pending_net_wt · status (pending/partial/completed)
///
///  Questions it answers (English / Gujlish / Hindi words):
///   • "job work summary" / "job work today"
///   • "job work issue this month"      • "Ramesh issue"
///   • "job work receive last month"    • "Ramesh receive"
///   • "job work pending" / "pending with Ramesh" / "karigar pase ketlu baki"
/// =======================================================================
class JobWorkAi {
  JobWorkAi._();

  // ---------------- cache (5 min) ----------------
  static List<_Issue>? _issues;
  static List<_Recv>? _recvs;
  static DateTime? _at;
  static Future<void>? _inflight;

  static void clearCache() {
    _issues = null;
    _recvs = null;
    _at = null;
  }

  static final DateFormat _ymd = DateFormat('yyyy-MM-dd');
  static final DateFormat _dmy = DateFormat('dd-MM-yyyy');

  // ---------------- detect ----------------
  static const List<String> _jobWords = [
    'job work', 'jobwork', 'job-work', 'job worker', 'jobworker', 'job wrok', 'jobwrok', 'karigar', 'kaarigar',
    'kareegar', 'job issue', 'job receive', 'job recive', 'job jama',
  ];

  /// null = not a job work question (other modules answer)
  static Future<AiAnswer?> handle(String raw, {bool force = false}) async {
    final t = ' ${raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s\-]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim()} ';
    final hasJob = _jobWords.any((w) => t.contains(' $w') || t.contains('$w '));
    // worker loss / metal ledger → that module (not here)
    final lossQ = RegExp(r' (loss|ghat|ghaat|ledger|metal ledger) ').hasMatch(t);
    if (!force && (!hasJob || lossQ)) return null;

    try {
      await _load();
    } catch (e) {
      return AiAnswer(
        text: 'Could not load job work data. Please check the internet and try again.',
        speech: 'Could not load job work data.',
      );
    }
    final issues = _issues ?? const <_Issue>[];
    final recvs = _recvs ?? const <_Recv>[];
    if (issues.isEmpty && recvs.isEmpty) {
      return const AiAnswer(text: 'No job work issue or receive entries found.', speech: 'No job work entries found.');
    }

    // ---- worker ----
    final names = <String>{
      ...issues.map((e) => e.worker),
      ...recvs.map((e) => e.worker),
    }..removeWhere((e) => e.isEmpty || e == '-');
    String? worker;
    for (final n in names) {
      final k = ' ${n.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim()} ';
      if (k.trim().isEmpty) continue;
      final first = k.trim().split(' ').first;
      final hit = t.contains(k) || (first.length >= 4 && t.contains(' $first '));
      if (hit && (worker == null || n.length > worker.length)) worker = n;
    }

    // ---- period ----
    final p = _period(t);

    // ---- intent ----
    final wantsPending = RegExp(r' (pending|baki|baaki|remaining|outstanding|pase|paase|not received|balance) ').hasMatch(t);
    final wantsReceive = RegExp(r' (receive|received|recive|recieve|receipt|jama|aavyu|avyu|aaya|return) ').hasMatch(t);
    final wantsIssue = RegExp(r' (issue|issued|isue|given|aapyu|apyu|diya|send|sent|out) ').hasMatch(t);

    if (wantsPending && !wantsIssue) return _pending(recvs, worker, p);
    if (wantsReceive && !wantsIssue) return _receive(recvs, worker, p);
    if (wantsIssue && !wantsReceive) return _issue(issues, worker, p);
    return _summary(issues, recvs, worker, p);
  }

  // =====================================================================
  //  LOAD (issue + receive together, no popup)
  // =====================================================================
  static Future<void> _load() {
    if (_issues != null && _at != null && DateTime.now().difference(_at!) < const Duration(minutes: 5)) {
      return Future.value();
    }
    if (_inflight != null) return _inflight!;
    _inflight = _fetch().whenComplete(() => _inflight = null);
    return _inflight!;
  }

  static Future<void> _fetch() async {
    final r = await Future.wait([
      ApiHelper().getRequest(ApiConstants.jobwork_issues, showLoading: false, receiveTimeout: const Duration(seconds: 60)),
      ApiHelper().getRequest(
        '${ApiConstants.jobwork_receive}?from=2000-01-01&to=${_ymd.format(DateTime.now())}',
        showLoading: false,
        receiveTimeout: const Duration(seconds: 60),
      ),
    ]);
    _issues = _list(r[0]?.data).map(_Issue.from).toList();
    _recvs = _list(r[1]?.data).map(_Recv.from).toList();
    _at = DateTime.now();
  }

  static List<Map> _list(dynamic body) {
    if (body is List) return body.whereType<Map>().toList();
    if (body is Map) {
      final d = body['data'];
      if (d is List) return d.whereType<Map>().toList();
      if (d is Map && d['data'] is List) return (d['data'] as List).whereType<Map>().toList();
    }
    return const [];
  }

  // =====================================================================
  //  ANSWERS
  // =====================================================================
  static AiAnswer _summary(List<_Issue> all, List<_Recv> allR, String? worker, _P p) {
    final iss = all.where((e) => _match(e.worker, worker) && p.has(e.date)).toList();
    final rec = allR.where((e) => _match(e.worker, worker) && p.has(e.date)).toList();
    final pend = allR.where((e) => _match(e.worker, worker) && e.pending > 0.0005 && !e.completed).toList();

    final iNet = _sum(iss.map((e) => e.net));
    final rNet = _sum(rec.map((e) => e.received));
    final pNet = _sum(pend.map((e) => e.pending));
    final who = worker == null ? 'All workers' : worker;

    // pending by worker (top)
    final byW = <String, double>{};
    for (final e in pend) {
      byW[e.worker] = (byW[e.worker] ?? 0) + e.pending;
    }
    final top = byW.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return AiAnswer(
      text: '🛠️ Job work · $who · ${p.label}\n'
          '📤 Issued: ${iss.length} vouchers · ${_g(iNet)} g net\n'
          '📥 Received: ${_g(rNet)} g net (${rec.where((e) => e.received > 0).length} vouchers)\n'
          '⏳ Pending with ${worker == null ? 'workers' : worker}: ${_g(pNet)} g net (${pend.length} vouchers)'
          '${worker == null && top.isNotEmpty ? '\nMost pending: ${top.take(3).map((e) => '${e.key} ${_g(e.value)} g').join(' · ')}' : ''}',
      speech: '${worker ?? 'Job work'}, ${p.label}. Issued ${_g(iNet)} grams, received ${_g(rNet)} grams. '
          'Pending ${_g(pNet)} grams.',
      stats: [
        AiStat('Issued', '${_g(iNet)} g'),
        AiStat('Received', '${_g(rNet)} g'),
        AiStat('Pending', '${_g(pNet)} g'),
        AiStat('Issue vouchers', '${iss.length}'),
        if (worker == null) AiStat('Workers', '${{...iss.map((e) => e.worker), ...rec.map((e) => e.worker)}.length}'),
      ],
      items: worker == null && top.isNotEmpty
          ? top
          .map((e) => AiRecord(
        title: e.key,
        subtitle: '${pend.where((x) => x.worker == e.key).length} pending vouchers',
        value: '${_g(e.value)} g',
        badge: 'Pending',
        badgeGood: false,
        details: [
          AiStat('Worker', e.key),
          AiStat('Pending net', '${_g(e.value)} g'),
          AiStat('Vouchers', pend.where((x) => x.worker == e.key).map((x) => x.voucher).join(', ')),
        ],
      ))
          .toList()
          : pend.map(_recvRecord).toList(),
      itemsTitle: worker == null ? 'Pending with workers' : 'Pending vouchers · $worker',
      followUps: [
        'Job work issue ${p.followLabel}',
        'Job work receive ${p.followLabel}',
        'Job work pending',
        if (top.isNotEmpty && worker == null) '${top.first.key} job work',
      ],
    );
  }

  static AiAnswer _issue(List<_Issue> all, String? worker, _P p) {
    final list = all.where((e) => _match(e.worker, worker) && p.has(e.date)).toList()
      ..sort((a, b) => (b.date ?? DateTime(1900)).compareTo(a.date ?? DateTime(1900)));
    final who = worker ?? 'All workers';
    if (list.isEmpty) {
      return AiAnswer(
        text: 'No job work issue found for $who · ${p.label}.',
        speech: 'No job work issue found.',
        followUps: ['Job work issue this month', 'Job work issue last month', 'Job work pending'],
      );
    }
    final net = _sum(list.map((e) => e.net));
    final gross = _sum(list.map((e) => e.gross));
    final pcs = _sum(list.map((e) => e.pcs));
    return AiAnswer(
      text: '📤 Job work issue · $who · ${p.label}\n'
          '${list.length} vouchers · gross ${_g(gross)} g · net ${_g(net)} g${pcs > 0 ? ' · ${_q(pcs)} pcs' : ''}',
      speech: '${list.length} job work issues, ${_g(net)} grams net, ${p.label}.',
      stats: [
        AiStat('Vouchers', '${list.length}'),
        AiStat('Gross', '${_g(gross)} g'),
        AiStat('Net', '${_g(net)} g'),
        if (pcs > 0) AiStat('Pcs', _q(pcs)),
        if (worker == null) AiStat('Workers', '${list.map((e) => e.worker).toSet().length}'),
      ],
      items: list
          .map((e) => _ref(AiRecord(
        title: e.voucher,
        subtitle: '${e.worker} · ${e.step.isNotEmpty ? '${e.step} · ' : ''}${_d(e.date)}',
        value: '${_g(e.net)} g',
        badge: 'Issue',
        badgeGood: true,
        details: [
          AiStat('Voucher', e.voucher),
          AiStat('Date', _d(e.date)),
          AiStat('Worker', e.worker),
          if (e.step.isNotEmpty) AiStat('Step', e.step),
          if (e.items.isNotEmpty) AiStat('Items', e.items),
          if (e.pcs > 0) AiStat('Pcs', _q(e.pcs)),
          AiStat('Gross', '${_g(e.gross)} g'),
          AiStat('Net', '${_g(e.net)} g'),
        ],
      ), 'jobwork_issue', e.id))
          .toList(),
      itemsTitle: 'Issue vouchers (newest first)',
      followUps: [
        'Job work receive ${p.followLabel}',
        'Job work pending',
        if (worker != null) '$worker pending',
      ],
    );
  }

  static AiAnswer _receive(List<_Recv> all, String? worker, _P p) {
    final list = all.where((e) => _match(e.worker, worker) && p.has(e.date) && e.received > 0.0005).toList()
      ..sort((a, b) => (b.date ?? DateTime(1900)).compareTo(a.date ?? DateTime(1900)));
    final who = worker ?? 'All workers';
    if (list.isEmpty) {
      return AiAnswer(
        text: 'No job work receive found for $who · ${p.label}.',
        speech: 'No job work receive found.',
        followUps: ['Job work receive this month', 'Job work pending', 'Job work issue this month'],
      );
    }
    final iNet = _sum(list.map((e) => e.issued));
    final rNet = _sum(list.map((e) => e.received));
    final pNet = _sum(list.map((e) => e.pending));
    final done = list.where((e) => e.completed).length;
    return AiAnswer(
      text: '📥 Job work receive · $who · ${p.label}\n'
          '${list.length} vouchers · issued ${_g(iNet)} g → received ${_g(rNet)} g · still pending ${_g(pNet)} g\n'
          '✅ Completed $done · ⏳ Partial / pending ${list.length - done}',
      speech: 'Received ${_g(rNet)} grams in ${list.length} job work vouchers, ${p.label}.',
      stats: [
        AiStat('Vouchers', '${list.length}'),
        AiStat('Issued', '${_g(iNet)} g'),
        AiStat('Received', '${_g(rNet)} g'),
        AiStat('Pending', '${_g(pNet)} g'),
      ],
      items: list.map(_recvRecord).toList(),
      itemsTitle: 'Receive vouchers (newest first)',
      followUps: ['Job work pending', 'Job work issue ${p.followLabel}', if (worker != null) '$worker issue'],
    );
  }

  static AiAnswer _pending(List<_Recv> all, String? worker, _P p) {
    // pending = whatever is still with the worker (date filter only if asked)
    final list = all
        .where((e) => _match(e.worker, worker) && e.pending > 0.0005 && !e.completed && (p.all || p.has(e.date)))
        .toList()
      ..sort((a, b) => b.pending.compareTo(a.pending));
    final who = worker ?? 'all workers';
    if (list.isEmpty) {
      return AiAnswer(
        text: '✅ Nothing pending with $who${p.all ? '' : ' · ${p.label}'}. All job work is received.',
        speech: 'Nothing is pending with $who.',
        followUps: ['Job work receive this month', 'Job work issue this month'],
      );
    }
    final pNet = _sum(list.map((e) => e.pending));
    final byW = <String, List<_Recv>>{};
    for (final e in list) {
      byW.putIfAbsent(e.worker, () => []).add(e);
    }
    final rows = byW.entries.toList()
      ..sort((a, b) => _sum(b.value.map((e) => e.pending)).compareTo(_sum(a.value.map((e) => e.pending))));
    final oldest = list.map((e) => e.date).whereType<DateTime>().fold<DateTime?>(null, (a, d) => a == null || d.isBefore(a) ? d : a);

    return AiAnswer(
      text: '⏳ Job work pending with $who${p.all ? '' : ' · ${p.label}'}\n'
          '${_g(pNet)} g net still to receive · ${list.length} vouchers'
          '${worker == null ? ' · ${byW.length} workers' : ''}'
          '${oldest != null ? '\nOldest pending issue: ${_d(oldest)} (${DateTime.now().difference(oldest).inDays} days)' : ''}',
      speech: '${_g(pNet)} grams pending with $who in ${list.length} vouchers.',
      stats: [
        AiStat('Pending', '${_g(pNet)} g'),
        AiStat('Vouchers', '${list.length}'),
        if (worker == null) AiStat('Workers', '${byW.length}'),
        if (oldest != null) AiStat('Oldest', _d(oldest)),
      ],
      items: worker == null
          ? rows
          .map((e) => AiRecord(
        title: e.key,
        subtitle: '${e.value.length} vouchers · issued ${_g(_sum(e.value.map((x) => x.issued)))} g',
        value: '${_g(_sum(e.value.map((x) => x.pending)))} g',
        badge: 'Pending',
        badgeGood: false,
        details: [
          AiStat('Worker', e.key),
          AiStat('Issued', '${_g(_sum(e.value.map((x) => x.issued)))} g'),
          AiStat('Received', '${_g(_sum(e.value.map((x) => x.received)))} g'),
          AiStat('Pending', '${_g(_sum(e.value.map((x) => x.pending)))} g'),
          AiStat('Vouchers', e.value.map((x) => x.voucher).join(', ')),
        ],
      ))
          .toList()
          : list.map(_recvRecord).toList(),
      itemsTitle: worker == null ? 'Pending worker wise (most first)' : 'Pending vouchers · $worker',
      followUps: [
        if (worker == null && rows.isNotEmpty) '${rows.first.key} pending',
        'Job work receive this month',
        'Job work issue this month',
      ],
    );
  }

  /// 🔗 tap → web jevu voucher details (items + PDF)
  static AiRecord _ref(AiRecord r, String module, String id) => id.isEmpty
      ? r
      : VoucherDetails.attachVoucher(
      r,
      VoucherRef(
        module: module,
        id: id,
        voucherNo: r.title,
        info: [for (final d in r.details) MapEntry(d.label, d.value)],
      ));

  static AiRecord _recvRecord(_Recv e) => _ref(_recvRecord0(e), 'jobwork_receive', e.id);

  static AiRecord _recvRecord0(_Recv e) => AiRecord(
    title: e.voucher,
    subtitle: '${e.worker} · ${e.step.isNotEmpty ? '${e.step} · ' : ''}${_d(e.date)}',
    value: e.pending > 0.0005 ? '${_g(e.pending)} g pending' : '${_g(e.received)} g',
    badge: e.completed ? 'Completed' : (e.received > 0.0005 ? 'Partial' : 'Pending'),
    badgeGood: e.completed,
    details: [
      AiStat('Voucher', e.voucher),
      AiStat('Date', _d(e.date)),
      AiStat('Worker', e.worker),
      if (e.step.isNotEmpty) AiStat('Step', e.step),
      if (e.process.isNotEmpty) AiStat('Process', e.process),
      if (e.items.isNotEmpty) AiStat('Items', e.items),
      AiStat('Issued', '${_g(e.issued)} g'),
      AiStat('Received', '${_g(e.received)} g'),
      AiStat('Pending', '${_g(e.pending)} g'),
      AiStat('Status', e.completed ? 'Completed' : (e.received > 0.0005 ? 'Partial' : 'Pending')),
    ],
  );

  // =====================================================================
  //  helpers
  // =====================================================================
  static bool _match(String name, String? worker) => worker == null || name.toLowerCase() == worker.toLowerCase();
  static double _sum(Iterable<double> v) => v.fold(0.0, (a, b) => a + b);
  static String _g(double v) => v.toStringAsFixed(3);
  static String _q(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  static String _d(DateTime? d) => d == null ? '-' : _dmy.format(d);

  static double number(dynamic v) => double.tryParse((v ?? '').toString().replaceAll(',', '').trim()) ?? 0;

  static String str(dynamic v) {
    final s = (v ?? '').toString().trim();
    return (s.isEmpty || s == 'null') ? '' : s;
  }

  static DateTime? date(dynamic v) {
    final s = str(v);
    if (s.isEmpty) return null;
    final iso = DateTime.tryParse(s.length >= 10 ? s.substring(0, 10) : s);
    if (iso != null) return iso;
    final m = RegExp(r'(\d{1,2})[-/](\d{1,2})[-/](\d{4})').firstMatch(s);
    if (m != null) return DateTime(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
    return null;
  }

  static _P _period(String t) {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    if (RegExp(r' (today|aaje|aje|aaj|aj) ').hasMatch(t)) return _P(today, today, 'today', 'today');
    if (RegExp(r' (yesterday|kale|kal|gaikale) ').hasMatch(t)) {
      final y = today.subtract(const Duration(days: 1));
      return _P(y, y, 'yesterday', 'yesterday');
    }
    if (RegExp(r' (this week|aa week|is week|aa athvadiye) ').hasMatch(t)) {
      final s = today.subtract(Duration(days: today.weekday - 1));
      return _P(s, today, 'this week', 'this week');
    }
    if (RegExp(r' (last month|gaya mahine|pichhla mahina|pichla mahina|previous month) ').hasMatch(t)) {
      return _P(DateTime(n.year, n.month - 1, 1), DateTime(n.year, n.month, 0), 'last month', 'last month');
    }
    if (RegExp(r' (this month|aa mahine|is mahine|current month) ').hasMatch(t)) {
      return _P(DateTime(n.year, n.month, 1), today, 'this month', 'this month');
    }
    if (RegExp(r' (this year|fy|financial year|aa varshe) ').hasMatch(t)) {
      final s = n.month >= 4 ? DateTime(n.year, 4, 1) : DateTime(n.year - 1, 4, 1);
      return _P(s, today, 'this FY', 'this year');
    }
    const months = ['january', 'february', 'march', 'april', 'may', 'june', 'july', 'august', 'september',
      'october', 'november', 'december'];
    const short = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
    for (var i = 0; i < 12; i++) {
      if (t.contains(' ${months[i]} ') || t.contains(' ${short[i]} ') || (i == 8 && t.contains(' sept '))) {
        final ym = RegExp(r' (20\d\d) ').firstMatch(t);
        var y = ym != null ? int.parse(ym[1]!) : n.year;
        if (ym == null && i + 1 > n.month) y -= 1;
        final name = DateFormat('MMMM yyyy').format(DateTime(y, i + 1, 1));
        return _P(DateTime(y, i + 1, 1), DateTime(y, i + 2, 0), name, name);
      }
    }
    return _P(null, null, 'all dates', 'this month', all: true);
  }
}

/// date range (null = all dates)
class _P {
  final DateTime? from, to;
  final String label, followLabel;
  final bool all;
  _P(this.from, this.to, this.label, this.followLabel, {this.all = false});

  bool has(DateTime? d) {
    if (all) return true;
    if (d == null) return false;
    final day = DateTime(d.year, d.month, d.day);
    return !day.isBefore(from!) && !day.isAfter(to!);
  }
}

class _Issue {
  String id = '';
  final String voucher, worker, step, items;
  final DateTime? date;
  final double gross, net, pcs;
  _Issue(this.voucher, this.worker, this.step, this.items, this.date, this.gross, this.net, this.pcs);

  static _Issue from(Map m) {
    final its = m['items'] is List ? (m['items'] as List).whereType<Map>().toList() : const <Map>[];
    String itemName(Map i) {
      final it = i['item'];
      return JobWorkAi.str(it is Map ? (it['item_name'] ?? it['name']) : (i['item_name'] ?? i['name']));
    }

    final names = its.map(itemName).where((e) => e.isNotEmpty).toSet().toList();
    var gross = JobWorkAi.number(m['gross_wt_sum']);
    var net = JobWorkAi.number(m['net_wt_sum']);
    if (gross == 0) gross = its.fold(0.0, (a, i) => a + JobWorkAi.number(i['gross_wt'] ?? i['gross_weight']));
    if (net == 0) net = its.fold(0.0, (a, i) => a + JobWorkAi.number(i['net_wt'] ?? i['net_weight']));
    final jw = m['job_worker'];
    final ps = m['production_step'];
    return _Issue(
      JobWorkAi.str(m['voucher_no']).isEmpty ? '-' : JobWorkAi.str(m['voucher_no']),
      JobWorkAi.str(jw is Map ? jw['name'] : (m['jobworker_name'] ?? m['job_worker_name'])).isEmpty
          ? '-'
          : JobWorkAi.str(jw is Map ? jw['name'] : (m['jobworker_name'] ?? m['job_worker_name'])),
      JobWorkAi.str(ps is Map ? ps['name'] : m['production_step_name']),
      names.join(', '),
      JobWorkAi.date(m['voucher_date'] ?? m['issue_date'] ?? m['created_at']),
      gross,
      net,
      its.fold(0.0, (a, i) => a + JobWorkAi.number(i['qty_pcs'])),
    )..id = JobWorkAi.str(m['id']);
  }
}

class _Recv {
  String id = '';
  final String voucher, worker, step, process, items, status;
  final DateTime? date;
  final double issued, received, pending;
  _Recv(this.voucher, this.worker, this.step, this.process, this.items, this.status, this.date, this.issued,
      this.received, this.pending);

  bool get completed => status == 'completed' || status == 'complete';

  static _Recv from(Map m) {
    final its = m['items'] is List ? (m['items'] as List).whereType<Map>().toList() : const <Map>[];
    final names = its
        .map((i) {
      final it = i['item'];
      return JobWorkAi.str(it is Map ? (it['item_name'] ?? it['name']) : (i['item_name'] ?? i['name']));
    })
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    final pr = m['process'];
    final issued = JobWorkAi.number(m['issue_net_wt']);
    final received = JobWorkAi.number(m['receive_net_wt']);
    var pending = JobWorkAi.number(m['pending_net_wt']);
    if (pending == 0 && m['pending_net_wt'] == null) pending = (issued - received).clamp(0, double.infinity).toDouble();
    final w = JobWorkAi.str(m['jobworker_name'] ?? (m['job_worker'] is Map ? m['job_worker']['name'] : null));
    return _Recv(
      JobWorkAi.str(m['voucher_no']).isEmpty ? '-' : JobWorkAi.str(m['voucher_no']),
      w.isEmpty ? '-' : w,
      JobWorkAi.str(m['production_step_name'] ?? (m['production_step'] is Map ? m['production_step']['name'] : null)),
      JobWorkAi.str(pr is Map ? pr['name'] : m['process_name']),
      names.join(', '),
      JobWorkAi.str(m['status']).toLowerCase(),
      JobWorkAi.date(m['voucher_date'] ?? m['created_at']),
      issued,
      received,
      pending,
    )..id = JobWorkAi.str(m['id']);
  }
}
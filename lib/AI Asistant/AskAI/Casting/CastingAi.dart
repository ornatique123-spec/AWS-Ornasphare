import 'dart:async';

import 'package:intl/intl.dart';

import '../../../Api_Constant/ApiConstants.dart';
import '../../../Api_Constant/api_helper.dart';
import '../core/ai_core.dart';

/// =======================================================================
///  🔥 CASTING AI — vacuum casting process (all stages)
///
///   1) Casting Heating         GET casting-heating
///   2) Casting Metal Issue     GET casting-metal-issue
///   3) Casting Receive         GET casting-receive
///   4) Tree Cutting Office     GET tree-cutting-office
///   5) Tree Cutting Issue      GET tree-cutting-issue
///   6) Tree Cutting Receive    GET tree-cutting-receive
///   7) Casting Sorting         GET casting-sorting
///   + one voucher full timeline: GET voucher-history?voucher_id=…
///
///  Questions (English / Gujlish):
///   • "casting summary" / "casting today" / "casting this month"
///   • "casting heating today"   • "metal issue this month"
///   • "casting receive loss"    • "tree cutting office"
///   • "tree cutting issue Ramesh" • "tree cutting receive last month"
///   • "sorting today"           • "casting pending"
///   • "casting loss" (casting receive + tree cutting receive, worker wise)
///   • "VV-001" / "VV-001 history" → full voucher timeline
///  No loader popups · 5 min cache · answers always in English.
/// =======================================================================
class CastingAi {
  CastingAi._();

  static final DateFormat _ymd = DateFormat('yyyy-MM-dd');
  static final DateFormat _dmy = DateFormat('dd-MM-yyyy');
  static const String _histUrl = '${ApiConstants.baseUrl}voucher-history';

  // ---------------- stages ----------------
  static final List<_Stage> stages = [
    _Stage('heating', 'Casting Heating', '🔥', ApiConstants.casting_heating,
        [' casting heating ', ' heating ', ' bhati ', ' heat '], [
          _Metric('Pcs', ['total_pcs'], ['qty', 'pcs'], count: true),
          _Metric('In bhati', ['in_bhati_pcs', 'in_bhati_count'], [], countWhere: 'in_bhati'),
        ]),
    _Stage('metal', 'Casting Metal Issue', '⚙️', ApiConstants.casting_metal_issue,
        [' casting metal ', ' metal issue ', ' silver issue ', ' metal ', ' silver '], [
          _Metric('Silver wt', ['silver_wt_total', 'silver_wt'], ['silver_wt'], grams: true),
          _Metric('Issued', ['issue_silver_wt_total', 'assigned_metal'], ['issue_silver_wt'], grams: true),
          _Metric('Pending', ['pending_metal'], [], grams: true, pending: true),
        ]),
    _Stage('receive', 'Casting Receive', '📥', ApiConstants.casting_receive,
        [' casting receive ', ' casting recive ', ' casting received ', ' release ', ' casting jama '], [
          _Metric('Release tree wt', ['release_tree_wt_total'], ['release_tree_wt'], grams: true),
          _Metric('Bhuko', ['release_tree_bhuko_total'], ['release_tree_bhuko'], grams: true),
          _Metric('Loss', ['loss_total'], ['loss'], grams: true, loss: true),
          _Metric('Pending', ['pending_receive'], [], grams: true, pending: true),
        ]),
    _Stage('office', 'Tree Cutting Office', '🏢', ApiConstants.tree_cutting_office,
        [' tree cutting office ', ' tree office ', ' office '], [
          _Metric('Tree wt', ['tree_wt_total'], ['tree_wt'], grams: true),
          _Metric('Tree bhuko', ['tree_bhuko_total'], ['tree_bhuko'], grams: true),
          _Metric('Office cut', ['office_cut_wt_total'], ['office_cut_wt'], grams: true),
          _Metric('Remaining', ['remaining_tree_wt_total'], ['remaining_tree_wt'], grams: true),
        ]),
    _Stage('treeissue', 'Tree Cutting Issue', '📤', ApiConstants.tree_cutting_issue,
        [' tree cutting issue ', ' tree issue ', ' cutting issue '], [
          _Metric('Tree wt issued', ['receive_tree_wt_total'], ['receive_tree_wt'], grams: true),
          _Metric('Pending', ['pending_tree_cutting'], [], grams: true, pending: true),
        ]),
    _Stage('treereceive', 'Tree Cutting Receive', '✂️', ApiConstants.tree_cutting_receive,
        [' tree cutting receive ', ' tree cutting recive ', ' tree receive ', ' cutting receive '], [
          _Metric('Issued tree wt', ['issue_tree_wt_total'], ['issue_tree_wt'], grams: true),
          _Metric('Received pc wt', ['receive_pc_wt_total'], ['receive_pc_wt'], grams: true),
          _Metric('Bhuko', ['receive_tree_bhuko_total'], ['receive_tree_bhuko'], grams: true),
          _Metric('Loss', ['loss_total'], ['loss'], grams: true, loss: true),
          _Metric('Pending', ['pending_receive'], [], grams: true, pending: true),
        ]),
    _Stage('sorting', 'Casting Sorting', '🗂️', ApiConstants.casting_sorting,
        [' casting sorting ', ' sorting ', ' sort ', ' sorted '], [
          _Metric('Weight', ['sorting_wt_total'], ['weight'], grams: true),
          _Metric('Qty', ['quantity_total'], ['quantity'], count: false),
          _Metric('Entries', ['sorting_count'], [], count: true),
        ]),
  ];

  static const List<String> _castWords = [
    ' casting ', ' cast ', ' vacuum ', ' tree ', ' bhati ', ' heating ', ' sorting ', ' buch ', ' tree cutting ',
    ' casting process ',
  ];

  // ---------------- cache ----------------
  static final Map<String, List<Map>> _data = {};
  static DateTime? _at;
  static Future<void>? _inflight;

  static void clearCache() {
    _data.clear();
    _at = null;
  }

  // =====================================================================
  //  ENTRY
  // =====================================================================
  /// null = not a casting question (other modules answer)
  static Future<AiAnswer?> handle(String raw, {bool force = false}) async {
    final t = ' ${raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s\-]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim()} ';
    final isCast = _castWords.any(t.contains) || stages.any((s) => s.words.take(1).any(t.contains));
    if (!force && !isCast) return null;

    try {
      await _load();
    } catch (_) {
      return const AiAnswer(
        text: 'Could not load casting data. Please check the internet and try again.',
        speech: 'Could not load casting data.',
      );
    }
    if (_data.values.every((l) => l.isEmpty)) {
      return const AiAnswer(text: 'No casting entries found.', speech: 'No casting entries found.');
    }

    // 1) voucher number → full timeline
    final v = _findVoucher(t);
    if (v != null) {
      final a = await _voucherHistory(v);
      if (a != null) return a;
    }

    // 2) worker
    final names = <String>{for (final l in _data.values) ...l.map(_worker)}..removeWhere((e) => e.isEmpty || e == '-');
    String? worker;
    for (final n in names) {
      final k = ' ${n.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim()} ';
      final first = k.trim().split(' ').first;
      final hit = t.contains(k) || (first.length >= 4 && t.contains(' $first '));
      if (hit && (worker == null || n.length > worker.length)) worker = n;
    }

    final p = _period(t);
    final wantsLoss = RegExp(r' (loss|ghat|ghaat|ghatt|vadharo|gain|profit) ').hasMatch(t);
    final wantsPending = RegExp(r' (pending|baki|baaki|remaining|outstanding) ').hasMatch(t);

    // 3) stage (longest matching word wins: "tree cutting issue" before "issue")
    _Stage? stage;
    var best = 0;
    for (final s in stages) {
      for (final w in s.words) {
        if (t.contains(w) && w.length > best) {
          best = w.length;
          stage = s;
        }
      }
    }
    // "casting issue" → metal issue · "casting receive" handled above
    if (stage == null && t.contains(' issue ') && !t.contains(' tree ')) stage = stages[1];

    if (wantsLoss && (stage == null || stage.metrics.any((m) => m.loss))) return _lossAnswer(stage, worker, p);
    if (wantsPending && stage == null) return _pendingAnswer(worker, p);
    if (stage != null) return _stageAnswer(stage, worker, p);
    return _summary(worker, p);
  }

  // =====================================================================
  //  LOAD (7 lists in parallel, no popup)
  // =====================================================================
  static Future<void> _load() {
    if (_data.isNotEmpty && _at != null && DateTime.now().difference(_at!) < const Duration(minutes: 5)) {
      return Future.value();
    }
    if (_inflight != null) return _inflight!;
    _inflight = _fetch().whenComplete(() => _inflight = null);
    return _inflight!;
  }

  static Future<void> _fetch() async {
    final to = _ymd.format(DateTime.now());
    final res = await Future.wait(stages.map((s) async {
      try {
        final r = await ApiHelper().getRequest('${s.api}?from_date=2000-01-01&to_date=$to',
            showLoading: false, receiveTimeout: const Duration(seconds: 60));
        return _list(r?.data);
      } catch (_) {
        return <Map>[];
      }
    }));
    _data.clear();
    for (var i = 0; i < stages.length; i++) {
      _data[stages[i].id] = res[i];
    }
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
  static AiAnswer _summary(String? worker, _P p) {
    final who = worker ?? 'All workers';
    final lines = <String>[];
    final stats = <AiStat>[];
    final items = <AiRecord>[];
    var totalLoss = 0.0;
    for (final s in stages) {
      final rows = _rows(s, worker, p);
      final main = s.metrics.first;
      final mv = _sum(rows, main);
      final lossM = s.metrics.where((m) => m.loss);
      final lv = lossM.isEmpty ? 0.0 : _sum(rows, lossM.first);
      totalLoss += lv;
      lines.add('${s.icon} ${s.title}: ${rows.length} vouchers · ${main.label} ${main.fmt(mv)}'
          '${lossM.isEmpty ? '' : ' · ${_lossText(lv)}'}');
      items.add(AiRecord(
        title: '${s.icon} ${s.title}',
        subtitle: '${rows.length} vouchers · ${p.label}',
        value: main.fmt(mv),
        badge: lossM.isEmpty ? '${rows.length}' : _lossText(lv),
        badgeGood: lossM.isEmpty || lv >= 0,
        details: [
          AiStat('Vouchers', '${rows.length}'),
          for (final m in s.metrics) AiStat(m.label, m.fmt(_sum(rows, m))),
        ],
      ));
    }
    stats
      ..add(AiStat('Heating', '${_rows(stages[0], worker, p).length}'))
      ..add(AiStat('Metal issue', '${_rows(stages[1], worker, p).length}'))
      ..add(AiStat('Sorting', '${_rows(stages[6], worker, p).length}'))
      ..add(AiStat('Total loss', _lossText(totalLoss)));
    return AiAnswer(
      text: '🔥 Casting · $who · ${p.label}\n${lines.join('\n')}',
      speech: 'Casting, ${p.label}. ${_rows(stages[1], worker, p).length} metal issues, '
          '${_rows(stages[6], worker, p).length} sortings. Total ${_lossText(totalLoss)}.',
      stats: stats,
      items: items,
      itemsTitle: 'All casting stages',
      followUps: ['Casting pending', 'Casting loss ${p.follow}', 'Metal issue ${p.follow}', 'Sorting ${p.follow}'],
    );
  }

  static AiAnswer _stageAnswer(_Stage s, String? worker, _P p) {
    final rows = _rows(s, worker, p)
      ..sort((a, b) => (_date(b) ?? DateTime(1900)).compareTo(_date(a) ?? DateTime(1900)));
    final who = worker ?? 'All workers';
    if (rows.isEmpty) {
      return AiAnswer(
        text: 'No ${s.title.toLowerCase()} found for $who · ${p.label}.',
        speech: 'No ${s.title.toLowerCase()} found.',
        followUps: ['${s.title} this month', '${s.title} last month', 'Casting summary'],
      );
    }
    final totals = [for (final m in s.metrics) '${m.label} ${m.fmt(_sum(rows, m))}'];
    return AiAnswer(
      text: '${s.icon} ${s.title} · $who · ${p.label}\n${rows.length} vouchers · ${totals.join(' · ')}',
      speech: '${rows.length} ${s.title.toLowerCase()} vouchers, ${p.label}. ${totals.first}.',
      stats: [
        AiStat('Vouchers', '${rows.length}'),
        for (final m in s.metrics) AiStat(m.label, m.fmt(_sum(rows, m))),
        if (worker == null) AiStat('Workers', '${rows.map(_worker).toSet().length}'),
      ],
      items: rows.map((r) => _record(s, r)).toList(),
      itemsTitle: '${s.title} vouchers (newest first)',
      followUps: [
        '${_next(s).title} ${p.follow}',
        if (s.metrics.any((m) => m.loss)) '${s.title} loss',
        'Casting summary ${p.follow}',
      ],
    );
  }

  static AiAnswer _lossAnswer(_Stage? only, String? worker, _P p) {
    final lossStages = only != null ? [only] : stages.where((s) => s.metrics.any((m) => m.loss)).toList();
    final byW = <String, double>{};
    final recs = <AiRecord>[];
    var total = 0.0;
    var srcTotal = 0.0;
    for (final s in lossStages) {
      final lm = s.metrics.firstWhere((m) => m.loss);
      for (final r in _rows(s, worker, p)) {
        final v = lm.value(r);
        total += v;
        srcTotal += s.metrics.first.value(r);
        byW[_worker(r)] = (byW[_worker(r)] ?? 0) + v;
        if (v.abs() > 0.0005) {
          recs.add(_record(s, r));
        }
      }
    }
    final rows = byW.entries.toList()..sort((a, b) => a.value.compareTo(b.value)); // most loss first (most negative)
    final title = only?.title ?? 'Casting + tree cutting';
    return AiAnswer(
      text: '⚖️ $title loss · ${worker ?? 'All workers'} · ${p.label}\n${_lossText(total)}'
          '${srcTotal > 0 ? ' (${(total.abs() / srcTotal * 100).toStringAsFixed(2)}% of ${_g(srcTotal)} g)' : ''}'
          '${worker == null && rows.isNotEmpty ? '\nWorker wise: ${rows.take(4).map((e) => '${e.key} ${_lossText(e.value)}').join(' · ')}' : ''}',
      speech: '$title, ${p.label}: ${_lossText(total)}.',
      stats: [
        AiStat('Total', _lossText(total)),
        if (srcTotal > 0) AiStat('Loss %', '${(total.abs() / srcTotal * 100).toStringAsFixed(2)}%'),
        AiStat('Vouchers', '${recs.length}'),
      ],
      items: worker == null
          ? rows
          .map((e) => AiRecord(
        title: e.key,
        subtitle: title,
        value: _lossText(e.value),
        badge: e.value < 0 ? 'Loss' : 'Gain',
        badgeGood: e.value >= 0,
        details: [AiStat('Worker', e.key), AiStat('Result', _lossText(e.value))],
      ))
          .toList()
          : recs,
      itemsTitle: worker == null ? 'Worker wise (most loss first)' : 'Vouchers with loss / gain',
      followUps: ['Casting receive loss', 'Tree cutting receive loss', 'Casting summary'],
    );
  }

  static AiAnswer _pendingAnswer(String? worker, _P p) {
    final lines = <String>[];
    final recs = <AiRecord>[];
    for (final s in stages) {
      final pm = s.metrics.where((m) => m.pending);
      if (pm.isEmpty) continue;
      final rows = _rows(s, worker, p.all ? p : p).where((r) => pm.first.value(r) > 0.0005).toList();
      if (rows.isEmpty) continue;
      lines.add('${s.icon} ${s.title}: ${rows.length} vouchers · ${_g(_sum(rows, pm.first))} g pending');
      recs.addAll(rows.map((r) => _record(s, r)));
    }
    if (lines.isEmpty) {
      return AiAnswer(
        text: '✅ Nothing pending in casting${worker == null ? '' : ' for $worker'}.',
        speech: 'Nothing is pending in casting.',
        followUps: const ['Casting summary', 'Casting loss'],
      );
    }
    return AiAnswer(
      text: '⏳ Casting pending · ${worker ?? 'All workers'}${p.all ? '' : ' · ${p.label}'}\n${lines.join('\n')}',
      speech: '${recs.length} casting vouchers are pending.',
      stats: [AiStat('Pending vouchers', '${recs.length}')],
      items: recs,
      itemsTitle: 'Pending vouchers',
      followUps: const ['Casting summary', 'Metal issue pending', 'Casting loss'],
    );
  }

  // ---------------- one voucher → full history ----------------
  static ({String no, int? id})? _findVoucher(String t) {
    String norm(String x) => x.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final tokens = t.toUpperCase().split(' ').where((w) => RegExp(r'\d').hasMatch(w) && RegExp(r'[A-Z]').hasMatch(w));
    final joined = norm(t);
    for (final l in _data.values) {
      for (final r in l) {
        final no = (r['voucher_no'] ?? '').toString();
        final n = norm(no);
        if (n.length < 3) continue;
        if (tokens.any((w) => norm(w) == n) || (n.length >= 5 && joined.contains(n))) {
          return (no: no, id: int.tryParse('${r['vacuum_voucher_id'] ?? r['voucher_id'] ?? ''}'));
        }
      }
    }
    return null;
  }

  static Future<AiAnswer?> _voucherHistory(({String no, int? id}) v) async {
    try {
      var id = v.id;
      if (id == null) {
        final r0 = await ApiHelper().getRequest(_histUrl, showLoading: false, receiveTimeout: const Duration(seconds: 40));
        final d0 = r0?.data is Map ? (r0!.data as Map)['data'] : null;
        final list = d0 is Map && d0['vouchers'] is List ? (d0['vouchers'] as List).whereType<Map>() : const <Map>[];
        for (final x in list) {
          if ((x['voucher_no'] ?? '').toString().toUpperCase() == v.no.toUpperCase()) {
            id = int.tryParse('${x['id']}');
            break;
          }
        }
      }
      if (id == null) return null;
      final r = await ApiHelper().getRequest('$_histUrl?voucher_id=$id',
          showLoading: false, receiveTimeout: const Duration(seconds: 40));
      final body = r?.data;
      final data = body is Map && body['data'] is Map ? body['data'] as Map : null;
      if (data == null) return null;
      final vo = data['voucher'] is Map ? data['voucher'] as Map : const {};
      final h = data['history'] is Map ? data['history'] as Map : const {};
      final sum = h['summary'] is Map ? h['summary'] as Map : const {};
      String s(dynamic x, [String d = '-']) {
        final y = (x ?? '').toString().trim();
        return y.isEmpty || y == 'null' ? d : y;
      }

      const keys = [
        ('casting_heating', 'Casting Heating', '🔥', 'total_count'),
        ('casting_metal_issue', 'Casting Metal Issue', '⚙️', 'issue_silver_wt_total'),
        ('casting_receive', 'Casting Receive', '📥', 'release_tree_total_wt_total'),
        ('tree_cutting_office', 'Tree Cutting Office', '🏢', 'tree_wt_total'),
        ('tree_cutting_issue', 'Tree Cutting Issue', '📤', 'receive_tree_wt_total'),
        ('tree_cutting_receive', 'Tree Cutting Receive', '✂️', 'receive_pc_wt_total'),
        ('casting_sorting', 'Casting Sorting', '🗂️', 'sorting_wt_total'),
      ];
      final recs = <AiRecord>[];
      var done = 0;
      var loss = 0.0;
      for (final k in keys) {
        final st = h[k.$1];
        if (st is! Map) continue;
        final rows = st['rows'] is List ? (st['rows'] as List).length : 0;
        if (rows > 0) done++;
        final l = double.tryParse(s(st['loss_total'], '0')) ?? 0;
        loss += l;
        recs.add(AiRecord(
          title: '${k.$3} ${k.$2}',
          subtitle: rows > 0 ? '$rows entries' : 'Not done yet',
          value: s(st[k.$4], rows > 0 ? '$rows' : '-'),
          badge: rows > 0 ? 'Done' : 'Pending',
          badgeGood: rows > 0,
          details: [
            for (final e in st.entries)
              if (e.key != 'rows' && e.value is! Map && e.value is! List)
                AiStat(e.key.toString().replaceAll('_', ' '), s(e.value)),
          ],
        ));
      }
      final vno = s(vo['voucher_no'], v.no);
      return AiAnswer(
        text: '🧾 $vno · ${s(vo['process_name'])} · ${s(vo['worker_name'])} · ${s(vo['voucher_date_view'] ?? vo['voucher_date'])}\n'
            'Gross ${s(sum['gross_wt'] ?? vo['gross_wt_total'], '0')} g · Net ${s(sum['net_wt'] ?? vo['net_wt_total'], '0')} g · '
            'Silver ${s(sum['silver_wt'] ?? vo['silver_wt_total'], '0')} g · Pcs ${s(sum['total_pcs'] ?? vo['total_pcs'], '0')}\n'
            '$done of ${recs.length} stages done${loss.abs() > 0.0005 ? ' · loss ${_g(loss)} g' : ''}',
        speech: 'Voucher $vno. $done of ${recs.length} stages done.',
        stats: [
          AiStat('Voucher', vno),
          AiStat('Worker', s(vo['worker_name'])),
          AiStat('Net wt', '${s(sum['net_wt'] ?? vo['net_wt_total'], '0')} g'),
          AiStat('Stages', '$done / ${recs.length}'),
        ],
        items: recs,
        itemsTitle: 'Timeline · $vno',
        followUps: const ['Casting summary', 'Casting pending', 'Voucher history report'],
      );
    } catch (_) {
      return null;
    }
  }

  // =====================================================================
  //  helpers
  // =====================================================================
  static _Stage _next(_Stage s) => stages[(stages.indexOf(s) + 1) % stages.length];

  static List<Map> _rows(_Stage s, String? worker, _P p) => (_data[s.id] ?? const <Map>[])
      .where((r) => (worker == null || _worker(r).toLowerCase() == worker.toLowerCase()) && p.has(_date(r)))
      .toList();

  static double _sum(List<Map> rows, _Metric m) => rows.fold(0.0, (a, r) => a + m.value(r));

  static AiRecord _record(_Stage s, Map r) {
    final main = s.metrics.first;
    final lm = s.metrics.where((m) => m.loss);
    final lv = lm.isEmpty ? 0.0 : lm.first.value(r);
    final pm = s.metrics.where((m) => m.pending);
    final pv = pm.isEmpty ? 0.0 : pm.first.value(r);
    final buchs = _items(r).map((i) => (i['buch_no'] ?? '').toString()).where((e) => e.isNotEmpty && e != 'null').toSet();
    return AiRecord(
      title: _str(r['voucher_no'], '-'),
      subtitle: '${_worker(r)} · ${_str(r['process_name'], s.title)} · ${_d(_date(r))}',
      value: main.fmt(main.value(r)),
      badge: lm.isNotEmpty && lv.abs() > 0.0005 ? _lossText(lv) : (pv > 0.0005 ? 'Pending' : s.title.split(' ').last),
      badgeGood: lm.isNotEmpty ? lv >= 0 : pv <= 0.0005,
      details: [
        AiStat('Stage', s.title),
        AiStat('Voucher', _str(r['voucher_no'], '-')),
        AiStat('Date', _d(_date(r))),
        AiStat('Worker', _worker(r)),
        if (_str(r['process_name'], '').isNotEmpty) AiStat('Process', _str(r['process_name'], '')),
        if (_str(r['total_pcs'], '').isNotEmpty) AiStat('Pcs', _str(r['total_pcs'], '')),
        for (final m in s.metrics) AiStat(m.label, m.fmt(m.value(r))),
        if (buchs.isNotEmpty) AiStat('Buch', buchs.take(12).join(', ')),
      ],
    );
  }

  static List<Map> _items(Map r) {
    for (final k in const ['items', 'custom_items', 'rows']) {
      if (r[k] is List) return (r[k] as List).whereType<Map>().toList();
    }
    return const [];
  }

  static String _worker(Map r) {
    final w = r['worker'];
    final s = _str(r['worker_name'] ?? (w is Map ? w['name'] : w) ?? r['jobworker_name'], '');
    return s.isEmpty ? '-' : s;
  }

  static DateTime? _date(Map r) => _toDate(r['voucher_date'] ?? r['date'] ?? r['created_at']);

  static String _str(dynamic v, String d) {
    final s = (v ?? '').toString().trim();
    return (s.isEmpty || s == 'null') ? d : s;
  }

  static double number(dynamic v) {
    if (v is bool) return v ? 1 : 0;
    return double.tryParse((v ?? '').toString().replaceAll(',', '').trim()) ?? 0;
  }

  static DateTime? _toDate(dynamic v) {
    final s = (v ?? '').toString().trim();
    if (s.isEmpty || s == 'null') return null;
    final iso = DateTime.tryParse(s.length >= 10 ? s.substring(0, 10) : s);
    if (iso != null) return iso;
    final m = RegExp(r'(\d{1,2})[-/](\d{1,2})[-/](\d{4})').firstMatch(s);
    if (m != null) return DateTime(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
    return null;
  }

  static String _g(double v) => v.toStringAsFixed(3);
  static String _d(DateTime? d) => d == null ? '-' : _dmy.format(d);

  /// API loss sign: − = loss (ghat), + = gain (vadharo)
  static String _lossText(double v) => v.abs() < 0.0005 ? 'No loss' : (v < 0 ? 'Loss ${_g(-v)} g' : 'Gain ${_g(v)} g');

  static _P _period(String t) {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    if (RegExp(r' (today|aaje|aje|aaj|aj) ').hasMatch(t)) return _P(today, today, 'today', 'today');
    if (RegExp(r' (yesterday|kale|kal|gaikale) ').hasMatch(t)) {
      final y = today.subtract(const Duration(days: 1));
      return _P(y, y, 'yesterday', 'yesterday');
    }
    if (RegExp(r' (this week|aa week|is week) ').hasMatch(t)) {
      return _P(today.subtract(Duration(days: today.weekday - 1)), today, 'this week', 'this week');
    }
    if (RegExp(r' (last month|gaya mahine|pichhla mahina|pichla mahina|previous month) ').hasMatch(t)) {
      return _P(DateTime(n.year, n.month - 1, 1), DateTime(n.year, n.month, 0), 'last month', 'last month');
    }
    if (RegExp(r' (this month|aa mahine|is mahine|current month) ').hasMatch(t)) {
      return _P(DateTime(n.year, n.month, 1), today, 'this month', 'this month');
    }
    if (RegExp(r' (this year|fy|financial year) ').hasMatch(t)) {
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

class _Stage {
  final String id, title, icon, api;
  final List<String> words;
  final List<_Metric> metrics;
  _Stage(this.id, this.title, this.icon, this.api, this.words, this.metrics);
}

/// one number of a voucher: list total key first, else sum of items[key]
class _Metric {
  final String label;
  final List<String> listKeys, itemKeys;
  final bool grams, loss, pending, count;
  final String? countWhere;
  _Metric(this.label, this.listKeys, this.itemKeys,
      {this.grams = false, this.loss = false, this.pending = false, this.count = false, this.countWhere});

  double value(Map r) {
    for (final k in listKeys) {
      final v = r[k];
      if (v != null && v is! Map && v is! List && v.toString().trim().isNotEmpty && v.toString() != 'null') {
        return CastingAi.number(v);
      }
    }
    final its = CastingAi._items(r);
    if (countWhere != null) {
      return its.where((i) => i[countWhere] == true || '${i[countWhere]}' == '1').length.toDouble();
    }
    if (itemKeys.isNotEmpty && its.isNotEmpty) {
      return its.fold(0.0, (a, i) {
        for (final k in itemKeys) {
          if (i[k] != null) return a + CastingAi.number(i[k]);
        }
        return a;
      });
    }
    if (count) return its.length.toDouble();
    return 0;
  }

  String fmt(double v) => grams ? '${v.toStringAsFixed(3)} g' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2));
}

class _P {
  final DateTime? from, to;
  final String label, follow;
  final bool all;
  _P(this.from, this.to, this.label, this.follow, {this.all = false});

  bool has(DateTime? d) {
    if (all) return true;
    if (d == null) return false;
    final day = DateTime(d.year, d.month, d.day);
    return !day.isBefore(from!) && !day.isAfter(to!);
  }
}
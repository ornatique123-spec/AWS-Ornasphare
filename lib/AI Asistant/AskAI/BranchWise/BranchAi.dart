import 'dart:async';

import 'package:intl/intl.dart';
import 'package:pecifician_sysytem/Settings/BranchManagementScreen.dart' show BranchApi, Company;

import '../../../Api_Constant/ApiConstants.dart';
import '../../../Api_Constant/api_helper.dart';
import '../../../Reports/BranchAccess.dart';
import '../../VoucherDetails.dart';
import '../core/ai_core.dart';

/// =======================================================================
///  🏢 BRANCH AI — main company admin can see ANY branch by asking
///
///  Same backend as the Branch Reports screens:
///    company/branch-reports/<report>?report_branches=slug1,slug2&per_page=50
///      sales-summary · approval-outstanding · worker-loss (+ job work) · stock-position
///
///  Ask:
///   • "Dishank branch sales today"        • "all branches sales this month"
///   • "branch wise approval pending"      • "Patel branch worker loss"
///   • "Dishank branch job work"           • "branch wise stock"
///   • "branch summary" (sales + approval + loss for every branch)
///  Branch chip in Ask AI → pick branches once, then every question = those branches.
///  Only the main company admin sees / uses this (same rule as Branch Reports).
/// =======================================================================
class BranchAi {
  BranchAi._();

  // ---------------- branches ----------------
  static List<Company> branches = [];
  static int? mainId;
  static bool canUse = false;
  static final Set<int> selected = {}; // chip selection (empty = all branches)
  static Future<void>? _initF;

  /// call once (Ask AI initState) — admin check + branch list
  static Future<void> init() => _initF ??= _init();

  static Future<void> _init() async {
    try {
      if (!await BranchAccess.isMainCompanyAdmin()) return;
      final o = await BranchApi.fetchOverview();
      branches = [if (o.mainCompany != null) o.mainCompany!, ...o.branches];
      mainId = o.mainCompany?.id;
      canUse = branches.length > 1;
    } catch (_) {
      canUse = false; // branch user / staff → no branch questions
    }
  }

  static String label(Company c) => c.isMain ? '${c.name} (Main)' : c.name;
  static String get selectedText {
    final s = branches.where((c) => selected.contains(c.id)).toList();
    return s.isEmpty || s.length == branches.length ? 'All branches' : s.map((c) => c.name).join(', ');
  }

  // ---------------- 🏢 branch cards: tap → that branch's details ----------------
  static final Expando<Future<AiAnswer> Function()> _tap = Expando('branchTap');
  static Future<AiAnswer> Function()? tapOf(Object r) => _tap[r];
  static bool isBranchCard(Object r) => _tap[r] != null;
  static AiRecord _card(AiRecord r, Future<AiAnswer> Function() onTap) {
    _tap[r] = onTap;
    return r;
  }

  // ---------------- cache (3 min per report + branch set) ----------------
  static final Map<String, ({DateTime at, List<Map> rows})> _cache = {};
  static void clearCache() => _cache.clear();

  static final DateFormat _dmy = DateFormat('dd-MM-yyyy');

  // ---------------- topics ----------------
  static const _sale = _Topic('sales-summary', 'Sales', '🧾', ['sale_date', 'date', 'created_at'],
      ['voucher_no', 'bill_no'], ['total_net_weight', 'net_weight'], ['net_total', 'total_amount', 'amount']);
  static const _appr = _Topic('approval-outstanding', 'Approval outstanding', '📋', ['date', 'approval_date', 'created_at'],
      ['approval_no', 'voucher_no'], ['net_weight', 'total_net_weight'], ['pending_amount', 'net_total']);
  static const _loss = _Topic('worker-loss', 'Worker loss', '⚖️', ['process_datetime', 'date', 'created_at'],
      ['voucher_no'], ['source_wt'], []);
  static const _stock = _Topic('stock-position', 'Stock position', '📦', ['date', 'created_at'],
      ['item_name', 'label_code', 'name'], ['net_weight', 'net_wt', 'total_net_weight', 'closing_net_weight'], []);

  // =====================================================================
  //  ENTRY — null = not a branch question
  // =====================================================================
  static Future<AiAnswer?> handle(String raw, {bool force = false}) async {
    await init();
    if (!canUse) return null;
    final t = ' ${raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s\-]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim()} ';

    // which branches did they say?
    final named = <Company>[];
    for (final c in branches) {
      final n = ' ${c.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim()} ';
      final first = n.trim().split(' ').first;
      final slug = (c.slug ?? '').toLowerCase();
      if (t.contains(n) || (first.length >= 4 && t.contains(' $first ')) || (slug.isNotEmpty && t.contains(' $slug '))) {
        named.add(c);
      }
    }
    final allWords = RegExp(r' (all branch|all branches|badhi branch|badha branch|every branch|branch wise|branchwise|branch-wise|har branch) ')
        .hasMatch(t);
    final saysBranch = t.contains(' branch ') || t.contains(' branches ') || t.contains(' main company ');
    // without the Branch chip → only when the word "branch" is said (so "Dishank Patel sales" stays normal)
    if (!force && !allWords && !saysBranch) return null;

    final pick = named.isNotEmpty
        ? named
        : (allWords || selected.isEmpty ? branches : branches.where((c) => selected.contains(c.id)).toList());
    final p = _period(t);

    // topic
    final topic = RegExp(r' (job work|jobwork|job worker|karigar) ').hasMatch(t)
        ? 'job'
        : RegExp(r' (loss|ghat|ghaat|worker loss) ').hasMatch(t)
        ? 'loss'
        : RegExp(r' (approval|aproval|approvel|outstanding) ').hasMatch(t)
        ? 'approval'
        : RegExp(r' (stock|position|maal) ').hasMatch(t)
        ? 'stock'
        : RegExp(r' (sale|sales|bill|bills|vechan|vechayu|invoice) ').hasMatch(t)
        ? 'sale'
        : 'summary';
    try {
      switch (topic) {
        case 'sale':
          return await _topicAnswer(_sale, pick, p, t);
        case 'approval':
          return await _topicAnswer(_appr, pick, p, t);
        case 'loss':
          return await _lossAnswer(pick, p, t, jobOnly: false);
        case 'job':
          return await _lossAnswer(pick, p, t, jobOnly: true);
        case 'stock':
          return await _topicAnswer(_stock, pick, p, t, noDate: true);
        default:
          return await _summary(pick, p);
      }
    } catch (e) {
      return AiAnswer(
        text: 'Could not load branch data (${pick.map((c) => c.name).join(', ')}). Please try again.',
        speech: 'Could not load branch data.',
      );
    }
  }

  // =====================================================================
  //  LOAD  company/branch-reports/<name>?report_branches=a,b  (all pages, no popup)
  // =====================================================================
  static Future<List<Map>> _rows(String name, List<Company> pick) async {
    final slugs = pick.map((c) => Uri.encodeQueryComponent(c.slug ?? c.id.toString())).join(',');
    final key = '$name|$slugs';
    final c = _cache[key];
    if (c != null && DateTime.now().difference(c.at) < const Duration(minutes: 3)) return c.rows;
    const per = 50;
    final out = <Map>[];
    for (var page = 1; page <= 60; page++) {
      var url = '${ApiConstants.baseUrl}company/branch-reports/$name?report_branches=$slugs&per_page=$per';
      if (page > 1) url += '&page=$page&start=${(page - 1) * per}';
      final res = await ApiHelper().getRequest(url, showLoading: false, receiveTimeout: const Duration(seconds: 60));
      final body = res?.data;
      if (body is! Map) break;
      if (body['success'] == false) throw Exception(body['message'] ?? 'failed');
      final d = body['data'];
      final dynamic raw = d is List ? d : (d is Map ? (d['data'] ?? d['rows'] ?? d['items']) : null);
      final list = raw is List ? raw.whereType<Map>().toList() : <Map>[];
      out.addAll(list);
      final total = int.tryParse('${body['recordsFiltered'] ?? body['recordsTotal'] ?? ''}');
      Map? meta = body['meta'] is Map ? body['meta'] : (body['pagination'] is Map ? body['pagination'] : null);
      if (meta == null && d is Map && d['current_page'] != null) meta = d;
      final cur = int.tryParse('${meta?['current_page'] ?? ''}') ?? 0;
      final last = int.tryParse('${meta?['last_page'] ?? ''}') ?? 0;
      final more = total != null ? out.length < total && list.isNotEmpty : (last > 0 ? cur < last : list.length >= per);
      if (!more) break;
    }
    _cache[key] = (at: DateTime.now(), rows: out);
    return out;
  }

  static String _branchOf(Map r) {
    final bn = '${r['branch_name'] ?? ''}'.trim();
    if (bn.isNotEmpty && bn != 'null' && bn != '-') return bn;
    final id = int.tryParse('${r['company_id'] ?? ''}');
    for (final c in branches) {
      if (c.id == id) return c.name;
    }
    final b = r['branch'] ?? r['branch_name'] ?? r['company'];
    if (b is Map && b['name'] != null) return b['name'].toString();
    final s = (b ?? r['company_name'] ?? '').toString().trim();
    return s.isEmpty || s == 'null' ? 'Main' : s;
  }

  // =====================================================================
  //  ANSWERS
  // =====================================================================
  static Future<AiAnswer> _topicAnswer(_Topic tp, List<Company> pick, _P p, String t, {bool noDate = false}) async {
    final all = await _rows(tp.name, pick);
    // customer filter (said a customer name that exists in this data)
    String? party;
    for (final r in all) {
      final n = _party(r);
      if (n.length < 3) continue;
      final k = ' ${n.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim()} ';
      if (t.contains(k) && (party == null || n.length > party.length)) party = n;
    }
    final rows = all
        .where((r) => (noDate || p.has(_date(r, tp.dateKeys))) && (party == null || _party(r) == party))
        .toList()
      ..sort((a, b) => (_date(b, tp.dateKeys) ?? DateTime(1900)).compareTo(_date(a, tp.dateKeys) ?? DateTime(1900)));

    final by = <String, List<Map>>{};
    for (final r in rows) {
      by.putIfAbsent(_branchOf(r), () => []).add(r);
    }
    final wt = rows.fold<double>(0, (a, r) => a + _num(r, tp.wtKeys));
    final amt = rows.fold<double>(0, (a, r) => a + _num(r, tp.amtKeys));
    final where = pick.length == branches.length ? 'All branches' : pick.map((c) => c.name).join(', ');
    final when = noDate ? 'now' : p.label;

    final lines = by.entries
        .map((e) => '${e.key}: ${e.value.length} · ${_g(e.value.fold<double>(0, (a, r) => a + _num(r, tp.wtKeys)))} g'
        '${tp.amtKeys.isEmpty ? '' : ' · ₹${_a(e.value.fold<double>(0, (a, r) => a + _num(r, tp.amtKeys)))}'}')
        .join('\n');

    final single = by.length <= 1;
    return AiAnswer(
      text: '${tp.icon} ${tp.title} · $where${party == null ? '' : ' · $party'} · $when\n'
          '${rows.length} entries · net ${_g(wt)} g${tp.amtKeys.isEmpty ? '' : ' · ₹${_a(amt)}'}'
          '${rows.isEmpty ? '' : '\n$lines'}',
      speech: '${tp.title}, $where, $when: ${rows.length} entries, ${_g(wt)} grams.',
      stats: [
        AiStat('Entries', '${rows.length}'),
        AiStat('Net wt', '${_g(wt)} g'),
        if (tp.amtKeys.isNotEmpty) AiStat('Amount', '₹${_a(amt)}'),
        AiStat('Branches', '${by.length}'),
      ],
      // one branch → its vouchers · many → one card per branch
      items: single
          ? rows.take(200).map((r) => _rowRecord(tp, r)).toList()
          : by.entries
          .map((e) => _card(AiRecord(
        title: e.key,
        subtitle: '${tp.title} · ${e.value.length} entries · $when',
        value: '${_g(e.value.fold<double>(0, (a, r) => a + _num(r, tp.wtKeys)))} g',
        badge: tp.amtKeys.isEmpty ? '${e.value.length}' : '₹${_a(e.value.fold<double>(0, (a, r) => a + _num(r, tp.amtKeys)))}',
        badgeGood: true,
        details: [
          AiStat('Branch', e.key),
          AiStat('Entries', '${e.value.length}'),
          AiStat('Net wt', '${_g(e.value.fold<double>(0, (a, r) => a + _num(r, tp.wtKeys)))} g'),
          if (tp.amtKeys.isNotEmpty) AiStat('Amount', '₹${_a(e.value.fold<double>(0, (a, r) => a + _num(r, tp.amtKeys)))}'),
        ],
      ), () async => _branchList(tp, e.key, e.value, when)))
          .followedBy(rows.take(200).map((r) => _rowRecord(tp, r))) // 🔗 vouchers stay tappable
          .toList(),
      itemsTitle: single ? '${tp.title} (newest first)' : 'Branch wise · then every entry',
      followUps: [
        for (final b in by.keys.take(2)) '$b branch ${tp.title.toLowerCase()} ${p.follow}',
        'All branches ${tp.title.toLowerCase()} ${p.follow}',
        'Branch summary ${p.follow}',
      ],
    );
  }

  static Future<AiAnswer> _lossAnswer(List<Company> pick, _P p, String t, {required bool jobOnly}) async {
    var rows = await _rows(_loss.name, pick);
    if (jobOnly) {
      final job = rows.where((r) => '${r['stage'] ?? ''}'.toLowerCase().contains('job')).toList();
      if (job.isNotEmpty) rows = job;
    }
    // worker filter
    String? worker;
    for (final r in rows) {
      final n = '${r['worker_name'] ?? ''}'.trim();
      if (n.length < 3) continue;
      final k = ' ${n.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim()} ';
      final first = k.trim().split(' ').first;
      if ((t.contains(k) || (first.length >= 4 && t.contains(' $first '))) && (worker == null || n.length > worker.length)) {
        worker = n;
      }
    }
    rows = rows.where((r) => p.has(_date(r, _loss.dateKeys)) && (worker == null || '${r['worker_name']}'.trim() == worker)).toList();
    double n(Map r, String k) => double.tryParse('${r[k] ?? ''}'.replaceAll(',', '')) ?? 0;
    final src = rows.fold<double>(0, (a, r) => a + n(r, 'source_wt'));
    final rec = rows.fold<double>(0, (a, r) => a + n(r, 'receive_wt') + n(r, 'bhuko'));
    final loss = rows.fold<double>(0, (a, r) => a + n(r, 'loss')); // − = loss
    final by = <String, List<Map>>{};
    for (final r in rows) {
      by.putIfAbsent(_branchOf(r), () => []).add(r);
    }
    final where = pick.length == branches.length ? 'All branches' : pick.map((c) => c.name).join(', ');
    final title = jobOnly ? 'Job work' : 'Worker loss';
    String lt(double v) => v.abs() < 0.0005 ? 'No loss' : (v < 0 ? 'Loss ${_g(-v)} g' : 'Gain ${_g(v)} g');
    return AiAnswer(
      text: '${jobOnly ? '🛠️' : '⚖️'} $title · $where${worker == null ? '' : ' · $worker'} · ${p.label}\n'
          'Issued ${_g(src)} g → received ${_g(rec)} g · ${lt(loss)}'
          '${src > 0 ? ' (${(loss.abs() / src * 100).toStringAsFixed(2)}%)' : ''}'
          '${by.length > 1 ? '\n${by.entries.map((e) => '${e.key}: ${lt(e.value.fold<double>(0, (a, r) => a + n(r, 'loss')))}').join('\n')}' : ''}',
      speech: '$title, $where, ${p.label}: ${lt(loss)}.',
      stats: [
        AiStat('Issued', '${_g(src)} g'),
        AiStat('Received', '${_g(rec)} g'),
        AiStat('Result', lt(loss)),
        AiStat('Entries', '${rows.length}'),
      ],
      items: by.length > 1
          ? by.entries.map((e) {
        final l = e.value.fold<double>(0, (a, r) => a + n(r, 'loss'));
        return _card(AiRecord(
          title: e.key,
          subtitle: '$title · ${e.value.length} entries · ${p.label}',
          value: '${_g(e.value.fold<double>(0, (a, r) => a + n(r, 'source_wt')))} g issued',
          badge: lt(l),
          badgeGood: l >= 0,
          details: [
            AiStat('Branch', e.key),
            AiStat('Issued', '${_g(e.value.fold<double>(0, (a, r) => a + n(r, 'source_wt')))} g'),
            AiStat('Received', '${_g(e.value.fold<double>(0, (a, r) => a + n(r, 'receive_wt') + n(r, 'bhuko')))} g'),
            AiStat('Result', lt(l)),
          ],
        ), () async => _lossList(title, e.key, e.value, p.label));
      }).toList()
          : rows.take(200).map(_lossRecord).toList(),
      itemsTitle: by.length > 1 ? 'Branch wise' : '$title entries',
      followUps: ['All branches ${title.toLowerCase()} ${p.follow}', 'Branch summary ${p.follow}'],
    );
  }

  static Future<AiAnswer> _summary(List<Company> pick, _P p) async {
    final r = await Future.wait([_rows(_sale.name, pick), _rows(_appr.name, pick), _rows(_loss.name, pick)]);
    final sales = r[0].where((x) => p.has(_date(x, _sale.dateKeys))).toList();
    final appr = r[1].where((x) => p.has(_date(x, _appr.dateKeys))).toList();
    final loss = r[2].where((x) => p.has(_date(x, _loss.dateKeys))).toList();
    final names = <String>{...sales.map(_branchOf), ...appr.map(_branchOf), ...loss.map(_branchOf), ...pick.map((c) => c.name)};
    double n(Map m, String k) => double.tryParse('${m[k] ?? ''}'.replaceAll(',', '')) ?? 0;
    final recs = <AiRecord>[];
    final lines = <String>[];
    for (final b in names) {
      final s = sales.where((x) => _branchOf(x) == b).toList();
      final a = appr.where((x) => _branchOf(x) == b).toList();
      final l = loss.where((x) => _branchOf(x) == b).fold<double>(0, (q, x) => q + n(x, 'loss'));
      final sw = s.fold<double>(0, (q, x) => q + _num(x, _sale.wtKeys));
      final sa = s.fold<double>(0, (q, x) => q + _num(x, _sale.amtKeys));
      final aw = a.fold<double>(0, (q, x) => q + _num(x, _appr.wtKeys));
      lines.add('🏢 $b: sales ${s.length} (${_g(sw)} g) · approval pending ${a.length} (${_g(aw)} g) · '
          '${l.abs() < 0.0005 ? 'no loss' : (l < 0 ? 'loss ${_g(-l)} g' : 'gain ${_g(l)} g')}');
      final lr = loss.where((x) => _branchOf(x) == b).toList();
      recs.add(_card(AiRecord(
        title: b,
        subtitle: 'Sales · approval · loss · ${p.label}',
        value: '${_g(sw)} g sold',
        badge: '₹${_a(sa)}',
        badgeGood: true,
        details: [
          AiStat('Sale bills', '${s.length}'),
          AiStat('Sold net', '${_g(sw)} g'),
          AiStat('Sale amount', '₹${_a(sa)}'),
          AiStat('Approval pending', '${a.length} · ${_g(aw)} g'),
          AiStat('Worker loss', l.abs() < 0.0005 ? 'No loss' : (l < 0 ? 'Loss ${_g(-l)} g' : 'Gain ${_g(l)} g')),
        ],
      ), () async => _branchFull(b, s, a, lr, p.label)));
    }
    return AiAnswer(
      text: '🏢 Branch summary · ${p.label}\n${lines.join('\n')}',
      speech: 'Branch summary for ${p.label}, ${names.length} branches.',
      stats: [
        AiStat('Branches', '${names.length}'),
        AiStat('Sale bills', '${sales.length}'),
        AiStat('Approval pending', '${appr.length}'),
      ],
      items: recs,
      itemsTitle: 'Branch wise',
      followUps: [
        'All branches sales ${p.follow}',
        'Branch wise approval pending',
        'All branches worker loss ${p.follow}',
        'Branch wise job work ${p.follow}',
      ],
    );
  }

  // =====================================================================
  //  🏢 TAP ON A BRANCH CARD → that branch only (no new API call)
  // =====================================================================
  static Future<AiAnswer> _branchList(_Topic tp, String branch, List<Map> rows, String when) async {
    final wt = rows.fold<double>(0, (a, r) => a + _num(r, tp.wtKeys));
    final amt = rows.fold<double>(0, (a, r) => a + _num(r, tp.amtKeys));
    final parties = rows.map(_party).where((e) => e.isNotEmpty).toSet();
    return AiAnswer(
      text: '🏢 $branch · ${tp.title} · $when\n${rows.length} entries · net ${_g(wt)} g'
          '${tp.amtKeys.isEmpty ? '' : ' · ₹${_a(amt)}'}${parties.isEmpty ? '' : ' · ${parties.length} customers'}',
      speech: '$branch, ${tp.title}, $when: ${rows.length} entries, ${_g(wt)} grams.',
      stats: [
        AiStat('Branch', branch),
        AiStat('Entries', '${rows.length}'),
        AiStat('Net wt', '${_g(wt)} g'),
        if (tp.amtKeys.isNotEmpty) AiStat('Amount', '₹${_a(amt)}'),
      ],
      items: rows.take(300).map((r) => _rowRecord(tp, r)).toList(),
      itemsTitle: '$branch · ${tp.title} (tap a voucher for items)',
      followUps: ['Branch summary', 'All branches ${tp.title.toLowerCase()}'],
    );
  }

  static double _n(Map r, String k) => double.tryParse('${r[k] ?? ''}'.replaceAll(',', '')) ?? 0;
  static String _lt(double v) => v.abs() < 0.0005 ? 'No loss' : (v < 0 ? 'Loss ${_g(-v)} g' : 'Gain ${_g(v)} g');

  /// worker-loss entry → tap opens the job work receive / issue voucher of that branch
  static AiRecord _lossRecord(Map r) {
    final rec = _lossRecord0(r);
    final stage = '${r['stage'] ?? ''}'.toLowerCase();
    final vid = r['voucher_id'] ?? r['jobwork_receive_id'] ?? r['jobwork_issue_id'] ?? r['id'];
    if (vid == null || !stage.contains('job')) return rec;
    final module = stage.contains('issue') ? 'branch_jobwork_issue' : 'branch_jobwork_receive';
    return VoucherDetails.attachVoucher(
        rec,
        VoucherRef(
          module: module,
          id: '$vid|${_slugOf(r)}',
          voucherNo: '${r['voucher_no'] ?? rec.title}',
          title: '${stage.contains('issue') ? 'Job Work Issue' : 'Job Work Receive'} · ${_branchOf(r)}',
          info: [for (final d in rec.details) MapEntry(d.label, d.value), MapEntry('Date', _d(_date(r, _loss.dateKeys)))],
        ));
  }

  static AiRecord _lossRecord0(Map r) {
    final l = _n(r, 'loss');
    return AiRecord(
      title: '${r['voucher_no'] ?? '-'}${'${r['buch_no'] ?? ''}'.trim().isNotEmpty && r['buch_no'] != '-' ? ' · ${r['buch_no']}' : ''}',
      subtitle: '${r['worker_name'] ?? '-'} · ${r['stage'] ?? ''} · ${_d(_date(r, _loss.dateKeys))}',
      value: '${_g(_n(r, 'source_wt'))} → ${_g(_n(r, 'receive_wt'))} g',
      badge: _lt(l),
      badgeGood: l >= 0,
      details: [
        AiStat('Branch', _branchOf(r)),
        AiStat('Worker', '${r['worker_name'] ?? '-'}'),
        AiStat('Stage', '${r['stage'] ?? '-'}'),
        AiStat('Issued', '${_g(_n(r, 'source_wt'))} g'),
        AiStat('Received', '${_g(_n(r, 'receive_wt'))} g'),
        AiStat('Bhuko', '${_g(_n(r, 'bhuko'))} g'),
        AiStat('Result', _lt(l)),
      ],
    );
  }

  static Future<AiAnswer> _lossList(String title, String branch, List<Map> rows, String when) async {
    final src = rows.fold<double>(0, (a, r) => a + _n(r, 'source_wt'));
    final l = rows.fold<double>(0, (a, r) => a + _n(r, 'loss'));
    return AiAnswer(
      text: '🏢 $branch · $title · $when\nIssued ${_g(src)} g · ${_lt(l)}'
          '${src > 0 ? ' (${(l.abs() / src * 100).toStringAsFixed(2)}%)' : ''} · ${rows.length} entries',
      speech: '$branch, $title, $when: ${_lt(l)}.',
      stats: [AiStat('Branch', branch), AiStat('Issued', '${_g(src)} g'), AiStat('Result', _lt(l)), AiStat('Entries', '${rows.length}')],
      items: rows.take(300).map(_lossRecord).toList(),
      itemsTitle: '$branch · $title entries',
      followUps: const ['Branch summary'],
    );
  }

  static Future<AiAnswer> _branchFull(String branch, List<Map> sales, List<Map> appr, List<Map> loss, String when) async {
    final sw = sales.fold<double>(0, (q, x) => q + _num(x, _sale.wtKeys));
    final sa = sales.fold<double>(0, (q, x) => q + _num(x, _sale.amtKeys));
    final aw = appr.fold<double>(0, (q, x) => q + _num(x, _appr.wtKeys));
    final l = loss.fold<double>(0, (q, x) => q + _n(x, 'loss'));
    return AiAnswer(
      text: '🏢 $branch · $when\n'
          '🧾 Sales: ${sales.length} bills · ${_g(sw)} g · ₹${_a(sa)}\n'
          '📋 Approval pending: ${appr.length} · ${_g(aw)} g\n'
          '⚖️ Worker loss: ${_lt(l)} (${loss.length} entries)',
      speech: '$branch, $when. ${sales.length} sale bills, ${appr.length} approvals pending, ${_lt(l)}.',
      stats: [
        AiStat('Sale bills', '${sales.length}'),
        AiStat('Sold', '${_g(sw)} g'),
        AiStat('Amount', '₹${_a(sa)}'),
        AiStat('Approval', '${appr.length}'),
        AiStat('Loss', _lt(l)),
      ],
      items: [
        ...sales.take(150).map((r) => _rowRecord(_sale, r)),
        ...appr.take(150).map((r) => _rowRecord(_appr, r)),
        ...loss.take(100).map(_lossRecord),
      ],
      itemsTitle: '$branch · sales, then approval, then loss',
      followUps: ['$branch branch sales', '$branch branch approval pending', 'Branch summary'],
    );
  }

  static String _slugOf(Map r) {
    final id = int.tryParse('${r['company_id'] ?? ''}');
    for (final c in branches) {
      if (c.id == id) return c.slug ?? c.id.toString();
    }
    return 'all';
  }

  /// 🔗 tap → branch voucher details (same as Branch Reports screen)
  static AiRecord _rowRecord(_Topic tp, Map r) {
    final rec = _rowRecord0(tp, r);
    final info = [for (final d in rec.details) MapEntry(d.label, d.value)];
    if (tp.name == _sale.name && r['id'] != null) {
      return VoucherDetails.attachVoucher(
          rec,
          VoucherRef(
              module: 'branch_sale', id: '${r['id']}|${_slugOf(r)}', voucherNo: rec.title, title: 'Sale Details · ${_branchOf(r)}', info: info));
    }
    if (tp.name == _appr.name && r['id'] != null) {
      return VoucherDetails.attachVoucher(
          rec,
          VoucherRef(
              module: 'branch_approval',
              id: '${r['id']}|${_slugOf(r)}',
              voucherNo: rec.title,
              title: 'Approval Details · ${_branchOf(r)}',
              info: info));
    }
    if (tp.name == _stock.name && r['item_id'] != null) {
      return VoucherDetails.attachVoucher(
          rec,
          VoucherRef(
              module: 'branch_stock',
              id: '${r['item_id']}|${r['stock_type'] ?? ''}|${_slugOf(r)}',
              voucherNo: rec.title,
              title: 'Stock Details · ${_branchOf(r)}',
              info: info));
    }
    return rec;
  }

  static AiRecord _rowRecord0(_Topic tp, Map r) {
    final no = _text(r, tp.noKeys);
    final w = _num(r, tp.wtKeys);
    final a = _num(r, tp.amtKeys);
    return AiRecord(
      title: no.isEmpty ? '-' : no,
      subtitle: '${_party(r).isEmpty ? '' : '${_party(r)} · '}${_d(_date(r, tp.dateKeys))} · ${_branchOf(r)}',
      value: '${_g(w)} g',
      badge: tp.amtKeys.isEmpty ? _branchOf(r) : '₹${_a(a)}',
      badgeGood: true,
      details: [
        AiStat('Branch', _branchOf(r)),
        if (_party(r).isNotEmpty) AiStat('Customer', _party(r)),
        AiStat('Date', _d(_date(r, tp.dateKeys))),
        for (final k in const ['stock_type_name', 'qty_pcs', 'total_qty', 'pending_pcs', 'total_gross_weight', 'gross_weight', 'total_net_weight',
          'net_weight', 'total_fine_weight', 'fine_weight', 'net_total', 'pending_amount', 'status'])
          if (r[k] != null && '${r[k]}'.trim().isNotEmpty && r[k] is! Map) AiStat(k.replaceAll('_', ' '), '${r[k]}'),
      ],
    );
  }

  // =====================================================================
  //  helpers
  // =====================================================================
  static String _party(Map r) {
    final c = r['customer'];
    if (c is Map && (c['name'] ?? '').toString().trim().isNotEmpty) return c['name'].toString().trim();
    final s = (r['customer_name'] ?? (c is String ? c : '') ?? '').toString().trim();
    return s == 'null' || s == '-' ? '' : s;
  }

  static String _text(Map r, List<String> keys) {
    for (final k in keys) {
      final v = r[k];
      if (v != null && v is! Map && '$v'.trim().isNotEmpty && '$v' != 'null') return '$v'.trim();
    }
    return '';
  }

  static double _num(Map r, List<String> keys) {
    for (final k in keys) {
      final v = r[k];
      if (v != null && v is! Map && '$v'.trim().isNotEmpty) return double.tryParse('$v'.replaceAll(',', '')) ?? 0;
    }
    return 0;
  }

  static DateTime? _date(Map r, List<String> keys) {
    for (final k in keys) {
      final s = '${r[k] ?? ''}'.trim();
      if (s.isEmpty || s == 'null') continue;
      final iso = DateTime.tryParse(s.length >= 10 ? s.substring(0, 10) : s);
      if (iso != null) return iso;
      final m = RegExp(r'(\d{1,2})[-/](\d{1,2})[-/](\d{4})').firstMatch(s);
      if (m != null) return DateTime(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
    }
    return null;
  }

  static final NumberFormat _amt = NumberFormat('#,##,##0', 'en_IN');
  static String _g(double v) => v.toStringAsFixed(3);
  static String _a(double v) => _amt.format(v);
  static String _d(DateTime? d) => d == null ? '-' : _dmy.format(d);

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

class _Topic {
  final String name, title, icon;
  final List<String> dateKeys, noKeys, wtKeys, amtKeys;
  const _Topic(this.name, this.title, this.icon, this.dateKeys, this.noKeys, this.wtKeys, this.amtKeys);
}

class _P {
  final DateTime? from, to;
  final String label, follow;
  final bool all;
  _P(this.from, this.to, this.label, this.follow, {this.all = false});

  bool has(DateTime? d) {
    if (all) return true;
    if (d == null) return true; // row without a date → keep
    final day = DateTime(d.year, d.month, d.day);
    return !day.isBefore(from!) && !day.isAfter(to!);
  }
}
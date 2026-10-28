import 'dart:async';
import 'dart:convert';

import '../../../Api_Constant/ApiConstants.dart';
import '../../../Api_Constant/api_helper.dart';
import '../../VoucherDetails.dart';
import '../core/ai_core.dart';

/// =======================================================================
///  🔎 BARCODE AI — "BR8 kya che?" / "TS3 nu status" / "BR8"
///
///  API: GET reports/barcode-history?code=BR8
///   → label kyare banyu / print thayu
///   → approval_history[]  (APP... · sold / returned / pending)
///   → sale_history[]      (PT-SL-003)
///   → return_history[]
///   → current_status
///
///  Darek voucher record par tap → VoucherDetails (Sale / Approval / Return
///  detail dialog, item table + PDF).
///  File: Ask AI/Barcode/BarcodeAi.dart
/// =======================================================================
class BarcodeAi {
  /// Aa shabdo hoy to barcode history j joie che
  static const List<String> _trigger = [
    'kya', 'kyaa', 'kyan', 'kyai', 'kai jagya', 'kya che', 'kyan che', 'status', 'history', 'itihas',
    'barcode', 'bar code', 'label', 'lebal', 'track', 'where', 'kahan', 'vechayo', 'vechayu', 'kone',
    'kona paase', 'kona pase', 'approval ma', 'sale ma', 'return', 'sthiti', 'halat',
  ];

  /// Voucher no (PT-SL-003, VV26-22, APP1789…) barcode nathi
  static final RegExp _voucherLike = RegExp(r'^(PT|VV|JI|AP|APP|SL|JR)\d*$');

  /// Bolela text mathi barcode code: "b r 8" / "br 8" / "BR-8" / "br8" → "BR8"
  /// [force] = true hoy to trigger word vagar pan (fakt code bolya hoy tyare)
  static String? detect(String raw, {bool force = false}) {
    var t = raw.toLowerCase().trim();
    // bolela number: "br eight" → "br 8"
    const nums = {
      'one': '1', 'two': '2', 'three': '3', 'four': '4', 'five': '5', 'six': '6', 'seven': '7',
      'eight': '8', 'nine': '9', 'ten': '10', 'eleven': '11', 'twelve': '12', 'zero': '0',
    };
    nums.forEach((k, v) => t = t.replaceAll(RegExp('\\b$k\\b'), v));
    // "b r 8" → "br 8" (chhuta letters jodo)
    t = t.replaceAllMapped(RegExp(r'\b(?:[a-z] ){1,4}[a-z]\b'), (m) => m[0]!.replaceAll(' ', ''));
    t = t.replaceAll(RegExp(r'[^a-z0-9\s-]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

    final m = RegExp(r'\b([a-z]{1,5})[\s-]?(\d{1,6})\b').firstMatch(t);
    if (m == null) return null;
    final code = '${m[1]}${m[2]}'.toUpperCase();
    if (_voucherLike.hasMatch(m[1]!.toUpperCase())) return null;
    // "10 gram", "top 5", "90 divas" jeva shabd barcode nathi
    const notCode = {'gram', 'gm', 'gms', 'g', 'top', 'din', 'divas', 'mahina', 'pehla', 'pela', 'last', 'pcs', 'nang', 'rs'};
    if (notCode.contains(m[1])) return null;

    final rest = t.replaceFirst(m[0]!, '').trim();
    final bool onlyCode = rest.isEmpty || rest == 'barcode' || rest == 'label';
    final bool asked = _trigger.any((w) => ' $t '.contains(' $w'));
    return (force || onlyCode || asked) ? code : null;
  }

  /// null = aa code no barcode nathi (pachhi bijo module javab aape)
  static Future<AiAnswer?> lookup(String code) async {
    try {
      final res = await ApiHelper().getRequest('${ApiConstants.Barcode_report}?code=$code');
      final body = res?.data;
      if (body is! Map || body['success'] == false) {
        return AiAnswer(
          text: 'Could not load the history for barcode $code right now. Please try again.',
          speech: 'Could not load the barcode history.',
        );
      }
      final list = (body['data'] as List? ?? const []).whereType<Map>().toList();
      if (list.isEmpty) return null;
      // Exact match pehla (BR8 shodho to BR80 nahi)
      final exact = list.where((e) => (e['label_code'] ?? e['barcode'] ?? '').toString().toUpperCase() == code);
      final d = Map<String, dynamic>.from(exact.isNotEmpty ? exact.first : list.first);
      final parties = await _loadParties(d);
      return _answer(d, parties);
    } catch (_) {
      return AiAnswer(
        text: 'Could not search barcode $code right now. Please check the internet and try again.',
        speech: 'Could not search the barcode right now.',
      );
    }
  }

  // =====================================================================
  //  ANSWER
  // =====================================================================
  // =====================================================================
  //  👤 CUSTOMER / WORKER — every voucher must show who it belongs to
  //   1) from the barcode-history row itself (customer_name, worker_name…)
  //   2) else from the voucher details API (same API as the tap dialog)
  // =====================================================================
  static const List<String> _workerKeys = [
    'worker_name', 'worker', 'karigar_name', 'karigar', 'artisan_name', 'artisan', 'employee_name',
  ];
  static const List<String> _customerKeys = [
    'customer_name', 'customer', 'party_name', 'party', 'account_name', 'account', 'ledger_name',
    'client_name', 'client', 'buyer_name', 'grahak', 'customer_full_name', 'name_of_customer',
  ];

  /// Jobwork = worker, everything else = customer (when the key doesn't say)
  static bool _isWorkerModule(String module) => module.startsWith('jobwork') || module.contains('worker');

  /// Find a name in a map (also inside "data", "voucher", "approval", "customer": {name})
  static _Party? _partyIn(dynamic m, String module, [int depth = 0]) {
    if (m is! Map || depth > 3) return null;
    String? txt(dynamic v) {
      if (v == null) return null;
      if (v is Map) {
        final n = v['name'] ?? v['full_name'] ?? v['customer_name'] ?? v['worker_name'] ?? v['account_name'];
        return txt(n);
      }
      final s = v.toString().trim();
      if (s.isEmpty || s == 'null' || s == '-' || RegExp(r'^\d+$').hasMatch(s)) return null;
      return s;
    }

    for (final k in _workerKeys) {
      final n = txt(m[k]);
      if (n != null) return _Party(n, true);
    }
    for (final k in _customerKeys) {
      final n = txt(m[k]);
      if (n != null) return _Party(n, _isWorkerModule(module));
    }
    for (final k in const ['data', 'voucher', 'approval', 'sale', 'return', 'details', 'header', 'master']) {
      final v = m[k];
      final r = v is List && v.isNotEmpty ? _partyIn(v.first, module, depth + 1) : _partyIn(v, module, depth + 1);
      if (r != null) return r;
    }
    return null;
  }

  static String _key(String module, String id, String voucherNo) => '$module|$id|$voucherNo';

  /// All vouchers of this barcode → customer / worker (API calls in parallel)
  static Future<Map<String, _Party>> _loadParties(Map<String, dynamic> d) async {
    final out = <String, _Party>{};
    final jobs = <Future<void>>[];

    void scan(List? h, String module) {
      for (final raw in (h ?? const []).whereType<Map>()) {
        final voucherNo = (raw['label'] ?? '').toString().split(' (').first.trim();
        final id = raw['id']?.toString() ?? '';
        final key = _key(module, id, voucherNo);
        final direct = _partyIn(raw, module);
        if (direct != null) {
          out[key] = direct;
          continue;
        }
        final cfg = VoucherDetails.configs[module];
        if (cfg == null || id.isEmpty) continue;
        jobs.add(() async {
          try {
            final res = await ApiHelper()
                .getRequest(cfg.detailsUrl(id), showLoading: false, receiveTimeout: const Duration(seconds: 8))
                .timeout(const Duration(seconds: 10));
            dynamic body = res?.data;
            if (body is String) body = jsonDecode(body);
            final p = _partyIn(body, module);
            if (p != null) out[key] = p;
          } catch (_) {}
        }());
      }
    }

    scan(d['approval_history'] as List?, 'approval');
    scan(d['sale_history'] as List?, 'sales');
    scan(d['return_history'] as List?, 'return');
    scan(d['jobwork_issue_history'] as List?, 'jobwork_issue');
    scan(d['jobwork_receive_history'] as List?, 'jobwork_receive');
    if (jobs.isNotEmpty) await Future.wait(jobs);
    return out;
  }

  static AiAnswer _answer(Map<String, dynamic> d, [Map<String, _Party> parties = const {}]) {
    final code = _clean(d['label_code'] ?? d['barcode']) ?? '-';
    final item = _clean(d['item_name']) ?? 'Item';
    final status = (d['current_status'] ?? '').toString().toLowerCase().trim();
    final huid = _clean(d['huid']);
    final created = _clean(d['label_created_at_fmt'] ?? d['label_created_at']);
    final printed = _clean(d['label_printed_at_fmt'] ?? d['label_printed_at']);

    final events = <_Event>[];

    // ---- label ----
    if (d['label_created_at'] != null) {
      events.add(_Event(
        date: _parse(d['label_created_at']),
        dateText: created ?? '',
        record: AiRecord(
          title: '🏷️ Label created',
          subtitle: '${created ?? '-'} · $item',
          value: code,
          badge: 'Label',
          badgeGood: true,
          details: [
            AiStat('Barcode', code),
            AiStat('Item', item),
            AiStat('Created on', created ?? '-'),
            if (huid != null) AiStat('HUID', huid),
          ],
        ),
      ));
    }
    if (d['label_printed_at'] != null) {
      events.add(_Event(
        date: _parse(d['label_printed_at']),
        dateText: printed ?? '',
        record: AiRecord(
          title: '🖨️ Label printed',
          subtitle: printed ?? '-',
          value: code,
          badge: 'Printed',
          badgeGood: true,
          details: [AiStat('Barcode', code), AiStat('Printed on', printed ?? '-')],
        ),
      ));
    }

    // ---- approval / sale / return / job work ----
    void addHistory(List? h, String module, String icon, String kind) {
      for (final raw in (h ?? const []).whereType<Map>()) {
        final label = (raw['label'] ?? '').toString(); // "APP1789194519 (12-09-2026) [sold]"
        final voucherNo = label.split(' (').first.trim();
        final dm = RegExp(r'\((\d{1,2}-\d{1,2}-\d{4})\)').firstMatch(label);
        final dateText = dm?[1] ?? '';
        final st = (raw['status'] ?? RegExp(r'\[(\w+)\]').firstMatch(label)?[1] ?? '').toString();
        final id = raw['id']?.toString() ?? '';
        // 👤 compulsory: Customer (sale / approval / return) or Worker (job work)
        final party = parties[_key(module, id, voucherNo)];
        final bool isWorker = party?.isWorker ?? _isWorkerModule(module);
        final String who = isWorker ? 'Worker' : 'Customer';
        final String name = party?.name ?? 'Not set';

        final rec = AiRecord(
          title: '$icon $kind · ${voucherNo.isEmpty ? '-' : voucherNo}',
          subtitle: '${dateText.isNotEmpty ? '$dateText · ' : ''}$who: $name',
          value: name, // top-right chip = customer / worker
          badge: st.isNotEmpty ? _statusText(st) : kind,
          badgeGood: !(st == 'sold' || module == 'sales'),
          details: [
            AiStat(who, name),
            AiStat('Voucher no.', voucherNo.isEmpty ? '-' : voucherNo),
            AiStat('Type', kind),
            if (dateText.isNotEmpty) AiStat('Date', dateText),
            if (st.isNotEmpty) AiStat('Status', _statusText(st)),
            AiStat('Barcode', code),
            AiStat('Item', item),
          ],
        );
        events.add(_Event(
          date: _ddmmyyyy(dateText),
          dateText: dateText,
          record: id.isEmpty
              ? rec
          // 🔗 tap → Sale / Approval / Return details dialog
              : VoucherDetails.attachVoucher(
            rec,
            VoucherRef(
              module: module,
              id: id,
              voucherNo: voucherNo,
              info: [
                MapEntry(who, name),
                MapEntry('Date', dateText),
                MapEntry('Barcode', code),
                if (st.isNotEmpty) MapEntry('Status', _statusText(st)),
              ],
            ),
          ),
        ));
      }
    }

    addHistory(d['approval_history'] as List?, 'approval', '📋', 'Approval');
    addHistory(d['sale_history'] as List?, 'sales', '🧾', 'Sale');
    addHistory(d['return_history'] as List?, 'return', '↩️', 'Return');
    addHistory(d['jobwork_issue_history'] as List?, 'jobwork_issue', '🛠️', 'Job work issue');
    addHistory(d['jobwork_receive_history'] as List?, 'jobwork_receive', '📥', 'Job work receive');

    // oldest first → timeline
    events.sort((a, b) => a.date.compareTo(b.date));

    final sales = (d['sale_history'] as List? ?? const []).whereType<Map>().toList();
    final apps = (d['approval_history'] as List? ?? const []).whereType<Map>().toList();
    final rets = (d['return_history'] as List? ?? const []).whereType<Map>().toList();
    final jobI = (d['jobwork_issue_history'] as List? ?? const []).whereType<Map>().toList();
    final jobR = (d['jobwork_receive_history'] as List? ?? const []).whereType<Map>().toList();
    String vno(Map m) => (m['label'] ?? '').toString().split(' (').first.trim();
    String dateOf(Map m) => RegExp(r'\((\d{1,2}-\d{1,2}-\d{4})\)').firstMatch('${m['label'] ?? ''}')?[1] ?? '';
    _Party? partyOf(Map m, String module) => parties[_key(module, m['id']?.toString() ?? '', vno(m))];
    String ref(Map m) {
      final dt = dateOf(m);
      return '${vno(m)}${dt.isEmpty ? '' : ', $dt'}';
    }

    // ---- where is it now (English, one clear line) ----
    String now; // for the text
    String nowSpoken; // short, for the voice
    switch (status) {
      case 'sold':
        final ps = sales.isEmpty ? null : partyOf(sales.last, 'sales');
        now = 'Sold${ps != null ? ' to ${ps.name}' : ''}${sales.isEmpty ? '' : ' (${ref(sales.last)})'}.';
        nowSpoken = 'sold${ps != null ? ' to ${ps.name}' : ''}';
        break;
      case 'approval':
      case 'on_approval':
      case 'in_approval':
      case 'pending':
        final pa = apps.isEmpty ? null : partyOf(apps.last, 'approval');
        now = 'On approval${pa != null ? ' with ${pa.name}' : ''}${apps.isEmpty ? '' : ' (${ref(apps.last)})'}.';
        nowSpoken = 'on approval${pa != null ? ' with ${pa.name}' : ''}';
        break;
      case 'returned':
      case 'return':
        now = 'Returned and back in stock${rets.isEmpty ? '' : ' (${ref(rets.last)})'}.';
        nowSpoken = 'returned and back in stock';
        break;
      case 'jobwork':
      case 'job_work':
      case 'in_jobwork':
        final pj = jobI.isEmpty ? null : partyOf(jobI.last, 'jobwork_issue');
        now = 'Out for job work${pj != null ? ' with ${pj.name}' : ''}${jobI.isEmpty ? '' : ' (${ref(jobI.last)})'}.';
        nowSpoken = 'out for job work${pj != null ? ' with ${pj.name}' : ''}';
        break;
      default:
        now = 'In stock at the shop.';
        nowSpoken = 'in stock at the shop';
    }

    // ---- journey summary ----
    String n(int c, String one) => '$c $one${c == 1 ? '' : 's'}';
    final journey = <String>[
      if (apps.isNotEmpty) n(apps.length, 'approval'),
      if (rets.isNotEmpty) n(rets.length, 'return'),
      if (jobI.isNotEmpty || jobR.isNotEmpty) n(jobI.length + jobR.length, 'job work entry'),
      if (sales.isNotEmpty) n(sales.length, 'sale'),
    ];
    final days = _daysSince(d['label_created_at']);

    final text = StringBuffer()
      ..writeln('$code · $item')
      ..writeln(now)
      ..write(journey.isEmpty
          ? 'No approval, sale or return yet.'
          : 'History: ${journey.join(' · ')}.');
    if (created != null) text.write(' Label created on $created${days != null ? ' ($days days ago)' : ''}.');
    if (events.length > 1 || journey.isNotEmpty) text.write('\nTap any voucher below to open full details.');

    final holder = _holder(status, sales, apps, parties);

    return AiAnswer(
      text: text.toString(),
      speech: '$code, $item, is $nowSpoken.',
      stats: [
        AiStat('Status', _statusText(status.isEmpty ? 'in_stock' : status)),
        if (holder != null) holder,
        AiStat('Item', item),
        AiStat('Barcode', code),
        if (huid != null) AiStat('HUID', huid),
        if (created != null) AiStat('Label created', created),
        if (days != null) AiStat('Age', '$days days'),
      ],
      items: events.map((e) => e.record).toList(),
      itemsTitle: 'Timeline · oldest first',
      followUps: [
        if (sales.isNotEmpty) '${vno(sales.last)} print',
        'Search another barcode',
      ],
    );
  }

  static String? _clean(dynamic v) {
    final s = (v ?? '').toString().trim();
    return (s.isEmpty || s == 'null' || s == '-') ? null : s;
  }

  static int? _daysSince(dynamic v) {
    final d = DateTime.tryParse(v?.toString() ?? '');
    if (d == null) return null;
    final n = DateTime.now().difference(d).inDays;
    return n < 0 ? null : n;
  }

  /// Who has it now (sold to / on approval with) → top stat chip
  static AiStat? _holder(String status, List<Map> sales, List<Map> apps, Map<String, _Party> parties) {
    Map? last;
    String module = '';
    if (status == 'sold' && sales.isNotEmpty) {
      last = sales.last;
      module = 'sales';
    } else if (const {'approval', 'on_approval', 'in_approval', 'pending'}.contains(status) && apps.isNotEmpty) {
      last = apps.last;
      module = 'approval';
    }
    if (last == null) return null;
    final vno = (last['label'] ?? '').toString().split(' (').first.trim();
    final p = parties[_key(module, last['id']?.toString() ?? '', vno)];
    final role = p?.isWorker == true ? 'Worker' : (module == 'sales' ? 'Sold to' : 'With customer');
    return AiStat(role, p?.name ?? 'Not set');
  }

  static String _statusText(String s) {
    switch (s.toLowerCase()) {
      case 'sold':
        return 'Sold';
      case 'approval':
      case 'on_approval':
      case 'in_approval':
      case 'pending':
        return 'On approval';
      case 'returned':
      case 'return':
        return 'Returned';
      case 'jobwork':
      case 'job_work':
      case 'in_jobwork':
        return 'Job work';
      case 'in_stock':
      case 'available':
      case 'stock':
        return 'In stock';
      default:
        return s.isEmpty ? '-' : '${s[0].toUpperCase()}${s.substring(1)}';
    }
  }

  static DateTime _parse(dynamic v) => DateTime.tryParse(v?.toString() ?? '') ?? DateTime(2000);

  static DateTime _ddmmyyyy(String s) {
    final m = RegExp(r'(\d{1,2})-(\d{1,2})-(\d{4})').firstMatch(s);
    if (m == null) return DateTime(2000);
    return DateTime(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!), 23, 59);
  }
}

class _Event {
  final DateTime date;
  final String dateText;
  final AiRecord record;
  _Event({required this.date, required this.dateText, required this.record});
}

class _Party {
  final String name;
  final bool isWorker;
  const _Party(this.name, this.isWorker);
}
import '../core/ai_core.dart';

/// Worker Loss Report API (`data[]`) ni ek entry
///
/// loss = receive + bhuko − source
///   −  (negative) = GHAT  — maal ochhu aavyu (sachu nuksan)
///   +  (positive) = VADHARO — aapya karta vadhu aavyu
class LossEntry {
  final String stage;
  final int? workerId;
  final String worker;
  final int? voucherId;
  final String voucherNo;
  final String buchNo;
  final double source;
  final double receive;
  final double bhuko;
  final double loss;
  final DateTime date;

  LossEntry({
    required this.stage,
    required this.workerId,
    required this.worker,
    this.voucherId,
    required this.voucherNo,
    required this.buchNo,
    required this.source,
    required this.receive,
    required this.bhuko,
    required this.loss,
    required this.date,
  });

  bool get isGhat => loss < 0;
  bool get isVadharo => loss > 0;

  /// Formula pramane loss (check mate)
  double get expectedLoss => receive + bhuko - source;

  /// Shanka vali entry: API loss formula sathe match nathi, athva weight vichitra che
  String? get issue {
    if (source == 0 && (receive > 0 || bhuko > 0)) return 'Source is 0 but there is receive / bhuko';
    if (source > 0 && receive > source * 1.5) return 'Receive is much more than source (${AiFmt.g(receive)} vs ${AiFmt.g(source)})';
    if ((loss - expectedLoss).abs() > 0.01) {
      return 'Loss is ${AiFmt.g(loss)} but by calculation it should be ${AiFmt.g(expectedLoss)}';
    }
    return null;
  }

  String get voucherKey => voucherNo.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  factory LossEntry.fromJson(Map<String, dynamic> j) {
    double d(String k) => double.tryParse(j[k]?.toString() ?? '') ?? 0;
    String s(String k) {
      final v = j[k]?.toString().trim();
      return (v == null || v.isEmpty) ? '-' : v;
    }

    final name = s('worker_name');
    return LossEntry(
      stage: s('stage'),
      workerId: int.tryParse(j['worker_id']?.toString() ?? ''),
      worker: (name == '-' || name.isEmpty) ? 'No Worker' : name,
      voucherId: int.tryParse(j['voucher_id']?.toString() ?? ''),
      voucherNo: s('voucher_no'),
      buchNo: s('buch_no'),
      source: d('source_wt'),
      receive: d('receive_wt'),
      bhuko: d('bhuko'),
      loss: d('loss'),
      date: DateTime.tryParse(s('process_datetime')) ?? ddmmyyyy(s('process_datetime_fmt')) ?? DateTime(2000),
    );
  }

  static DateTime? ddmmyyyy(String s) {
    final m = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})').firstMatch(s);
    if (m == null) return null;
    return DateTime(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
  }

  static String lossText(double l) {
    if (l.abs() < 0.0005) return '0 g';
    return l < 0 ? 'Loss ${AiFmt.g(-l)} g' : 'Gain ${AiFmt.g(l)} g';
  }

  AiRecord toRecord() => AiRecord(
    title: '$voucherNo${buchNo != '-' ? ' · $buchNo' : ''}',
    subtitle: '$worker · $stage · ${AiFmt.date(date)}',
    value: '${AiFmt.g(source)} → ${AiFmt.g(receive)} g',
    badge: lossText(loss),
    badgeGood: loss >= 0,
    details: [
      AiStat('Worker', worker),
      AiStat('Stage', stage),
      AiStat('Date', AiFmt.date(date)),
      AiStat('Voucher', voucherNo),
      if (buchNo != '-') AiStat('Buch', buchNo),
      AiStat('Source', '${AiFmt.g(source)} g'),
      AiStat('Receive', '${AiFmt.g(receive)} g'),
      AiStat('Bhuko', '${AiFmt.g(bhuko)} g'),
      AiStat('Loss', lossText(loss)),
      if (source > 0) AiStat('Loss %', '${AiFmt.g(-loss / source * 100)}%'),
      if (issue != null) AiStat('⚠️ Check', issue!),
    ],
  );
}

// =======================================================================
//  📒 WORKER METAL LEDGER
//  API: GET reports/worker-loss?mode=ledger&format=daily|detailed
//           &worker_id=&from_date=&to_date=
//  data.groups[] → rows[]
//
//  API sign j rakhyo che:  balance = debit − credit
//    + (Dr) = worker paase metal BAAKI
//    − (Cr) = worker ne VADHU malyu / aapyu
// =======================================================================

/// format value → label (WorkerMetalLedgerScreen jevu j)
const Map<String, String> ledgerFormats = {
  'daily': 'Daily',
  'detailed': 'Detailed Ledger',
};

class LedgerRow {
  final DateTime date;
  final String voucherNo;
  final String type; // Detailed ma Issue / Receive, Daily ma khali
  final String item; // item_name / particulars
  final double debit;
  final double credit;
  final double balance; // + Dr, − Cr

  LedgerRow({
    required this.date,
    required this.voucherNo,
    required this.type,
    required this.item,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  String get voucherKey => voucherNo.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  factory LedgerRow.fromJson(Map<String, dynamic> r) {
    final voucher = _s(r['voucher_no'] ?? r['reference']);
    final item = _s(r['item_name'] ?? r['item']);
    final particulars = _s(r['particulars']);
    return LedgerRow(
      date: _date(r['date']),
      voucherNo: voucher.isEmpty ? '-' : voucher,
      type: _s(r['type']),
      item: item.isNotEmpty ? item : (particulars.isEmpty ? '-' : particulars),
      debit: _d(r['debit']),
      credit: _d(r['credit']),
      balance: _d(r['balance']),
    );
  }
}

class LedgerGroup {
  final int? workerId;
  final String worker;
  final String metal;
  final double opening; // + Dr, − Cr
  final double debit;
  final double credit;
  final double closing; // + Dr, − Cr
  final List<LedgerRow> rows; // juni pehla (API kram)

  LedgerGroup({
    required this.workerId,
    required this.worker,
    required this.metal,
    required this.opening,
    required this.debit,
    required this.credit,
    required this.closing,
    required this.rows,
  });

  factory LedgerGroup.fromJson(Map<String, dynamic> g) {
    final rows = (g['rows'] is List ? g['rows'] as List : const [])
        .whereType<Map>()
        .map((r) => LedgerRow.fromJson(Map<String, dynamic>.from(r)))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final name = _s(g['worker_name']);
    final metal = _s(g['metal']);
    return LedgerGroup(
      workerId: int.tryParse(g['worker_id']?.toString() ?? ''),
      worker: name.isEmpty ? 'No Worker' : name,
      metal: metal.isEmpty ? 'Metal' : metal,
      opening: _d(g['opening']),
      debit: _d(g['debit']),
      credit: _d(g['credit']),
      closing: _d(g['closing']),
      rows: rows,
    );
  }

  /// API body → groups
  static List<LedgerGroup> listFrom(dynamic body) {
    if (body is! Map) return [];
    final data = body['data'];
    final groups = data is Map ? data['groups'] : (body['groups']);
    if (groups is! List) return [];
    return groups.whereType<Map>().map((g) => LedgerGroup.fromJson(Map<String, dynamic>.from(g))).toList();
  }
}

/// "12.5 g Dr" / "3 g Cr" / "0 g"
String ledgerBal(double v) {
  if (v.abs() < 0.0005) return '0 g';
  return '${AiFmt.g(v.abs())} g ${v > 0 ? 'Dr' : 'Cr'}';
}

/// Repository bharine rakhe, engine vanche (format → groups)
class LedgerStore {
  static final Map<String, List<LedgerGroup>> data = {};
  static final Map<String, String> errors = {};

  static List<LedgerGroup>? of(String format) => data[format];

  static void clear() {
    data.clear();
    errors.clear();
  }
}

double _d(dynamic v) => double.tryParse(v?.toString().replaceAll(',', '') ?? '') ?? 0;

String _s(dynamic v) {
  final t = v?.toString().trim() ?? '';
  return (t.isEmpty || t == 'null' || t == '-') ? '' : t;
}

DateTime _date(dynamic v) {
  final raw = _s(v);
  return DateTime.tryParse(raw) ?? LossEntry.ddmmyyyy(raw) ?? DateTime(2000);
}
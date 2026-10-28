import '../core/ai_core.dart';

/// One approval from the Approval Outstanding API (`data[]`) — goods still with the customer
class ApprovalEntry {
  final int id;
  final String approvalNo;
  final DateTime date;
  final String customer;
  final String status; // open / partial
  final String remarks;
  final String createdBy;
  final int pendingPcs;
  final double gross;
  final double other;
  final double net;
  final double purity;
  final double waste;
  final double fine;
  final double labourRate;
  final double labourAmount;
  final double otherAmount;
  final double amount;

  ApprovalEntry({
    required this.id,
    required this.approvalNo,
    required this.date,
    required this.customer,
    required this.status,
    required this.remarks,
    required this.createdBy,
    required this.pendingPcs,
    required this.gross,
    required this.other,
    required this.net,
    required this.purity,
    required this.waste,
    required this.fine,
    required this.labourRate,
    required this.labourAmount,
    required this.otherAmount,
    required this.amount,
  });

  bool get isOpen => status == 'open';
  bool get isPartial => status == 'partial';

  /// Status open che pan ek pan piece baki nathi — bandh karvo joie
  bool get isEmpty => pendingPcs == 0 || net == 0;

  /// Ketla divas thi customer pase che
  int get ageDays {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day).difference(DateTime(date.year, date.month, date.day)).inDays;
  }

  /// Follow-up priority: vadhu maal + vadhu juno = vadhu jokham
  double get risk => net * (ageDays + 1);

  String get key => approvalNo.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  String get digits => approvalNo.replaceAll(RegExp(r'[^0-9]'), '');

  String get statusLabel => isOpen
      ? 'Open'
      : isPartial
      ? 'Partial'
      : (status.isEmpty || status == '-' ? '-' : '${status[0].toUpperCase()}${status.substring(1)}');

  factory ApprovalEntry.fromJson(Map<String, dynamic> j) {
    double d(List<String> keys) {
      for (final k in keys) {
        final v = double.tryParse(j[k]?.toString() ?? '');
        if (v != null) return v;
      }
      return 0;
    }

    String s(List<String> keys) {
      for (final k in keys) {
        final v = j[k]?.toString().trim();
        if (v != null && v.isNotEmpty && v != '-') return v;
      }
      return '-';
    }

    return ApprovalEntry(
      id: int.tryParse(j['id']?.toString() ?? '') ?? 0,
      approvalNo: s(['approval_no', 'voucher_no']),
      date: _parseDate(s(['approval_date', 'date', 'approval_date_fmt'])) ?? DateTime(2000),
      customer: s(['customer_name', 'customer']),
      status: s(['status']).toLowerCase(),
      remarks: s(['remarks']),
      createdBy: s(['created_by']),
      // pending_* = haju customer pase che te
      pendingPcs: d(['pending_items', 'pending_pcs', 'qty_pcs']).round(),
      gross: d(['pending_gross_weight', 'gross_weight']),
      other: d(['pending_other_weight', 'other_weight']),
      net: d(['pending_net_weight', 'net_weight']),
      purity: d(['pending_purity', 'purity']),
      waste: d(['pending_waste_percent', 'waste_percent']),
      fine: d(['fine_weight', 'pending_fine_weight']),
      labourRate: d(['pending_labour_rate', 'labour_rate']),
      labourAmount: d(['labour_amount', 'pending_labour_amount']),
      otherAmount: d(['pending_other_amount', 'other_amount']),
      amount: d(['pending_total_amount', 'pending_amount', 'net_total']),
    );
  }

  static DateTime? _parseDate(String s) {
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    final m = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})').firstMatch(s);
    if (m == null) return null;
    return DateTime(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
  }

  AiRecord toRecord() => AiRecord(
    title: approvalNo,
    subtitle: '$customer · ${AiFmt.date(date)} · $ageDays days',
    value: '${AiFmt.g(net)} g · $pendingPcs pcs',
    badge: statusLabel,
    badgeGood: !(ageDays > 30 || isEmpty),
    details: [
      AiStat('Customer', customer),
      AiStat('Date', AiFmt.date(date)),
      AiStat('Age', '$ageDays days'),
      AiStat('Status', statusLabel),
      AiStat('Pending pcs', '$pendingPcs'),
      AiStat('Gross', '${AiFmt.g(gross)} g'),
      if (other > 0) AiStat('Other', '${AiFmt.g(other)} g'),
      AiStat('Net', '${AiFmt.g(net)} g'),
      if (purity > 0) AiStat('Purity', '${AiFmt.g(purity)}%'),
      if (fine > 0) AiStat('Fine', '${AiFmt.g(fine)} g'),
      if (labourRate > 0) AiStat('Labour rate', '₹${AiFmt.g(labourRate)}'),
      if (amount > 0) AiStat('Amount', AiFmt.inr(amount, decimals: 2)),
      AiStat('Created by', createdBy),
      if (remarks != '-') AiStat('Remarks', remarks),
    ],
  );
}

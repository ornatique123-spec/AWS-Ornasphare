import '../core/ai_core.dart';

/// One bill / voucher from the Sales Summary API (`data[]`)
class SaleVoucher {
  final int id;
  final String voucherNo;
  final DateTime date;
  final String customer;
  final String createdBy;
  final String remarks;
  final int qty;
  final double gross;
  final double other;
  final double net;
  final double purity;
  final double waste;
  final double fine;
  final double metalRate;
  final double metalAmount;
  final double labourRate;
  final double labourAmount;
  final double otherAmount;
  final double netTotal;

  SaleVoucher({
    required this.id,
    required this.voucherNo,
    required this.date,
    required this.customer,
    required this.createdBy,
    required this.remarks,
    required this.qty,
    required this.gross,
    required this.other,
    required this.net,
    required this.purity,
    required this.waste,
    required this.fine,
    required this.metalRate,
    required this.metalAmount,
    required this.labourRate,
    required this.labourAmount,
    required this.otherAmount,
    required this.netTotal,
  });

  /// Weight che pan amount 0 — rate / labour baki hoy evo bill
  bool get isUnpriced => netTotal == 0 && net > 0;

  String get voucherKey => voucherNo.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  factory SaleVoucher.fromJson(Map<String, dynamic> j) {
    double d(String k) => double.tryParse(j[k]?.toString() ?? '') ?? 0;
    String s(List<String> keys) {
      for (final k in keys) {
        final v = j[k]?.toString().trim();
        if (v != null && v.isNotEmpty && v != '-') return v;
      }
      return '-';
    }

    return SaleVoucher(
      id: int.tryParse(j['id']?.toString() ?? '') ?? 0,
      voucherNo: s(['voucher_no', 'bill_no']),
      date: _parseDate(s(['sale_date', 'date', 'sale_date_fmt'])) ?? DateTime(2000),
      customer: s(['customer_name', 'customer', 'party_name']),
      createdBy: s(['created_by', 'user']),
      remarks: s(['remarks']),
      qty: (double.tryParse(j['qty_pcs']?.toString() ?? '') ?? 0).round(),
      gross: d('gross_weight'),
      other: d('other_weight'),
      net: d('net_weight'),
      purity: d('purity'),
      waste: d('waste_percent'),
      fine: d('fine_weight'),
      metalRate: d('metal_rate'),
      metalAmount: d('metal_amount'),
      labourRate: d('labour_rate'),
      labourAmount: d('labour_amount'),
      otherAmount: d('other_amount'),
      netTotal: d('net_total'),
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
    title: voucherNo,
    subtitle: '$customer · ${AiFmt.date(date)}',
    value: '${AiFmt.g(net)} g',
    badge: AiFmt.inr(netTotal),
    badgeGood: netTotal > 0,
    details: [
      AiStat('Customer', customer),
      AiStat('Date', AiFmt.date(date)),
      AiStat('Qty', '$qty pcs'),
      AiStat('Gross', '${AiFmt.g(gross)} g'),
      if (other > 0) AiStat('Other', '${AiFmt.g(other)} g'),
      AiStat('Net', '${AiFmt.g(net)} g'),
      AiStat('Purity', '${AiFmt.g(purity)}%'),
      if (waste > 0) AiStat('Waste', '${AiFmt.g(waste)}%'),
      AiStat('Fine', '${AiFmt.g(fine)} g'),
      if (metalAmount > 0) AiStat('Metal', AiFmt.inr(metalAmount)),
      if (labourAmount > 0) AiStat('Labour', AiFmt.inr(labourAmount)),
      if (otherAmount > 0) AiStat('Other ₹', AiFmt.inr(otherAmount)),
      AiStat('Total', AiFmt.inr(netTotal, decimals: 2)),
      AiStat('Created by', createdBy),
      if (remarks != '-') AiStat('Remarks', remarks),
    ],
  );
}
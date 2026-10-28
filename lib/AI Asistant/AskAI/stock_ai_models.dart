/// =======================================================================
///  STOCK AI — MODELS
///  Stock Gallery API (`/api/stock-gallery`) na response mathi banave che.
///  Date fields (created_at / sold_at) API ma aave to aging + period-wise
///  selling automatic exact thai jase. Na aave to ID order par chale che.
/// =======================================================================

import 'core/ai_core.dart';

export 'core/ai_core.dart';

class StockItem {
  final int id;
  final String itemName;
  final String labelCode;
  final String huid;
  final double grossWeight;
  final double otherWeight;
  final double netWeight;
  final bool hasOtherWeight;
  final bool isSold;
  final String? imageUrl;
  final String? imageDownloadUrl;

  /// Stock ma kyare aavyo (label banyu). API ma hoy to j male.
  final DateTime? addedOn;

  /// Kyare vechayo. API ma hoy to j male.
  final DateTime? soldOn;

  StockItem({
    required this.id,
    required this.itemName,
    required this.labelCode,
    required this.huid,
    required this.grossWeight,
    required this.otherWeight,
    required this.netWeight,
    required this.hasOtherWeight,
    required this.isSold,
    this.imageUrl,
    this.imageDownloadUrl,
    this.addedOn,
    this.soldOn,
  });

  bool get inStock => !isSold;
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  /// Stock ma ketla divas thi che (sold hoy to sold thaya sudhi).
  int? get ageDays {
    if (addedOn == null) return null;
    final end = (isSold && soldOn != null) ? soldOn! : DateTime.now();
    return end.difference(addedOn!).inDays;
  }

  /// Vechata ketla divas lagya.
  int? get daysToSell {
    if (addedOn == null || soldOn == null) return null;
    return soldOn!.difference(addedOn!).inDays;
  }

  /// Common list record (Ask AI screen mate)
  AiRecord toRecord() => AiRecord(
    title: labelCode,
    subtitle: '$itemName${ageDays != null ? ' · $ageDays days' : ''}',
    value: '${AiFmt.g(netWeight)} g',
    badge: isSold ? 'Sold' : 'In stock',
    badgeGood: !isSold,
    imageUrl: hasImage ? imageUrl : null,
    showThumb: true,
    details: [
      AiStat('Item', itemName),
      AiStat('Gross', '${AiFmt.g(grossWeight)} g'),
      AiStat('Other', '${AiFmt.g(otherWeight)} g'),
      AiStat('Net', '${AiFmt.g(netWeight)} g'),
      if (huid != '-') AiStat('HUID', huid),
      if (ageDays != null) AiStat('Age', '$ageDays days'),
    ],
  );

  factory StockItem.fromJson(Map<String, dynamic> j) {
    final status = (j['stock_status'] ?? '').toString().toLowerCase();
    final soldRaw = j['is_sold'];
    final sold = soldRaw == 1 ||
        soldRaw == true ||
        soldRaw?.toString() == '1' ||
        status.contains('out');

    return StockItem(
      id: _int(j['id']),
      itemName: (j['item_name'] ?? '-').toString().trim(),
      labelCode: (j['label_code'] ?? j['qr_code'] ?? '-').toString().trim(),
      huid: (j['huid'] ?? '-').toString(),
      grossWeight: _dbl(j['gross_weight']),
      otherWeight: _dbl(j['other_weight']),
      netWeight: _dbl(j['net_weight']),
      hasOtherWeight: j['has_other_weight'] == true || _dbl(j['other_weight']) > 0,
      isSold: sold,
      imageUrl: (j['image_url'] == null || j['image_url'].toString().isEmpty)
          ? null
          : j['image_url'].toString(),
      imageDownloadUrl: j['image_download_url']?.toString(),
      addedOn: _date(j, const [
        'created_at',
        'label_date',
        'stock_date',
        'purchase_date',
        'inward_date',
        'date',
      ]),
      soldOn: _date(j, const ['sold_at', 'sold_date', 'sale_date', 'invoice_date']),
    );
  }

  static int _int(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

  static double _dbl(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  static DateTime? _date(Map<String, dynamic> j, List<String> keys) {
    for (final k in keys) {
      final v = j[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isEmpty || s == '-') continue;
      final d = DateTime.tryParse(s) ?? _ddmmyyyy(s);
      if (d != null) return d;
    }
    return null;
  }

  /// "12-10-2026" / "12/10/2026" format support
  static DateTime? _ddmmyyyy(String s) {
    final m = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})').firstMatch(s);
    if (m == null) return null;
    return DateTime(int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!));
  }
}


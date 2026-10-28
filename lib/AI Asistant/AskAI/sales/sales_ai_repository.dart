import '../../../Api_Constant/ApiConstants.dart';
import '../../../Api_Constant/api_helper.dart';
import 'sales_ai_models.dart';

/// =======================================================================
///  SALES REPOSITORY
///  Chhela 2 varsh nu sales summary ek var laave, 5 minute cache.
///  Pachhi badhu (aaje / mahina / customer / compare) phone ma j gani le.
/// =======================================================================
class SalesAiRepository {
  static List<SaleVoucher>? _cache;
  static DateTime? _cachedAt;
  static DateTime? loadedFrom;

  static const int historyDays = 730;

  static Future<List<SaleVoucher>> loadAll({bool force = false}) async {
    if (!force &&
        _cache != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < const Duration(minutes: 5)) {
      return _cache!;
    }

    final to = DateTime.now();
    final from = to.subtract(const Duration(days: historyDays));

    // 👉 ADJUST: Salesumryreport screen ma je constant / GET method / date
    //    parameter na naam vapro cho te j muko (from_date / to_date ke start_date...).
    final response = await ApiHelper().getRequest(
      "${ApiConstants.Sale_Summary_report}?from_date=${_ymd(from)}&to_date=${_ymd(to)}",
      showLoading: false, // 🔕 no loader popup (Ask AI shows its own loading card)
      receiveTimeout: const Duration(seconds: 60),
    );

    final body = response?.data;
    if (body is! Map || body['success'] == false) {
      throw Exception(body is Map ? (body['message'] ?? 'Could not load sales') : 'Could not load sales');
    }

    final list = (body['data'] as List? ?? [])
        .whereType<Map>()
        .map((e) => SaleVoucher.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    _cache = list;
    _cachedAt = DateTime.now();
    loadedFrom = list.isEmpty ? from : list.map((e) => e.date).reduce((a, b) => a.isBefore(b) ? a : b);
    return list;
  }

  static void clearCache() {
    _cache = null;
    _cachedAt = null;
  }

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
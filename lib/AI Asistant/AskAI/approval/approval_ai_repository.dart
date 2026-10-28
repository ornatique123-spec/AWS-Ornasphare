import '../../../Api_Constant/ApiConstants.dart';
import '../../../Api_Constant/api_helper.dart';
import 'approval_ai_models.dart';

/// =======================================================================
///  APPROVAL REPOSITORY — Approval Outstanding (haju customer pase je maal che)
/// =======================================================================
class ApprovalAiRepository {
  static List<ApprovalEntry>? _cache;
  static DateTime? _cachedAt;

  static Future<List<ApprovalEntry>> loadAll({bool force = false}) async {
    if (!force &&
        _cache != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < const Duration(minutes: 5)) {
      return _cache!;
    }

    // 👉 ADJUST: Approvaloutstandingreport screen ma je constant / GET method che te j muko.
    //    Date filter hoy to badhu aave evi range aapo (outstanding = aaj sudhi nu badhu baki).
    final response = await ApiHelper().getRequest(ApiConstants.Approval_Outstanding_report);

    final body = response?.data;
    if (body is! Map || body['success'] == false) {
      throw Exception(body is Map ? (body['message'] ?? 'Could not load approvals') : 'Could not load approvals');
    }

    final list = (body['data'] as List? ?? [])
        .whereType<Map>()
        .map((e) => ApprovalEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    _cache = list;
    _cachedAt = DateTime.now();
    return list;
  }

  static void clearCache() {
    _cache = null;
    _cachedAt = null;
  }
}

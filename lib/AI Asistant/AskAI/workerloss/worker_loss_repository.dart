import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../Api_Constant/ApiConstants.dart';
import '../../../Api_Constant/api_helper.dart';
import 'worker_loss_models.dart';

/// =======================================================================
///  WORKER LOSS REPOSITORY — badhi entry ek var (filter vagar), 5 min cache
///
///  Sathe Metal Ledger pan laave che (banne format):
///    reports/worker-loss?mode=ledger&format=daily
///    reports/worker-loss?mode=ledger&format=detailed
///  → LedgerStore ma rakhe che, AI engine tya thi vanche.
///  Ledger fail thay to pan Loss vadu chalu rahe.
/// =======================================================================
class WorkerLossRepository {
  static List<LossEntry>? _cache;
  static DateTime? _cachedAt;

  /// Ledger ketla juna thi lavvu (opening 0 thi sharu thay)
  static const String ledgerFrom = '2020-01-01';

  static Future<List<LossEntry>> loadAll({bool force = false}) async {
    if (!force &&
        _cache != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < const Duration(minutes: 5)) {
      return _cache!;
    }

    // Loss + banne ledger ek sathe (parallel)
    final results = await Future.wait([
      _loadLoss(),
      for (final f in ledgerFormats.keys) _loadLedger(f),
    ]);

    final list = results.first as List<LossEntry>;
    _cache = list;
    _cachedAt = DateTime.now();
    return list;
  }

  static Future<List<LossEntry>> _loadLoss() async {
    // 👉 ADJUST: WorkerLossReportScreen ma je constant / GET method che te j muko.
    //    Filter (from_date, worker_id, stage...) vagar — AI pote filter kare che.
    final response = await ApiHelper().getRequest(
      ApiConstants.worker_loss_report,
      showLoading: false, // 🔕 no loader popup
      receiveTimeout: const Duration(seconds: 60),
    );

    final body = response?.data;
    if (body is! Map || body['success'] == false) {
      throw Exception(body is Map ? (body['message'] ?? 'Could not load worker loss') : 'Could not load worker loss');
    }

    return (body['data'] as List? ?? [])
        .whereType<Map>()
        .map((e) => LossEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Badha worker nu ledger (worker_id vagar) — AI pote worker / date filter kare che
  static Future<void> _loadLedger(String format) async {
    try {
      final to = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final url = '${ApiConstants.worker_loss_report}'
          '?mode=ledger&format=$format&from_date=$ledgerFrom&to_date=$to';
      debugPrint('📒 LEDGER ($format) => $url');

      final response = await ApiHelper().getRequest(
        url,
        showLoading: false, // 🔕 no loader popup
        receiveTimeout: const Duration(seconds: 60),
      );
      final body = response?.data;
      if (body is! Map || body['success'] == false) {
        LedgerStore.errors[format] =
        body is Map ? (body['message']?.toString() ?? 'Could not load ledger') : 'Could not load ledger';
        LedgerStore.data.remove(format);
        return;
      }
      LedgerStore.data[format] = LedgerGroup.listFrom(body);
      LedgerStore.errors.remove(format);
      debugPrint('📒 LEDGER ($format) groups=${LedgerStore.data[format]!.length}');
    } catch (e) {
      LedgerStore.errors[format] = e.toString();
      LedgerStore.data.remove(format);
      debugPrint('❌ LEDGER ($format) ERROR => $e');
    }
  }

  static void clearCache() {
    _cache = null;
    _cachedAt = null;
    LedgerStore.clear();
  }
}
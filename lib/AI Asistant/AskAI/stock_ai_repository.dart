import '../../Api_Constant/ApiConstants.dart';
import '../../Api_Constant/api_helper.dart';
import 'stock_ai_models.dart';

/// =======================================================================
///  STOCK AI REPOSITORY
///  Stock Gallery API na BADHA page ek sathe laave che ane 10 minute
///  cache rakhe che.
///
///  🔕 NO loader popup: every page call uses `showLoading: false`
///     (Ask AI screen shows its own "Getting your data ready…" card).
///  ⚡ Faster: asks 200 items per page (if backend allows `per_page`)
///     and loads 6 pages at the same time.
///  🔁 If 2 places ask together, they share ONE download.
/// =======================================================================
class StockAiRepository {
  static List<StockItem>? _cache;
  static DateTime? _cachedAt;
  static Future<List<StockItem>>? _inflight;

  /// Parallel ma ketla page ek sathe mangavva
  static const int _parallel = 6;

  /// Ek page ma ketla item mangavva (backend ignore kare to pan chale)
  static const int _perPage = 200;

  static Future<List<StockItem>> loadAll({
    bool force = false,
    void Function(int done, int total)? onProgress,
  }) {
    if (!force &&
        _cache != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < const Duration(minutes: 10)) {
      return Future.value(_cache!);
    }
    // already downloading → same download share karo (2 var API nahi)
    if (_inflight != null) return _inflight!;
    _inflight = _load(onProgress).whenComplete(() => _inflight = null);
    return _inflight!;
  }

  static Future<List<StockItem>> _load(void Function(int done, int total)? onProgress) async {
    final first = await _fetchPage(1);
    final items = <StockItem>[...first.items];
    final lastPage = first.lastPage;
    onProgress?.call(1, lastPage);

    var done = 1;
    for (var p = 2; p <= lastPage; p += _parallel) {
      final batch = [
        for (var i = p; i < p + _parallel && i <= lastPage; i++) _fetchPage(i),
      ];
      final results = await Future.wait(batch);
      for (final r in results) {
        items.addAll(r.items);
      }
      done += batch.length;
      onProgress?.call(done, lastPage);
    }

    // duplicate ID hata vo (page vacche data badlay to)
    final seen = <int>{};
    final unique = items.where((e) => seen.add(e.id)).toList();

    _cache = unique;
    _cachedAt = DateTime.now();
    return unique;
  }

  static void clearCache() {
    _cache = null;
    _cachedAt = null;
  }

  static Future<_Page> _fetchPage(int page) async {
    final response = await ApiHelper().getRequest(
      "${ApiConstants.stock_gallery}?page=$page&per_page=$_perPage",
      showLoading: false, // 🔕 loader popup band
      receiveTimeout: const Duration(seconds: 60),
    );

    final body = response?.data;
    if (body is! Map || body['success'] == false) {
      throw Exception(body is Map ? (body['message'] ?? 'Stock load failed') : 'Stock load failed');
    }

    final list = (body['data'] as List? ?? [])
        .whereType<Map>()
        .map((e) => StockItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final pg = body['pagination'] as Map?;
    final lastPage = int.tryParse(pg?['last_page']?.toString() ?? '') ?? 1;

    return _Page(list, lastPage);
  }
}

class _Page {
  final List<StockItem> items;
  final int lastPage;
  _Page(this.items, this.lastPage);
}
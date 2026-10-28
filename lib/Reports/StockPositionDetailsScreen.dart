import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import '../Extra/AppColors.dart';
import '../Extra/AppMessage.dart';
import 'package:pecifician_sysytem/Settings/BranchManagementScreen.dart'
    show BranchApi, Company, BranchTypeX;
import 'BranchAccess.dart';

/// ================================================================
/// 📦 STOCK POSITION DETAILS (item par click kare tyare)
///
/// Normal : GET reports/stock-position/details?item_id=4&stock_type=all
/// PDF    : GET reports/stock-position/details/pdf?item_id=4&stock_type=all
/// Excel  : GET reports/stock-position/details/excel?item_id=4&stock_type=all
/// Branch : GET reports/stock-position/details?item_id=4&stock_type=all
///          &report_branches=branch-one-slug,branch-two-slug
///          (PDF / Excel ma pan e j report_branches jay)
///
/// Upar Branch Reports tab (fakt main company admin). Main screen ma
/// branch merge hoy to e j branches select thai ne page khule.
/// ================================================================

class StockPositionDetailsScreen extends StatefulWidget {
  final String itemId;
  final String itemName;
  final String stockType;

  /// Branch merge report hoy to select kareli branches na slug
  final List<String> branchSlugs;

  /// Branch report base (company/branch-reports/stock-position)
  final String? branchReportUrl;

  /// company_id → branch naam (Branch column mate)
  final Map<int, String> branchNames;

  const StockPositionDetailsScreen({
    super.key,
    required this.itemId,
    required this.itemName,
    required this.stockType,
    this.branchSlugs = const [],
    this.branchReportUrl,
    this.branchNames = const {},
  });

  @override
  State<StockPositionDetailsScreen> createState() =>
      _StockPositionDetailsScreenState();
}

class _StockPositionDetailsScreenState
    extends State<StockPositionDetailsScreen> {
  static const Color _ink = Color(0xff172033);
  static const Color _muted = Color(0xff7A8194);
  static const Color _line = Color(0xffE3E7F0);
  static const Color _bg = Color(0xffF5F7FB);
  static const Color _green = Color(0xff16A34A);
  static const Color _orange = Color(0xffE08A00);

  static const int _perPage = 25;

  /// "" = All items, "with" = With image, "without" = Without image
  static const Map<String, String> _imageFilters = {
    "": "All items",
    "with_image": "With image",
    "without_image": "Without image",
  };

  String _imageStatus = "";

  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  String? _error;

  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic>? _serverTotals;
  int? _withImage;
  int? _withoutImage;
  int? _total;
  int? _cachedWith;
  int? _cachedWithout;

  String? _exporting;

  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _hScroll = ScrollController();

  final NumberFormat _wt = NumberFormat("#,##0.000");

  // ============================================================
  // 🔥 BRANCH (main screen mathi aavela slug — khali = normal)
  // ============================================================

  List<Company> branchCompanies = [];
  Set<int> selectedCompanyIds = {};

  /// "View Report" pachhi apply thayela slug (khali = normal report)
  List<String> _appliedSlugs = [];

  bool branchesLoading = false;
  bool canViewBranches = false;
  bool branchExpanded = true;
  bool branchReportLoading = false;

  bool get _branchMode => _appliedSlugs.isNotEmpty;

  /// "stock-position" — Stock_Position_report mathi report nu naam
  String get _reportName {
    final String path = Uri.parse(ApiConstants.Stock_Position_report).path;
    const String marker = "/reports/";
    final int i = path.indexOf(marker);
    return i >= 0
        ? path.substring(i + marker.length)
        : path.split("/").where((e) => e.isNotEmpty).last;
  }

  @override
  void initState() {
    super.initState();
    // Main screen ma branch merge hoy to e j branches thi sharu
    _appliedSlugs = List<String>.from(widget.branchSlugs);
    _fetch();
    _loadBranches();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  // ============================================================
  // URL
  // ============================================================

  /// reports/stock-position/details  (export hoy to /details/pdf, /details/excel)
  /// Branch merge hoy to pan e j URL — fakt &report_branches=a,b umerAy
  ///
  /// 🔥 Branch merge hoy tyare biji report jevu j:
  ///   company/branch-reports/stock-position/details
  ///     ?item_id=4&stock_type=all&report_branches=a,b&per_page=25
  ///   PDF / Excel → e j URL + &export=pdf / &export=excel
  String get _branchBase {
    final String? fromMain = widget.branchReportUrl;
    if (fromMain != null && fromMain.isNotEmpty) return fromMain;
    return "${ApiConstants.baseUrl}company/branch-reports/$_reportName";
  }

  String _baseUrl([String? export]) {
    if (_branchMode) return "$_branchBase/details";
    final String root = ApiConstants.Stock_Position_report;
    return export == null ? "$root/details" : "$root/details/$export";
  }

  String _buildUrl({int page = 1, String? export}) {
    final List<String> q = [
      "item_id=${Uri.encodeQueryComponent(widget.itemId)}",
      "stock_type=$_stockTypeParam",
      if (_branchMode) ...[
        // Comma encode na thay (%2C) etle hathe
        "report_branches=${_appliedSlugs.map(Uri.encodeQueryComponent).join(",")}",
        // Branch ma item id alag hoy shake → naam pan mokliye
        if (widget.itemName.trim().isNotEmpty)
          "item_name=${Uri.encodeQueryComponent(widget.itemName.trim())}",
      ],
      if (_imageStatus.isNotEmpty) "image_status=$_imageStatus",
      if (export == null) ...[
        "per_page=$_perPage",
        if (page > 1) "page=$page",
        if (page > 1 && _branchMode) "start=${(page - 1) * _perPage}",
      ] else if (_branchMode)
        "export=$export",
    ];
    return "${_baseUrl(export)}?${q.join("&")}";
  }

  /// Image filter mate badha pages lai aave (client side filter sacho rahe)
  Future<void> _ensureAllPages() async {
    int guard = 0;
    while (_hasMore && mounted && guard < 200) {
      guard++;
      final int before = _rows.length;
      await _fetch(loadMore: true);
      if (_rows.length == before) break;
    }
  }

  /// Image filter badlo → API + list update
  Future<void> _setImageStatus(String status) async {
    if (status == _imageStatus) return;
    setState(() => _imageStatus = status);
    await _fetch();
    if (_imageStatus.isNotEmpty) await _ensureAllPages();
  }

  /// API ma stock_type=all jay chhe (backend pramane)
  String get _stockTypeParam => "all";

  // ============================================================
  // API
  // ============================================================

  Future<void> _fetch({bool loadMore = false}) async {
    final int page = loadMore ? _page + 1 : 1;
    final String url = _buildUrl(page: page);
    debugPrint("🔥 STOCK POSITION DETAILS API: $url");

    setState(() {
      if (loadMore) {
        _loadingMore = true;
      } else {
        _loading = true;
        _error = null;
      }
    });

    try {
      final response =
      await ApiHelper().getRequest(url, showLoading: !loadMore);
      final dynamic body = response?.data;
      if (!mounted) return;

      debugPrint("🔥 STOCK DETAILS STATUS: ${response?.statusCode}");
      debugPrint("🔥 STOCK DETAILS RESPONSE: $body");

      if (response?.statusCode == 200 && body is Map) {
        final rows = _parseRows(body);
        setState(() {
          _rows = loadMore ? [..._rows, ...rows] : rows;
          if (!loadMore) _parseMeta(body);
          _page = page;
          _hasMore = _computeHasMore(body, page, rows.length);
        });
      } else {
        final String msg = body is Map && body["message"] != null
            ? body["message"].toString()
            : "Could not load details";
        if (loadMore) {
          AppMessage.error(context, msg);
        } else {
          setState(() {
            _rows = [];
            _error = msg;
            _hasMore = false;
          });
        }
      }
    } catch (e) {
      debugPrint("❌ Stock details error: $e");
      if (mounted && !loadMore) {
        setState(() => _error = "Could not load details");
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  /// data: [..] / data.data: [..] / data.rows.data: [..]
  dynamic _paginator(Map body) {
    final dynamic data = body["data"];
    if (data is Map) {
      for (final k in ["rows", "items", "data"]) {
        if (data[k] is Map && data[k]["data"] is List) return data[k];
      }
      if (data["data"] is List && data["current_page"] != null) return data;
    }
    return null;
  }

  List<Map<String, dynamic>> _parseRows(Map body) {
    final dynamic data = body["data"];
    List raw = [];
    final p = _paginator(body);
    if (p is Map) {
      raw = p["data"];
    } else if (data is List) {
      raw = data;
    } else if (data is Map) {
      for (final k in ["rows", "items", "data", "lines"]) {
        if (data[k] is List) {
          raw = data[k];
          break;
        }
      }
    } else if (body["rows"] is List) {
      raw = body["rows"];
    }
    // 🔥 Branch response bija shape ma aave (company wise group vagere)
    // to aakha response ma thi label vali list shodhi lo
    if (raw.isEmpty) raw = _deepFindRows(body);

    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Response ma kyay pan label/weight vali list hoy to bhegi kari aape
  /// (jem ke data.branches[].rows, data.companies[].data ...)
  List _deepFindRows(dynamic node, [int depth = 0]) {
    if (depth > 5) return [];
    bool looksLikeRow(dynamic m) =>
        m is Map &&
            (m.containsKey("qr_code") ||
                m.containsKey("label_code") ||
                m.containsKey("barcode") ||
                m.containsKey("gross_weight"));

    if (node is List) {
      if (node.isNotEmpty && node.every(looksLikeRow)) return node;
      final List out = [];
      for (final e in node) {
        out.addAll(_deepFindRows(e, depth + 1));
      }
      return out;
    }
    if (node is Map) {
      final List out = [];
      for (final v in node.values) {
        if (v is Map || v is List) out.addAll(_deepFindRows(v, depth + 1));
      }
      return out;
    }
    return [];
  }

  void _parseMeta(Map body) {
    final dynamic data = body["data"];
    final Map src = data is Map ? data : body;

    final dynamic t = src["totals"] ?? src["summary"] ?? body["totals"];
    _serverTotals = t is Map ? Map<String, dynamic>.from(t) : null;

    final dynamic counts =
        src["image_counts"] ?? src["counts"] ?? body["image_counts"];
    final Map c = counts is Map ? counts : src;
    _withImage = int.tryParse(
        "${c["with_image"] ?? c["withImage"] ?? c["with"] ?? ""}");
    _withoutImage = int.tryParse(
        "${c["without_image"] ?? c["withoutImage"] ?? c["without"] ?? ""}");

    final p = _paginator(body);
    _total = int.tryParse(
        "${(p is Map ? p["total"] : null) ?? body["recordsFiltered"] ?? body["total"] ?? ""}");
  }

  bool _computeHasMore(Map body, int page, int got) {
    final p = _paginator(body);
    if (p is Map) {
      final int last = int.tryParse("${p["last_page"] ?? ""}") ?? 0;
      if (last > 0) return page < last;
      if (p.containsKey("next_page_url")) return p["next_page_url"] != null;
    }
    if (_total != null) return _rows.length < _total! && got > 0;
    return got >= _perPage;
  }

  // ============================================================
  // EXPORT (PDF / Excel)
  // ============================================================

  Future<void> _export(String type) async {
    if (_exporting != null) return;
    setState(() => _exporting = type);

    final String url = _buildUrl(export: type);
    debugPrint("🔥 STOCK DETAILS ${type.toUpperCase()}: $url");

    try {
      final response = await ApiHelper().getPdfRequest(url);
      final dynamic data = response?.data;

      if (response == null ||
          response.statusCode != 200 ||
          data is! List<int> ||
          data.isEmpty) {
        if (mounted) AppMessage.error(context, "Could not download the file");
        return;
      }

      // Server e file ni jagye JSON error mokli hoy (pehlo byte 0x7B)
      if (data.first == 0x7B) {
        String msg = "Could not download the file";
        try {
          final dynamic j = jsonDecode(utf8.decode(data));
          if (j is Map && j["message"] != null) msg = j["message"].toString();
        } catch (_) {}
        if (mounted) AppMessage.error(context, msg);
        return;
      }

      final Directory dir = await getTemporaryDirectory();
      final String stamp = DateFormat("ddMMyyyy_HHmm").format(DateTime.now());
      final String safeName =
      widget.itemName.replaceAll(RegExp(r"[^A-Za-z0-9]+"), "_");
      final File file = File(
          "${dir.path}/Stock_${safeName}_$stamp.${type == "pdf" ? "pdf" : "xlsx"}");
      await file.writeAsBytes(data, flush: true);
      await OpenFile.open(file.path);
    } catch (e) {
      debugPrint("❌ Stock details export error: $e");
      if (mounted) AppMessage.error(context, "Could not download the file");
    } finally {
      if (mounted) setState(() => _exporting = null);
    }
  }

  // ============================================================
  // VALUES
  // ============================================================

  static double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString().replaceAll(",", "") ?? "") ?? 0;
  }

  static String _str(dynamic v) {
    if (v == null) return "";
    if (v is Map) return (v["item_name"] ?? v["name"] ?? "").toString();
    final s = v.toString().trim();
    return s == "null" ? "" : s;
  }

  String _date(Map r) {
    final String s = _str(r["date"] ?? r["created_at"] ?? r["entry_date"]);
    final DateTime? d = DateTime.tryParse(s);
    if (d == null) return s.isEmpty ? "-" : s;
    return DateFormat("dd-MM-yyyy hh:mm a").format(d.toLocal());
  }

  String _label(Map r) {
    final dynamic set = r["item_set"];
    return _str(r["label_code"] ??
        r["qr_code"] ??
        r["barcode"] ??
        r["label"] ??
        (set is Map ? set["qr_code"] : null));
  }

  String _item(Map r) {
    final s = _str(r["item_name"] ?? r["item"]);
    return s.isEmpty ? widget.itemName : s;
  }

  double _qty(Map r) => _num(r["qty_pcs"] ?? r["qty"] ?? r["pcs"] ?? 1);
  double _gross(Map r) => _num(r["gross_weight"] ?? r["gross"]);
  double _net(Map r) => _num(r["net_weight"] ?? r["net"]);
  double _fine(Map r) =>
      _num(r["fine_weight"] ?? r["total_fine_weight"] ?? r["fine"]);

  bool _hasImage(Map r) {
    final dynamic s = r["image_status"];
    if (s != null) {
      final t = s.toString().toLowerCase();
      if (t.contains("without") || t == "0" || t == "false") return false;
      if (t.contains("with") || t == "1" || t == "true") return true;
    }
    final dynamic flag = r["has_image"];
    if (flag != null) return flag == true || flag.toString() == "1";
    final dynamic img = r["image"] ?? r["image_url"] ?? r["images"];
    if (img is List) return img.isNotEmpty;
    return _str(img).isNotEmpty;
  }

  String _branch(Map r) {
    final int? id = int.tryParse("${r["company_id"] ?? ""}");
    if (id != null) {
      for (final c in branchCompanies) {
        if (c.id == id) return c.name;
      }
      if (widget.branchNames[id] != null) return widget.branchNames[id]!;
    }
    final dynamic b = r["branch"] ?? r["branch_name"] ?? r["company"];
    if (b is Map) return _str(b["name"]);
    return _str(b ?? r["company_name"]);
  }

  /// Image filter pramane rows (server e filter na karyu hoy to pan sachu)
  List<Map<String, dynamic>> get _imageRows {
    if (_imageStatus == "with_image") {
      return _rows.where((r) => _hasImage(r)).toList();
    }
    if (_imageStatus == "without_image") {
      return _rows.where((r) => !_hasImage(r)).toList();
    }
    return _rows;
  }

  List<Map<String, dynamic>> get _visibleRows {
    final q = _searchCtrl.text.trim().toLowerCase();
    final base = _imageRows;
    if (q.isEmpty) return base;
    return base
        .where((r) => "${_label(r)} ${_item(r)} ${_branch(r)} ${_date(r)}"
        .toLowerCase()
        .contains(q))
        .toList();
  }

  double _total4(String key) {
    final t = _serverTotals;
    // Image filter / branch merge ma list mathi j total (sachu rahe)
    if (t != null && _imageStatus.isEmpty && !_branchMode) {
      final alias = {
        "qty": ["qty_pcs", "qty", "pcs"],
        "gross": ["gross_weight", "gross"],
        "net": ["net_weight", "net"],
        "fine": ["fine_weight", "total_fine_weight", "fine"],
      }[key]!;
      for (final a in alias) {
        if (t[a] != null) return _num(t[a]);
      }
    }
    return _imageRows.fold<double>(0, (s, r) {
      switch (key) {
        case "qty":
          return s + _qty(r);
        case "gross":
          return s + _gross(r);
        case "net":
          return s + _net(r);
        default:
          return s + _fine(r);
      }
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetch,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    _branchReportWidget(),
                    _imageFilterCard(),
                    _totalsRow(),
                    _searchBox(),
                    _table(),
                    if (_hasMore) _loadMoreBtn(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- HEADER ----------------

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.secondaryDark],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Stock Position Details",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    widget.itemName,
                    if (widget.stockType.isNotEmpty && widget.stockType != "-")
                      widget.stockType,
                  ].join(" | "),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: _muted),
                ),
              ],
            ),
          ),
          _exportBtn("excel", Icons.table_chart_rounded,
              const Color(0xff1D6F42)),
          const SizedBox(width: 6),
          _exportBtn("pdf", Icons.picture_as_pdf_rounded,
              const Color(0xffD64545)),
        ],
      ),
    );
  }

  Widget _exportBtn(String type, IconData icon, Color color) {
    final bool busy = _exporting == type;
    return InkWell(
      onTap: busy ? null : () => _export(type),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            busy
                ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: color),
            )
                : Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(
              type == "pdf" ? "PDF" : "Excel",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- IMAGE FILTER ----------------

  Widget _imageFilterCard() {
    // Server count na aave to "All items" vakhte ganela count rakhiye
    if (_imageStatus.isEmpty && _withImage == null) {
      _cachedWith = _rows.where((r) => _hasImage(r)).length;
      _cachedWithout = _rows.length - _cachedWith!;
    }
    final int withImg = _withImage ??
        _cachedWith ??
        _rows.where((r) => _hasImage(r)).length;
    final int withoutImg = _withoutImage ??
        _cachedWithout ??
        _rows.where((r) => !_hasImage(r)).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _countPill("With image", withImg, _green),
              const SizedBox(width: 8),
              _countPill("Without image", withoutImg, _orange),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            "Image status",
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: _muted,
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _imageFilters.entries.map((e) {
                final bool sel = e.key == _imageStatus;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: sel,
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    selectedColor: AppColors.primaryDark,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                        color: sel ? AppColors.primaryDark : _line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : _ink,
                    ),
                    onSelected: (_) => _setImageStatus(e.key),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _countPill(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              label.startsWith("With ")
                  ? Icons.image_rounded
                  : Icons.hide_image_rounded,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 11.5, color: color),
              ),
            ),
            Text(
              "$count",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- TOTALS ----------------

  Widget _totalsRow() {
    final items = [
      ("Qty Pcs", _total4("qty").toStringAsFixed(0), Icons.inventory_2_rounded),
      ("Gross Wt", _wt.format(_total4("gross")), Icons.scale_rounded),
      ("Net Wt", _wt.format(_total4("net")), Icons.balance_rounded),
      ("Fine Wt", _wt.format(_total4("fine")), Icons.diamond_rounded),
    ];

    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final it = items[i];
          return Container(
            width: 130,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: _card(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(it.$3, size: 13, color: AppColors.primaryDark),
                    const SizedBox(width: 5),
                    Text(it.$1,
                        style: const TextStyle(fontSize: 11, color: _muted)),
                  ],
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    it.$2,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _ink,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------- SEARCH ----------------

  Widget _searchBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 42,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 13, color: _ink),
              decoration: InputDecoration(
                hintText: "Search label, item, branch",
                hintStyle: const TextStyle(fontSize: 13, color: _muted),
                prefixIcon: Icon(Icons.search_rounded,
                    size: 19, color: AppColors.primaryDark),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                  BorderSide(color: AppColors.primaryDark.withOpacity(0.6)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Showing ${_visibleRows.length}"
                "${_total != null && _imageStatus.isEmpty ? " of $_total" : ""} entries"
                "${_imageStatus.isEmpty ? "" : " • ${_imageFilters[_imageStatus]}"}",
            style: const TextStyle(fontSize: 11.5, color: _muted),
          ),
        ],
      ),
    );
  }

  // ---------------- TABLE ----------------

  Widget _table() {
    if (_loading && _rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final rows = _visibleRows;
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 50),
        child: Column(
          children: [
            Icon(
              _error != null
                  ? Icons.cloud_off_rounded
                  : Icons.inventory_2_outlined,
              size: 44,
              color: _muted.withOpacity(0.6),
            ),
            const SizedBox(height: 10),
            Text(
              _error ?? "No records found",
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // (title, width, alignLeft)
    final List<(String, double, bool)> cols = [
      ("#", 44, false),
      ("Date", 150, true),
      ("Label Code", 110, true),
      ("Item", 120, true),
      ("Qty Pcs", 75, false),
      ("Gross Wt", 95, false),
      ("Net Wt", 95, false),
      ("Fine Wt", 95, false),
      ("Image status", 120, true),
      if (_branchMode) ("Branch", 130, true),
    ];
    final double width = cols.fold(0.0, (s, c) => s + c.$2);

    Widget cell(String text, (String, double, bool) c,
        {bool head = false, Color? color, bool isLast = false}) {
      return Container(
        width: c.$2,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        alignment: c.$3 ? Alignment.centerLeft : Alignment.center,
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
            right: BorderSide(
              color: head ? Colors.white24 : _line,
              width: 0.8,
            ),
          ),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: head ? FontWeight.w800 : FontWeight.w500,
            color: head ? Colors.white : (color ?? _ink),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      decoration: _card(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Scrollbar(
          controller: _hScroll,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _hScroll,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Column(
                children: [
                  Container(
                    color: AppColors.primaryDark,
                    child: Row(
                      children: [
                        for (int i = 0; i < cols.length; i++)
                          cell(cols[i].$1, cols[i],
                              head: true, isLast: i == cols.length - 1),
                      ],
                    ),
                  ),
                  for (int r = 0; r < rows.length; r++)
                    Builder(builder: (_) {
                      final row = rows[r];
                      final bool img = _hasImage(row);
                      final values = [
                        "${r + 1}",
                        _date(row),
                        _label(row).isEmpty ? "-" : _label(row),
                        _item(row),
                        _qty(row).toStringAsFixed(0),
                        _wt.format(_gross(row)),
                        _wt.format(_net(row)),
                        _wt.format(_fine(row)),
                        img ? "With image" : "Without image",
                        if (_branchMode)
                          _branch(row).isEmpty ? "-" : _branch(row),
                      ];
                      return Container(
                        decoration: BoxDecoration(
                          color: r.isEven ? Colors.white : _bg,
                          border: const Border(
                            top: BorderSide(color: _line, width: 0.6),
                          ),
                        ),
                        child: Row(
                          children: [
                            for (int i = 0; i < cols.length; i++)
                              cell(
                                values[i],
                                cols[i],
                                isLast: i == cols.length - 1,
                                color: cols[i].$1 == "Image status"
                                    ? (img ? _green : _orange)
                                    : cols[i].$1 == "Branch"
                                    ? _green
                                    : null,
                              ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loadMoreBtn() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: InkWell(
        onTap: _loadingMore ? null : () => _fetch(loadMore: true),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primaryDark.withOpacity(0.3)),
          ),
          child: Center(
            child: _loadingMore
                ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryDark,
              ),
            )
                : Text(
              "Load More (${_rows.length} loaded)",
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 🔥 BRANCH REPORTS — LOAD (fakt main company admin)
  // ============================================================

  Future<void> _loadBranches() async {
    setState(() => branchesLoading = true);
    try {
      final bool isAdmin = await BranchAccess.isMainCompanyAdmin();
      if (!isAdmin) {
        if (mounted) setState(() => canViewBranches = false);
        return;
      }

      final overview = await BranchApi.fetchOverview();
      if (!mounted) return;

      final List<Company> list = [
        if (overview.mainCompany != null) overview.mainCompany!,
        ...overview.branches,
      ];

      setState(() {
        branchCompanies = list;
        canViewBranches = list.length > 1;

        // Aavta slug hoy to e j select, nahi to main company
        final Set<int> fromSlugs = {
          for (final c in list)
            if (_appliedSlugs.contains(c.slug ?? c.id.toString())) c.id,
        };
        selectedCompanyIds = fromSlugs.isNotEmpty
            ? fromSlugs
            : {if (overview.mainCompany != null) overview.mainCompany!.id};
      });
    } catch (e) {
      debugPrint("❌ Branch list load failed: $e");
      if (mounted) setState(() => canViewBranches = false);
    } finally {
      if (mounted) setState(() => branchesLoading = false);
    }
  }

  String _companyLabel(Company c) =>
      c.isMain ? "${c.name} (Main Company)" : c.name;

  /// 🔥 VIEW REPORT — select kareli branches nu details
  Future<void> _viewBranchReport() async {
    if (selectedCompanyIds.isEmpty) {
      AppMessage.error(context, "Please select at least one branch");
      return;
    }
    setState(() {
      _appliedSlugs = branchCompanies
          .where((c) => selectedCompanyIds.contains(c.id))
          .map((c) => c.slug ?? c.id.toString())
          .toList();
      branchReportLoading = true;
    });
    try {
      _cachedWith = null;
      _cachedWithout = null;
      await _fetch();
      if (_imageStatus.isNotEmpty) await _ensureAllPages();
    } finally {
      if (mounted) setState(() => branchReportLoading = false);
    }
  }

  Future<void> _clearBranchReport() async {
    setState(() {
      _appliedSlugs = [];
      _cachedWith = null;
      _cachedWithout = null;
    });
    await _fetch();
    if (_imageStatus.isNotEmpty) await _ensureAllPages();
  }

  // ============================================================
  // 🔥 BRANCH REPORTS (expand tab)
  // ============================================================

  Widget _branchReportWidget() {
    if (branchesLoading) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        padding: const EdgeInsets.all(14),
        decoration: _card(),
        child: Row(
          children: [
            SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              "Loading branches...",
              style: TextStyle(fontSize: 12.5, color: _muted),
            ),
          ],
        ),
      );
    }

    if (!canViewBranches) return const SizedBox.shrink();

    final selectedList = branchCompanies
        .where((c) => selectedCompanyIds.contains(c.id))
        .toList();

    final Set<String> selectedSlugs =
    selectedList.map((c) => c.slug ?? c.id.toString()).toSet();
    final bool appliedDiffers = selectedSlugs.length != _appliedSlugs.length ||
        !selectedSlugs.containsAll(_appliedSlugs);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => branchExpanded = !branchExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        AppColors.primaryDark,
                        AppColors.secondaryDark,
                      ]),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.account_tree_rounded,
                        size: 13, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Branch Reports",
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${selectedCompanyIds.length}/${branchCompanies.length}",
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: branchExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.primaryDark, size: 22),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: !branchExpanded
                ? const SizedBox(width: double.infinity)
                : Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: _openBranchPicker,
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: selectedList.isEmpty
                                ? const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Text(
                                "Select branches",
                                style: TextStyle(
                                    color: _muted, fontSize: 13),
                              ),
                            )
                                : Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final c in selectedList)
                                  _branchChip(c),
                              ],
                            ),
                          ),
                          Icon(Icons.keyboard_arrow_down_rounded,
                              color: AppColors.primaryDark),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Select one or more branches to combine their report data.",
                    style: TextStyle(fontSize: 11.5, color: _muted),
                  ),
                  const SizedBox(height: 10),
                  _viewReportButton(highlight: appliedDiffers),
                  if (_branchMode) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                      decoration: BoxDecoration(
                        color: _green.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(8),
                        border:
                        Border.all(color: _green.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              size: 15, color: _green),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Showing combined report of "
                                  "${_appliedSlugs.length} "
                                  "${_appliedSlugs.length == 1 ? 'branch' : 'branches'}",
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xff166534),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _clearBranchReport,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8),
                              minimumSize: const Size(0, 28),
                              tapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              "Clear",
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xffD32F2F),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _branchChip(Company c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primaryDark.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(c.isMain ? Icons.verified_rounded : c.type.icon,
              size: 13, color: AppColors.primaryDark),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              _companyLabel(c),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 2),
          InkWell(
            onTap: () => setState(() => selectedCompanyIds.remove(c.id)),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close_rounded,
                  size: 14, color: AppColors.primaryDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewReportButton({required bool highlight}) {
    return InkWell(
      onTap: branchReportLoading ? null : _viewBranchReport,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xff22C55E), Color(0xff16A34A)],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: _green.withOpacity(highlight ? 0.35 : 0.15),
              blurRadius: highlight ? 10 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: branchReportLoading
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white),
          )
              : const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.analytics_rounded,
                  size: 17, color: Colors.white),
              SizedBox(width: 6),
              Text(
                "View Report",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🔥 Multi-select bottom sheet
  Future<void> _openBranchPicker() async {
    final Set<int> temp = {...selectedCompanyIds};

    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            final bool allSelected = temp.length == branchCompanies.length;

            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "Select Branches",
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setSheet(() {
                              if (allSelected) {
                                temp.clear();
                              } else {
                                temp.addAll(branchCompanies.map((c) => c.id));
                              }
                            }),
                            child: Text(
                              allSelected ? "Clear All" : "Select All",
                              style: TextStyle(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: branchCompanies.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: Colors.grey.shade200,
                        ),
                        itemBuilder: (context, i) {
                          final c = branchCompanies[i];
                          final bool checked = temp.contains(c.id);
                          return InkWell(
                            onTap: () => setSheet(() {
                              checked ? temp.remove(c.id) : temp.add(c.id);
                            }),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryDark
                                          .withOpacity(0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      c.isMain
                                          ? Icons.verified_rounded
                                          : c.type.icon,
                                      size: 17,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _companyLabel(c),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: _ink,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          [
                                            c.isMain ? "Main" : c.type.label,
                                            if (c.city != null) c.city!,
                                            if (!c.active) "Inactive",
                                          ].join(" • "),
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: c.active
                                                ? _muted
                                                : Colors.red.shade400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration:
                                    const Duration(milliseconds: 150),
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: checked
                                          ? AppColors.gradientBlue
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: checked
                                            ? AppColors.gradientBlue
                                            : Colors.grey.shade400,
                                        width: 1.4,
                                      ),
                                    ),
                                    child: checked
                                        ? const Icon(Icons.check_rounded,
                                        size: 14, color: Colors.white)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.border),
                                padding:
                                const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                              child: Text(
                                "Cancel",
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: InkWell(
                              onTap: () => Navigator.pop(sheetContext, temp),
                              borderRadius: BorderRadius.circular(9),
                              child: Container(
                                padding:
                                const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                    AppColors.primaryDark,
                                    AppColors.secondaryDark,
                                  ]),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Center(
                                  child: Text(
                                    "Done (${temp.length})",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() => selectedCompanyIds = result);
    }
  }

  BoxDecoration _card() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: _line),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.03),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ],
  );
}
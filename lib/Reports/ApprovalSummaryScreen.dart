import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pecifician_sysytem/Settings/BranchManagementScreen.dart'
    show BranchApi, Company, BranchTypeX;
import 'package:provider/provider.dart';

import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import '../Extra/AppColors.dart';
import '../Extra/AppMessage.dart';
import '../Extra/ItemProvider.dart';
import '../Extra/PremiumSearchableDropdown.dart';
import 'BranchAccess.dart';

/// ================================================================
/// 📊 APPROVAL SUMMARY
///
/// Normal : GET reports/approval-summary
///          ?per_page=25&page=..  (Filter pachhi: &from_date=&to_date=
///                                 &customer_id=&voucher_no=)
/// Branch : GET company/branch-reports/approval-summary
///          ?report_branches=slug1,slug2&per_page=25   (View Report)
///
/// Branch Reports tab fakt MAIN COMPANY ADMIN ne j dekhay.
/// ================================================================

class ApprovalSummaryScreen extends StatefulWidget {
  const ApprovalSummaryScreen({super.key});

  @override
  State<ApprovalSummaryScreen> createState() => _ApprovalSummaryScreenState();
}

/// Ek stage (Issued / Returned / Sold / Pending) ni vigat
class _Stage {
  final String key;
  final String title;
  final String short;
  final Color color;
  final IconData icon;
  final List<String> aliases;

  const _Stage(this.key, this.title, this.short, this.color, this.icon,
      this.aliases);
}

class _ApprovalSummaryScreenState extends State<ApprovalSummaryScreen> {
  // ============================================================
  // 🔧 API URLS
  // ============================================================

  static String get _normalUrl => "${ApiConstants.baseUrl}reports/approval-summary";

  static String get _branchUrl =>
      "${ApiConstants.baseUrl}company/branch-reports/approval-summary";

  /// Export: reports/approval-summary?export=pdf  (CSV mate ?export=csv)
  static String _exportUrl(String type) => _normalUrl;

  // ============================================================
  // COLORS
  // ============================================================

  static const Color _ink = Color(0xff172033);
  static const Color _muted = Color(0xff7A8194);
  static const Color _line = Color(0xffE3E7F0);
  static const Color _bg = Color(0xffF5F7FB);

  static const List<_Stage> _stages = [
    _Stage("issued", "Issued on Approval", "Issued", Color(0xff6D4AFF),
        Icons.outbox_rounded, ["issued", "approval", "approved", "issue"]),
    _Stage("returned", "Returned", "Returned", Color(0xff16A34A),
        Icons.assignment_return_rounded, ["returned", "return", "returns"]),
    _Stage("sold", "Sold", "Sold", Color(0xff2563EB),
        Icons.shopping_bag_rounded, ["sold", "sale", "sales"]),
    _Stage("pending", "Pending with Customer", "Pending", Color(0xffE08A00),
        Icons.hourglass_bottom_rounded, ["pending", "balance", "with_customer"]),
  ];

  /// metric key → screen label
  static const List<(String, String)> _metrics = [
    ("gross", "Gross Wt"),
    ("other", "Other Wt"),
    ("net", "Net Wt"),
    ("fine", "Fine Wt"),
  ];

  // ============================================================
  // FILTERS
  // ============================================================

  String? selectedCustomerId;
  DateTime? fromDate;
  DateTime? toDate;
  final TextEditingController voucherCtrl = TextEditingController();
  bool filterApplied = false;

  // ============================================================
  // DATA
  // ============================================================

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  dynamic _serverSummary;
  int? _totalVouchers;

  final TextEditingController searchCtrl = TextEditingController();
  final Set<String> _expanded = {};
  String? _exporting;

  final DateFormat _apiDate = DateFormat("yyyy-MM-dd");
  final DateFormat _uiDate = DateFormat("dd MMM yyyy");
  final NumberFormat _wtFmt = NumberFormat("#,##0.000");

  // ============================================================
  // 🔥 BRANCH REPORTS STATE
  // ============================================================

  static const int branchPerPage = 25;

  List<Company> branchCompanies = [];
  Set<int> selectedCompanyIds = {};
  List<int> appliedCompanyIds = [];

  bool get branchMode => appliedCompanyIds.isNotEmpty;

  int branchPage = 1;
  bool branchHasMore = false;
  bool branchLoadingMore = false;

  bool branchesLoading = false;
  bool canViewBranches = false;
  bool branchExpanded = true;
  bool branchReportLoading = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      Provider.of<ItemProvider>(context, listen: false).loadCustomers();
    });
    _fetch();
    loadBranches();
  }

  @override
  void dispose() {
    voucherCtrl.dispose();
    searchCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // URLS
  // ============================================================

  Map<String, String> _filterQuery({int page = 1}) {
    final Map<String, String> q = {
      "per_page": "$branchPerPage",
      if (page > 1) "page": "$page",
    };
    if (filterApplied) {
      if (fromDate != null) q["from_date"] = _apiDate.format(fromDate!);
      if (toDate != null) q["to_date"] = _apiDate.format(toDate!);
      if (selectedCustomerId != null && selectedCustomerId!.isNotEmpty) {
        q["customer_id"] = selectedCustomerId!;
      }
      if (voucherCtrl.text.trim().isNotEmpty) {
        q["voucher_no"] = voucherCtrl.text.trim();
      }
    }
    return q;
  }

  String buildReportUrl(int page) => Uri.parse(_normalUrl)
      .replace(queryParameters: _filterQuery(page: page))
      .toString();

  List<String> get _appliedBranchSlugs => branchCompanies
      .where((c) => appliedCompanyIds.contains(c.id))
      .map((c) => c.slug ?? c.id.toString())
      .toList();

  String buildBranchReportUrl(int page) {
    // Comma encode na thay (%2C) etle URL hathe banaviye
    final String branches =
    _appliedBranchSlugs.map(Uri.encodeQueryComponent).join(",");

    String url = "$_branchUrl"
        "?report_branches=$branches"
        "&per_page=$branchPerPage";
    if (page > 1) url += "&page=$page";
    return url;
  }

  // ============================================================
  // API (normal + branch, pagination sathe)
  // ============================================================

  Future<void> _loadMore() => _fetch(loadMore: true);

  Future<void> _fetch({bool loadMore = false}) async {
    final int page = loadMore ? branchPage + 1 : 1;
    final String url =
    branchMode ? buildBranchReportUrl(page) : buildReportUrl(page);

    debugPrint(
        "🔥 ${branchMode ? "BRANCH " : ""}APPROVAL SUMMARY API: $url");

    setState(() {
      if (loadMore) {
        branchLoadingMore = true;
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

      if (response?.statusCode == 200 && body is Map) {
        final List<Map<String, dynamic>> rows = _parseRows(body);

        setState(() {
          _rows = loadMore ? [..._rows, ...rows] : rows;
          if (!loadMore) {
            _serverSummary = _parseSummary(body);
            _expanded.clear();
          }
          _totalVouchers = _parseTotal(body) ?? _totalVouchers;
          branchPage = page;
          branchHasMore = _hasMorePages(body, page, rows.length);
        });
        debugPrint("✅ Approval summary rows: ${_rows.length}");
      } else {
        final String msg = body is Map && body["message"] != null
            ? body["message"].toString()
            : "Could not load the report";
        if (loadMore) {
          AppMessage.error(context, msg);
        } else {
          setState(() {
            _rows = [];
            _serverSummary = null;
            _totalVouchers = null;
            _error = msg;
            branchHasMore = false;
          });
        }
      }
    } catch (e) {
      debugPrint("❌ Approval summary error: $e");
      if (mounted && !loadMore) {
        setState(() => _error = "Could not load the report");
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          branchLoadingMore = false;
        });
      }
    }
  }

  // ============================================================
  // PARSE — response alag shape ma aave to pan chale
  // ============================================================

  dynamic _paginator(Map body) {
    final dynamic data = body["data"];
    if (data is Map) {
      for (final k in ["rows", "vouchers", "approvals", "data"]) {
        if (data[k] is Map && data[k]["data"] is List) return data[k];
      }
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
      for (final k in ["rows", "vouchers", "approvals", "data", "items"]) {
        if (data[k] is List) {
          raw = data[k];
          break;
        }
      }
    }

    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  dynamic _parseSummary(Map body) {
    final dynamic data = body["data"];
    if (data is Map) {
      for (final k in ["totals", "summary", "cards", "stats", "metrics_totals"]) {
        if (data[k] is Map || data[k] is List) return data[k];
      }
    }
    return body["totals"] ?? body["summary"];
  }

  int? _parseTotal(Map body) {
    final dynamic data = body["data"];
    final p = _paginator(body);
    return int.tryParse("${(p is Map ? p["total"] : null) ?? (data is Map ? (data["total_vouchers"] ?? data["voucher_count"]) : null) ?? body["recordsFiltered"] ?? body["total"] ?? ""}");
  }

  bool _hasMorePages(Map body, int page, int got) {
    final p = _paginator(body);
    if (p is Map) {
      final int last = int.tryParse("${p["last_page"] ?? ""}") ?? 0;
      if (last > 0) return page < last;
      if (p.containsKey("next_page_url")) return p["next_page_url"] != null;
    }
    final int? total = _parseTotal(body);
    if (total != null) return _rows.length < total && got > 0;
    return got >= branchPerPage;
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
    if (v is Map) return (v["name"] ?? v["label"] ?? "").toString();
    final s = v.toString().trim();
    return s == "null" ? "" : s;
  }

  /// metric na shakya key naam (gross → gross, gross_weight, gross_wt)
  static List<String> _metricKeys(String m) {
    if (m == "qty") return ["qty", "items", "pcs", "qty_pcs", "count", "item_count"];
    if (m == "fine") return ["fine", "fine_weight", "fine_wt", "total_fine_weight"];
    return [m, "${m}_weight", "${m}_wt"];
  }

  /// Ek map mathi metric value (direct keys)
  static dynamic _pick(Map m, String metric) {
    for (final k in _metricKeys(metric)) {
      if (m[k] != null) return m[k];
    }
    return null;
  }

  /// Row mathi stage nu metric:
  /// issued_qty / issued_gross_weight / issued: {qty, gross}
  double _rowMetric(Map r, _Stage st, String metric) {
    for (final a in st.aliases) {
      final dynamic nested = r[a];
      if (nested is Map) {
        final v = _pick(nested, metric);
        if (v != null) return _num(v);
      }
      for (final k in _metricKeys(metric)) {
        final dynamic v = r["${a}_$k"] ?? r["${k}_$a"];
        if (v != null) return _num(v);
      }
    }
    return 0;
  }

  /// Server key/label kaya stage nu chhe? (pending → return → sold → issued
  /// kram ma, jethi "Pending Approval" ke "Approval Return" issued ma na jay)
  static String? _stageOfLabel(String raw) {
    final String k = raw.toLowerCase();
    if (k.contains("pending") || k.contains("balance") || k.contains("with customer") || k.contains("with_customer")) {
      return "pending";
    }
    if (k.contains("return")) return "returned";
    if (k.contains("sold") || k.contains("sale")) return "sold";
    if (k.contains("issue") || k.contains("approval")) return "issued";
    return null;
  }

  /// Summary card nu metric — server totals hoy to e, nahi to rows no sarvalo
  double _summaryMetric(_Stage st, String metric) {
    final dynamic s = _serverSummary;
    Map? sec;

    if (s is Map) {
      for (final entry in s.entries) {
        final String k = entry.key.toString().toLowerCase();
        if (entry.value is Map && _stageOfLabel(k) == st.key) {
          sec = entry.value;
          break;
        }
      }
      // Flat: issued_qty, issued_gross ...
      if (sec == null) {
        for (final a in st.aliases) {
          for (final k in _metricKeys(metric)) {
            if (s["${a}_$k"] != null) return _num(s["${a}_$k"]);
          }
        }
      }
    } else if (s is List) {
      for (final e in s.whereType<Map>()) {
        final String label =
            "${e["key"] ?? ""} ${e["label"] ?? ""} ${e["title"] ?? ""}";
        if (_stageOfLabel(label) == st.key) {
          sec = e;
          break;
        }
      }
    }

    if (sec != null) {
      final v = _pick(sec, metric);
      if (v != null) return _num(v);
    }

    return _rows.fold<double>(0, (sum, r) => sum + _rowMetric(r, st, metric));
  }

  String _voucherNo(Map r) =>
      _str(r["approval_no"] ?? r["voucher_no"] ?? r["number"] ?? r["voucher"]);

  String _customer(Map r) => _str(r["customer_name"] ?? r["customer"]);

  String _date(Map r) {
    final String s =
    _str(r["approval_date"] ?? r["date"] ?? r["entry_date"] ?? r["voucher_date"]);
    final DateTime? d = DateTime.tryParse(s);
    return d == null
        ? (s.isEmpty ? "-" : s)
        : DateFormat("dd-MM-yyyy").format(d.toLocal());
  }

  String _branchNameOf(Map r) {
    final int? companyId = int.tryParse("${r["company_id"] ?? ""}");
    if (companyId != null) {
      for (final c in branchCompanies) {
        if (c.id == companyId) return c.name;
      }
    }
    return _str(r["branch_name"] ?? r["branch"] ?? r["company_name"]);
  }

  String _qty(double v) => v.toStringAsFixed(0);

  // ============================================================
  // SEARCH
  // ============================================================

  List<Map<String, dynamic>> get _filteredRows {
    final String q = searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _rows;
    return _rows.where((r) {
      return "${_voucherNo(r)} ${_customer(r)} ${_branchNameOf(r)}"
          .toLowerCase()
          .contains(q);
    }).toList();
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Future<void> applyFilter() async {
    if (fromDate != null && toDate != null && fromDate!.isAfter(toDate!)) {
      AppMessage.error(context, "From Date cannot be greater than To Date");
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      filterApplied = true;
      appliedCompanyIds = [];
      branchHasMore = false;
    });
    await _fetch();
  }

  Future<void> resetFilters() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      selectedCustomerId = null;
      fromDate = null;
      toDate = null;
      voucherCtrl.clear();
      searchCtrl.clear();
      filterApplied = false;
      appliedCompanyIds = [];
      branchHasMore = false;
    });
    await _fetch();
  }

  Future<void> _pickDate(bool isFrom) async {
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: (isFrom ? fromDate : toDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (d == null) return;
    setState(() => isFrom ? fromDate = d : toDate = d);
  }

  Future<void> _export(String type) async {
    if (_exporting != null) return;

    setState(() => _exporting = type);

    final String url;
    if (branchMode) {
      // 🔥 Branch merge report:
      // company/branch-reports/approval-summary
      //   ?report_branches=slug1,slug2&export=pdf
      // (Comma encode na thay etle URL hathe banaviye)
      final String branches =
      _appliedBranchSlugs.map(Uri.encodeQueryComponent).join(",");
      url = "$_branchUrl?report_branches=$branches&export=$type";
    } else {
      // 🔥 reports/approval-summary?export=pdf (+ filter hoy to e pan)
      // per_page / page export ma na jay
      final Map<String, String> q = {
        "export": type,
        ..._filterQuery()..remove("per_page")..remove("page"),
      };
      url = Uri.parse(_exportUrl(type))
          .replace(queryParameters: q)
          .toString();
    }
    debugPrint("🔥 APPROVAL SUMMARY EXPORT: $url");

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

      final Directory dir = await getTemporaryDirectory();
      final String stamp = DateFormat("ddMMyyyy_HHmm").format(DateTime.now());
      final File file = File(
          "${dir.path}/Approval_Summary_$stamp.${type == "pdf" ? "pdf" : "csv"}");
      await file.writeAsBytes(data, flush: true);
      await OpenFile.open(file.path);
    } catch (e) {
      debugPrint("❌ Approval summary export error: $e");
      if (mounted) AppMessage.error(context, "Could not download the file");
    } finally {
      if (mounted) setState(() => _exporting = null);
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final rows = _filteredRows;

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
                    branchReportWidget(),
                    _filterCard(),
                    _summaryCards(),
                    _searchBox(),
                    ..._voucherList(rows),
                    if (branchHasMore) _loadMoreButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Approval Summary",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Issued, returned, sold and pending items",
                  style: TextStyle(fontSize: 11.5, color: _muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FILTER CARD
  // ============================================================

  Widget _filterCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// INFO
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: AppColors.primaryDark),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Filter by approval date. Figures show the current status of "
                        "items on those vouchers, including later returns and sales.",
                    style: TextStyle(fontSize: 11, color: _muted, height: 1.35),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          /// CUSTOMER
          Consumer<ItemProvider>(
            builder: (context, provider, _) {
              final List<Map<String, dynamic>> customers = provider.customers
                  .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
                  .toList();

              Map<String, dynamic>? selected;
              for (final c in customers) {
                if (c["id"]?.toString() == selectedCustomerId) {
                  selected = c;
                  break;
                }
              }

              return PremiumSearchableDropdown<Map<String, dynamic>>(
                label: "",
                hint: "All Customers",
                items: customers,
                value: selected,
                prefixIcon: Icons.person_outline_rounded,
                itemLabel: (c) => c["name"]?.toString() ?? "-",
                searchText: (c) => [
                  c["name"]?.toString() ?? "",
                  c["mobile_no"]?.toString() ?? "",
                ].join(" "),
                onChanged: (c) =>
                    setState(() => selectedCustomerId = c?["id"]?.toString()),
              );
            },
          ),

          const SizedBox(height: 8),

          /// DATES
          Row(
            children: [
              _dateTile("From", fromDate, () => _pickDate(true)),
              const SizedBox(width: 8),
              _dateTile("To", toDate, () => _pickDate(false)),
            ],
          ),

          const SizedBox(height: 8),

          /// VOUCHER
          SizedBox(
            height: 44,
            child: TextField(
              controller: voucherCtrl,
              style: const TextStyle(fontSize: 13, color: _ink),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => applyFilter(),
              decoration: _inputDecoration(
                hint: "Approval voucher number",
                icon: Icons.receipt_long_outlined,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: _gradientButton(
                  label: "Filter",
                  icon: Icons.filter_alt_rounded,
                  busy: _loading && !branchMode,
                  onTap: applyFilter,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _outlineButton(
                  label: "Reset",
                  icon: Icons.refresh_rounded,
                  color: _ink,
                  onTap: resetFilters,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _outlineButton(
                  label: _exporting == "csv" ? "Downloading..." : "Export CSV",
                  icon: Icons.grid_on_rounded,
                  color: const Color(0xff1D6F42),
                  onTap: () => _export("csv"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _outlineButton(
                  label: _exporting == "pdf" ? "Downloading..." : "Export PDF",
                  icon: Icons.picture_as_pdf_rounded,
                  color: const Color(0xffD64545),
                  onTap: () => _export("pdf"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateTile(String label, DateTime? d, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _line),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(fontSize: 10, color: _muted)),
                    Text(
                      d == null ? "dd/mm/yyyy" : _uiDate.format(d),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: d == null ? _muted : _ink,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.calendar_month_rounded,
                  size: 18, color: AppColors.primaryDark),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _muted, fontSize: 13),
      prefixIcon: icon == null
          ? null
          : Icon(icon, size: 19, color: AppColors.primaryDark),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.primaryDark.withOpacity(0.6)),
      ),
    );
  }

  Widget _gradientButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool busy = false,
  }) {
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryDark, AppColors.secondaryDark],
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: busy
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white),
          )
              : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
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

  Widget _outlineButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 🔥 OVERVIEW — premium cards (horizontal scroll)
  // ============================================================

  /// Rang ne thodo ghatto karvo (gradient na bija chheda mate)
  static Color _darken(Color c, [double amount = 0.22]) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  Widget _summaryCards() {
    if (_rows.isEmpty && _serverSummary == null) return const SizedBox.shrink();

    final int vouchers = _totalVouchers ?? _rows.length;
    final double issued = _summaryMetric(_stages[0], "qty");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// TITLE + TOTAL VOUCHERS
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.secondaryDark],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "Overview",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.secondaryDark],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long_rounded,
                        size: 13, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      "$vouchers vouchers",
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        /// CARDS — horizontal scroll
        SizedBox(
          height: 240,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            itemCount: _stages.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _stageCard(_stages[i], issued),
          ),
        ),
      ],
    );
  }

  Widget _stageCard(_Stage st, double issuedTotal) {
    final double items = _summaryMetric(st, "qty");
    final bool isIssued = st.key == "issued";
    final double pct = !isIssued && issuedTotal > 0
        ? (items / issuedTotal).clamp(0.0, 1.0).toDouble()
        : 1.0;

    return Container(
      width: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          colors: [st.color.withOpacity(0.7), _darken(st.color).withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: st.color.withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            /// Decorative circles
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.10),
                ),
              ),
            ),
            Positioned(
              right: 30,
              top: 40,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// ICON + TITLE
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.25),
                          ),
                        ),
                        child: Icon(st.icon, size: 16, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          st.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  /// BIG COUNT
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _qty(items),
                        style: const TextStyle(
                          fontSize: 30,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          "items",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (!isIssued)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "${(pct * 100).toStringAsFixed(0)}%",
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),

                  /// Issued no ketlo bhag (progress)
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 4,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),

                  const SizedBox(height: 10),

                  /// WEIGHTS (glass box)
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.18),
                      ),
                    ),
                    child: Column(
                      children: [
                        for (final m in _metrics)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Text(
                                  m.$2,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: Colors.white.withOpacity(0.78),
                                  ),
                                ),
                                const Spacer(),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      "${_wtFmt.format(_summaryMetric(st, m.$1))} g",
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _searchBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 44,
            child: TextField(
              controller: searchCtrl,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 13, color: _ink),
              decoration: _inputDecoration(
                hint: "Search voucher, customer, branch",
                icon: Icons.search_rounded,
              ).copyWith(
                suffixIcon: searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => setState(searchCtrl.clear),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            searchCtrl.text.isEmpty
                ? "Showing ${_rows.length}${_totalVouchers != null ? " of $_totalVouchers" : ""} vouchers"
                : "Showing ${_filteredRows.length} of ${_rows.length} vouchers",
            style: const TextStyle(fontSize: 11.5, color: _muted),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 🔥 VOUCHER CARDS
  // ============================================================

  List<Widget> _voucherList(List<Map<String, dynamic>> rows) {
    if (_loading && _rows.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (rows.isEmpty) {
      return [
        Padding(
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
                _error ?? "No vouchers found",
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ];
    }

    return [
      for (int i = 0; i < rows.length; i++) _voucherCard(rows[i], i),
    ];
  }

  Widget _voucherCard(Map<String, dynamic> r, int index) {
    final String voucher = _voucherNo(r);
    final String key = "${voucher}_$index";
    final bool open = _expanded.contains(key);

    final String customer = _customer(r);
    final String branch = _branchNameOf(r);

    final double issued = _rowMetric(r, _stages[0], "qty");
    final double returned = _rowMetric(r, _stages[1], "qty");
    final double sold = _rowMetric(r, _stages[2], "qty");
    final double pending = _rowMetric(r, _stages[3], "qty");

    final double base = issued > 0 ? issued : (returned + sold + pending);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => open ? _expanded.remove(key) : _expanded.add(key)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// VOUCHER + DATE
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryDark,
                          AppColors.secondaryDark,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long_rounded,
                        size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          voucher.isEmpty ? "-" : voucher,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _date(r),
                          style:
                          const TextStyle(fontSize: 11, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: _muted),
                  ),
                ],
              ),

              /// CUSTOMER + BRANCH
              if (customer.isNotEmpty || branch.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (customer.isNotEmpty)
                        _metaItem(Icons.person_outline_rounded, customer, _ink),
                      if (branch.isNotEmpty)
                        _metaItem(Icons.account_tree_rounded, branch,
                            _stages[1].color,
                            bold: true),
                    ],
                  ),
                ),

              const SizedBox(height: 10),

              /// STATUS BAR (returned / sold / pending)
              if (base > 0)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 6,
                    child: Row(
                      children: [
                        if (returned > 0)
                          Expanded(
                            flex: (returned * 100).round(),
                            child: Container(color: _stages[1].color),
                          ),
                        if (sold > 0)
                          Expanded(
                            flex: (sold * 100).round(),
                            child: Container(color: _stages[2].color),
                          ),
                        if (pending > 0)
                          Expanded(
                            flex: (pending * 100).round(),
                            child: Container(color: _stages[3].color),
                          ),
                        if (base - returned - sold - pending > 0.0001)
                          Expanded(
                            flex: ((base - returned - sold - pending) * 100)
                                .round(),
                            child: Container(color: _line),
                          ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 10),

              /// 4 STAGE QTY
              Row(
                children: [
                  for (int i = 0; i < _stages.length; i++) ...[
                    Expanded(
                      child: _stageQty(
                        _stages[i],
                        [issued, returned, sold, pending][i],
                        _rowMetric(r, _stages[i], "net"),
                      ),
                    ),
                    if (i != _stages.length - 1) const SizedBox(width: 6),
                  ],
                ],
              ),

              /// EXPAND — badha weights (table)
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                alignment: Alignment.topCenter,
                child: open
                    ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _weightTable(r),
                )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stageQty(_Stage st, double qty, double net) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: st.color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            st.short,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: st.color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _qty(qty),
            style: TextStyle(
              fontSize: 16,
              height: 1,
              fontWeight: FontWeight.w900,
              color: qty > 0 ? st.color : _muted,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              "${_wtFmt.format(net)} g",
              style: const TextStyle(fontSize: 9.5, color: _muted),
            ),
          ),
        ],
      ),
    );
  }

  /// Expand thay tyare: rows = Gross/Other/Net/Fine, cols = stages
  Widget _weightTable(Map r) {
    Widget cell(String t,
        {bool head = false, Color? color, TextAlign align = TextAlign.right}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment:
          align == TextAlign.left ? Alignment.centerLeft : Alignment.centerRight,
          child: Text(
            t,
            textAlign: align,
            style: TextStyle(
              fontSize: head ? 10.5 : 11,
              fontWeight: head ? FontWeight.w800 : FontWeight.w600,
              color: color ?? (head ? _muted : _ink),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _line),
      ),
      child: Table(
        columnWidths: const {0: FlexColumnWidth(1.15)},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: const TableBorder(
          horizontalInside: BorderSide(color: _line, width: 0.7),
        ),
        children: [
          TableRow(
            children: [
              cell("", head: true, align: TextAlign.left),
              for (final st in _stages)
                cell(st.short, head: true, color: st.color),
            ],
          ),
          for (final m in _metrics)
            TableRow(
              children: [
                cell(m.$2, head: true, align: TextAlign.left),
                for (final st in _stages)
                  cell(_wtFmt.format(_rowMetric(r, st, m.$1))),
              ],
            ),
        ],
      ),
    );
  }

  Widget _metaItem(IconData icon, String text, Color color,
      {bool bold = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color.withOpacity(0.8)),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color: color,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // 🔥 BRANCH REPORTS — LOAD (fakt main company admin)
  // ============================================================

  Future<void> loadBranches() async {
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
        selectedCompanyIds = {
          if (overview.mainCompany != null) overview.mainCompany!.id,
        };
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

  /// 🔥 VIEW REPORT — fakt branch URL
  Future<void> viewBranchReport() async {
    if (selectedCompanyIds.isEmpty) {
      AppMessage.error(context, "Please select at least one branch");
      return;
    }

    setState(() {
      appliedCompanyIds = selectedCompanyIds.toList();
      branchPage = 1;
      branchReportLoading = true;
    });

    try {
      await _fetch();
    } finally {
      if (mounted) setState(() => branchReportLoading = false);
    }
  }

  Future<void> clearBranchReport() async {
    setState(() {
      appliedCompanyIds = [];
      branchPage = 1;
      branchHasMore = false;
    });
    await _fetch();
  }

  // ============================================================
  // 🔥 BRANCH REPORTS (expand tab)
  // ============================================================

  Widget branchReportWidget() {
    if (branchesLoading) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(),
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
            Text(
              "Loading branches...",
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    if (!canViewBranches) return const SizedBox.shrink();

    final selectedList =
    branchCompanies.where((c) => selectedCompanyIds.contains(c.id)).toList();

    final bool appliedDiffers = appliedCompanyIds.toSet().length !=
        selectedCompanyIds.length ||
        !appliedCompanyIds.toSet().containsAll(selectedCompanyIds);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---------------- HEADER (tap = expand) ----------------
          InkWell(
            onTap: () => setState(() => branchExpanded = !branchExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryDark,
                          AppColors.secondaryDark,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.account_tree_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
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
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.primaryDark,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ---------------- BODY ----------------
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
                  // Multi select box
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
                                ? Padding(
                              padding: const EdgeInsets.only(
                                  left: 4),
                              child: Text(
                                "Select branches",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
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
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.primaryDark,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    "Select one or more branches to combine their report data.",
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 10),

                  _viewReportButton(highlight: appliedDiffers),

                  // Branch report chalu hoy tyare info + clear
                  if (branchMode) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                      decoration: BoxDecoration(
                        color: const Color(0xff16A34A).withOpacity(0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xff16A34A).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 15,
                            color: Color(0xff16A34A),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Showing combined report of "
                                  "${appliedCompanyIds.length} "
                                  "${appliedCompanyIds.length == 1 ? 'branch' : 'branches'}",
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xff166534),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: clearBranchReport,
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
          Icon(
            c.isMain ? Icons.verified_rounded : c.type.icon,
            size: 13,
            color: AppColors.primaryDark,
          ),
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
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewReportButton({required bool highlight}) {
    return InkWell(
      onTap: branchReportLoading ? null : viewBranchReport,
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
              color: const Color(0xff16A34A).withOpacity(highlight ? 0.35 : 0.15),
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
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.analytics_rounded, size: 17, color: Colors.white),
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
                                color: Color(0xff172033),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setSheet(() {
                                if (allSelected) {
                                  temp.clear();
                                } else {
                                  temp.addAll(branchCompanies.map((c) => c.id));
                                }
                              });
                            },
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
                                horizontal: 16,
                                vertical: 10,
                              ),
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
                                            color: Color(0xff172033),
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
                                                ? Colors.grey.shade600
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
                                        ? const Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    )
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
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primaryDark,
                                      AppColors.secondaryDark,
                                    ],
                                  ),
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

  /// Branch report ni next page
  Widget _loadMoreButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: InkWell(
        onTap: branchLoadingMore
            ? null
            : _loadMore,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primaryDark.withOpacity(0.3)),
          ),
          child: Center(
            child: branchLoadingMore
                ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryDark,
              ),
            )
                : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: 4),
                Text(
                  "Load More (${_rows.length}${_totalVouchers != null ? " / $_totalVouchers" : ""} loaded)",
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.primaryDark.withOpacity(0.12)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.035),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }
}
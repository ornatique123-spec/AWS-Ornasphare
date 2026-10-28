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
/// 📋 APPROVAL & RETURN REGISTER
///
/// Normal  : GET reports/approval-return-register
///           ?columns=voucher_no,date,type,approval_voucher_no,customer,
///                    branch,qty_pcs,gross_weight,other_weight,net_weight,
///                    fine_weight,amount,pending_qty
///           (Filter pachhi: &from_date=&to_date=&customer_id=
///                           &voucher_no=&entry_type=)
/// Branch  : GET company/branch-reports/approval-return-register
///           ?report_branches=slug1,slug2&per_page=25   (View Report)
///
/// Branch Reports tab fakt MAIN COMPANY ADMIN ne j dekhay.
/// ================================================================

class ApprovalReturnRegisterScreen extends StatefulWidget {
  const ApprovalReturnRegisterScreen({super.key});

  @override
  State<ApprovalReturnRegisterScreen> createState() =>
      _ApprovalReturnRegisterScreenState();
}

class _ApprovalReturnRegisterScreenState
    extends State<ApprovalReturnRegisterScreen> {
  // ============================================================
  // 🔧 API URLS — backend pramane jarur pade to badlo
  // ============================================================

  /// 🔥 Normal report na shakya path — pehlo je "Route not found"
  /// na aape e vaparay ane yaad rahe. Sacho path khabar pade to
  /// fakt e j ek line rakho (pehla mukho).
  static const List<String> _normalPaths = [
    "reports/approval-return-register",
  ];

  /// Je path chalyo e (app chalu hoy tya sudhi yaad)
  static String? _workingPath;

  static String get _normalUrl =>
      "${ApiConstants.baseUrl}${_workingPath ?? _normalPaths.first}";

  static String get _branchUrl =>
      "${ApiConstants.baseUrl}company/branch-reports/approval-return-register";

  /// Export: reports/approval-return-register?export=pdf (CSV mate ?export=csv)
  static String _exportUrl(String type) => _normalUrl;

  // ============================================================
  // COLORS
  // ============================================================

  static const Color _ink = Color(0xff172033);
  static const Color _muted = Color(0xff7A8194);
  static const Color _line = Color(0xffE3E7F0);
  static const Color _bg = Color(0xffF5F7FB);

  static const Color _apprColor = Color(0xff6D4AFF);
  static const Color _retColor = Color(0xff16A34A);
  static const Color _saleColor = Color(0xff2563EB);
  static const Color _pendColor = Color(0xffE08A00);

  // ============================================================
  // ENTRY TYPE (value API mate, label screen mate)
  // ============================================================

  /// API na "entry_types" pramane (value = label)
  static const Map<String, String> _entryTypes = {
    "": "All types",
    "Approval": "Approval",
    "Approval Return": "Approval Return",
    "Sale from Approval": "Sale from Approval",
  };

  // ============================================================
  // 🔥 REPORT COLUMNS — ek j jagyae (kram = card no kram)
  // ============================================================

  static const List<Map<String, String>> reportColumns = [
    {"label": "Date", "key": "date"},
    {"label": "Type", "key": "type"},
    {"label": "Voucher", "key": "voucher_no"},
    {"label": "Approval Voucher", "key": "approval_voucher_no"},
    {"label": "Customer", "key": "customer"},
    {"label": "Branch", "key": "branch"},
    {"label": "Qty", "key": "qty_pcs"},
    {"label": "Gross Wt", "key": "gross_weight"},
    {"label": "Other Wt", "key": "other_weight"},
    {"label": "Net Wt", "key": "net_weight"},
    {"label": "Fine Wt", "key": "fine_weight"},
    {"label": "Amount", "key": "amount"},
    {"label": "Pending Qty", "key": "pending_qty"},
  ];

  /// Voucher hamesha (band nahi thay)
  static const String _fixedColumn = "Voucher";

  /// Card ni niche na number box ma aavta columns
  static const List<String> _numberKeys = [
    "qty_pcs",
    "gross_weight",
    "other_weight",
    "net_weight",
    "fine_weight",
    "pending_qty",
  ];

  Map<String, bool> columnVisibility = {
    for (final c in reportColumns) c["label"]!: true,
  };

  bool columnsExpanded = false;
  bool columnsLoading = false;

  // ============================================================
  // FILTERS
  // ============================================================

  String? selectedCustomerId;
  String? selectedCustomerName;
  DateTime? fromDate;
  DateTime? toDate;
  String entryType = "";
  final TextEditingController voucherCtrl = TextEditingController();

  /// Filter dabavya pachhi j date/customer/voucher API ma jay
  bool filterApplied = false;

  /// ⚠️ Server filter sathe "Route not found" aape → filter vagar
  /// moṭa page lavi app ma j filter (aa request mate)
  bool _localOnly = false;

  /// Customer param na shakya naam — server je sweekare e yaad rahe
  static const List<String> _custParams = ["customer_id", "customer", "party_id"];
  static int _custParamIdx = 0;
  int _custTry = 0; // aa request ma kayu naam
  static const int _localPerPage = 500;

  // ============================================================
  // DATA
  // ============================================================

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic>? _serverSummary;

  /// Server parthi kul entries (data.rows.total)
  int? _totalEntries;
  bool totalsExpanded = true;

  final TextEditingController searchCtrl = TextEditingController();

  String? _exporting;

  final DateFormat _apiDate = DateFormat("yyyy-MM-dd");
  final DateFormat _uiDate = DateFormat("dd MMM yyyy");
  final NumberFormat _wtFmt = NumberFormat("#,##0.000");
  final NumberFormat _amtFmt = NumberFormat("#,##0.00");

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

  /// 👥 Branch merge → pasand kareli badhi branch na customer
  List<Map<String, dynamic>> _branchCustomers = [];
  bool _branchCustLoading = false;

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
  // URL — NORMAL (Sale Summary jevu)
  // ============================================================

  /// 🔥 columns=voucher_no,date,type,... (Sale Summary jevu)
  /// Voucher hamesha pehlo, pachhi je tick hoy e screen na kram ma
  List<String> getSelectedColumns() => [
    "voucher_no",
    ...reportColumns
        .where((c) =>
    c["label"] != _fixedColumn &&
        columnVisibility[c["label"]] == true)
        .map((c) => c["key"]!),
  ];

  /// 🔎 Fakt filter (customer / date / voucher / type) — normal ane
  /// branch banne report ma e j jay
  Map<String, String> _filterParams() {
    final Map<String, String> q = {};
    if (!filterApplied || _localOnly) return q;
    if (fromDate != null) q["from_date"] = _apiDate.format(fromDate!);
    if (toDate != null) q["to_date"] = _apiDate.format(toDate!);
    if (selectedCustomerId != null && selectedCustomerId!.isNotEmpty) {
      q[_custParams[_custTry % _custParams.length]] = selectedCustomerId!;
    }
    if (voucherCtrl.text.trim().isNotEmpty) {
      q["voucher_no"] = voucherCtrl.text.trim();
    }
    if (entryType.isNotEmpty) q["entry_type"] = entryType;
    return q;
  }

  Map<String, String> _filterQuery({int page = 1}) {
    return {
      "columns": getSelectedColumns().join(","),
      "per_page": "${_localOnly ? _localPerPage : branchPerPage}",
      if (page > 1) "page": "$page",
      ..._filterParams(),
    };
  }

  /// "&from_date=..&customer_id=.." (branch URL mate)
  String get _filterSuffix => _filterParams()
      .entries
      .map((e) => "&${e.key}=${Uri.encodeQueryComponent(e.value)}")
      .join();

  String buildReportUrl([String? path, int page = 1]) =>
      Uri.parse(path == null ? _normalUrl : "${ApiConstants.baseUrl}$path")
          .replace(queryParameters: _filterQuery(page: page))
          .toString();

  static bool _isRouteNotFound(dynamic statusCode, dynamic body) =>
      body is Map &&
          (body["code"] == "ROUTE_NOT_FOUND" ||
              (statusCode == 404 &&
                  body["message"]?.toString().toLowerCase() == "route not found."));

  // ============================================================
  // URL — BRANCH (fakt aa j)
  // ============================================================

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
        "&per_page=${_localOnly ? _localPerPage : branchPerPage}"
        "$_filterSuffix"; // 🔎 customer / date / voucher / type

    if (page > 1) {
      url += "&page=$page&start=${(page - 1) * branchPerPage}";
    }
    return url;
  }

  // ============================================================
  // API
  // ============================================================

  /// Load More — normal ane branch banne mate
  Future<void> _loadMore() async {
    if (branchMode) {
      await _loadBranchReport(loadMore: true);
    } else {
      await _fetch(loadMore: true);
    }
  }

  Future<void> _fetch({bool loadMore = false}) async {
    if (branchMode) {
      await _loadBranchReport(loadMore: loadMore);
      return;
    }

    final int page = loadMore ? branchPage + 1 : 1;

    setState(() {
      if (loadMore) {
        branchLoadingMore = true;
      } else {
        _loading = true;
        _error = null;
      }
    });

    try {
      // Path pehla mali gayo hoy to e j; nahi to ek pachhi ek try
      final List<String> paths =
      _workingPath != null ? [_workingPath!] : _normalPaths;

      dynamic response;
      dynamic body;

      for (final path in paths) {
        final String url = buildReportUrl(path, page);
        debugPrint("🔥 APPROVAL RETURN REGISTER API: $url");

        response = await ApiHelper().getRequest(url, showLoading: !loadMore);
        body = response?.data;

        if (_isRouteNotFound(response?.statusCode, body)) {
          debugPrint("⚠️ Route not found: $path — next try");
          continue;
        }

        _workingPath = path;
        debugPrint("✅ Register path: $path");
        break;
      }

      if (!mounted) return;

      // ⚠️ Filter sathe "Route not found" → filter vagar lavo, app ma filter
      if ((_isRouteNotFound(response?.statusCode, body) ||
          response?.statusCode == 404) &&
          filterApplied &&
          !_localOnly) {
        _workingPath = null;
        // 1) Customer param nu biju naam try (customer / party_id)
        if (selectedCustomerId != null &&
            _custTry < _custParamIdx + _custParams.length - 1) {
          _custTry++;
          debugPrint("⚠️ Customer param try: ${_custParams[_custTry % _custParams.length]}");
          await _fetch(loadMore: loadMore);
          return;
        }
        // 2) Koi na chale → filter vagar lavi app ma filter
        debugPrint("⚠️ Server filter not supported → app filter");
        _localOnly = true;
        await _fetch(loadMore: loadMore);
        return;
      }

      // ✅ Chalyu → aa customer param naam yaad
      if (response?.statusCode == 200 && filterApplied && !_localOnly) {
        _custParamIdx = _custTry % _custParams.length;
      }

      if (response?.statusCode == 200 && body is Map) {
        final List<Map<String, dynamic>> rows = _parseRows(body);
        setState(() {
          _rows = loadMore ? [..._rows, ...rows] : rows;
          if (!loadMore) _serverSummary = _localOnly ? null : _parseSummary(body);
          _totalEntries = _localOnly ? null : _parseTotal(body);
          branchPage = page;
          branchHasMore = _hasMorePages(body, page, rows.length);
        });
        debugPrint("✅ Register rows: ${_rows.length}");
      } else if (!loadMore) {
        setState(() {
          _rows = [];
          _serverSummary = null;
          _error = _isRouteNotFound(response?.statusCode, body)
              ? "Report API not found on server (check path in _normalPaths)"
              : body is Map && body["message"] != null
              ? body["message"].toString()
              : "Could not load the report";
        });
      }
    } catch (e) {
      debugPrint("❌ Register API error: $e");
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

  int? _parseTotal(Map body) {
    final dynamic data = body["data"];
    final dynamic p = data is Map && data["rows"] is Map ? data["rows"] : null;
    return int.tryParse(
        "${(p is Map ? p["total"] : null) ?? body["recordsFiltered"] ?? body["recordsTotal"] ?? ""}");
  }

  /// Laravel paginator (data.rows) / DataTables — vadhu page chhe?
  bool _hasMorePages(Map body, int page, int got) {
    final dynamic data = body["data"];
    final dynamic p = data is Map && data["rows"] is Map ? data["rows"] : data;

    if (p is Map) {
      final int last = int.tryParse("${p["last_page"] ?? ""}") ?? 0;
      if (last > 0) return page < last;
      if (p.containsKey("next_page_url")) return p["next_page_url"] != null;
    }

    final int? total = int.tryParse(
        "${body["recordsFiltered"] ?? body["recordsTotal"] ?? ""}");
    if (total != null) return _rows.length < total && got > 0;

    return got >= branchPerPage;
  }

  Future<void> _loadBranchReport({bool loadMore = false}) async {
    final int page = loadMore ? branchPage + 1 : 1;
    final String url = buildBranchReportUrl(page);

    debugPrint("🔥 BRANCH APPROVAL RETURN REGISTER API: $url");

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

      // ⚠️ Filter sathe "Route not found" → filter vagar lavo, app ma filter
      if ((_isRouteNotFound(response?.statusCode, body) ||
          response?.statusCode == 404) &&
          filterApplied &&
          !_localOnly) {
        if (selectedCustomerId != null &&
            _custTry < _custParamIdx + _custParams.length - 1) {
          _custTry++;
          await _loadBranchReport(loadMore: loadMore);
          return;
        }
        debugPrint("⚠️ Branch filter not supported → app filter");
        _localOnly = true;
        await _loadBranchReport(loadMore: loadMore);
        return;
      }

      if (response?.statusCode == 200 && body is Map) {
        final List<Map<String, dynamic>> rows = _parseRows(body);

        setState(() {
          _rows = loadMore ? [..._rows, ...rows] : rows;
          if (!loadMore) _serverSummary = _parseSummary(body);
          _totalEntries = _parseTotal(body);
          branchPage = page;
          branchHasMore = _hasMorePages(body, page, rows.length);
        });
      } else {
        final String msg = body is Map && body["message"] != null
            ? body["message"].toString()
            : "Failed to load branch report";
        AppMessage.error(context, msg);
        if (!loadMore) {
          setState(() {
            _rows = [];
            _serverSummary = null;
            _error = msg;
            branchHasMore = false;
          });
        }
      }
    } catch (e) {
      debugPrint("❌ Branch register error: $e");
      if (mounted) AppMessage.error(context, "Failed to load branch report");
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

  List<Map<String, dynamic>> _parseRows(Map body) {
    final dynamic data = body["data"];
    List raw = [];
    if (data is List) {
      raw = data;
    } else if (data is Map) {
      // 🔥 Aa API: data.rows = Laravel paginator → data.rows.data
      final dynamic rowsObj = data["rows"];
      if (rowsObj is Map && rowsObj["data"] is List) {
        raw = rowsObj["data"];
      } else {
        final inner = data["data"] ?? rowsObj ?? data["items"];
        if (inner is List) raw = inner;
      }
    } else if (body["rows"] is List) {
      raw = body["rows"];
    }
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Map<String, dynamic>? _parseSummary(Map body) {
    final dynamic data = body["data"];
    dynamic s = data is Map ? (data["totals"] ?? data["summary"]) : null;
    s ??= body["totals"] ?? body["summary"];
    return s is Map ? Map<String, dynamic>.from(s) : null;
  }

  // ============================================================
  // FIELD VALUES
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

  dynamic _raw(Map r, String key) {
    switch (key) {
      case "date":
        return r["entry_date"] ?? r["date"] ?? r["voucher_date"];
      case "type":
        return r["entry_type"] ?? r["type_label"] ?? r["type"];
      case "voucher_no":
        return r["voucher_no"] ?? r["voucher"];
      case "approval_voucher_no":
        return r["approval_no"] ??
            r["approval_voucher_no"] ??
            r["approval_voucher"];
      case "customer":
        return r["customer_name"] ?? r["customer"];
      case "qty":
      case "qty_pcs":
        return r["qty_pcs"] ?? r["qty"] ?? r["pcs"];
      case "pending_qty":
        return r["pending_qty"] ?? r["pending_pcs"];
      case "amount":
        return r["amount"] ?? r["total_amount"] ?? r["net_total"];
      case "gross_weight":
        return r["gross"] ?? r["gross_weight"];
      case "other_weight":
        return r["other"] ?? r["other_weight"];
      case "net_weight":
        return r["net"] ?? r["net_weight"];
      case "fine_weight":
        return r["fine"] ?? r["fine_weight"];
      default:
        return r[key];
    }
  }

  String _branchNameOf(Map r) {
    final int? companyId = int.tryParse("${r["company_id"] ?? ""}");
    if (companyId != null) {
      for (final c in branchCompanies) {
        if (c.id == companyId) return c.name;
      }
    }
    return _str(r["branch_name"] ?? r["branch"] ?? r["company_name"] ?? r["company"]);
  }

  String _date(Map r) {
    final String s = _str(_raw(r, "date"));
    final DateTime? d = DateTime.tryParse(s);
    return d == null ? (s.isEmpty ? "-" : s) : DateFormat("dd-MM-yyyy").format(d);
  }

  /// "approval_return" → "Approval Return"
  String _typeLabel(Map r) {
    final String t = _str(_raw(r, "type"));
    if (t.isEmpty) return "-";
    if (_entryTypes[t] != null && t.isNotEmpty) return _entryTypes[t]!;
    return t
        .replaceAll("_", " ")
        .split(" ")
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(" ");
  }

  /// 0 = approval, 1 = return, 2 = sale
  int _kind(Map r) {
    final String t = _str(_raw(r, "type")).toLowerCase();
    if (t.contains("return")) return 1;
    if (t.contains("sale")) return 2;
    return 0;
  }

  Color _kindColor(int k) =>
      k == 1 ? _retColor : (k == 2 ? _saleColor : _apprColor);

  String _fmtNumber(String key, double v) {
    if (key == "qty" || key == "qty_pcs" || key == "pending_qty") {
      return v.toStringAsFixed(0);
    }
    if (key == "amount") return _amtFmt.format(v);
    return _wtFmt.format(v);
  }

  bool _visible(String label) =>
      label == _fixedColumn || columnVisibility[label] == true;

  // ============================================================
  // SEARCH (app ma j)
  // ============================================================

  /// 🔎 Filter app ma pan — API koi filter na gane to pan sachu dekhay
  bool _passFilter(Map r) {
    if (!filterApplied) return true;

    // Customer
    if (selectedCustomerId != null && selectedCustomerId!.isNotEmpty) {
      final String cid = _str(r["customer_id"] ??
          (r["customer"] is Map ? r["customer"]["id"] : null));
      if (cid.isNotEmpty) {
        if (cid != selectedCustomerId) return false;
      } else if ((selectedCustomerName ?? "").isNotEmpty) {
        final String name = _str(_raw(r, "customer")).toLowerCase().trim();
        if (name.isNotEmpty &&
            name != selectedCustomerName!.toLowerCase().trim()) {
          return false;
        }
      }
    }

    // Date
    if (fromDate != null || toDate != null) {
      final DateTime? d = _rowDate(r);
      if (d != null) {
        final DateTime day = DateTime(d.year, d.month, d.day);
        if (fromDate != null &&
            day.isBefore(DateTime(fromDate!.year, fromDate!.month, fromDate!.day))) {
          return false;
        }
        if (toDate != null &&
            day.isAfter(DateTime(toDate!.year, toDate!.month, toDate!.day))) {
          return false;
        }
      }
    }

    // Voucher
    final String v = voucherCtrl.text.trim().toLowerCase();
    if (v.isNotEmpty) {
      final String text = "${_str(_raw(r, "voucher_no"))} "
          "${_str(_raw(r, "approval_voucher_no"))}"
          .toLowerCase();
      if (!text.contains(v)) return false;
    }

    // Entry type
    if (entryType.isNotEmpty) {
      final int want = entryType == "Approval Return"
          ? 1
          : (entryType == "Sale from Approval" ? 2 : 0);
      if (_kind(r) != want) return false;
    }
    return true;
  }

  /// Row ni tarikh (yyyy-MM-dd / dd-MM-yyyy / dd/MM/yyyy)
  DateTime? _rowDate(Map r) {
    final String s = _str(_raw(r, "date"));
    if (s.isEmpty) return null;
    final DateTime? iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    for (final f in ["dd-MM-yyyy", "dd/MM/yyyy", "dd MMM yyyy", "dd-MM-yyyy HH:mm"]) {
      try {
        return DateFormat(f).parseStrict(s);
      } catch (_) {}
    }
    return null;
  }

  List<Map<String, dynamic>> get _filteredRows {
    final String q = searchCtrl.text.trim().toLowerCase();
    final List<Map<String, dynamic>> base =
    filterApplied ? _rows.where(_passFilter).toList() : _rows;
    if (q.isEmpty) return base;
    return base.where((r) {
      final String text = [
        _str(_raw(r, "voucher_no")),
        _str(_raw(r, "approval_voucher_no")),
        _str(_raw(r, "customer")),
        _branchNameOf(r),
        _typeLabel(r),
      ].join(" ").toLowerCase();
      return text.contains(q);
    }).toList();
  }

  // ============================================================
  // TOTALS — server summary hoy to e, nahi to rows parthi
  // ============================================================

  static const List<String> _totalKeys = [
    "qty",
    "gross_weight",
    "other_weight",
    "net_weight",
    "fine_weight",
    "amount",
  ];

  Map<String, double> _sectionFromServer(List<String> names) {
    final s = _serverSummary;
    if (s == null) return {};
    for (final n in names) {
      final dynamic sec = s[n];
      if (sec is Map) {
        const Map<String, String> short = {
          "gross_weight": "gross",
          "other_weight": "other",
          "net_weight": "net",
          "fine_weight": "fine",
        };
        return {
          for (final k in _totalKeys)
            k: _num(sec[k] ??
                sec[short[k]] ??
                (k == "qty" ? sec["qty_pcs"] : null) ??
                (k == "amount" ? sec["total_amount"] : null)),
        };
      }
    }
    return {};
  }

  Map<String, double> _sectionFromRows(int kind) {
    final Map<String, double> t = {for (final k in _totalKeys) k: 0};
    final Iterable<Map<String, dynamic>> src =
    filterApplied ? _rows.where(_passFilter) : _rows;
    for (final r in src.where((r) => _kind(r) == kind)) {
      for (final k in _totalKeys) {
        t[k] = t[k]! + _num(_raw(r, k));
      }
    }
    return t;
  }

  List<({String title, Color color, Map<String, double> values})>
  get _totalSections {
    Map<String, double> pick(List<String> names, int kind) {
      final fromServer = _sectionFromServer(names);
      return fromServer.isNotEmpty ? fromServer : _sectionFromRows(kind);
    }

    final pendingServer = _sectionFromServer([
      "Pending Approval (current)",
      "Pending Approval",
      "pending_approval",
      "pending",
    ]);

    final Map<String, double> pending = pendingServer.isNotEmpty
        ? pendingServer
        : {
      for (final k in _totalKeys) k: 0,
      "qty": (filterApplied ? _rows.where(_passFilter) : _rows).fold<double>(
          0, (s, r) => s + _num(_raw(r, "pending_qty"))),
    };

    return [
      (
      title: "Approval",
      color: _apprColor,
      values: pick(["Approval", "approval"], 0),
      ),
      (
      title: "Approval Return",
      color: _retColor,
      values: pick(["Approval Return", "approval_return"], 1),
      ),
      (
      title: "Sale from Approval",
      color: _saleColor,
      values: pick(["Sale from Approval", "sale_from_approval"], 2),
      ),
      (title: "Pending Approval", color: _pendColor, values: pending),
    ];
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  /// "Filter" — pela jevo normal report (branch report bandh)
  Future<void> applyFilter() async {
    if (fromDate != null && toDate != null && fromDate!.isAfter(toDate!)) {
      AppMessage.error(context, "From Date cannot be greater than To Date");
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      filterApplied = true;
      _localOnly = false; // pehla server filter try
      _custTry = _custParamIdx; // je naam chalyu hatu e thi sharu
      branchHasMore = false;
      branchPage = 1;
      // 🔥 Branch report chalu hoy to e j branch ma filter (bandh nahi)
    });
    await _fetch();
  }

  Future<void> resetFilters() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      selectedCustomerId = null;
      selectedCustomerName = null;
      fromDate = null;
      toDate = null;
      entryType = "";
      voucherCtrl.clear();
      searchCtrl.clear();
      filterApplied = false;
      _localOnly = false;
      appliedCompanyIds = [];
      _branchCustomers = [];
      branchHasMore = false;
    });
    await _fetch();
  }

  Future<void> _pickDate(bool isFrom) async {
    final DateTime initial = (isFrom ? fromDate : toDate) ?? DateTime.now();
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (d == null) return;
    setState(() => isFrom ? fromDate = d : toDate = d);
    // 🔎 Tarikh pasand kari → turant search (banne tarikh sachi hoy to)
    if (fromDate == null || toDate == null || !fromDate!.isAfter(toDate!)) {
      await applyFilter();
    } else {
      AppMessage.error(context, "From Date cannot be greater than To Date");
    }
  }

  Future<void> _toggleColumn(String label) async {
    if (label == _fixedColumn || columnsLoading) return;
    setState(() {
      columnVisibility[label] = !(columnVisibility[label] ?? false);
    });

    // Normal report ma columns API ma jay chhe — farithi load
    if (!branchMode) {
      setState(() => columnsLoading = true);
      await _fetch();
      if (mounted) setState(() => columnsLoading = false);
    }
  }

  // ============================================================
  // EXPORT (CSV / PDF)
  // ============================================================

  Future<void> _export(String type) async {
    if (_exporting != null) return;

    setState(() => _exporting = type);

    final String url;
    if (branchMode) {
      // 🔥 Branch merge report:
      // company/branch-reports/approval-return-register
      //   ?report_branches=slug1,slug2&export=pdf
      // (Comma encode na thay etle URL hathe banaviye)
      final String branches =
      _appliedBranchSlugs.map(Uri.encodeQueryComponent).join(",");
      url = "$_branchUrl?report_branches=$branches&export=$type$_filterSuffix";
    } else {
      // 🔥 reports/approval-return-register?export=pdf
      // (+ columns ane filter hoy to e pan; per_page / page nahi)
      final Map<String, String> q = {
        "export": type,
        ..._filterQuery()..remove("per_page")..remove("page"),
      };
      url = Uri.parse(_exportUrl(type))
          .replace(queryParameters: q)
          .toString();
    }
    debugPrint("🔥 REGISTER EXPORT: $url");

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
        "${dir.path}/Approval_Return_Register_$stamp.${type == "pdf" ? "pdf" : "csv"}",
      );
      await file.writeAsBytes(data, flush: true);
      await OpenFile.open(file.path);
    } catch (e) {
      debugPrint("❌ Register export error: $e");
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
    final List<Map<String, dynamic>> rows = _filteredRows;

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
                  padding: const EdgeInsets.only(bottom: 20),
                  children: [
                    branchReportWidget(),
                    _filterCard(),
                    _totalsSection(),
                    _columnsCard(),
                    _searchBox(),
                    ..._entries(rows),
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
                  "Approval & Return Register",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Approval issues, returns and sales",
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
          /// CUSTOMER
          Consumer<ItemProvider>(
            builder: (context, provider, _) {
              // 👥 Branch merge hoy to badhi branch na customer, nahi to potana
              final bool useBranch = branchMode && _branchCustomers.isNotEmpty;
              final List<Map<String, dynamic>> customers = useBranch
                  ? _branchCustomers
                  : provider.customers
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
                hint: branchMode && _branchCustLoading
                    ? "Loading branch customers..."
                    : (useBranch ? "All Customers (all branches)" : "All Customers"),
                items: customers,
                value: selected,
                prefixIcon: Icons.person_outline_rounded,
                itemLabel: (c) {
                  final String n = c["name"]?.toString() ?? "-";
                  if (!useBranch) return n;
                  final String b = _custBranch(c);
                  return b.isEmpty ? n : "$n  •  $b";
                },
                searchText: (c) => [
                  c["name"]?.toString() ?? "",
                  c["mobile_no"]?.toString() ?? "",
                  c["email"]?.toString() ?? "",
                  if (useBranch) _custBranch(c),
                ].join(" "),
                onChanged: (c) {
                  setState(() {
                    selectedCustomerId = c?["id"]?.toString();
                    selectedCustomerName = c?["name"]?.toString();
                  });
                  applyFilter(); // 🔎 customer pasand → turant search
                },
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

          /// ENTRY TYPE
          const Padding(
            padding: EdgeInsets.only(top: 10, bottom: 6),
            child: Text(
              "Entry type",
              style: TextStyle(
                fontSize: 11.5,
                color: _muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _entryTypes.entries.map((e) {
                final bool sel = e.key == entryType;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(e.key == "Sale from Approval" ? "Sale" : e.value),
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
                    onSelected: (_) {
                      setState(() => entryType = e.key);
                      applyFilter(); // 🔎 type pasand → turant search
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          /// FILTER + RESET
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

          /// EXPORT
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
      prefixIcon:
      icon == null ? null : Icon(icon, size: 19, color: AppColors.primaryDark),
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
  // TOTALS (swipe cards)
  // ============================================================

  Widget _totalsSection() {
    if (_rows.isEmpty && _serverSummary == null) return const SizedBox.shrink();

    final sections = _totalSections;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => totalsExpanded = !totalsExpanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                Text(
                  "Totals",
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                const Spacer(),
                Text(
                  totalsExpanded ? "Hide" : "Show",
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
                AnimatedRotation(
                  turns: totalsExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 20, color: _muted),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          alignment: Alignment.topCenter,
          child: !totalsExpanded
              ? const SizedBox(width: double.infinity)
              : SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
              itemCount: sections.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _totalCard(
                sections[i].title,
                sections[i].color,
                sections[i].values,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _totalCard(String title, Color color, Map<String, double> v) {
    Widget stat(String label, String key) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: _muted)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _fmtNumber(key, v[key] ?? 0),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
          ),
        ],
      ),
    );

    // ⚠️ borderRadius sathe border no rang badhe ek j hovo joie —
    // etle upar ni rangin patti alag Container thi (ClipRRect ma)
    return Container(
      width: 252,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 3, color: color),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    stat("Qty", "qty"),
                    stat("Gross Wt", "gross_weight"),
                    stat("Other Wt", "other_weight"),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    stat("Net Wt", "net_weight"),
                    stat("Fine Wt", "fine_weight"),
                    stat("Amount", "amount"),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CUSTOM COLUMNS
  // ============================================================

  Widget _columnsCard() {
    final int on = reportColumns.where((c) => _visible(c["label"]!)).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => columnsExpanded = !columnsExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
              child: Row(
                children: [
                  Icon(Icons.view_column_rounded,
                      size: 18, color: AppColors.primaryDark),
                  const SizedBox(width: 8),
                  Text(
                    "Custom Report Columns",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const Spacer(),
                  if (columnsLoading)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  Text(
                    "$on / ${reportColumns.length}",
                    style: const TextStyle(fontSize: 11.5, color: _muted),
                  ),
                  AnimatedRotation(
                    turns: columnsExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: _muted),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            alignment: Alignment.topCenter,
            child: !columnsExpanded
                ? const SizedBox(width: double.infinity)
                : Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: reportColumns.map((c) {
                  final String label = c["label"]!;
                  final bool fixed = label == _fixedColumn;
                  final bool sel = _visible(label);

                  return InkWell(
                    onTap: fixed ? null : () => _toggleColumn(label),
                    borderRadius: BorderRadius.circular(7),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel
                            ? AppColors.primaryDark.withOpacity(0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: sel
                              ? AppColors.primaryDark.withOpacity(0.3)
                              : _line,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            fixed
                                ? Icons.lock_rounded
                                : (sel
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded),
                            size: 14,
                            color: sel ? AppColors.primaryDark : _muted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight:
                              sel ? FontWeight.w600 : FontWeight.w500,
                              color: sel ? AppColors.primaryDark : _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _searchBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
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
            searchCtrl.text.isEmpty && !filterApplied
                ? "Showing ${_rows.length}${_totalEntries != null ? " of $_totalEntries" : ""} entries"
                : "Showing ${_filteredRows.length} of ${_rows.length} entries",
            style: const TextStyle(fontSize: 11.5, color: _muted),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ENTRY CARDS
  // ============================================================

  List<Widget> _entries(List<Map<String, dynamic>> rows) {
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
                _error ?? "No entries found",
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ];
    }

    return rows.map(_entryCard).toList();
  }

  Widget _entryCard(Map<String, dynamic> r) {
    final int kind = _kind(r);
    final Color kc = _kindColor(kind);

    final String voucher = _str(_raw(r, "voucher_no"));
    final String apprVoucher = _str(_raw(r, "approval_voucher_no"));
    final String customer = _str(_raw(r, "customer"));
    final String branch = _branchNameOf(r);

    final List<Map<String, String>> numberCols = reportColumns
        .where((c) => _numberKeys.contains(c["key"]) && _visible(c["label"]!))
        .toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      // ⚠️ IntrinsicHeight + LayoutBuilder vaparvathi "no size" error
      // aavti — have Stack ma patti, ane number grid Row thi
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          children: [
            /// Type rang ni patti
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 4, color: kc),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// TYPE + DATE
                  Row(
                    children: [
                      if (_visible("Type"))
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: kc.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _typeLabel(r),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: kc,
                            ),
                          ),
                        ),
                      const Spacer(),
                      if (_visible("Date"))
                        Text(
                          _date(r),
                          style:
                          const TextStyle(fontSize: 11.5, color: _muted),
                        ),
                    ],
                  ),

                  const SizedBox(height: 7),

                  /// VOUCHER + AMOUNT
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// 🔵 VOUCHER NO — tap → Voucher Details
                            InkWell(
                              onTap: voucher.isEmpty
                                  ? null
                                  : () => _openVoucherDetails(r),
                              borderRadius: BorderRadius.circular(4),
                              child: Text(
                                voucher.isEmpty ? "-" : voucher,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: _saleColor,
                                  decoration: TextDecoration.underline,
                                  decorationColor: _saleColor,
                                ),
                              ),
                            ),
                            if (_visible("Approval Voucher"))
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  "Approval: ${apprVoucher.isEmpty ? "—" : apprVoucher}",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11.5, color: _muted),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_visible("Amount"))
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _amtFmt.format(_num(_raw(r, "amount"))),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                              ),
                            ),
                            const Text(
                              "Amount",
                              style: TextStyle(fontSize: 10, color: _muted),
                            ),
                          ],
                        ),
                    ],
                  ),

                  /// CUSTOMER + BRANCH
                  if ((_visible("Customer") && customer.isNotEmpty) ||
                      (_visible("Branch") && branch.isNotEmpty))
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          if (_visible("Customer") && customer.isNotEmpty)
                            _metaItem(Icons.person_outline_rounded,
                                customer, _ink),
                          if (_visible("Branch") && branch.isNotEmpty)
                            _metaItem(Icons.account_tree_rounded, branch,
                                _retColor,
                                bold: true),
                        ],
                      ),
                    ),

                  /// NUMBERS
                  if (numberCols.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 9),
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 4),
                      decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < numberCols.length; i += 3)
                            Padding(
                              padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                              child: Row(
                                children: [
                                  for (int j = i; j < i + 3; j++)
                                    Expanded(
                                      child: j < numberCols.length
                                          ? _numberCell(r, numberCols[j])
                                          : const SizedBox.shrink(),
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
  // 🧾 VOUCHER DETAILS
  // reports/approval-return-register/{type}/{voucher_id}/details
  // ============================================================

  /// Entry type → URL na type (approval / approval-return / sale)
  String _detailsType(Map r) {
    switch (_kind(r)) {
      case 1:
        return "return";
      case 2:
        return "sale";
      default:
        return "approval";
    }
  }

  /// 🔥 Row biji company (branch) no hoy to e company — nahi to null
  Company? _otherCompanyOf(Map r) {
    if (!branchMode) return null;
    final int? companyId = int.tryParse("${r["company_id"] ?? ""}");
    if (companyId == null) return null;
    for (final c in branchCompanies) {
      if (c.id == companyId) return c.isMain ? null : c;
    }
    return null;
  }

  void _openVoucherDetails(Map r) {
    final String id =
    _str(r["voucher_id"] ?? r["id"] ?? r["approval_id"]);

    if (id.isEmpty) {
      AppMessage.error(context, "Voucher ID not found");
      return;
    }

    final Company? other = _otherCompanyOf(r);

    // Biji company no data:
    //   company/branch-report-details/{approval|return|sale}/{id}
    //   ?report_branches={slug}
    // Potani company no data: pela jevu j
    final String url = other != null
        ? "${ApiConstants.baseUrl}"
        "company/branch-report-details/${_detailsType(r)}/$id"
        "?report_branches=${Uri.encodeQueryComponent(other.slug ?? other.id.toString())}"
        : "${ApiConstants.baseUrl}"
        "reports/approval-return-register/${_detailsType(r)}/$id/details";

    debugPrint("🧾 VOUCHER DETAILS URL: $url");

    showDialog(
      context: context,
      builder: (_) => _VoucherDetailsDialog(
        url: url,
        voucherNo: _str(_raw(r, "voucher_no")),
        date: _date(r),
        customer: _str(_raw(r, "customer")),
        approvalNo: _str(_raw(r, "approval_voucher_no")),
      ),
    );
  }

  Widget _numberCell(Map r, Map<String, String> col) {
    return Column(
      children: [
        Text(
          col["label"]!,
          style: const TextStyle(fontSize: 10, color: _muted),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _fmtNumber(col["key"]!, _num(_raw(r, col["key"]!))),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
        ),
      ],
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

  /// 👥 customer_list?management_branches[]=1&management_branches[]=2
  Future<void> _loadBranchCustomers() async {
    if (appliedCompanyIds.isEmpty) {
      setState(() => _branchCustomers = []);
      return;
    }
    final String q =
    appliedCompanyIds.map((id) => "management_branches[]=$id").join("&");
    final String base = ApiConstants.customer_list;
    final String url = "$base${base.contains('?') ? '&' : '?'}$q";
    debugPrint("👥 BRANCH CUSTOMERS: $url");

    setState(() => _branchCustLoading = true);
    try {
      final res = await ApiHelper().getRequest(url, showLoading: false);
      final dynamic body = res?.data;
      List raw = [];
      if (body is Map) {
        final dynamic d = body["data"];
        if (d is List) {
          raw = d;
        } else if (d is Map && d["data"] is List) {
          raw = d["data"];
        }
      } else if (body is List) {
        raw = body;
      }
      if (!mounted) return;
      setState(() {
        _branchCustomers = raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
      debugPrint("👥 Branch customers: ${_branchCustomers.length}");
    } catch (e) {
      debugPrint("❌ Branch customers error: $e");
    } finally {
      if (mounted) setState(() => _branchCustLoading = false);
    }
  }

  /// Customer ni branch nu naam (dropdown ma dekhava)
  String _custBranch(Map c) {
    final int? id = int.tryParse("${c["company_id"] ?? ""}");
    if (id != null) {
      for (final b in branchCompanies) {
        if (b.id == id) return b.name;
      }
    }
    final dynamic b = c["branch"] ?? c["branch_name"] ?? c["company"];
    if (b is Map && b["name"] != null) return b["name"].toString();
    return _str(b ?? c["company_name"]);
  }

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

    _loadBranchCustomers(); // 👥 badhi branch na customer

    try {
      await _fetch();
    } finally {
      if (mounted) setState(() => branchReportLoading = false);
    }
  }

  Future<void> clearBranchReport() async {
    setState(() {
      appliedCompanyIds = [];
      _branchCustomers = [];
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
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
                  "Load More (${_rows.length}${_totalEntries != null ? " / $_totalEntries" : ""} loaded)",
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


/// ================================================================
/// 🧾 VOUCHER DETAILS DIALOG — web jevu (stats + search + table)
/// ================================================================
class _VoucherDetailsDialog extends StatefulWidget {
  final String url;
  final String voucherNo;
  final String date;

  /// List na row mathi (details API ma customer naam nathi aavtu)
  final String customer;
  final String approvalNo;

  const _VoucherDetailsDialog({
    required this.url,
    required this.voucherNo,
    required this.date,
    this.customer = "",
    this.approvalNo = "",
  });

  @override
  State<_VoucherDetailsDialog> createState() => _VoucherDetailsDialogState();
}

class _VoucherDetailsDialogState extends State<_VoucherDetailsDialog> {
  static const Color _ink = Color(0xff172033);
  static const Color _muted = Color(0xff7A8194);
  static const Color _line = Color(0xffE3E7F0);
  static const Color _bg = Color(0xffF5F7FB);

  bool _loading = true;
  String? _error;

  String _voucherNo = "";
  String _date = "";
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _serverTotals;

  final TextEditingController _search = TextEditingController();
  final NumberFormat _wt = NumberFormat("#,##0.000");
  final NumberFormat _amt = NumberFormat("#,##0.00");

  /// Table columns: label, key, width, number?
  static const List<(String, String, double, bool)> _cols = [
    ("#", "_index", 40, false),
    ("Label", "label", 90, false),
    ("Item", "item", 110, false),
    ("Approval", "approval", 120, false),
    ("Customer", "customer", 130, false),
    ("Gross Wt", "gross", 90, true),
    ("Other Wt", "other", 85, true),
    ("Net Wt", "net", 90, true),
    ("Purity", "purity", 80, true),
    ("Fine Wt", "fine", 90, true),
    ("Amount", "amount", 95, true),
    ("Remarks", "remarks", 120, false),
  ];

  @override
  void initState() {
    super.initState();
    _voucherNo = widget.voucherNo;
    _date = widget.date;
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // ---------------- API ----------------

  Future<void> _load() async {
    try {
      final response =
      await ApiHelper().getRequest(widget.url, showLoading: false);
      final dynamic body = response?.data;

      if (!mounted) return;

      if (response?.statusCode == 200 && body is Map) {
        final dynamic data = body["data"] ?? body;

        // ---- items ----
        List raw = [];
        if (data is Map && data["lines"] is List) {
          // 🔥 Aa API: data.lines[] = { source, approval, amount }
          raw = (data["lines"] as List)
              .whereType<Map>()
              .map((l) => _flattenLine(l, data))
              .toList();
        } else if (data is List) {
          raw = data;
        } else if (data is Map) {
          final dynamic it = data["items"] ??
              data["rows"] ??
              data["details"] ??
              data["data"];
          if (it is List) {
            raw = it;
          } else if (it is Map && it["data"] is List) {
            raw = it["data"];
          }
        }

        // ---- header (voucher no / date) ----
        if (data is Map) {
          final dynamic v = data["voucher"] ?? data["approval"] ?? data;
          if (v is Map) {
            final String no =
            _s(v["number"] ?? v["voucher_no"] ?? v["approval_no"]);
            if (no.isNotEmpty) _voucherNo = no;
            final String d = _fmtDate(_s(v["date"] ??
                v["entry_date"] ??
                v["approval_date"] ??
                v["voucher_date"]));
            if (d.isNotEmpty) _date = d;
          }
        }

        // ---- totals ----
        dynamic t = data is Map ? (data["totals"] ?? data["summary"]) : null;
        t ??= body["totals"];

        setState(() {
          _items = raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _serverTotals = t is Map ? Map<String, dynamic>.from(t) : null;
          _loading = false;
        });

        debugPrint("🧾 Voucher items: ${_items.length}");
      } else {
        setState(() {
          _loading = false;
          _error = body is Map && body["message"] != null
              ? body["message"].toString()
              : "Could not load voucher details";
        });
      }
    } catch (e) {
      debugPrint("❌ Voucher details error: $e");
      if (mounted) {
        setState(() {
          _loading = false;
          _error = "Could not load voucher details";
        });
      }
    }
  }

  // ---------------- LINE → TABLE ROW ----------------

  /// data.lines[] ni ek line ne table na ek row ma badle.
  /// source   = aa voucher nu item (sale / return / approval)
  /// approval = mul approval item (label, item naam, approval no)
  Map<String, dynamic> _flattenLine(Map line, Map data) {
    final Map src = line["source"] is Map ? line["source"] : line;
    final Map appr = line["approval"] is Map ? line["approval"] : src;

    final Map itemSet = appr["item_set"] is Map
        ? appr["item_set"]
        : (src["item_set"] is Map ? src["item_set"] : {});

    final Map item = appr["item"] is Map
        ? appr["item"]
        : (itemSet["item"] is Map
        ? itemSet["item"]
        : (src["item"] is Map ? src["item"] : {}));

    final Map approvalHead = appr["approval"] is Map ? appr["approval"] : {};

    // Approval voucher: approval item ma, nahi to (approval type hoy to)
    // aa j voucher no number, nahi to list row nu
    String approvalNo = _s(approvalHead["approval_no"]);
    if (approvalNo.isEmpty && _s(data["type"]).toLowerCase() == "approval") {
      approvalNo = _s(data["number"]);
    }
    if (approvalNo.isEmpty) approvalNo = widget.approvalNo;

    return {
      "label": _first([
        appr["qr_code"],
        itemSet["barcode"],
        itemSet["qr_code"],
        src["qr_code"],
        appr["huid"],
      ]),
      "item_name": _first([item["item_name"], src["item_name"]]),
      "approval_no": approvalNo,
      "customer_name": widget.customer,
      "gross": src["gross_weight"] ?? appr["gross_weight"],
      "other": src["other_weight"] ?? appr["other_weight"],
      "net": src["net_weight"] ?? appr["net_weight"],
      "purity": src["purity"] ?? appr["purity"],
      "fine": src["fine_weight"] ??
          src["total_fine_weight"] ??
          appr["total_fine_weight"],
      "amount": line["amount"] ?? src["total_amount"] ?? appr["total_amount"],
      "remarks": _first([src["remarks"], appr["remarks"]]),
      "qty": src["qty"] ?? 1,
    };
  }

  /// Pehlu khali na hoy e value
  static String _first(List values) {
    for (final v in values) {
      final String s = _s(v);
      if (s.isNotEmpty) return s;
    }
    return "";
  }

  // ---------------- HELPERS ----------------

  static String _s(dynamic v) {
    if (v == null) return "";
    if (v is Map) return (v["name"] ?? v["item_name"] ?? "").toString();
    final s = v.toString().trim();
    return s == "null" ? "" : s;
  }

  static double _n(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString().replaceAll(",", "") ?? "") ?? 0;
  }

  static String _fmtDate(String s) {
    final DateTime? d = DateTime.tryParse(s);
    // "2026-10-07T18:30:00Z" = India ma 08-10-2026 → local time
    return d == null ? s : DateFormat("dd-MM-yyyy").format(d.toLocal());
  }

  /// Item ma key alag naam thi aave to pan
  dynamic _raw(Map r, String key) {
    switch (key) {
      case "label":
        return r["label"] ?? r["label_code"] ?? r["barcode"] ?? r["code"] ?? r["qr_code"];
      case "item":
        return r["item_name"] ?? r["item"];
      case "approval":
        return r["approval_no"] ?? r["approval"] ?? r["voucher_no"];
      case "customer":
        return r["customer_name"] ?? r["customer"];
      case "gross":
        return r["gross"] ?? r["gross_weight"] ?? r["gross_wt"];
      case "other":
        return r["other"] ?? r["other_weight"] ?? r["less_weight"];
      case "net":
        return r["net"] ?? r["net_weight"] ?? r["net_wt"];
      case "fine":
        return r["fine"] ?? r["fine_weight"] ?? r["fine_wt"];
      case "amount":
        return r["amount"] ?? r["total_amount"] ?? r["net_total"];
      case "purity":
        return r["purity"] ?? r["touch"];
      default:
        return r[key];
    }
  }

  String _cell(Map r, String key, int index) {
    if (key == "_index") return "${index + 1}";
    final dynamic v = _raw(r, key);
    if (key == "amount") return _amt.format(_n(v));
    if (key == "purity") return v == null ? "-" : _n(v).toStringAsFixed(3);
    if (["gross", "other", "net", "fine"].contains(key)) {
      return _wt.format(_n(v));
    }
    final String s = _s(v);
    return s.isEmpty ? "-" : s;
  }

  List<Map<String, dynamic>> get _filtered {
    final String q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((r) {
      return "${_s(_raw(r, "label"))} ${_s(_raw(r, "item"))}"
          .toLowerCase()
          .contains(q);
    }).toList();
  }

  /// Totals — badha items na (search pramane nahi), web jevu
  double _total(String key) {
    final t = _serverTotals;
    if (t != null) {
      final dynamic v = t[key] ??
          t["${key}_weight"] ??
          (key == "qty" ? (t["quantity"] ?? t["items"]) : null);
      if (v != null) return _n(v);
    }
    if (key == "qty") {
      // line ma qty hoy to eno sarvalo, nahi to items ni sankhya
      final bool hasQty = _items.any((r) => r["qty"] != null);
      return hasQty
          ? _items.fold<double>(0, (s, r) => s + _n(r["qty"]))
          : _items.length.toDouble();
    }
    return _items.fold<double>(0, (s, r) => s + _n(_raw(r, key)));
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            /// HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 6, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Voucher Details",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: _ink),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _line),

            Flexible(
              child: _loading
                  ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
                  : _error != null
                  ? Padding(
                padding: const EdgeInsets.all(30),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted),
                ),
              )
                  : _content(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    final List<Map<String, dynamic>> rows = _filtered;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// VOUCHER | DATE | ITEMS
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12.5, color: _muted),
              children: [
                TextSpan(
                  text: _voucherNo.isEmpty ? "-" : _voucherNo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                TextSpan(text: "  |  $_date  |  ${_items.length} items"),
              ],
            ),
          ),

          const SizedBox(height: 12),

          /// STATS (2 x 2)
          Row(
            children: [
              _stat("Quantity (items)", _total("qty").toStringAsFixed(0)),
              const SizedBox(width: 8),
              _stat("Gross Wt", "${_wt.format(_total("gross"))} g"),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _stat("Other Wt", "${_wt.format(_total("other"))} g"),
              const SizedBox(width: 8),
              _stat("Net Wt", "${_wt.format(_total("net"))} g"),
            ],
          ),

          const SizedBox(height: 14),

          /// SEARCH
          const Text(
            "Search barcode / label",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 42,
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 13, color: _ink),
              decoration: InputDecoration(
                hintText: "Type or scan barcode / label",
                hintStyle: const TextStyle(color: _muted, fontSize: 13),
                prefixIcon: const Icon(Icons.qr_code_scanner_rounded,
                    size: 19, color: _muted),
                filled: true,
                fillColor: _bg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _line),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Showing ${rows.length} items. Totals above are for all voucher items.",
            style: const TextStyle(fontSize: 11, color: _muted),
          ),

          const SizedBox(height: 12),

          /// TABLE
          _table(rows),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: _muted)),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _table(List<Map<String, dynamic>> rows) {
    final double width = _cols.fold<double>(0, (s, c) => s + c.$3);

    Widget cell(String text, double w,
        {bool number = false,
          bool bold = false,
          Color color = _ink,
          bool last = false}) {
      return Container(
        width: w,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
        alignment: number ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(right: BorderSide(color: _line, width: 0.8)),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            color: color,
          ),
        ),
      );
    }

    // Header
    final Widget head = Container(
      color: AppColors.primaryDark,
      child: Row(
        children: [
          for (int i = 0; i < _cols.length; i++)
            cell(_cols[i].$1, _cols[i].$3,
                number: _cols[i].$4,
                bold: true,
                color: Colors.white,
                last: i == _cols.length - 1),
        ],
      ),
    );

    // Rows
    final List<Widget> body = [];
    for (int r = 0; r < rows.length; r++) {
      body.add(Container(
        decoration: BoxDecoration(
          color: r.isEven ? Colors.white : const Color(0xffFAFBFD),
          border: const Border(top: BorderSide(color: _line, width: 0.8)),
        ),
        child: Row(
          children: [
            for (int i = 0; i < _cols.length; i++)
              cell(_cell(rows[r], _cols[i].$2, r), _cols[i].$3,
                  number: _cols[i].$4,
                  bold: _cols[i].$2 == "label",
                  last: i == _cols.length - 1),
          ],
        ),
      ));
    }

    if (rows.isEmpty) {
      body.add(SizedBox(
        width: width,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text(
            "No items found",
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 12.5),
          ),
        ),
      ));
    }

    // Total (badha items na)
    String totalFor(String key) {
      switch (key) {
        case "gross":
        case "other":
        case "net":
        case "fine":
          return _wt.format(_total(key));
        case "amount":
          return _amt.format(_total("amount"));
        case "purity":
          return "-";
        default:
          return "";
      }
    }

    // "Total" label first 5 columns (#..Customer) ni jagya ma
    final double labelW =
    _cols.take(5).fold<double>(0, (s, c) => s + c.$3);

    final Widget total = Container(
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withOpacity(0.06),
        border: const Border(top: BorderSide(color: _line, width: 1.2)),
      ),
      child: Row(
        children: [
          cell("Total", labelW, bold: true),
          for (int i = 5; i < _cols.length; i++)
            cell(totalFor(_cols[i].$2), _cols[i].$3,
                number: _cols[i].$4,
                bold: true,
                last: i == _cols.length - 1),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [head, ...body, total],
            ),
          ),
        ),
      ),
    );
  }
}
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import 'package:pecifician_sysytem/Settings/BranchManagementScreen.dart'
    show BranchApi, Company, BranchTypeX;

import '../Extra/AppColors.dart';
import '../Extra/AppMessage.dart';
import '../Extra/ItemProvider.dart';
import '../Extra/PremiumSearchableDropdown.dart';
import 'BranchAccess.dart';
import 'WorkerLossReportScreen.dart';

/// ================================================================
/// 📒 WORKER METAL LEDGER
///
/// API: GET reports/worker-loss?mode=ledger&format=daily
///          &worker_id=61&from_date=2026-10-01&to_date=2026-10-07
///
/// Dr = worker paase metal baaki (pending)
/// Cr = vadhu malyu (excess received)
/// Opening = From Date pehla na badha vyavahar
/// ================================================================

/// ---------------------------------------------------------------
/// MODELS
/// ---------------------------------------------------------------
class _LedgerRow {
  final String date;
  final String voucher;
  final String type;
  final String item;
  final double debit;
  final double credit;
  final double balance; // + = Cr, − = Dr

  _LedgerRow({
    required this.date,
    required this.voucher,
    required this.type,
    required this.item,
    required this.debit,
    required this.credit,
    required this.balance,
  });
}

class _LedgerGroup {
  final String worker;
  final String metal;
  final double opening; // + = Cr, − = Dr
  final List<_LedgerRow> rows;
  final double totalDebit;
  final double totalCredit;
  final double closing; // + = Cr, − = Dr

  /// Branch report ma kai branch nu ledger chhe (normal ma "")
  final String branch;

  _LedgerGroup({
    required this.worker,
    required this.metal,
    required this.opening,
    required this.rows,
    required this.totalDebit,
    required this.totalCredit,
    required this.closing,
    this.branch = "",
  });
}

/// ---------------------------------------------------------------
/// PARSER — API: data.groups[] → rows[]
/// API ma balance = debit − credit  (+ = Dr, − = Cr)
/// App ma andar  + = Cr, − = Dr  → etle sign ulto karie
/// ---------------------------------------------------------------
class _LedgerParser {
  static double _d(dynamic v) => double.tryParse(v?.toString() ?? "") ?? 0;

  static String _s(dynamic v) {
    final String t = v?.toString().trim() ?? "";
    return (t.isEmpty || t == "null") ? "" : t;
  }

  /// "2026-09-30" → "30-09-2026"
  static String _date(dynamic v) {
    final String raw = _s(v);
    final DateTime? d = DateTime.tryParse(raw);
    return d == null ? (raw.isEmpty ? "-" : raw) : DateFormat("dd-MM-yyyy").format(d);
  }

  static List<_LedgerGroup> parse(
      dynamic body, {
        String Function(Map g)? branchOf,
      }) {
    if (body is! Map) return [];

    // Normal:  data.groups[]
    // Branch:  data.groups[] / data[] (groups) / data[{company_id, groups[]}]
    //          / data.{slug: {groups[]}}  — badha shape sambhaliye
    final List<Map> groups = [];

    void collect(dynamic node, [Map? parent]) {
      if (node is List) {
        for (final e in node) {
          collect(e, parent);
        }
      } else if (node is Map) {
        if (node["rows"] is List) {
          // Aa j ek group chhe — parent (branch) nu company_id aapo
          final Map g = Map.from(node);
          if (parent != null) {
            g["company_id"] ??= parent["company_id"] ?? parent["id"];
            g["branch_name"] ??= parent["branch_name"] ??
                parent["company_name"] ??
                parent["name"];
          }
          groups.add(g);
        } else if (node["groups"] is List) {
          collect(node["groups"], node);
        } else if (node["data"] != null) {
          collect(node["data"], parent);
        } else {
          // { "slug": {groups: []}, ... }
          for (final v in node.values) {
            if (v is Map || v is List) collect(v, parent);
          }
        }
      }
    }

    collect(body["data"]);
    if (groups.isEmpty) return [];

    return groups.map((g) {
      final List rows = g["rows"] is List ? g["rows"] : [];

      final dynamic wn = g["worker_name"] is Map ? g["worker_name"]["name"] : g["worker_name"];

      return _LedgerGroup(
        branch: branchOf == null ? "" : branchOf(g),
        worker: _s(wn).isEmpty ? "No Worker" : _s(wn),
        metal: _s(g["metal"]).isEmpty ? "Metal" : _s(g["metal"]),
        opening: -_d(g["opening"]),
        totalDebit: _d(g["debit"]),
        totalCredit: _d(g["credit"]),
        closing: -_d(g["closing"]),
        rows: rows.whereType<Map>().map((r) {
          final String voucher = _s(r["voucher_no"] ?? r["reference"]);
          final String item = _s(r["item_name"] ?? r["item"]);
          final String particulars = _s(r["particulars"]);

          return _LedgerRow(
            date: _date(r["date"]),
            voucher: voucher,
            // Detailed ma "type" (Issue/Receive) aave; Daily ma nathi
            type: _s(r["type"]),
            item: item.isNotEmpty ? item : (particulars.isEmpty ? "-" : particulars),
            debit: _d(r["debit"]),
            credit: _d(r["credit"]),
            balance: -_d(r["balance"]),
          );
        }).toList(),
      );
    }).toList();
  }
}

/// ================================================================
/// SCREEN
/// ================================================================
class WorkerMetalLedgerScreen extends StatefulWidget {
  const WorkerMetalLedgerScreen({super.key});

  @override
  State<WorkerMetalLedgerScreen> createState() =>
      _WorkerMetalLedgerScreenState();
}

class _WorkerMetalLedgerScreenState extends State<WorkerMetalLedgerScreen> {
  static const Color _drRed = Color(0xffC53B4E);
  static const Color _crBlue = Color(0xff2563C9);
  static const Color _muted = Color(0xff8A8F98);
  static const Color _ink = Color(0xff1C1E24);

  /// format value → label
  static const Map<String, String> _formats = {
    "daily": "Daily",
    "detailed": "Detailed Ledger",
  };

  DateTime _from = DateTime.now().subtract(const Duration(days: 6));
  DateTime _to = DateTime.now();
  String? _workerId;
  String _format = "daily";

  bool _loading = false;
  String? _error;
  List<_LedgerGroup> _groups = [];
  dynamic _rawBody; // parse na thay to batavva
  String? _exporting;

  // ============================================================
  // 🔥 BRANCH REPORTS
  // ============================================================

  /// Branch report ma ek page ma ketla record
  static const int branchPerPage = 25;

  /// Branch API mathi aavti companies (main + branches)
  List<Company> branchCompanies = [];

  /// Dropdown ma select kareli (haju apply nathi thai)
  Set<int> selectedCompanyIds = {};

  /// "View Report" dabavya pachhi apply thayeli
  List<int> appliedCompanyIds = [];

  /// Branch report chalu chhe? (true hoy to branch API vaparay)
  bool get branchMode => appliedCompanyIds.isNotEmpty;

  /// Branch report pagination
  int branchPage = 1;
  bool branchHasMore = false;
  bool branchLoadingMore = false;

  bool branchesLoading = false;
  bool canViewBranches = false;
  bool branchExpanded = true;
  bool branchReportLoading = false;


  final NumberFormat _wt = NumberFormat("#,##0.000");
  final DateFormat _apiDate = DateFormat("yyyy-MM-dd");
  final DateFormat _uiDate = DateFormat("dd MMM yyyy");

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<ItemProvider>(context, listen: false).loadJobWorker();
    });
    _fetch();

    // 🔥 Branch list (fakt main company admin ne j tab dekhashe)
    loadBranches();
  }

  /// =========================================================
  /// API
  /// =========================================================
  Map<String, String> _query() => {
    "mode": "ledger",
    "format": _format,
    if (_workerId != null) "worker_id": _workerId!,
    "from_date": _apiDate.format(_from),
    "to_date": _apiDate.format(_to),
  };

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    // 🔥 Branch report chalu hoy to fakt branch URL
    final String url = branchMode
        ? buildBranchLedgerUrl()
        : Uri.parse("${ApiConstants.baseUrl}reports/worker-loss")
        .replace(queryParameters: _query())
        .toString();

    debugPrint("${branchMode ? "🔥 BRANCH " : ""}WORKER LEDGER URL => $url");

    try {
      final response = await ApiHelper().getRequest(url);

      if (!mounted) return;

      if (response != null &&
          response.statusCode == 200 &&
          response.data is Map &&
          response.data["success"] != false) {
        _rawBody = response.data;
        _logRaw(response.data);

        final List<_LedgerGroup> groups = _LedgerParser.parse(
          response.data,
          branchOf: branchMode ? _branchNameOf : null,
        );

        setState(() => _groups = groups);
      } else {
        _rawBody = response?.data;
        setState(() {
          _groups = [];
          _error = (response?.data is Map && response?.data["message"] != null)
              ? response!.data["message"].toString()
              : "Could not load the ledger. Pull down to retry.";
        });
      }
    } catch (e, st) {
      debugPrint("WORKER LEDGER ERROR => $e\n$st");
      if (mounted) {
        setState(() => _error = "Could not load the ledger. Pull down to retry.");
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Logcat ma aakho jawab (lambo hoy to tukda ma)
  void _logRaw(dynamic data) {
    try {
      final String s = const JsonEncoder.withIndent("  ").convert(data);
      const int chunk = 800;
      for (int i = 0; i < s.length; i += chunk) {
        debugPrint(s.substring(i, i + chunk > s.length ? s.length : i + chunk));
      }
    } catch (_) {}
  }

  /// =========================================================
  /// EXPORT
  /// =========================================================
  Future<void> _export(String type) async {
    if (_exporting != null) return;

    final bool isPdf = type == "pdf";
    setState(() => _exporting = type);

    // Normal:  reports/worker-loss/export/pdf?mode=ledger&format=..&from..
    // Branch:  e j URL + &report_branches=slug1,slug2 (ke "all")
    final String url = _withBranches(
      Uri.parse("${ApiConstants.baseUrl}reports/worker-loss/export/$type")
          .replace(queryParameters: _query())
          .toString(),
    );

    debugPrint("WORKER LEDGER EXPORT branchMode=$branchMode => $url");

    try {
      final response = await ApiHelper().getPdfRequest(url);
      final dynamic data = response?.data;

      if (response == null || response.statusCode != 200 || data is! List<int> || data.isEmpty) {
        if (mounted) AppMessage.error(context, "Could not download the file");
        return;
      }

      final bool okPdf = data.length > 4 && data[0] == 0x25 && data[1] == 0x50;
      final bool okXlsx = data.length > 2 && data[0] == 0x50 && data[1] == 0x4B;
      if ((isPdf && !okPdf) || (!isPdf && !okXlsx)) {
        final String text = utf8.decode(data, allowMalformed: true);
        debugPrint("EXPORT NOT A FILE => ${text.length > 300 ? text.substring(0, 300) : text}");
        String msg = "The server did not return a valid file";
        try {
          final dynamic j = jsonDecode(text);
          if (j is Map && j["message"] != null) msg = j["message"].toString();
        } catch (_) {}
        if (mounted) AppMessage.error(context, msg);
        return;
      }

      final Directory dir = await getTemporaryDirectory();
      final String stamp = DateFormat("ddMMyyyy_HHmm").format(DateTime.now());
      final File f = File("${dir.path}/Worker_Ledger_$stamp.${isPdf ? "pdf" : "xlsx"}");
      await f.writeAsBytes(data, flush: true);
      final result = await OpenFile.open(f.path);
      if (result.type != ResultType.done && mounted) {
        AppMessage.error(
          context,
          isPdf
              ? "Unable to open PDF"
              : "No app found to open Excel. Install Excel or Google Sheets.",
        );
      }
    } catch (e) {
      debugPrint("WORKER LEDGER EXPORT ERROR => $e");
      if (mounted) AppMessage.error(context, "Could not download the file");
    } finally {
      if (mounted) setState(() => _exporting = null);
    }
  }

  /// =========================================================
  /// HELPERS
  /// =========================================================
  String _bal(double v) {
    if (v.abs() < 0.0005) return _wt.format(0);
    return "${_wt.format(v.abs())} ${v > 0 ? "Cr" : "Dr"}";
  }

  Color _balColor(double v) {
    if (v.abs() < 0.0005) return _muted;
    return v > 0 ? _crBlue : _drRed;
  }

  Future<void> _pickDate(bool isFrom) async {
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d == null) return;
    setState(() {
      if (isFrom) {
        _from = d;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = d;
        if (_from.isAfter(_to)) _from = _to;
      }
    });
  }

  /// =========================================================
  /// BUILD
  /// =========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetch,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header()),
              // 🔥 Branch Reports tab sauthi upar
              SliverToBoxAdapter(child: branchReportWidget()),
              SliverToBoxAdapter(child: _filterCard()),
              SliverToBoxAdapter(child: _legend()),
              if (_loading && _groups.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null && _groups.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _emptyState(Icons.cloud_off_rounded, _error!),
                )
              else if (_groups.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _emptyState(
                      Icons.menu_book_outlined,
                      "No ledger entries for these filters.",
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (_, i) => _groupCard(_groups[i]),
                      childCount: _groups.length,
                    ),
                  ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  /// =========================================================
  /// HEADER
  /// =========================================================
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
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
                  "Worker Metal Ledger",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Metal pending and excess, by worker",
                  style: TextStyle(fontSize: 11.5, color: _muted),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WorkerLossReportScreen()),
            ),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.trending_down_rounded,
                      size: 16, color: AppColors.primaryDark),
                  SizedBox(width: 5),
                  Text(
                    "Loss",
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// =========================================================
  /// FILTER CARD
  /// =========================================================
  Widget _filterCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// DATES
          Row(
            children: [
              _dateTile("From", _from, () => _pickDate(true)),
              const SizedBox(width: 10),
              _dateTile("To", _to, () => _pickDate(false)),
            ],
          ),

          const SizedBox(height: 12),

          /// WORKER (premium searchable + ✕)
          const Text(
            "Worker",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Consumer<ItemProvider>(
            builder: (context, provider, _) {
              final List<Map<String, dynamic>> workers = provider.Job_worker
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();

              Map<String, dynamic>? selected;
              for (final w in workers) {
                if (w["id"]?.toString() == _workerId) {
                  selected = w;
                  break;
                }
              }

              return Stack(
                alignment: Alignment.centerRight,
                children: [
                  PremiumSearchableDropdown<Map<String, dynamic>>(
                    label: "",
                    hint: "All Workers",
                    items: workers,
                    value: selected,
                    prefixIcon: Icons.person_outline_rounded,
                    itemLabel: (w) =>
                    w["name"]?.toString() ?? w["worker_name"]?.toString() ?? "-",
                    searchText: (w) => [
                      w["name"]?.toString() ?? "",
                      w["worker_name"]?.toString() ?? "",
                      w["mobile_no"]?.toString() ?? "",
                    ].join(" "),
                    onChanged: (w) {
                      setState(() => _workerId = w?["id"]?.toString());
                      // Branch report chalu hoy to e j chalu rahe
                      _fetch();
                    },
                  ),
                  if (selected != null)
                    _clearIcon(() {
                      setState(() => _workerId = null);
                      _fetch();
                    }, right: 40),
                ],
              );
            },
          ),

          const SizedBox(height: 12),

          /// FORMAT
          const Text(
            "Format",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: _formats.entries.map((e) {
                final bool sel = e.key == _format;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (sel) return;
                      setState(() => _format = e.key);
                      _fetch();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primaryDark : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        e.value,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : _muted,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          /// BUTTONS
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _gradientButton(
                  icon: Icons.filter_alt_rounded,
                  label: "Show",
                  busy: _loading,
                  onTap: _loading
                      ? null
                      : () {
                    // Branch report chalu hoy to branch sathe j load
                    _fetch();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _exportButton("pdf", "PDF",
                    Icons.picture_as_pdf_rounded, _drRed),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _exportButton("excel", "Excel",
                    Icons.grid_on_rounded, const Color(0xff1D6F42)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateTile(String label, DateTime d, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(fontSize: 10.5, color: _muted)),
                    const SizedBox(height: 2),
                    Text(
                      _uiDate.format(d),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.calendar_month_rounded,
                  size: 18, color: AppColors.primaryDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gradientButton({
    required IconData icon,
    required String label,
    required bool busy,
    required VoidCallback? onTap,
  }) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, AppColors.secondaryDark],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Center(
            child: busy
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
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

  Widget _exportButton(String type, String label, IconData icon, Color color) {
    final bool busy = _exporting == type;

    return Opacity(
      opacity: _exporting != null && !busy ? 0.5 : 1,
      child: Material(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _exporting != null ? null : () => _export(type),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.35)),
            ),
            child: Center(
              child: busy
                  ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
                  : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _legend() {
    Widget dot(Color c, String t) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(t, style: const TextStyle(fontSize: 11, color: _muted)),
      ],
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(_hPad + 2, 4, _hPad + 2, 8),
      child: Wrap(
        spacing: 14,
        runSpacing: 4,
        children: [
          dot(_drRed, "Dr: metal pending from worker"),
          dot(_crBlue, "Cr: excess received"),
          const Text(
            "Weights in grams",
            style: TextStyle(fontSize: 11, color: _muted),
          ),
        ],
      ),
    );
  }

  /// =========================================================
  /// 📐 RESPONSIVE HELPERS
  /// =========================================================
  bool get _isTablet => MediaQuery.of(context).size.width >= 600;

  /// Card ni bahar ni jagya — phone 12, tablet 20
  double get _hPad => _isTablet ? 20 : 12;

  /// =========================================================
  /// GROUP CARD (Worker — Metal) — ✨ premium + responsive
  /// =========================================================
  Widget _groupCard(_LedgerGroup g) {
    final Color cc = _balColor(g.closing);
    final bool tablet = _isTablet;

    return Center(
      child: ConstrainedBox(
        // Moṭa tablet / landscape ma card bahu pahoḍu na thay
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Container(
          margin: EdgeInsets.fromLTRB(_hPad, 0, _hPad, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primaryDark.withOpacity(0.10)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withOpacity(0.07),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                /// ---------- HEADER ----------
                Container(
                  padding: EdgeInsets.fromLTRB(
                      tablet ? 18 : 12, tablet ? 16 : 12, tablet ? 18 : 12, tablet ? 16 : 12),
                  // 🎨 Halko header — gaḍho blue fakt avatar ma
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xffDCE8FB), // light blue
                        Color(0xffF0F5FE),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: const Border(
                      bottom: BorderSide(color: Color(0xffC9DAF6)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: tablet ? 46 : 40,
                        height: tablet ? 46 : 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primaryDark, AppColors.secondaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          g.worker.isNotEmpty ? g.worker[0].toUpperCase() : "?",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: tablet ? 19 : 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      SizedBox(width: tablet ? 14 : 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              g.worker,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _ink,
                                fontSize: tablet ? 17 : 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            // Metal + branch chips — jagya na hoy to niche jay
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _headChip(Icons.diamond_outlined, g.metal),
                                if (g.branch.isNotEmpty)
                                  _headChip(Icons.account_tree_rounded, g.branch),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "Net pending",
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width *
                                  (tablet ? 0.3 : 0.38),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: cc.withOpacity(0.09),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: cc.withOpacity(0.35)),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                "${_bal(g.closing)} g",
                                style: TextStyle(
                                  color: cc,
                                  fontSize: tablet ? 15 : 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                /// ---------- SUMMARY STRIP (Opening / Dr / Cr / Closing) ----------
                _groupSummary(g),

                /// ---------- TABLE ----------
                _ledgerTable(g),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Header ma nani white chip (metal / branch)
  Widget _headChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primaryDark.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.primaryDark),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.primaryDark,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 4 nana box — phone ma 2×2, mota phone / tablet ma 1 line
  Widget _groupSummary(_LedgerGroup g) {
    final tiles = <Widget>[
      _totalTile("Opening", _bal(g.opening), _balColor(g.opening)),
      _totalTile("Total Dr", _wt.format(g.totalDebit), _drRed),
      _totalTile("Total Cr", _wt.format(g.totalCredit), _crBlue),
      _totalTile("Closing", _bal(g.closing), _balColor(g.closing), strong: true),
    ];

    return Container(
      color: const Color(0xffF5F8FE),
      padding: EdgeInsets.all(_isTablet ? 12 : 10),
      child: LayoutBuilder(builder: (context, box) {
        if (box.maxWidth < 380) {
          return Column(
            children: [
              Row(children: [tiles[0], const SizedBox(width: 8), tiles[1]]),
              const SizedBox(height: 8),
              Row(children: [tiles[2], const SizedBox(width: 8), tiles[3]]),
            ],
          );
        }
        return Row(
          children: [
            for (int i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              tiles[i],
            ],
          ],
        );
      }),
    );
  }

  /// =========================================================
  /// 📊 LEDGER TABLE — responsive
  /// Phone: horizontal scroll (swipe hint sathe)
  /// Tablet: jagya vadhu hoy to column pahoḍa thai aakhi width bhare
  /// =========================================================
  static const Color _drTint = Color(0xffFCEEF0);
  static const Color _crTint = Color(0xffEBF2FD);
  static const Color _headBg = Color(0xffE6EFFC); // light blue
  static const Color _headText = Color(0xff2F4A78);

  Widget _ledgerTable(_LedgerGroup g) {
    return LayoutBuilder(builder: (context, box) {
      // Daily ma voucher / type nathi → e column chhupavo
      final bool showVoucher = g.rows.any((r) => r.voucher.isNotEmpty);
      final bool showType = g.rows.any((r) => r.type.isNotEmpty);

      // Base width (phone mate)
      double wDate = 96, wVoucher = 108, wType = 86, wItem = 170;
      double wAmt = 108, wBal = 132;

      double total() =>
          wDate +
              (showVoucher ? wVoucher : 0) +
              (showType ? wType : 0) +
              wItem +
              wAmt * 2 +
              wBal;

      // 🔥 Jagya vadhu hoy (tablet) → badha column ek sarkha pahoḍa
      final double avail = box.maxWidth;
      final bool scrolls = total() > avail + 0.5;
      if (!scrolls) {
        final double k = avail / total();
        wDate *= k;
        wVoucher *= k;
        wType *= k;
        wItem *= k;
        wAmt *= k;
        wBal *= k;
      }

      final double tableWidth = scrolls ? total() : avail;
      // Opening / Total row ma "label" pehla column thi Item sudhi
      final double labelWidth = tableWidth - wAmt * 2 - wBal;
      final double fs = _isTablet ? 13 : 12.5;

      Widget cell(
          String text, {
            required double w,
            Color? bg,
            Color color = _ink,
            FontWeight weight = FontWeight.w500,
            TextAlign align = TextAlign.left,
            double? size,
            bool header = false,
          }) {
        return Container(
          width: w,
          color: bg,
          padding: EdgeInsets.symmetric(
              horizontal: 10, vertical: header ? 12 : (_isTablet ? 12 : 11)),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: align,
            style: TextStyle(
              fontSize: size ?? (header ? 11.5 : fs),
              fontWeight: weight,
              color: color,
              letterSpacing: header ? 0.4 : 0,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );
      }

      Color typeColor(_LedgerRow r) {
        final String t = r.type.toLowerCase();
        if (t.contains("issue")) return _drRed;
        if (t.contains("receive")) return _crBlue;
        return AppColors.primaryDark;
      }

      /// ---------- HEADER ----------
      final Widget head = Container(
        decoration: BoxDecoration(
          color: _headBg,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            cell("DATE", w: wDate, color: _headText, weight: FontWeight.w700, header: true),
            if (showVoucher)
              cell("VOUCHER", w: wVoucher, color: _headText, weight: FontWeight.w700, header: true),
            if (showType)
              cell("TYPE", w: wType, color: _headText, weight: FontWeight.w700, header: true),
            cell(showVoucher ? "ITEM" : "PARTICULARS",
                w: wItem, color: _headText, weight: FontWeight.w700, header: true),
            cell("NET DEBIT", w: wAmt, bg: _drRed.withOpacity(0.12), color: _drRed,
                weight: FontWeight.w800, align: TextAlign.right, header: true),
            cell("NET CREDIT", w: wAmt, bg: _crBlue.withOpacity(0.12), color: _crBlue,
                weight: FontWeight.w800, align: TextAlign.right, header: true),
            cell("NET BALANCE", w: wBal, color: _headText,
                weight: FontWeight.w700, align: TextAlign.right, header: true),
          ],
        ),
      );

      /// ---------- OPENING ----------
      final Widget opening = Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: labelWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                child: Row(
                  children: [
                    const Icon(Icons.login_rounded, size: 15, color: _muted),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        "Opening balance",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: fs,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            cell("—", w: wAmt, bg: _drTint, color: _muted, align: TextAlign.right),
            cell("—", w: wAmt, bg: _crTint, color: _muted, align: TextAlign.right),
            cell(_bal(g.opening), w: wBal, color: _balColor(g.opening),
                weight: FontWeight.w700, align: TextAlign.right),
          ],
        ),
      );

      /// ---------- DATA ROWS ----------
      final List<Widget> rows = [];
      for (int i = 0; i < g.rows.length; i++) {
        final r = g.rows[i];
        final bool hasDr = r.debit > 0.0005;
        final bool hasCr = r.credit > 0.0005;

        rows.add(Container(
          decoration: BoxDecoration(
            color: i.isEven ? Colors.white : const Color(0xffFAFAFC),
            border: Border(
              bottom: BorderSide(color: AppColors.border.withOpacity(0.6)),
            ),
          ),
          child: Row(
            children: [
              cell(r.date, w: wDate, weight: FontWeight.w600),
              if (showVoucher)
                cell(r.voucher.isEmpty ? "—" : r.voucher,
                    w: wVoucher,
                    color: r.voucher.isEmpty ? _muted : const Color(0xff2563EB),
                    weight: FontWeight.w700),
              if (showType)
                Container(
                  width: wType,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  alignment: Alignment.centerLeft,
                  child: r.type.isEmpty
                      ? const Text("—", style: TextStyle(color: _muted))
                      : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: typeColor(r).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      r.type,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: typeColor(r),
                      ),
                    ),
                  ),
                ),
              cell(r.item, w: wItem, color: const Color(0xff4A4F5C)),
              cell(_wt.format(r.debit), w: wAmt, bg: _drTint,
                  color: hasDr ? _drRed : _muted,
                  weight: hasDr ? FontWeight.w800 : FontWeight.w500,
                  align: TextAlign.right),
              cell(_wt.format(r.credit), w: wAmt, bg: _crTint,
                  color: hasCr ? _crBlue : _muted,
                  weight: hasCr ? FontWeight.w800 : FontWeight.w500,
                  align: TextAlign.right),
              cell(_bal(r.balance), w: wBal, color: _balColor(r.balance),
                  weight: FontWeight.w700, align: TextAlign.right),
            ],
          ),
        ));
      }

      if (g.rows.isEmpty) {
        rows.add(SizedBox(
          width: tableWidth,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Column(
              children: [
                Icon(Icons.inbox_outlined, size: 22, color: _muted),
                SizedBox(height: 4),
                Text(
                  "No entries in this period",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: _muted),
                ),
              ],
            ),
          ),
        ));
      }

      /// ---------- TOTALS / CLOSING ----------
      final Widget totals = Container(
        decoration: BoxDecoration(
          color: const Color(0xffF1F2F6),
          border: Border(top: BorderSide(color: AppColors.primaryDark.withOpacity(0.25), width: 1.4)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: labelWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: Text(
                  "Period totals / Closing",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fs,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ),
            ),
            cell(_wt.format(g.totalDebit), w: wAmt,
                bg: _drRed.withOpacity(0.16), color: _drRed,
                weight: FontWeight.w800, align: TextAlign.right, size: fs),
            cell(_wt.format(g.totalCredit), w: wAmt,
                bg: _crBlue.withOpacity(0.16), color: _crBlue,
                weight: FontWeight.w800, align: TextAlign.right, size: fs),
            cell(_bal(g.closing), w: wBal, color: _balColor(g.closing),
                weight: FontWeight.w800, align: TextAlign.right, size: fs + 0.5),
          ],
        ),
      );

      final Widget table = SizedBox(
        width: tableWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [head, opening, ...rows, totals],
        ),
      );

      // Tablet: aakhi width bhari, scroll nahi
      if (!scrolls) return table;

      // Phone: horizontal scroll + nani hint
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 6),
              child: table,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: const [
                Icon(Icons.swipe_left_rounded, size: 13, color: _muted),
                SizedBox(width: 4),
                Text(
                  "Swipe to see all columns",
                  style: TextStyle(fontSize: 10.5, color: _muted),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _summaryLine({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color tint,
  }) {
    return Container(
      color: tint,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowTile(_LedgerRow r, int i) {
    final bool isDebit = r.debit > 0.0005 && r.credit <= 0.0005;
    final bool isCredit = r.credit > 0.0005 && r.debit <= 0.0005;
    final Color typeColor =
    isDebit ? _drRed : (isCredit ? _crBlue : AppColors.primaryDark);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 14, 11),
      decoration: BoxDecoration(
        color: i.isEven ? Colors.white : const Color(0xffFAFAFC),
        border: Border(top: BorderSide(color: AppColors.border.withOpacity(0.6))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Rang ni patti (Dr lal / Cr blue)
          Container(
            width: 3,
            height: 40,
            margin: const EdgeInsets.only(right: 10, top: 2),
            decoration: BoxDecoration(
              color: typeColor,
              borderRadius: BorderRadius.circular(3),
            ),
          ),

          /// DATE + VOUCHER + ITEM
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      r.date,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    if (r.type.isNotEmpty) const SizedBox(width: 6),
                    if (r.type.isNotEmpty)
                      Container(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          r.type,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: typeColor,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  r.voucher.isEmpty ? r.item : "${r.voucher}  •  ${r.item}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: _muted),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          /// AMOUNT + BALANCE
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (r.debit > 0.0005)
                Text(
                  "Dr ${_wt.format(r.debit)}",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _drRed,
                  ),
                ),
              if (r.credit > 0.0005)
                Text(
                  "Cr ${_wt.format(r.credit)}",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _crBlue,
                  ),
                ),
              if (r.debit <= 0.0005 && r.credit <= 0.0005)
                Text(
                  _wt.format(0),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _muted,
                  ),
                ),
              const SizedBox(height: 3),
              Text(
                "Bal ${_bal(r.balance)}",
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: _balColor(r.balance),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalTile(String label, String value, Color color,
      {bool strong = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: strong ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(strong ? 0.45 : 0.25)),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 10.5, color: _muted)),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 🔥 BRANCH REPORTS — LOAD BRANCHES (fakt main company admin)
  // ============================================================

  Future<void> loadBranches() async {
    setState(() => branchesLoading = true);

    try {
      // 🔐 Fakt main company admin ne j Branch Reports dekhay
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

        // Main company + ek branch hoy tyare j tab dekhay
        canViewBranches = list.length > 1;

        // Default: main company select
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

  /// 🔥 VIEW REPORT — fakt select kareli branches
  Future<void> viewBranchReport() async {
    if (selectedCompanyIds.isEmpty) {
      AppMessage.error(context, "Please select at least one branch");
      return;
    }

    setState(() {
      appliedCompanyIds = selectedCompanyIds.toList();
      branchReportLoading = true;
    });

    try {
      await _fetch();
    } finally {
      if (mounted) setState(() => branchReportLoading = false);
    }
  }

  /// Branch report bandh kari ne potani company no ledger
  Future<void> clearBranchReport() async {
    _exitBranchMode();
    await _fetch();
  }

  void _exitBranchMode() {
    setState(() => appliedCompanyIds = []);
  }

  /// Select kareli branches na slug (report_branches mate)
  List<String> get _appliedBranchSlugs => branchCompanies
      .where((c) => appliedCompanyIds.contains(c.id))
      .map((c) => c.slug ?? c.id.toString())
      .toList();

  /// Group kai branch nu chhe — company_id thi branch list mathi naam
  String _branchNameOf(Map j) {
    final int? companyId = int.tryParse("${j["company_id"] ?? ""}");
    if (companyId != null) {
      for (final c in branchCompanies) {
        if (c.id == companyId) return c.name;
      }
    }
    final dynamic b = j["branch"] ?? j["branch_name"] ?? j["company"];
    if (b is Map) return b["name"]?.toString() ?? "";
    return (b ?? j["company_name"] ?? "").toString();
  }

  // ============================================================
  // 🔥 BRANCH LEDGER URL
  // reports/worker-loss?mode=ledger&format=daily&worker_id=..
  //     &from_date=..&to_date=..&report_branches=slug1,slug2
  // (Worker Loss jevu j — e j API + report_branches)
  // ============================================================

  /// report_branches ni value:
  /// badhi branches select hoy to "all", nahi to slug1,slug2
  String get _reportBranchesValue {
    if (branchCompanies.isNotEmpty &&
        appliedCompanyIds.toSet().containsAll(branchCompanies.map((c) => c.id))) {
      return "all";
    }
    // Comma encode na thay (%2C) etle hathe join
    return _appliedBranchSlugs.map(Uri.encodeQueryComponent).join(",");
  }

  /// Branch mode hoy to URL ma &report_branches=.. umero
  String _withBranches(String url) {
    if (!branchMode) return url;
    final String sep = url.contains("?") ? "&" : "?";
    return "$url${sep}report_branches=$_reportBranchesValue";
  }

  String buildBranchLedgerUrl() => _withBranches(
    Uri.parse("${ApiConstants.baseUrl}reports/worker-loss")
        .replace(queryParameters: _query())
        .toString(),
  );

  // ============================================================
  // 🔐 BRANCH REPORTS (expand tab)
  // ============================================================

  Widget branchReportWidget() {
    if (branchesLoading) {
      return Container(
        margin: const EdgeInsets.fromLTRB(14, 6, 14, 2),
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
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 2),
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

  /// =========================================================
  /// EMPTY / RAW RESPONSE
  /// =========================================================
  Widget _emptyState(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 46, color: _muted.withOpacity(0.6)),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 13),
          ),
          if (_rawBody != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _showRaw,
              icon: const Icon(Icons.code_rounded, size: 18),
              label: const Text("Show API response"),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                side: BorderSide(color: AppColors.border),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showRaw() {
    String text;
    try {
      text = const JsonEncoder.withIndent("  ").convert(_rawBody);
    } catch (_) {
      text = _rawBody.toString();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheet) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "API response",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: text));
                        AppMessage.success(context, "Copied");
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text("Copy"),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  child: SelectableText(
                    text,
                    style: const TextStyle(
                      fontFamily: "monospace",
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ❌ CLEAR ICON — dropdown ni andar, arrow ni dabi baju
  Widget _clearIcon(VoidCallback onClear, {double right = 37}) {
    return Positioned(
      right: right,
      top: 0,
      bottom: 0,
      child: Center(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
            onClear();
          },
          child: Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Icon(Icons.close_rounded, size: 13, color: Colors.red.shade700),
          ),
        ),
      ),
    );
  }
}
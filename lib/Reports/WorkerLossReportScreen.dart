import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import 'package:pecifician_sysytem/Settings/BranchManagementScreen.dart'
    show BranchApi, Company, BranchTypeX;

import '../Extra/AppColors.dart';
import '../Extra/AppMessage.dart';
import '../Extra/ItemProvider.dart';
import '../Extra/PermissionDeniedWidget.dart';
import '../Extra/PremiumSearchableDropdown.dart';
import 'BranchAccess.dart';
import 'WorkerMetalLedgerScreen.dart';

/// ================================================================
/// 📊 WORKER LOSS REPORT
///
/// API: GET reports/worker-loss?from_date=&to_date=&worker_id=
///
/// - Date + Worker → API thi
/// - Stage / Voucher / Loss type / Only loss / Search → app ma j
///   (turant, farithi API call vagar)
/// - Totals, Worker summary, Stage summary → filter pachhi na data
///   parthi j ganay, etle hamesha list sathe match thay
/// ================================================================

class _WLRow {
  final String stage;
  final String workerId;
  final String workerName;
  final String voucherNo;
  final String voucherId;
  final String buchNo;
  final double sourceWt;
  final double receiveWt;
  final double bhuko;
  final double loss;
  final DateTime? dateTime;
  final String dateText;

  /// Branch report ma kai branch ni entry chhe (normal report ma "")
  final String branchName;

  _WLRow({
    required this.stage,
    required this.workerId,
    required this.workerName,
    required this.voucherNo,
    required this.voucherId,
    required this.buchNo,
    required this.sourceWt,
    required this.receiveWt,
    required this.bhuko,
    required this.loss,
    required this.dateTime,
    required this.dateText,
    this.branchName = "",
  });

  static double _d(dynamic v) => double.tryParse(v?.toString() ?? "") ?? 0;

  /// Object aave to "name" lai le, nahi to text
  static String _s(dynamic v) {
    if (v is Map) return v["name"]?.toString() ?? "";
    return v?.toString() ?? "";
  }

  factory _WLRow.fromJson(Map<String, dynamic> j, {String branch = ""}) {
    final String name = _s(j["worker_name"] ?? j["worker"]).trim();
    return _WLRow(
      stage: j["stage"]?.toString() ?? "-",
      workerId: j["worker_id"]?.toString() ?? "",
      workerName: name.isEmpty || name == "-" ? "No Worker" : name,
      voucherNo: j["voucher_no"]?.toString() ?? "-",
      voucherId: j["voucher_id"]?.toString() ?? "",
      buchNo: j["buch_no"]?.toString() ?? "-",
      sourceWt: _d(j["source_wt"]),
      receiveWt: _d(j["receive_wt"]),
      bhuko: _d(j["bhuko"]),
      loss: _d(j["loss"]),
      dateTime: DateTime.tryParse(j["process_datetime"]?.toString() ?? ""),
      dateText: j["process_datetime_fmt"]?.toString() ?? "",
      branchName: branch,
    );
  }
}

class _Group {
  final String label;
  int rows = 0;
  double source = 0, receive = 0, bhuko = 0, loss = 0;
  _Group(this.label);

  void add(_WLRow r) {
    rows++;
    source += r.sourceWt;
    receive += r.receiveWt;
    bhuko += r.bhuko;
    loss += r.loss;
  }
}

class WorkerLossReportScreen extends StatefulWidget {
  const WorkerLossReportScreen({super.key});

  @override
  State<WorkerLossReportScreen> createState() => _WorkerLossReportScreenState();
}

class _WorkerLossReportScreenState extends State<WorkerLossReportScreen> {
  /// =========================================================
  /// COLORS
  /// =========================================================
  static const Color _lossRed = Color(0xffD64545);
  static const Color _gainGreen = Color(0xff1F9D55);
  static const Color _muted = Color(0xff8A8F98);
  static const Color _ink = Color(0xff1C1E24);
  static const Color _linkBlue = Color(0xff2563EB);

  /// 🎨 Light blue palette (gaḍho blue ochho)
  static const Color _lbTop = Color(0xffDCE8FB);
  static const Color _lbBottom = Color(0xffF0F5FE);
  static const Color _lbBorder = Color(0xffC9DAF6);
  static const Color _lbSoft = Color(0xffF5F8FE);
  static const Color _lbText = Color(0xff2F4A78);

  /// 📐 Responsive
  bool get _isTablet => MediaQuery.of(context).size.width >= 600;
  double get _hPad => _isTablet ? 20 : 14;

  /// Tablet ma 2 card ek line ma (700+ width), phone ma 1
  int get _cols => MediaQuery.of(context).size.width >= 700 ? 2 : 1;

  /// Card list → line ma goṭhvo (tablet 2 column), moṭi screen ma 1200 max
  Widget _gridRow(List<Widget> cards, int row) {
    final int start = row * _cols;
    final List<Widget> items = [];
    for (int c = 0; c < _cols; c++) {
      if (c > 0) items.add(const SizedBox(width: 12));
      final int i = start + c;
      items.add(Expanded(child: i < cards.length ? cards[i] : const SizedBox()));
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: _hPad),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: items),
        ),
      ),
    );
  }

  static const List<String> _knownStages = [
    "Jobwork Receive",
    "Casting Receive",
    "Tree Cutting Receive",
  ];

  static const List<String> _lossTypes = ["All", "Loss", "Gain", "Zero"];

  /// =========================================================
  /// FILTERS
  /// =========================================================
  DateTime _from = DateTime.now().subtract(const Duration(days: 6));
  DateTime _to = DateTime.now();
  String? _workerId;
  String? _workerName;
  String _stage = "All";
  String _voucher = "";
  String _lossType = "All";
  bool _onlyLoss = false;

  /// =========================================================
  /// DATA
  /// =========================================================
  bool _loading = false;
  String? _error;
  List<_WLRow> _rows = [];

  int _tab = 0; // 0 = Vouchers, 1 = Workers, 2 = Stages
  final TextEditingController _searchCtrl = TextEditingController();
  int _visible = 25;

  /// "pdf" / "excel" — download chalu hoy tyare
  String? _exporting;

  List<String> _permissions = [];
  bool _permLoaded = false;

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
    _loadPermissions();
    Future.microtask(() {
      Provider.of<ItemProvider>(context, listen: false).loadJobWorker();
    });
    _fetch();

    // 🔥 Branch list (fakt main company admin ne j tab dekhashe)
    loadBranches();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _permissions = prefs.getStringList("user_permissions") ?? [];
      _permLoaded = true;
    });
  }

  bool get _canView =>
      _permissions.contains("report-worker-loss-view") ||
          _permissions.contains("report-worker-loss-manage");

  /// =========================================================
  /// API
  /// =========================================================
  Future<void> _fetch() async {
    // 🔥 Branch report chalu hoy to branch API
    if (branchMode) {
      await _loadBranchReport();
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final Map<String, String> q = {
      "from_date": _apiDate.format(_from),
      "to_date": _apiDate.format(_to),
      if (_workerId != null) "worker_id": _workerId!,
    };

    final String url = Uri.parse("${ApiConstants.baseUrl}reports/worker-loss")
        .replace(queryParameters: q)
        .toString();

    debugPrint("WORKER LOSS URL => $url");

    try {
      final response = await ApiHelper().getRequest(url);

      if (response != null &&
          response.statusCode == 200 &&
          response.data is Map &&
          response.data["success"] == true) {
        final List raw =
        response.data["data"] is List ? response.data["data"] : [];

        final List<_WLRow> rows = raw
            .whereType<Map>()
            .map((e) => _WLRow.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        if (!mounted) return;
        setState(() {
          _rows = rows;
          _visible = 25;
        });
      } else {
        if (!mounted) return;
        setState(() => _error = "Could not load the report. Pull down to retry.");
      }
    } catch (e) {
      debugPrint("WORKER LOSS ERROR => $e");
      if (mounted) {
        setState(() => _error = "Could not load the report. Pull down to retry.");
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// =========================================================
  /// 📤 EXPORT (PDF / EXCEL)
  /// Screen par je filter che e j file ma aave
  /// =========================================================
  Map<String, String> _exportQuery() {
    return {
      "from_date": _apiDate.format(_from),
      "to_date": _apiDate.format(_to),
      if (_workerId != null) "worker_id": _workerId!,
      if (_stage != "All") "stage": _stage,
      if (_voucher.trim().isNotEmpty) "voucher_no": _voucher.trim(),
      if (_onlyLoss || _lossType == "Loss") "only_loss": "1",
    };
  }

  Future<void> _export(String type) async {
    if (_exporting != null) return;

    final bool isPdf = type == "pdf";
    setState(() => _exporting = type);

    // 🔥 Branch merge hoy to fakt report_branches=all (bija filter nahi —
    // branch list pan date / worker vagar j aave chhe):
    //   reports/worker-loss/export/pdf?report_branches=all
    //   reports/worker-loss/export/excel?report_branches=all
    // Normal report ma pela jevu j (screen na filter sathe)
    final String exportBase =
        "${ApiConstants.baseUrl}reports/worker-loss/export/$type";

    // Excel hamesha direct: export/excel?report_branches=all
    final String url = (branchMode || !isPdf)
        ? "$exportBase?report_branches=all"
        : Uri.parse(exportBase)
        .replace(queryParameters: _exportQuery())
        .toString();

    debugPrint("WORKER LOSS EXPORT branchMode=$branchMode "
        "applied=$appliedCompanyIds URL => $url");

    try {
      final response = await ApiHelper().getPdfRequest(url);

      if (response == null || response.statusCode != 200) {
        debugPrint("EXPORT STATUS => ${response?.statusCode}");
        if (mounted) AppMessage.error(context, "Could not download the ${isPdf ? "PDF" : "Excel"} file");
        return;
      }

      final dynamic data = response.data;
      if (data is! List<int> || data.isEmpty) {
        debugPrint("EXPORT INVALID TYPE => ${data.runtimeType}");
        if (mounted) AppMessage.error(context, "The server sent an empty file");
        return;
      }

      // Sachi file che? PDF = "%PDF", XLSX = "PK" (zip)
      final bool looksPdf = data.length > 4 &&
          data[0] == 0x25 && data[1] == 0x50 && data[2] == 0x44 && data[3] == 0x46;
      final bool looksXlsx = data.length > 2 && data[0] == 0x50 && data[1] == 0x4B;

      if ((isPdf && !looksPdf) || (!isPdf && !looksXlsx)) {
        final String text =
        utf8.decode(data, allowMalformed: true);
        debugPrint("EXPORT NOT A FILE => ${text.length > 300 ? text.substring(0, 300) : text}");
        // Server e JSON error mokli hoy to eno message batavo
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
      final File file = File(
        "${dir.path}/Worker_Loss_$stamp.${isPdf ? "pdf" : "xlsx"}",
      );
      await file.writeAsBytes(data, flush: true);

      final result = await OpenFile.open(file.path);

      if (result.type != ResultType.done && mounted) {
        AppMessage.error(
          context,
          isPdf
              ? "Unable to open PDF"
              : "No app found to open Excel. Install Excel or Google Sheets.",
        );
      }
    } catch (e) {
      debugPrint("WORKER LOSS EXPORT ERROR => $e");
      if (mounted) AppMessage.error(context, "Could not download the file");
    } finally {
      if (mounted) setState(() => _exporting = null);
    }
  }

  /// =========================================================
  /// CLIENT FILTERS
  /// =========================================================
  List<_WLRow> get _filtered {
    final String search = _searchCtrl.text.trim().toLowerCase();
    final String voucher = _voucher.trim().toLowerCase();

    return _rows.where((r) {
      if (_stage != "All" && r.stage != _stage) return false;
      if (voucher.isNotEmpty && !r.voucherNo.toLowerCase().contains(voucher)) {
        return false;
      }
      if (_onlyLoss && r.loss >= 0) return false;

      switch (_lossType) {
        case "Loss":
          if (r.loss >= 0) return false;
          break;
        case "Gain":
          if (r.loss <= 0) return false;
          break;
        case "Zero":
          if (r.loss.abs() > 0.0005) return false;
          break;
      }

      if (search.isNotEmpty) {
        final String text =
        "${r.voucherNo} ${r.buchNo} ${r.workerName} ${r.stage} ${r.branchName}"
            .toLowerCase();
        if (!text.contains(search)) return false;
      }
      return true;
    }).toList();
  }

  List<_Group> _groupBy(List<_WLRow> rows, String Function(_WLRow) key) {
    final Map<String, _Group> map = {};
    for (final r in rows) {
      map.putIfAbsent(key(r), () => _Group(key(r))).add(r);
    }
    final List<_Group> list = map.values.toList()
      ..sort((a, b) => a.loss.compareTo(b.loss)); // vadhu loss upar
    return list;
  }

  int get _activeFilterCount =>
      (_workerId != null ? 1 : 0) +
          (_stage != "All" ? 1 : 0) +
          (_voucher.trim().isNotEmpty ? 1 : 0) +
          (_lossType != "All" ? 1 : 0) +
          (_onlyLoss ? 1 : 0);

  /// =========================================================
  /// HELPERS
  /// =========================================================
  Color _lossColor(double v) {
    if (v < -0.0005) return _lossRed;
    if (v > 0.0005) return _gainGreen;
    return _muted;
  }

  String _signed(double v) {
    if (v.abs() < 0.0005) return _wt.format(0);
    return "${v > 0 ? "+" : "−"}${_wt.format(v.abs())}";
  }

  /// =========================================================
  /// BUILD
  /// =========================================================
  @override
  Widget build(BuildContext context) {
    if (!_permLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_canView) {
      return Scaffold(
        body: PermissionDeniedWidget(onBack: () => Navigator.pop(context)),
      );
    }

    final List<_WLRow> rows = _filtered;

    double source = 0, receive = 0, bhuko = 0, loss = 0;
    for (final r in rows) {
      source += r.sourceWt;
      receive += r.receiveWt;
      bhuko += r.bhuko;
      loss += r.loss;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: _ledgerBottomButton(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetch,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header()),
              // 🔥 Branch Reports tab sauthi upar
              SliverToBoxAdapter(child: branchReportWidget()),
              SliverToBoxAdapter(child: _filterStrip()),
              if (_loading && _rows.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null && _rows.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _emptyState(Icons.cloud_off_rounded, _error!),
                )
              else ...[
                  SliverToBoxAdapter(
                    child: _heroCard(rows.length, source, receive, bhuko, loss),
                  ),
                  SliverToBoxAdapter(child: _exportRow()),
                  SliverToBoxAdapter(child: _tabs()),
                  ..._tabContent(rows),
                  if (branchMode && branchHasMore)
                    SliverToBoxAdapter(child: _loadMoreButton()),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
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
      padding: EdgeInsets.fromLTRB(_hPad, 12, _hPad, 6),
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
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Worker Loss Report",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Source, receive, bhuko and loss by worker",
                  style: TextStyle(fontSize: 11.5, color: _muted),
                ),
              ],
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              InkWell(
                onTap: _openFilterSheet,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.tune_rounded, color: AppColors.primaryDark),
                ),
              ),
              if (_activeFilterCount > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: _lossRed,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      "$_activeFilterCount",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Date range + active filter chips (tap → sheet, x → hatavo)
  Widget _filterStrip() {
    final List<Widget> chips = [
      _chip(
        icon: Icons.calendar_month_rounded,
        label: "${_uiDate.format(_from)} – ${_uiDate.format(_to)}",
        onTap: _openFilterSheet,
      ),
      if (_workerId != null)
        _chip(
          icon: Icons.person_outline_rounded,
          label: _workerName ?? "Worker",
          onClear: () {
            setState(() {
              _workerId = null;
              _workerName = null;
            });
            _fetch();
          },
        ),
      if (_stage != "All")
        _chip(
          icon: Icons.layers_outlined,
          label: _stage,
          onClear: () => setState(() => _stage = "All"),
        ),
      if (_voucher.trim().isNotEmpty)
        _chip(
          icon: Icons.receipt_long_outlined,
          label: _voucher,
          onClear: () => setState(() => _voucher = ""),
        ),
      if (_lossType != "All")
        _chip(
          icon: Icons.trending_down_rounded,
          label: _lossType,
          onClear: () => setState(() => _lossType = "All"),
        ),
      if (_onlyLoss)
        _chip(
          icon: Icons.warning_amber_rounded,
          label: "Only loss",
          onClear: () => setState(() => _onlyLoss = false),
        ),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(_hPad, 6, _hPad, 4),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap ?? _openFilterSheet,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.fromLTRB(10, 0, onClear != null ? 4 : 12, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: AppColors.primaryDark),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
            if (onClear != null)
              InkWell(
                onTap: onClear,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 15, color: _muted),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// =========================================================
  /// HERO (NET LOSS + 4 STATS)
  /// =========================================================
  Widget _heroCard(
      int count,
      double source,
      double receive,
      double bhuko,
      double loss,
      ) {
    final bool isLoss = loss < -0.0005;
    final bool isGain = loss > 0.0005;
    final Color lc = _lossColor(loss);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Container(
          margin: EdgeInsets.fromLTRB(_hPad, 8, _hPad, 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _lbBorder),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff2563EB).withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                /// ── TOP: Net loss (compact ek line)
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [_lbTop, _lbBottom]),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _lbBorder),
                        ),
                        child: Icon(
                          isGain
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          size: 16,
                          color: isLoss || isGain ? lc : _lbText,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Net Loss",
                              style: TextStyle(
                                color: _lbText,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              "$count entries",
                              style: const TextStyle(
                                  color: _muted, fontSize: 10.5),
                            ),
                          ],
                        ),
                      ),
                      // Value + Loss / Gain badge
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _signed(loss),
                                style: TextStyle(
                                  color: isLoss || isGain ? lc : _ink,
                                  fontSize: _isTablet ? 22 : 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.only(left: 3, bottom: 3),
                                child: Text("g",
                                    style: TextStyle(
                                        color: _muted, fontSize: 11.5)),
                              ),
                              if (isLoss || isGain) ...[
                                const SizedBox(width: 8),
                                Container(
                                  margin: const EdgeInsets.only(bottom: 3),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: lc.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(5),
                                    border:
                                    Border.all(color: lc.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    isLoss ? "Loss" : "Gain",
                                    style: TextStyle(
                                      color: lc,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                /// ── BOTTOM: Source / Receive / Bhuko
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      _heroStat("Source", source),
                      _heroDivider(),
                      _heroStat("Receive", receive),
                      _heroDivider(),
                      _heroStat("Bhuko", bhuko),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroStat(String label, double v) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
                color: _muted, fontSize: 10.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _wt.format(v),
              style: TextStyle(
                color: _ink,
                fontSize: _isTablet ? 14 : 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroDivider() =>
      Container(width: 1, height: 24, color: _lbBorder);

  /// =========================================================
  /// 📒 BOTTOM FIXED — WORKER METAL LEDGER
  /// =========================================================
  Widget _ledgerBottomButton() {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(_hPad, 10, _hPad, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryDark, AppColors.secondaryDark],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const WorkerMetalLedgerScreen(),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.menu_book_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Worker Metal Ledger",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// =========================================================
  /// 🧾 VOUCHER POPUP — e voucher ni badhi entries
  /// (screen par aavelo data j, navi API nahi)
  /// =========================================================
  void _openVoucherPopup(String voucherNo) {
    final List<_WLRow> items =
    _rows.where((e) => e.voucherNo == voucherNo).toList();
    if (items.isEmpty) return;

    double src = 0, rec = 0, bh = 0, ls = 0;
    for (final e in items) {
      src += e.sourceWt;
      rec += e.receiveWt;
      bh += e.bhuko;
      ls += e.loss;
    }

    final Set<String> workers = items.map((e) => e.workerName).toSet();
    final Set<String> stages = items.map((e) => e.stage).toSet();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheet) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scroll) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  /// HEADER
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryDark,
                                AppColors.secondaryDark,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.receipt_long_rounded,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                voucherNo,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: _linkBlue,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "${items.length} entries  •  ${workers.join(", ")}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12, color: _muted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheet),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),

                  /// STAGES
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: stages.map(_stagePill).toList(),
                      ),
                    ),
                  ),

                  /// TOTALS
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        _miniStat("Source", src),
                        _miniStat("Receive", rec),
                        _miniStat("Bhuko", bh),
                        Expanded(
                          child: Column(
                            children: [
                              const Text("Loss",
                                  style:
                                  TextStyle(fontSize: 10.5, color: _muted)),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _signed(ls),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: _lossColor(ls),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Divider(height: 1, color: AppColors.border),

                  /// ENTRIES
                  Expanded(
                    child: ListView.separated(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final e = items[i];
                        final Color lc = _lossColor(e.loss);

                        return Container(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: AppColors.gradientBlue,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "${i + 1}",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "B. No ${e.buchNo}",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: _ink,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _signed(e.loss),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: lc,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _miniStat("Source", e.sourceWt),
                                  _miniStat("Receive", e.receiveWt),
                                  _miniStat("Bhuko", e.bhuko),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.person_outline_rounded,
                                      size: 13, color: _muted),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      e.workerName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 11.5, color: _ink),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  _stagePill(e.stage),
                                  const Spacer(),
                                  Text(
                                    e.dateText,
                                    style: const TextStyle(
                                        fontSize: 10.5, color: _muted),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// =========================================================
  /// EXPORT BUTTONS
  /// =========================================================
  Widget _exportRow() {
    return Padding(
      padding: EdgeInsets.fromLTRB(_hPad, 6, _hPad, 0),
      child: Row(
        children: [
          Expanded(
            child: _exportButton(
              type: "excel",
              label: "Excel",
              icon: Icons.grid_on_rounded,
              color: const Color(0xff1D6F42), // Excel green
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _exportButton(
              type: "pdf",
              label: "PDF",
              icon: Icons.picture_as_pdf_rounded,
              color: const Color(0xffD64545),
            ),
          ),
        ],
      ),
    );
  }

  Widget _exportButton({
    required String type,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final bool busy = _exporting == type;
    final bool disabled = _exporting != null && !busy;

    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _exporting != null ? null : () => _export(type),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.35)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: busy
                      ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                      : Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 8),
                Text(
                  busy ? "Downloading..." : "Download $label",
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
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

  /// =========================================================
  /// TABS
  /// =========================================================
  Widget _tabs() {
    final List<String> labels = [
      "Vouchers",
      "Workers",
      "Stages",
      if (branchMode) "Branches",
    ];

    return Container(
      margin: EdgeInsets.fromLTRB(_hPad, 10, _hPad, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final bool sel = i == _tab;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? _lbTop : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                      color: sel ? _lbBorder : Colors.transparent),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: sel ? _lbText : _muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  List<Widget> _tabContent(List<_WLRow> rows) {
    if (_tab == 0) return _voucherTab(rows);
    if (_tab == 1) return _groupTab(_groupBy(rows, (r) => r.workerName), true);
    // Branch wise total (tap → e branch ni entries search ma)
    if (_tab == 3 && branchMode) {
      return _groupTab(
        _groupBy(rows, (r) => r.branchName.isEmpty ? "-" : r.branchName),
        true,
      );
    }
    return _groupTab(_groupBy(rows, (r) => r.stage), false);
  }

  /// =========================================================
  /// VOUCHER TAB
  /// =========================================================
  List<Widget> _voucherTab(List<_WLRow> rows) {
    final int shown = rows.length < _visible ? rows.length : _visible;

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(_hPad, 0, _hPad, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() => _visible = 25),
            style: const TextStyle(fontSize: 13.5),
            decoration: InputDecoration(
              hintText: "Search voucher, B. No, worker",
              hintStyle: const TextStyle(color: _muted, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: _muted),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () => setState(() => _searchCtrl.clear()),
              ),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primaryDark),
              ),
            ),
          ),
        ),
      ),
      if (rows.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 40),
            child: _emptyState(
              Icons.inventory_2_outlined,
              "No entries match these filters.",
            ),
          ),
        )
      else
        SliverList(
          delegate: SliverChildBuilderDelegate(
                (_, i) {
              final List<Widget> cards = [
                for (int k = i * _cols; k < (i + 1) * _cols && k < shown; k++)
                  _voucherCard(rows[k]),
              ];
              return _gridRow(cards, 0);
            },
            childCount: (shown / _cols).ceil(),
          ),
        ),
      if (shown < rows.length)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(_hPad, 6, _hPad, 0),
            child: OutlinedButton(
              onPressed: () => setState(() => _visible += 25),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                side: BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text("Show more (${rows.length - shown} left)"),
            ),
          ),
        ),
    ];
  }

  Widget _voucherCard(_WLRow r) {
    final Color lc = _lossColor(r.loss);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _lbBorder.withOpacity(0.7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff2563EB).withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            /// Loss rang ni patti
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: lc,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(14),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// Voucher + loss
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              /// 🔵 VOUCHER NO — tap → popup
                              InkWell(
                                onTap: () => _openVoucherPopup(r.voucherNo),
                                borderRadius: BorderRadius.circular(4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      r.voucherNo,
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                        color: _linkBlue,
                                        decoration: TextDecoration.underline,
                                        decorationColor: _linkBlue,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.open_in_new_rounded,
                                        size: 13, color: _linkBlue),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "B. No ${r.buchNo}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: _muted),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: lc.withOpacity(0.09),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: lc.withOpacity(0.3)),
                              ),
                              child: Text(
                                _signed(r.loss),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: lc,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              "Loss (g)",
                              style: TextStyle(fontSize: 10.5, color: _muted),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    /// Weights
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _lbSoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _lbBorder.withOpacity(0.6)),
                      ),
                      child: Row(
                        children: [
                          _miniStat("Source", r.sourceWt),
                          const Icon(Icons.arrow_forward_rounded,
                              size: 14, color: _muted),
                          _miniStat("Receive", r.receiveWt),
                          _miniStat("Bhuko", r.bhuko),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    /// Worker + date (line 1), stage + branch (line 2) — overflow nahi
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded,
                            size: 14, color: _muted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            r.workerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.schedule_rounded,
                            size: 12, color: _muted),
                        const SizedBox(width: 3),
                        Text(
                          r.dateText,
                          style: const TextStyle(fontSize: 10.5, color: _muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _stagePill(r.stage),
                        if (branchMode && r.branchName.isNotEmpty)
                          _branchPill(r.branchName),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, double v) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10.5, color: _muted)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _wt.format(v),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _branchPill(String name) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 90),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _gainGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: _gainGreen,
        ),
      ),
    );
  }

  Widget _stagePill(String stage) {
    final String short = stage.replaceAll(" Receive", "");
    final Color c = stage.startsWith("Casting")
        ? const Color(0xffB7791F)
        : stage.startsWith("Tree")
        ? const Color(0xff2B6CB0)
        : const Color(0xff6B46C1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        short,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c),
      ),
    );
  }

  /// =========================================================
  /// WORKER / STAGE TAB
  /// =========================================================
  List<Widget> _groupTab(List<_Group> groups, bool isWorker) {
    if (groups.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 40),
            child: _emptyState(
              Icons.inventory_2_outlined,
              "No entries match these filters.",
            ),
          ),
        ),
      ];
    }

    double maxAbs = 0;
    for (final g in groups) {
      if (g.loss.abs() > maxAbs) maxAbs = g.loss.abs();
    }

    return [
      SliverList(
        delegate: SliverChildBuilderDelegate(
              (_, i) {
            final List<Widget> cards = [
              for (int k = i * _cols; k < (i + 1) * _cols && k < groups.length; k++)
                _groupCard(groups[k], maxAbs, isWorker),
            ];
            return _gridRow(cards, 0);
          },
          childCount: (groups.length / _cols).ceil(),
        ),
      ),
    ];
  }

  Widget _groupCard(_Group g, double maxAbs, bool isWorker) {
    final Color lc = _lossColor(g.loss);
    final double frac = maxAbs <= 0 ? 0 : (g.loss.abs() / maxAbs);

    return InkWell(
      onTap: () {
        // Tap → e worker / stage na voucher jovo
        setState(() {
          if (isWorker) {
            _searchCtrl.text = g.label;
          } else {
            _stage = g.label;
          }
          _tab = 0;
          _visible = 25;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _lbBorder.withOpacity(0.7)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xff2563EB).withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_lbTop, _lbBottom]),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _lbBorder),
                  ),
                  child: isWorker
                      ? Text(
                    g.label.isNotEmpty ? g.label[0].toUpperCase() : "?",
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                      : const Icon(Icons.layers_outlined,
                      size: 18, color: AppColors.primaryDark),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      Text(
                        "${g.rows} entries",
                        style: const TextStyle(fontSize: 11.5, color: _muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  _signed(g.loss),
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: lc,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: _muted),
              ],
            ),

            /// Loss nu maap (sauthi vadhu = puri patti)
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Container(height: 5, color: _lbSoft),
                  FractionallySizedBox(
                    widthFactor: frac.clamp(0.0, 1.0).toDouble(),
                    child: Container(height: 5, color: lc),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),
            Row(
              children: [
                _miniStat("Source", g.source),
                _miniStat("Receive", g.receive),
                _miniStat("Bhuko", g.bhuko),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(IconData icon, String text) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 46, color: _muted.withOpacity(0.6)),
        const SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 13),
        ),
      ],
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
      branchPage = 1;
      branchReportLoading = true;
    });

    try {
      await _fetch();
    } finally {
      if (mounted) setState(() => branchReportLoading = false);
    }
  }

  /// Branch report bandh kari ne potani company no report
  Future<void> clearBranchReport() async {
    _exitBranchMode();
    await _fetch();
  }

  void _exitBranchMode() {
    setState(() {
      appliedCompanyIds = [];
      branchPage = 1;
      branchHasMore = false;
      if (_tab == 3) _tab = 0; // "Branches" tab fakt branch report ma
    });
  }

  /// Select kareli branches na slug (report_branches mate)
  List<String> get _appliedBranchSlugs => branchCompanies
      .where((c) => appliedCompanyIds.contains(c.id))
      .map((c) => c.slug ?? c.id.toString())
      .toList();

  /// Row kai branch ni chhe — company_id thi branch list mathi naam
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
  // 🔥 BRANCH REPORT URL
  // company/branch-reports/worker-loss?report_branches=slug1,slug2&per_page=25
  // ============================================================

  String get branchWorkerLossUrl =>
      "${ApiConstants.baseUrl}company/branch-reports/worker-loss";

  String buildBranchReportUrl(int page) {
    // Comma encode na thay (%2C) etle URL hathe banaviye
    final String branches =
    _appliedBranchSlugs.map(Uri.encodeQueryComponent).join(",");

    String url = "$branchWorkerLossUrl"
        "?report_branches=$branches"
        "&per_page=$branchPerPage";

    // Load More vakhte j (DataTables "start" + Laravel "page" banne)
    if (page > 1) {
      url += "&page=$page&start=${(page - 1) * branchPerPage}";
    }

    return url;
  }

  // ============================================================
  // 🔥 BRANCH REPORT API (pagination sathe)
  // ============================================================

  Future<void> _loadBranchReport({bool loadMore = false}) async {
    final int page = loadMore ? branchPage + 1 : 1;
    final String url = buildBranchReportUrl(page);

    debugPrint("🔥 BRANCH WORKER LOSS API: $url");

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

      if (response?.statusCode == 200 && body is Map) {
        final dynamic data = body["data"];

        List raw = [];
        if (data is List) {
          raw = data;
        } else if (data is Map && data["data"] is List) {
          raw = data["data"];
        }

        final List<_WLRow> rows = raw.whereType<Map>().map((e) {
          final m = Map<String, dynamic>.from(e);
          return _WLRow.fromJson(m, branch: _branchNameOf(m));
        }).toList();

        if (!mounted) return;

        setState(() {
          final List<_WLRow> all = loadMore ? [..._rows, ...rows] : rows;
          _rows = all;
          // Branch report ma server thi page aave chhe — badha j batavo
          _visible = all.length < 25 ? 25 : all.length;
          branchPage = page;

          // DataTables: recordsFiltered / Laravel: last_page
          final int? total = int.tryParse(
              "${body["recordsFiltered"] ?? body["recordsTotal"] ?? body["total"] ?? ""}");
          final int last = int.tryParse(
              "${(data is Map ? data["last_page"] : null) ?? body["last_page"] ?? ""}") ??
              0;

          if (total != null) {
            branchHasMore = all.length < total && rows.isNotEmpty;
          } else if (last > 0) {
            branchHasMore = page < last;
          } else {
            branchHasMore = rows.length >= branchPerPage;
          }
        });

        debugPrint("✅ Branch worker loss rows: ${_rows.length}");
      } else {
        final String msg = body is Map && body["message"] != null
            ? body["message"].toString()
            : "Failed to load branch report";

        if (!mounted) return;
        AppMessage.error(context, msg);

        if (!loadMore) {
          setState(() {
            _rows = [];
            _error = msg;
            branchHasMore = false;
          });
        }
      }
    } catch (e) {
      debugPrint("❌ Branch worker loss exception: $e");
      if (!mounted) return;
      AppMessage.error(context, "Failed to load branch report");
      if (!loadMore) setState(() => _error = "Could not load the branch report.");
    } finally {
      if (mounted) {
        setState(() {
          branchLoadingMore = false;
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // 🔥 BRANCH REPORTS (expand tab)
  // ============================================================

  Widget branchReportWidget() {
    if (branchesLoading) {
      return Container(
        margin: EdgeInsets.fromLTRB(_hPad, 6, _hPad, 2),
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
      margin: EdgeInsets.fromLTRB(_hPad, 6, _hPad, 2),
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
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      child: InkWell(
        onTap: branchLoadingMore
            ? null
            : () => _loadBranchReport(loadMore: true),
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
                  "Load More (${_rows.length} loaded)",
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

  /// =========================================================
  /// FILTER SHEET
  /// =========================================================
  void _openFilterSheet() {
    DateTime from = _from;
    DateTime to = _to;
    String? workerId = _workerId;
    String? workerName = _workerName;
    String stage = _stage;
    String lossType = _lossType;
    bool onlyLoss = _onlyLoss;
    final TextEditingController voucherCtrl =
    TextEditingController(text: _voucher);

    final List<String> stages = {
      ..._knownStages,
      ..._rows.map((r) => r.stage),
    }.toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheet) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            Future<void> pickDate(bool isFrom) async {
              final DateTime? d = await showDatePicker(
                context: context,
                initialDate: isFrom ? from : to,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (d == null) return;
              setSheet(() {
                if (isFrom) {
                  from = d;
                  if (to.isBefore(from)) to = from;
                } else {
                  to = d;
                  if (from.isAfter(to)) from = to;
                }
              });
            }

            Widget dateTile(String label, DateTime d, bool isFrom) {
              return Expanded(
                child: InkWell(
                  onTap: () => pickDate(isFrom),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: const TextStyle(fontSize: 11, color: _muted)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded,
                                size: 14, color: AppColors.primaryDark),
                            const SizedBox(width: 6),
                            Text(
                              _uiDate.format(d),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            Widget quickRange(String label, int days) {
              return ActionChip(
                label: Text(label),
                labelStyle: const TextStyle(fontSize: 12),
                backgroundColor: AppColors.background,
                side: BorderSide(color: AppColors.border),
                onPressed: () => setSheet(() {
                  to = DateTime.now();
                  from = to.subtract(Duration(days: days - 1));
                }),
              );
            }

            Widget choice(String value, String current, ValueChanged<String> on) {
              final bool sel = value == current;
              return ChoiceChip(
                label: Text(value),
                selected: sel,
                showCheckmark: false,
                selectedColor: AppColors.primaryDark,
                backgroundColor: AppColors.background,
                side: BorderSide(
                  color: sel ? AppColors.primaryDark : AppColors.border,
                ),
                labelStyle: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : _ink,
                ),
                onSelected: (_) => setSheet(() => on(value)),
              );
            }

            Widget title(String t) => Padding(
              padding: const EdgeInsets.only(top: 18, bottom: 8),
              child: Text(
                t,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            );

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        "Filters",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),

                      /// DATE
                      title("Date range"),
                      Row(
                        children: [
                          dateTile("From", from, true),
                          const SizedBox(width: 10),
                          dateTile("To", to, false),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          quickRange("Today", 1),
                          quickRange("7 days", 7),
                          quickRange("30 days", 30),
                          quickRange("90 days", 90),
                        ],
                      ),

                      /// WORKER
                      title("Worker"),
                      Consumer<ItemProvider>(
                        builder: (context, provider, _) {
                          final List<Map<String, dynamic>> workers = provider
                              .Job_worker
                              .whereType<Map>()
                              .map((e) => Map<String, dynamic>.from(e))
                              .toList();

                          Map<String, dynamic>? selected;
                          for (final w in workers) {
                            if (w["id"]?.toString() == workerId) {
                              selected = w;
                              break;
                            }
                          }

                          return PremiumSearchableDropdown<Map<String, dynamic>>(
                            label: "",
                            hint: "All workers",
                            items: workers,
                            value: selected,
                            prefixIcon: Icons.person_outline_rounded,
                            itemLabel: (w) => w["name"]?.toString() ?? "-",
                            searchText: (w) => w["name"]?.toString() ?? "",
                            onChanged: (w) => setSheet(() {
                              workerId = w?["id"]?.toString();
                              workerName = w?["name"]?.toString();
                            }),
                          );
                        },
                      ),
                      if (workerId != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => setSheet(() {
                              workerId = null;
                              workerName = null;
                            }),
                            child: const Text("Clear worker"),
                          ),
                        ),

                      /// VOUCHER
                      title("Voucher no"),
                      TextField(
                        controller: voucherCtrl,
                        decoration: InputDecoration(
                          hintText: "e.g. VV26-",
                          prefixIcon: const Icon(Icons.receipt_long_outlined),
                          filled: true,
                          fillColor: AppColors.background,
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),

                      /// STAGE
                      title("Stage"),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          choice("All", stage, (v) => stage = v),
                          for (final s in stages) choice(s, stage, (v) => stage = v),
                        ],
                      ),

                      /// LOSS TYPE
                      title("Loss type"),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final t in _lossTypes)
                            choice(t, lossType, (v) => lossType = v),
                        ],
                      ),

                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: onlyLoss,
                        activeColor: AppColors.primaryDark,
                        title: const Text(
                          "Show only loss",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          "Hide entries where receive is equal or more",
                          style: TextStyle(fontSize: 11.5),
                        ),
                        onChanged: (v) => setSheet(() => onlyLoss = v),
                      ),

                      const SizedBox(height: 14),

                      /// BUTTONS
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setSheet(() {
                                to = DateTime.now();
                                from = to.subtract(const Duration(days: 6));
                                workerId = null;
                                workerName = null;
                                stage = "All";
                                lossType = "All";
                                onlyLoss = false;
                                voucherCtrl.clear();
                              }),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _ink,
                                side: BorderSide(color: AppColors.border),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text("Reset"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primaryDark,
                                    AppColors.secondaryDark,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    final bool needsFetch = from != _from ||
                                        to != _to ||
                                        workerId != _workerId;

                                    setState(() {
                                      _from = from;
                                      _to = to;
                                      _workerId = workerId;
                                      _workerName = workerName;
                                      _stage = stage;
                                      _lossType = lossType;
                                      _onlyLoss = onlyLoss;
                                      _voucher = voucherCtrl.text.trim();
                                      _visible = 25;
                                    });

                                    Navigator.pop(sheet);

                                    // Date / worker badlay to farithi load.
                                    // Branch report chalu hoy to e j chalu
                                    // rahe (bandh nahi thay) — etle PDF /
                                    // Excel pan branch URL thi j aave.
                                    if (needsFetch) {
                                      _fetch();
                                    }
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    child: Center(
                                      child: Text(
                                        "Apply filters",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() => voucherCtrl.dispose());
  }
}
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pecifician_sysytem/Settings/BranchManagementScreen.dart'
    show BranchApi, Company, BranchTypeX;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import '../Dashboard/HomeScreen.dart';
import '../Extra/AppColors.dart';
import '../Extra/AppMessage.dart';
import '../Extra/ItemProvider.dart';
import '../Extra/PermissionDeniedWidget.dart';
import 'BranchAccess.dart';

class Approvaloutstandingreport extends StatefulWidget {
  const Approvaloutstandingreport({super.key});

  @override
  State<Approvaloutstandingreport> createState() =>
      _ApprovaloutstandingreportState();
}

class _ApprovaloutstandingreportState extends State<Approvaloutstandingreport> {
  TextEditingController searchController = TextEditingController();
  TextEditingController fromDateController = TextEditingController();
  TextEditingController toDateController = TextEditingController();

  List userlist = [];
  List<Map<String, dynamic>> items = [];
  List searchResults = [];
  bool isLoading = false;
  Map<String, bool> expandedMap = {};
  Map<String, dynamic>? summaryTotals;
  String? Code;
  String? selectedItem;
  List allUsers = [];
  List<String> userPermissions = [];

  // ============================================================
  // API COLUMNS RESPONSE
  // ============================================================

  List<Map<String, dynamic>> apiColumns = [];

  // ============================================================
  // DATE FILTER APPLIED OR NOT
  // ============================================================

  bool filterApplied = false;

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


  // ============================================================
  // 🔥 REPORT COLUMNS — એક જ જગ્યાએ (ક્રમ = screen પરનો ક્રમ)
  // ============================================================

  static const List<Map<String, String>> reportColumns = [
    {"label": "Approval No", "key": "approval_no"},
    {"label": "Date", "key": "date"},
    {"label": "Customer", "key": "customer"},
    {"label": "Status", "key": "status"},
    {"label": "Pending Pcs", "key": "pending_pcs"},
    {"label": "Gross Wt", "key": "gross_weight"},
    {"label": "Other Wt", "key": "other_weight"},
    {"label": "Net Wt", "key": "net_weight"},
    {"label": "Purity", "key": "purity"},
    {"label": "Waste %", "key": "waste_percent"},
    {"label": "Fine Wt", "key": "fine_weight"},
    {"label": "Metal Rate", "key": "metal_rate"},
    {"label": "Metal Amt", "key": "metal_amount"},
    {"label": "Labour Rate", "key": "labour_rate"},
    {"label": "Labour Amt", "key": "labour_amount"},
    {"label": "Other Amount", "key": "other_amount"},
    {"label": "Pending Amount", "key": "pending_amount"},
    {"label": "Total", "key": "net_total"},
    {"label": "Remarks", "key": "remarks"},
    {"label": "Created By", "key": "created_by"},
  ];

  // ============================================================
  // DEFAULT SELECTION
  // ============================================================

  Map<String, bool> columnVisibility = {
    "Approval No": true,
    "Date": true,
    "Customer": true,
    "Status": true,
    "Pending Pcs": true,
    "Gross Wt": true,
    "Other Wt": false,
    "Net Wt": true,
    "Purity": true,
    "Waste %": true,
    "Fine Wt": true,
    "Metal Rate": true,
    "Metal Amt": true,
    "Labour Rate": true,
    "Labour Amt": true,
    "Other Amount": false,
    "Pending Amount": true,
    "Total": true,
    "Remarks": true,
    "Created By": false,
  };

  // ============================================================
  // UI LABEL -> API COLUMN NAME
  // ============================================================

  final Map<String, String> columnApiMap = {
    for (final c in reportColumns) c["label"]!: c["key"]!,
  };

  bool columnsLoading = false;

  /// 🔥 Approval details ખૂલતો હોય ત્યારે બીજી વાર tap ના થાય
  bool _openingVoucher = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    loadPermissions();

    Future.microtask(() {
      if (!mounted) return;

      Provider.of<ItemProvider>(context, listen: false).loadCustomers();
    });

    DateTime today = DateTime.now();

    String formattedDate = "${today.day.toString().padLeft(2, '0')}-"
        "${today.month.toString().padLeft(2, '0')}-"
        "${today.year}";

    fromDateController.text = formattedDate;
    toDateController.text = formattedDate;

    // Initial API call ma date filter apply nahi thase.
    filterApplied = false;

    // પહેલી વખત load થાય ત્યારે પણ spinner
    isLoading = true;

    Salesumryreport().whenComplete(() {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    });

    // 🔥 Branch list (fakt main company admin ne j tab dekhashe)
    loadBranches();
  }

  @override
  void dispose() {
    searchController.dispose();
    fromDateController.dispose();
    toDateController.dispose();
    super.dispose();
  }


  // ============================================================
  // 🔥 LOAD BRANCHES (dropdown mate)
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
      // Branch access nathi (branch user / staff) → tab nahi dekhay
      debugPrint("❌ Branch list load failed: $e");
      if (mounted) setState(() => canViewBranches = false);
    } finally {
      if (mounted) setState(() => branchesLoading = false);
    }
  }

  String _companyLabel(Company c) =>
      c.isMain ? "${c.name} (Main Company)" : c.name;

  /// From / To date sachi chhe ke nahi
  bool _validDateRange() {
    if (fromDateController.text.trim().isEmpty ||
        toDateController.text.trim().isEmpty) {
      return false;
    }

    try {
      final fromDate = _convertToDate(fromDateController.text.trim());
      final toDate = _convertToDate(toDateController.text.trim());

      if (fromDate.isAfter(toDate)) {
        AppMessage.error(context, "From Date cannot be greater than To Date");
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 🔥 VIEW REPORT — fakt select kareli branches (date/customer nahi)
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
      await Salesumryreport();
    } finally {
      if (mounted) setState(() => branchReportLoading = false);
    }
  }

  /// Branch report bandh kari ne potani company no report
  Future<void> clearBranchReport() async {
    setState(() {
      appliedCompanyIds = [];
      branchPage = 1;
      branchHasMore = false;
    });
    await Salesumryreport();
  }

  /// Select kareli branches na slug (report_branches mate)
  List<String> get _appliedBranchSlugs => branchCompanies
      .where((c) => appliedCompanyIds.contains(c.id))
      .map((c) => c.slug ?? c.id.toString())
      .toList();

  // ============================================================
  // 🔥 BRANCH REPORT URL (fakt aa j)
  // company/branch-reports/approval-outstanding?report_branches=slug1,slug2&per_page=25
  // ============================================================

  /// Normal API (ApiConstants.Approval_Outstanding_report = .../reports/<naam>)
  /// mathi report nu naam lai ne branch URL banave
  String get branchApprovalOutstandingUrl {
    final String path = Uri.parse(ApiConstants.Approval_Outstanding_report).path;
    const String marker = "/reports/";
    final int i = path.indexOf(marker);

    final String reportName = i >= 0
        ? path.substring(i + marker.length)
        : "approval-outstanding";

    return "${ApiConstants.baseUrl}company/branch-reports/$reportName";
  }

  String buildBranchReportUrl(int page) {
    // Comma encode na thay (%2C) etle URL hathe banaviye
    final String branches =
    _appliedBranchSlugs.map(Uri.encodeQueryComponent).join(",");

    String url = "$branchApprovalOutstandingUrl"
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

    debugPrint("🔥 BRANCH APPROVAL OUTSTANDING API: $url");

    if (loadMore) setState(() => branchLoadingMore = true);

    try {
      final response =
      await ApiHelper().getRequest(url, showLoading: !loadMore);

      final dynamic body = response?.data;

      if (response?.statusCode == 200 && body is Map) {
        final parsed = _parseBranchResponse(Map<String, dynamic>.from(body));

        if (!mounted) return;

        setState(() {
          final List rows =
          loadMore ? [...allUsers, ...parsed.rows] : parsed.rows;

          userlist = rows;
          allUsers = rows;
          summaryTotals = parsed.totals ?? calculateTotals(rows);
          if (parsed.columns.isNotEmpty) apiColumns = parsed.columns;
          branchPage = page;

          // DataTables response: recordsFiltered thi khabar pade vadhu chhe ke nahi
          final int? total = int.tryParse(
              "${body["recordsFiltered"] ?? body["recordsTotal"] ?? ""}");
          branchHasMore = total != null
              ? rows.length < total && parsed.rows.isNotEmpty
              : parsed.hasMore;
        });

        debugPrint("✅ Branch report rows: ${allUsers.length}");
      } else {
        final String msg = body is Map && body["message"] != null
            ? body["message"].toString()
            : "Failed to load branch report";

        if (!mounted) return;
        AppMessage.error(context, msg);

        if (!loadMore) {
          setState(() {
            userlist = [];
            allUsers = [];
            summaryTotals = {};
            branchHasMore = false;
          });
        }
      }
    } catch (e) {
      debugPrint("❌ Branch report exception: $e");
      if (mounted) AppMessage.error(context, "Failed to load branch report");
    } finally {
      if (mounted && loadMore) setState(() => branchLoadingMore = false);
    }
  }

  /// Response alag alag shape ma aave to pan chale
  ({
  List rows,
  Map<String, dynamic>? totals,
  List<Map<String, dynamic>> columns,
  bool hasMore,
  }) _parseBranchResponse(Map<String, dynamic> body) {
    final dynamic data = body["data"];

    // ---- rows ----
    List rows = [];
    if (data is List) {
      rows = data;
    } else if (data is Map) {
      final inner = data["data"] ?? data["rows"] ?? data["items"];
      if (inner is List) rows = inner;
    } else if (body["rows"] is List) {
      rows = body["rows"];
    }

    // ---- totals ----
    dynamic t = body["totals"] ?? body["summary"];
    if (t == null && data is Map) t = data["totals"];
    final Map<String, dynamic>? totals =
    t is Map ? Map<String, dynamic>.from(t) : null;

    // ---- columns ----
    dynamic cols = body["columns"];
    if (cols == null && data is Map) cols = data["columns"];
    final List<Map<String, dynamic>> columns = cols is List
        ? cols
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList()
        : [];

    // ---- pagination ----
    Map? meta;
    if (body["meta"] is Map) {
      meta = body["meta"];
    } else if (body["pagination"] is Map) {
      meta = body["pagination"];
    } else if (data is Map && data["current_page"] != null) {
      meta = data;
    }

    bool hasMore;
    final int current = int.tryParse("${meta?["current_page"] ?? ""}") ?? 0;
    final int last = int.tryParse("${meta?["last_page"] ?? ""}") ?? 0;

    if (last > 0) {
      hasMore = current < last;
    } else if (meta != null && meta.containsKey("next_page_url")) {
      hasMore = meta["next_page_url"] != null;
    } else if (body["links"] is Map && (body["links"] as Map).containsKey("next")) {
      hasMore = body["links"]["next"] != null;
    } else {
      hasMore = rows.length >= branchPerPage;
    }

    return (rows: rows, totals: totals, columns: columns, hasMore: hasMore);
  }


  // ============================================================
  // GET SELECTED API COLUMNS
  // ============================================================

  List<String> getSelectedColumns() {
    return columnVisibility.entries
        .where((entry) => entry.value)
        .map((entry) => columnApiMap[entry.key])
        .whereType<String>()
        .toList();
  }

  // ============================================================
  // BUILD REPORT URL
  // ============================================================

  String buildSalesSummaryUrl() {
    final selectedColumns = getSelectedColumns();

    final Map<String, String> queryParams = {
      "columns": selectedColumns.join(","),
    };

    if (filterApplied) {
      if (fromDateController.text.trim().isNotEmpty) {
        queryParams["from_date"] = _toApiDate(fromDateController.text.trim());
      }

      if (toDateController.text.trim().isNotEmpty) {
        queryParams["to_date"] = _toApiDate(toDateController.text.trim());
      }

      if (selectedItem != null && selectedItem!.trim().isNotEmpty) {
        queryParams["customer_id"] = selectedItem!.trim();
      }
    }

    return Uri.parse(ApiConstants.Approval_Outstanding_report)
        .replace(queryParameters: queryParams)
        .toString();
  }

  // ============================================================
  // BUILD PDF URL
  // ============================================================

  String buildPdfUrl() {
    final selectedColumns = getSelectedColumns();

    final Map<String, String> queryParams = {
      "columns": selectedColumns.join(","),
    };

    if (filterApplied) {
      if (fromDateController.text.trim().isNotEmpty) {
        queryParams["from_date"] = fromDateController.text.trim();
      }

      if (toDateController.text.trim().isNotEmpty) {
        queryParams["to_date"] = toDateController.text.trim();
      }

      if (selectedItem != null && selectedItem!.trim().isNotEmpty) {
        queryParams["customer_id"] = selectedItem!.trim();
      }
    }

    return Uri.parse(ApiConstants.Approval_Outstanding_report_pdf)
        .replace(queryParameters: queryParams)
        .toString();
  }

  // ============================================================
  // 🔥 BUILD BRANCH PDF URL
  // company/branch-reports/approval-outstanding
  //   ?report_branches=slug1,slug2&export=pdf&columns=...
  // ============================================================

  String buildBranchPdfUrl() {
    // Comma encode na thay (%2C) etle URL hathe banaviye
    final String branches =
    _appliedBranchSlugs.map(Uri.encodeQueryComponent).join(",");

    final String columns =
    getSelectedColumns().map(Uri.encodeQueryComponent).join(",");

    return "$branchApprovalOutstandingUrl"
        "?report_branches=$branches"
        "&export=pdf"
        "&columns=$columns";
  }

  // ============================================================
  // BUILD EXCEL URL
  // ============================================================

  String buildExcelUrl() {
    final selectedColumns = getSelectedColumns();

    final Map<String, String> queryParams = {
      "columns": selectedColumns.join(","),
    };

    if (filterApplied) {
      if (fromDateController.text.trim().isNotEmpty) {
        queryParams["from_date"] = fromDateController.text.trim();
      }

      if (toDateController.text.trim().isNotEmpty) {
        queryParams["to_date"] = toDateController.text.trim();
      }

      if (selectedItem != null && selectedItem!.trim().isNotEmpty) {
        queryParams["customer_id"] = selectedItem!.trim();
      }
    }

    return Uri.parse(ApiConstants.Approval_Outstanding_report_excel)
        .replace(queryParameters: queryParams)
        .toString();
  }

  // ============================================================
  // DATE PICKER
  // ============================================================

  Future<void> _selectDate(TextEditingController controller) async {
    DateTime initialDate = DateTime.now();

    try {
      if (controller.text.trim().isNotEmpty) {
        initialDate = _convertToDate(controller.text.trim());
      }
    } catch (_) {
      initialDate = DateTime.now();
    }

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      controller.text = "${picked.day.toString().padLeft(2, '0')}-"
          "${picked.month.toString().padLeft(2, '0')}-"
          "${picked.year}";
    }
  }

  // ============================================================
  // SEARCH USER
  // ============================================================

  void searchUser(String value) {
    if (value.isEmpty) {
      setState(() {
        userlist = allUsers;
      });
      return;
    }

    List filteredList = allUsers.where((user) {
      final name = user["name"]?.toString().toLowerCase() ?? "";

      final role = user["role"]?.toString().toLowerCase() ?? "";

      final customer = (_customerName(user) ?? "").toLowerCase();

      final voucher = (user["approval_no"] ?? user["voucher_no"])
          ?.toString()
          .toLowerCase() ??
          "";

      final searchValue = value.toLowerCase();

      return name.contains(searchValue) ||
          role.contains(searchValue) ||
          customer.contains(searchValue) ||
          voucher.contains(searchValue);
    }).toList();

    setState(() {
      userlist = filteredList;
      summaryTotals = calculateTotals(filteredList);
    });
  }

  // ============================================================
  // DATE FILTER
  // ============================================================

  Future<void> applyDateFilter() async {
    if (fromDateController.text.trim().isEmpty ||
        toDateController.text.trim().isEmpty) {
      return;
    }

    try {
      final fromDate = _convertToDate(fromDateController.text.trim());
      final toDate = _convertToDate(toDateController.text.trim());

      if (fromDate.isAfter(toDate)) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("From Date cannot be greater than To Date"),
          ),
        );

        return;
      }
    } catch (e) {
      return;
    }

    setState(() {
      filterApplied = true;
      isLoading = true;

      // "Show" = pela jevo normal report (branch report bandh)
      appliedCompanyIds = [];
      branchPage = 1;
      branchHasMore = false;
    });

    try {
      await Salesumryreport();
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // PERMISSIONS
  // ============================================================

  Future<void> loadPermissions() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    List<String> perms = prefs.getStringList("user_permissions") ?? [];

    if (!mounted) return;

    setState(() {
      userPermissions = perms;
    });
  }

  bool hasPermission(String permissionName) {
    return userPermissions.contains(permissionName);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (!(hasPermission("report-sales-summary-view") ||
        hasPermission("report-sales-summary-manage"))) {
      return Scaffold(
        body: PermissionDeniedWidget(
          onBack: () => Navigator.pop(context),
        ),
      );
    }

    final size = MediaQuery.of(context).size;

    final height = size.height;
    final width = size.width;

    final isMobile = width < 600;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: const Color(0xffF5F7FB),
        body: Stack(
          children: [
            Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top + 50),

                /// 🔥 AAKHI SCREEN SCROLL THAY
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 🔥 Branch Reports tab sauthi upar
                        branchReportWidget(),
                        const SizedBox(height: 8),

                        filterWidget(),

                        summaryStatsWidget(),

                        customReportColumnsWidget(),

                        Container(
                          margin: const EdgeInsets.only(
                              top: 10, left: 10, right: 10),
                          width: double.infinity,
                          height: 1.5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryDark.withOpacity(0.05),
                                AppColors.primaryDark,
                                AppColors.secondaryDark,
                                AppColors.primaryDark.withOpacity(0.05),
                              ],
                            ),
                          ),
                        ),

                        buildDataTableSection(),

                        if (branchMode && branchHasMore) _loadMoreButton(),

                        SizedBox(height: height * 0.02),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ==================================================
            // TOP HEADER
            // ==================================================

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(
                  top: 30,
                  left: 14,
                  right: 14,
                  bottom: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Text(
                      "Approval Outstanding",
                      style: TextStyle(
                        color: Color(0xff172033),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HomeScreen(),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: EdgeInsets.all(isMobile ? 7 : 9),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryDark,
                                AppColors.secondaryDark,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryDark.withOpacity(0.18),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: isMobile ? 19 : 22,
                          ),
                        ),
                      ),
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

  // ============================================================
  // 🔥 CUSTOM REPORT COLUMNS — 3 LINES + HORIZONTAL SCROLL
  // ============================================================

  Widget customReportColumnsWidget() {
    /// 🔥 કેટલી lines માં બતાવવું
    const int lineCount = 3;

    final int perLine = (reportColumns.length / lineCount).ceil();

    final List<List<Map<String, String>>> lines = [
      for (int i = 0; i < reportColumns.length; i += perLine)
        reportColumns.sublist(
          i,
          (i + perLine) > reportColumns.length
              ? reportColumns.length
              : i + perLine,
        ),
    ];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Custom Report Columns",
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (columnsLoading)
                SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryDark,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: lines.map((line) {
                return TableRow(
                  children: List.generate(perLine, (i) {
                    if (i >= line.length) return const SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: _columnCheckItem(line[i]),
                    );
                  }),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// =========================================================
  /// 🔥 એક checkbox + label
  /// =========================================================
  Widget _columnCheckItem(Map<String, String> c) {
    final String key = c["label"]!;

    final bool isFixed = key == "Approval No";

    final bool isSelected = isFixed ? true : (columnVisibility[key] ?? false);

    final bool disabled = isFixed || columnsLoading;

    final Color boxColor =
    isFixed ? Colors.grey.shade400 : AppColors.gradientBlue;

    return InkWell(
      onTap: disabled
          ? null
          : () async {
        setState(() {
          columnVisibility[key] = !isSelected;
          columnsLoading = true;
        });

        await Salesumryreport();

        if (!mounted) return;

        setState(() => columnsLoading = false);
      },
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: isSelected ? boxColor : Colors.white,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: isSelected ? boxColor : Colors.grey.shade500,
                  width: 1.3,
                ),
              ),
              child: isSelected
                  ? const Icon(
                Icons.check_rounded,
                size: 12,
                color: Colors.white,
              )
                  : null,
            ),
            const SizedBox(width: 6),
            Text(
              key,
              style: TextStyle(
                fontSize: 12.5,
                color: isFixed ? Colors.black45 : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TABLE
  // ============================================================

  Widget buildDataTableSection() {
    final List<Map<String, String>> columnFieldMap = reportColumns;

    final visibleColumns = columnFieldMap
        .where((c) => columnVisibility[c["label"]] == true)
        .toList();

    // 🔥 Branch report ma kai branch nu approval chhe e column
    if (branchMode) {
      visibleColumns.insert(
        visibleColumns.isEmpty ? 0 : 1,
        const {"label": "Branch", "key": "branch"},
      );
    }

    double minColWidth(String label) {
      switch (label) {
        case "Approval No":
          return 120;
        case "Branch":
          return 130;
        case "Customer":
          return 150;
        case "Created By":
          return 120;
        case "Date":
          return 95;
        case "Remarks":
          return 130;
        case "Status":
          return 100;
        case "Other Amount":
        case "Pending Amount":
          return 125;
        case "Pending Pcs":
          return 100;
        case "Purity":
        case "Waste %":
          return 85;
        case "Fine Wt":
          return 100;
        case "Metal Rate":
        case "Labour Rate":
          return 105;
        case "Metal Amt":
        case "Labour Amt":
        case "Total":
          return 120;
        default:
          return 95;
      }
    }

    const double srWidth = 55;
    const double dividerWidth = 1;

    final totalKeyMap = {
      "Pending Pcs": "pending_pcs",
      "Gross Wt": "gross_weight",
      "Other Wt": "other_weight",
      "Net Wt": "net_weight",
      "Fine Wt": "fine_weight",
      "Metal Amt": "metal_amount",
      "Labour Amt": "labour_amount",
      "Other Amount": "other_amount",
      "Pending Amount": "pending_amount",
      "Total": "net_total",
    };

    final headerStyle = TextStyle(
      color: AppColors.primaryDark,
      fontSize: 12.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.15,
    );

    const bodyStyle = TextStyle(
      color: Color(0xff303744),
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
    );

    final totalStyle = TextStyle(
      color: AppColors.primaryDark,
      fontSize: 12.5,
      fontWeight: FontWeight.w800,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isLoading
          ? const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      )
          : userlist.isEmpty
          ? _emptyDataWidget()
          : ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double availableWidth = constraints.maxWidth;

            final int totalDividers =
            visibleColumns.isEmpty ? 0 : visibleColumns.length;

            final double dividersTotalWidth =
                totalDividers * dividerWidth;

            final double neededWidth = srWidth +
                visibleColumns.fold(
                  0.0,
                      (sum, c) => sum + minColWidth(c["label"]!),
                ) +
                dividersTotalWidth;

            final bool fitsScreen = neededWidth <= availableWidth;

            double srColWidth = srWidth;

            Map<String, double> colWidths = {};

            if (fitsScreen) {
              final double extra = availableWidth - neededWidth;

              final double extraPerCol = visibleColumns.isEmpty
                  ? 0
                  : extra / visibleColumns.length;

              for (var c in visibleColumns) {
                colWidths[c["label"]!] =
                    minColWidth(c["label"]!) + extraPerCol;
              }
            } else {
              for (var c in visibleColumns) {
                colWidths[c["label"]!] = minColWidth(c["label"]!);
              }
            }

            final double tableWidth = srColWidth +
                colWidths.values.fold(0.0, (a, b) => a + b) +
                dividersTotalWidth;

            Widget buildRow({
              required String srText,
              required List<String> values,
              required TextStyle style,
              Color? bgColor,
              Gradient? gradient,
              Map<String, dynamic>? user,
            }) {
              return Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  gradient: gradient,
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: srColWidth,
                        child:
                        _tableCell(srText, style, center: true),
                      ),
                      VerticalDivider(
                        width: dividerWidth,
                        thickness: 1,
                        color: Colors.grey.shade200,
                      ),
                      for (int i = 0;
                      i < visibleColumns.length;
                      i++) ...[
                        SizedBox(
                          width:
                          colWidths[visibleColumns[i]["label"]!]!,
                          child: visibleColumns[i]["label"] ==
                              "Approval No" &&
                              user != null
                              ? InkWell(
                            onTap: () {
                              showVoucherDetailsDialog(user);
                            },
                            borderRadius:
                            BorderRadius.circular(4),
                            child: _tableCell(
                              values[i],
                              style.copyWith(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w700,
                                decoration:
                                TextDecoration.underline,
                                decorationColor:
                                Colors.blue.shade700,
                              ),
                              center: false,
                            ),
                          )
                              : _tableCell(
                            values[i],
                            style,
                            center: visibleColumns[i]
                            ["label"] ==
                                "Pending Pcs",
                          ),
                        ),
                        if (i != visibleColumns.length - 1)
                          VerticalDivider(
                            width: dividerWidth,
                            thickness: 1,
                            color: Colors.grey.shade200,
                          ),
                      ],
                    ],
                  ),
                ),
              );
            }

            // HEADER
            final headerRow = buildRow(
              srText: "Sr No",
              values:
              visibleColumns.map((c) => c["label"]!).toList(),
              style: headerStyle,
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryDark.withOpacity(0.055),
                  AppColors.secondaryDark.withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            );

            // TOTAL ROW
            Widget? totalRow;

            if (summaryTotals != null) {
              final values = <String>[];

              for (int i = 0; i < visibleColumns.length; i++) {
                final c = visibleColumns[i];

                if (i == 0) {
                  values.add("Total");
                } else if (totalKeyMap.containsKey(c["label"])) {
                  final raw =
                  summaryTotals![totalKeyMap[c["label"]]];

                  final double value = raw is num
                      ? raw.toDouble()
                      : double.tryParse(raw?.toString() ?? "") ?? 0;

                  final int decimals =
                  _getColumnDecimals(c["key"]!, c["label"]!);

                  values.add(value.toStringAsFixed(decimals));
                } else {
                  values.add("");
                }
              }

              totalRow = buildRow(
                srText: "",
                values: values,
                style: totalStyle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryDark.withOpacity(0.07),
                    AppColors.secondaryDark.withOpacity(0.10),
                  ],
                ),
              );
            }

            // BODY ROWS (page scroll sathe)
            final List<Widget> bodyRows = [];

            for (int index = 0; index < userlist.length; index++) {
              final user = userlist[index];

              final values = visibleColumns
                  .map((c) => _getFieldValue(user, c["key"]!))
                  .toList();

              bodyRows.add(
                buildRow(
                  srText: "${index + 1}",
                  values: values,
                  style: bodyStyle,
                  user: Map<String, dynamic>.from(user),
                  bgColor: index.isEven
                      ? Colors.white
                      : const Color(0xffF9FAFC),
                ),
              );
              bodyRows.add(Divider(height: 1, color: Colors.grey.shade200));
            }

            Widget tableColumn = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                headerRow,
                Divider(height: 1, color: Colors.grey.shade300),
                ...bodyRows,
                if (totalRow != null) ...[
                  Divider(height: 1, color: Colors.grey.shade300),
                  totalRow,
                ],
              ],
            );

            if (fitsScreen) {
              return SizedBox(
                width: availableWidth,
                child: tableColumn,
              );
            }

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: tableWidth, child: tableColumn),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // API COLUMN DECIMALS
  // ============================================================

  int _getColumnDecimals(String key, String label) {
    for (final column in apiColumns) {
      if (column["key"]?.toString() == key) {
        final decimals = column["decimals"];

        if (decimals is num) return decimals.toInt();

        if (decimals != null) {
          return int.tryParse(decimals.toString()) ?? 2;
        }
      }
    }

    if (label == "Pending Pcs") return 0;

    if (label.contains("Wt")) return 3;

    return 2;
  }

  // ============================================================
  // EMPTY DATA
  // ============================================================

  Widget _emptyDataWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withOpacity(0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 38,
              color: AppColors.primaryDark.withOpacity(0.65),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "No Data Found",
            style: TextStyle(
              fontSize: 15,
              color: Color(0xff687080),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            "Try changing your filters or selected columns",
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TABLE CELL
  // ============================================================

  Widget _tableCell(String text, TextStyle style, {bool center = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
      child: Align(
        alignment: center ? Alignment.center : Alignment.centerLeft,
        child: Text(
          text,
          style: style,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ),
    );
  }

  // ============================================================
  // FIELD VALUE
  // ============================================================

  String _getFieldValue(Map user, String key) {
    dynamic value;

    switch (key) {
      case "date":
        value = user["date"] ?? user["sale_date"];

        if (value == null || value.toString().trim().isEmpty) {
          return "-";
        }

        return formatDate(value.toString());

      case "customer":
        value = _customerName(user);
        break;

      case "created_by":
        value = user["created_by"];
        if (value is Map) value = value["name"];
        value ??= user["creator"] is Map ? user["creator"]["name"] : null;
        break;

      case "branch":
        value = _branchNameOf(user);
        break;

      default:
        value = user[key];
    }

    if (value == null || value is Map || value.toString().trim().isEmpty) {
      return "-";
    }

    return value.toString();
  }

  /// Customer naam — branch report ma "customer" aakho object aave chhe
  String? _customerName(Map user) {
    final dynamic byName = user["customer_name"];
    if (byName != null && byName.toString().trim().isNotEmpty) {
      return byName.toString();
    }
    final dynamic c = user["customer"];
    if (c is Map) return c["name"]?.toString();
    if (c != null && c.toString().trim().isNotEmpty) return c.toString();
    return null;
  }

  /// Approval kai branch nu chhe — company_id thi branch list mathi naam
  String? _branchNameOf(Map user) {
    final int? companyId = int.tryParse("${user["company_id"] ?? ""}");
    if (companyId != null) {
      for (final c in branchCompanies) {
        if (c.id == companyId) return c.name;
      }
    }
    final dynamic b = user["branch"] ?? user["branch_name"] ?? user["company"];
    if (b is Map) return b["name"]?.toString();
    return (b ?? user["company_name"])?.toString();
  }

  // ============================================================
  // REPORT API
  // ============================================================

  Future<void> Salesumryreport() async {
    try {
      final List<String> selectedColumns = getSelectedColumns();

      if (selectedColumns.isEmpty) {
        if (!mounted) return;

        setState(() {
          userlist = [];
          allUsers = [];
          summaryTotals = {};
          apiColumns = [];
        });

        return;
      }

      // 🔥 Branch report chalu hoy to branch API
      if (branchMode) {
        await _loadBranchReport();
        return;
      }

      final String url = buildSalesSummaryUrl();

      debugPrint("🔥 APPROVAL OUTSTANDING API: $url");

      final response = await ApiHelper().getRequest(url);

      if (response != null && response.statusCode == 200) {
        final data = response.data;

        final List<dynamic> categories =
        data["data"] is List ? List<dynamic>.from(data["data"]) : [];

        final Map<String, dynamic> apiTotals = data["totals"] is Map
            ? Map<String, dynamic>.from(data["totals"])
            : calculateTotals(categories);

        final List<Map<String, dynamic>> returnedColumns =
        data["columns"] is List
            ? (data["columns"] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
            : [];

        if (!mounted) return;

        setState(() {
          userlist = categories;
          allUsers = categories;
          summaryTotals = apiTotals;
          apiColumns = returnedColumns;
        });

        searchController.clear();
        searchResults.clear();

        debugPrint("✅ Approval Outstanding Loaded: ${categories.length}");
        debugPrint("✅ API Columns: $returnedColumns");

        if (categories.isEmpty && filterApplied && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "No records found for the selected customer/date range",
              ),
            ),
          );
        }
      } else {
        debugPrint(
          "❌ Approval Outstanding API failed | Status: ${response?.statusCode}",
        );

        if (!mounted) return;

        setState(() {
          userlist = [];
          allUsers = [];
          summaryTotals = {};
          apiColumns = [];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Failed to load report (status: ${response?.statusCode})",
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ Approval Outstanding API Exception: $e");

      if (!mounted) return;

      setState(() {
        userlist = [];
        allUsers = [];
        summaryTotals = {};
        apiColumns = [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Something went wrong: $e")),
      );
    }
  }

  // ============================================================
  // 🔥 BRANCH REPORTS (expand tab)
  // ============================================================

  Widget branchReportWidget() {
    if (branchesLoading) {
      return Container(
        margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
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
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
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
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
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
                  "Load More (${allUsers.length} loaded)",
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

  // ============================================================
  // DELETE DIALOG
  // ============================================================

  void _showDeleteDialog(Map user) {
    showGeneralDialog(
      context: context,
      barrierLabel: "Delete",
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        final screenWidth = MediaQuery.of(context).size.width;

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Center(
            child: Container(
              width: screenWidth * 0.85,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                color: Colors.white,
                border: Border.all(color: Colors.blue.shade100),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xffff4e50), Color(0xfff00000)],
                      ),
                    ),
                    child: const Icon(
                      Icons.delete,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "Delete Sale?",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Are you sure you want to delete this sale?",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 25),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade200,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "Cancel",
                            style: TextStyle(color: Colors.black87),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xfff00000),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () async {
                            Navigator.pop(context);
                            deleteUser(user["id"].toString());
                          },
                          child: const Text(
                            "Delete",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
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
      transitionBuilder: (context, anim, _, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
    );
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> deleteUser(String ID) async {
    try {
      final response = await ApiHelper().deleteRequest(
        "${ApiConstants.delete_users}/$ID",
      );

      if (response?.statusCode == 200) {
        await Salesumryreport();
      } else {
        debugPrint("❌ Delete failed | Status: ${response?.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Delete exception: $e");
    }
  }

  // ============================================================
  // FILTER WIDGET
  // ============================================================

  Widget filterWidget() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // CUSTOMER
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Consumer<ItemProvider>(
              builder: (context, provider, child) {
                final customers = provider.customers;

                return DropdownButtonFormField<String>(
                  value: selectedItem != null &&
                      customers.any(
                            (e) => e["id"].toString() == selectedItem,
                      )
                      ? selectedItem
                      : null,
                  dropdownColor: Colors.white,
                  hint: Text(
                    "Select Customer",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.primaryDark,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                      size: 20,
                      color: AppColors.primaryDark,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: BorderSide(
                        color: AppColors.primaryDark.withOpacity(0.5),
                      ),
                    ),
                  ),
                  items: customers.map<DropdownMenuItem<String>>((item) {
                    return DropdownMenuItem<String>(
                      value: item["id"].toString(),
                      child: Text(
                        item["name"] ?? "",
                        style: const TextStyle(color: Colors.black),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedItem = value;
                      filterApplied = false;
                    });
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 7),

          // DATE
          Row(
            children: [
              Expanded(
                child: _dateField(
                  controller: fromDateController,
                  hint: "From Date",
                  onTap: () => _selectDate(fromDateController),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _dateField(
                  controller: toDateController,
                  hint: "To Date",
                  onTap: () => _selectDate(toDateController),
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          // BUTTONS
          Row(
            children: [
              Expanded(
                child: customButton(
                  title: "Show",
                  icon: Icons.visibility_rounded,
                  gradient: LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.secondaryDark],
                  ),
                  onTap: applyDateFilter,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: customButton(
                  title: "PDF",
                  icon: Icons.picture_as_pdf_rounded,
                  gradient: const LinearGradient(
                    colors: [Color(0xffE57373), Color(0xffD32F2F)],
                  ),
                  onTap: openPdf,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: customButton(
                  title: "Excel",
                  icon: Icons.table_chart_rounded,
                  gradient: const LinearGradient(
                    colors: [Color(0xff66BB6A), Color(0xff2E7D32)],
                  ),
                  onTap: () => openexel(Code.toString()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY STATS ROW
  // ============================================================

  num _totalValue(List<String> keys) {
    if (summaryTotals == null) return 0;

    for (final key in keys) {
      final raw = summaryTotals![key];

      if (raw == null) continue;

      if (raw is num) return raw;

      final parsed = num.tryParse(raw.toString());

      if (parsed != null) return parsed;
    }

    return 0;
  }

  Widget summaryStatsWidget() {
    if (summaryTotals == null) {
      return const SizedBox.shrink();
    }

    final List<Map<String, dynamic>> stats = [
      {"label": "Voucher Count", "value": userlist.length, "decimals": 0},
      {
        "label": "Pending Pcs",
        "value": _totalValue(["pending_pcs", "qty_pcs"]),
        "decimals": 0,
      },
      {
        "label": "Pending Gross Wt",
        "value": _totalValue(["pending_gross_weight", "gross_weight"]),
        "decimals": 3,
      },
      {
        "label": "Pending Other Wt",
        "value": _totalValue(["pending_other_weight", "other_weight"]),
        "decimals": 3,
      },
      {
        "label": "Pending Net Wt",
        "value": _totalValue(["pending_net_weight", "net_weight"]),
        "decimals": 3,
      },
      {
        "label": "Pending Other Amount",
        "value": _totalValue(["pending_other_amount", "other_amount"]),
        "decimals": 2,
      },
      {
        "label": "Pending Amount",
        "value": _totalValue(["pending_amount"]),
        "decimals": 2,
      },
    ];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xff1E2233),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (int i = 0; i < stats.length; i++) ...[
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: "${stats[i]["label"]}: ",
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: (stats[i]["value"] as num)
                          .toStringAsFixed(stats[i]["decimals"] as int),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (i != stats.length - 1) const SizedBox(width: 26),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DATE FIELD
  // ============================================================

  Widget _dateField({
    required TextEditingController controller,
    required String hint,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: IgnorePointer(
        child: TextField(
          controller: controller,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.calendar_month_rounded,
              size: 19,
              color: AppColors.primaryDark,
            ),
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
            const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: BorderSide(
                color: AppColors.primaryDark.withOpacity(0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CUSTOM BUTTON
  // ============================================================

  Widget customButton({
    required String title,
    IconData? icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 17, color: Colors.white),
              const SizedBox(width: 5),
            ],
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PREMIUM ICON BUTTON
  // ============================================================

  Widget premiumIconBtn(
      IconData icon,
      Color color, {
        required VoidCallback onTap,
      }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Icon(icon, color: color, size: 19),
      ),
    );
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String formatDate(String date) {
    try {
      final value = date.trim();

      if (value.isEmpty) return "-";

      final datePart = value.split(" ")[0];
      final parts = datePart.split("-");

      if (parts.length == 3) {
        if (parts[0].length == 4) {
          return "${parts[2]}-${parts[1]}-${parts[0]}";
        }
        return datePart;
      }

      return value;
    } catch (e) {
      return date;
    }
  }

  // ============================================================
  // CONVERT DATE
  // ============================================================

  DateTime _convertToDate(String input) {
    final parts = input.trim().split("-");

    if (parts.length != 3) {
      throw FormatException("Invalid date: $input");
    }

    return DateTime(
      int.parse(parts[2]),
      int.parse(parts[1]),
      int.parse(parts[0]),
    );
  }

  // ============================================================
  // SEARCH API
  // ============================================================

  Future<void> searchItemsApi(String keyword) async {
    if (keyword.isEmpty) {
      setState(() => items = []);
      return;
    }

    final response = await ApiHelper().getRequest(
      "${ApiConstants.Barcode_report}/suggest?q=$keyword",
    );

    if (response != null && response.statusCode == 200) {
      setState(() {
        searchResults = response.data["data"];
      });
    } else {
      debugPrint("Search API Failed");
    }
  }

  // ============================================================
  // PDF
  // ============================================================

  Future<void> openPdf() async {
    try {
      if (getSelectedColumns().isEmpty) {
        debugPrint("❌ Please select at least one column");
        return;
      }

      // 🔥 Branch merge report hoy to branch PDF URL, nahi to pela jevu
      final String url = branchMode ? buildBranchPdfUrl() : buildPdfUrl();

      debugPrint("🔥 APPROVAL OUTSTANDING PDF API: $url");

      final response = await ApiHelper().getPdfRequest(url);

      if (response != null && response.statusCode == 200) {
        final dir = await getTemporaryDirectory();

        final file = File("${dir.path}/Approval Outstanding.pdf");

        await file.writeAsBytes(List<int>.from(response.data));

        await OpenFile.open(file.path);
      } else {
        debugPrint("PDF Download Failed: ${response?.statusCode}");
      }
    } catch (e) {
      debugPrint("PDF Error: $e");
    }
  }

  // ============================================================
  // EXCEL
  // ============================================================

  Future<void> openexel(String Code) async {
    try {
      // 🔥 Branch merge hoy to branch Excel, nahi to pela jevu
      final String url = branchMode ? buildBranchExcelUrl() : buildExcelUrl();

      debugPrint("🔥 APPROVAL OUTSTANDING EXCEL API: $url");

      final response = await ApiHelper().getPdfRequest(url);
      final dynamic data = response?.data;

      if (response == null || response.statusCode != 200) {
        debugPrint("Excel Download Failed: ${response?.statusCode}");
        if (mounted) AppMessage.error(context, "Unable to download Excel");
        return;
      }

      await _saveAndOpenExcel(data, "approval_outstanding.xlsx");
    } catch (e) {
      debugPrint("Excel Error: $e");
      if (mounted) {
        AppMessage.error(context, "Something went wrong while downloading Excel");
      }
    }
  }

  /// Branch merge Excel — direct Excel (id vagar), normal Excel URL j +
  /// &report_branches=slug1,slug2
  /// reports/approval-outstanding/excel?columns=..&report_branches=a,b
  String buildBranchExcelUrl() {
    final String branches =
    _appliedBranchSlugs.map(Uri.encodeQueryComponent).join(",");
    final String base = buildExcelUrl();
    final String sep = base.contains("?") ? "&" : "?";
    // Comma encode na thay (%2C) etle hathe umeriye
    return "$base${sep}report_branches=$branches";
  }

  /// Bytes save kari ne Excel kholo — kai khotu hoy to message batave
  Future<void> _saveAndOpenExcel(dynamic data, String fileName) async {
    if (data is! List<int> || data.isEmpty) {
      if (mounted) AppMessage.error(context, "Excel file is empty");
      return;
    }

    // Server e file ni jagyae JSON error mokli hoy to
    final String head =
    String.fromCharCodes(data.take(1)).trim();
    if (head == "{" || head == "<") {
      String msg = "Unable to download Excel";
      try {
        final dynamic j = jsonDecode(utf8.decode(data));
        if (j is Map && j["message"] != null) msg = j["message"].toString();
      } catch (_) {}
      debugPrint("❌ Excel server response: ${utf8.decode(data, allowMalformed: true)}");
      if (mounted) AppMessage.error(context, msg);
      return;
    }

    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/$fileName");
    await file.writeAsBytes(data, flush: true);

    final result = await OpenFile.open(file.path);
    debugPrint("📂 Excel open: ${result.type} ${result.message}");
    if (result.type != ResultType.done && mounted) {
      AppMessage.error(
        context,
        result.type == ResultType.noAppToOpen
            ? "No app found to open Excel file"
            : result.message,
      );
    }
  }

  // ============================================================
  // CALCULATE TOTALS
  // ============================================================

  Map<String, dynamic> calculateTotals(List data) {
    double pendingPcs = 0;
    double gross = 0;
    double otherWeight = 0;
    double net = 0;
    double fine = 0;
    double metal = 0;
    double labour = 0;
    double otherAmount = 0;
    double pendingAmount = 0;
    double total = 0;

    double toDouble(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0;
    }

    for (var item in data) {
      pendingPcs += toDouble(item["pending_pcs"]);
      gross += toDouble(item["gross_weight"]);
      otherWeight += toDouble(item["other_weight"]);
      net += toDouble(item["net_weight"]);
      fine += toDouble(item["fine_weight"]);
      metal += toDouble(item["metal_amount"]);
      labour += toDouble(item["labour_amount"]);
      otherAmount += toDouble(item["other_amount"]);
      pendingAmount += toDouble(item["pending_amount"]);
      total += toDouble(item["net_total"]);
    }

    return {
      "voucher_count": data.length,
      "pending_pcs": pendingPcs,
      "gross_weight": gross,
      "other_weight": otherWeight,
      "net_weight": net,
      "fine_weight": fine,
      "metal_amount": metal,
      "labour_amount": labour,
      "other_amount": otherAmount,
      "pending_amount": pendingAmount,
      "net_total": total,
    };
  }

  // ============================================================
  // 🔥 APPROVAL DETAILS
  // ============================================================

  Future<void> showVoucherDetailsDialog(Map<String, dynamic> user) async {
    if (_openingVoucher) return;

    // VOUCHER ID
    final dynamic voucherId =
        user["id"] ?? user["voucher_id"] ?? user["sales_summary_id"];

    if (voucherId == null || voucherId.toString().trim().isEmpty) {
      AppMessage.error(context, "Voucher ID not found");
      return;
    }

    // ITEM TABLE COLUMNS
    const List<String> defaultColumns = ["qr_code", "huid", "item"];

    const List<String> voucherLevelKeys = [
      "voucher_no",
      "date",
      "customer",
      "created_by",
    ];

    const List<String> excludedColumns = ["approval_no"];

    final List<String> mergedColumns = <String>{
      ...defaultColumns,
      ...getSelectedColumns()
          .where((k) => !voucherLevelKeys.contains(k))
          .where((k) => !excludedColumns.contains(k)),
    }.toList();

    final String selectedColumns = mergedColumns.join(",");

    // INFO ROW
    const List<String> alwaysShowInInfoRow = [
      "Approval No",
      "Date",
      "Customer",
    ];

    final List<MapEntry<String, String>> infoItems = reportColumns
        .where(
          (c) =>
      alwaysShowInInfoRow.contains(c["label"]) ||
          columnVisibility[c["label"]] == true,
    )
        .map((c) => MapEntry(c["label"]!, _getFieldValue(user, c["key"]!)))
        .where((e) => alwaysShowInInfoRow.contains(e.key) || e.value != "-")
        .toList();

    // URL
    // 🔥 Biji company (branch) no approval hoy to:
    //   company/branch-report-details/approval/{id}?report_branches={slug}
    // Potani company no hoy to pela jevu j
    final Company? other = _otherCompanyOf(user);
    final String? branchSlug =
    other == null ? null : (other.slug ?? other.id.toString());

    // 🔥 Sale Summary jevu j — biji company hoy to + &report_branches=all
    //   reports/approval-outstanding/{id}/details?columns=..&report_branches=all
    final String url = Uri.parse(
      "${ApiConstants.baseUrl}reports/approval-outstanding/$voucherId/details",
    ).replace(queryParameters: {
      "columns": selectedColumns,
      if (branchSlug != null) "report_branches": "all",
    }).toString();

    debugPrint("APPROVAL DETAILS URL => $url");

    _openingVoucher = true;

    // LOADER
    bool loaderOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    void closeLoader() {
      if (!loaderOpen) return;
      loaderOpen = false;
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }

    dynamic responseData;
    bool ok = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final String token = prefs.getString("token") ?? "";

      final Response response = await Dio().get(
        url,
        options: Options(
          headers: {
            "Authorization": "Bearer $token",
            "Accept": "application/json",
          },
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      debugPrint("APPROVAL DETAILS STATUS => ${response.statusCode}");
      debugPrint("APPROVAL DETAILS RESPONSE => ${response.data}");

      responseData = response.data;

      if (responseData is String) {
        try {
          responseData = jsonDecode(responseData);
        } catch (e) {
          debugPrint("JSON Decode Error: $e");
        }
      }

      if (responseData is! Map) {
        closeLoader();
        if (mounted) {
          AppMessage.error(context, "Invalid response from server");
        }
      } else if (responseData["success"] == false) {
        closeLoader();
        if (mounted) {
          AppMessage.error(
            context,
            responseData["message"]?.toString() ??
                "Unable to load approval details",
          );
        }
      } else {
        ok = true;
      }
    } on DioException catch (e) {
      debugPrint("APPROVAL DETAILS DIO ERROR => ${e.type} | ${e.message}");
      debugPrint("STATUS => ${e.response?.statusCode}");
      debugPrint("RESPONSE => ${e.response?.data}");

      closeLoader();

      String message = "Unable to load approval details";

      final dynamic errData = e.response?.data;

      if (errData is Map && errData["message"] != null) {
        message = errData["message"].toString();
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        message = "Server is taking too long. Please try again.";
      } else if (e.type == DioExceptionType.connectionError) {
        message = "No internet connection";
      }

      if (mounted) AppMessage.error(context, message);
    } catch (e, stackTrace) {
      debugPrint("APPROVAL DETAILS ERROR => $e");
      debugPrint(stackTrace.toString());

      closeLoader();

      if (mounted) AppMessage.error(context, "Something went wrong");
    } finally {
      closeLoader();
      _openingVoucher = false;
    }

    if (!ok || !mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _VoucherDetailsDialog(
        responseData: responseData,
        voucherId: voucherId.toString(),
        selectedColumns: selectedColumns,
        infoItems: infoItems,
        branchSlug: branchSlug,
      ),
    );
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

  // UI date (dd-MM-yyyy) → API (yyyy-MM-dd)
  String _toApiDate(String uiDate) {
    try {
      final parts = uiDate.trim().split("-");
      if (parts.length == 3) {
        final day = parts[0].padLeft(2, '0');
        final month = parts[1].padLeft(2, '0');
        final year = parts[2];
        return "$year-$month-$day";
      }
    } catch (_) {}
    return uiDate;
  }
}

// ================================================================
// APPROVAL DETAILS DIALOG
// ================================================================

class _VoucherDetailsDialog extends StatefulWidget {
  final dynamic responseData;
  final String voucherId;
  final String selectedColumns;
  final List<MapEntry<String, String>> infoItems;

  /// Biji company (branch) no approval hoy to eno slug — nahi to null
  final String? branchSlug;

  const _VoucherDetailsDialog({
    required this.responseData,
    required this.voucherId,
    required this.selectedColumns,
    required this.infoItems,
    this.branchSlug,
  });

  @override
  State<_VoucherDetailsDialog> createState() => _VoucherDetailsDialogState();
}

class _VoucherDetailsDialogState extends State<_VoucherDetailsDialog> {
  final TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> allData = [];
  List<Map<String, dynamic>> filteredData = [];
  List<Map<String, dynamic>> columns = [];

  bool pdfLoading = false;
  bool excelLoading = false;

  static const Color bgDark = Color(0xff1E2233);
  static const Color headerDark = Color(0xff171A28);
  static const Color rowDarkA = Color(0xff242840);
  static const Color rowDarkB = Color(0xff2A2E48);
  static const Color borderColor = Color(0xff363B57);

  /// Checkbox key → item row નું સાચું field નામ
  static const Map<String, String> _keyAliasMap = {
    "net_total": "total_amount",
  };

  /// Value શોધવા માટે વૈકલ્પિક key નામો
  static const Map<String, List<String>> _valueAliasMap = {
    "item_name": [
      "item_name",
      "item",
      "name",
      "product_name",
      "design_name",
      "item_title",
      "particulars",
      "description",
      "item_desc",
    ],
    "pending_pcs": [
      "pending_pcs",
      "qty_pcs",
      "pcs",
      "quantity",
      "qty",
      "pending_qty",
      "pending_quantity",
      "item_pcs",
    ],
    "huid": ["huid", "huid_no", "huid_number"],
    "qr_code": ["qr_code", "qrcode", "barcode", "code"],
  };

  String _normalizeKey(String key) {
    return key.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
  }

  String _resolveRowValue(Map<String, dynamic> row, String key) {
    final List<String> candidates = _valueAliasMap[key] ?? [key];

    for (final candidate in candidates) {
      if (row.containsKey(candidate)) {
        final dynamic value = row[candidate];

        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
    }

    final String normalizedTarget = _normalizeKey(key);

    for (final entry in row.entries) {
      if (_normalizeKey(entry.key) == normalizedTarget) {
        final dynamic value = entry.value;

        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
    }

    return "-";
  }

  static const Map<String, String> _localColumnLabels = {
    "qr_code": "QR Code",
    "huid": "HUID",
    "item": "Item",
    "item_name": "Item",
    "approval_no": "Approval No",
    "qty_pcs": "Qty",
    "purity": "Purity",
    "waste_percent": "Waste %",
    "pending_pcs": "Pending Pcs",
    "gross_weight": "Gross Wt",
    "other_weight": "Other Wt",
    "net_weight": "Net Wt",
    "fine_weight": "Fine Wt",
    "metal_rate": "Metal Rate",
    "labour_rate": "Labour Rate",
    "metal_amount": "Metal Amt",
    "labour_amount": "Labour Amt",
    "other_amount": "Other Amount",
    "pending_amount": "Pending Amount",
    "total_amount": "Total",
    "net_total": "Total",
    "remarks": "Remarks",
    "created_by": "Created By",
    "status": "Status",
  };

  @override
  void initState() {
    super.initState();
    _parseResponse();
    searchController.addListener(_applySearch);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _parseResponse() {
    Map<String, dynamic> response = {};

    if (widget.responseData is Map) {
      response = Map<String, dynamic>.from(widget.responseData);
    }

    // DATA
    // Normal: data = [ {row}, ... ]
    // 🔥 Branch: data = { number, date, type, lines: [ {source: {...}}, ... ] }
    final dynamic dataNode = response["data"];

    List<dynamic> rawData = [];
    if (dataNode is List) {
      rawData = List<dynamic>.from(dataNode);
    } else if (dataNode is Map) {
      final dynamic lines =
          dataNode["lines"] ?? dataNode["items"] ?? dataNode["data"];
      if (lines is List) rawData = List<dynamic>.from(lines);
    }

    allData = rawData
        .whereType<Map>()
        .map<Map<String, dynamic>>((e) => _flattenLine(Map<String, dynamic>.from(e)))
        .toList();

    // API COLUMNS (metadata)
    final List<Map<String, dynamic>> apiColumns = [];

    if (response["columns"] is List) {
      for (final column in response["columns"]) {
        if (column is Map) {
          apiColumns.add(Map<String, dynamic>.from(column));
        }
      }
    }

    // DEFAULT COLUMNS
    final List<Map<String, dynamic>> defaultColumns = [
      {"label": "QR Code", "key": "qr_code"},
      {"label": "HUID", "key": "huid"},
    ];

    const Set<String> hiddenColumns = {"approval_no", "pending_pcs"};

    final Map<String, Map<String, dynamic>> mergedColumns = {};

    for (final column in defaultColumns) {
      final String key = column["key"]?.toString() ?? "";

      if (key.isEmpty || hiddenColumns.contains(key)) continue;

      mergedColumns[key] = column;
    }

    final List<String> selectedKeys = widget.selectedColumns
        .split(",")
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .where((key) => !hiddenColumns.contains(key))
        .toList();

    for (final String rawKey in selectedKeys) {
      final String selectedKey = _keyAliasMap[rawKey] ?? rawKey;

      if (hiddenColumns.contains(selectedKey)) continue;

      if (mergedColumns.containsKey(selectedKey)) continue;

      Map<String, dynamic>? apiColumn;

      for (final column in apiColumns) {
        if (column["key"]?.toString() == selectedKey) {
          apiColumn = column;
          break;
        }
      }

      if (apiColumn != null) {
        mergedColumns[selectedKey] = apiColumn;
        continue;
      }

      mergedColumns[selectedKey] = {
        "label": _localColumnLabels[selectedKey] ??
            _formatColumnLabel(selectedKey),
        "key": selectedKey,
      };
    }

    columns = mergedColumns.values.toList();

    filteredData = List<Map<String, dynamic>>.from(allData);

    debugPrint(
      "FINAL TABLE COLUMNS: ${columns.map((e) => e["key"]).join(", ")}",
    );
  }

  /// 🔥 Branch line { source: {...}, item_set: {...} } ne ek sapat row ma
  /// fervo — normal row hoy to em ne em j rahe
  Map<String, dynamic> _flattenLine(Map<String, dynamic> line) {
    final dynamic src = line["source"];
    if (src is! Map) return line;

    final Map<String, dynamic> source = Map<String, dynamic>.from(src);
    final Map<String, dynamic> row = {
      // line na sada fields (amount vagere)
      for (final e in line.entries)
        if (e.value is! Map && e.value is! List) e.key: e.value,
      // source na fields (weights, rate, status ...)
      for (final e in source.entries)
        if (e.value is! Map && e.value is! List) e.key: e.value,
    };

    final dynamic itemSet = source["item_set"] ?? line["item_set"];
    final dynamic item = source["item"] ?? line["item"] ??
        (itemSet is Map ? itemSet["item"] : null);

    // QR / HUID
    if ((row["qr_code"] ?? "").toString().trim().isEmpty && itemSet is Map) {
      row["qr_code"] = itemSet["qr_code"] ?? itemSet["barcode"];
    }
    if ((row["huid"] ?? "").toString().trim().isEmpty && itemSet is Map) {
      row["huid"] = itemSet["HUID"] ?? itemSet["huid"];
    }

    // Item naam
    if (item is Map) {
      row["item"] = item["item_name"] ?? item["name"];
    } else if (item != null) {
      row["item"] = item;
    }
    row["item_name"] ??= row["item"];

    // Fine Wt
    row["fine_weight"] ??= source["total_fine_weight"];

    // Pending amount (pending hoy to total)
    row["pending_amount"] ??=
    (row["status"]?.toString().toLowerCase() == "pending")
        ? row["total_amount"]
        : 0;

    return row;
  }

  void _applySearch() {
    final String keyword = searchController.text.trim().toLowerCase();

    if (keyword.isEmpty) {
      setState(() {
        filteredData = List<Map<String, dynamic>>.from(allData);
      });
      return;
    }

    setState(() {
      filteredData = allData.where((row) {
        return row.values.any((value) {
          if (value == null) return false;
          return value.toString().toLowerCase().contains(keyword);
        });
      }).toList();
    });
  }

  /// 🔥 PDF / Excel URL (encode થયેલું, double slash વગર)
  /// 🔥 PDF / Excel URL — Sale Summary jevu j
  /// reports/approval-outstanding/{id}/details/pdf?columns=..
  /// Biji company (branch) no approval hoy to + &report_branches=all
  String _exportUrl(String type) {
    return Uri.parse(
      "${ApiConstants.baseUrl}reports/approval-outstanding/"
          "${widget.voucherId}/details/$type",
    ).replace(
      queryParameters: {
        "columns": widget.selectedColumns,
        if (widget.branchSlug != null) "report_branches": detailsReportBranches,
      },
    ).toString();
  }

  /// Biji company na approval na PDF / Excel mate report_branches
  static const String detailsReportBranches = "all";

  Future<void> _openPdf() async {
    if (pdfLoading) return;

    setState(() => pdfLoading = true);

    try {
      final String url = _exportUrl("pdf");

      debugPrint("🔥 APPROVAL DETAILS PDF API: $url");

      final response = await ApiHelper().getPdfRequest(url);

      if (response != null && response.statusCode == 200) {
        final dir = await getTemporaryDirectory();

        final file = File("${dir.path}/approval_${widget.voucherId}.pdf");

        await file.writeAsBytes(List<int>.from(response.data));

        await OpenFile.open(file.path);
      } else {
        if (mounted) AppMessage.error(context, "Unable to download PDF");
      }
    } catch (e) {
      debugPrint("Approval PDF Error: $e");

      if (mounted) {
        AppMessage.error(context, "Something went wrong while downloading PDF");
      }
    } finally {
      if (mounted) setState(() => pdfLoading = false);
    }
  }

  Future<void> _openExcel() async {
    if (excelLoading) return;

    setState(() => excelLoading = true);

    try {
      final String url = _exportUrl("excel");

      debugPrint("🔥 APPROVAL DETAILS EXCEL API: $url");

      final response = await ApiHelper().getPdfRequest(url);
      final dynamic data = response?.data;

      if (response == null || response.statusCode != 200) {
        if (mounted) AppMessage.error(context, "Unable to download Excel");
        return;
      }

      if (data is! List<int> || data.isEmpty) {
        if (mounted) AppMessage.error(context, "Excel file is empty");
        return;
      }

      // Server e file ni jagyae JSON / HTML error mokli hoy to
      final String head = String.fromCharCodes(data.take(1)).trim();
      if (head == "{" || head == "<") {
        String msg = "Unable to download Excel";
        try {
          final dynamic j = jsonDecode(utf8.decode(data));
          if (j is Map && j["message"] != null) msg = j["message"].toString();
        } catch (_) {}
        debugPrint(
            "❌ Excel server response: ${utf8.decode(data, allowMalformed: true)}");
        if (mounted) AppMessage.error(context, msg);
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/approval_${widget.voucherId}.xlsx");
      await file.writeAsBytes(data, flush: true);

      final result = await OpenFile.open(file.path);
      debugPrint("📂 Excel open: ${result.type} ${result.message}");
      if (result.type != ResultType.done && mounted) {
        AppMessage.error(
          context,
          result.type == ResultType.noAppToOpen
              ? "No app found to open Excel file"
              : result.message,
        );
      }
    } catch (e) {
      debugPrint("Approval Excel Error: $e");

      if (mounted) {
        AppMessage.error(
          context,
          "Something went wrong while downloading Excel",
        );
      }
    } finally {
      if (mounted) setState(() => excelLoading = false);
    }
  }


  double _colWidth(String key) {
    switch (key) {
      case "label":
        return 140;
      case "huid":
        return 130;
      case "item":
      case "item_name":
        return 160;
      case "approval_no":
        return 160;
      case "voucher_no":
        return 145;
      case "date":
        return 105;
      case "customer":
        return 180;
      case "gross_weight":
      case "other_weight":
      case "net_weight":
      case "fine_weight":
        return 110;
      case "qty_pcs":
      case "pending_pcs":
        return 90;
      case "status":
        return 100;
      case "purity":
      case "waste_percent":
        return 90;
      case "metal_rate":
      case "labour_rate":
        return 110;
      case "metal_amount":
      case "labour_amount":
      case "other_amount":
      case "pending_amount":
      case "net_total":
      case "total_amount":
        return 125;
      case "remarks":
        return 180;
      case "created_by":
        return 130;
      default:
        return 110;
    }
  }

  bool _isNumeric(String key) {
    return [
      "qty_pcs",
      "pending_pcs",
      "gross_weight",
      "other_weight",
      "net_weight",
      "purity",
      "waste_percent",
      "fine_weight",
      "metal_rate",
      "metal_amount",
      "labour_rate",
      "labour_amount",
      "other_amount",
      "pending_amount",
      "total_amount",
      "net_total",
    ].contains(key);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 600;

    return Dialog(
      insetPadding: EdgeInsets.all(isMobile ? 8 : 24),
      backgroundColor: bgDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: size.width * (isMobile ? 0.97 : 0.92),
        height: size.height * (isMobile ? 0.88 : 0.85),
        child: Column(
          children: [
            _buildHeader(isMobile),
            _buildInfoRow(isMobile),
            Expanded(
              child: filteredData.isEmpty
                  ? const Center(
                child: Text(
                  "No approval items found",
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
              )
                  : columns.isEmpty
                  ? const Center(
                child: Text(
                  "No columns found",
                  style:
                  TextStyle(fontSize: 14, color: Colors.white70),
                ),
              )
                  : Padding(
                padding: const EdgeInsets.all(12),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: _buildTable(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 18,
        vertical: 14,
      ),
      decoration: const BoxDecoration(
        color: headerDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Approval Details",
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 15 : 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _headerActionButton(
            label: "Excel",
            color: const Color(0xff3B82F6),
            loading: excelLoading,
            onTap: _openExcel,
          ),
          const SizedBox(width: 8),
          _headerActionButton(
            label: "PDF",
            color: const Color(0xffE53935),
            loading: pdfLoading,
            onTap: _openPdf,
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, color: Colors.white70, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerActionButton({
    required String label,
    required Color color,
    required bool loading,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(7),
        ),
        child: loading
            ? const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(bool isMobile) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 12 : 18,
        12,
        isMobile ? 12 : 18,
        8,
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 20,
        runSpacing: 10,
        children: [
          for (final item in widget.infoItems) _infoItem(item.key, item.value),
          SizedBox(
            width: isMobile ? double.infinity : 260,
            child: TextField(
              controller: searchController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                hintText: "Search QR, HUID, item, value...",
                hintStyle: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12.5,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Colors.white38,
                  size: 19,
                ),
                filled: true,
                fillColor: rowDarkA,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(color: Colors.white38),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem(String title, String value) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: "$title: ",
            style: const TextStyle(
              fontSize: 12.5,
              color: Colors.white54,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              fontSize: 12.5,
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    Widget buildCell(
        String text,
        double width, {
          bool header = false,
          bool right = false,
        }) {
      return Container(
        width: width,
        constraints: const BoxConstraints(minHeight: 42),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        alignment: right ? Alignment.centerRight : Alignment.centerLeft,
        decoration: const BoxDecoration(
          border: Border(
            right: BorderSide(color: borderColor),
            bottom: BorderSide(color: borderColor),
          ),
        ),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: header ? FontWeight.w800 : FontWeight.w600,
            color: Colors.white,
          ),
        ),
      );
    }

    const double srWidth = 55;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: headerDark,
            child: Row(
              children: [
                buildCell("#", srWidth, header: true),
                ...columns.map((column) {
                  final String key = column["key"]?.toString() ?? "";
                  final String label = column["label"]?.toString() ?? "";

                  return buildCell(
                    label,
                    _colWidth(key),
                    header: true,
                    right: _isNumeric(key),
                  );
                }),
              ],
            ),
          ),
          ...filteredData.asMap().entries.map((entry) {
            final int index = entry.key;
            final Map<String, dynamic> row = entry.value;

            return Container(
              color: index.isEven ? rowDarkA : rowDarkB,
              child: Row(
                children: [
                  buildCell("${index + 1}", srWidth),
                  ...columns.map((column) {
                    final String key = column["key"]?.toString() ?? "";

                    return buildCell(
                      _resolveRowValue(row, key),
                      _colWidth(key),
                      right: _isNumeric(key),
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatColumnLabel(String key) {
    return _localColumnLabels[key] ??
        key
            .replaceAll("_", " ")
            .split(" ")
            .map(
              (word) => word.isEmpty
              ? ""
              : "${word[0].toUpperCase()}${word.substring(1)}",
        )
            .join(" ");
  }
}
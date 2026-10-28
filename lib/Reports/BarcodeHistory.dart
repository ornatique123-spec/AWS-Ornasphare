import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pecifician_sysytem/Settings/BranchManagementScreen.dart'
    show BranchApi, Company, BranchTypeX;
import 'package:shared_preferences/shared_preferences.dart';
import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import '../Dashboard/HomeScreen.dart';
import '../Extra/AppColors.dart';
import '../Extra/AppMessage.dart';
import '../Extra/PermissionDeniedWidget.dart';
import 'BranchAccess.dart';

class Barcodehistory extends StatefulWidget {
  const Barcodehistory({super.key});

  @override
  State<Barcodehistory> createState() => _BarcodehistoryState();
}

class _BarcodehistoryState extends State<Barcodehistory> {
  TextEditingController searchController = TextEditingController();
  TextEditingController fromDateController = TextEditingController();
  TextEditingController toDateController = TextEditingController();
  List userlist = [];
  List<Map<String, dynamic>> items = [];
  List searchResults = [];
  bool isLoading = false;

  /// 🔥 EXPANDABLE CARD STATE — key = user id / label_code / index
  Map<String, bool> expandedMap = {};

  String? Code;
  Future<void> _selectDate(TextEditingController controller) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      controller.text =
      "${picked.day}-${picked.month}-${picked.year}";
    }
  }

  List allUsers = []; // 🔥 original data store

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



  void searchUser(String value) {
    if (value.isEmpty) {
      setState(() {
        userlist = allUsers; // reset
      });
      return;
    }

    List filteredList = allUsers.where((user) {
      final name = user["name"]?.toString().toLowerCase() ?? "";
      final role = user["role"]?.toString().toLowerCase() ?? "";

      return name.contains(value.toLowerCase()) ||
          role.contains(value.toLowerCase());
    }).toList();

    setState(() {
      userlist = filteredList;
    });
  }

  void applyDateFilter() {
    if (fromDateController.text.isEmpty ||
        toDateController.text.isEmpty) {
      setState(() {
        userlist = allUsers;
      });
      return;
    }

    DateTime fromDate = _convertToDate(fromDateController.text);
    DateTime toDate = _convertToDate(toDateController.text);

    List filtered = allUsers.where((user) {
      if (user["created_at"] == null) return false;

      DateTime userDate = DateTime.parse(user["created_at"]);

      return userDate.isAfter(fromDate.subtract(const Duration(days: 1))) &&
          userDate.isBefore(toDate.add(const Duration(days: 1)));
    }).toList();

    setState(() {
      userlist = filtered;
    });
  }

  List<String> userPermissions = [];   // 🔥 ADD
  Future<void> loadPermissions() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // 🔥 Full prefs debug
    Set<String> keys = prefs.getKeys();
    print("🔥 All SharedPreferences Keys: $keys");

    List<String> perms = prefs.getStringList("user_permissions") ?? [];
    print("🔥 user_permissions value: $perms");

    setState(() {
      userPermissions = perms;
    });
  }

  /// 🔥 Permission check helper
  bool hasPermission(String permissionName) {
    print("🔥 Checking '$permissionName' in $userPermissions => ${userPermissions.contains(permissionName)}");
    return userPermissions.contains(permissionName);
  }


  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    loadPermissions();

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
  @override
  Widget build(BuildContext context) {

    if(!(
        hasPermission("report-barcode-history-view") ||
            hasPermission("report-barcode-history-manage")
    )){
      return Scaffold(
        body: PermissionDeniedWidget(
          onBack: (){
            Navigator.pop(context);
          },
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
          MaterialPageRoute(
            builder: (_) => const HomeScreen(),
          ),
        );
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,  // ⭐ IMPORTANT FIX
        backgroundColor: AppColors.white,
        body: Stack(
          children: [

            /// 🔥 MAIN CONTENT
            Column(
              children: [

                /// IMPORTANT: top padding space leave karvu (AppBar mate)
                SizedBox(
                  height: MediaQuery.of(context).padding.top + 40,
                ),

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

                        Container(
                          margin: const EdgeInsets.only(top: 10),
                          width: double.infinity,
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryDark.withOpacity(0.1),
                                AppColors.primaryDark,
                                AppColors.secondaryDark.withOpacity(0.4),
                                AppColors.primaryDark.withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),

                        if (userlist.isEmpty)
                          const SizedBox(
                            height: 200,
                            child: Center(
                              child: Text(
                                "No Data Found",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              children: [
                                for (int i = 0; i < userlist.length; i++)
                                  buildUserCard(userlist[i], i),
                              ],
                            ),
                          ),

                        if (branchMode && branchHasMore) _loadMoreButton(),

                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),

              ],
            ),

            /// ✅ APPBAR (OVERLAY)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(
                  top: 30,
                  left: 16,
                  right: 16,
                  bottom: 16,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [

                    /// ✅ CENTER TITLE
                    const Text(
                      "Barcode History",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    /// ✅ LEFT BACK ICON
                    Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HomeScreen(),
                            ),
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.all(isMobile ? 6 : 8),
                          decoration: BoxDecoration(
                            color:AppColors.primaryDark,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: isMobile ? 20 : 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )

          ],
        ),
      ),
    );

  }


  /// 🔥 EXPANDABLE CARD
  /// Top (always visible): status chip + delete + expand arrow, item name + label code.
  /// Body (only when expanded): the ERP details grid.
  Widget buildUserCard(Map user, int index) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;

    final String cardKey =
    (user["id"] ?? user["label_code"] ?? index).toString();
    final bool isExpanded = expandedMap[cardKey] ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// ================= HEADER (ALWAYS VISIBLE / TAP TO EXPAND) =================
          InkWell(
            borderRadius: BorderRadius.circular(5),
            onTap: () {
              setState(() {
                expandedMap[cardKey] = !isExpanded;
              });
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // STATUS
                statusChip(
                  user["current_status"].toString(),
                ),

                const SizedBox(width: 10),

                // ITEM NAME
                Expanded(
                  flex: 2,
                  child: Text(
                    user["item_name"] ?? "",
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                const SizedBox(width: 10),

                // LABEL CODE
                Expanded(
                  flex: 1,
                  child: Text(
                    user["label_code"] ?? "",
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                const SizedBox(width: 8),

                // EXPAND / COLLAPSE ICON - ALWAYS LAST
                // EXPAND / COLLAPSE ICON - CIRCLE
                Container(
                  width: 25,
                  height: 25,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryDark.withOpacity(0.10),
                    border: Border.all(
                      color: AppColors.primaryDark.withOpacity(0.25),
                    ),
                  ),
                  child: Center(
                    child: AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: AppColors.primaryDark,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// ================= EXPANDABLE DETAILS (ERP GRID) =================
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            sizeCurve: Curves.easeInOut,
            crossFadeState:
            isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: EdgeInsets.only(top: isTablet ? 10 : 8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  border: Border.all(color: AppColors.border, width: 1.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  children: [

                    /// 🔥 Branch report ma kai branch nu chhe
                    if (branchMode) ...[
                      _erpRow("Branch", _branchNameOf(user), "", ""),
                      Divider(height: 1, color: AppColors.border),
                    ],

                    /// Row 1
                    _erpRow("Label Create", formatDate(user["label_created_at"]), "", ""),
                    Divider(height: 1, color: AppColors.border),

                    _erpRow("Label Print", formatDate(user["label_printed_at"].toString()), "", ""),
                    Divider(height: 1, color: AppColors.border),

                    _erpRow(
                      "Approval History",
                      user["approval_history"] != null && user["approval_history"].isNotEmpty
                          ? user["approval_history"][0]["label"]
                          : "-",
                      "",
                      "",
                      historyList: user["approval_history"] ?? [],
                    ),
                    Divider(height: 1, color: AppColors.border),

                    _erpRow(
                      "Sale History",
                      user["sale_history"] != null && user["sale_history"].isNotEmpty
                          ? user["sale_history"][0]["label"]
                          : "-",
                      "",
                      "",
                      historyList: user["sale_history"] ?? [],
                    ),
                    Divider(height: 1, color: AppColors.border),

                    _erpRow(
                      "Return History",
                      user["return_history"] != null && user["return_history"].isNotEmpty
                          ? user["return_history"][0]["label"]
                          : "-",
                      "",
                      "",
                      historyList: user["return_history"] ?? [],
                    ),

                    /// Row 2
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 🔥 REPORT LOAD — branch hoy to branch API, nahi to normal
  // ============================================================

  bool get _hasCode =>
      Code != null && Code!.trim().isNotEmpty && Code != "null";

  Future<void> loadReport() async {
    if (branchMode) {
      await _loadBranchReport();
      return;
    }

    if (_hasCode) {
      await category(Code!);
    } else {
      setState(() {
        userlist = [];
        allUsers = [];
        expandedMap.clear();
      });
    }
  }

  /// Card kai branch nu chhe — company_id thi branch list mathi naam
  String _branchNameOf(Map user) {
    final int? companyId = int.tryParse("${user["company_id"] ?? ""}");
    if (companyId != null) {
      for (final c in branchCompanies) {
        if (c.id == companyId) return c.name;
      }
    }
    final dynamic b = user["branch"] ?? user["branch_name"] ?? user["company"];
    if (b is Map) return b["name"]?.toString() ?? "-";
    final String s = (b ?? user["company_name"] ?? "").toString().trim();
    return s.isEmpty ? "-" : s;
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
      await loadReport();
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
    await loadReport();
  }

  /// Select kareli branches na slug (report_branches mate)
  List<String> get _appliedBranchSlugs => branchCompanies
      .where((c) => appliedCompanyIds.contains(c.id))
      .map((c) => c.slug ?? c.id.toString())
      .toList();

  // ============================================================
  // 🔥 BRANCH REPORT URL
  // Normal:  .../api/reports/<report-name>
  // Branch:  .../api/company/branch-reports/<report-name>
  //          ?report_branches=slug1,slug2&per_page=25
  // ============================================================

  // Branch merge ma normal API j + report_branches:
  //   reports/barcode-history/suggest?q=r&report_branches=all
  //   reports/barcode-history?code=RI1&report_branches=all
  //   reports/barcode-history/pdf?code=RI1&report_branches=all   (PDF)
  //   reports/barcode-history/excel?code=RI1&report_branches=all (Excel)

  /// report_branches ni value (API "all" mange chhe)
  static const String reportBranchesValue = "all";

  String buildBranchReportUrl(int page) {
    return "${ApiConstants.Barcode_report}"
        "?code=${Uri.encodeQueryComponent(Code ?? "")}"
        "&report_branches=$reportBranchesValue";
  }

  /// PDF / Excel URL — branch mode hoy to &report_branches=all umero
  String _exportUrl(String base, String code) {
    final String url = "$base?code=${Uri.encodeQueryComponent(code)}";
    return branchMode ? "$url&report_branches=$reportBranchesValue" : url;
  }

  // ============================================================
  // 🔥 BRANCH REPORT API (pagination sathe)
  // ============================================================

  Future<void> _loadBranchReport({bool loadMore = false}) async {
    // Barcode select na hoy to kai load na karvu (normal jevu j)
    if (!_hasCode) {
      setState(() {
        userlist = [];
        allUsers = [];
        expandedMap.clear();
        branchHasMore = false;
      });
      return;
    }

    final int page = loadMore ? branchPage + 1 : 1;
    final String url = buildBranchReportUrl(page);

    debugPrint("🔥 BRANCH BARCODE HISTORY API: $url");

    if (loadMore) setState(() => branchLoadingMore = true);

    try {
      final response =
      await ApiHelper().getRequest(url, showLoading: !loadMore);

      final dynamic body = response?.data;

      if (response?.statusCode == 200 && body is Map) {
        final dynamic data = body["data"];

        List rows = [];
        if (data is List) {
          rows = data;
        } else if (data is Map && data["data"] is List) {
          rows = data["data"];
        }

        if (!mounted) return;

        setState(() {
          final List all = loadMore ? [...allUsers, ...rows] : rows;

          userlist = all;
          allUsers = all;
          if (!loadMore) expandedMap.clear();
          branchPage = page;

          // DataTables: recordsFiltered / Laravel: last_page
          final int? total = int.tryParse(
              "${body["recordsFiltered"] ?? body["recordsTotal"] ?? body["total"] ?? ""}");
          final int last = int.tryParse(
              "${(data is Map ? data["last_page"] : null) ?? body["last_page"] ?? ""}") ??
              0;

          // Ek code nu history — badhu ek sathe aave, Load More nahi
          branchHasMore = false;
          debugPrint("Branch rows total=$total last=$last");
        });

        searchController.clear();
        searchResults.clear();
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

  Widget permissionChip(String text, bool isTablet) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 14 : 12,
        vertical: isTablet ? 8 : 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1633),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: isTablet ? 12 : 11,
        ),
      ),
    );
  }



  Future<void> category(String Code) async {



    final response = await ApiHelper().getRequest(
      "${ApiConstants.Barcode_report}?code=$Code",
    );

    print("user API URL: ${ApiConstants.users}");
    print("users Raw Response: ${response.toString()}");

    if (!mounted) return;

    if (response != null && response.statusCode == 200) {

      final data = response.data;

      // ✅ success check
      final List categories = data['data'] is List ? data['data'] : [];

      setState(() {
        userlist = categories;
        allUsers = categories; // 🔥 store original
        expandedMap.clear(); // 🔥 fresh data -> collapse all cards
      });

      print("✅ Total user: ${userlist.length}");
      searchController.clear();
      searchResults.clear();

    } else {
      setState(() {
        userlist = [];
      });
      print("❌ userlist API failed");
    }
  }


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
                color: Colors.white.withOpacity(0.1),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  /// 🔥 Delete Icon
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Color(0xffff4e50),
                          Color(0xfff00000),
                        ],
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
                    "Delete User?",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      decoration: TextDecoration.none,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    "Are you sure you want to delete ${user["name"]}?",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      decoration: TextDecoration.none,
                    ),
                  ),

                  const SizedBox(height: 25),

                  Row(
                    children: [

                      /// Cancel Button
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade800,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "Cancel",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      /// Delete Button
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xfff00000),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () async {

                            Navigator.pop(context); // close dialog

                            deleteUser(user["id"].toString()); // Your API call

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
            scale: CurvedAnimation(
              parent: anim,
              curve: Curves.easeOutBack,
            ),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> deleteUser(String ID) async {
    try {
      final response = await ApiHelper().deleteRequest(
        "${ApiConstants.delete_users}/$ID",
      );

      if (response?.statusCode == 200) {
        print("✅ Deleted Successfully");
        print("Response: ${response?.data}");



      } else {
        print("❌ Logout failed | Status: ${response?.statusCode}");
      }

    } catch (e) {
      print("❌ Logout exception: $e");
    }
  }

  Widget filterWidget() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 5, 10, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [

          /// 🔍 SEARCH FIELD
          Column(
            children: [
              /// 🔍 SEARCH FIELD
              TextField(
                controller: searchController,
                onChanged: (value) {
                  searchItemsApi(value);
                },
                decoration: InputDecoration(
                  hintText: "Search (HUID / QR)",
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  prefixIcon: const Icon(Icons.search, size: 18,color: AppColors.primaryDark,),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.border)
                  ),

                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color:AppColors.border),
                  ),

                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
              ),

              /// 🔥 DROPDOWN RESULT LIST
              /// 🔥 SEARCH RESULT DROPDOWN
              if (searchController.text.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: isLoading
                      ? const Padding(
                    padding: EdgeInsets.all(0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                      : searchResults.isEmpty
                      ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(
                      child: Text(
                        "No items found",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                      : ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero, // 🔥 MUST ADD
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final item = searchResults[index];

                      final itemName =
                          item?["item_name"] ?? "Item";
                      final huid = item["HUID"] ?? "-";
                      final qr = item["code"] ?? "-";

                      return InkWell(
                        onTap: () {
                          //addItemToCard(item); // 🔥 IMPORTANT
                          // updateFinalItems();
                          FocusManager.instance.primaryFocus?.unfocus(); // 🔥 close keyboard
                          Code = item["code"];
                          // Branch report chalu hoy to branch API ma code jay
                          loadReport();
                          setState(() {

                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: index == searchResults.length - 1
                                    ? Colors.transparent
                                    : Colors.grey.shade200,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              /// 🔹 LEFT INFO
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      itemName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "HUID: $huid | QR: $qr",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              /// ➕ ADD ICON
                              const Icon(
                                Icons.add_circle,
                                color: Color(0xffC8A96A),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),


          Row(
            children: [

              Expanded(
                child: customButton(
                  title: "Show",
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryDark,
                      AppColors.secondaryDark,
                    ],
                  ),
                  onTap: () async {
                    // Branch report chalu hoy to e j chalu rahe
                    // (bandh karvo hoy to "Clear")
                    applyDateFilter();
                  },
                ),
              ),

              const SizedBox(width: 10),


              Expanded(
                child: customButton(
                  title: "PDF",
                  icon: Icons.picture_as_pdf,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xffE57373), Color(0xffD32F2F),Color(0xffE57373)
                    ],
                  ),
                  onTap: () {
                    openPdf(Code.toString());
                  },
                ),
              ),


              const SizedBox(width: 10),


              Expanded(
                child: customButton(
                  title: "Excel",
                  icon: Icons.table_chart,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xff66BB6A), // light green
                      Color(0xff2E7D32), // dark green
                      Color(0xff66BB6A), // light green
                    ],
                  ),
                  onTap: () {
                    openexel(Code.toString());
                  },
                ),
              ),

            ],
          )

        ],
      ),
    );
  }

  Widget customButton({
    required String title,
    IconData? icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {

    return InkWell(
      onTap: onTap,

      borderRadius: BorderRadius.circular(5),

      child: Container(
        height: 35,

        decoration: BoxDecoration(

          gradient: gradient,

          borderRadius: BorderRadius.circular(5),

        ),


        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            if(icon != null)...[

              Icon(
                icon,
                size: 18,
                color: Colors.white,
              ),

              const SizedBox(width: 6),

            ],


            Text(
              title,

              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),

            ),

          ],
        ),
      ),
    );
  }
  /// 🔹 Status Chip
  Widget statusChip(String status) {

    Color startColor;
    Color endColor;
    String label;

    switch (status.toLowerCase()) {

      case "in_stock":
      /// 🔹 Active
        startColor = const Color(0xffC8A96A);
        endColor   = const Color(0xffE6C58A);
        label = "in stock";
        break;

      case "sold":
      /// 🔹 Inactive
        startColor = const Color(0xffD9534F);
        endColor   = const Color(0xffF28B82);
        label = "Sold";
        break;

      case "returned":
      /// 🔹 In progress
        startColor = const Color(0xffB07A3F);
        endColor   = const Color(0xffE0A96D);
        label = "Returned";
        break;

      case "approval":
      /// 🔹 In progress
        startColor = const Color(0xffB07A3F);
        endColor   = const Color(0xffE0A96D);
        label = "Approval";
        break;

      default:
        return const SizedBox.shrink(); // 👈 Unknown hide
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [startColor, endColor],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.4),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [

          /// dot
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: 6),

          /// label
          Text(
            label,   // 🔥 IMPORTANT CHANGE HERE
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }


  Widget premiumIconBtn(IconData icon, Color color, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _erpRow(
      String t1,
      String v1,
      String t2,
      String v2, {
        List historyList = const [],
      }) {
    bool isExpanded = false;

    return StatefulBuilder(
      builder: (context, setStateRow) {
        bool hasMultiple =
            historyList != null && historyList.isNotEmpty;


        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              /// 🔹 MAIN ROW
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            t1,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black,
                            ),
                          ),
                        ),

                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [

                              /// 🔥 VALUE (Single item hoy to direct show)
                              Expanded(
                                child: Text(
                                  historyList.isNotEmpty
                                      ? historyList.first["label"] ?? "-"
                                      : v1,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black,
                                  ),
                                ),
                              ),

                              /// 🔥 EXPAND ICON (ONLY IF MULTIPLE)
                              if (hasMultiple)
                                InkWell(
                                  onTap: () {
                                    setStateRow(() {
                                      isExpanded = !isExpanded;
                                    });
                                  },
                                  child: Icon(
                                    isExpanded
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down,
                                    size: 20,
                                    color: Colors.black,
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

              /// 🔽 EXPANDED LIST
              if (isExpanded && hasMultiple)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300, // ✅ WHITE BACKGROUND
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: historyList.asMap().entries.map<Widget>((entry) {
                      int index = entry.key;
                      var e = entry.value;

                      return Column(
                        children: [

                          /// 🔹 ROW
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            child: Row(
                              children: [

                                /// 🔢 SERIAL NUMBER
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    "Vouchar ${index + 1}", // 🔥 1,2,3...
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),



                                /// RIGHT VALUE
                                Expanded(
                                  flex: 3,
                                  child: InkWell(
                                    onTap: (){
                                      getApprovalDetails(e); // 🔥 id pass karo
                                    },
                                    child: Text(
                                      e["label"] ?? "",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue, // 🔥 LINK COLOR
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          /// 🔻 DIVIDER (last ma avoid)
                          if (index != historyList.length - 1)
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: Colors.white,
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ),


            ],
          ),
        );
      },
    );
  }

  Widget _erpRow1(String t1, String v1, String t2, String v2) {
    final bool hideRight = (t2.isEmpty && v2.isEmpty);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          /// Left Field
          Expanded(
            flex: hideRight ? 1 : 1,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    t1,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.black,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    double.tryParse(v1.toString()) != null
                        ? double.parse(v1.toString()).toStringAsFixed(2)
                        : v1.toString(),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// Right Field (ONLY IF NOT EMPTY)
          if (!hideRight)
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      t2,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      double.tryParse(v2.toString()) != null
                          ? double.parse(v2.toString()).toStringAsFixed(2)
                          : v2.toString(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }


  String formatDate(String date) {
    try {
      final parts = date.split(" ")[0].split("-"); // 🔥 space par split
      return "${parts[2]}-${parts[1]}-${parts[0]}"; // dd-MM-yyyy
    } catch (e) {
      return "-";
    }
  }


  DateTime _convertToDate(String input) {
    final parts = input.split("-");
    return DateTime(
      int.parse(parts[2]), // year
      int.parse(parts[1]), // month
      int.parse(parts[0]), // day
    );
  }

  Future<void> searchItemsApi(String keyword) async {
    if (keyword.isEmpty) {
      setState(() {
        items = [];
      });
      return;
    }

    // Branch merge chalu hoy to:
    //   reports/barcode-history/suggest?q=r&report_branches=all
    final String url =
        "${ApiConstants.Barcode_report}/suggest?q=${Uri.encodeQueryComponent(keyword)}"
        "${branchMode ? "&report_branches=$reportBranchesValue" : ""}";

    debugPrint("🔥 BARCODE SUGGEST URL => $url");

    final response = await ApiHelper().getRequest(url, showLoading: false);

    if (response != null && response.statusCode == 200) {
      final data = response.data;

      setState(() {
        searchResults = response.data["data"];

      });
    } else {
      print("Search API Failed");
    }
  }

  /// 🔹 PDF Button
  Widget pdfBtn(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 0, 0),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xffE57373), Color(0xffD32F2F),Color(0xffE57373)],
          ),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.picture_as_pdf, color: Colors.white, size: 20),
            SizedBox(width: 4),
            Text("PDF",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500,fontSize: 16)),
          ],
        ),
      ),
    );
  }



  Widget excelBtn(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.fromLTRB(0, 0, 20, 0),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xff66BB6A), // light green
              Color(0xff2E7D32), // dark green
              Color(0xff66BB6A), // light green
            ],
          ),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.table_chart, color: Colors.white, size: 18),
            SizedBox(width: 4),
            Text(
              "Excel",
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 16
              ),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> openPdf(String Code) async {
    final String url = _exportUrl(ApiConstants.Barcode_report_pdf, Code);
    debugPrint("🔥 BARCODE PDF URL => $url");

    final response = await ApiHelper().getPdfRequest(url);
    await _saveAndOpen(response, isPdf: true);
  }

  /// File save + open. Server JSON error mokle to eno message batave.
  Future<void> _saveAndOpen(dynamic response, {required bool isPdf}) async {
    if (response == null || response.statusCode != 200) {
      debugPrint("EXPORT STATUS => ${response?.statusCode}");
      if (mounted) {
        AppMessage.error(
            context, "Could not download the ${isPdf ? "PDF" : "Excel"} file");
      }
      return;
    }

    final dynamic data = response.data;
    if (data is! List<int> || data.isEmpty) {
      if (mounted) AppMessage.error(context, "The server sent an empty file");
      return;
    }

    // PDF = "%PDF", XLSX = "PK"
    final bool okPdf = data.length > 4 &&
        data[0] == 0x25 && data[1] == 0x50 && data[2] == 0x44 && data[3] == 0x46;
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

    final dir = await getTemporaryDirectory();
    final file = File(
      "${dir.path}/barcode_history_${DateTime.now().millisecondsSinceEpoch}"
          ".${isPdf ? "pdf" : "xlsx"}",
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
  }

  Future<void> openPdf1(Map<String, dynamic> item) async {

    /// 🔥 TYPE DETECTION
    bool isSale = item["voucher_no"] != null;
    bool isReturn = item["return_voucher_no"] != null;
    bool isApproval = item["approval_no"] != null;

    String api = "";
    int id = item["id"];

    /// 🔥 API SELECT
    if (isSale) {
      api = ApiConstants.Sale_pdf;
    } else if (isReturn) {
      api = ApiConstants.return_pdf;
    } else if (isApproval) {
      api = ApiConstants.Approval_pdf;
    }

    /// 🔥 API CALL
    final response = await ApiHelper().getRequestWithId(
      api,
      id,
      responseType: ResponseType.bytes,
    );

    if (response != null && response.statusCode == 200) {

      final dir = await getTemporaryDirectory();

      /// 🔥 FILE NAME BASED ON TYPE
      String fileName = isSale
          ? "Sale_$id.pdf"
          : isReturn
          ? "Return_$id.pdf"
          : "Approval_$id.pdf";

      final file = File("${dir.path}/$fileName");

      await file.writeAsBytes(response.data);

      OpenFile.open(file.path);

    } else {
      print("PDF Download Failed");
    }
  }



  Future<void> openexel(String Code) async {
    final String url = _exportUrl(ApiConstants.Barcode_report_excel, Code);
    debugPrint("🔥 BARCODE EXCEL URL => $url");

    final response = await ApiHelper().getPdfRequest(url);
    await _saveAndOpen(response, isPdf: false);
  }

  Future<void> getApprovalDetails(Map<String, dynamic> e) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final response = await ApiHelper().getRequest(
      e["api_url"], // 🔥 dynamic URL
    );

    Navigator.pop(context);

    if (response != null && response.statusCode == 200) {

      /// 🔥 DIRECT JSON (NO DECODE)
      final data = response.data;

      final item =
      data["data"] is List ? data["data"][0] : data["data"];

      showApprovalDialog(item);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load details")),
      );
    }
  }



  void showApprovalDialog(Map<String, dynamic> item) {
    String val(dynamic v) => v == null ? "-" : v.toString();

    /// 🔥 TYPE DETECTION
    bool isSale = item["voucher_no"] != null;
    bool isReturn = item["return_voucher_no"] != null;
    bool isApproval = item["approval_no"] != null;

    /// 🔥 ITEMS LIST
    List items = isSale
        ? (item["sale_items"] ?? [])
        : isReturn
        ? (item["items"] ?? [])
        : (item["items"] ?? []);

    /// 🔥 COMMON DATA
    String customerName = isSale
        ? val(item["customer"]?["name"])
        : isReturn
        ? val(item["approval"]?["customer"]?["name"])
        : val(item["customer"]?["name"]);

    String voucherNo = isSale
        ? val(item["voucher_no"])
        : isReturn
        ? val(item["return_voucher_no"])
        : val(item["approval_no"]);

    String date = isSale
        ? val(item["sale_date"]?.toString().split("T")[0])
        : isReturn
        ? val(item["return_date"])
        : val(item["approval_date"]);

    /// 🔥 TOP VALUES
    String grossWt = "-";
    String netWt = "-";
    String amount = "-";

    if (isSale) {
      grossWt = val(item["gross_weight"]);
      netWt = val(item["net_weight"]);
      amount = val(item["total_amount"]);
    } else if (isReturn) {

      Map<String, dynamic> firstItem = {};

      if (items.isNotEmpty && items[0] is Map<String, dynamic>) {
        firstItem = items[0];
      }

      Map<String, dynamic> saleItem =
      firstItem["sale_item"] is Map<String, dynamic>
          ? firstItem["sale_item"]
          : {};

      grossWt = val(saleItem["gross_weight"]);
      netWt   = val(saleItem["net_weight"]);

      amount = val(item["return_total"]);
    }else if (isApproval) {
      grossWt = val(item["totals"]?["gross_weight"]);
      netWt = val(item["totals"]?["net_weight"]);
      amount = val(item["totals"]?["amount_all"]);
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xffFAF7F2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          insetPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.92,
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  /// 🔝 HEADER
                  Row(
                    children: [
                      Text(
                        isSale
                            ? "Sale Voucher Details"
                            : isReturn
                            ? "Return  Details"
                            : "Approval Details",
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black
                        ),
                      ),
                      const Spacer(),



                      InkWell(
                        onTap: (){
                          openPdf1(item);
                        },
                        borderRadius: BorderRadius.circular(5),
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(20, 0, 0, 0),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xffE57373), Color(0xffD32F2F),Color(0xffE57373)],
                            ),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.picture_as_pdf, color: Colors.white, size: 18),
                              SizedBox(width: 4),
                              Text("PDF",
                                  style: TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.w500,fontSize: 14)),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      InkWell(
                        onTap: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          SystemChannels.textInput.invokeMethod('TextInput.hide');
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "Back",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  /// 🔹 TOP INFO
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                          color: Colors.grey.shade200, width: 1.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      children: [
                        _erpRow1("Customer", customerName, "Voucher", voucherNo),

                        Divider(height: 1.5, color: Colors.grey.shade200),



                        _erpRow1("Date", date, "Gross Wt", grossWt),

                        Divider(height: 1.0, color: Colors.grey.shade200),

                        _erpRow1("Net Wt", netWt, "Amount", amount),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  /// 🔹 ITEMS LIST
                  SizedBox(
                    height: 110,
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final data = items[index];

                        Map<String, dynamic> current =
                        data is Map<String, dynamic> ? data : {};

                        Map<String, dynamic> saleItem =
                        isReturn ? (current["sale_item"] ?? {}) : current;

                        Map<String, dynamic> itemset = isReturn
                            ? (saleItem["itemset"] ?? {})
                            : (current["itemset"] ?? {});

                        /// 🔥 ITEM NAME FIX (ALL CASE)
                        String itemName = isReturn
                            ? val(itemset["item"]?["item_name"])
                            : val(current["item_name"]);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                                color: Colors.grey.shade200, width: 1.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(
                            children: [
                              _erpRow1(
                                "Item",
                                itemName,
                                "",
                                "",
                              ),

                              Divider(
                                  height: 1.0,
                                  color: Colors.grey.shade200),

                              _erpRow1(
                                "Other Wt",
                                val(saleItem["other_weight"]),
                                "Gross.wt",
                                val(saleItem["gross_weight"]),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  /// 🔻 CLOSE
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Center(
                      child: Container(
                        width: 100,
                        height: 40,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xffC8A96A), Color(0xffE6C58A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: const Text(
                            "Close",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }



}
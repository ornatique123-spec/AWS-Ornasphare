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
import '../Extra/PremiumSearchableDropdown.dart';
import 'BranchAccess.dart';
import 'StockPositionDetailsScreen.dart';

/// 🔥 Simple column definition used by the custom grid table
class _ColDef {
  final String title;
  final double width;
  final bool alignLeft;

  const _ColDef(this.title, {required this.width, this.alignLeft = false});
}

class Stockpositionreport extends StatefulWidget {
  const Stockpositionreport({super.key});

  @override
  State<Stockpositionreport> createState() => _StockpositionreportState();
}

class _StockpositionreportState extends State<Stockpositionreport> {
  TextEditingController searchController = TextEditingController();
  TextEditingController fromDateController = TextEditingController();
  TextEditingController toDateController = TextEditingController();
  List userlist = [];
  List<Map<String, dynamic>> items = [];
  List searchResults = [];
  bool isLoading = false;
  Map<String, bool> expandedMap = {};
  Map<String, dynamic>? summaryTotals;
  String? selectedCustomerId;   // 🔥 ADD — item ni ID sathe conflict thavani nathi
  String? Code;
  Future<void> _selectDate(TextEditingController controller) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      controller.text = "${picked.day}-${picked.month}-${picked.year}";
    }
  }

  String? selectedItem;
  String? selectedCustomerName;

  /// ✅ Dropdown ma pasand karela option (normal + branch banne mate)
  ///   item:     {"id": key, "item_id", "name", "company_id", "branch"}
  ///   customer: {"id": key, "cust_id", "name", "company_id", "branch"}
  Map<String, dynamic>? _selItemOpt;
  Map<String, dynamic>? _selCustOpt;
  String? selectedCompanyId;
  String? selectedUserId;
  String? selectedParty; // 🔥 UI ONLY - wire to real party data when API provides it
  List allUsers = []; // 🔥 original data store

  // ============================================================
  // 🔥 BRANCH REPORT STATE
  // ============================================================

  /// Branch report ma ek page ma ketla record
  static const int branchPerPage = 25;

  /// Branch API mathi aavti companies (main + branches)
  List<Company> branchCompanies = [];

  /// Dropdown ma select kareli (haji apply nathi thai)
  Set<int> selectedCompanyIds = {};

  /// "View Report" dabavya pachhi apply thayeli
  List<int> appliedCompanyIds = [];

  /// Branch report chalu chhe? (true hoy to branch API vaparay)
  bool get branchMode => appliedCompanyIds.isNotEmpty;

  int branchPage = 1;
  bool branchHasMore = false;
  bool branchLoadingMore = false;

  bool branchesLoading = false;
  bool canViewBranches = false;
  bool branchExpanded = true;
  bool branchReportLoading = false;

  /// Table no horizontal scroll
  final ScrollController _hTableScroll = ScrollController();

  @override
  void dispose() {
    _hTableScroll.dispose();
    searchController.dispose();
    fromDateController.dispose();
    toDateController.dispose();
    super.dispose();
  }

  void searchUser(String value) {
    _applyFilters();
  }

  void applyDateFilter() {
    if (fromDateController.text.isEmpty || toDateController.text.isEmpty) {
      setState(() {
        userlist = allUsers;
        summaryTotals = calculateSummaryTotals(allUsers);
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
      summaryTotals = calculateSummaryTotals(filtered);
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
    Future.microtask(() {
      Provider.of<ItemProvider>(context, listen: false).loadItems();
      Provider.of<ItemProvider>(context, listen: false).loadCustomers();
    });

    Stockpositionreport();
    loadBranches();
  }

  @override
  Widget build(BuildContext context) {

    if(!(
        hasPermission("report-stock-position-view") ||
            hasPermission("report-stock-position-manage")
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
        resizeToAvoidBottomInset: false, // ⭐ IMPORTANT FIX
        backgroundColor: AppColors.white,
        body: Stack(
          children: [
            /// 🔥 MAIN CONTENT
            Column(
              children: [
                /// IMPORTANT: top padding space leave karvu (AppBar mate)
                SizedBox(height: MediaQuery.of(context).padding.top + 40),

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

                        filterWidget(isMobile),

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

                        /// 🔥 TOP SUMMARY CARDS (matches reference layout)
                        summaryCardsRow(isMobile),

                        /// 🔥 SEARCH ROW
                        searchRow(isMobile),

                        /// 🔥 TABLE
                        Container(
                          margin: const EdgeInsets.fromLTRB(10, 6, 10, 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.primaryDark.withOpacity(0.12),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: buildDataTable(),
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
                    /// CENTER TITLE
                    const Text(
                      "Stock Position",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    /// LEFT BACK ICON
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
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: EdgeInsets.all(isMobile ? 6 : 8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.shadow,
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: isMobile ? 20 : 24,
                          ),
                        ),
                      ),
                    ),

                    /// RIGHT — PREMIUM EXCEL / PDF ICON BUTTONS
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          excelBtn(
                            isMobile,
                                () => openexel(Code ?? ""),
                          ),
                          SizedBox(width: isMobile ? 8 : 10),
                          pdfBtn(
                            isMobile,
                                () => openPdf(),
                          ),
                        ],
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

  /// 🔥 FILTER BAR — Item / Customer dropdowns + Filter / Reset
  /// Branch merge hoy tyare item / customer branch na data mathi j aave
  Widget filterWidget(bool isMobile) {
    final double w = isMobile ? double.infinity : 240;
    final int active = (_selItemOpt != null ? 1 : 0) +
        (_selCustOpt != null ? 1 : 0) +
        (searchController.text.trim().isNotEmpty ? 1 : 0);

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          /// ── HEADER
          Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withOpacity(0.04),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.primaryDark.withOpacity(0.08),
                ),
              ),
            ),
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
                    Icons.tune_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "Report Filters",
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (active > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xff2563EB).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "$active active",
                      style: const TextStyle(
                        color: Color(0xff2563EB),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                InkWell(
                  onTap: () async {
                    searchController.clear();
                    _clearSelections();
                    _applyFilters();

                    // Branch report chalu hoy to normal report pachho
                    if (branchMode) await clearBranchReport();
                  },
                  borderRadius: BorderRadius.circular(5),
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded,
                            size: 14, color: Colors.blueGrey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          "Reset",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.blueGrey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// ── BODY
          Padding(
            padding: const EdgeInsets.all(10),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 10,
              spacing: 10,
              children: [
                SizedBox(
                  width: w,
                  child: _fieldLabel("Item", Icons.inventory_2_outlined,
                      itemDropdown()),
                ),
                SizedBox(
                  width: w,
                  child: _fieldLabel("Customer", Icons.person_outline,
                      customerDropdown()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Nanu label + field
  Widget _fieldLabel(String label, IconData icon, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 5),
          child: Row(
            children: [
              Icon(icon, size: 12.5, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        field,
      ],
    );
  }

  // ============================================================
  // 🔥 ITEM / CUSTOMER OPTIONS
  //
  // Normal  → ItemProvider (items / customers) jevu pehla hatu
  // Branch  → merge thayela rows mathi, dar branch nu alag
  //           ("Ring • Main Branch", "Ramesh • Surat")
  // ============================================================

  static const Map<String, dynamic> _allItemsOpt = {
    "id": "__all__",
    "name": "All Items",
  };

  static const Map<String, dynamic> _allCustOpt = {
    "id": "__all__",
    "name": "All Customers",
  };

  String _rowCompany(Map u) => _text(u["company_id"], "");

  String _rowItemId(Map u) {
    final dynamic item = u["item"];
    return _text(u["item_id"] ?? (item is Map ? item["id"] : null), "");
  }

  String _rowItemName(Map u) {
    final dynamic item = u["item"];
    return _text(
      u["item_name"] ??
          (item is Map ? item["item_name"] ?? item["name"] : null),
      "",
    );
  }

  String _rowCustId(Map u) {
    final dynamic c = u["customer"] ?? u["party"];
    return _text(
      u["customer_id"] ?? u["party_id"] ?? (c is Map ? c["id"] : null),
      "",
    );
  }

  String _rowCustName(Map u) {
    final String n = _partyName(u);
    return n == "-" ? "" : n;
  }

  /// Item options
  List<Map<String, dynamic>> _itemOptions(ItemProvider provider) {
    final List<Map<String, dynamic>> out = [];

    if (branchMode) {
      final Set<String> seen = {};
      for (final raw in allUsers) {
        if (raw is! Map) continue;
        final String name = _rowItemName(raw);
        final String id = _rowItemId(raw);
        if (name.isEmpty && id.isEmpty) continue;
        final String company = _rowCompany(raw);
        final String key = "$company|${id.isNotEmpty ? id : name}";
        if (!seen.add(key)) continue;
        out.add({
          "id": key,
          "item_id": id,
          "name": name.isEmpty ? "Item $id" : name,
          "company_id": company,
          "branch": _branchNameOf(raw),
        });
      }
      out.sort((a, b) => "${a["name"]}${a["branch"]}"
          .toLowerCase()
          .compareTo("${b["name"]}${b["branch"]}".toLowerCase()));
    } else {
      for (final raw in provider.items) {
        if (raw is! Map) continue;
        final String id = _text(raw["id"], "");
        out.add({
          "id": "i$id",
          "item_id": id,
          "name": _text(raw["item_name"] ?? raw["name"], "-"),
          "item_code": _text(raw["item_code"], ""),
        });
      }
    }

    return [_allItemsOpt, ...out];
  }

  /// Customer options
  List<Map<String, dynamic>> _customerOptions(ItemProvider provider) {
    final List<Map<String, dynamic>> out = [];

    if (branchMode) {
      final Set<String> seen = {};
      for (final raw in allUsers) {
        if (raw is! Map) continue;
        final String name = _rowCustName(raw);
        final String id = _rowCustId(raw);
        if (name.isEmpty && id.isEmpty) continue;
        final String company = _rowCompany(raw);
        final String key = "$company|${id.isNotEmpty ? id : name}";
        if (!seen.add(key)) continue;
        out.add({
          "id": key,
          "cust_id": id,
          "name": name.isEmpty ? "Customer $id" : name,
          "company_id": company,
          "branch": _branchNameOf(raw),
        });
      }
      out.sort((a, b) => "${a["name"]}${a["branch"]}"
          .toLowerCase()
          .compareTo("${b["name"]}${b["branch"]}".toLowerCase()));
    } else {
      for (final raw in provider.customers) {
        if (raw is! Map) continue;
        final String id = _text(raw["id"], "");
        out.add({
          "id": "c$id",
          "cust_id": id,
          "name": _text(raw["name"], "-"),
          "mobile": _text(raw["mobile_no"] ?? raw["mobile"], ""),
          "email": _text(raw["email"], ""),
        });
      }
    }

    return [_allCustOpt, ...out];
  }

  String _optLabel(Map<String, dynamic> o) {
    final String branch = (o["branch"] ?? "").toString();
    return branch.isEmpty || branch == "-"
        ? (o["name"] ?? "-").toString()
        : "${o["name"]}  •  $branch";
  }

  bool _rowMatchesItem(Map u, Map<String, dynamic> o) {
    final String company = (o["company_id"] ?? "").toString();
    if (company.isNotEmpty && _rowCompany(u) != company) return false;

    final String optId = (o["item_id"] ?? "").toString();
    final String rowId = _rowItemId(u);
    if (optId.isNotEmpty && rowId.isNotEmpty) return optId == rowId;

    return _rowItemName(u).toLowerCase() ==
        (o["name"] ?? "").toString().toLowerCase();
  }

  bool _rowMatchesCustomer(Map u, Map<String, dynamic> o) {
    final String company = (o["company_id"] ?? "").toString();
    if (company.isNotEmpty && _rowCompany(u) != company) return false;

    final String optId = (o["cust_id"] ?? "").toString();
    final String rowId = _rowCustId(u);
    if (optId.isNotEmpty && rowId.isNotEmpty) return optId == rowId;

    return _rowCustName(u).toLowerCase() ==
        (o["name"] ?? "").toString().toLowerCase();
  }

  /// Item + Customer + Search → list ane totals
  List _filtered(List src) {
    final String q = searchController.text.trim().toLowerCase();

    return src.where((u) {
      if (u is! Map) return false;
      if (_selItemOpt != null && !_rowMatchesItem(u, _selItemOpt!)) {
        return false;
      }
      if (_selCustOpt != null && !_rowMatchesCustomer(u, _selCustOpt!)) {
        return false;
      }
      if (q.isEmpty) return true;

      return [
        _rowItemName(u),
        _text(u["stock_type"], ""),
        _partyName(u),
        if (branchMode) _branchNameOf(u),
      ].join(" ").toLowerCase().contains(q);
    }).toList();
  }

  void _applyFilters() {
    if (!mounted) return;
    setState(() {
      userlist = _filtered(allUsers);
      summaryTotals = calculateSummaryTotals(userlist);
    });
  }

  void _clearSelections() {
    _selItemOpt = null;
    _selCustOpt = null;
    selectedItem = null;
    selectedCustomerId = null;
    selectedCustomerName = null;
    selectedCompanyId = null;
    selectedUserId = null;
    selectedParty = null;
  }

  /// Branch report 25-25 na page ma aave — filter pehla badha pages
  Future<void> _ensureAllBranchPages() async {
    if (!branchMode) return;
    int guard = 0;
    while (branchHasMore && mounted && guard < 200) {
      guard++;
      final int before = allUsers.length;
      await _loadBranchReport(loadMore: true);
      if (allUsers.length == before) break; // aagal kai nathi
    }
  }

  Widget itemDropdown() {
    return Consumer<ItemProvider>(
      builder: (context, provider, child) {
        final List<Map<String, dynamic>> opts = _itemOptions(provider);

        return PremiumSearchableDropdown<Map<String, dynamic>>(
          label: "",
          hint: "All Items",
          items: opts,
          value: _selItemOpt,
          prefixIcon: Icons.inventory_2_outlined,
          menuWidth: MediaQuery.of(context).size.width * 0.92,
          itemLabel: _optLabel,
          searchText: (o) => [
            o["name"],
            o["item_code"],
            o["branch"],
            o["item_id"],
          ].map((e) => e?.toString() ?? "").join(" "),
          onChanged: (o) async {
            final bool all = o == null || o["id"] == "__all__";
            setState(() {
              _selItemOpt = all ? null : o;
              selectedItem = all ? null : o["item_id"]?.toString();
            });
            if (!all) await _ensureAllBranchPages();
            _applyFilters();
          },
        );
      },
    );
  }

  Widget customerDropdown() {
    return Consumer<ItemProvider>(
      builder: (context, provider, child) {
        final List<Map<String, dynamic>> opts = _customerOptions(provider);

        return PremiumSearchableDropdown<Map<String, dynamic>>(
          label: "",
          hint: "All Customers",
          items: opts,
          value: _selCustOpt,
          prefixIcon: Icons.person_outline,
          menuWidth: MediaQuery.of(context).size.width * 0.92,
          itemLabel: _optLabel,
          searchText: (o) => [
            o["name"],
            o["mobile"],
            o["email"],
            o["branch"],
            o["cust_id"],
          ].map((e) => e?.toString() ?? "").join(" "),
          onChanged: (o) async {
            final bool all = o == null || o["id"] == "__all__";
            setState(() {
              _selCustOpt = all ? null : o;
              selectedCustomerId = all ? null : o["cust_id"]?.toString();
              selectedCustomerName = all ? null : o["name"]?.toString();
            });
            if (!all) await _ensureAllBranchPages();
            _applyFilters();
          },
        );
      },
    );
  }

  /// 🔥 UI-ONLY party dropdown — wire this to a real Party list once the API exposes one
  Widget partyDropdown() {
    final List<String> partyNames = allUsers
        .map((e) => e["party_name"]?.toString())
        .whereType<String>()
        .toSet()
        .toList();

    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selectedParty,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          hint: const Text(
            "All Parties",
            style: TextStyle(color: Colors.black54, fontSize: 14),
          ),
          items: partyNames
              .map(
                (p) => DropdownMenuItem<String>(
              value: p,
              child: Text(
                p,
                style: const TextStyle(color: Colors.black, fontSize: 14),
              ),
            ),
          )
              .toList(),
          onChanged: (value) {
            setState(() {
              selectedParty = value;
              if (value == null) {
                userlist = allUsers;
              } else {
                userlist = allUsers
                    .where((u) => u["party_name"]?.toString() == value)
                    .toList();
              }
              summaryTotals = calculateSummaryTotals(userlist);
            });
          },
        ),
      ),
    );
  }

  Widget filterActionBtn(
      String label,
      Color color,
      IconData icon, {
        required VoidCallback onTap,
      }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔥 TOP SUMMARY CARDS
  Widget summaryCardsRow(bool isMobile) {
    if (summaryTotals == null) return const SizedBox();

    final t = summaryTotals!;
    final cards = <Widget>[
      _summaryCard("Entries", "${userlist.length}",
          Icons.format_list_numbered_rounded, const Color(0xff0F766E)),
      _summaryCard("Qty Pcs", "${t["qty_pcs"]}", Icons.inventory_2_outlined,
          AppColors.primaryDark),
      _summaryCard("Gross Wt", "${t["gross_weight"]}", Icons.scale_rounded,
          const Color(0xff7C3AED)),
      _summaryCard("Other Wt", "${t["less_weight"]}",
          Icons.remove_circle_outline_rounded, const Color(0xff64748B)),
      _summaryCard("Net Wt", "${t["net_weight"]}", Icons.balance_rounded,
          const Color(0xff2563EB)),
      _summaryCard("Fine Wt", "${t["fine_weight"]}", Icons.diamond_outlined,
          const Color(0xffB45309)),
      _summaryCard("Labour Amt", "${t["labour_amount"]}",
          Icons.handyman_outlined, const Color(0xff9333EA)),
      _summaryCard("Other Amt", "${t["other_amount"]}",
          Icons.add_card_rounded, const Color(0xffEA580C)),
    ];

    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => cards[i],
      ),
    );
  }

  /// ✨ Premium summary card — rangin icon + label + value
  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      constraints: const BoxConstraints(minWidth: 122),
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.09), color.withOpacity(0.03)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 10.5,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 🔥 Entries chip + premium search box
  Widget searchRow(bool isMobile) {
    final Widget entries = Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryDark.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.table_rows_rounded,
              size: 15, color: AppColors.primaryDark),
          const SizedBox(width: 6),
          Text(
            "${userlist.length}",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            "entries",
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
          ),
        ],
      ),
    );

    final Widget search = SizedBox(
      height: 40,
      child: TextField(
        controller: searchController,
        onChanged: (v) {
          searchUser(v);
          setState(() {}); // clear icon mate
        },
        style: const TextStyle(color: Colors.black, fontSize: 13.5),
        decoration: InputDecoration(
          hintText: "Search item, party, stock type...",
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded,
              color: AppColors.primaryDark, size: 20),
          suffixIcon: searchController.text.isEmpty
              ? null
              : IconButton(
            splashRadius: 18,
            icon: Icon(Icons.close_rounded,
                size: 18, color: Colors.grey.shade600),
            onPressed: () {
              searchController.clear();
              _applyFilters();
            },
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
          const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.primaryDark, width: 1.4),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: isMobile
          ? Row(
        children: [
          entries,
          const SizedBox(width: 8),
          Expanded(child: search),
        ],
      )
          : Row(
        children: [
          entries,
          const Spacer(),
          SizedBox(width: 300, child: search),
        ],
      ),
    );
  }

  /// 🔥 TABLE COLUMN DEFINITIONS — width + numeric alignment in one place
  static const List<_ColDef> _tableCols = [
    _ColDef("#", width: 44),
    _ColDef("Item", width: 150, alignLeft: true),
    _ColDef("Stock Type", width: 120, alignLeft: true),
    _ColDef("Party", width: 120, alignLeft: true),
    _ColDef("Qty Pcs", width: 90),
    _ColDef("Gross Wt", width: 100),
    _ColDef("Other Wt", width: 100),
    _ColDef("Net Wt", width: 100),
    _ColDef("Fine Wt", width: 100),
    _ColDef("Labour Amt", width: 110),
    _ColDef("Other Amt", width: 110),
  ];

  /// 🔥 MAIN DATA TABLE — proper grid look with vertical dividers between
  /// every column (scrolls both ways so it works on mobile too)
  /// Branch report ma "#" pachhi "Branch" column umerAy
  List<_ColDef> get _activeCols => branchMode
      ? [
    _tableCols.first,
    const _ColDef("Branch", width: 130, alignLeft: true),
    ..._tableCols.skip(1),
  ]
      : _tableCols;

  /// Column → totals key (footer total row mate)
  static const Map<String, String> _totalKeys = {
    "Qty Pcs": "qty_pcs",
    "Gross Wt": "gross_weight",
    "Other Wt": "less_weight",
    "Net Wt": "net_weight",
    "Fine Wt": "fine_weight",
    "Labour Amt": "labour_amount",
    "Other Amt": "other_amount",
  };

  /// ✨ PREMIUM TABLE
  /// - Gradient header (uppercase, letter spacing)
  /// - Halka zebra rows, numbers jamni baju (tabular)
  /// - Item = link chip, Branch = badge
  /// - Niche TOTAL row
  Widget buildDataTable() {
    final List<_ColDef> cols = _activeCols;

    if (userlist.isEmpty) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withOpacity(0.07),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.primaryDark,
                  size: 24,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "No records found",
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                "Try another item or customer",
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    final double tableWidth =
    cols.fold<double>(0, (sum, c) => sum + c.width);

    // Item / Branch column nu index
    final int itemIndex = branchMode ? 2 : 1;
    final int branchIndex = branchMode ? 1 : -1;

    const TextStyle numStyle = TextStyle(
      fontSize: 12.5,
      color: Color(0xff1F2937),
      fontFeatures: [FontFeature.tabularFigures()],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Scrollbar(
        controller: _hTableScroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _hTableScroll,
          scrollDirection: Axis.horizontal,
          // Vertical scroll aakhi screen sathe thay chhe
          child: SizedBox(
            width: tableWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// ── HEADER
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryDark,
                        AppColors.secondaryDark,
                      ],
                    ),
                  ),
                  child: Row(
                    children: List.generate(cols.length, (i) {
                      final col = cols[i];
                      return _gridCell(
                        width: col.width,
                        align: _alignOf(col, i),
                        isLast: i == cols.length - 1,
                        dividerColor: Colors.white.withOpacity(0.14),
                        vPad: 13,
                        child: Text(
                          col.title.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            letterSpacing: 0.6,
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                /// ── DATA ROWS
                ...List.generate(userlist.length, (index) {
                  final user = userlist[index];
                  final bool isEven = index % 2 == 0;
                  final values = [
                    "${index + 1}",
                    if (branchMode) _branchNameOf(user),
                    _text(_rowItemName(user), "-"),
                    _text(user["stock_type"], "-"),
                    _partyName(user),
                    _num(user["qty_pcs"]).toStringAsFixed(0),
                    _num(user["gross_weight"]).toStringAsFixed(3),
                    _num(user["less_weight"]).toStringAsFixed(3),
                    _num(user["net_weight"]).toStringAsFixed(3),
                    _num(user["fine_weight"]).toStringAsFixed(3),
                    _num(user["labour_amount"]).toStringAsFixed(2),
                    _num(user["other_amount"]).toStringAsFixed(2),
                  ];

                  return Container(
                    decoration: BoxDecoration(
                      color: isEven
                          ? Colors.white
                          : AppColors.primaryDark.withOpacity(0.028),
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.border.withOpacity(0.7),
                          width: 0.6,
                        ),
                      ),
                    ),
                    child: Row(
                      children: List.generate(cols.length, (i) {
                        final col = cols[i];
                        final bool isLast = i == cols.length - 1;
                        final Alignment align = _alignOf(col, i);

                        Widget content;

                        if (i == 0) {
                          // # → nanu gol badge
                          content = Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.primaryDark.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              values[i],
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          );
                        } else if (i == itemIndex) {
                          // Item → link (tap = details)
                          content = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  values[i],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.primaryDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(
                                Icons.open_in_new_rounded,
                                size: 12,
                                color: AppColors.primaryDark.withOpacity(0.7),
                              ),
                            ],
                          );
                        } else if (i == branchIndex) {
                          // Branch → badge
                          content = Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xff16A34A).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color:
                                const Color(0xff16A34A).withOpacity(0.25),
                              ),
                            ),
                            child: Text(
                              values[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff166534),
                              ),
                            ),
                          );
                        } else {
                          content = Text(
                            values[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: col.alignLeft
                                ? const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xff374151),
                            )
                                : numStyle,
                          );
                        }

                        final Widget cell = _gridCell(
                          width: col.width,
                          align: align,
                          isLast: isLast,
                          dividerColor: AppColors.border.withOpacity(0.6),
                          child: content,
                        );

                        if (i != itemIndex) return cell;
                        return InkWell(
                          onTap: () => _openItemDetails(
                            Map<String, dynamic>.from(user),
                            values[i],
                          ),
                          child: cell,
                        );
                      }),
                    ),
                  );
                }),

                /// ── TOTAL ROW
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark.withOpacity(0.07),
                    border: Border(
                      top: BorderSide(
                        color: AppColors.primaryDark.withOpacity(0.35),
                        width: 1.2,
                      ),
                    ),
                  ),
                  child: Row(
                    children: List.generate(cols.length, (i) {
                      final col = cols[i];
                      final String? key = _totalKeys[col.title];
                      String text = "";
                      if (i == itemIndex) text = "TOTAL";
                      if (key != null) {
                        text = (summaryTotals?[key] ?? "").toString();
                      }
                      return _gridCell(
                        width: col.width,
                        align: _alignOf(col, i),
                        isLast: i == cols.length - 1,
                        dividerColor: AppColors.border.withOpacity(0.6),
                        vPad: 12,
                        child: Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                            letterSpacing: i == itemIndex ? 0.8 : 0,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// "#" vachche, text dabi baju, numbers jamni baju
  Alignment _alignOf(_ColDef col, int index) {
    if (index == 0) return Alignment.center;
    return col.alignLeft ? Alignment.centerLeft : Alignment.centerRight;
  }

  /// 🔥 Item par click → details page (branch mode hoy to branch wise)
  void _openItemDetails(Map<String, dynamic> user, String itemName) {
    final dynamic item = user["item"];
    final String itemId = _text(
      user["item_id"] ?? (item is Map ? item["id"] : null),
      "",
    );

    if (itemId.isEmpty) {
      AppMessage.error(context, "Item ID not found");
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StockPositionDetailsScreen(
          itemId: itemId,
          itemName: itemName,
          stockType: _text(user["stock_type"], ""),
          branchSlugs: branchMode ? _appliedBranchSlugs : const [],
          branchReportUrl: branchMode ? branchStockPositionUrl : null,
          branchNames: {for (final c in branchCompanies) c.id: c.name},
        ),
      ),
    );
  }

  /// Branch merge report nu PDF / Excel URL
  /// company/branch-reports/stock-position?report_branches=a,b&export=pdf
  String _branchExportUrl(String type) {
    final String branches =
    _appliedBranchSlugs.map(Uri.encodeQueryComponent).join(",");
    return "$branchStockPositionUrl?report_branches=$branches&export=$type";
  }

  /// "1,234.5", "<b>12</b>" → 1234.5 (comma / html hoy to pan sacho aankdo)
  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    final String clean = "$v"
        .replaceAll(RegExp(r'<[^>]*>'), "")
        .replaceAll(",", "")
        .replaceAll(RegExp(r'[^0-9.\-]'), "");
    return double.tryParse(clean) ?? 0;
  }

  /// Value ne text ma; object/blank hoy to fallback
  String _text(dynamic v, String fallback) {
    if (v == null || v is Map || v is List) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  /// Party naam — branch report ma object aave to pan chale
  String _partyName(Map user) {
    final dynamic byName = user["party_name"] ?? user["customer_name"];
    if (byName != null && byName.toString().trim().isNotEmpty) {
      return byName.toString();
    }
    final dynamic p = user["party"] ?? user["customer"];
    if (p is Map) return p["name"]?.toString() ?? "-";
    return _text(p, "-");
  }

  /// Stock kai branch no chhe — company_id thi branch list mathi naam
  String _branchNameOf(Map user) {
    final int? companyId = int.tryParse("${user["company_id"] ?? ""}");
    if (companyId != null) {
      for (final c in branchCompanies) {
        if (c.id == companyId) return c.name;
      }
    }
    final dynamic b = user["branch"] ?? user["branch_name"] ?? user["company"];
    if (b is Map) return b["name"]?.toString() ?? "-";
    return _text(b ?? user["company_name"], "-");
  }

  /// 🔥 One table cell with a right-side vertical divider (skipped on the
  /// last column so the outer border stays clean).
  Widget _gridCell({
    required double width,
    required Alignment align,
    required bool isLast,
    required Color dividerColor,
    required Widget child,
    double vPad = 11,
  }) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: vPad),
      alignment: align,
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(right: BorderSide(color: dividerColor, width: 0.8)),
      ),
      child: child,
    );
  }

  Future<void> Stockpositionreport() async {
    // 🔥 Branch report chalu hoy to branch API
    if (branchMode) {
      await _loadBranchReport();
      return;
    }

    final response = await ApiHelper().getRequest(
      ApiConstants.Stock_Position_report,
    );

    print("Stock API URL: ${ApiConstants.Stock_Position_report}");
    print("Stock Raw Response: ${response.toString()}");

    if (!mounted) return;

    if (response != null && response.statusCode == 200) {
      final data = response.data;

      // ✅ success check
      final List categories = data is Map && data['data'] is List
          ? data['data']
          : (data is Map && data['data'] is Map && data['data']['data'] is List
          ? data['data']['data']
          : []);

      searchController.clear();
      searchResults.clear();

      setState(() {
        allUsers = categories; // 🔥 store original
        // Item / Customer pasand karela hoy to e pramane j
        userlist = _filtered(allUsers);
        summaryTotals = calculateSummaryTotals(userlist);
      });

      print("✅ Total user: ${userlist.length}");
    } else {
      setState(() {
        userlist = [];
      });
      print("❌ userlist API failed");
    }
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
      // Branch ma item / customer alag aave → juni pasand saaf
      _clearSelections();
      searchController.clear();
    });

    try {
      await Stockpositionreport();
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
      _clearSelections();
      searchController.clear();
    });
    await Stockpositionreport();
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

  static const String _branchReportsBase =
      "${ApiConstants.baseUrl}company/branch-reports/";

  /// Aa screen ni normal API (ApiConstants.Stock_Position_report) mathi
  /// report nu naam lai ne branch URL banave — sale summary jevu j.
  String get branchStockPositionUrl {
    final String path = Uri.parse(ApiConstants.Stock_Position_report).path;
    const String marker = "/reports/";
    final int i = path.indexOf(marker);

    final String reportName = i >= 0
        ? path.substring(i + marker.length)
        : path.split("/").where((e) => e.isNotEmpty).last;

    return "$_branchReportsBase$reportName";
  }

  String buildBranchReportUrl(int page) {
    // Comma encode na thay (%2C) etle URL hathe banaviye
    final String branches =
    _appliedBranchSlugs.map(Uri.encodeQueryComponent).join(",");

    String url = "$branchStockPositionUrl"
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

    debugPrint("🔥 BRANCH STOCK POSITION API: $url");

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

          allUsers = all;
          userlist = _filtered(all);
          summaryTotals = calculateSummaryTotals(userlist);
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
            summaryTotals = calculateSummaryTotals([]);
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
                "View",
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
        searchResults = [];
        summaryTotals = calculateSummaryTotals(userlist);
      });
      return;
    }

    final response = await ApiHelper().getRequest(
      "${ApiConstants.Barcode_report}/suggest?q=$keyword",
    );

    if (response != null && response.statusCode == 200) {
      setState(() {
        searchResults = response.data["data"];
        summaryTotals = calculateSummaryTotals(searchResults);
      });
    } else {
      print("Search API Failed");
    }
  }

  /// 🔹 PDF Button — premium circular icon button (appbar)
  Widget pdfBtn(bool isMobile, VoidCallback onTap) {
    return Tooltip(
      message: "Download PDF",
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          padding: EdgeInsets.all(isMobile ? 7 : 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xffEF5350), Color(0xffB71C1C)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xffB71C1C).withOpacity(0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            Icons.picture_as_pdf_rounded,
            color: Colors.white,
            size: isMobile ? 18 : 20,
          ),
        ),
      ),
    );
  }

  /// 🔹 Excel Button — premium circular icon button (appbar)
  Widget excelBtn(bool isMobile, VoidCallback onTap) {
    return Tooltip(
      message: "Download Excel",
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          padding: EdgeInsets.all(isMobile ? 7 : 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xff66BB6A), Color(0xff1B5E20)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff1B5E20).withOpacity(0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            Icons.grid_on_rounded,
            color: Colors.white,
            size: isMobile ? 18 : 20,
          ),
        ),
      ),
    );
  }

  Future<void> openPdf() async {
    try {
      // 🔥 Branch merge hoy to branch PDF, nahi to pela jevu
      final String url = branchMode
          ? _branchExportUrl("pdf")
          : ApiConstants.Stock_Position_report_pdf;
      debugPrint("🔥 STOCK POSITION PDF: $url");

      final response = await ApiHelper().getPdfRequest(url);

      if (response != null && response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File("${dir.path}/Stock Position.pdf");

        /// 🔥 IMPORTANT: ensure List<int>
        final bytes = List<int>.from(response.data);

        await file.writeAsBytes(bytes);

        await OpenFile.open(file.path);
      } else {
        print("PDF Download Failed: ${response?.statusCode}");
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  Future<void> openexel(String Code) async {
    try {
      // 🔥 Branch merge hoy to branch Excel, nahi to pela jevu
      final String url = branchMode
          ? _branchExportUrl("excel")
          : ApiConstants.Stock_Position_report_excel;
      debugPrint("🔥 STOCK POSITION EXCEL: $url");

      final response = await ApiHelper().getPdfRequest(url);

      if (response != null && response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File("${dir.path}/Stock Position.xlsx");

        /// 🔥 IMPORTANT: ensure List<int>
        final bytes = List<int>.from(response.data);

        await file.writeAsBytes(bytes);

        await OpenFile.open(file.path);
      } else {
        print("PDF Download Failed: ${response?.statusCode}");
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  Map<String, dynamic> calculateSummaryTotals(List data) {
    double qty = 0;
    double gross = 0;
    double lessWeight = 0;   // 🔥 ADDED — this feeds "Total Other Wt" card
    double net = 0;
    double labour = 0;
    double other = 0;
    double fine = 0;

    for (var item in data) {
      if (item is! Map) continue;
      fine += _num(item["fine_weight"]);
      qty += _num(item["qty_pcs"]);
      gross += _num(item["gross_weight"]);
      lessWeight += _num(item["less_weight"]);
      net += _num(item["net_weight"]);
      labour += _num(item["labour_amount"]);
      other += _num(item["other_amount"]);
    }

    return {
      "qty_pcs": qty.toStringAsFixed(0),
      "gross_weight": gross.toStringAsFixed(3),
      "less_weight": lessWeight.toStringAsFixed(3),   // 🔥 ADDED
      "net_weight": net.toStringAsFixed(3),
      "fine_weight": fine.toStringAsFixed(3),
      "metal_amount": "0.00",
      "labour_amount": labour.toStringAsFixed(2),
      "other_amount": other.toStringAsFixed(2),   // 🔥 FIXED — was 3 decimals, amount should be 2
      "net_total": (labour + other).toStringAsFixed(2),
    };
  }

  void filterByItem(String? itemId) {
    if (itemId == null || itemId.isEmpty) {
      setState(() {
        userlist = allUsers; // જો કઈ સિલેક્ટ ના હોય તો બધો ડેટા બતાવો
        summaryTotals = calculateSummaryTotals(allUsers);
      });
    } else {
      setState(() {
        userlist = allUsers.where((user) {
          return user["item_id"].toString() == itemId;
        }).toList();

        summaryTotals = calculateSummaryTotals(userlist);
      });
    }
  }
}
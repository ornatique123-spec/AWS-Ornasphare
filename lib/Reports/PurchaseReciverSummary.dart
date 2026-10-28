import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pecifician_sysytem/Settings/BranchManagementScreen.dart'
    show BranchApi, Company, BranchTypeX;
import 'package:provider/provider.dart';
import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import '../Dashboard/HomeScreen.dart';
import '../Extra/AppColors.dart';
import '../Extra/AppMessage.dart';
import '../Extra/ItemProvider.dart';
import '../Extra/PremiumSearchableDropdown.dart';
import 'BranchAccess.dart';

/// 🔥 Simple column definition used by the custom grid table
class _ColDef {
  final String title;
  final double width;
  final bool alignLeft;

  const _ColDef(this.title, {required this.width, this.alignLeft = false});
}

class Purchasereciversummary extends StatefulWidget {
  const Purchasereciversummary({super.key});

  @override
  State<Purchasereciversummary> createState() => _PurchasereciversummaryState();
}

class _PurchasereciversummaryState extends State<Purchasereciversummary> {
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

      // 🔥 Date pasand karta j list update (Show dabavvani jarur nathi)
      setState(() => dateFilterApplied = true);
      await _ensureAllBranchPages();
      applyDateFilter();
    }
  }

  /// Row ni date — "2026-10-22", "2026-10-22 10:30:00", "2026-10-22T..",
  /// "22-10-2026" badha chale
  DateTime? _rowDate(Map user) {
    for (final dynamic raw in [
      user["return_date"],
      user["return_date_fmt"],
      user["date"],
      user["created_at"],
    ]) {
      if (raw == null) continue;
      final String s = raw.toString().trim();
      if (s.isEmpty) continue;
      final String first = s.split(RegExp(r'[ T]')).first;

      final DateTime? iso = DateTime.tryParse(first);
      if (iso != null) return DateTime(iso.year, iso.month, iso.day);

      final parts = first.split(RegExp(r'[-/.]'));
      if (parts.length == 3) {
        final int? d = int.tryParse(parts[0]);
        final int? m = int.tryParse(parts[1]);
        final int? y = int.tryParse(parts[2]);
        if (d != null && m != null && y != null) return DateTime(y, m, d);
      }
    }
    return null;
  }

  /// Date filter bandh — badhi date no data
  Future<void> clearDateFilter() async {
    final DateTime today = DateTime.now();
    final String t = "${today.day}-${today.month}-${today.year}";
    setState(() {
      dateFilterApplied = false;
      fromDateController.text = t;
      toDateController.text = t;
    });
    applyDateFilter();
  }
  String? selectedItem;
  String? selectedCustomerName;

  /// ✅ Pasand karelo customer option
  /// normal: {"id": "c12", "cust_id": "12", "name"}
  /// branch: {"id": "9|12", "cust_id", "name", "company_id", "branch"}
  Map<String, dynamic>? _selCustOpt;
  bool dateFilterApplied = false;
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
    List filtered = List.from(allUsers);

    /// =========================================
    /// CUSTOMER FILTER — always active jyare select thay
    /// =========================================
    if (_selCustOpt != null) {
      filtered = filtered
          .where((user) => user is Map && _custMatch(user, _selCustOpt!))
          .toList();
    }

    /// =========================================
    /// DATE FILTER — bas "Show" dabaya pachi j apply thay
    /// =========================================
    if (dateFilterApplied &&
        fromDateController.text.isNotEmpty &&
        toDateController.text.isNotEmpty) {
      DateTime fromDate = _convertToDate(fromDateController.text);
      DateTime toDate = _convertToDate(toDateController.text);

      // From > To hoy to ulta kari de
      if (fromDate.isAfter(toDate)) {
        final DateTime tmp = fromDate;
        fromDate = toDate;
        toDate = tmp;
      }

      filtered = filtered.where((user) {
        if (user is! Map) return false;
        final DateTime? d = _rowDate(user);
        if (d == null) return false;
        return !d.isBefore(fromDate) && !d.isAfter(toDate);
      }).toList();
    }

    setState(() {
      userlist = filtered;
      summaryTotals = calculateTotals(filtered); // 🔥 VERY IMPORTANT
    });
  }




  /// Branch report 25-25 page ma aave — filter pehla badha pages
  Future<void> _ensureAllBranchPages() async {
    if (!branchMode) return;
    int guard = 0;
    while (branchHasMore && mounted && guard < 200) {
      guard++;
      final int before = allUsers.length;
      await _loadBranchReport(loadMore: true);
      if (allUsers.length == before) break;
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    Future.microtask(() {
      Provider.of<ItemProvider>(context, listen: false).loadCustomers();
    });
    DateTime today = DateTime.now();

    String formattedDate = "${today.day}-${today.month}-${today.year}";

    fromDateController.text = formattedDate;
    toDateController.text = formattedDate;

    Purchasereciversummary();
    loadBranches();
  }
  @override
  Widget build(BuildContext context) {

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

            // /// ✅ Background Image
            // Positioned.fill(
            //   child: Image.asset(
            //     "assets/static/img_3.png",
            //     fit: BoxFit.fill,
            //   ),
            // ),

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

                        /// 🔥 TABLE VIEW
                        Container(
                          margin: const EdgeInsets.fromLTRB(10, 8, 10, 10),
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
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 10,),

                /// 🔥 BOTTOM SUMMARY
                buildSummaryRow(),
                SizedBox(height: height * 0.02),


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
                      "Purchase Reciver Summary",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
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

  /// =========================================================
  /// TABLE COLUMN DEFINITIONS — width + numeric alignment in one place
  /// =========================================================
  static const List<_ColDef> _tableCols = [
    _ColDef("#", width: 44),
    _ColDef("Voucher No", width: 150, alignLeft: true),
    _ColDef("Date", width: 100),
    _ColDef("Customer", width: 150, alignLeft: true),
    _ColDef("Qty", width: 70),
    _ColDef("Gross Wt", width: 100),
    _ColDef("Net Wt", width: 100),
    _ColDef("Fine Wt", width: 100),
    _ColDef("Metal Amt", width: 115),
    _ColDef("Labour Amt", width: 115),
    _ColDef("Other Amt", width: 110),
    _ColDef("Total", width: 120),
  ];

  /// =========================================================
  /// MAIN DATA TABLE — proper grid look with vertical dividers between
  /// every column (scrolls both ways so it works on mobile too)
  /// =========================================================
  /// Branch report ma "#" pachhi "Branch" column umerAy
  List<_ColDef> get _activeCols => branchMode
      ? [
    _tableCols.first,
    const _ColDef("Branch", width: 130, alignLeft: true),
    ..._tableCols.skip(1),
  ]
      : _tableCols;

  /// Column → totals key (TOTAL row mate)
  static const Map<String, String> _totalKeys = {
    "Qty": "qty_pcs",
    "Gross Wt": "gross_weight",
    "Net Wt": "net_weight",
    "Fine Wt": "fine_weight",
    "Metal Amt": "metal_amount",
    "Labour Amt": "labour_amount",
    "Other Amt": "other_amount",
    "Total": "net_total",
  };

  /// "#" vachche, text dabi baju, aankda jamni baju
  Alignment _alignOf(_ColDef col, int i) {
    if (i == 0) return Alignment.center;
    if (col.title == "Date") return Alignment.center;
    return col.alignLeft ? Alignment.centerLeft : Alignment.centerRight;
  }

  /// ✨ PREMIUM TABLE
  /// gradient header • zebra rows • voucher bold • branch badge • TOTAL row
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
                child: Icon(Icons.receipt_long_rounded,
                    color: AppColors.primaryDark),
              ),
              const SizedBox(height: 10),
              const Text(
                "No Data Found",
                style: TextStyle(
                  fontSize: 13.5,
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                "Try another customer or date",
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    final double tableWidth =
    cols.fold<double>(0, (sum, c) => sum + c.width);

    final int branchIndex = branchMode ? 1 : -1;
    final int voucherIndex = branchMode ? 2 : 1;
    final int customerIndex = branchMode ? 4 : 3;

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
          child: SizedBox(
            width: tableWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// ── HEADER
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryDark, AppColors.secondaryDark],
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
                    _text(user["return_voucher_no"], "-"),
                    user["return_date_fmt"]?.toString() ??
                        formatDate(user["return_date"]?.toString() ?? ""),
                    _customerName(user) ?? "-",
                    _f0(user["qty_pcs"]),
                    _f2(user["gross_weight"]),
                    _f2(user["net_weight"]),
                    _f2(user["fine_weight"]),
                    _f2(user["metal_amount"]),
                    _f2(user["labour_amount"]),
                    _f2(user["other_amount"]),
                    _f2(user["return_total"] ?? user["net_total"]),
                  ];

                  return InkWell(
                    onLongPress: () => _showDeleteDialog(user),
                    child: Container(
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
                          final bool isTotalCol = col.title == "Total";
                          Widget content;

                          if (i == 0) {
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
                          } else if (i == branchIndex) {
                            content = Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color:
                                const Color(0xff16A34A).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: const Color(0xff16A34A)
                                      .withOpacity(0.25),
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
                              style: i == voucherIndex
                                  ? TextStyle(
                                fontSize: 12.5,
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w700,
                              )
                                  : i == customerIndex
                                  ? const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xff111827),
                                fontWeight: FontWeight.w600,
                              )
                                  : col.alignLeft || col.title == "Date"
                                  ? const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xff374151),
                              )
                                  : isTotalCol
                                  ? numStyle.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
                              )
                                  : numStyle,
                            );
                          }

                          return _gridCell(
                            width: col.width,
                            align: _alignOf(col, i),
                            isLast: isLast,
                            dividerColor: AppColors.border.withOpacity(0.6),
                            child: content,
                          );
                        }),
                      ),
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
                      if (i == voucherIndex) text = "TOTAL";
                      if (key != null && summaryTotals != null) {
                        text = key == "qty_pcs"
                            ? _f0(summaryTotals![key])
                            : _f2(summaryTotals![key]);
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
                            letterSpacing: i == voucherIndex ? 0.8 : 0,
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

  /// Value ne text ma; object/blank hoy to fallback
  String _text(dynamic v, String fallback) {
    if (v == null || v is Map || v is List) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  /// Customer naam — branch report ma "customer" object aave chhe
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

  // ============================================================
  // 🔢 NUMBERS — "." pachhi 2 digit
  // ============================================================

  /// "1,234.5", "₹ 12" → 1234.5
  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    final String clean = "$v"
        .replaceAll(RegExp(r'<[^>]*>'), "")
        .replaceAll(",", "")
        .replaceAll(RegExp(r'[^0-9.\-]'), "");
    return double.tryParse(clean) ?? 0;
  }

  String _f2(dynamic v) => _num(v).toStringAsFixed(2);

  String _f0(dynamic v) => _num(v).toStringAsFixed(0);

  // ============================================================
  // 👤 CUSTOMER — normal: customers list, branch: rows mathi
  // ============================================================

  String _custId(Map u) {
    final dynamic c = u["customer"];
    return _text(u["customer_id"] ?? (c is Map ? c["id"] : null), "");
  }

  bool _custMatch(Map u, Map<String, dynamic> o) {
    final String company = (o["company_id"] ?? "").toString();
    if (company.isNotEmpty && _text(u["company_id"], "") != company) {
      return false;
    }
    final String optId = (o["cust_id"] ?? "").toString();
    final String rowId = _custId(u);
    if (optId.isNotEmpty && rowId.isNotEmpty) return optId == rowId;
    return (_customerName(u) ?? "").trim().toLowerCase() ==
        (o["name"] ?? "").toString().trim().toLowerCase();
  }

  List<Map<String, dynamic>> _customerOptions(ItemProvider provider) {
    final List<Map<String, dynamic>> out = [];

    if (branchMode) {
      final Set<String> seen = {};
      for (final u in allUsers) {
        if (u is! Map) continue;
        final String name = (_customerName(u) ?? "").trim();
        final String id = _custId(u);
        if (name.isEmpty && id.isEmpty) continue;
        final String company = _text(u["company_id"], "");
        final String key = "$company|${id.isNotEmpty ? id : name}";
        if (!seen.add(key)) continue;
        out.add({
          "id": key,
          "cust_id": id,
          "name": name.isEmpty ? "Customer $id" : name,
          "company_id": company,
          "branch": _branchNameOf(u),
        });
      }
      out.sort((a, b) => "${a["name"]}${a["branch"]}"
          .toLowerCase()
          .compareTo("${b["name"]}${b["branch"]}".toLowerCase()));
    } else {
      for (final c in provider.customers) {
        if (c is! Map) continue;
        final String id = _text(c["id"], "");
        out.add({
          "id": "c$id",
          "cust_id": id,
          "name": _text(c["name"], "-"),
          "mobile": _text(c["mobile_no"] ?? c["mobile"], ""),
          "email": _text(c["email"], ""),
        });
      }
    }

    return [
      {"id": "__all__", "name": "All Customers"},
      ...out,
    ];
  }

  /// Bill kai branch nu chhe — company_id thi branch list mathi naam
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

  /// =========================================================
  /// One table cell with a right-side vertical divider (skipped on the
  /// last column so the outer border stays clean).
  /// =========================================================
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
      // Branch ma customer alag aave → juni pasand saaf
      _selCustOpt = null;
      selectedItem = null;
      selectedCustomerName = null;
    });

    try {
      await Purchasereciversummary();
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
      _selCustOpt = null;
      selectedItem = null;
      selectedCustomerName = null;
    });
    await Purchasereciversummary();
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

  /// Aa screen ni normal API (ApiConstants.Purchase_Summary_report) mathi
  /// report nu naam lai ne branch URL banave — sale summary jevu j.
  String get branchPurchaseSummaryUrl {
    final String path = Uri.parse(ApiConstants.Purchase_Summary_report).path;
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

    String url = "$branchPurchaseSummaryUrl"
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

    debugPrint("🔥 BRANCH PURCHASE SUMMARY API: $url");

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
          userlist = all;
          summaryTotals = calculateTotals(all);
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

        searchController.clear();
        // Customer / date pasand hoy to e pramane j
        if (_selCustOpt != null || dateFilterApplied) applyDateFilter();
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
            summaryTotals = calculateTotals([]);
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



  Future<void> Purchasereciversummary() async {

    // 🔥 Branch report chalu hoy to branch API
    if (branchMode) {
      await _loadBranchReport();
      return;
    }

    final response = await ApiHelper().getRequest(
      ApiConstants.Purchase_Summary_report,
    );

    print("Purchase API URL: ${ApiConstants.Purchase_Summary_report}");
    print("Purchase Raw Response: ${response.toString()}");

    if (!mounted) return;

    if (response != null && response.statusCode == 200) {

      final data = response.data;

      // ✅ success check
      final List categories = data is Map && data['data'] is List
          ? data['data']
          : (data is Map && data['data'] is Map && data['data']['data'] is List
          ? data['data']['data']
          : []);
      // final List banner = data['data']['banner_ads'];
      // final List popupAds = data['data']['PopupBannerAd'];

      setState(() {
        userlist = categories;
        allUsers = categories; // 🔥 store original
        //summaryTotals = data["totals"]; // 🔥 IMPORTANT
        summaryTotals = calculateTotals(categories);
        // optional: if needed later
        // bannerList = data['data']['banner_ads'];
        // popupBanner = data['data']['PopupBannerAd'];
      });

      // 🔥 applyDateFilter() removed from here — date filter should
      // only apply when the user presses "Show", not on initial load
      if (_selCustOpt != null || dateFilterApplied) applyDateFilter();
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        children: [

          /// =========================================================
          /// CUSTOMER — SEARCHABLE DROPDOWN
          /// =========================================================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Consumer<ItemProvider>(
              builder: (context, provider, child) {
                // ✅ Branch merge hoy to branch na customer (branch naam sathe)
                final List<Map<String, dynamic>> opts =
                _customerOptions(provider);

                return PremiumSearchableDropdown<Map<String, dynamic>>(
                  label: "",
                  hint: "All Customers",
                  items: opts,
                  value: _selCustOpt,
                  prefixIcon: Icons.person_outline,
                  menuWidth: MediaQuery.of(context).size.width * 0.92,
                  itemLabel: (o) {
                    final String b = (o["branch"] ?? "").toString();
                    return b.isEmpty || b == "-"
                        ? (o["name"] ?? "-").toString()
                        : "${o["name"]}  •  $b";
                  },
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
                      selectedItem = all ? null : o["cust_id"]?.toString();
                      selectedCustomerName =
                      all ? null : o["name"]?.toString();
                    });
                    // Branch ma baki na page pan lai ne filter
                    if (!all) await _ensureAllBranchPages();
                    applyDateFilter();
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 5),
          /// 📅 DATE ROW
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(fromDateController),
                  child: IgnorePointer(
                    child: TextField(
                      controller: fromDateController,
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        hintText: "From Date",
                        hintStyle: TextStyle(color: Colors.grey.shade600),
                        suffixIcon: const Icon(Icons.calendar_today, size: 18,color: AppColors.primaryDark,),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
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
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(toDateController),
                  child: IgnorePointer(
                    child: TextField(
                      controller: toDateController,
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        hintText: "To Date",
                        hintStyle: TextStyle(color: Colors.grey.shade600),
                        suffixIcon: const Icon(Icons.calendar_today, size: 18,color: AppColors.primaryDark,),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
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
                  ),
                ),
              ),
            ],
          ),

          // 🔥 Date filter chalu hoy tyare info + Clear
          if (dateFilterApplied) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withOpacity(0.06),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                    color: AppColors.primaryDark.withOpacity(0.18)),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_available_rounded,
                      size: 15, color: AppColors.primaryDark),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "${fromDateController.text}  →  ${toDateController.text}"
                          "  •  ${userlist.length} records",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: clearDateFilter,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 26),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                    setState(() {
                      dateFilterApplied = true; // 🔥 have date filter active thashe
                    });

                    // Branch ma baki na page pan lai ne filter
                    await _ensureAllBranchPages();
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
                    openPdf();
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

      default:
        startColor = const Color(0xff9E9E9E);
        endColor   = const Color(0xffCFCFCF);
        label = "Unknown";
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
        child: Icon(icon, color:Colors.red, size: 20),
      ),
    );
  }

  Widget _erpRow(String t1, String v1, String t2, String v2) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [

          /// Left Field
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    t1,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black, // ✅ FIX
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    v1,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black, // ✅ FIX
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// Right Field
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    t2,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black, // ✅ FIX
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    v2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black, // ✅ FIX
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

  Widget _erpRow1(String t1, String v1, String t2, String v2) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          /// Left Field
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    t1,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black, // ✅ FIX
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    v1,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black, // ✅ FIX
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// Right Field
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    t2,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black, // ✅ FIX
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    v2,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black, // ✅ FIX
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

    final response = await ApiHelper().getRequest(
      "${ApiConstants.Barcode_report}/suggest?q=$keyword",
    );

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
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xffE57373), Color(0xffD32F2F),Color(0xffE57373)],
          ),
          borderRadius: BorderRadius.circular(8),
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
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xff66BB6A), // light green
              Color(0xff2E7D32), // dark green
              Color(0xff66BB6A), // light green
            ],
          ),
          borderRadius: BorderRadius.circular(8),
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


  Future<void> openPdf() async {
    try {
      // 🔥 Branch merge report hoy to:
      //   company/branch-reports/<report>?report_branches=slug1,slug2&export=pdf
      // nahi to pela jevu j
      final String url;
      if (branchMode) {
        // Comma encode na thay (%2C) etle URL hathe banaviye
        final String branches =
        _appliedBranchSlugs.map(Uri.encodeQueryComponent).join(",");
        url = "$branchPurchaseSummaryUrl"
            "?report_branches=$branches"
            "&export=pdf";
      } else {
        url = ApiConstants.Purchase_Summary_report_pdf;
      }

      debugPrint("🔥 PURCHASE SUMMARY PDF API: $url");

      final response = await ApiHelper().getPdfRequest(url);

      if (response != null && response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File("${dir.path}/purchase_Reciver Summary.pdf");

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
      // Branch merge → company/branch-reports/<report>?report_branches=..&export=excel
      final String url;
      if (branchMode) {
        final String branches =
        _appliedBranchSlugs.map(Uri.encodeQueryComponent).join(",");
        url = "$branchPurchaseSummaryUrl"
            "?report_branches=$branches"
            "&export=excel";
      } else {
        url = ApiConstants.Purchase_Summary_report_excel;
      }
      debugPrint("🔥 PURCHASE SUMMARY EXCEL API: $url");

      final response = await ApiHelper().getPdfRequest(url);

      if (response != null && response.statusCode == 200) {
        final dynamic raw = response.data;
        final Uint8List? bytes = raw is Uint8List
            ? raw
            : (raw is List<int> ? Uint8List.fromList(raw) : null);
        if (bytes == null || bytes.isEmpty || bytes.first == 0x7B) {
          if (mounted) AppMessage.error(context, "No file received from server");
          return;
        }
        final dir = await getTemporaryDirectory();
        final file = File(
            "${dir.path}/Purchase_Receiver_Summary_${DateTime.now().millisecondsSinceEpoch}.xlsx");
        await file.writeAsBytes(bytes, flush: true);
        await OpenFile.open(file.path);
      } else {
        if (mounted) AppMessage.error(context, "Excel Download Failed");
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  /// ✨ BOTTOM SUMMARY — premium cards ("." pachhi 2 digit)
  Widget buildSummaryRow() {
    if (summaryTotals == null) return const SizedBox();
    final t = summaryTotals!;

    final cards = <Widget>[
      _summaryBox("Vouchers", _f0(t["voucher_count"]),
          Icons.receipt_long_rounded, const Color(0xff0F766E)),
      _summaryBox("Qty", _f0(t["qty_pcs"]), Icons.inventory_2_outlined,
          AppColors.primaryDark),
      _summaryBox("Gross Wt", _f2(t["gross_weight"]), Icons.scale_rounded,
          const Color(0xff7C3AED)),
      _summaryBox("Net Wt", _f2(t["net_weight"]), Icons.balance_rounded,
          const Color(0xff2563EB)),
      _summaryBox("Fine Wt", _f2(t["fine_weight"]), Icons.diamond_outlined,
          const Color(0xffB45309)),
      _summaryBox("Metal Amt", _f2(t["metal_amount"]),
          Icons.currency_rupee_rounded, const Color(0xff0E7490)),
      _summaryBox("Labour Amt", _f2(t["labour_amount"]),
          Icons.handyman_outlined, const Color(0xff9333EA)),
      _summaryBox("Other Amt", _f2(t["other_amount"]),
          Icons.add_card_rounded, const Color(0xffEA580C)),
      _summaryBox("Total", _f2(t["net_total"]),
          Icons.account_balance_wallet_rounded, const Color(0xff16A34A)),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.primaryDark.withOpacity(0.15)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SizedBox(
        height: 52,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemCount: cards.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => cards[i],
        ),
      ),
    );
  }

  Widget _summaryBox(String title, String value, IconData icon, Color color) {
    return Container(
      constraints: const BoxConstraints(minWidth: 118),
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
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

  Map<String, dynamic> calculateTotals(List data) {
    double vouchers = 0;
    double qty = 0, gross = 0, net = 0, fine = 0;
    double metal = 0, labour = 0, other = 0, total = 0;

    for (var item in data) {
      if (item is! Map) continue;
      vouchers += 1;
      qty += _num(item["qty_pcs"]);
      gross += _num(item["gross_weight"]);
      net += _num(item["net_weight"]);
      fine += _num(item["fine_weight"]);
      metal += _num(item["metal_amount"]);
      labour += _num(item["labour_amount"]);
      other += _num(item["other_amount"]);
      // Table ma je Total dekhay e j (return_total na hoy to net_total)
      total += _num(item["return_total"] ?? item["net_total"]);
    }

    return {
      "voucher_count": vouchers,
      "qty_pcs": qty,
      "gross_weight": gross,
      "net_weight": net,
      "fine_weight": fine,
      "metal_amount": metal,
      "labour_amount": labour,
      "other_amount": other,
      "net_total": total,
    };
  }


}
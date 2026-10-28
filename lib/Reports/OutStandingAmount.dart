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

class Outstandingamount extends StatefulWidget {
  const Outstandingamount({super.key});

  @override
  State<Outstandingamount> createState() => _OutstandingamountState();
}

class _OutstandingamountState extends State<Outstandingamount> {
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
    DateTime initial = DateTime.now();
    try {
      if (controller.text.isNotEmpty) initial = _convertToDate(controller.text);
    } catch (_) {}

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      controller.text =
      "${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}";
      // ✅ Date badlay e j vakhte list update
      if (useDate) _applyFilters();
    }
  }
  String? selectedItem;
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


  String? selectedCity;
  void searchUser(String value) {
    _applyFilters();
  }

  /// 🔥 CHECKBOX VARIABLES
  /// Start ma "Default Report" → badho data. Checkbox lagavo e pramane
  /// list tarat update thay.
  bool useDefault = true;

  /// Report Filters card khulyu chhe? (start ma bandh — fakt Default)
  bool filtersExpanded = false;
  bool useDate = false;
  bool useParty = false;
  Map<String, dynamic>? _selPartyOpt;
  bool useCity = false;
  /// 🔥 VARIABLES ADD KARO
  bool useWeight = false;
  bool useAmount = false;

  TextEditingController weightFromController = TextEditingController();
  TextEditingController weightToController = TextEditingController();

  TextEditingController amountFromController = TextEditingController();
  TextEditingController amountToController = TextEditingController();
  /// Juno naam — have badha filter sathe
  void applyDateFilter() => _applyFilters();

  // ============================================================
  // 🔥 FILTER ENGINE (client side — default data upar)
  // ============================================================

  bool get _anyFilter =>
      useDate || useParty || useCity || useWeight || useAmount;

  /// "₹ 1,234.50", "<b>12.5</b>", "12.500 g" → number
  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    final String clean = "$v"
        .replaceAll(RegExp(r'<[^>]*>'), "")
        .replaceAll(",", "")
        .replaceAll(RegExp(r'[^0-9.\-]'), "");
    return double.tryParse(clean) ?? 0;
  }

  // ============================================================
  // 🔥 ROW NORMALIZE
  //
  // Branch report ni rows ma field na naam alag aave chhe
  // (gross_wt, balance, voucher_date, party_name...) ane ghani vaar
  // andar nested object ma hoy. Etle list ma badhu 0 aavtu.
  // Aa function dar row ne normal report na naam ma fervi de chhe.
  // ============================================================

  static const Map<String, List<String>> _aliases = {
    "voucher_no": [
      "voucher_no", "voucher_number", "bill_no", "invoice_no", "sale_no",
      "voucher", "no",
    ],
    "sale_date": [
      "sale_date", "voucher_date", "bill_date", "invoice_date", "date",
      "created_at",
    ],
    "party": [
      "customer_name", "party", "party_name", "customer_name", "customer", "account_name",
      "name",
    ],
    "city": ["city", "party_city", "customer_city"],
    "gross_weight": [
      "gross_weight", "sum_gross_weight", "gross_weight_fmt", "gross_wt", "total_gross_weight", "total_gross_wt",
      "gross",
    ],
    "net_weight": [
      "net_weight", "sum_net_weight", "net_weight_fmt", "net_wt", "total_net_weight", "total_net_wt", "net",
    ],
    "total_amount": [
      "total_amount", "grand_total", "net_total", "total", "bill_amount",
      "amount", "net_amount",
    ],
    "amount_in": [
      "amount_in", "amount_in_fmt", "received_amount", "in_amount", "received",
      "credit", "amount_received",
    ],
    "amount_out": [
      "amount_out", "amount_out_fmt", "paid_amount", "out_amount", "debit", "given_amount", "amount_paid",
    ],
    "fine_weight": [
      "fine_weight", "sum_fine_weight", "fine_weight_fmt", "fine_wt",
    ],
    "metal_amount": [
      "metal_amount", "sum_metal_amount", "metal_amount_fmt",
    ],
    "labour_amount": [
      "labour_amount", "sum_labour_amount", "labour_amount_fmt",
    ],
    "metal_debit": [
      "metal_debit", "metal_dr", "metal_debit_fmt",
    ],
    "pending": [
      "pending", "pending_amount", "pending_amount_fmt", "balance", "balance_amount",
      "outstanding", "outstanding_amount", "due", "due_amount", "remaining",
    ],
  };

  /// Nested object (sale / voucher / data / row / attributes) ne bahar lavo
  Map<String, dynamic> _flatten(Map raw) {
    final Map<String, dynamic> out = {};
    for (final key in ["sale", "voucher", "data", "row", "attributes"]) {
      final dynamic inner = raw[key];
      if (inner is Map) {
        inner.forEach((k, v) => out.putIfAbsent("$k", () => v));
      }
    }
    raw.forEach((k, v) => out["$k"] = v); // bahar na field ni priority
    return out;
  }

  bool _isBlank(dynamic v) =>
      v == null || (v is String && (v.trim().isEmpty || v == "null"));

  Map<String, dynamic> _normalizeRow(dynamic raw) {
    if (raw is! Map) return {};
    final Map<String, dynamic> row = _flatten(raw);

    const Set<String> textKeys = {"voucher_no", "sale_date", "party", "city"};
    bool pendingFound = false;

    _aliases.forEach((canon, keys) {
      final bool numeric = !textKeys.contains(canon);

      // ✅ Je pehli key HAJAR hoy e j levani — 0 hoy to pan.
      // (pehla 0 hoy to biji key par jatu → Amount In / Pending khota)
      for (final k in keys) {
        final dynamic v = row[k];
        if (_isBlank(v)) continue;
        if (numeric && (v is Map || v is List)) continue;
        if (!numeric && v is List) continue;
        row[canon] = numeric ? _num(v) : v;
        if (canon == "pending") pendingFound = true;
        break;
      }
    });

    // Pending koi key ma j na aave tyare j gano
    if (!pendingFound && _num(row["total_amount"]) != 0) {
      final double p = _num(row["total_amount"]) -
          _num(row["amount_in"]) +
          _num(row["amount_out"]);
      row["pending"] = p > 0 ? p : 0.0;
    }

    return row;
  }

  List _normalizeAll(List rows) {
    if (rows.isNotEmpty && rows.first is Map) {
      debugPrint("🔎 OUTSTANDING ROW KEYS => ${(rows.first as Map).keys.toList()}");
    }
    return rows.map(_normalizeRow).where((e) => e.isNotEmpty).toList();
  }

  DateTime? _rowDate(Map u) {
    final String raw = "${u["sale_date"] ?? u["date"] ?? ""}".trim();
    if (raw.isEmpty) return null;
    final DateTime? iso = DateTime.tryParse(raw.split(" ").first);
    if (iso != null) return iso;
    try {
      return _convertToDate(raw.split(" ").first);
    } catch (_) {
      return null;
    }
  }

  String _rowPartyName(Map u) =>
      _text(u["party"] ?? u["customer_name"] ?? u["customer"], "");

  String _rowPartyId(Map u) {
    final dynamic c = u["customer"] ?? u["party"];
    return _text(
      u["customer_id"] ?? u["party_id"] ?? (c is Map ? c["id"] : null),
      "",
    );
  }

  String _rowCity(Map u) => _text(u["city"], "");

  /// Weight = net (na hoy to gross), Amount = pending
  double _rowWeight(Map u) {
    final double n = _num(u["net_weight"]);
    return n != 0 ? n : _num(u["gross_weight"]);
  }

  double _rowAmount(Map u) => _num(u["pending"] ?? u["pending_amount"]);

  bool _partyMatch(Map u, Map<String, dynamic> o) {
    final String company = (o["company_id"] ?? "").toString();
    if (company.isNotEmpty && _text(u["company_id"], "") != company) {
      return false;
    }
    final String optId = (o["cust_id"] ?? "").toString();
    final String rowId = _rowPartyId(u);
    if (optId.isNotEmpty && rowId.isNotEmpty) return optId == rowId;
    return _rowPartyName(u).toLowerCase() ==
        (o["name"] ?? "").toString().toLowerCase();
  }

  List _filtered(List src) {
    if (useDefault || !_anyFilter) {
      return _searchOnly(src);
    }

    DateTime? from, to;
    if (useDate) {
      try {
        if (fromDateController.text.isNotEmpty) {
          from = _convertToDate(fromDateController.text);
        }
        if (toDateController.text.isNotEmpty) {
          to = _convertToDate(toDateController.text);
        }
      } catch (_) {}
    }

    final double? wFrom = double.tryParse(weightFromController.text.trim());
    final double? wTo = double.tryParse(weightToController.text.trim());
    final double? aFrom = double.tryParse(amountFromController.text.trim());
    final double? aTo = double.tryParse(amountToController.text.trim());

    return _searchOnly(src.where((u) {
      if (u is! Map) return false;

      if (useDate && (from != null || to != null)) {
        final DateTime? d = _rowDate(u);
        if (d == null) return false;
        final DateTime day = DateTime(d.year, d.month, d.day);
        if (from != null && day.isBefore(from)) return false;
        if (to != null && day.isAfter(to)) return false;
      }

      if (useParty && _selPartyOpt != null && !_partyMatch(u, _selPartyOpt!)) {
        return false;
      }

      if (useCity && selectedCity != null && selectedCity!.isNotEmpty) {
        if (_rowCity(u).toLowerCase() != selectedCity!.toLowerCase()) {
          return false;
        }
      }

      if (useWeight) {
        final double w = _rowWeight(u);
        if (wFrom != null && wFrom > 0 && w < wFrom) return false;
        if (wTo != null && wTo > 0 && w > wTo) return false;
      }

      if (useAmount) {
        final double a = _rowAmount(u);
        if (aFrom != null && aFrom > 0 && a < aFrom) return false;
        if (aTo != null && aTo > 0 && a > aTo) return false;
      }

      return true;
    }).toList());
  }

  List _searchOnly(List src) {
    final String q = searchController.text.trim().toLowerCase();
    if (q.isEmpty) return src;
    return src.where((u) {
      if (u is! Map) return false;
      return [
        _text(u["voucher_no"], ""),
        _rowPartyName(u),
        _rowCity(u),
        if (branchMode) _branchNameOf(u),
      ].join(" ").toLowerCase().contains(q);
    }).toList();
  }

  void _applyFilters() {
    if (!mounted) return;
    setState(() {
      userlist = _filtered(allUsers);
      summaryTotals = calculateTotals(userlist);
    });
  }

  /// Checkbox badlay → Default bandh / chalu + list update
  Future<void> _toggle(void Function() change) async {
    setState(() {
      change();
      useDefault = !_anyFilter;
    });
    if (_anyFilter) await _ensureAllBranchPages();
    _applyFilters();
  }

  void _setDefault(bool v) {
    setState(() {
      useDefault = true;
      useDate = false;
      useParty = false;
      useCity = false;
      useWeight = false;
      useAmount = false;
    });
    _applyFilters();
  }

  void _resetAll() {
    searchController.clear();
    final String today = _todayText();
    fromDateController.text = today;
    toDateController.text = today;
    weightFromController.clear();
    weightToController.clear();
    amountFromController.clear();
    amountToController.clear();
    _selPartyOpt = null;
    selectedItem = null;
    selectedCity = null;
    _setDefault(true);
  }

  String _todayText() {
    final DateTime t = DateTime.now();
    return "${t.day.toString().padLeft(2, '0')}-${t.month.toString().padLeft(2, '0')}-${t.year}";
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
    //print("🔥 Checking '$permissionName' in $userPermissions => ${userPermissions.contains(permissionName)}");
    return userPermissions.contains(permissionName);
  }


  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    loadPermissions();
    Future.microtask(() {
      Provider.of<ItemProvider>(context, listen: false).loadCustomers();
    });
    DateTime today = DateTime.now();

    String formattedDate =
        "${today.day.toString().padLeft(2, '0')}-${today.month.toString().padLeft(2, '0')}-${today.year}";

    fromDateController.text = formattedDate;
    toDateController.text = formattedDate;
    Salesumryreport();

    // 🔥 Branch list (fakt main company admin ne j tab dekhashe)
    loadBranches();
  }

  @override
  void dispose() {
    searchController.dispose();
    fromDateController.dispose();
    toDateController.dispose();
    weightFromController.dispose();
    weightToController.dispose();
    amountFromController.dispose();
    amountToController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {

    if(!(
        hasPermission("report-outstanding-amount-view") ||
            hasPermission("report-outstanding-amount-manage")
    )){
      return Scaffold(
        body: PermissionDeniedWidget(
          onBack: (){
            Navigator.pop(context,true);
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

            /// ✅ Background Image
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
                        const SizedBox(height: 8),

                        filterWidget(),

                        /// ✨ SUMMARY CARDS (filter pramane)
                        _summaryGrid(isMobile),

                        /// List header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryDark,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Vouchers",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryDark.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  "${userlist.length}",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                useDefault ? "Default report" : "Filtered",
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

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
                          SizedBox(
                            height: 200,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryDark
                                          .withOpacity(0.07),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.receipt_long_rounded,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    "No Data Found",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    "Change filters to see vouchers",
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              children: [
                                for (final u in userlist) buildUserCard(u),
                              ],
                            ),
                          ),

                        if (branchMode && branchHasMore) _loadMoreButton(),
                      ],
                    ),
                  ),
                ),


                SizedBox(height: height * 0.02),

                // /// Bottom Button
                // InkWell(
                //   onTap: () {
                //     Navigator.push(
                //       context,
                //       MaterialPageRoute(
                //         builder: (context) => const Creteuserscreen(),
                //       ),
                //     );
                //   },
                //   borderRadius: BorderRadius.circular(15),
                //   child: Container(
                //     margin: const EdgeInsets.all(16),
                //     padding: const EdgeInsets.symmetric(vertical: 14),
                //     decoration: BoxDecoration(
                //       gradient: const LinearGradient(
                //         colors: [
                //           Color(0xffE6C58A),
                //           Color(0xffC8A96A),
                //           Color(0xffE6C58A)
                //         ],
                //       ),
                //       borderRadius: BorderRadius.circular(15),
                //     ),
                //     child: const Center(
                //       child: Text(
                //         "+ Create Approval",
                //         style: TextStyle(
                //           fontWeight: FontWeight.bold,
                //           color: Colors.black,
                //           fontSize: 16,
                //         ),
                //       ),
                //     ),
                //   ),
                // ),
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
                      "Outstanding Amount",
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

                    /// RIGHT NOTIFICATION ICON
                    // Align(
                    //   alignment: Alignment.centerRight,
                    //
                    //   child: Container(
                    //     padding: EdgeInsets.all(isMobile ? 6 : 8),
                    //
                    //     decoration: BoxDecoration(
                    //       color: Colors.white,
                    //
                    //       borderRadius: BorderRadius.circular(8),
                    //
                    //       boxShadow: [
                    //         BoxShadow(
                    //           color: AppColors.shadow,
                    //
                    //           blurRadius: 20,
                    //
                    //           offset: const Offset(5, 10),
                    //         ),
                    //       ],
                    //     ),
                    //
                    //     child: Stack(
                    //       clipBehavior: Clip.none,
                    //
                    //       children: [
                    //         Icon(
                    //           Icons.notifications_none,
                    //
                    //           size: isMobile ? 22 : 24,
                    //
                    //           color: Colors.red,
                    //         ),
                    //
                    //         Positioned(
                    //           right: -2,
                    //
                    //           top: -2,
                    //
                    //           child: Container(
                    //             height: 8,
                    //
                    //             width: 8,
                    //
                    //             decoration: const BoxDecoration(
                    //               color: Colors.red,
                    //
                    //               shape: BoxShape.circle,
                    //             ),
                    //           ),
                    //         ),
                    //       ],
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              ),
            )

          ],
        ),
      ),
    );

  }





  /// ✨ PREMIUM VOUCHER CARD
  Widget buildUserCard(Map user) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;

    final double pending = _rowAmount(user);
    final bool isPending = pending > 0.0001;
    final Color stateColor =
    isPending ? const Color(0xffDC2626) : const Color(0xff16A34A);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryDark.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              /// Side colour strip (pending = lal, clear = lilo)
              Container(width: 4, color: stateColor),

              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(isTablet ? 14 : 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// ── TOP: voucher + party + delete
                      Row(
                        children: [
                          // Lambo voucher no hoy to pan jagya bahar na jay
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: size.width * 0.38,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primaryDark,
                                    AppColors.secondaryDark,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                _text(user["voucher_no"], "-"),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _text(_rowPartyName(user), "-"),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xff111827),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today_rounded,
                                        size: 11, color: Colors.grey.shade500),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        formatDate(
                                            (user["sale_date"] ?? "").toString()),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                    if (_rowCity(user).isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Icon(Icons.location_on_outlined,
                                          size: 12,
                                          color: Colors.grey.shade500),
                                      const SizedBox(width: 2),
                                      Flexible(
                                        child: Text(
                                          _rowCity(user),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (hasPermission("report-outstanding-amount-delete"))
                            premiumIconBtn(
                              Icons.delete_outline_rounded,
                              Colors.red,
                              onTap: () => _showDeleteDialog(user),
                            ),
                        ],
                      ),

                      /// Branch badge (merge vakhte)
                      if (branchMode) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xff16A34A).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: const Color(0xff16A34A).withOpacity(0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.account_tree_rounded,
                                  size: 11, color: Color(0xff166534)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _branchNameOf(user),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xff166534),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 10),

                      /// ── METRICS
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark.withOpacity(0.035),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                _metric("Gross Wt",
                                    _num(user["gross_weight"]).toStringAsFixed(3)),
                                _metric("Net Wt",
                                    _num(user["net_weight"]).toStringAsFixed(3)),
                                _metric("Fine Wt",
                                    _num(user["fine_weight"]).toStringAsFixed(3)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _metric("Metal Amt",
                                    _num(user["metal_amount"]).toStringAsFixed(2)),
                                _metric("Labour Amt",
                                    _num(user["labour_amount"]).toStringAsFixed(2)),
                                _metric("Metal Dr",
                                    _num(user["metal_debit"]).toStringAsFixed(3)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _metric("Total",
                                    _num(user["total_amount"]).toStringAsFixed(2)),
                                _metric("Amount In",
                                    _num(user["amount_in"]).toStringAsFixed(2),
                                    color: const Color(0xff16A34A)),
                                _metric("Amount Out",
                                    _num(user["amount_out"]).toStringAsFixed(2),
                                    color: const Color(0xffEA580C)),
                              ],
                            ),
                            const SizedBox(height: 8),

                            /// Pending — alag highlight patti
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: stateColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                    color: stateColor.withOpacity(0.25)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.hourglass_bottom_rounded,
                                      size: 14, color: stateColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Pending",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: stateColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      pending.toStringAsFixed(2),
                                      textAlign: TextAlign.right,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: stateColor,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(String label, String value,
      {Color? color, bool bold = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
              color: color ?? const Color(0xff111827),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  /// Value ne text ma; object/blank hoy to fallback
  String _text(dynamic v, [String fallback = "-"]) {
    if (v == null || v is List) return fallback;
    if (v is Map) {
      final n = v["name"] ?? v["customer_name"];
      return n == null ? fallback : n.toString();
    }
    final s = v.toString().trim();
    return s.isEmpty || s == "null" ? fallback : s;
  }

  /// Card kai branch nu chhe — company_id thi branch list mathi naam
  String _branchNameOf(Map user) {
    final int? companyId = int.tryParse("${user["company_id"] ?? ""}");
    if (companyId != null) {
      for (final c in branchCompanies) {
        if (c.id == companyId) return c.name;
      }
    }
    return _text(user["branch"] ??
        user["branch_name"] ??
        user["company"] ??
        user["company_name"]);
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
      _selPartyOpt = null;
      selectedItem = null;
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
      _selPartyOpt = null;
      selectedItem = null;
    });
    await Salesumryreport();
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

  /// Aa screen ni normal API (ApiConstants.OutStanding_amount_report) mathi
  /// report nu naam lai ne branch URL banave — sale summary jevu j.
  String get branchOutstandingAmountUrl {
    final String path = Uri.parse(ApiConstants.OutStanding_amount_report).path;
    const String marker = "/reports/";
    final int i = path.indexOf(marker);

    final String reportName = i >= 0
        ? path.substring(i + marker.length)
        : "outstanding-amount";

    return "$_branchReportsBase$reportName";
  }

  String buildBranchReportUrl(int page) {
    // Comma encode na thay (%2C) etle URL hathe banaviye
    final String branches =
    _appliedBranchSlugs.map(Uri.encodeQueryComponent).join(",");

    String url = "$branchOutstandingAmountUrl"
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

    debugPrint("🔥 BRANCH OUTSTANDING AMOUNT API: $url");

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
        } else if (data is Map && data["rows"] is List) {
          rows = data["rows"];
        } else if (body["rows"] is List) {
          rows = body["rows"];
        }

        // ✅ Branch na field naam → normal naam (0 na aave)
        rows = _normalizeAll(rows);

        if (!mounted) return;

        setState(() {
          // Page overlap thay to same voucher 2 vaar na gane
          final Set<String> seen = {};
          final List all = (loadMore ? [...allUsers, ...rows] : rows)
              .where((r) => r is! Map ||
              seen.add("${r["company_id"]}|${r["id"]}|${r["voucher_no"]}"))
              .toList();

          allUsers = all;
          userlist = _filtered(all);
          summaryTotals = calculateTotals(userlist);
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



  Future<void> Salesumryreport() async {

    // 🔥 Branch report chalu hoy to branch API
    if (branchMode) {
      await _loadBranchReport();
      return;
    }

    final response = await ApiHelper().getRequest(
      ApiConstants.OutStanding_amount_report,
    );

    print("user API URL: ${ApiConstants.OutStanding_amount_report}");
    print("users Raw Response: ${response.toString()}");

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
        allUsers = _normalizeAll(categories); // 🔥 store original
        // ✅ Start ma default (badho data) — checkbox hoy to e pramane
        userlist = _filtered(allUsers);
        summaryTotals = calculateTotals(userlist);
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

  // ============================================================
  // ✨ PREMIUM FILTER PANEL (web jevu — checkbox vala section)
  // ============================================================

  Widget filterWidget() {
    final double w = MediaQuery.of(context).size.width;
    final bool isTablet = w >= 600;
    final bool isNarrow = w < 360; // nana phone (320-359)

    return Container(
      margin: EdgeInsets.fromLTRB(isTablet ? 14 : 10, 5, isTablet ? 14 : 10, 0),
      padding: EdgeInsets.all(isTablet ? 14 : 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryDark.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          /// Title (tap = expand / collapse) + Default report
          InkWell(
            onTap: () => setState(() => filtersExpanded = !filtersExpanded),
            borderRadius: BorderRadius.circular(5),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryDark, AppColors.secondaryDark],
                    ),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Icon(Icons.tune_rounded,
                      size: 14, color: Colors.white),
                ),
                const SizedBox(width: 8),
                // 🔥 Title + badge baki ni badhi jagya le → Default jamni baju j rahe
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          "Report Filters",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                      if (_activeCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            "$_activeCount",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _checkChip(
                  label: isNarrow ? "Default" : "Default Report",
                  value: useDefault,
                  onTap: () => _setDefault(true),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: filtersExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.primaryDark,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),

          /// ── BODY (expand thay tyare j)
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: !filtersExpanded
                ? const SizedBox(width: double.infinity)
                : Padding(
              padding: const EdgeInsets.only(top: 12),
              // 🔥 Sachi jagya pramane column: mobile 1, tablet 2, moti screen 3
              child: LayoutBuilder(builder: (context, box) {
                const double gap = 10;
                final double avail = box.maxWidth;
                final int cols = avail < 560 ? 1 : (avail < 900 ? 2 : 3);
                final double cardW = (avail - gap * (cols - 1)) / cols;
                final bool oneCol = cols == 1;

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    /// 📅 DATE
                    _section(
                      width: cardW,
                      title: "Use Date",
                      icon: Icons.date_range_rounded,
                      value: useDate,
                      onChanged: (v) => _toggle(() => useDate = v),
                      child: Row(
                        children: [
                          Expanded(
                            child: _dateField("From Date", fromDateController),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _dateField("To Date", toDateController),
                          ),
                        ],
                      ),
                    ),

                    /// 👤 PARTY
                    _section(
                      width: cardW,
                      title: "Use Party",
                      icon: Icons.person_outline_rounded,
                      value: useParty,
                      onChanged: (v) => _toggle(() => useParty = v),
                      child: Consumer<ItemProvider>(
                        builder: (context, provider, _) {
                          return PremiumSearchableDropdown<Map<String, dynamic>>(
                            label: "",
                            hint: "All Parties",
                            enabled: useParty,
                            items: _partyOptions(provider),
                            value: _selPartyOpt,
                            prefixIcon: Icons.person_outline,
                            menuWidth: isTablet ? (w * 0.6).clamp(320.0, 560.0).toDouble() : w * 0.92,
                            itemLabel: (o) {
                              final String b = (o["branch"] ?? "").toString();
                              return b.isEmpty
                                  ? (o["name"] ?? "-").toString()
                                  : "${o["name"]}  •  $b";
                            },
                            searchText: (o) => [
                              o["name"],
                              o["mobile"],
                              o["branch"],
                            ].map((e) => e?.toString() ?? "").join(" "),
                            onChanged: (o) async {
                              final bool all = o == null || o["id"] == "__all__";
                              setState(() {
                                _selPartyOpt = all ? null : o;
                                selectedItem = all ? null : o["cust_id"]?.toString();
                              });
                              await _ensureAllBranchPages();
                              _applyFilters();
                            },
                          );
                        },
                      ),
                    ),

                    /// 📍 CITY
                    _section(
                      width: cardW,
                      title: "Use City",
                      icon: Icons.location_city_rounded,
                      value: useCity,
                      onChanged: (v) => _toggle(() => useCity = v),
                      child: PremiumSearchableDropdown<Map<String, dynamic>>(
                        label: "",
                        hint: "All Cities",
                        enabled: useCity,
                        items: _cityOptions(),
                        value: selectedCity == null
                            ? null
                            : {"id": selectedCity, "name": selectedCity},
                        prefixIcon: Icons.location_on_outlined,
                        itemLabel: (o) => (o["name"] ?? "-").toString(),
                        onChanged: (o) async {
                          final bool all = o == null || o["id"] == "__all__";
                          setState(() {
                            selectedCity = all ? null : o["name"]?.toString();
                          });
                          await _ensureAllBranchPages();
                          _applyFilters();
                        },
                      ),
                    ),

                    /// ⚖️ WEIGHT
                    _section(
                      width: cardW,
                      title: "Use Weight",
                      subtitle: "Net weight",
                      icon: Icons.scale_rounded,
                      value: useWeight,
                      onChanged: (v) => _toggle(() => useWeight = v),
                      child: Row(
                        children: [
                          Expanded(
                            child: _numField(
                                "Weight From", weightFromController, useWeight),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child:
                            _numField("Weight To", weightToController, useWeight),
                          ),
                        ],
                      ),
                    ),

                    /// 💰 AMOUNT
                    _section(
                      width: cardW,
                      title: "Use Amount",
                      subtitle: "Pending amount",
                      icon: Icons.currency_rupee_rounded,
                      value: useAmount,
                      onChanged: (v) => _toggle(() => useAmount = v),
                      child: Row(
                        children: [
                          Expanded(
                            child: _numField(
                                "Amount From", amountFromController, useAmount),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child:
                            _numField("Amount To", amountToController, useAmount),
                          ),
                        ],
                      ),
                    ),

                    /// 🔘 ACTIONS — tablet ma bija card jevi box ma
                    Container(
                      width: cardW,
                      padding: oneCol
                          ? EdgeInsets.zero
                          : const EdgeInsets.fromLTRB(10, 10, 10, 10),
                      decoration: oneCol
                          ? null
                          : BoxDecoration(
                        color: const Color(0xffFAFAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: customButton(
                                  title: "Filter",
                                  icon: Icons.filter_alt_rounded,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xff22C55E), Color(0xff16A34A)],
                                  ),
                                  onTap: () async {
                                    await _ensureAllBranchPages();
                                    _applyFilters();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: customButton(
                                  title: "Reset",
                                  icon: Icons.refresh_rounded,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xffF43F5E), Color(0xffE11D48)],
                                  ),
                                  onTap: _resetAll,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
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
                              const SizedBox(width: 8),
                              Expanded(
                                child: customButton(
                                  title: "PDF",
                                  icon: Icons.picture_as_pdf_rounded,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xffEF4444), Color(0xffB91C1C)],
                                  ),
                                  onTap: openPdf,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  /// Ketla filter chalu chhe (header badge mate)
  int get _activeCount => [useDate, useParty, useCity, useWeight, useAmount]
      .where((e) => e)
      .length;

  /// Party options — normal: customers, branch: rows mathi (branch sathe)
  List<Map<String, dynamic>> _partyOptions(ItemProvider provider) {
    final List<Map<String, dynamic>> out = [];
    if (branchMode) {
      final Set<String> seen = {};
      for (final u in allUsers) {
        if (u is! Map) continue;
        final String name = _rowPartyName(u);
        final String id = _rowPartyId(u);
        if (name.isEmpty && id.isEmpty) continue;
        final String company = _text(u["company_id"], "");
        final String key = "$company|${id.isNotEmpty ? id : name}";
        if (!seen.add(key)) continue;
        out.add({
          "id": key,
          "cust_id": id,
          "name": name.isEmpty ? "Party $id" : name,
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
        });
      }
    }
    return [
      {"id": "__all__", "name": "All Parties"},
      ...out,
    ];
  }

  /// City options — data mathi j
  List<Map<String, dynamic>> _cityOptions() {
    final Set<String> cities = {};
    for (final u in allUsers) {
      if (u is! Map) continue;
      final String c = _rowCity(u);
      if (c.isNotEmpty && c != "-") cities.add(c);
    }
    final List<String> sorted = cities.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [
      {"id": "__all__", "name": "All Cities"},
      for (final c in sorted) {"id": c, "name": c},
    ];
  }

  /// Checkbox vala section card
  Widget _section({
    required double width,
    required String title,
    String? subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Widget child,
  }) {
    final Color c = AppColors.primaryDark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: width,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: value ? c.withOpacity(0.045) : const Color(0xffFAFAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value ? c.withOpacity(0.45) : AppColors.border,
          width: value ? 1.2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => onChanged(!value),
            borderRadius: BorderRadius.circular(5),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  _box(value),
                  const SizedBox(width: 8),
                  Icon(icon, size: 15, color: value ? c : Colors.grey.shade500),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: value ? c : Colors.black87,
                      ),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        "($subtitle)",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Opacity(opacity: value ? 1 : 0.55, child: child),
        ],
      ),
    );
  }

  Widget _box(bool value) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: value ? AppColors.primaryDark : Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: value ? AppColors.primaryDark : Colors.grey.shade400,
          width: 1.4,
        ),
      ),
      child: value
          ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
          : null,
    );
  }

  Widget _checkChip({
    required String label,
    required bool value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: value
              ? AppColors.primaryDark.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: value
                ? AppColors.primaryDark.withOpacity(0.35)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _box(value),
            const SizedBox(width: 6),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: value ? AppColors.primaryDark : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDeco(String hint, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 12),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: BorderSide(color: AppColors.border),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: BorderSide(color: AppColors.primaryDark, width: 1.2),
      ),
    );
  }

  Widget _dateField(String hint, TextEditingController c) {
    return InkWell(
      onTap: useDate ? () => _selectDate(c) : null,
      borderRadius: BorderRadius.circular(5),
      child: IgnorePointer(
        child: TextField(
          controller: c,
          maxLines: 1,
          style: const TextStyle(color: Colors.black, fontSize: 13),
          decoration: _fieldDeco(
            hint,
            suffix: Icon(Icons.calendar_today_rounded,
                size: 16, color: AppColors.primaryDark),
          ).copyWith(
            // Nana phone ma icon jagya ochhi le
            suffixIconConstraints:
            const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ),
      ),
    );
  }

  Widget _numField(String hint, TextEditingController c, bool enabled) {
    return TextField(
      controller: c,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => _applyFilters(),
      style: const TextStyle(
        color: Colors.black,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      decoration: _fieldDeco(hint),
    );
  }

  /// ✨ SUMMARY CARDS GRID
  Widget _summaryGrid(bool isMobile) {
    if (summaryTotals == null) return const SizedBox();
    final t = summaryTotals!;
    String f(dynamic v, int d) =>
        (double.tryParse("${v ?? 0}") ?? 0).toStringAsFixed(d);

    final cards = <Widget>[
      _statCard("Vouchers", f(t["voucher_count"], 0),
          Icons.receipt_long_rounded, AppColors.primaryDark),
      _statCard("Gross Wt", f(t["gross_weight"], 3), Icons.scale_rounded,
          const Color(0xff7C3AED)),
      _statCard("Net Wt", f(t["net_weight"], 3), Icons.balance_rounded,
          const Color(0xff2563EB)),
      _statCard("Fine Wt", f(t["fine_weight"], 3), Icons.diamond_outlined,
          const Color(0xffB45309)),
      _statCard("Metal Amt", f(t["metal_amount"], 2),
          Icons.currency_rupee_rounded, const Color(0xff0E7490)),
      _statCard("Labour Amt", f(t["labour_amount"], 2),
          Icons.handyman_outlined, const Color(0xff9333EA)),
      _statCard("Metal Dr", f(t["metal_debit"], 3),
          Icons.trending_down_rounded, const Color(0xffBE123C)),
      _statCard("Total Amount", f(t["total_amount"], 2),
          Icons.account_balance_wallet_rounded, const Color(0xff0F766E)),
      _statCard("Amount In", f(t["amount_in"], 2),
          Icons.south_west_rounded, const Color(0xff16A34A)),
      _statCard("Amount Out", f(t["amount_out"], 2),
          Icons.north_east_rounded, const Color(0xffEA580C)),
      _statCard("Pending", f(t["pending_amount"], 2),
          Icons.hourglass_bottom_rounded, const Color(0xffDC2626)),
    ];

    // ↔️ Horizontal scroll — ek line ma badha card
    final double cardW = isMobile ? 140 : 160;

    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => SizedBox(width: cardW, child: cards[i]),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 0),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: color,
                      fontFeatures: const [FontFeature.tabularFigures()],
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
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 6),

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


            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
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
        child: Icon(icon, color: color, size: 19),
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


  // Future<void> openPdf() async {
  //   try {
  //     final response = await ApiHelper().getPdfRequest(
  //       ApiConstants.OutStanding_amount_report_pdf,
  //     );
  //
  //     if (response != null && response.statusCode == 200) {
  //       final dir = await getTemporaryDirectory();
  //       final file = File("${dir.path}/outstanding_amount.pdf");
  //
  //       /// 🔥 IMPORTANT: ensure List<int>
  //       final bytes = List<int>.from(response.data);
  //
  //       await file.writeAsBytes(bytes);
  //
  //       await OpenFile.open(file.path);
  //     } else {
  //       print("PDF Download Failed: ${response?.statusCode}");
  //     }
  //   } catch (e) {
  //     print("Error: $e");
  //   }
  // }

  // ============================================================
  // 📄 PDF / EXCEL — branch wise (kale na screen jevu j)
  //
  // Normal : OutStanding_amount_report_pdf / _excel ?filters
  // Branch : company/branch-reports/outstanding-amount
  //            ?report_branches=a,b&export=pdf|excel&filters
  // ============================================================

  String? _exporting; // "pdf" / "excel" chalu hoy tyare bijo tap nahi

  Future<void> openPdf() => _export("pdf");

  Future<void> openexel(String Code) => _export("excel");

  /// Filter pramane query (normal + branch banne ma same)
  String _filterQuery() {
    final bool isDefaultReport = useDefault || !_anyFilter;
    String enc(String v) => Uri.encodeQueryComponent(v);

    return [
      "use_default_report=${isDefaultReport ? 1 : 0}",
      "use_date=${useDate ? 1 : 0}",
      "from_date=${useDate ? apiDate(fromDateController.text) : ""}",
      "to_date=${useDate ? apiDate(toDateController.text) : ""}",
      "use_party=${useParty ? 1 : 0}",
      "customer_id=${useParty ? enc(selectedItem ?? "") : ""}",
      "use_city=${useCity ? 1 : 0}",
      "city=${useCity ? enc(selectedCity ?? "") : ""}",
      "use_mode=0",
      "payment_mode=",
      "use_weight=${useWeight ? 1 : 0}",
      "weight_from=${useWeight ? enc(weightFromController.text.trim()) : ""}",
      "weight_to=${useWeight ? enc(weightToController.text.trim()) : ""}",
      "use_amount=${useAmount ? 1 : 0}",
      "amount_from=${useAmount ? enc(amountFromController.text.trim()) : ""}",
      "amount_to=${useAmount ? enc(amountToController.text.trim()) : ""}",
    ].join("&");
  }

  String _exportUrl(String type) {
    if (branchMode) {
      // Comma encode na thay (%2C) etle hathe
      final String branches =
      _appliedBranchSlugs.map(Uri.encodeQueryComponent).join(",");
      return "$branchOutstandingAmountUrl"
          "?report_branches=$branches"
          "&export=$type"
          "&${_filterQuery()}";
    }
    final String base = type == "pdf"
        ? ApiConstants.OutStanding_amount_report_pdf
        : ApiConstants.OutStanding_amount_report_excel;
    return "$base${base.contains('?') ? '&' : '?'}${_filterQuery()}";
  }

  Future<void> _export(String type) async {
    if (_exporting != null) return;
    _exporting = type;

    final String label = type == "pdf" ? "PDF" : "Excel";

    try {
      final String url = _exportUrl(type);
      debugPrint("📤 OUTSTANDING $label URL => $url");

      final response = await ApiHelper().getPdfRequest(
        url,
        receiveTimeout: const Duration(minutes: 2),
      );

      if (!mounted) return;

      if (response == null || response.statusCode != 200) {
        AppMessage.error(
          context,
          _exportError(response?.data) ?? "Failed to download $label",
        );
        return;
      }

      final dynamic raw = response.data;
      final Uint8List? bytes = raw is Uint8List
          ? raw
          : (raw is List<int> ? Uint8List.fromList(raw) : null);

      // Bytes ni jagya e JSON error aave to
      if (bytes == null || bytes.isEmpty || bytes.first == 0x7B /* { */) {
        AppMessage.error(
          context,
          _exportError(raw) ?? "No file received from server",
        );
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      final String stamp =
          "${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}";
      final String ext = type == "pdf" ? "pdf" : "xlsx";
      final file = File(
        "${dir.path}/Outstanding_Amount${branchMode ? "_Branches" : ""}_$stamp.$ext",
      );
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      AppMessage.success(context, "$label downloaded");
      await OpenFile.open(file.path);
    } catch (e) {
      debugPrint("❌ OUTSTANDING $label ERROR => $e");
      if (mounted) AppMessage.error(context, "Download failed");
    } finally {
      _exporting = null;
    }
  }

  /// JSON (bytes / map / string) mathi message
  String? _exportError(dynamic data) {
    try {
      dynamic d = data;
      if (d is List<int>) d = utf8.decode(d);
      if (d is String) d = jsonDecode(d);
      if (d is Map && d["message"] != null) return d["message"].toString();
    } catch (_) {}
    return null;
  }

  String apiDate(String value) {
    if (value.isEmpty) return "";
    try {
      final parts = value.split("-");
      return "${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}";
    } catch (_) {
      return "";
    }
  }

  Widget buildSummaryRow() {

    if (summaryTotals == null) {
      return const SizedBox(); // or loader
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: Colors.grey),
          bottom: BorderSide(color: Colors.grey),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [

            _summaryBox("Voucher", summaryTotals!["voucher_count"].toString()),

            _summaryBox(
              "Gross",
              double.parse(
                summaryTotals!["gross_weight"].toString(),
              ).toStringAsFixed(2),
            ),

            _summaryBox("Net",
                summaryTotals!["net_weight"].toString()),

            _summaryBox("Amount IN",
                summaryTotals!["amount_in"].toString()),

            _summaryBox("Amount Out",
                summaryTotals!["amount_out"].toString()),

            _summaryBox("Pending Amt",double.parse(
              summaryTotals!["pending_amount"].toString(),
            ).toStringAsFixed(2),
            ),

            _summaryBox("Total",
                summaryTotals!["total_amount"].toString()),

          ],
        ),
      ),
    );
  }



  Widget _summaryBox(String title, String value) {
    return Container(
      width: 90,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(title,
              style: const TextStyle(fontSize: 11, color: Colors.black54)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> calculateTotals(List data) {
    double voucherCount = 0;
    double gross = 0, net = 0, fine = 0;
    double metalAmt = 0, labourAmt = 0, metalDr = 0;
    double totalAmount = 0, amountIn = 0, amountOut = 0, pending = 0;

    for (var item in data) {
      if (item is! Map) continue;
      voucherCount += 1;

      // ✅ _num — "15,774.67" jeva comma vala aankda pan gane
      gross += _num(item["gross_weight"]);
      net += _num(item["net_weight"]);
      fine += _num(item["fine_weight"]);
      metalAmt += _num(item["metal_amount"]);
      labourAmt += _num(item["labour_amount"]);
      metalDr += _num(item["metal_debit"]);
      totalAmount += _num(item["total_amount"]);
      amountIn += _num(item["amount_in"]);
      amountOut += _num(item["amount_out"]);
      pending += _num(item["pending"] ?? item["pending_amount"]);
    }

    return {
      "voucher_count": voucherCount,
      "gross_weight": gross,
      "net_weight": net,
      "fine_weight": fine,
      "metal_amount": metalAmt,
      "labour_amount": labourAmt,
      "metal_debit": metalDr,
      "total_amount": totalAmount,
      "amount_in": amountIn,
      "amount_out": amountOut,
      "pending_amount": pending,
    };
  }


}
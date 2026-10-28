import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pecifician_sysytem/Approval/CreateApprovalReturn.dart';
import 'package:pecifician_sysytem/Extra/AppColors.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import '../Dashboard/HomeScreen.dart';
import '../Extra/AppMessage.dart';
import '../Extra/ItemProvider.dart';
import '../Extra/PermissionDeniedWidget.dart';
import '../Extra/PremiumSearchableDropdown.dart';
import 'package:intl/intl.dart';

import 'package:pecifician_sysytem/Settings/BranchManagementScreen.dart'
    show BranchApi, Company, BranchTypeX;
import 'package:pecifician_sysytem/Reports/BranchAccess.dart';

class Approvalreturnscreen extends StatefulWidget {
  const Approvalreturnscreen({super.key});

  @override
  State<Approvalreturnscreen> createState() => _ApprovalreturnscreenState();
}

class _ApprovalreturnscreenState extends State<Approvalreturnscreen> {
  TextEditingController searchController = TextEditingController();
  TextEditingController fromDateController = TextEditingController();
  TextEditingController toDateController = TextEditingController();
  List userlist = [];
  String? selectedItem;
  List<Map<String, dynamic>> tableRows = [];
  Timer? _huidTimer;
  int apiRowCount = 0;
  List customerlist = [];
  String? selectedUser;
  String? selectedCompanyId;
  String? selectedUserId;
  DateTime? birthDate;
  DateTime? anniversaryDate;
  List<Map<String, dynamic>> allItems = [];
  List<Map<String, dynamic>> items = [];
  String? selectedCustomerName;
  bool dateFilterApplied = false;
  List cartItems = [];
  Future<void> _selectDate(TextEditingController controller) async {
    DateTime initial = DateTime.now();

    if (controller.text.isNotEmpty) {
      try {
        initial = _convertToDate(controller.text);
      } catch (_) {}
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        controller.text = _formatUiDate(picked);
      });
    }
  }

  List allUsers = []; // 🔥 original data store
  String _norm(dynamic v) =>
      (v ?? "").toString().trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  void applyDateFilter() {
    List filtered = List.from(allUsers);

    // ============================================================
    // DATE FILTER - "Show" dabaya pachi j apply thay
    // ============================================================
    if (dateFilterApplied &&
        fromDateController.text.isNotEmpty &&
        toDateController.text.isNotEmpty) {
      final DateTime fromDate = _convertToDate(fromDateController.text);
      final DateTime toDate = _convertToDate(toDateController.text);

      final DateTime startDate = DateTime(
        fromDate.year,
        fromDate.month,
        fromDate.day,
      );
      final DateTime endDate = DateTime(
        toDate.year,
        toDate.month,
        toDate.day,
        23,
        59,
        59,
      );

      filtered = filtered.where((user) {
        final raw = user["return_date"];
        if (raw == null) return false;

        final DateTime? userDate = DateTime.tryParse(raw.toString());
        if (userDate == null) return false;

        return !userDate.isBefore(startDate) && !userDate.isAfter(endDate);
      }).toList();
    }

    // ============================================================
    // CUSTOMER FILTER
    // ============================================================
    if (selectedCustomerName != null &&
        selectedCustomerName!.trim().isNotEmpty) {
      final String query = _norm(selectedCustomerName);

      debugPrint("FILTER QUERY => '$query'");
      if (allUsers.isNotEmpty) {
        debugPrint("SAMPLE ROW => ${allUsers.first}");
      }

      filtered = filtered.where((user) {
        final dynamic c = user["customer"];

        // 1) id thi match (jo API ma customer_id aave to)
        final String apiCustomerId =
            (user["customer_id"] ?? (c is Map ? c["id"] : null))?.toString() ??
                "";

        if (apiCustomerId.isNotEmpty && selectedUserId != null) {
          return apiCustomerId == selectedUserId;
        }

        // 2) id na hoy to name thi match (safe compare)
        final String name = _norm(
          user["customer_name"] ?? (c is Map ? c["name"] : null),
        );

        if (name.isEmpty) return false;

        return name == query || name.contains(query) || query.contains(name);
      }).toList();
    }

    debugPrint("FILTERED COUNT => ${filtered.length}");

    setState(() {
      userlist = filtered;
    });
  }

  DateTime _convertToDate(String input) {
    try {
      return DateFormat("d-M-yyyy").parse(input.trim());
    } catch (_) {
      return DateTime.now();
    }
  }

  // ============================================================
  // 🔥 BRANCH REPORTS (Sale Summary jevu j)
  // ============================================================

  /// Branch API mathi aavti companies (main + branches)
  List<Company> branchCompanies = [];

  /// Dropdown ma select kareli (haju apply nathi thai)
  Set<int> selectedCompanyIds = {};

  /// "View" dabavya pachhi apply thayeli
  List<int> appliedCompanyIds = [];

  /// Branch report chalu chhe?
  bool get _branchMode => appliedCompanyIds.isNotEmpty;

  bool branchesLoading = false;
  bool canViewBranches = false;
  bool branchExpanded = true;
  bool branchReportLoading = false;

  /// management_branches[]=1&management_branches[]=2
  String get _branchQuery => appliedCompanyIds
      .map((id) => "management_branches[]=$id")
      .join("&");

  /// return_list?management_branches[]=1&management_branches[]=2 (branch mode only)
  String _br(String url) => _branchMode
      ? "$url${url.contains('?') ? '&' : '?'}$_branchQuery"
      : url;

  /// approval return → branch name (company_id / branch / company_name)
  String _branchOf(Map user) {
    final int? id = int.tryParse("${user["company_id"] ?? ""}");
    if (id != null) {
      for (final c in branchCompanies) {
        if (c.id == id) return c.name;
      }
    }
    final dynamic b = user["branch"] ?? user["branch_name"] ?? user["company"];
    if (b is Map && b["name"] != null) return b["name"].toString();
    final String t = (b ?? user["company_name"] ?? "").toString().trim();
    return t.isEmpty || t == "null" ? "" : t;
  }

  /// Main company nu id (branch list mathi)
  int? get _mainCompanyId {
    for (final c in branchCompanies) {
      if (c.isMain) return c.id;
    }
    return null;
  }

  /// ✅ Aa approval return main company no chhe? (fakt eno j edit / delete)
  /// Branch list j na hoy (branch user) to potano j data → true
  bool _isMainData(Map user) {
    final int? mainId = _mainCompanyId;
    if (mainId == null) return true;

    final int? id = int.tryParse("${user["company_id"] ?? ""}");
    if (id != null) return id == mainId;

    // company_id na aave to branch na naam thi
    final String br = _branchOf(user).trim().toLowerCase();
    if (br.isEmpty) return true;
    for (final c in branchCompanies) {
      if (c.name.trim().toLowerCase() == br) return c.isMain;
    }
    return true;
  }

  List<String> userPermissions = []; // 🔥 ADD

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
    // print("🔥 Checking '$permissionName' in $userPermissions => ${userPermissions.contains(permissionName)}");
    return userPermissions.contains(permissionName);
  }

  @override
  void initState() {
    super.initState();
    loadPermissions();

    // 🔥 DEFAULT: chhella 1 week (aaj sahit 7 divas)
    final DateTime today = DateTime.now();
    final DateTime weekAgo = today.subtract(const Duration(days: 6));

    fromDateController.text = _formatUiDate(weekAgo);
    toDateController.text = _formatUiDate(today);

    // 🔥 Screen khulta j date filter lagu thay
    dateFilterApplied = true;

    Future.microtask(() {
      Provider.of<ItemProvider>(context, listen: false).loadreturnCustomers();
    });

    getSaleDetails(); // API pachhi applyDateFilter() automatic call thay chhe
    _loadBranches();
  }

  Future<void> category() async {
    final response = await ApiHelper().getRequest(ApiConstants.customerlist);

    print("user API URL: ${ApiConstants.customerlist}");
    print("users Raw Response: ${response.toString()}");

    if (!mounted) return;

    if (response != null && response.statusCode == 200) {
      final data = response.data;

      setState(() {
        customerlist = data['data'] ?? [];
      });
    } else {
      setState(() {
        customerlist = [];
      });
    }
  }

  Future<void> getSaleDetails() async {
    // 🔥 Branch mode → ?management_branches[]=1&management_branches[]=2
    final String url = _br(ApiConstants.return_list);
    debugPrint("📋 APPROVAL RETURN URL => $url");

    final response = await ApiHelper().getRequest(url);

    if (!mounted) return;

    if (response != null && response.statusCode == 200) {
      final data = response.data;

      final List categories = data["data"] ?? [];

      setState(() {
        tableRows.clear();

        allUsers = List.from(categories);
        allItems = List.from(categories);

        userlist = List.from(categories);
      });

      print("API TOTAL => ${categories.length}");
      print("ALL USERS => ${allUsers.length}");

      /// Existing selected date hoy to filter
      applyDateFilter();
    } else {
      setState(() {
        allUsers = [];
        allItems = [];
        userlist = [];
      });
      print("API Failed");
      AppMessage.error(context, "Failed to load data");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!(hasPermission("approval-return-view") ||
        hasPermission("approval-return-manage"))) {
      return Scaffold(
        body: PermissionDeniedWidget(
          onBack: () {
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

        Navigator.pop(context, true);
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false, // ⭐ IMPORTANT FIX
        backgroundColor: AppColors.white,
        body: Stack(
          children: [
            /// ✅ Main Content
            Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top + 40),

                // 🔥 Branch Reports tab sauthi upar
                _buildBranchCard(),

                /// 🔥 FILTER SECTION (NEW)
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

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(left: 10, right: 10, top: 0),
                    itemCount: userlist.length,
                    itemBuilder: (context, index) {
                      final item = userlist[index];
                      return buildCard(item, index);
                    },
                  ),
                ),

                /// 🔥 Dynamic Bottom Section
                // Expanded(
                //   child: _buildRecentScansList(height),
                // ),
                if (hasPermission("approval-return-create"))
                /// Bottom Button
                  InkWell(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const Createapprovalreturn(),
                        ),
                      );

                      // ✅ Create pachhi list refresh
                      if (!mounted) return;
                      if (result == true) await getSaleDetails();
                    },
                    borderRadius: BorderRadius.circular(5),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryDark.withOpacity(0.7),
                              AppColors.secondaryDark.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Center(
                          child: Text(
                            "+ Create Approval Return",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
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
                      "Approval Return List",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                          Navigator.pop(context, true);
                        },
                        child: Container(
                          padding: EdgeInsets.all(isMobile ? 6 : 8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark,
                            borderRadius: BorderRadius.circular(5),
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

                    /// ✅ RIGHT — EXCEL + PDF
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _exportBtn(
                            icon: Icons.table_chart_rounded,
                            color: const Color(0xff16A34A),
                            tooltip: "Excel",
                            busy: _exporting == "excel",
                            onTap: () => _export("excel"),
                            isMobile: isMobile,
                          ),
                          const SizedBox(width: 8),
                          _exportBtn(
                            icon: Icons.picture_as_pdf_rounded,
                            color: const Color(0xffDC2626),
                            tooltip: "PDF",
                            busy: _exporting == "pdf",
                            onTap: () => _export("pdf"),
                            isMobile: isMobile,
                          ),
                        ],
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
            ),
          ],
        ),

        //bottomNavigationBar: _buildSaveButton(),
      ),
    );
  }

  /// 📄 Card nu PDF
  /// Branch mode: return_pdf/378?management_branches[]=21 (fakt e card ni branch)
  /// Normal: pehla jevu j (getRequestWithId)
  Future<void> openPdf(int id, {Map? row}) async {
    await _openCardFile(
      id: id,
      row: row,
      endpoint: ApiConstants.return_pdf,
      fileName: "return_$id.pdf",
      label: "PDF",
    );
  }

  /// Card (row) ni branch nu id — company_id, nahi to branch na naam thi
  int? _rowBranchId(Map? row) {
    if (row == null) return null;

    final int? id = int.tryParse("${row["company_id"] ?? ""}");
    if (id != null) return id;

    final dynamic b = row["branch"] ?? row["company"];
    if (b is Map) {
      final int? bid = int.tryParse("${b["id"] ?? ""}");
      if (bid != null) return bid;
    }

    final String name = _branchOf(row).trim().toLowerCase();
    if (name.isEmpty) return null;
    for (final c in branchCompanies) {
      if (c.name.trim().toLowerCase() == name) return c.id;
    }
    return null;
  }

  Future<void> _openCardFile({
    required int id,
    Map? row,
    required String endpoint,
    required String fileName,
    required String label,
  }) async {
    try {
      dynamic response;

      if (_branchMode) {
        // 🔥 Fakt aa card ni j branch → ?management_branches[]=21
        final String base = endpoint.endsWith("/")
            ? "$endpoint$id"
            : "$endpoint/$id";
        final int? branchId = _rowBranchId(row);
        // Card ni branch na male to j select kareli badhi branches
        final String url = branchId != null
            ? "$base${base.contains('?') ? '&' : '?'}management_branches[]=$branchId"
            : _br(base);
        debugPrint("📄 CARD $label URL => $url");

        response = await ApiHelper().getPdfRequest(
          url,
          receiveTimeout: const Duration(minutes: 2),
        );
      } else {
        // ✅ Pehla jevu j — koi badlav nahi
        response = await ApiHelper().getRequestWithId(
          endpoint,
          id,
          responseType: ResponseType.bytes,
        );
      }

      if (!mounted) return;

      if (response == null || response.statusCode != 200) {
        AppMessage.error(
          context,
          _exportError(response?.data) ?? "$label Download Failed",
        );
        return;
      }

      final dynamic raw = response.data;
      final Uint8List? bytes = raw is Uint8List
          ? raw
          : (raw is List<int> ? Uint8List.fromList(raw) : null);

      // JSON error aave to khoti file save na thay
      if (bytes == null || bytes.isEmpty || bytes.first == 0x7B /* { */) {
        AppMessage.error(context, _exportError(raw) ?? "$label not available");
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/$fileName");
      await file.writeAsBytes(bytes, flush: true);

      OpenFile.open(file.path);
    } catch (e) {
      debugPrint("❌ CARD $label ERROR => $e");
      if (mounted) AppMessage.error(context, "$label Download Failed");
    }
  }

  /// Header Cell
  Widget _buildHeaderCell(String title) {
    return Expanded(
      child: Container(
        height: 55,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xff2B3050), // dark brown
              Color(0xff1b1411),
              Color(0xff3A3F63), // deep dark
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border(
            right: BorderSide(
              color: Color(0xffC9A44A).withOpacity(0.6), // gold divider
              width: 1.2,
            ),
            left: BorderSide(
              color: Color(0xffC9A44A).withOpacity(0.6), // gold divider
              width: 1.2,
            ),
            top: BorderSide(
              color: Color(0xffC9A44A).withOpacity(0.6), // gold divider
              width: 1.2,
            ),
            bottom: BorderSide(
              color: Color(0xffC9A44A).withOpacity(0.6), // gold bottom line
              width: 1.5,
            ),
          ),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xffE6C36A), // gold text
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  void calculateNetWeight(int index) {
    double gross = double.tryParse(tableRows[index]["gross"]!.text) ?? 0;

    double other = double.tryParse(tableRows[index]["other"]!.text) ?? 0;

    double net = gross - other;

    tableRows[index]["net"]!.text = net.toStringAsFixed(3);
  }

  Future<void> loadItemDetails(String itemId) async {
    final response = await ApiHelper().postRequest(
      ApiConstants.label_item_list,
      {"item_id": itemId},
    );

    if (!mounted) return;

    if (response != null &&
        response.statusCode == 200 &&
        response.data["data"] != null) {
      final List data = response.data["data"];

      setState(() {
        tableRows.clear();

        for (var row in data) {
          tableRows.add({
            "gross": TextEditingController(text: row["gross_weight"] ?? ""),
            "other": TextEditingController(text: row["other"] ?? ""),
            "net": TextEditingController(text: row["net_weight"] ?? ""),
            "labourRate": TextEditingController(
              text: row["sale_labour_rate"]?.toString() ?? "",
            ),
            "labourAmount": TextEditingController(
              text: row["sale_labour_amount"]?.toString() ?? "",
            ),
            "purity": TextEditingController(
              text: row["outward_purity"]?.toString() ?? "",
            ),
            "size": TextEditingController(text: row["size"] ?? ""),
            "huid": TextEditingController(text: row["HUID"] ?? ""),
          });
        }
        apiRowCount = data.length; // ⭐ important
        /// 🔥 Extra 3 Empty Rows
        for (int i = 0; i < 3; i++) {
          tableRows.add({
            "gross": TextEditingController(),
            "other": TextEditingController(),
            "net": TextEditingController(),
            "labourRate": TextEditingController(),
            "labourAmount": TextEditingController(),
            "purity": TextEditingController(),
            "size": TextEditingController(),
            "huid": TextEditingController(),
          });
        }
      });
    }
  }

  Future<List<Map<String, String>>?> openApprovePopup(
      BuildContext context,
      ) async {
    List<Map<String, String>> tableRows = [];
    TextEditingController labelController = TextEditingController();
    String? popupSelectedUser; // 👈 add this
    bool showScanner = false;
    bool showLabelField = false;

    return showDialog<List<Map<String, String>>>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 40,
              ),
              backgroundColor: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    width: double.infinity,
                    height: showScanner || showLabelField ? 700 : 500,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),

                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        /// Title
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Sale Estimate",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            Row(
                              children: [
                                /// Edit Icon
                                IconButton(
                                  onPressed: () {
                                    print("Edit Clicked");
                                    setState(() {
                                      showLabelField = true;
                                      showScanner = false;
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                  ),
                                ),

                                /// Scan Icon
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      showScanner = true;
                                      showLabelField = false;
                                    });
                                    print("Scan Clicked");
                                  },
                                  icon: const Icon(
                                    Icons.qr_code_scanner,
                                    color: Colors.white,
                                  ),
                                ),

                                /// Close Icon
                                IconButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Select Party",
                              style: TextStyle(color: Colors.white70),
                            ),

                            const SizedBox(height: 8),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white24),
                                color: Colors.white.withOpacity(0.05),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  dropdownColor: Colors.black,
                                  hint: const Text(
                                    "Select Customer",
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  value: popupSelectedUser,
                                  items: customerlist
                                      .map<DropdownMenuItem<String>>((user) {
                                    return DropdownMenuItem<String>(
                                      value: user["id"].toString(),
                                      child: Text(
                                        user["name"] ?? "",
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    );
                                  })
                                      .toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      popupSelectedUser = val;
                                      showScanner = false;
                                      showLabelField = false;
                                      final selectedData = customerlist
                                          .firstWhere(
                                            (user) =>
                                        user["id"].toString() == val,
                                      );
                                      selectedCompanyId =
                                          selectedData["company_id"].toString();

                                      print(
                                        "Selected Company ID: $selectedCompanyId",
                                      );
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),

                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            /// Title

                            /// Customer Dropdown
                            if (popupSelectedUser != null) ...[
                              const SizedBox(height: 15),

                              /// Label TextField
                              if (showLabelField) ...[
                                TextField(
                                  controller: labelController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: "Enter Label",
                                    labelStyle: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                    //filled: true,
                                    //fillColor: Colors.white.withOpacity(0.05),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),

                                  onSubmitted: (value) {
                                    if (value.trim().isEmpty) return;

                                    setState(() {
                                      tableRows.add({
                                        //"label": value.trim(),
                                        "gross": "10.0",
                                        "other": "2.5",
                                        "net": "7.5",
                                        "size": "10",
                                        "huid": "001",
                                      });
                                    });

                                    labelController.clear();
                                  },
                                ),
                              ],

                              const SizedBox(height: 20),

                              /// Scanner
                              if (showScanner) ...[
                                //_buildScannerSection(),
                              ],

                              const SizedBox(height: 20),

                              /// Table
                              /// Table/Grid
                              SizedBox(
                                height: 220,
                                child: Column(
                                  children: [
                                    /// Header
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.white24,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          _buildHeaderCell("Gross\nWeight"),
                                          _buildHeaderCell("Other"),
                                          _buildHeaderCell("Net\nWeight"),
                                          _buildHeaderCell("Size"),
                                          _buildHeaderCell("HUID"),
                                        ],
                                      ),
                                    ),

                                    /// Rows
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: Table(
                                          border: TableBorder.all(
                                            color: Colors.white24,
                                          ),
                                          children: tableRows.asMap().entries.map((
                                              entry,
                                              ) {
                                            int index = entry.key;
                                            var row = entry.value;

                                            return TableRow(
                                              children: [
                                                _buildTableCell1(
                                                  row["gross"]!,
                                                      (val) {
                                                    row["gross"] = val;
                                                  },
                                                ),
                                                _buildTableCell1(
                                                  row["other"]!,
                                                      (val) {
                                                    row["other"] = val;
                                                  },
                                                ),
                                                _buildTableCell1(row["net"]!, (
                                                    val,
                                                    ) {
                                                  row["net"] = val;
                                                }),
                                                // _buildTableCell1(row["labourRate"]!, (val){ row["labourRate"] = val; }),
                                                // _buildTableCell1(row["labourAmount"]!, (val){ row["labourAmount"] = val; }),
                                                _buildTableCell1(row["size"]!, (
                                                    val,
                                                    ) {
                                                  row["size"] = val;
                                                }),
                                                _buildTableCell1(row["huid"]!, (
                                                    val,
                                                    ) {
                                                  row["huid"] = val;
                                                }),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 15),

                              /// Submit Button
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF00C853),
                                      Color(0xFF64DD17),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.pop(
                                      context,
                                      tableRows,
                                    ); // 🔥 return data
                                    print(tableRows);
                                  },
                                  child: const Text(
                                    "Submit",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTableCell1(String value, Function(String) onChanged) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(0),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.10),
            Colors.white.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          right: BorderSide(
            color: Color(0xffC9A44A).withOpacity(0.6), // gold divider
            width: 0.8,
          ),
          left: BorderSide(
            color: Color(0xffC9A44A).withOpacity(0.6), // gold divider
            width: 0.8,
          ),
          bottom: BorderSide(
            color: Color(0xffC9A44A).withOpacity(0.6), // gold bottom line
            width: 0.8,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(0),
        child: TextFormField(
          initialValue: value,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 0),
            border: InputBorder.none,
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget filterWidget() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 12, 10, 0),
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
          Container(
            padding: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Consumer<ItemProvider>(
              builder: (context, provider, child) {
                final List<Map<String, dynamic>> customers = provider.customers
                    .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
                    .toList();

                /// CURRENT SELECTED CUSTOMER
                Map<String, dynamic>? selectedCustomer;

                if (selectedItem != null) {
                  try {
                    selectedCustomer = customers.firstWhere(
                          (customer) =>
                      customer["id"]?.toString() == selectedItem.toString(),
                    );
                  } catch (_) {
                    selectedCustomer = null;
                  }
                }

                return Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    PremiumSearchableDropdown<Map<String, dynamic>>(
                      label: "",
                      hint: "Select Customer",
                      items: customers,
                      value: selectedCustomer,
                      prefixIcon: Icons.person_outline,

                      itemLabel: (customer) => customer["name"]?.toString() ?? "-",

                      /// SEARCH — Name / Mobile / Email / ID
                      searchText: (customer) {
                        return [
                          customer["name"]?.toString() ?? "",
                          customer["mobile_no"]?.toString() ?? "",
                          customer["mobile"]?.toString() ?? "",
                          customer["email"]?.toString() ?? "",
                          customer["id"]?.toString() ?? "",
                        ].join(" ");
                      },

                      onChanged: (selectedData) => _setCustomerFilter(selectedData),
                    ),

                    /// ❌ CLEAR — dropdown ની અંદર, arrow ની ડાબી બાજુ
                    if (selectedCustomer != null)
                      Positioned(
                        right: 40, // 🔥 arrow થી અંતર — જરૂર મુજબ 32–48 કરો
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              _setCustomerFilter(null);
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
                              child: Icon(
                                Icons.close_rounded,
                                size: 13,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
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
                        suffixIcon: const Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: AppColors.primaryDark,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.border),
                        ),

                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.border),
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
                        suffixIcon: const Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: AppColors.primaryDark,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.border),
                        ),

                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.border),
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

          const SizedBox(height: 8),

          /// 🔥 BUTTONS
          Row(
            children: [
              /// SHOW
              Expanded(
                child: InkWell(
                  onTap: () {
                    if (fromDateController.text.trim().isEmpty ||
                        toDateController.text.trim().isEmpty) {
                      AppMessage.error(context, "Please select From and To date");
                      return;
                    }

                    final from = _convertToDate(fromDateController.text);
                    final to = _convertToDate(toDateController.text);

                    if (from.isAfter(to)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("From Date, To Date karta moti na hovi joie"),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    setState(() {
                      dateFilterApplied = true;
                    });

                    applyDateFilter();
                  },
                  borderRadius: BorderRadius.circular(5),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryDark.withOpacity(0.7),
                          AppColors.secondaryDark.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Center(
                      child: Text(
                        "Show",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: pdfBtn1(() {
                  if (selectedItem == null || selectedItem.toString().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Please Select Customer First"),
                        backgroundColor: Colors.red,
                      ),
                    );

                    return;
                  }

                  openApprovalPdf(
                    fromDateController.text,
                    toDateController.text,
                  );

                  print("PDF Click");
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget buildCard(Map<String, dynamic> item, int index) {
  //   return Container(
  //     margin: const EdgeInsets.symmetric(vertical: 6),
  //     padding: const EdgeInsets.all(12),
  //     decoration: BoxDecoration(
  //       color: AppColors.cardBackground,
  //       borderRadius: BorderRadius.circular(10),
  //       border: Border.all(color: AppColors.border),
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //
  //         /// 🔝 TOP ROW
  //         Row(
  //           children: [
  //             statusChip(item["metal"].toString()),
  //             const Spacer(),
  //             /// ⚙️ ACTIONS
  //             Row(
  //               mainAxisAlignment: MainAxisAlignment.end,
  //               children: [
  //
  //                 if (hasPermission("approval-return-edit") || hasPermission("approval-return-manage"))
  //                 premiumIconBtn(Icons.visibility, Colors.blue, onTap: () {
  //                   getApprovalDetails(item["id"]); // 🔥 id pass karo
  //                   print("View Item");
  //                 }),
  //
  //
  //                 const SizedBox(width: 8),
  //
  //                 pdfBtn(() {
  //                   //openPdf(item["id"]);
  //                   int id = int.tryParse(item["id"]?.toString() ?? "0") ?? 0;
  //
  //
  //                   openPdf(id);
  //
  //                 }),
  //
  //                 const SizedBox(width: 8),
  //
  //                 // premiumIconBtn(Icons.delete, Colors.red, onTap: () {
  //                 //   setState(() {
  //                 //     items.removeAt(index);
  //                 //   });
  //                 // }),
  //               ],
  //             ),
  //           ],
  //         ),
  //
  //         const SizedBox(height: 8),
  //
  //         /// 🧾 TITLE
  //         Row(
  //           children: [
  //             Text(
  //               item["voucher_no"] ?? "",
  //               style: const TextStyle(
  //                 fontSize: 15,
  //                 color: Colors.black, // ✅ FIX
  //                 fontWeight: FontWeight.w600,
  //               ),
  //             ),
  //             const Spacer(),
  //             Text(
  //               item["customer_name"]?.toString() ?? "",
  //               style: const TextStyle(
  //                 fontSize: 15,
  //                 color: Colors.black, // ✅ FIX
  //                 fontWeight: FontWeight.w600,
  //               ),
  //             ),
  //           ],
  //         ),
  //
  //         const SizedBox(height: 10),
  //         /// 🔥 ERP GRID (MAIN FIX)
  //         Container(
  //           padding: const EdgeInsets.symmetric(vertical: 6),
  //           decoration: BoxDecoration(
  //             color:AppColors.background,
  //             border: Border.all(color: AppColors.border,width: 1.5),
  //             borderRadius: BorderRadius.circular(6),
  //           ),
  //           child: Column(
  //             children: [
  //
  //               /// Row 1
  //               _erpRow("Date", formatDate(item["return_date"].toString()),
  //                   "R_total", item["return_total"]?.toString() ?? "-"),
  //
  //               Divider(height: 1, color: AppColors.border),
  //
  //               /// Row 2
  //               _erpRow(
  //                 "Type",
  //                 item["source_type"]?.toString() ?? "-",
  //                 "",
  //                 "",
  //               ),
  //             ],
  //           ),
  //         ),
  //
  //         const SizedBox(height: 10),
  //
  //         /// Divider
  //         //  Divider(color: Colors.grey.shade300, height: 1),
  //
  //
  //
  //       ],
  //     ),
  //   );
  //
  //
  // }
  int? expandedApprovalReturnId;
  Widget buildCard(Map<String, dynamic> item, int index) {
    final size = MediaQuery.of(context).size;
    final bool isTablet = size.width >= 600;

    // =========================================================
    // UNIQUE ID
    // =========================================================
    final int id = int.tryParse(item["id"]?.toString() ?? "0") ?? 0;

    final bool isExpanded = expandedApprovalReturnId == id;

    // =========================================================
    // DATA
    // =========================================================
    final String voucherNo = item["voucher_no"]?.toString() ?? "-";

    final String customerName = item["customer_name"]?.toString() ?? "-";

    final String metal = item["metal"]?.toString() ?? "-";

    final String returnDate = item["return_date"]?.toString() ?? "";

    final String returnTotal = item["return_total"]?.toString() ?? "-";

    final String sourceType = item["source_type"]?.toString() ?? "-";

    /// 🔐 Main company sivay ni branch no data → delete nahi
    final bool canModify = _isMainData(item);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),

      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(5),

        border: Border.all(
          color: isExpanded
              ? AppColors.primaryDark.withOpacity(0.45)
              : AppColors.border,
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),

      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),

        child: Column(
          children: [
            // =====================================================
            // HEADER - ALWAYS VISIBLE
            // =====================================================
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 14 : 10,
                vertical: isTablet ? 12 : 10,
              ),

              child: Row(
                children: [
                  // =================================================
                  // INDEX
                  // =================================================
                  Container(
                    width: 27,
                    height: 27,
                    alignment: Alignment.center,

                    decoration: BoxDecoration(
                      color: AppColors.gradientBlue,
                      borderRadius: BorderRadius.circular(5),
                    ),

                    child: Text(
                      "${index + 1}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // =================================================
                  // VOUCHER NO + CUSTOMER
                  // =================================================
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // VOUCHER NO
                        Text(
                          voucherNo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 3),

                        // CUSTOMER NAME
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: 13,
                              color: Colors.grey.shade600,
                            ),

                            const SizedBox(width: 4),

                            Expanded(
                              child: Text(
                                customerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),

                        /// 🏢 BRANCH (branch mode)
                        if (_branchMode && _branchOf(item).isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryDark.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: AppColors.primaryDark.withOpacity(0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.store_mall_directory_rounded,
                                    size: 11, color: AppColors.primaryDark),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    _branchOf(item),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: AppColors.primaryDark,
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

                  const SizedBox(width: 5),

                  // =================================================
                  // METAL STATUS
                  // =================================================
                  statusChip(metal),

                  SizedBox(width: isTablet ? 8 : 5),

                  // =================================================
                  // VIEW
                  // =================================================
                  if (hasPermission("approval-return-edit") ||
                      hasPermission("approval-return-manage")) ...[
                    premiumIconBtn(
                      Icons.visibility_rounded,
                      AppColors.gradientBlue,
                      onTap: () {
                        getApprovalDetails(id);

                        debugPrint("VIEW APPROVAL RETURN ID => $id");
                      },
                    ),

                    SizedBox(width: isTablet ? 8 : 5),
                  ],

                  // =================================================
                  // PDF
                  // =================================================
                  pdfBtn(() {
                    openPdf(id, row: item);
                  }),

                  SizedBox(width: isTablet ? 8 : 5),

                  if (canModify && hasPermission("approval-return-delete")) ...[
                    //SizedBox(width: isTablet ? 8 : 5),

                    premiumIconBtn(
                      Icons.delete_outline_rounded,
                      Colors.red,
                      onTap: () {
                        if (id > 0) {
                          _showDeleteDialog(item);
                        }
                      },
                    ),
                  ],
                  SizedBox(width: isTablet ? 8 : 5),
                  // =================================================
                  // EXPAND BUTTON
                  // =================================================
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (expandedApprovalReturnId == id) {
                          // Same card -> close
                          expandedApprovalReturnId = null;
                        } else {
                          // New card -> open
                          // Previous automatically close
                          expandedApprovalReturnId = id;
                        }
                      });
                    },

                    borderRadius: BorderRadius.circular(20),

                    child: AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,

                      duration: const Duration(milliseconds: 250),

                      child: Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,

                        decoration: BoxDecoration(
                          color: AppColors.primaryDark.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),

                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 22,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // =====================================================
            // EXPANDED SECTION
            // =====================================================
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),

              firstChild: const SizedBox(width: double.infinity, height: 0),

              secondChild: Container(
                width: double.infinity,

                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),

                child: Column(
                  children: [
                    // =================================================
                    // DIVIDER
                    // =================================================
                    Divider(height: 1, color: AppColors.border),

                    const SizedBox(height: 10),

                    // =================================================
                    // ERP DETAILS
                    // =================================================
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),

                      decoration: BoxDecoration(
                        color: AppColors.background,

                        border: Border.all(color: AppColors.border, width: 1.2),

                        borderRadius: BorderRadius.circular(6),
                      ),

                      child: Column(
                        children: [
                          // ===========================================
                          // DATE / RETURN TOTAL
                          // ===========================================
                          _erpRow(
                            "Date",
                            returnDate.isNotEmpty
                                ? formatDate(returnDate)
                                : "-",

                            "R_total",
                            returnTotal,
                          ),

                          Divider(height: 1, color: AppColors.border),

                          // ===========================================
                          // TYPE
                          // ===========================================
                          _erpRow("Type", sourceType, "", ""),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
            ),
          ],
        ),
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

  Widget premiumIconBtn(
      IconData icon,
      Color color, {
        required VoidCallback onTap,
      }) {
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

  /// 🔹 PDF Button
  Widget pdfBtn(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xffE57373), Color(0xffD32F2F)],
          ),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.picture_as_pdf, color: Colors.white, size: 16),
            SizedBox(width: 0),
            Text(
              "",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget pdfBtn1(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xffE57373), Color(0xffD32F2F)],
          ),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.picture_as_pdf, color: Colors.white, size: 16),
            SizedBox(width: 4),
            Text(
              "PDF",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> openApprovalPdf(String fromDate, String toDate) async {
    if (fromDate.trim().isEmpty || toDate.trim().isEmpty) {
      AppMessage.error(context, "Please select From and To date");
      return;
    }

    final fromDateApi = formatDate(fromDate);
    final toDateApi = formatDate(toDate);
    // 🔥 Branch mode → &management_branches[]=1&management_branches[]=2
    final String url = _br(
      "${ApiConstants.baseUrl}returns/export/listpdf"
          "?from_date=$fromDateApi"
          "&to_date=$toDateApi",
    );
    debugPrint("📤 RETURN LIST PDF URL => $url");

    final response = await ApiHelper().getpdfapprovalreturnRequest(
      url,
      responseType: ResponseType.bytes,
    );

    if (!mounted) return;

    if (response != null && response.statusCode == 200) {
      final dir = await getTemporaryDirectory();

      final file = File("${dir.path}/approval_report.pdf");

      await file.writeAsBytes(response.data);

      await OpenFile.open(file.path);
    } else {
      print("PDF Download Failed");
    }
  }

  /// =========================================================
  /// 📄 EXPORT — PDF / EXCEL (getPdfRequest → bytes)
  /// return_list?from_date=..&to_date=..&management_branches[]=1&export=pdf
  /// =========================================================

  static String get _exportUrl => ApiConstants.return_list;

  /// "pdf" / "excel" chalu hoy tyare (bijo tap na thay)
  String? _exporting;

  Future<void> _export(String type) async {
    if (_exporting != null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _exporting = type);

    try {
      // List ma je date + branch chhe e j export ma pan
      String base = _exportUrl;
      if (fromDateController.text.trim().isNotEmpty &&
          toDateController.text.trim().isNotEmpty) {
        base += "?from_date=${formatDate(fromDateController.text.trim())}"
            "&to_date=${formatDate(toDateController.text.trim())}";
      }
      base = _br(base);
      final String url = "$base${base.contains('?') ? '&' : '?'}export=$type";
      debugPrint("📤 EXPORT $type URL => $url");

      final response = await ApiHelper().getPdfRequest(
        url,
        receiveTimeout: const Duration(minutes: 2),
      );

      if (!mounted) return;

      if (response == null || response.statusCode != 200) {
        AppMessage.error(
          context,
          _exportError(response?.data) ??
              "Failed to download ${type == 'pdf' ? 'PDF' : 'Excel'}",
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
      final file = File("${dir.path}/Approval_Return_$stamp.$ext");
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      AppMessage.success(
          context, "${type == 'pdf' ? 'PDF' : 'Excel'} downloaded");
      await OpenFile.open(file.path);
    } catch (e) {
      debugPrint("❌ EXPORT $type ERROR => $e");
      if (mounted) AppMessage.error(context, "Download failed");
    } finally {
      if (mounted) setState(() => _exporting = null);
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

  Widget _exportBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required bool busy,
    required VoidCallback onTap,
    required bool isMobile,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: _exporting != null ? null : onTap,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          padding: EdgeInsets.all(isMobile ? 6 : 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          // Loader fakt ApiHelper nu j (button ma spinner nahi)
          child: Opacity(
            opacity: busy ? 0.5 : 1,
            child: Icon(icon, color: color, size: isMobile ? 20 : 24),
          ),
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
      case "gold":
        startColor = const Color(0xffC8A96A);
        endColor = const Color(0xffE6C58A);
        label = "Gold";
        break;

      case "silver":
        startColor = const Color(0xffD9534F);
        endColor = const Color(0xffF28B82);
        label = "Silver";
        break;

      case "platinum":
        startColor = const Color(0xffB07A3F);
        endColor = const Color(0xffE0A96D);
        label = "Platinum";
        break;

      case "other":
        startColor = const Color(0xff7B5E57);
        endColor = const Color(0xffBCAAA4);
        label = "Other";
        break;

      default:
        return const SizedBox.shrink(); // 👈 Unknown hide
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [startColor, endColor]),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
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
            label,
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

  Future<void> openPdfUrl(String url) async {
    final Uri uri = Uri.parse(url);

    print(url);

    if (!await launchUrl(uri)) {
      throw Exception('Could not launch $uri');
    }
  }

  void searchUser(String value) {
    if (value.isEmpty) {
      setState(() {
        userlist = allItems;
      });
      return;
    }

    List filteredList = allItems.where((user) {
      final name = user["voucher_no"]?.toString().toLowerCase() ?? "";
      final customer = user["customer_name"]?.toString().toLowerCase() ?? "";
      final source = user["source_type"]?.toString().toLowerCase() ?? "";

      return name.contains(value.toLowerCase()) ||
          customer.contains(value.toLowerCase()) ||
          source.contains(value.toLowerCase());
    }).toList();

    setState(() {
      userlist = filteredList;
    });
  }

  Future<void> getApprovalDetails(dynamic id) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final response = await ApiHelper().getRequestWithId(
      ApiConstants.returns_vouchar,
      id,
    );

    Navigator.pop(context);

    if (response != null && response.statusCode == 200) {
      /// ✅ DIRECT JSON (NO utf8.decode)
      final data = response.data;

      final item = data["data"] is List ? data["data"][0] : data["data"];

      showApprovalDialog(item);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to load details")));
    }
  }

  void showApprovalDialog(Map<String, dynamic> item) {
    String val(dynamic v) {
      if (v == null || v.toString().trim().isEmpty) {
        return "-";
      }
      return v.toString();
    }

    final List items = item["items"] is List ? item["items"] : [];

    final Size screenSize = MediaQuery.of(context).size;

    final bool isTablet = screenSize.width >= 600;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.50),
      builder: (dialogContext) {
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.transparent,

          insetPadding: EdgeInsets.symmetric(
            horizontal: isTablet ? 30 : 12,
            vertical: 18,
          ),

          child: Container(
            width: isTablet ? 900 : double.infinity,

            constraints: BoxConstraints(maxHeight: screenSize.height * 0.88),

            decoration: BoxDecoration(
              color: AppColors.background,

              borderRadius: BorderRadius.circular(15),

              border: Border.all(
                color: AppColors.primaryDark.withOpacity(0.14),
              ),

              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.20),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),

            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),

              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // =========================================================
                  // PREMIUM BLUE HEADER
                  // =========================================================
                  Container(
                    width: double.infinity,

                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),

                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primaryDark, AppColors.gradientBlue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),

                    child: Row(
                      children: [
                        // ICON
                        Container(
                          width: 40,
                          height: 40,

                          alignment: Alignment.center,

                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.14),

                            borderRadius: BorderRadius.circular(9),

                            border: Border.all(
                              color: Colors.white.withOpacity(0.18),
                            ),
                          ),

                          child: const Icon(
                            Icons.assignment_return_outlined,
                            color: Colors.white,
                            size: 21,
                          ),
                        ),

                        const SizedBox(width: 10),

                        // TITLE
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Return Details",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),

                              SizedBox(height: 2),

                              Text(
                                "Approval return voucher details",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ===============================================
                        // PDF BUTTON
                        // ===============================================
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),

                            onTap: () {
                              openPdf(item["id"]);
                            },

                            child: Container(
                              height: 36,

                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),

                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.13),

                                borderRadius: BorderRadius.circular(8),

                                border: Border.all(
                                  color: Colors.white.withOpacity(0.16),
                                ),
                              ),

                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.picture_as_pdf_outlined,
                                    color: Colors.white,
                                    size: 17,
                                  ),

                                  SizedBox(width: 5),

                                  Text(
                                    "PDF",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 7),

                        // ===============================================
                        // CLOSE
                        // ===============================================
                        Material(
                          color: Colors.transparent,

                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),

                            onTap: () {
                              Navigator.pop(dialogContext);
                            },

                            child: Container(
                              width: 36,
                              height: 36,

                              alignment: Alignment.center,

                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.13),

                                borderRadius: BorderRadius.circular(8),
                              ),

                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // =========================================================
                  // BODY
                  // =========================================================
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          // =================================================
                          // VOUCHER INFORMATION TITLE
                          // =================================================
                          Row(
                            children: [
                              Container(
                                width: 29,
                                height: 29,

                                alignment: Alignment.center,

                                decoration: BoxDecoration(
                                  color: AppColors.iconBg,
                                  borderRadius: BorderRadius.circular(7),
                                ),

                                child: const Icon(
                                  Icons.receipt_long_outlined,
                                  size: 16,
                                  color: AppColors.primaryDark,
                                ),
                              ),

                              const SizedBox(width: 8),

                              const Text(
                                "Voucher Information",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),

                              const Spacer(),

                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),

                                decoration: BoxDecoration(
                                  color: AppColors.iconBg,

                                  borderRadius: BorderRadius.circular(20),

                                  border: Border.all(color: AppColors.border),
                                ),

                                child: Text(
                                  val(item["return_voucher_no"]),

                                  style: const TextStyle(
                                    color: AppColors.primaryDark,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // =================================================
                          // VOUCHER INFO CARD
                          // =================================================
                          Container(
                            width: double.infinity,

                            decoration: BoxDecoration(
                              color: Colors.white,

                              borderRadius: BorderRadius.circular(9),

                              border: Border.all(color: AppColors.border),

                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.shadow,
                                  blurRadius: 7,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),

                            child: Column(
                              children: [
                                // ===========================================
                                // CUSTOMER + VOUCHER
                                // ===========================================
                                _premiumApprovalInfoRow(
                                  leftIcon: Icons.person_outline_rounded,
                                  leftTitle: "Customer",
                                  leftValue: val(item["customer"]?["name"]),

                                  rightIcon: Icons.confirmation_number_outlined,
                                  rightTitle: "Voucher",
                                  rightValue: val(item["return_voucher_no"]),
                                ),

                                const Divider(
                                  height: 1,
                                  color: AppColors.border,
                                ),

                                // ===========================================
                                // DATE + REMARKS
                                // ===========================================
                                _premiumApprovalInfoRow(
                                  leftIcon: Icons.calendar_month_outlined,
                                  leftTitle: "Date",
                                  leftValue: val(item["return_date"]),

                                  rightIcon: Icons.notes_rounded,
                                  rightTitle: "Remarks",
                                  rightValue: val(item["remarks"]),
                                ),

                                const Divider(
                                  height: 1,
                                  color: AppColors.border,
                                ),

                                // ===========================================
                                // AMOUNT
                                // ===========================================
                                Container(
                                  width: double.infinity,

                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 11,
                                  ),

                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.iconBg.withOpacity(0.65),

                                        Colors.white,
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                  ),

                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,

                                        alignment: Alignment.center,

                                        decoration: BoxDecoration(
                                          color: AppColors.primaryDark
                                              .withOpacity(0.09),

                                          borderRadius: BorderRadius.circular(
                                            7,
                                          ),
                                        ),

                                        child: const Icon(
                                          Icons.currency_rupee_rounded,
                                          size: 17,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),

                                      const SizedBox(width: 9),

                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Return Amount",
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                color: AppColors.textSecondary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      Text(
                                        val(item["return_total"]),

                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // =================================================
                          // ITEM DETAILS HEADER
                          // =================================================
                          Row(
                            children: [
                              Container(
                                width: 29,
                                height: 29,

                                alignment: Alignment.center,

                                decoration: BoxDecoration(
                                  color: AppColors.iconBg,

                                  borderRadius: BorderRadius.circular(7),
                                ),

                                child: const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 15,
                                  color: AppColors.primaryDark,
                                ),
                              ),

                              const SizedBox(width: 8),

                              const Text(
                                "Item Details",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),

                              const Spacer(),

                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),

                                decoration: BoxDecoration(
                                  color: AppColors.iconBg,

                                  borderRadius: BorderRadius.circular(20),

                                  border: Border.all(color: AppColors.border),
                                ),

                                child: Text(
                                  "${items.length} ${items.length == 1 ? "Item" : "Items"}",

                                  style: const TextStyle(
                                    color: AppColors.primaryDark,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // =================================================
                          // ITEMS
                          // =================================================
                          if (items.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 30),

                              decoration: BoxDecoration(
                                color: Colors.white,

                                borderRadius: BorderRadius.circular(9),

                                border: Border.all(color: AppColors.border),
                              ),

                              child: const Column(
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    color: AppColors.textLight,
                                    size: 28,
                                  ),

                                  SizedBox(height: 7),

                                  Text(
                                    "No items available",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),

                              itemCount: items.length,

                              separatorBuilder: (context, index) {
                                return const SizedBox(height: 8);
                              },

                              itemBuilder: (context, index) {
                                final Map<String, dynamic> row =
                                Map<String, dynamic>.from(
                                  items[index] ?? {},
                                );

                                final Map<String, dynamic> approvalItem =
                                row["approval_item"] is Map
                                    ? Map<String, dynamic>.from(
                                  row["approval_item"],
                                )
                                    : <String, dynamic>{};

                                final Map<String, dynamic> itemset =
                                approvalItem["item_set"] is Map
                                    ? Map<String, dynamic>.from(
                                  approvalItem["item_set"],
                                )
                                    : <String, dynamic>{};

                                final Map<String, dynamic> itemData =
                                itemset["item"] is Map
                                    ? Map<String, dynamic>.from(itemset["item"])
                                    : <String, dynamic>{};

                                return Container(
                                  width: double.infinity,

                                  decoration: BoxDecoration(
                                    color: Colors.white,

                                    borderRadius: BorderRadius.circular(9),

                                    border: Border.all(color: AppColors.border),

                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.shadow,
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),

                                  child: Column(
                                    children: [
                                      // =====================================
                                      // ITEM CARD HEADER
                                      // =====================================
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),

                                        decoration: BoxDecoration(
                                          color: AppColors.iconBg.withOpacity(
                                            0.65,
                                          ),

                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(8),

                                            topRight: Radius.circular(8),
                                          ),
                                        ),

                                        child: Row(
                                          children: [
                                            Container(
                                              width: 27,
                                              height: 27,

                                              alignment: Alignment.center,

                                              decoration: BoxDecoration(
                                                color: AppColors.primaryDark,

                                                borderRadius:
                                                BorderRadius.circular(6),
                                              ),

                                              child: Text(
                                                "${index + 1}",

                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),

                                            const SizedBox(width: 8),

                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                CrossAxisAlignment.start,

                                                children: [
                                                  Text(
                                                    val(itemData["item_name"]),

                                                    maxLines: 1,

                                                    overflow:
                                                    TextOverflow.ellipsis,

                                                    style: const TextStyle(
                                                      color:
                                                      AppColors.textPrimary,
                                                      fontSize: 11.5,
                                                      fontWeight:
                                                      FontWeight.w700,
                                                    ),
                                                  ),

                                                  const SizedBox(height: 1),

                                                  Text(
                                                    "Code: ${val(approvalItem["qr_code"])}",

                                                    style: const TextStyle(
                                                      color: AppColors
                                                          .textSecondary,
                                                      fontSize: 9.5,
                                                      fontWeight:
                                                      FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            const Icon(
                                              Icons.inventory_2_outlined,
                                              size: 17,
                                              color: AppColors.primaryDark,
                                            ),
                                          ],
                                        ),
                                      ),

                                      // =====================================
                                      // WEIGHT DETAILS
                                      // =====================================
                                      Padding(
                                        padding: const EdgeInsets.all(10),

                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: _premiumWeightBox(
                                                title: "Gross Wt",
                                                value: val(
                                                  itemset["gross_weight"],
                                                ),
                                                icon: Icons.scale_outlined,
                                              ),
                                            ),

                                            const SizedBox(width: 7),

                                            Expanded(
                                              child: _premiumWeightBox(
                                                title: "Less Wt",
                                                value: val(itemset["other"]),
                                                icon: Icons
                                                    .remove_circle_outline_rounded,
                                              ),
                                            ),

                                            const SizedBox(width: 7),

                                            Expanded(
                                              child: _premiumWeightBox(
                                                title: "Net Wt",
                                                value: val(
                                                  itemset["net_weight"],
                                                ),
                                                icon: Icons.balance_outlined,
                                                highlight: true,
                                              ),
                                            ),

                                            const SizedBox(width: 7),

                                            Expanded(
                                              child: _premiumWeightBox(
                                                title: "Other",
                                                value: val(
                                                  itemset["sale_other"],
                                                ),
                                                icon: Icons.more_horiz_rounded,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),

                  // =========================================================
                  // BOTTOM BAR
                  // =========================================================
                  Container(
                    width: double.infinity,

                    padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),

                    decoration: const BoxDecoration(
                      color: Colors.white,

                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),

                    child: Row(
                      children: [
                        // SUMMARY
                        Expanded(
                          child: Text(
                            "${items.length} ${items.length == 1 ? "item" : "items"} in this return",

                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        // CLOSE BUTTON
                        SizedBox(
                          width: isTablet ? 180 : 130,
                          height: 42,

                          child: Material(
                            color: Colors.transparent,

                            child: InkWell(
                              borderRadius: BorderRadius.circular(7),

                              onTap: () {
                                Navigator.pop(dialogContext);
                              },

                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.primaryDark,
                                      AppColors.gradientBlue,
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),

                                  borderRadius: BorderRadius.circular(7),

                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryDark.withOpacity(
                                        0.20,
                                      ),

                                      blurRadius: 7,

                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),

                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,

                                  children: [
                                    Icon(
                                      Icons.check_circle_outline_rounded,
                                      color: Colors.white,
                                      size: 17,
                                    ),

                                    SizedBox(width: 6),

                                    Text(
                                      "Close",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
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
          ),
        );
      },
    );
  }

  Widget _premiumApprovalInfoRow({
    required IconData leftIcon,
    required String leftTitle,
    required String leftValue,
    required IconData rightIcon,
    required String rightTitle,
    required String rightValue,
  }) {
    Widget info({
      required IconData icon,
      required String title,
      required String value,
    }) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.iconBg,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 15, color: AppColors.primaryDark),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
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

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          info(icon: leftIcon, title: leftTitle, value: leftValue),

          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(vertical: 7),
            color: AppColors.border,
          ),

          info(icon: rightIcon, title: rightTitle, value: rightValue),
        ],
      ),
    );
  }

  Widget _premiumWeightBox({
    required String title,
    required String value,
    required IconData icon,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),

      decoration: BoxDecoration(
        color: highlight
            ? AppColors.primaryDark.withOpacity(0.07)
            : AppColors.background,

        borderRadius: BorderRadius.circular(7),

        border: Border.all(
          color: highlight
              ? AppColors.primaryDark.withOpacity(0.20)
              : AppColors.border,
        ),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 12,
                color: highlight
                    ? AppColors.primaryDark
                    : AppColors.textSecondary,
              ),

              const SizedBox(width: 4),

              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 8.5,
                    color: highlight
                        ? AppColors.primaryDark
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 5),

          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,

            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: highlight ? AppColors.primaryDark : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  String formatDate(String date) {
    final parts = date.split('-');
    return "${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}";
  }

  /// 🔥 Customer select / clear → filter ફરી લગાવો
  void _setCustomerFilter(Map<String, dynamic>? customer) {
    setState(() {
      selectedItem = customer?["id"]?.toString();
      selectedCustomerName = customer?["name"]?.toString();
      selectedCompanyId = customer?["company_id"]?.toString();
      selectedUserId = customer?["id"]?.toString();
    });

    applyDateFilter();

    debugPrint("Selected Customer => ${customer?["name"] ?? "ALL"}");
  }

  void _showDeleteDialog(Map item) {
    String clean(dynamic v) {
      final s = v?.toString().trim() ?? "";
      return s == "null" ? "" : s;
    }

    /// ============================================
    /// VOUCHER DATA
    /// ============================================
    final String voucherNo = clean(item["voucher_no"]);
    final String heading =
    voucherNo.isNotEmpty ? voucherNo : "Voucher #${clean(item["id"])}";

    final String customer = clean(item["customer_name"]);
    final String total = clean(item["return_total"]);

    /// 2026-09-30 → 30-09-2026
    String date = clean(item["return_date"]);
    if (date.length >= 10 && date[4] == "-") {
      date = date.substring(0, 10).split("-").reversed.join("-");
    }

    final String subtitle = [
      if (customer.isNotEmpty) customer,
      if (date.isNotEmpty) date,
      if (total.isNotEmpty) "₹ $total",
    ].join("  •  ");

    /// ============================================
    /// DIALOG
    /// ============================================
    showGeneralDialog(
      context: context,
      barrierLabel: "Delete",
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.45),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, _, __) {
        final double width = MediaQuery.of(dialogContext).size.width;

        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: width >= 600 ? 420 : width * 0.88,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.gradientBlue.withOpacity(0.18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark.withOpacity(0.25),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    /// ===================================
                    /// HEADER
                    /// ===================================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primaryDark, AppColors.gradientBlue],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.30),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              size: 30,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "Delete Approval Return?",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "This action cannot be undone",
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.white.withOpacity(0.75),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    /// ===================================
                    /// VOUCHER CARD
                    /// ===================================
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.gradientBlue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.gradientBlue.withOpacity(0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.gradientBlue.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.assignment_return_outlined,
                                size: 21,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    heading,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  if (subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Text(
                        "Are you sure you want to delete this approval return voucher?",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    /// ===================================
                    /// BUTTONS
                    /// ===================================
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: AppColors.border)),
                      ),
                      child: Row(
                        children: [
                          /// CANCEL
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  side: BorderSide(color: AppColors.border),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                ),
                                child: const Text(
                                  "Cancel",
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          /// DELETE
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(9),
                                  onTap: () {
                                    Navigator.pop(dialogContext);
                                    deleteUser(item["id"].toString());
                                  },
                                  child: Ink(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          AppColors.primaryDark,
                                          AppColors.gradientBlue,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(9),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.gradientBlue
                                              .withOpacity(0.30),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          "Delete",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
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
            ),
          ),
        );
      },
      transitionBuilder: (context, anim, _, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> deleteUser(String id) async {
    try {
      final response = await ApiHelper().deleteRequest(
        "${ApiConstants.returns_vouchar}/$id",
      );

      if (!mounted) return;

      await _handleDeleteResponse(response?.statusCode, response?.data);
    } on DioException catch (e) {
      /// ApiHelper 4xx ને exception તરીકે ફેંકે તો પણ message બતાવો
      if (!mounted) return;
      await _handleDeleteResponse(e.response?.statusCode, e.response?.data);
    } catch (e) {
      debugPrint("❌ DELETE RETURN ERROR => $e");
      if (!mounted) return;
      await _showMessageDialog(
        title: "Delete Failed",
        message: "Something went wrong. Please try again.",
      );
    }
  }

  Future<void> _handleDeleteResponse(int? statusCode, dynamic data) async {
    final Map body = data is Map ? data : {};

    final bool isSuccess = (statusCode == 200 || statusCode == 204) &&
        body["success"] != false &&
        body["status"] != false;

    if (isSuccess) {
      AppMessage.success(
        context,
        body["message"]?.toString() ?? "Approval return deleted successfully",
      );

      /// 🔥 Return list ફરી લાવો (category() customer list હતું)
      await getSaleDetails();
      return;
    }

    await _showMessageDialog(
      title: "Delete Failed",
      message: body["message"]?.toString() ?? "Failed to delete voucher",
    );

    /// Server એ બદલાયેલો data કહ્યો હોય તો પણ list fresh કરો
    if (statusCode == 409 && mounted) {
      await getSaleDetails();
    }
  }

  /// 🔥 Message popup — OK દબાવતાં જ બંધ
  Future<void> _showMessageDialog({
    required String title,
    required String message,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 30),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 30,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "OK",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatUiDate(DateTime d) => "${d.day}-${d.month}-${d.year}";

  @override
  void dispose() {
    searchController.dispose();
    fromDateController.dispose();
    toDateController.dispose();
    super.dispose();
  }

  /// 🔥 LOAD BRANCHES (Sale Summary jevu j)
  /// =========================================================

  Future<void> _loadBranches() async {
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

  /// From / To date (dd-MM-yyyy → yyyy-MM-dd), khotu hoy to null

  /// Approval return list farithi (branch mujab)
  Future<void> _reloadReturns() async {
    setState(() => expandedApprovalReturnId = null);
    await getSaleDetails();
  }

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
      await _reloadReturns();
    } finally {
      if (mounted) setState(() => branchReportLoading = false);
    }
  }

  /// Branch report bandh kari ne potani company ni gallery
  Future<void> clearBranchReport() async {
    setState(() => appliedCompanyIds = []);
    await _reloadReturns();
  }

  // ============================================================
  // 🔥 BRANCH REPORTS (expand tab) — Sale Summary jevu j
  // ============================================================

  Widget _buildBranchCard() {
    if (branchesLoading) {
      return Container(
        margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        padding: const EdgeInsets.all(14),
        decoration: _branchCardDecoration(),
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
      decoration: _branchCardDecoration(),
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
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: selectedList.isEmpty
                                ? Padding(
                              padding: const EdgeInsets.only(left: 4),
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
                    "Select one or more branches to see their approval returns.",
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 10),

                  _viewReportButton(highlight: appliedDiffers),

                  // Branch report chalu hoy tyare info + clear
                  if (_branchMode) ...[
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
                              "Showing approval returns of "
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
                              padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: const Size(0, 28),
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
      borderRadius: BorderRadius.circular(5),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xff22C55E), Color(0xff16A34A)],
          ),
          borderRadius: BorderRadius.circular(5),
          boxShadow: [
            BoxShadow(
              color:
              const Color(0xff16A34A).withOpacity(highlight ? 0.35 : 0.15),
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
                                  borderRadius: BorderRadius.circular(5),
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
                              borderRadius: BorderRadius.circular(5),
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
                                  borderRadius: BorderRadius.circular(5),
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

  BoxDecoration _branchCardDecoration() {
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
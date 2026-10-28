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
import '../Extra/ItemProvider.dart';
import '../Extra/PermissionDeniedWidget.dart';
import '../Extra/PremiumSearchableDropdown.dart';
import 'Recive_return_purchase.dart';
import '../Extra/AppMessage.dart';
import 'package:intl/intl.dart';

import 'package:pecifician_sysytem/Settings/BranchManagementScreen.dart'
    show BranchApi, Company, BranchTypeX;
import 'package:pecifician_sysytem/Reports/BranchAccess.dart';

class Receivevoucharscreen extends StatefulWidget {
  const Receivevoucharscreen({super.key});

  @override
  State<Receivevoucharscreen> createState() => _ReceivevoucharscreenState();
}

class _ReceivevoucharscreenState extends State<Receivevoucharscreen> {
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
  List cartItems = [];
  bool dateFilterApplied = false;
  Future<void> _selectDate(TextEditingController controller) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        // ✅ hammesha dd-MM-yyyy (01-05-2026)
        controller.text = DateFormat("dd-MM-yyyy").format(picked);
      });
    }
  }
  List allUsers = []; // 🔥 original data store
  void applyDateFilter() {
    List filtered = List.from(allUsers);

    /// =========================================
    /// CUSTOMER FILTER — always active jyare selected hoy
    /// =========================================
    if (selectedItem != null &&
        selectedItem.toString().isNotEmpty) {

      filtered = filtered.where((item) {
        return item["customer_id"]?.toString() ==
            selectedItem.toString();
      }).toList();
    }

    /// =========================================
    /// DATE FILTER — bas "Show" dabaya pachi j apply thay
    /// =========================================
    if (dateFilterApplied &&
        fromDateController.text.isNotEmpty &&
        toDateController.text.isNotEmpty) {

      try {
        final DateTime fromDate =
        _convertToDate(fromDateController.text);

        final DateTime toDate =
        _convertToDate(toDateController.text);

        filtered = filtered.where((item) {
          final String voucherDate =
              item["voucher_date"]?.toString() ?? "";

          if (voucherDate.isEmpty) {
            return false;
          }

          final DateTime? itemDate =
          DateTime.tryParse(voucherDate);

          if (itemDate == null) {
            return false;
          }

          return !itemDate.isBefore(fromDate) &&
              !itemDate.isAfter(toDate);
        }).toList();
      } catch (e) {
        print("DATE FILTER ERROR => $e");
      }
    }

    setState(() {
      userlist = filtered;
    });

    print("FILTERED COUNT => ${filtered.length}");
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

  /// sales_advance_ledger_vouchers?management_branches[]=1&management_branches[]=2 (branch mode only)
  String _br(String url) => _branchMode
      ? "$url${url.contains('?') ? '&' : '?'}$_branchQuery"
      : url;

  /// voucher → branch name (company_id / branch / company_name)
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

  /// ✅ Aa voucher main company no chhe? (fakt eno j edit / delete)
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
    // print("🔥 Checking '$permissionName' in $userPermissions => ${userPermissions.contains(permissionName)}");
    return userPermissions.contains(permissionName);
  }
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    loadPermissions();
    //category();
    Future.microtask(() {
      Provider.of<ItemProvider>(context, listen: false).loadCustomers();

      DateTime today = DateTime.now();

      String formattedDate = "${today.day}-${today.month}-${today.year}";

      fromDateController.text = formattedDate;
      toDateController.text = formattedDate;
    });
    getSaleDetails();
    _loadBranches();
  }

  Future<void> category() async {
    final response =
    await ApiHelper().getRequest(ApiConstants.customerlist);

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
    final String url = _br(ApiConstants.sales_advance_ledger_vouchers);
    debugPrint("📋 RECEIVE VOUCHER URL => $url");

    final response = await ApiHelper().getRequest(url);

    if (!mounted) return;

    if (response != null && response.statusCode == 200) {

      final data = response.data;

      // ✅ success check
      final List categories = data['data'] ?? [];

      setState(() {

        tableRows.clear();
        userlist = categories;
        allUsers = categories; // 🔥 store original
        allItems = List.from(categories); // 🔥 must for filter


      });
      // Customer select hoy (ane Show dabavyu hoy to date) e j filter fari lagu
      applyDateFilter();
    } else {
      setState(() {
        userlist = [];
        allUsers = [];
        allItems = [];
      });
      print("API Failed");
      AppMessage.error(context, "Failed to load data");
    }
  }



  @override
  Widget build(BuildContext context) {

    if(!(
        hasPermission("approval-return-view") ||
            hasPermission("approval-return-manage")
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

        Navigator.pop(context,true);
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,  // ⭐ IMPORTANT FIX
        backgroundColor: AppColors.white,
        body: Stack(
          children: [

            /// ✅ Main Content
            Column(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).padding.top + 40,
                ),

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
                    padding: const EdgeInsets.only(left: 10,right: 10, top: 0),
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
                          builder: (context) => const ReciveReturnPurchase(),
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
                            "+ Create Receive Return",
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
                      "Receive Vouchar ",
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
                          Navigator.pop(context,true);
                        },
                        child: Container(
                          padding: EdgeInsets.all(isMobile ? 6 : 8),
                          decoration: BoxDecoration(
                            color:AppColors.primaryDark,
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
            )
          ],
        ),
        //bottomNavigationBar: _buildSaveButton(),

      ),
    );
  }





  /// 📄 Card nu PDF
  /// Branch mode: sales_advance_ledger_vouchers_pdf/378?management_branches[]=21 (fakt e card ni branch)
  /// Normal: pehla jevu j (getRequestWithId)
  Future<void> openPdf(int id, {Map? row}) async {
    await _openCardFile(
      id: id,
      row: row,
      endpoint: ApiConstants.sales_advance_ledger_vouchers_pdf,
      fileName: "Sale Advance Ledger$id.pdf",
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
              Color(0xff3A3F63),// deep dark
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
    double gross =
        double.tryParse(tableRows[index]["gross"]!.text) ?? 0;

    double other =
        double.tryParse(tableRows[index]["other"]!.text) ?? 0;

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
                text: row["sale_labour_rate"]?.toString() ?? ""),
            "labourAmount": TextEditingController(
                text: row["sale_labour_amount"]?.toString() ?? ""),
            "purity": TextEditingController(
                text: row["outward_purity"]?.toString() ?? ""),
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


  Future<List<Map<String,String>>?> openApprovePopup(BuildContext context) async {

    List<Map<String, String>> tableRows = [];
    TextEditingController labelController = TextEditingController();
    String? popupSelectedUser; // 👈 add this
    bool showScanner = false;
    bool showLabelField = false;

    return showDialog<List<Map<String,String>>>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) {

        return StatefulBuilder(
          builder: (context, setState) {

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 40),
              backgroundColor: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    width: double.infinity,
                    height: showScanner || showLabelField?700:500,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                      ),
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
                                  icon: const Icon(Icons.edit, color: Colors.white),
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
                                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                                ),

                                /// Close Icon
                                IconButton(
                                  onPressed: (){
                                    Navigator.pop(context);
                                  },
                                  icon: const Icon(Icons.close, color: Colors.white),
                                ),

                              ],
                            )

                          ],
                        ),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            const Text("Select Party",
                                style: TextStyle(color: Colors.white70)),

                            const SizedBox(height: 8),

                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                  items: customerlist.map<DropdownMenuItem<String>>((user) {
                                    return DropdownMenuItem<String>(
                                      value: user["id"].toString(),
                                      child: Text(
                                        user["name"] ?? "",
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      popupSelectedUser = val;
                                      showScanner = false;
                                      showLabelField = false;
                                      final selectedData = customerlist.firstWhere(
                                            (user) => user["id"].toString() == val,
                                      );
                                      selectedCompanyId =
                                          selectedData["company_id"].toString();

                                      print("Selected Company ID: $selectedCompanyId");
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
                                    labelStyle: const TextStyle(color: Colors.white70),
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
                                        border: Border.all(color: Colors.white24),
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
                                          border: TableBorder.all(color: Colors.white24),
                                          children: tableRows.asMap().entries.map((entry) {

                                            int index = entry.key;
                                            var row = entry.value;

                                            return TableRow(
                                              children: [

                                                _buildTableCell1(row["gross"]!, (val){ row["gross"] = val; }),
                                                _buildTableCell1(row["other"]!, (val){ row["other"] = val; }),
                                                _buildTableCell1(row["net"]!, (val){ row["net"] = val; }),
                                                // _buildTableCell1(row["labourRate"]!, (val){ row["labourRate"] = val; }),
                                                // _buildTableCell1(row["labourAmount"]!, (val){ row["labourAmount"] = val; }),
                                                _buildTableCell1(row["size"]!, (val){ row["size"] = val; }),
                                                _buildTableCell1(row["huid"]!, (val){ row["huid"] = val; }),

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
                                  onPressed: (){
                                    Navigator.pop(context, tableRows); // 🔥 return data
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
                              )

                            ]

                          ],
                        )


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
              border: Border.all(color: AppColors.border),
            ),
            child: Consumer<ItemProvider>(
              builder: (context, provider, child) {
                final customers = provider.customers;

                /// FIND SELECTED CUSTOMER
                Map? selectedCustomer;

                if (selectedItem != null) {
                  try {
                    selectedCustomer = customers.firstWhere(
                          (item) => item["id"]?.toString() == selectedItem.toString(),
                    );
                  } catch (_) {
                    selectedCustomer = null;
                  }
                }

                return Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    PremiumSearchableDropdown<Map>(
                      label: "",
                      hint: "Select Customer",
                      items: List<Map>.from(customers),
                      value: selectedCustomer,
                      prefixIcon: Icons.person_outline,

                      itemLabel: (item) => item["name"]?.toString() ?? "-",

                      /// SEARCH — Name / Mobile / Email / ID
                      searchText: (item) {
                        return [
                          item["name"]?.toString() ?? "",
                          item["mobile_no"]?.toString() ?? "",
                          item["email"]?.toString() ?? "",
                          item["id"]?.toString() ?? "",
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

          const SizedBox(height: 8),

          /// 🔥 BUTTONS
          Row(
            children: [

              /// SHOW
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      dateFilterApplied = true;   // 🔥 have date filter active thashe
                    });

                    applyDateFilter();   // 🔥 FIXED — was commented out
                    print("Apply Filter");
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
          )
        ],
      ),
    );
  }
  int? expandedVoucherId;
  Widget buildCard(Map<String, dynamic> item, int index) {
    final size = MediaQuery.of(context).size;
    final bool isTablet = size.width >= 600;

    // =========================================================
    // UNIQUE ID
    // =========================================================
    final int id =
        int.tryParse(item["id"]?.toString() ?? "0") ?? 0;

    final bool isExpanded = expandedVoucherId == id;

    // =========================================================
    // DATA
    // =========================================================
    final String voucherNo =
        item["voucher_no"]?.toString() ?? "-";

    final String date =
        item["voucher_date_fmt"]?.toString() ??
            item["voucher_date"]?.toString() ??
            "-";

    final String partyName =
        item["party_name"]?.toString() ?? "-";

    final String entryType =
        item["entry_type_label"]?.toString() ?? "-";

    final String paymentMode =
        item["payment_mode_label"]?.toString() ?? "-";

    final String metalType =
        item["metal_type_label"]?.toString() ?? "-";

    final String cashIn =
        item["cash_in"]?.toString() ?? "0";

    final String cashOut =
        item["cash_out"]?.toString() ?? "0";

    final String metalIn =
        item["metal_in"]?.toString() ?? "0";

    final String metalOut =
        item["metal_out"]?.toString() ?? "0";

    final String rate =
        item["rate"]?.toString() ?? "0";

    final String amount =
        item["amount"]?.toString() ?? "0";

    final String remarks =
        item["remarks"]?.toString() ?? "";

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
                  // VOUCHER NO + PARTY NAME
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

                        // PARTY NAME
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
                                partyName,
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
                  // ENTRY TYPE
                  // =================================================
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),

                    decoration: BoxDecoration(
                      color:
                      AppColors.primaryDark.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(5),
                    ),

                    child: Text(
                      entryType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),

                  SizedBox(
                    width: isTablet ? 8 : 5,
                  ),

                  // =================================================
                  // PDF
                  // =================================================
                  pdfBtn(() {
                    openPdf(id, row: item);
                  }),

                  SizedBox(
                    width: isTablet ? 8 : 5,
                  ),

                  // =================================================
                  // EXPAND BUTTON
                  // =================================================
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (expandedVoucherId == id) {
                          // Same card -> close
                          expandedVoucherId = null;
                        } else {
                          // Open selected card
                          // Previous card automatically close
                          expandedVoucherId = id;
                        }
                      });
                    },

                    borderRadius: BorderRadius.circular(20),

                    child: AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,

                      duration: const Duration(
                        milliseconds: 250,
                      ),

                      child: Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,

                        decoration: BoxDecoration(
                          color: AppColors.primaryDark
                              .withOpacity(0.08),
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
              duration: const Duration(
                milliseconds: 250,
              ),

              firstChild: const SizedBox(
                width: double.infinity,
                height: 0,
              ),

              secondChild: Container(
                width: double.infinity,

                padding: const EdgeInsets.fromLTRB(
                  10,
                  0,
                  10,
                  10,
                ),

                child: Column(
                  children: [

                    // =================================================
                    // DIVIDER
                    // =================================================
                    Divider(
                      height: 1,
                      color: AppColors.border,
                    ),

                    const SizedBox(height: 10),

                    // =================================================
                    // ERP DETAILS
                    // =================================================
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                      ),

                      decoration: BoxDecoration(
                        color: AppColors.background,

                        border: Border.all(
                          color: AppColors.border,
                          width: 1.2,
                        ),

                        borderRadius: BorderRadius.circular(6),
                      ),

                      child: Column(
                        children: [

                          // ===========================================
                          // DATE / AMOUNT
                          // ===========================================
                          _erpRow(
                            "Date",
                            date,
                            "Amount",
                            amount,
                          ),

                          Divider(
                            height: 1,
                            color: AppColors.border,
                          ),

                          // ===========================================
                          // TYPE / PAYMENT
                          // ===========================================
                          _erpRow(
                            "Type",
                            entryType,
                            "Payment",
                            paymentMode,
                          ),

                          Divider(
                            height: 1,
                            color: AppColors.border,
                          ),

                          // ===========================================
                          // CASH IN / CASH OUT
                          // ===========================================
                          _erpRow(
                            "Cash In",
                            cashIn,
                            "Cash Out",
                            cashOut,
                          ),

                          Divider(
                            height: 1,
                            color: AppColors.border,
                          ),

                          // ===========================================
                          // METAL / RATE
                          // ===========================================
                          _erpRow(
                            "Metal",
                            metalType,
                            "Rate",
                            rate,
                          ),

                          Divider(
                            height: 1,
                            color: AppColors.border,
                          ),

                          // ===========================================
                          // METAL IN / METAL OUT
                          // ===========================================
                          _erpRow(
                            "Metal In",
                            metalIn,
                            "Metal Out",
                            metalOut,
                          ),

                          // ===========================================
                          // REMARKS
                          // ===========================================
                          if (remarks.trim().isNotEmpty) ...[
                            Divider(
                              height: 1,
                              color: AppColors.border,
                            ),

                            _erpRow(
                              "Remarks",
                              remarks,
                              "",
                              "",
                            ),
                          ],
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


  Widget premiumIconBtn(IconData icon, Color color, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
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
            Text("",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500)),
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
            Text("PDF",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Future<void> openApprovalPdf(
      String fromDate,
      String toDate,
      ) async {

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
    debugPrint("📤 RECEIVE VOUCHER LIST PDF URL => $url");

    final response = await ApiHelper().getpdfapprovalreturnRequest(
      url,
      responseType: ResponseType.bytes,
    );

    if (!mounted) return;





    if (response != null && response.statusCode == 200) {

      final dir = await getTemporaryDirectory();

      final file = File(
        "${dir.path}/approval_report.pdf",
      );

      await file.writeAsBytes(response.data);

      await OpenFile.open(file.path);

    } else {

      print("PDF Download Failed");

    }
  }

  /// =========================================================
  /// 📄 EXPORT — PDF / EXCEL (getPdfRequest → bytes)
  /// sales_advance_ledger_vouchers?from_date=..&to_date=..&management_branches[]=1&export=pdf
  /// =========================================================

  static String get _exportUrl => ApiConstants.sales_advance_ledger_vouchers;

  /// "pdf" / "excel" chalu hoy tyare (bijo tap na thay)
  String? _exporting;

  Future<void> _export(String type) async {
    if (_exporting != null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _exporting = type);

    try {
      // Show dabavyu hoy to date + branch e j export ma pan
      String base = _exportUrl;
      if (dateFilterApplied &&
          fromDateController.text.trim().isNotEmpty &&
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
      final file = File("${dir.path}/Receive_Voucher_$stamp.$ext");
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
        endColor   = const Color(0xffE6C58A);
        label = "Gold";
        break;

      case "silver":
        startColor = const Color(0xffD9534F);
        endColor   = const Color(0xffF28B82);
        label = "Silver";
        break;

      case "platinum":
        startColor = const Color(0xffB07A3F);
        endColor   = const Color(0xffE0A96D);
        label = "Platinum";
        break;

      case "other":
        startColor = const Color(0xff7B5E57);
        endColor   = const Color(0xffBCAAA4);
        label = "Other";
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
        borderRadius: BorderRadius.circular(5),
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

      final item = data["data"] is List
          ? data["data"][0]
          : data["data"];

      showApprovalDialog(item);

    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load details")),
      );
    }
  }


  void showApprovalDialog(Map<String, dynamic> item) {
    String val(dynamic v) => v == null ? "-" : v.toString();

    var items = item["items"] ?? [];
    var data = item["data"] ?? [];
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xffFAF7F2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ), // 🔥 FIX
          child: Container(
            width: MediaQuery.of(context).size.width * 0.92,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// 🔝 HEADER
                  Row(
                    children: [
                      const Text(
                        "Return Details",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),

                      pdfBtn(() {
                        openPdf(item["id"]);
                      }),

                      const SizedBox(width: 8),

                      InkWell(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
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

                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: Colors.grey.shade200,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      children: [
                        /// Row 1
                        _erpRow(
                          "Customer",
                          val(item["customer"]?["name"]),
                          "Vouchar",
                          val(item["return_voucher_no"]),
                        ),
                        Divider(height: 1.5, color: Colors.grey.shade200),
                        /// Row 2
                        _erpRow(
                          "Date",
                          (val(item["return_date"])
                          ),
                          "Remarks",
                          val(item["remarks"]), // ✅ BEST),
                        ),
                        Divider(height: 1.0, color: Colors.grey.shade200),
                        /// Row 3
                        _erpRow(
                          "Amount",
                          val(item["return_total"]),
                          "",
                          val(item[""]),
                        ),
                      ],
                    ),
                  ),
                  /// 🔹 TOP INFO (3x3 GRID)
                  const SizedBox(height: 12),
                  Container(
                    height: 110,
                    child: ListView.builder(
                      scrollDirection: Axis.vertical,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final data = items[index];

                        final saleItem = data['approval_item'] ?? {};
                        final itemset = saleItem['item_set'] ?? {};
                        final itemData = itemset['item'] ?? {};

                        return Container(
                          width: 220,
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: Colors.grey.shade200,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(
                            children: [
                              /// Row 1
                              _erpRow(
                                "Item",
                                val(itemData['item_name']),
                                "Code",
                                val(itemData['item_code']),
                              ),
                              Divider(height: 1.0, color: Colors.grey.shade200),
                              /// Row 2
                              _erpRow(
                                "Gross Wt",
                                val(itemset['gross_weight']),
                                "Less Wt",
                                val(itemset['other']),
                              ),

                              Divider(height: 1.0, color: Colors.grey.shade200),

                              /// Row 2
                              _erpRow(
                                "Net Wt",
                                val(itemset['net_weight']),
                                "Other",
                                val(itemset['sale_other']),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),
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

  String formatDate(String date) {
    final parts = date.split('-');
    return "${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}";
  }

  /// 🔥 Customer select / clear → filter ફરી લગાવો
  void _setCustomerFilter(Map? customer) {
    setState(() {
      selectedItem = customer?["id"]?.toString();
      selectedCompanyId = customer?["company_id"]?.toString();
      selectedUserId = customer?["id"]?.toString();
    });

    debugPrint("Selected Customer => ${customer?["name"] ?? "ALL"}");

    /// customer હોય → એનો data, null → date પ્રમાણે બધું
    applyDateFilter();
  }

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

  /// Receive voucher list farithi (branch mujab)
  Future<void> _reloadVouchers() async {
    setState(() => expandedVoucherId = null);
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
      await _reloadVouchers();
    } finally {
      if (mounted) setState(() => branchReportLoading = false);
    }
  }

  /// Branch report bandh kari ne potani company ni gallery
  Future<void> clearBranchReport() async {
    setState(() => appliedCompanyIds = []);
    await _reloadVouchers();
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
                    "Select one or more branches to see their receive vouchers.",
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
                              "Showing receive vouchers of "
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
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pecifician_sysytem/Approval/CreateApprovalScreen.dart';
import 'package:pecifician_sysytem/Dashboard/HomeScreen.dart';
import 'package:pecifician_sysytem/Extra/AppColors.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import '../Extra/ItemProvider.dart';
import '../Extra/PermissionDeniedWidget.dart';
import '../Extra/PremiumSearchableDropdown.dart';
import '../Extra/AppMessage.dart';
import 'package:intl/intl.dart';

import 'package:pecifician_sysytem/Settings/BranchManagementScreen.dart'
    show BranchApi, Company, BranchTypeX;
import 'package:pecifician_sysytem/Reports/BranchAccess.dart';

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({super.key});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  TextEditingController searchController = TextEditingController();
  TextEditingController fromDateController = TextEditingController();
  TextEditingController toDateController = TextEditingController();
  List userlist = [];
  String? selectedItem;
  String? selectedCompanyId;
  String? selectedUserId;
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
  String? selectedCustomerName;
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> allItems = [];

  void searchCustomer(String value) {
    setState(() {
      if (value.trim().isEmpty) {
        userlist = List.from(allItems);
      } else {
        final String query = value.trim().toLowerCase();

        userlist = allItems.where((item) {
          final String customerName =
              item["customer_name"]?.toString().toLowerCase() ?? "";

          final String approvalNo =
              item["approval_no"]?.toString().toLowerCase() ?? "";

          return customerName.contains(query) ||
              approvalNo.contains(query);
        }).toList();
      }
    });
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

  /// Approval_list?management_branches[]=1&management_branches[]=2 (branch mode only)
  String _br(String url) => _branchMode
      ? "$url${url.contains('?') ? '&' : '?'}$_branchQuery"
      : url;

  /// approval → branch name (company_id / branch / company_name)
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

  /// ✅ Aa approval main company no chhe? (fakt eno j edit / delete)
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
    //print("🔥 Checking '$permissionName' in $userPermissions => ${userPermissions.contains(permissionName)}");
    return userPermissions.contains(permissionName);
  }

  Future<void> category() async {
    // 🔥 Branch mode → ?management_branches[]=1&management_branches[]=2
    final String url = _br(ApiConstants.Approval_list);

    final response = await ApiHelper().getRequest(url);

    print("approval API URL: $url");
    print("approval Raw Response: ${response.toString()}");

    if (!mounted) return;

    if (response != null && response.statusCode == 200) {
      final data = response.data;

      // ✅ success check
      final List categories = data['data'] ?? [];

      setState(() {
        userlist = categories;
        allItems = List.from(categories); // 🔥 must for filter
      });
      // 🔥 Date + Customer filter banne fari lagu karo
      applyDateFilter();
      print("✅ Total approval: ${userlist.length}");
    } else {
      setState(() {
        userlist = [];
        allItems = [];
      });
      print("❌ userlist API failed");
    }
  }

  /// 📄 Card nu PDF
  /// Branch mode: Approval_pdf/378?management_branches[]=21 (fakt e card ni branch)
  /// Normal: pehla jevu j (getRequestWithId)
  Future<void> openPdf(int id, {Map? row}) async {
    await _openCardFile(
      id: id,
      row: row,
      endpoint: ApiConstants.Approval_pdf,
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

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<ItemProvider>(context, listen: false).refreshapprovalCustomers();
    });
    loadPermissions();
    DateTime today = DateTime.now();

    String formattedDate = "${today.day}-${today.month}-${today.year}";

    fromDateController.text = formattedDate;
    toDateController.text = formattedDate;

    category();
    _loadBranches();
  }

  /// ============================================================
  /// 🔥 LIST SUMMARY (QTY / GROSS WT / NET WT)
  ///
  /// "userlist" ma je pan vouchers currently filter thai ne
  /// dekhata hoy (date range / customer filter lagavya pachi),
  /// e badha vouchers na "total_items" (qty), "total_gross_weight"
  /// ane "total_net_weight" ne add kari ne ek combined total
  /// batavvanu — vouchers no count nahi, balke badha vouchers
  /// na items/weights no SUM.
  ///
  /// Example: Voucher 1 ma 10 item, Voucher 2 ma 25 item
  /// => Qty = 35, ane e j rite gross/net weight pan
  /// badha vouchers na weight no total.
  /// ============================================================

  /// ============================================================
  /// 🔥 LIST SUMMARY (QTY / GROSS WT / NET WT)
  ///
  /// Fakt e j vouchers count/sum thay che jena par EDIT icon
  /// dekhay che — matlab status "closed" na hoy AND user ne
  /// "approval-edit" ya "approval-manage" permission hoy.
  /// (Same condition je buildCard() ma edit icon batavva mate
  /// use thay che.)
  /// ============================================================

  List get _editableVouchers {
    final bool canEdit =
        hasPermission("approval-edit") || hasPermission("approval-manage");

    if (!canEdit) {
      return [];
    }

    return userlist.where((raw) {
      final Map item = raw is Map ? raw : {};

      final String status = item["status"]?.toString() ?? "";

      // Edit icon jeva j — biji branch no voucher count nahi
      return status.toLowerCase() != "closed" && _isMainData(item);
    }).toList();
  }

  Map<String, double> _calculateListSummary() {
    int totalQty = 0;

    double totalGross = 0;

    double totalNet = 0;

    for (final dynamic raw in _editableVouchers) {
      final Map item = raw is Map ? raw : {};

      final int itemQty =
          int.tryParse(item["total_items"]?.toString() ?? "0") ?? 0;

      totalQty += itemQty;

      /// 🔥 API field naam "gross_weight" che, "total_gross_weight" nathi
      totalGross +=
          double.tryParse(item["gross_weight"]?.toString() ?? "0") ?? 0;

      totalNet +=
          double.tryParse(item["total_net_weight"]?.toString() ?? "0") ?? 0;
    }

    return {
      "qty": totalQty.toDouble(),

      "gross": totalGross,

      "net": totalNet,
    };
  }

  /// ============================================================
  /// 🔥 SUMMARY BAR WIDGET
  /// ============================================================

  Widget buildListSummaryBar() {
    final Map<String, double> totals = _calculateListSummary();

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),

      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),

      decoration: BoxDecoration(
        color: AppColors.background,

        border: Border.all(color: AppColors.border, width: 1.5),

        borderRadius: BorderRadius.circular(0),
      ),

      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,

        child: Row(
          children: [
            _listSummaryBox("Vouchers", "${_editableVouchers.length}"),

            _listSummaryBox("Qty", totals["qty"]!.toStringAsFixed(0)),

            _listSummaryBox("Gross Wt", totals["gross"]!.toStringAsFixed(3)),

            _listSummaryBox("Net Wt", totals["net"]!.toStringAsFixed(3)),
          ],
        ),
      ),
    );
  }

  Widget _listSummaryBox(String title, String value) {
    return Container(
      width: 100,

      margin: const EdgeInsets.only(right: 8),

      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.border),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            title,

            maxLines: 1,

            overflow: TextOverflow.ellipsis,

            style: const TextStyle(fontSize: 10.5, color: Colors.black54),
          ),

          const SizedBox(height: 4),

          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!(hasPermission("approval-view") || hasPermission("approval-manage"))) {
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
            /// 🔥 Main UI
            Column(
              children: [
                /// IMPORTANT: top padding space leave karvu (AppBar mate)
                SizedBox(height: MediaQuery.of(context).padding.top + 30),

                // 🔥 Branch Reports tab sauthi upar
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _buildBranchCard(),
                ),

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
                  child: userlist.isEmpty
                      ? Center(
                    child: Text(
                      "No Data Found",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: userlist.length,
                    itemBuilder: (context, index) {
                      final item = userlist[index];
                      return buildCard(item, index);
                    },
                  ),
                ),

                /// =====================================================
                /// 🔥 SUMMARY BAR — QTY / GROSS WT / NET WT
                /// =====================================================
                if (userlist.isNotEmpty) buildListSummaryBar(),

                if (hasPermission("approval-create"))
                /// Bottom Button
                  InkWell(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const Createapprovalscreen(),
                        ),
                      );

                      // ✅ Create pachhi list refresh
                      if (!mounted) return;
                      if (result == true) await category();
                    },
                    borderRadius: BorderRadius.circular(5),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Container(
                        margin: const EdgeInsets.only(left: 16,right: 16,bottom: 16,top: 5),
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
                            "+ Create Approval",
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
                      "Approval",
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

                    // /// RIGHT NOTIFICATION ICON
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
      ),
    );
  }

  /// 🔥 CARD UI
  ///
  int? expandedApprovalId;
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
  //         /// 🔝 TOP ROW
  //         Row(
  //           children: [
  //             statusChip(item["status"]),
  //             const Spacer(),
  //
  //             /// ⚙️ ACTIONS
  //             Row(
  //               mainAxisAlignment: MainAxisAlignment.end,
  //               children: [
  //                 if (hasPermission("approval-edit") || hasPermission("approval-manage"))
  //                 premiumIconBtn(
  //                   Icons.edit,
  //                   Colors.blue,
  //                   onTap: () {
  //                     Navigator.push(
  //                       context,
  //                       MaterialPageRoute(
  //                         builder: (context) =>
  //                             Createapprovalscreen(userData: item),
  //                       ),
  //                     );
  //                   },
  //                 ),
  //
  //                 const SizedBox(width: 8),
  //                 if (hasPermission("approval-delete"))
  //                 premiumIconBtn(
  //                   Icons.visibility,
  //                   Colors.blue,
  //                   onTap: () {
  //                     getApprovalDetails(item["id"]); // 🔥 id pass karo
  //                     print("View Item");
  //                   },
  //                 ),
  //
  //                 const SizedBox(width: 8),
  //
  //                 pdfBtn(() {
  //                   openPdf(item["id"]);
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
  //               item["approval_no"],
  //               style: const TextStyle(
  //                 fontSize: 15,
  //                 color: Colors.black, // ✅ FIX
  //                 fontWeight: FontWeight.w600,
  //               ),
  //             ),
  //             const Spacer(),
  //             Text(
  //               item["customer_name"],
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
  //
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
  //               /// Row 1
  //               _erpRow(
  //                 "Date",
  //                 formatDate(item["approval_date"].toString()),
  //                 "Items",
  //                 item["total_items"].toString(),
  //               ),
  //
  //               Divider(height: 1, color: AppColors.border),
  //
  //               /// Row 2
  //               _erpRow(
  //                 "Total Wt",
  //                 item["total_net_weight"].toString() ?? "-",
  //                 "Amount",
  //                 "₹ ${item["total_amount"]}",
  //               ),
  //             ],
  //           ),
  //         ),
  //
  //         const SizedBox(height: 10),
  //
  //         // /// Divider
  //         // Divider(color: Colors.grey.shade300, height: 1),
  //         //
  //         // const SizedBox(height: 6),
  //       ],
  //     ),
  //   );
  // }

  Widget buildCard(Map<String, dynamic> item, int index) {
    final size = MediaQuery.of(context).size;
    final bool isTablet = size.width >= 600;

    // =========================================================
    // UNIQUE ID
    // =========================================================
    final int id = int.tryParse(item["id"]?.toString() ?? "0") ?? 0;

    final bool isExpanded = expandedApprovalId == id;

    // =========================================================
    // DATA - SAME EXISTING DATA
    // =========================================================
    final String approvalNo = item["approval_no"]?.toString() ?? "-";

    final String customerName = item["customer_name"]?.toString() ?? "-";

    final String status = item["status"]?.toString() ?? "-";

    final String approvalDate = item["approval_date"]?.toString() ?? "";

    final String totalItems = item["total_items"]?.toString() ?? "0";

    final String totalNetWeight = item["total_net_weight"]?.toString() ?? "-";

    final String totalAmount = item["total_amount"]?.toString() ?? "0";
    final String created_by = item["created_by"]?.toString() ?? "0";

    /// 🔐 Main company sivay ni branch no data → edit nahi
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
                  // APPROVAL NO + CUSTOMER NAME
                  // =================================================
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // APPROVAL NO
                        Text(
                          approvalNo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 2),

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
                        const SizedBox(height: 2),
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
                                created_by,
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
                  // STATUS
                  // =================================================
                  // statusChip(status),
                  SizedBox(width: isTablet ? 8 : 5),

                  // =================================================
                  // EDIT
                  // =================================================
                  if (canModify &&
                      status.toLowerCase() != "closed" &&
                      (hasPermission("approval-edit") ||
                          hasPermission("approval-manage"))) ...[
                    premiumIconBtn(
                      Icons.edit_rounded,
                      AppColors.gradientBlue,
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                Createapprovalscreen(userData: item),
                          ),
                        );

                        // ✅ Update pachhi list refresh
                        if (!mounted) return;
                        if (result == true) await category();
                      },
                    ),

                    SizedBox(width: isTablet ? 8 : 5),
                  ],

                  // =================================================
                  // VIEW
                  // =================================================
                  if (hasPermission("approval-delete")) ...[
                    premiumIconBtn(
                      Icons.visibility_rounded,
                      AppColors.gradientBlue,
                      onTap: () {
                        getApprovalDetails(id);

                        debugPrint("VIEW APPROVAL ID => $id");
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

                  // =================================================
                  // EXPAND BUTTON
                  // =================================================
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (expandedApprovalId == id) {
                          // Same card click -> close
                          expandedApprovalId = null;
                        } else {
                          // Open selected card
                          // Previous card automatically closes
                          expandedApprovalId = id;
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
                          // DATE / ITEMS
                          // ===========================================
                          _erpRow(
                            "Date",
                            approvalDate.isNotEmpty
                                ? formatDate(approvalDate)
                                : "-",

                            "Items",
                            totalItems,
                          ),

                          Divider(height: 1, color: AppColors.border),

                          // ===========================================
                          // TOTAL WEIGHT / AMOUNT
                          // ===========================================
                          _erpRow(
                            "Total Wt",
                            totalNetWeight,

                            "Amount",
                            "₹ $totalAmount",
                          ),
                          Divider(height: 1, color: AppColors.border),
                          _erpRow("Status", status, "", ""),
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
    final bool hideLeft = v1.toString().trim().isEmpty;
    final bool hideRight = v2.toString().trim().isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          /// LEFT FIELD
          if (!hideLeft)
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      t1,
                      style: const TextStyle(fontSize: 12, color: Colors.black),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      double.tryParse(v1.toString()) != null
                          ? double.parse(v1.toString()).toStringAsFixed(2)
                          : v1.toString(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          /// RIGHT FIELD
          if (!hideRight)
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      t2,
                      style: const TextStyle(fontSize: 12, color: Colors.black),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      double.tryParse(v2.toString()) != null
                          ? double.parse(v2.toString()).toStringAsFixed(2)
                          : v2.toString(),
                      style: const TextStyle(
                        fontSize: 13,
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

  /// 🔹 Status Chip
  Widget statusChip(String status) {
    Color startColor;
    Color endColor;

    switch (status.toLowerCase()) {
      case "open":

      /// 🔹 Soft Gold (Active)
        startColor = const Color(0xffC8A96A);
        endColor = const Color(0xffE6C58A);
        break;

      case "close":

      /// 🔹 Olive Green (Completed - premium feel)
        startColor = const Color(0xff6D8B3D);
        endColor = const Color(0xffA3C46B);
        break;

      case "partial":

      /// 🔹 Royal Bronze (In progress)
        startColor = const Color(0xffB07A3F);
        endColor = const Color(0xffE0A96D);
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
          /// 🔹 Status Dot
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: 6),

          /// 🔹 Text
          Text(
            status,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 0.3,
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

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xffF3E9DA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: Color(0xff8B6B2C)),
      ),
    );
  }

  /// 🔹 Icon Button

  /// 🔹 PDF Button
  Widget pdfBtn(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
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
      borderRadius: BorderRadius.circular(10),
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
          // TextField(
          //   controller: searchController,
          //   style: const TextStyle(color: Colors.black),
          //   onChanged: (value) {
          //     searchCustomer(value); // 🔥 LIVE SEARCH
          //   },
          //   decoration: InputDecoration(
          //     hintText: "Search Customer",
          //     hintStyle: TextStyle(color: Colors.grey.shade600),
          //     prefixIcon: Icon(Icons.search, color: AppColors.primaryDark),
          //     filled: true,
          //     fillColor: Colors.white,
          //     contentPadding: const EdgeInsets.symmetric(vertical: 0),
          //     border: OutlineInputBorder(
          //       borderRadius: BorderRadius.circular(8),
          //       borderSide: BorderSide(color: AppColors.border),
          //     ),
          //
          //     enabledBorder: OutlineInputBorder(
          //       borderRadius: BorderRadius.circular(8),
          //       borderSide: BorderSide(color: AppColors.border),
          //     ),
          //
          //     focusedBorder: OutlineInputBorder(
          //       borderRadius: BorderRadius.circular(8),
          //       borderSide: BorderSide(color: AppColors.border),
          //     ),
          //   ),
          // ),

          Container(
            padding: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Consumer<ItemProvider>(
              builder: (context, provider, child) {
                final List<Map<String, dynamic>> customers = provider.Approval_customers
                    .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
                    .toList();

                Map<String, dynamic>? selectedCustomer;

                if (selectedItem != null) {
                  try {
                    selectedCustomer = customers.firstWhere(
                          (e) => e["id"]?.toString() == selectedItem.toString(),
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
                      prefixIcon: Icons.person_outline_rounded,
                      dropdownMaxHeight: 350,
                      itemLabel: (customer) => customer["name"]?.toString() ?? "",
                      searchText: (customer) {
                        final name = customer["name"]?.toString() ?? "";
                        final mobile = customer["mobile"]?.toString() ??
                            customer["mobile_no"]?.toString() ??
                            customer["phone"]?.toString() ??
                            "";
                        final code = customer["code"]?.toString() ??
                            customer["customer_code"]?.toString() ??
                            "";
                        return "$name $mobile $code";
                      },
                      onChanged: (customer) => _setCustomerFilter(customer),
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
                    applyLocalFilter();
                    print("Apply Filter");
                  },
                  borderRadius: BorderRadius.circular(8),
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

  void showApprovalDialog(Map<String, dynamic> item) {
    // ============================================================
    // SAFE VALUE
    // ============================================================
    String val(dynamic v) {
      if (v == null) return "-";

      final String value = v.toString().trim();

      if (value.isEmpty || value.toLowerCase() == "null") {
        return "-";
      }

      return value;
    }

    // ============================================================
    // ITEMS
    // ============================================================
    final List<dynamic> items = item["items"] is List ? item["items"] : [];

    final int approvalId = int.tryParse(item["id"]?.toString() ?? "0") ?? 0;

    final String customerName = val(item["customer"]?["name"]);

    final String approvalNo = val(item["approval_no"] ?? item["voucher_no"]);

    // ============================================================
    // SHOW DIALOG
    // ============================================================
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.55),

      builder: (dialogContext) {
        final Size size = MediaQuery.of(dialogContext).size;

        final bool isTablet = size.width >= 600;

        /// 🔥 STATUS FILTER STATE
        String selectedStatusFilter = "All";

        return StatefulBuilder(
          builder: (context, setDialogState) {
            /// ============================================================
            /// STATUS NORMALIZE HELPER
            /// ============================================================
            String normalizeStatus(dynamic raw) {
              final String s = raw?.toString().trim().toLowerCase() ?? "";

              if (s.contains("partial")) return "Partial Returned";
              if (s.contains("return")) return "Partial Returned";
              if (s.contains("complete")) return "Completed";
              if (s.contains("sold")) return "Sold";
              if (s.contains("pending")) return "Pending";

              return "Pending"; // fallback
            }

            /// ============================================================
            /// FILTERED ITEMS
            /// ============================================================
            final List<dynamic> filteredItems = selectedStatusFilter == "All"
                ? items
                : items.where((rawData) {
              final Map<String, dynamic> data = rawData is Map
                  ? Map<String, dynamic>.from(rawData)
                  : <String, dynamic>{};

              final String itemStatus = normalizeStatus(
                data["status"] ?? data["item_status"],
              );

              return itemStatus == selectedStatusFilter;
            }).toList();

            return Dialog(
              elevation: 0,
              backgroundColor: Colors.transparent,

              insetPadding: EdgeInsets.symmetric(
                horizontal: isTablet ? 50 : 14,
                vertical: 24,
              ),

              child: Container(
                width: isTablet ? 720 : double.infinity,

                constraints: BoxConstraints(maxHeight: size.height * 0.90),

                decoration: BoxDecoration(
                  color: const Color(0xffF5F8FC),

                  borderRadius: BorderRadius.circular(14),

                  border: Border.all(
                    color: AppColors.gradientBlue.withOpacity(0.20),
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
                  borderRadius: BorderRadius.circular(14),

                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ========================================================
                      // PREMIUM BLUE HEADER
                      // ========================================================
                      Container(
                        width: double.infinity,

                        padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),

                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primaryDark, AppColors.gradientBlue],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),

                        child: Row(
                          children: [
                            // ==================================================
                            // HEADER ICON
                            // ==================================================
                            Container(
                              width: 40,
                              height: 40,

                              alignment: Alignment.center,

                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.13),

                                borderRadius: BorderRadius.circular(9),

                                border: Border.all(
                                  color: Colors.white.withOpacity(0.18),
                                ),
                              ),

                              child: const Icon(
                                Icons.fact_check_outlined,
                                color: Colors.white,
                                size: 21,
                              ),
                            ),

                            const SizedBox(width: 10),

                            // ==================================================
                            // TITLE
                            // ==================================================
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Approval Details",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),

                                  const SizedBox(height: 2),

                                  Text(
                                    approvalNo != "-" ? approvalNo : customerName,

                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,

                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.75),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // ==================================================
                            // PDF
                            // ==================================================
                            Material(
                              color: Colors.transparent,

                              child: InkWell(
                                onTap: () {
                                  openPdf(approvalId);
                                },

                                borderRadius: BorderRadius.circular(8),

                                child: Container(
                                  width: 38,
                                  height: 38,

                                  alignment: Alignment.center,

                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.12),

                                    borderRadius: BorderRadius.circular(8),

                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.15),
                                    ),
                                  ),

                                  child: const Icon(
                                    Icons.picture_as_pdf_rounded,
                                    color: Colors.white,
                                    size: 19,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 7),

                            // ==================================================
                            // CLOSE
                            // ==================================================
                            Material(
                              color: Colors.transparent,

                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(dialogContext);
                                },

                                borderRadius: BorderRadius.circular(8),

                                child: Container(
                                  width: 38,
                                  height: 38,

                                  alignment: Alignment.center,

                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.12),

                                    borderRadius: BorderRadius.circular(8),
                                  ),

                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white,
                                    size: 21,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ========================================================
                      // SCROLLABLE BODY
                      // ========================================================
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(12),

                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              // ==================================================
                              // CUSTOMER HERO CARD
                              // ==================================================
                              Container(
                                width: double.infinity,

                                padding: const EdgeInsets.all(12),

                                decoration: BoxDecoration(
                                  color: Colors.white,

                                  borderRadius: BorderRadius.circular(9),

                                  border: Border.all(color: AppColors.border),

                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.025),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),

                                child: Row(
                                  children: [
                                    // CUSTOMER ICON
                                    Container(
                                      width: 42,
                                      height: 42,

                                      alignment: Alignment.center,

                                      decoration: BoxDecoration(
                                        color: AppColors.gradientBlue.withOpacity(
                                          0.09,
                                        ),

                                        shape: BoxShape.circle,
                                      ),

                                      child: const Icon(
                                        Icons.person_outline_rounded,
                                        color: AppColors.gradientBlue,
                                        size: 21,
                                      ),
                                    ),

                                    const SizedBox(width: 10),

                                    // CUSTOMER NAME
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,

                                        children: [
                                          Text(
                                            customerName,

                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,

                                            style: const TextStyle(
                                              color: Colors.black87,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),

                                          const SizedBox(height: 3),

                                          Text(
                                            "Customer",
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // APPROVAL CHIP
                                    if (approvalNo != "-")
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 6,
                                        ),

                                        decoration: BoxDecoration(
                                          color: AppColors.gradientBlue.withOpacity(
                                            0.08,
                                          ),

                                          borderRadius: BorderRadius.circular(6),

                                          border: Border.all(
                                            color: AppColors.gradientBlue
                                                .withOpacity(0.15),
                                          ),
                                        ),

                                        child: Text(
                                          approvalNo,

                                          style: const TextStyle(
                                            color: AppColors.primaryDark,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 14),

                              // ==================================================
                              // APPROVAL SUMMARY TITLE
                              // ==================================================
                              _approvalSectionTitle(
                                icon: Icons.analytics_outlined,
                                title: "Approval Summary",
                              ),

                              const SizedBox(height: 7),

                              // ==================================================
                              // SUMMARY CARD
                              // ==================================================
                              Container(
                                width: double.infinity,

                                padding: const EdgeInsets.symmetric(vertical: 5),

                                decoration: BoxDecoration(
                                  color: Colors.white,

                                  borderRadius: BorderRadius.circular(9),

                                  border: Border.all(color: AppColors.border),
                                ),

                                child: Column(
                                  children: [
                                    // ============================================
                                    // DATE / GROSS WEIGHT
                                    // ============================================
                                    _erpRow(
                                      "Date",
                                      val(item["approval_date"]),
                                      "Gross Wt",
                                      val(item["totals"]?["gross_weight"]),
                                    ),

                                    Divider(height: 1, color: AppColors.border),

                                    // ============================================
                                    // NET WEIGHT / AMOUNT
                                    // ============================================
                                    _erpRow(
                                      "Net Wt",
                                      val(item["totals"]?["net_weight"]),
                                      "Amount",
                                      "₹ ${val(item["totals"]?["amount_all"])}",
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // ==================================================
                              // ITEMS TITLE
                              // ==================================================
                              Row(
                                children: [
                                  _approvalSectionTitle(
                                    icon: Icons.inventory_2_outlined,
                                    title: "Approval Items",
                                  ),

                                  const Spacer(),

                                  // ITEM COUNT
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),

                                    decoration: BoxDecoration(
                                      color: AppColors.gradientBlue.withOpacity(
                                        0.08,
                                      ),

                                      borderRadius: BorderRadius.circular(20),

                                      border: Border.all(
                                        color: AppColors.gradientBlue.withOpacity(
                                          0.12,
                                        ),
                                      ),
                                    ),

                                    child: Text(
                                      "${filteredItems.length} ${filteredItems.length == 1 ? "Item" : "Items"}",

                                      style: const TextStyle(
                                        color: AppColors.primaryDark,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),

                              // ==================================================
                              // STATUS FILTER DROPDOWN
                              // ==================================================
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedStatusFilter,
                                    isExpanded: true,
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: AppColors.primaryDark,
                                    ),
                                    dropdownColor: Colors.white,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: "All",
                                        child: Text("All Items"),
                                      ),
                                      DropdownMenuItem(
                                        value: "Pending",
                                        child: Text("Pending"),
                                      ),
                                      DropdownMenuItem(
                                        value: "Partial Returned",
                                        child: Text("Partial Returned"),
                                      ),
                                      DropdownMenuItem(
                                        value: "Completed",
                                        child: Text("Completed"),
                                      ),
                                      DropdownMenuItem(
                                        value: "Sold",
                                        child: Text("Sold"),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      if (value == null) return;

                                      setDialogState(() {
                                        selectedStatusFilter = value;
                                      });
                                    },
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),

                              // ==================================================
                              // EMPTY ITEMS
                              // ==================================================
                              if (filteredItems.isEmpty)
                                Container(
                                  width: double.infinity,

                                  padding: const EdgeInsets.symmetric(vertical: 28),

                                  decoration: BoxDecoration(
                                    color: Colors.white,

                                    borderRadius: BorderRadius.circular(9),

                                    border: Border.all(color: AppColors.border),
                                  ),

                                  child: Column(
                                    children: [
                                      Container(
                                        width: 46,
                                        height: 46,

                                        alignment: Alignment.center,

                                        decoration: BoxDecoration(
                                          color: AppColors.gradientBlue.withOpacity(
                                            0.07,
                                          ),
                                          shape: BoxShape.circle,
                                        ),

                                        child: const Icon(
                                          Icons.inventory_2_outlined,
                                          color: AppColors.gradientBlue,
                                          size: 23,
                                        ),
                                      ),

                                      const SizedBox(height: 8),

                                      Text(
                                        selectedStatusFilter == "All"
                                            ? "No approval items found"
                                            : "No $selectedStatusFilter items found",
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // ==================================================
                              // ITEM CARDS
                              // ==================================================
                              ...List.generate(filteredItems.length, (index) {
                                final dynamic rawData = filteredItems[index];

                                final Map<String, dynamic> data = rawData is Map
                                    ? Map<String, dynamic>.from(rawData)
                                    : <String, dynamic>{};

                                final String itemName = val(data["item_name"]);

                                final String qrCode = val(data["qr_code"]);

                                final String grossWeight = val(
                                  data["gross_weight"],
                                );

                                final String itemStatus = normalizeStatus(
                                  data["status"] ?? data["item_status"],
                                );

                                Color statusColor;

                                switch (itemStatus) {
                                  case "Pending":
                                    statusColor = Colors.orange;
                                    break;
                                  case "Partial Returned":
                                    statusColor = Colors.blue;
                                    break;
                                  case "Completed":
                                    statusColor = Colors.green;
                                    break;
                                  case "Sold":
                                    statusColor = Colors.purple;
                                    break;
                                  default:
                                    statusColor = Colors.grey;
                                }

                                return Container(
                                  width: double.infinity,

                                  margin: const EdgeInsets.only(bottom: 9),

                                  decoration: BoxDecoration(
                                    color: Colors.white,

                                    borderRadius: BorderRadius.circular(9),

                                    border: Border.all(color: AppColors.border),

                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.025),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),

                                  child: Column(
                                    children: [
                                      // ========================================
                                      // ITEM HEADER
                                      // ========================================
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 8,
                                        ),

                                        decoration: BoxDecoration(
                                          color: AppColors.gradientBlue.withOpacity(
                                            0.045,
                                          ),

                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(9),
                                            topRight: Radius.circular(9),
                                          ),
                                        ),

                                        child: Row(
                                          children: [
                                            // INDEX
                                            Container(
                                              width: 26,
                                              height: 26,

                                              alignment: Alignment.center,

                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    AppColors.primaryDark,
                                                    AppColors.gradientBlue,
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),

                                                borderRadius: BorderRadius.circular(
                                                  5,
                                                ),
                                              ),

                                              child: Text(
                                                "${index + 1}",

                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),

                                            const SizedBox(width: 8),

                                            // ITEM NAME
                                            Expanded(
                                              child: Text(
                                                itemName,

                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,

                                                style: const TextStyle(
                                                  color: Colors.black87,
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),

                                            const SizedBox(width: 8),

                                            // QR CODE CHIP
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),

                                              decoration: BoxDecoration(
                                                color: AppColors.gradientBlue
                                                    .withOpacity(0.08),

                                                borderRadius: BorderRadius.circular(
                                                  5,
                                                ),

                                                border: Border.all(
                                                  color: AppColors.gradientBlue
                                                      .withOpacity(0.12),
                                                ),
                                              ),

                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.qr_code_2_rounded,
                                                    size: 12,
                                                    color: AppColors.primaryDark,
                                                  ),

                                                  const SizedBox(width: 3),

                                                  Text(
                                                    qrCode,

                                                    style: const TextStyle(
                                                      color: AppColors.primaryDark,
                                                      fontSize: 9.5,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            const SizedBox(width: 6),

                                            // STATUS BADGE
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: statusColor.withOpacity(
                                                  0.12,
                                                ),
                                                borderRadius:
                                                BorderRadius.circular(5),
                                                border: Border.all(
                                                  color: statusColor.withOpacity(
                                                    0.30,
                                                  ),
                                                ),
                                              ),
                                              child: Text(
                                                itemStatus,
                                                style: TextStyle(
                                                  color: statusColor,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      Divider(height: 1, color: AppColors.border),

                                      // ========================================
                                      // ITEM DETAILS
                                      // ========================================
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 5,
                                        ),

                                        child: _erpRow(
                                          "Code",
                                          qrCode,
                                          "Gross Wt",
                                          grossWeight,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),

                              const SizedBox(height: 3),
                            ],
                          ),
                        ),
                      ),

                      // ========================================================
                      // BOTTOM CLOSE BUTTON
                      // ========================================================
                      Container(
                        width: double.infinity,

                        padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),

                        decoration: BoxDecoration(
                          color: Colors.white,

                          border: Border(top: BorderSide(color: AppColors.border)),
                        ),

                        child: SizedBox(
                          width: double.infinity,
                          height: 42,

                          child: Material(
                            color: Colors.transparent,

                            child: InkWell(
                              onTap: () {
                                Navigator.pop(dialogContext);
                              },

                              borderRadius: BorderRadius.circular(7),

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
                                      color: AppColors.gradientBlue.withOpacity(
                                        0.18,
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
                                      Icons.close_rounded,
                                      color: Colors.white,
                                      size: 17,
                                    ),

                                    SizedBox(width: 5),

                                    Text(
                                      "Close",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
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
              ),
            );
          },
        );
      },
    );
  }

  Future<void> getApprovalDetails(dynamic id) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final response = await ApiHelper().getRequestWithId(
      ApiConstants.Approval_dailog_list,
      id,
      responseType: ResponseType.bytes,
    );

    Navigator.pop(context);

    if (response != null && response.statusCode == 200) {
      /// 🔥 BYTES → STRING → JSON
      String jsonString = utf8.decode(response.data);
      final data = jsonDecode(jsonString);

      final item = data["data"] is List ? data["data"][0] : data["data"];

      showApprovalDialog(item);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to load details")));
    }
  }

  void applyLocalFilter() {
    if (fromDateController.text.isEmpty || toDateController.text.isEmpty) {
      setState(() {
        userlist = allItems;
      });

      return;
    }

    DateTime fromDate = parseSafeDate(fromDateController.text);

    DateTime toDate = parseSafeDate(toDateController.text);

    List filtered = allItems.where((user) {
      /// 🔥 USE MAIN created_at
      if (user["approval_date"] == null) {
        return false;
      }

      DateTime userDate = DateTime.parse(user["approval_date"]);

      return userDate.isAfter(fromDate.subtract(const Duration(days: 1))) &&
          userDate.isBefore(toDate.add(const Duration(days: 1)));
    }).toList();

    setState(() {
      userlist = filtered;
    });
  }

  DateTime parseSafeDate(String dateStr) {
    final parts = dateStr.split("-");

    String day = parts[0].padLeft(2, '0');
    String month = parts[1].padLeft(2, '0');
    String year = parts[2];

    return DateTime.parse("$year-$month-$day");
  }

  String formatDateForApi(String input) {
    if (input.isEmpty) return "";

    final parts = input.split("-");
    return "${parts[2]}-${parts[1]}-${parts[0]}";
  }

  String formatDate(String date) {
    DateTime parsedDate = DateTime.parse(date);

    String day = parsedDate.day.toString().padLeft(2, '0');
    String month = parsedDate.month.toString().padLeft(2, '0');
    String year = parsedDate.year.toString();

    return "$day-$month-$year";
  }

  Future<void> openApprovalPdf(String fromDate, String toDate) async {
    if (fromDate.trim().isEmpty || toDate.trim().isEmpty) {
      AppMessage.error(context, "Please select From and To date");
      return;
    }

    final fromDateApi = formatDate1(fromDate);
    final toDateApi = formatDate1(toDate);

    // 🔥 Branch mode → &management_branches[]=1&management_branches[]=2
    final String url = _br(
      "${ApiConstants.baseUrl}approvals/export/pdf"
          "?from_date=$fromDateApi"
          "&to_date=$toDateApi",
    );
    debugPrint("📤 APPROVAL PDF URL => $url");

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
  /// approvals/export/pdf?from_date=..&to_date=..&management_branches[]=1
  /// =========================================================

  /// "pdf" / "excel" chalu hoy tyare (bijo tap na thay)
  String? _exporting;

  Future<void> _export(String type) async {
    if (_exporting != null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _exporting = type);

    try {
      // List ma je date + branch chhe e j export ma pan
      // approvals/export/pdf | approvals/export/excel
      String base = "${ApiConstants.baseUrl}approvals/export/$type";
      if (fromDateController.text.trim().isNotEmpty &&
          toDateController.text.trim().isNotEmpty) {
        base += "?from_date=${formatDate1(fromDateController.text.trim())}"
            "&to_date=${formatDate1(toDateController.text.trim())}";
      }
      final String url = _br(base);
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
      final file = File("${dir.path}/Approval_$stamp.$ext");
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


  String formatDate1(String date) {
    final parts = date.split('-');

    return "${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}";
  }

  Widget _approvalSectionTitle({
    required IconData icon,
    required String title,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 27,
          height: 27,

          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.gradientBlue.withOpacity(0.09),
            borderRadius: BorderRadius.circular(6),

            border: Border.all(color: AppColors.gradientBlue.withOpacity(0.10)),
          ),

          child: Icon(icon, size: 15, color: AppColors.gradientBlue),
        ),

        const SizedBox(width: 7),

        Text(
          title,
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  void applyDateFilter() {
    List result = List.from(allItems);

    // 📅 Date filter
    if (fromDateController.text.isNotEmpty &&
        toDateController.text.isNotEmpty) {
      final fromDate = parseSafeDate(fromDateController.text);
      final toDate = parseSafeDate(toDateController.text);

      final startDate = DateTime(fromDate.year, fromDate.month, fromDate.day);
      final endDate =
      DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59);

      result = result.where((user) {
        final raw = user["approval_date"];
        if (raw == null) return false;

        final d = DateTime.parse(raw.toString()).toLocal();
        return !d.isBefore(startDate) && !d.isAfter(endDate);
      }).toList();
    }

    // 👤 Customer filter
    if (selectedUserId != null && selectedUserId!.isNotEmpty) {
      result = result.where((approval) {
        // 1) id thi match (jo API ma customer_id aave to)
        final customerId = approval["customer_id"]?.toString() ??
            approval["customer"]?["id"]?.toString();

        if (customerId != null && customerId.isNotEmpty) {
          return customerId == selectedUserId;
        }

        // 2) id na hoy to name thi match
        final name =
            approval["customer_name"]?.toString().trim().toLowerCase() ?? "";
        return name == (selectedCustomerName ?? "").trim().toLowerCase();
      }).toList();
    }

    setState(() {
      userlist = result;
    });
  }

  /// 🔥 Customer select / clear → filter ફરી લગાવો
  void _setCustomerFilter(Map<String, dynamic>? customer) {
    setState(() {
      selectedItem = customer?["id"]?.toString();
      selectedCompanyId = customer?["company_id"]?.toString();
      selectedUserId = customer?["id"]?.toString();
    });

    /// customer હોય → list filter, null → બધું દેખાશે
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

  /// Approval list farithi (branch mujab)
  Future<void> _reloadApprovals() async {
    setState(() => expandedApprovalId = null);
    await category();
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
      await _reloadApprovals();
    } finally {
      if (mounted) setState(() => branchReportLoading = false);
    }
  }

  /// Branch report bandh kari ne potani company ni gallery
  Future<void> clearBranchReport() async {
    setState(() => appliedCompanyIds = []);
    await _reloadApprovals();
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
                    "Select one or more branches to see their approvals.",
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
                              "Showing approvals of "
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
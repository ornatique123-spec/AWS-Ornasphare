import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pecifician_sysytem/User/CreteUserScreen.dart';
import 'package:pecifician_sysytem/Vacuum/Tree_Cutting_Office/AddTreeCuttingOffice.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Api_Constant/ApiConstants.dart';
import '../../Api_Constant/api_helper.dart';
import '../../Dashboard/HomeScreen.dart';
import '../../Extra/AppColors.dart';
import '../../Extra/AppMessage.dart';
import '../../Extra/ItemProvider.dart';
import '../../Extra/PermissionDeniedWidget.dart';
import 'package:intl/intl.dart';

import '../../Extra/PremiumSearchableDropdown.dart';
import '../../Offline Data/OfflineValueSave.dart';
import '../../Offline Data/offline_api_helper.dart';
// 🏢 Branch Reports (Sale Summary jevu j)
import 'package:pecifician_sysytem/Settings/BranchManagementScreen.dart'
    show BranchApi, Company, BranchTypeX;
import 'package:pecifician_sysytem/Reports/BranchAccess.dart';

class Treecuttingoffice extends StatefulWidget {
  const Treecuttingoffice({super.key});

  @override
  State<Treecuttingoffice> createState() => _TreecuttingofficeState();
}

class _TreecuttingofficeState extends State<Treecuttingoffice> {
  TextEditingController searchController = TextEditingController();
  TextEditingController fromDateController = TextEditingController();
  TextEditingController toDateController = TextEditingController();
  Future<void> _selectDate(TextEditingController controller) async {
    DateTime initial = DateTime.now();
    try {
      if (controller.text.trim().isNotEmpty) {
        initial = DateFormat("dd-MM-yyyy").parse(controller.text.trim());
      }
    } catch (_) {}

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
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

  final Map<String, TextEditingController> lossControllers = {};
  final Map<String, TextEditingController> otherMetalControllers = {};
  String? selectedRole;
  List allUsers = []; // 🔥 original data store
  // ============================================================
  // 🔥 BRANCH REPORTS (Sale Summary jevu j)
  // ============================================================

  /// Branch API mathi aavti companies (main + branches)
  List<Company> branchCompanies = [];

  /// Dropdown ma select kareli (haju apply nathi thai)
  Set<int> selectedCompanyIds = {};

  /// "View Report" dabavya pachhi apply thayeli
  List<int> appliedCompanyIds = [];

  /// Branch report chalu chhe? (true hoy to report_branches jay)
  bool get _branchMode => appliedCompanyIds.isNotEmpty;

  bool branchesLoading = false;
  bool canViewBranches = false;
  bool branchExpanded = true;
  bool branchReportLoading = false;

  /// Apply thayeli branches → management_branches[]=1&management_branches[]=2
  String get _branchQuery => appliedCompanyIds
      .map((id) => "management_branches[]=$id")
      .join("&");

  /// tree_cutting_office?management_branches[]=1&management_branches[]=2 (branch mode only)
  String _br(String url) => _branchMode
      ? "$url${url.contains('?') ? '&' : '?'}$_branchQuery"
      : url;

  /// tree office → branch name (company_id / branch / company_name)
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




  /// 🔍 Search pan worker + date filter sathe j lagu thay
  void searchUser(String value) => applyAllFilters();

  List userlist = [];
  bool isSearchOpen = false;
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

  double totalIssueSilverWt = 0.0;

  final Offlinevaluesave _offlineDraft = Offlinevaluesave();

  Map<String, TextEditingController> buchNoControllers = {};
  Map<String, TextEditingController> receiveTreeWtControllers = {};
  Map<String, TextEditingController> treeWtControllers = {};
  Map<String, TextEditingController> bhukoControllers = {};
  Map<String, TextEditingController> remainingTreeWtControllers = {};
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    Future.microtask(() {
      Provider.of<ItemProvider>(context, listen: false).loadJobWorker();
    });
    loadPermissions();
    DateTime today = DateTime.now();
    DateTime sevenDaysAgo = today.subtract(const Duration(days: 7));

    String formatDate(DateTime date) {
      return "${date.day.toString().padLeft(2, '0')}-"
          "${date.month.toString().padLeft(2, '0')}-"
          "${date.year}";
    }

    fromDateController.text = formatDate(sevenDaysAgo);
    toDateController.text = formatDate(today);

    String from = DateFormat(
      "yyyy-MM-dd",
    ).format(DateFormat("dd-MM-yyyy").parse(fromDateController.text));

    String to = DateFormat(
      "yyyy-MM-dd",
    ).format(DateFormat("dd-MM-yyyy").parse(toDateController.text));

    category(fromDate: from, toDate: to);
    _loadBranches();
  }

  @override
  Widget build(BuildContext context) {
    if (!(hasPermission("tree-cutting-office-view") ||
        hasPermission("tree-cutting-office-manage"))) {
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

        Navigator.pop(context,true);
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false, // 🔥 IMPORTANT
        backgroundColor: AppColors.white,
        body: Stack(
          children: [
            /// ✅ Main Content
            Column(
              children: [
                /// IMPORTANT: top padding space leave karvu (AppBar mate)
                SizedBox(height: MediaQuery.of(context).padding.top + 40),

                // 🔥 Branch Reports tab sauthi upar
                _buildBranchCard(),

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

                /// 🔥 Dynamic Bottom Section
                /// 🔥 Fully Dynamic List
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
                      return buildUserCard(userlist[index], index);
                    },
                  ),
                ),
                SizedBox(height: 10,)
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
                child: Row(
                  children: [
                    /// ✅ LEFT BACK ICON
                    InkWell(
                      onTap: () {
                        Navigator.pop(context, true);
                      },
                      child: Container(
                        padding: EdgeInsets.all(isMobile ? 6 : 8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark,
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

                    const SizedBox(width: 10),

                    /// ✅ CENTER TITLE / SEARCH FIELD
                    Expanded(
                      child: isSearchOpen
                          ? TextField(
                        controller: searchController,
                        autofocus: false,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: "Search voucher, worker, process...",
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                        onChanged: (value) {
                          searchUser(value);
                        },
                      )
                          : const Text(
                        "Tree Cutting Office",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    /// ✅ EXCEL + PDF (search khulyu hoy tyare jagya mate chhupay)
                    if (!isSearchOpen) ...[
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
                      const SizedBox(width: 8),
                    ],

                    /// ✅ RIGHT SEARCH / CLOSE ICON
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (isSearchOpen) {
                            isSearchOpen = false;
                            searchController.clear();
                          } else {
                            isSearchOpen = true;
                          }
                        });
                        if (!isSearchOpen) applyAllFilters();
                      },
                      child: Container(
                        padding: EdgeInsets.all(isMobile ? 6 : 8),
                        decoration: BoxDecoration(
                          color: isSearchOpen
                              ? Colors.grey.shade300
                              : AppColors.primaryDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Icon(
                          isSearchOpen ? Icons.close : Icons.search,
                          color: isSearchOpen ? Colors.black87 : Colors.white,
                          size: isMobile ? 20 : 24,
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
  int? expandedTreeOfficeId;
  Widget buildUserCard(Map user, int index) {
    final size = MediaQuery.of(context).size;
    final bool isTablet = size.width >= 600;

    /// =========================================================
    /// UNIQUE ID
    /// =========================================================
    final int id =
        int.tryParse(user["id"]?.toString() ?? "0") ?? 0;

    final bool isExpanded = expandedTreeOfficeId == id;

    /// =========================================================
    /// DATA
    /// =========================================================
    final String voucherNo =
        user["voucher_no"]?.toString() ?? "-";

    final String voucherDate =
        user["voucher_date"]?.toString() ?? "";

    final String processName =
        user["process_name"]?.toString() ?? "-";

    final String workerName =
        user["worker_name"]?.toString() ?? "-";

    final String officeUsed =
        user["office_used"]?.toString() ?? "-";

    final String treeWt =
        user["tree_wt_total"]?.toString() ?? "-";

    final String officeCutWt =
        user["office_cut_wt_total"]?.toString() ?? "-";

    final String pendingWt =
        user["remaining_tree_wt_total"]?.toString() ?? "-";

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

            /// =====================================================
            /// HEADER - ALWAYS VISIBLE
            /// =====================================================
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 14 : 10,
                vertical: isTablet ? 12 : 10,
              ),

              child: Row(
                children: [

                  /// =================================================
                  /// INDEX
                  /// =================================================
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

                  /// =================================================
                  /// VOUCHER + TREE WT / PENDING WT
                  /// =================================================
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        /// Voucher No
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

                        const SizedBox(height: 4),

                        /// Tree Wt + Pending Wt
                        Row(
                          children: [

                            Icon(
                              Icons.scale_outlined,
                              size: 13,
                              color: Colors.grey.shade600,
                            ),

                            const SizedBox(width: 4),

                            Text(
                              "Tree: $treeWt",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const SizedBox(width: 8),

                            Container(
                              width: 1,
                              height: 12,
                              color: Colors.grey.shade300,
                            ),

                            const SizedBox(width: 8),

                            Flexible(
                              child: Text(
                                "Pending: $pendingWt",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        /// 🏢 BRANCH (branch mode)
                        if (_branchMode && _branchOf(user).isNotEmpty) ...[
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
                                    _branchOf(user),
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

                  /// =================================================
                  /// PDF
                  /// =================================================
                  if (hasPermission("tree-cutting-office-view") ||
                      hasPermission("tree-cutting-office-manage")) ...[
                    pdfBtn(() {
                      openPdf(user["id"]);
                    }),

                    SizedBox(
                      width: isTablet ? 8 : 5,
                    ),
                  ],

                  /// =================================================
                  /// EDIT
                  /// =================================================
                  if (hasPermission("tree-cutting-office-edit") ||
                      hasPermission("tree-cutting-office-manage")) ...[
                    premiumIconBtn(
                      Icons.edit_rounded,
                      Colors.blue,
                      onTap: () async {
                        await getApprovalDetails(
                          int.parse(
                            user["id"].toString(),
                          ),
                        );
                      },
                    ),

                    SizedBox(
                      width: isTablet ? 8 : 5,
                    ),
                  ],

                  /// =================================================
                  /// EXPAND BUTTON
                  /// =================================================
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (expandedTreeOfficeId == id) {
                          /// Same card click -> Close
                          expandedTreeOfficeId = null;
                        } else {
                          /// New card open
                          /// Previous automatically close
                          expandedTreeOfficeId = id;
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

            /// =====================================================
            /// EXPANDED SECTION
            /// =====================================================
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),

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

                    /// Divider
                    Divider(
                      height: 1,
                      color: AppColors.border,
                    ),

                    const SizedBox(height: 10),

                    /// =================================================
                    /// ERP DATA
                    /// =================================================
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(6),

                        border: Border.all(
                          color: AppColors.border,
                          width: 1.2,
                        ),
                      ),

                      child: Column(
                        children: [

                          /// =============================================
                          /// DATE / PROCESS
                          /// =============================================
                          _erpRow(
                            "Date",
                            voucherDate.isNotEmpty
                                ? formatDate(voucherDate)
                                : "-",
                            "Process",
                            processName,
                          ),

                          Divider(
                            height: 1,
                            color: AppColors.border,
                          ),

                          /// =============================================
                          /// WORKER / OFFICE USED
                          /// =============================================
                          _erpRow(
                            "W Name",
                            workerName,
                            "Office Used",
                            officeUsed,
                          ),

                          Divider(
                            height: 1,
                            color: AppColors.border,
                          ),

                          /// =============================================
                          /// TREE WT / OFFICE CUT WT
                          /// =============================================
                          _erpRow(
                            "Tree Wt",
                            treeWt,
                            "Office Cut Wt",
                            officeCutWt,
                          ),

                          Divider(
                            height: 1,
                            color: AppColors.border,
                          ),

                          /// =============================================
                          /// PENDING WT
                          /// =============================================
                          _erpRow(
                            "Pending Wt",
                            pendingWt,
                            "",
                            "",
                          ),
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

  Future<void> category({String? fromDate, String? toDate}) async {
    String url = ApiConstants.tree_cutting_office;

    if (fromDate != null &&
        toDate != null &&
        fromDate.isNotEmpty &&
        toDate.isNotEmpty) {
      url += "?from_date=$fromDate&to_date=$toDate";
    }

    // 🏢 Branch mode → &management_branches[]=1&management_branches[]=2
    url = _br(url);

    final response = await ApiHelper().getRequest(url);

    print("tree office API URL: $url");
    print("tree office Raw Response: ${response.toString()}");

    if (!mounted) return;

    if (response != null && response.statusCode == 200) {
      final data = response.data;

      // ✅ success check
      final List categories = data['data'] ?? [];

      /// 🔥 SUCCESS MESSAGE (OPTIONAL)
      if (data["success"] == true) {
        AppMessage.success(
          context,
          data["message"] ?? "Data Loaded Successfully",
        );
      }
      setState(() {
        userlist = categories;
        allUsers = categories; // 🔥 store original
      });

      applyDateFilter();
      print("✅ Total user: ${userlist.length}");
    } else {
      setState(() {
        userlist = [];
        allUsers = [];
      });
      print("❌ tree office list API failed");
      AppMessage.error(context, "Failed to load data");
    }
  }

  /// =========================================================
  /// 📄 EXPORT — PDF / EXCEL (getPdfRequest → bytes)
  /// tree_cutting_office?management_branches[]=1&...&from_date=..&to_date=..&export=pdf
  /// =========================================================

  static String get _exportUrl => ApiConstants.tree_cutting_office;

  /// "pdf" / "excel" chalu hoy tyare (bijo tap na thay)
  String? _exporting;

  Future<void> _export(String type) async {
    if (_exporting != null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _exporting = type);

    try {
      // List ma je date range chhe e j export ma pan
      final r = _apiRange();
      String base = _exportUrl;
      if (r.from != null && r.to != null) {
        base += "?from_date=${r.from}&to_date=${r.to}";
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
      final file = File("${dir.path}/Tree_Cutting_Office_$stamp.$ext");
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
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.all(isMobile ? 6 : 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
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

  /// =========================================================
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
  ({String? from, String? to}) _apiRange() {
    String? conv(String s) {
      try {
        if (s.trim().isEmpty) return null;
        return DateFormat("yyyy-MM-dd")
            .format(DateFormat("dd-MM-yyyy").parse(s.trim()));
      } catch (_) {
        return null;
      }
    }

    return (from: conv(fromDateController.text), to: conv(toDateController.text));
  }

  /// Tree office list farithi (branch + date mujab)
  Future<void> _reloadTreeOffice() async {
    setState(() {
      expandedTreeOfficeId = null;
      isSearchOpen = false;
      searchController.clear();
    });
    final r = _apiRange();
    await category(fromDate: r.from, toDate: r.to);
  }

  /// 🔥 VIEW — fakt select kareli branches
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
      await _reloadTreeOffice();
    } finally {
      if (mounted) setState(() => branchReportLoading = false);
    }
  }

  /// Branch report bandh kari ne potani company ni gallery
  Future<void> clearBranchReport() async {
    setState(() => appliedCompanyIds = []);
    await _reloadTreeOffice();
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
                    "Select one or more branches to see their tree cutting office.",
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
                              "Showing tree cutting office of "
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
          Consumer<ItemProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              /// ============================================================
              /// 🔥 ONLY ACTIVE WORKERS
              /// ============================================================
              final List<Map<String, dynamic>> activeWorkers =
              provider.Job_worker.whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .where((e) {
                final dynamic v = e["is_active"] ?? e["is_used"];
                return v == true ||
                    v == 1 ||
                    v.toString().trim().toLowerCase() == "true" ||
                    v.toString().trim() == "1";
              })
                  .toList();

              /// CURRENT SELECTED WORKER FIND (String id -> Map)
              Map<String, dynamic>? selectedWorkerData;

              if (selectedRole != null && selectedRole!.isNotEmpty) {
                for (final data in activeWorkers) {
                  if (data["id"]?.toString() == selectedRole) {
                    selectedWorkerData = data;
                    break;
                  }
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dropdownLabel("Worker", required: false),
                  Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      PremiumSearchableDropdown<Map<String, dynamic>>(
                        label: "", // 🔥 label upar bahar chhe
                        hint: "Select Worker",
                        items: activeWorkers,
                        value: selectedWorkerData,
                        prefixIcon: Icons.person_outline,

                        /// DISPLAY
                        itemLabel: (data) {
                          return data["name"]?.toString() ??
                              data["worker_name"]?.toString() ??
                              "-";
                        },

                        /// SEARCH
                        searchText: (data) {
                          return [
                            data["name"]?.toString() ?? "",
                            data["worker_name"]?.toString() ?? "",
                            data["mobile_no"]?.toString() ?? "",
                            data["id"]?.toString() ?? "",
                          ].join(" ");
                        },

                        /// ON CHANGED
                        onChanged: (selectedData) {
                          selectedRole = selectedData?["id"]?.toString();

                          /// 🔥 Worker + Date range banne saathe apply
                          applyAllFilters();
                        },
                      ),

                      /// ❌ CLEAR — worker nikle, date filter chalu rahe
                      if (selectedWorkerData != null)
                        _clearIcon(
                              () {
                            setState(() => selectedRole = null);
                            applyAllFilters();
                          },
                          right: 40,
                        ),
                    ],
                  ),
                ],
              );
            },
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
                    FocusManager.instance.primaryFocus?.unfocus();
                    final r = _apiRange();

                    if (r.from != null &&
                        r.to != null &&
                        r.from!.compareTo(r.to!) > 0) {
                      AppMessage.error(
                          context, "From Date cannot be greater than To Date");
                      return;
                    }

                    // ✅ Date khali hoy to crash nahi — badha records
                    category(fromDate: r.from, toDate: r.to);
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

              /// CLEAR
              Expanded(
                child: InkWell(
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    searchController.clear();
                    fromDateController.clear();
                    toDateController.clear();

                    setState(() {
                      selectedRole = null;
                      isSearchOpen = false;
                      expandedTreeOfficeId = null;
                    });

                    // Date vagar badha records farithi
                    category();
                  },

                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Center(
                      child: Text(
                        "Clear",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
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
    );
  }

  void applyDateFilter() {
    applyAllFilters();
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
                  flex: 3,
                  child: Text(
                    t1,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black, // ✅ FIX
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    v1,
                    style: const TextStyle(
                      fontSize: 12,
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
                      fontSize: 12,
                      overflow: TextOverflow.ellipsis,
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
    return date.split("T")[0].split("-").reversed.join("-");
  }

  DateTime _convertToDate(String input) {
    try {
      return DateFormat("dd-MM-yyyy").parse(input.trim());
    } catch (_) {
      return DateTime.now();
    }
  }

  Widget twoFieldRow(Widget left, Widget right) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: left),

          // const SizedBox(width: 10),
          //
          // Expanded(child: right),
        ],
      ),
    );
  }

  Widget _buildDropdown(
      BuildContext context,
      String label,
      List items, // 🔥 changed
      String? value,
      Function(String?) onChanged, {
        bool isRequired = false, // 🔥 ADD THIS
      }) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final width = MediaQuery.of(context).size.width;

    final isTablet = width >= 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// 🔹 LABEL WITH *
        RichText(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontSize: isTablet ? 14 : 13,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
            children: [
              if (isRequired)
                TextSpan(
                  text: " *",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: screenHeight * 0.01),

        Container(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.border, width: 1.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black),
              dropdownColor: Colors.white, // 🔥 ADD THIS
              /// 🔥 Hint
              hint: Text(
                "Select $label",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: isTablet ? 14 : 13,
                ),
              ),

              /// 🔥 Selected Value Style
              style: TextStyle(
                color: Colors.black,
                fontSize: isTablet ? 14 : 13,
                fontWeight: FontWeight.w500,
              ),
              items: items.map<DropdownMenuItem<String>>((item) {
                return DropdownMenuItem<String>(
                  value: item["id"].toString(),
                  child: Text(item["name"] ?? ""),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
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
          children: const [
            Icon(Icons.picture_as_pdf, color: Colors.white, size: 18),
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

  Future<void> openPdf(int id) async {
    final response = await ApiHelper().getRequestWithId(
      ApiConstants.tree_cutting_office_pdf,
      id,
      responseType: ResponseType.bytes,
    );

    if (!mounted) return;

    final dynamic raw = response?.data;
    if (response != null &&
        response.statusCode == 200 &&
        raw is List<int> &&
        raw.isNotEmpty &&
        raw.first != 0x7B /* { = JSON error */) {
      final dir = await getTemporaryDirectory();

      final file = File("${dir.path}/Tree-Cutting-Office$id.pdf");

      await file.writeAsBytes(raw, flush: true);

      OpenFile.open(file.path);
    } else {
      AppMessage.error(context, _exportError(raw) ?? "PDF Download Failed");
    }
  }

  Widget _infoCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: 18),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),

                const SizedBox(height: 3),

                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isLoadingApproval = false; // 🔥 class-level flag

  Future<void> getApprovalDetails(int id) async {
    if (_isLoadingApproval) return;

    _isLoadingApproval = true;

    try {
      final response = await ApiHelper().getRequestWithId(
        ApiConstants.tree_cutting_office,
        id,
      );

      if (response == null ||
          response.statusCode != 200 ||
          response.data is! Map ||
          response.data["success"] != true) {
        if (mounted) AppMessage.error(context, "Failed to load details");
        return;
      }

      /// ============================================
      /// API DATA
      /// ============================================
      final Map<String, dynamic> data =
      Map<String, dynamic>.from(
        response.data["data"],
      );

      /// ============================================
      /// API ITEMS
      /// ============================================
      final List<Map<String, dynamic>> items =
      (data["items"] as List? ?? [])
          .map(
            (e) => Map<String, dynamic>.from(e),
      )
          .toList();

      /// ============================================
      /// PREPARE API ITEMS
      /// ============================================
      for (int index = 0; index < items.length; index++) {
        final item = items[index];

        /// ==========================================
        /// UNIQUE ROW KEY
        /// ==========================================
        final String key =
        item["row_key"]?.toString().trim().isNotEmpty == true
            ? item["row_key"].toString().trim()
            : item["vacuum_voucher_item_id"] != null
            ? item["vacuum_voucher_item_id"].toString()
            : item["casting_release_item_id"] != null
            ? "custom_${item["casting_release_item_id"]}"
            : "item_$index";

        item["_local_key"] = key;

        /// ==========================================
        /// CHECKBOX
        /// ==========================================
        final String? groupKey =
        item["issue_group_key"]?.toString();

        if (groupKey != null &&
            groupKey.isNotEmpty &&
            groupKey != "null") {
          item["group_id"] = groupKey;
          item["selected"] = true;
        } else {
          item["group_id"] = null;
          item["selected"] = false;
        }

        /// ==========================================
        /// API VALUES
        ///
        /// Important:
        /// API values ne change nathi karvana.
        /// ==========================================
        item["buch_no"] =
            item["buch_no"]?.toString() ?? "";

        item["tree_wt"] =
            item["tree_wt"]?.toString() ?? "0.000";

        item["tree_bhuko"] =
            item["tree_bhuko"]?.toString() ?? "";

        item["office_cut_wt"] =
            item["office_cut_wt"]?.toString() ?? "";

        item["remaining_tree_wt"] =
            item["remaining_tree_wt"]?.toString() ??
                item["tree_wt"]?.toString() ??
                "0.000";

        item["checked"] =
            item["in_bhati"] ?? false;

        item["check_time"] =
            item["checked_at_view"] ?? "-";
      }

      /// ============================================
      /// DEBUG API DATA BEFORE DRAFT
      /// ============================================
      debugPrint(
        "========== API ITEMS BEFORE DRAFT ==========",
      );

      for (final item in items) {
        debugPrint(
          "KEY=${item["_local_key"]} | "
              "BUCH=${item["buch_no"]} | "
              "TREE=${item["tree_wt"]} | "
              "BHUKO=${item["tree_bhuko"]} | "
              "REMAIN=${item["remaining_tree_wt"]}",
        );
      }

      /// ============================================
      /// LOAD OFFLINE DRAFT
      /// ============================================
      final draftItems =
      await _offlineDraft.loadCastingDraft(id);

      if (draftItems != null && draftItems.isNotEmpty) {
        for (final draft in draftItems) {
          /// ========================================
          /// DRAFT UNIQUE KEY
          /// ========================================
          String draftKey = "";

          if (draft["row_key"] != null &&
              draft["row_key"]
                  .toString()
                  .trim()
                  .isNotEmpty) {
            draftKey =
                draft["row_key"].toString().trim();
          } else if (draft["_local_key"] != null &&
              draft["_local_key"]
                  .toString()
                  .trim()
                  .isNotEmpty) {
            draftKey =
                draft["_local_key"].toString().trim();
          } else if (draft["vacuum_voucher_item_id"] !=
              null) {
            draftKey =
                draft["vacuum_voucher_item_id"]
                    .toString();
          } else if (draft["casting_release_item_id"] !=
              null) {
            draftKey =
            "custom_${draft["casting_release_item_id"]}";
          }

          /// Invalid old draft
          if (draftKey.isEmpty ||
              draftKey == "null") {
            continue;
          }

          /// ========================================
          /// FIND EXACT ROW
          /// ========================================
          final int matchIndex =
          items.indexWhere(
                (item) =>
            item["_local_key"]?.toString() ==
                draftKey,
          );

          if (matchIndex != -1) {
            /// ======================================
            /// IMPORTANT
            ///
            /// API identity values overwrite na
            /// karva.
            ///
            /// Draft mathi only editable values
            /// restore karvana.
            /// ======================================

            final currentItem = items[matchIndex];

            /// Buch only locally editable custom
            if (currentItem["is_custom"] == true &&
                draft["buch_no"] != null) {
              currentItem["buch_no"] =
              draft["buch_no"];
            }

            /// Tree Bhuko
            if (draft["tree_bhuko"] != null) {
              currentItem["tree_bhuko"] =
              draft["tree_bhuko"];
            }

            /// Office Cut
            if (draft["office_cut_wt"] != null) {
              currentItem["office_cut_wt"] =
              draft["office_cut_wt"];
            }

            /// Remaining
            if (draft["remaining_tree_wt"] != null) {
              currentItem["remaining_tree_wt"] =
              draft["remaining_tree_wt"];
            }

            /// Selection
            if (draft["selected"] != null) {
              currentItem["selected"] =
              draft["selected"];
            }

            if (draft["group_id"] != null) {
              currentItem["group_id"] =
              draft["group_id"];
            }
          }

          /// ========================================
          /// LOCALLY CREATED CUSTOM ROW
          /// ========================================
          else {
            final bool isLocalCustom =
                draft["is_custom"] == true &&
                    draftKey.startsWith("custom_") &&
                    draft["casting_release_item_id"] ==
                        null;

            if (isLocalCustom) {
              final newItem =
              Map<String, dynamic>.from(
                draft,
              );

              newItem["_local_key"] = draftKey;

              items.add(newItem);
            }
          }
        }
      }

      /// ============================================
      /// FINAL DEBUG
      /// ============================================
      debugPrint(
        "========== FINAL ITEMS ==========",
      );

      for (final item in items) {
        debugPrint(
          "KEY=${item["_local_key"]} | "
              "BUCH=${item["buch_no"]} | "
              "TREE=${item["tree_wt"]} | "
              "BHUKO=${item["tree_bhuko"]} | "
              "REMAIN=${item["remaining_tree_wt"]}",
        );
      }

      if (!mounted) return;

      /// ============================================
      /// OPEN SCREEN
      /// ============================================
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              Addtreecuttingoffice(
                voucher: data,
                items: items,
              ),
        ),
      );

      if (!mounted) return;

      if (result == true) {
        // ✅ screen ni date range + branch sathe refresh
        final r = _apiRange();
        await category(fromDate: r.from, toDate: r.to);
      }
    } catch (e, stackTrace) {
      debugPrint(
        "❌ getApprovalDetails Error: $e",
      );

      debugPrint(
        stackTrace.toString(),
      );
    } finally {
      _isLoadingApproval = false;
    }
  }

  void showCastingDialog1(
      BuildContext context,
      Map<String, dynamic> voucher,
      List<Map<String, dynamic>> items,
      ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xffF8F5F0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          insetPadding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(dialogContext).size.width < 600 ? 8 : 16,
            vertical: MediaQuery.of(dialogContext).size.width < 600 ? 12 : 24,
          ),
          child: StatefulBuilder(
            builder: (context, setStateDialog) {
              final screenWidth = MediaQuery.of(context).size.width;
              final screenHeight = MediaQuery.of(context).size.height;

              final bool isMobile = screenWidth < 600;
              final bool isTablet = screenWidth >= 600 && screenWidth < 1000;

              final double baseFont = isMobile ? 12 : 13;
              final double headerFont = isMobile ? 11 : 12;

              final double dialogWidth = isMobile
                  ? screenWidth
                  : isTablet
                  ? screenWidth * 0.95
                  : screenWidth * 0.85;

              final double dialogHeight = isMobile
                  ? screenHeight * 0.92
                  : screenHeight * 0.85;

              /*
             * Column widths.
             *
             * Mobile width નાનું હશે તો horizontal scroll આવશે.
             * Tablet/Desktop પર available width પ્રમાણે table stretch થશે.
             */
              final Map<String, double> colBase = {
                "sr": 48,
                "check": 50,
                "buch": 75,
                "treeWt": 105,
                "treeBhuko": 105,
                "remaining": 120,
              };

              final double baseTotal = colBase.values.fold(
                0.0,
                    (sum, width) => sum + width,
              );

              /*
             * Live totals.
             */
              final double totalTreeWt = items.fold<double>(
                0.0,
                    (sum, item) =>
                sum +
                    (double.tryParse(item["tree_wt"]?.toString() ?? "0") ?? 0),
              );

              final double totalTreeBhuko = items.fold<double>(
                0.0,
                    (sum, item) =>
                sum +
                    (double.tryParse(item["tree_bhuko"]?.toString() ?? "0") ??
                        0),
              );

              final double totalRemainingTreeWt = items.fold<double>(
                0.0,
                    (sum, item) =>
                sum +
                    (double.tryParse(
                      item["remaining_tree_wt"]?.toString() ?? "0",
                    ) ??
                        0),
              );

              return SizedBox(
                width: dialogWidth,
                height: dialogHeight,
                child: Container(
                  padding: EdgeInsets.all(isMobile ? 10 : 14),
                  child: Column(
                    children: [
                      /*
                     * Scrollable content.
                     */
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              /*
                             * Header.
                             */
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final bool veryNarrow =
                                      constraints.maxWidth < 320;

                                  final Widget actionRow = Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      pdfBtn(() {
                                        openPdf(voucher["id"]);
                                      }),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () {
                                          Navigator.pop(dialogContext);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: const Text(
                                            "Back",
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );

                                  final Widget titleText = Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Tree Cutting Office",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: isMobile ? 14 : 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        "${voucher["voucher_no"] ?? "-"} • "
                                            "${voucher["voucher_date"] ?? "-"}",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: isMobile ? 10 : 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  );

                                  if (veryNarrow) {
                                    return Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        titleText,
                                        const SizedBox(height: 8),
                                        actionRow,
                                      ],
                                    );
                                  }

                                  return Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.center,
                                    children: [
                                      Expanded(child: titleText),
                                      const SizedBox(width: 8),
                                      actionRow,
                                    ],
                                  );
                                },
                              ),

                              SizedBox(height: isMobile ? 14 : 20),

                              /*
                             * Information cards.
                             */
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _infoCard(
                                          title: "Process",
                                          value: voucher["process_name"] ?? "-",
                                          icon: Icons.settings,
                                          color: Colors.blue,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _infoCard(
                                          title: "Worker",
                                          value: voucher["worker_name"] ?? "-",
                                          icon: Icons.person,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _infoCard(
                                          title: "Created Date",
                                          value:
                                          voucher["created_at_view"] ??
                                              voucher["voucher_date"] ??
                                              "-",
                                          icon: Icons.calendar_today,
                                          color: Colors.green,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _infoCard(
                                          title: "Total Pcs",
                                          value: "${voucher["total_pcs"] ?? 0}",
                                          icon: Icons.inventory_2,
                                          color: Colors.purple,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              SizedBox(height: isMobile ? 8 : 10),

                              /*
                             * Custom item button.
                             */
                              Align(
                                alignment: Alignment.centerRight,
                                child: InkWell(
                                  onTap: () {
                                    final groupId = DateTime.now()
                                        .millisecondsSinceEpoch
                                        .toString();


                                    setStateDialog(() {
                                      for (var item in items) {
                                        if (item["selected"] == true &&
                                            item["group_id"] == null) {
                                          item["group_id"] = groupId;
                                        }
                                      }
                                    });

                                    _offlineDraft.saveCastingDraft(
                                      voucher["id"],
                                      items,
                                    );

                                  },
                                  child: Container(
                                    width: 150,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.primaryDark.withOpacity(
                                            0.7,
                                          ),
                                          AppColors.secondaryDark.withOpacity(
                                            0.7,
                                          ),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        SizedBox(width: 5),
                                        Text(
                                          "Apply to Checked",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(height: isMobile ? 8 : 10),

                              /*
                             * Main responsive table.
                             */
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final double availableWidth =
                                      constraints.maxWidth;

                                  final bool needsScroll =
                                      baseTotal > availableWidth;

                                  final double stretchFactor = needsScroll
                                      ? 1.0
                                      : availableWidth / baseTotal;

                                  final double sSr =
                                      colBase["sr"]! * stretchFactor;
                                  final double sCheck =
                                      colBase["check"]! * stretchFactor;

                                  final double sBuch =
                                      colBase["buch"]! * stretchFactor;

                                  final double sTreeWt =
                                      colBase["treeWt"]! * stretchFactor;

                                  final double sTreeBhuko =
                                      colBase["treeBhuko"]! * stretchFactor;

                                  final double sRemaining =
                                      (colBase["remaining"]! * stretchFactor) - 2;

                                  final double effectiveWidth = needsScroll
                                      ? baseTotal
                                      : availableWidth;

                                  final Widget tableContent = Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      /*
                                     * Header row.
                                     */
                                      Container(
                                        width: effectiveWidth,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              AppColors.primaryDark.withOpacity(
                                                0.7,
                                              ),
                                              AppColors.secondaryDark
                                                  .withOpacity(0.7),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            _headerCell(
                                              "Sr. No",
                                              sSr,
                                              headerFont,
                                            ),
                                            _headerCell(
                                              "✓",
                                              sCheck,
                                              headerFont,
                                            ),
                                            _headerCell(
                                              "Buch No",
                                              sBuch,
                                              headerFont,
                                            ),
                                            _headerCell(
                                              "Tree Wt",
                                              sTreeWt,
                                              headerFont,
                                            ),
                                            _headerCell(
                                              "Tree Bhuko",
                                              sTreeBhuko,
                                              headerFont,
                                            ),
                                            _headerCell(
                                              "Remaining\nTree Wt",
                                              sRemaining,
                                              headerFont,
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 8),

                                      /*
                                     * Item rows.
                                     */
                                      SizedBox(
                                        height: isMobile
                                            ? screenHeight * 0.37
                                            : screenHeight * 0.42,
                                        width: effectiveWidth,
                                        child: items.isEmpty
                                            ? Center(
                                          child: Text(
                                            "No items found",
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        )
                                            : ListView.builder(
                                          itemCount: items.length,
                                          keyboardDismissBehavior:
                                          ScrollViewKeyboardDismissBehavior
                                              .onDrag,
                                          itemBuilder: (context, index) {
                                            final Map<String, dynamic>
                                            item = items[index];

                                            final bool isCustom =
                                                item["is_custom"] == true;

                                            final String itemKey =
                                                item["id"]?.toString() ??
                                                    item["vacuum_voucher_item_id"]
                                                        ?.toString() ??
                                                    "item_$index";

                                            return Container(
                                              key: ValueKey(itemKey),
                                              margin:
                                              const EdgeInsets.only(
                                                bottom: 5,
                                              ),
                                              constraints:
                                              const BoxConstraints(
                                                minHeight: 48,
                                              ),
                                              decoration: BoxDecoration(
                                                color: getGroupColor(
                                                  item["group_id"],
                                                ),

                                                borderRadius:
                                                BorderRadius.circular(
                                                  0,
                                                ),

                                                border: Border.all(
                                                  color: getGroupColor(
                                                    item["group_id"],
                                                  ),
                                                ),
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                CrossAxisAlignment
                                                    .center,
                                                children: [
                                                  /*
                                                       * Sr. No.
                                                       */
                                                  SizedBox(
                                                    width: sSr,
                                                    child: Padding(
                                                      padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 2,
                                                      ),
                                                      child: Text(
                                                        "${index + 1}",
                                                        textAlign:
                                                        TextAlign
                                                            .center,
                                                        style: TextStyle(
                                                          fontSize:
                                                          baseFont,
                                                          fontWeight:
                                                          FontWeight
                                                              .bold,
                                                          color: Colors
                                                              .black,
                                                        ),
                                                      ),
                                                    ),
                                                  ),

                                                  SizedBox(
                                                    width: sCheck,
                                                    child: Checkbox(
                                                      value:
                                                      item["selected"] ??
                                                          false,
                                                      activeColor:
                                                      AppColors
                                                          .primaryDark,
                                                      onChanged: (value) {
                                                        setStateDialog(() {
                                                          item["selected"] = value ?? false;

                                                          if (value == false) {
                                                            item["group_id"] = null;
                                                          }
                                                        });

                                                        _offlineDraft.saveCastingDraft(
                                                          voucher["id"],
                                                          items,
                                                        );
                                                      },
                                                    ),
                                                  ),

                                                  /*
                                                       * Buch No.
                                                       */
                                                  SizedBox(
                                                    width: sBuch,
                                                    child: TextFormField(
                                                      key: ValueKey(
                                                        "buch_${itemKey}_${item["buch_no"]}",
                                                      ),
                                                      initialValue:
                                                      item["buch_no"]
                                                          ?.toString() ??
                                                          "",
                                                      readOnly: !isCustom,
                                                      textAlign: TextAlign
                                                          .center,
                                                      style: TextStyle(
                                                        fontSize:
                                                        baseFont,
                                                        fontWeight:
                                                        FontWeight
                                                            .bold,
                                                        color:
                                                        Colors.black,
                                                      ),
                                                      decoration: InputDecoration(
                                                        border:
                                                        InputBorder
                                                            .none,
                                                        isDense: true,
                                                        filled: isCustom,
                                                        fillColor:
                                                        isCustom
                                                            ? Colors.blue
                                                            .withOpacity(
                                                          0.04,
                                                        )
                                                            : Colors
                                                            .transparent,
                                                        contentPadding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal:
                                                          4,
                                                          vertical:
                                                          12,
                                                        ),
                                                      ),
                                                      onChanged: (value) {
                                                        item["buch_no"] =
                                                            value;

                                                        _offlineDraft
                                                            .saveCastingDraft(
                                                          voucher["id"],
                                                          items,
                                                        );
                                                      },
                                                    ),
                                                  ),

                                                  /*
                                                       * Tree Weight - editable.
                                                       */
                                                  SizedBox(
                                                    width: sTreeWt,
                                                    child: Padding(
                                                      padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 3,
                                                      ),
                                                      child: TextFormField(
                                                        key: ValueKey(
                                                          "tree_wt_$itemKey",
                                                        ),
                                                        initialValue:
                                                        item["tree_wt"]
                                                            ?.toString() ??
                                                            "",
                                                        keyboardType:
                                                        const TextInputType.numberWithOptions(
                                                          decimal:
                                                          true,
                                                        ),
                                                        textInputAction:
                                                        TextInputAction
                                                            .next,
                                                        textAlign:
                                                        TextAlign
                                                            .center,
                                                        style: TextStyle(
                                                          fontSize:
                                                          baseFont,
                                                          fontWeight:
                                                          FontWeight
                                                              .bold,
                                                          color: Colors
                                                              .black,
                                                        ),
                                                        decoration:
                                                        _cellDecoration(),
                                                        onChanged: (value) {
                                                          final double
                                                          treeWt =
                                                              double.tryParse(
                                                                value,
                                                              ) ??
                                                                  0;

                                                          final double
                                                          treeBhuko =
                                                              double.tryParse(
                                                                item["tree_bhuko"]
                                                                    ?.toString() ??
                                                                    "0",
                                                              ) ??
                                                                  0;

                                                          double
                                                          remaining =
                                                              treeWt -
                                                                  treeBhuko;

                                                          if (remaining <
                                                              0) {
                                                            remaining = 0;
                                                          }

                                                          item["tree_wt"] =
                                                              value;

                                                          item["remaining_tree_wt"] =
                                                              remaining
                                                                  .toStringAsFixed(
                                                                3,
                                                              );

                                                          _offlineDraft
                                                              .saveCastingDraft(
                                                            voucher["id"],
                                                            items,
                                                          );

                                                          setStateDialog(
                                                                () {},
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ),

                                                  /*
                                                       * Tree Bhuko - editable.
                                                       */
                                                  SizedBox(
                                                    width: sTreeBhuko,
                                                    child: Padding(
                                                      padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 3,
                                                      ),
                                                      child: TextFormField(
                                                        key: ValueKey(
                                                          "tree_bhuko_$itemKey",
                                                        ),
                                                        initialValue:
                                                        item["tree_bhuko"]
                                                            ?.toString() ??
                                                            "",
                                                        keyboardType:
                                                        const TextInputType.numberWithOptions(
                                                          decimal:
                                                          true,
                                                        ),
                                                        textInputAction:
                                                        TextInputAction
                                                            .done,
                                                        textAlign:
                                                        TextAlign
                                                            .center,
                                                        style: TextStyle(
                                                          fontSize:
                                                          baseFont,
                                                          fontWeight:
                                                          FontWeight
                                                              .bold,
                                                          color: Colors
                                                              .black,
                                                        ),
                                                        decoration:
                                                        _cellDecoration(),
                                                        onChanged: (value) {
                                                          final double
                                                          treeWt =
                                                              double.tryParse(
                                                                item["tree_wt"]
                                                                    ?.toString() ??
                                                                    "0",
                                                              ) ??
                                                                  0;

                                                          final double
                                                          treeBhuko =
                                                              double.tryParse(
                                                                value,
                                                              ) ??
                                                                  0;

                                                          double
                                                          remaining =
                                                              treeWt -
                                                                  treeBhuko;

                                                          if (remaining <
                                                              0) {
                                                            remaining = 0;
                                                          }

                                                          item["tree_bhuko"] =
                                                              value;

                                                          /*
                                                               * APIમાં office_cut_wt પણ
                                                               * tree_bhuko જેટલું જ મોકલવાનું હોય તો.
                                                               */
                                                          item["office_cut_wt"] =
                                                              value;

                                                          item["remaining_tree_wt"] =
                                                              remaining
                                                                  .toStringAsFixed(
                                                                3,
                                                              );

                                                          _offlineDraft
                                                              .saveCastingDraft(
                                                            voucher["id"],
                                                            items,
                                                          );

                                                          setStateDialog(
                                                                () {},
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ),

                                                  /*
                                                       * Remaining weight - read only.
                                                       */
                                                  SizedBox(
                                                    width: sRemaining,
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 1,
                                                        vertical: 4,
                                                      ),
                                                      child: Container(
                                                        alignment: Alignment.center,
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 2,
                                                          vertical: 8,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.green.withOpacity(0.08),
                                                          borderRadius: BorderRadius.circular(0),
                                                          border: Border.all(
                                                            color: Colors.green.withOpacity(0.20),
                                                            width: 1,
                                                          ),
                                                        ),
                                                        child: FittedBox(
                                                          fit: BoxFit.scaleDown,
                                                          child: Text(
                                                            double.tryParse(
                                                              item["remaining_tree_wt"]?.toString() ?? "0",
                                                            )?.toStringAsFixed(3) ??
                                                                "0.000",
                                                            maxLines: 1,
                                                            style: TextStyle(
                                                              fontSize: baseFont,
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.green.shade700,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  );

                                  if (!needsScroll) {
                                    return tableContent;
                                  }

                                  return Scrollbar(
                                    thumbVisibility: true,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: tableContent,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      /*
                     * Totals.
                     */
                      Container(
                        margin: const EdgeInsets.only(top: 0),
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 0 : 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          //border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: isMobile
                            ? Row(
                          children: [
                            Expanded(
                              child: _treeTotalBox(
                                title: "Tree Wt",
                                value: totalTreeWt,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _treeTotalBox(
                                title: "Tree Bhuko",
                                value: totalTreeBhuko,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _treeTotalBox(
                                title: "Remaining",
                                value: totalRemainingTreeWt,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        )
                            : Row(
                          children: [
                            Expanded(
                              child: _treeTotalBox(
                                title: "Tree Wt",
                                value: totalTreeWt,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _treeTotalBox(
                                title: "Tree Bhuko",
                                value: totalTreeBhuko,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _treeTotalBox(
                                title: "Remaining",
                                value: totalRemainingTreeWt,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),

                      /*
                     * Fixed Apply button.
                     */
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: InkWell(
                          onTap: () async {
                            FocusManager.instance.primaryFocus?.unfocus();

                            /*
                           * Negative remaining validation.
                           */
                            final invalidIndex = items.indexWhere((item) {
                              final treeWt =
                                  double.tryParse(
                                    item["tree_wt"]?.toString() ?? "0",
                                  ) ??
                                      0;

                              final treeBhuko =
                                  double.tryParse(
                                    item["tree_bhuko"]?.toString() ?? "0",
                                  ) ??
                                      0;

                              return treeBhuko > treeWt;
                            });

                            if (invalidIndex != -1) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "${items[invalidIndex]["buch_no"] ?? "Item ${invalidIndex + 1}"}: "
                                        "Tree Bhuko, Tree Wt કરતાં વધારે ન હોઈ શકે.",
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            /*
                           * Empty custom buch validation.
                           */
                            final invalidCustomIndex = items.indexWhere(
                                  (item) =>
                              item["is_custom"] == true &&
                                  (item["buch_no"]?.toString().trim().isEmpty ??
                                      true),
                            );

                            if (invalidCustomIndex != -1) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Custom item માટે Buch No દાખલ કરો.",
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            /*
                           * Totals voucher objectમાં પણ update.
                           */
                            voucher["tree_wt_total"] = totalTreeWt
                                .toStringAsFixed(3);

                            voucher["office_cut_wt_total"] = totalTreeBhuko
                                .toStringAsFixed(3);

                            voucher["remaining_tree_wt_total"] =
                                totalRemainingTreeWt.toStringAsFixed(3);

                            await _offlineDraft.saveCastingDraft(
                              voucher["id"],
                              items,
                            );

                            /*
                           * તમારું existing API update function.
                           *
                           * Functionનું નામ અલગ હોય તો અહીં બદલો.
                           */
                            await updateCastingHeating(voucher["id"], items);

                            if (!context.mounted) return;

                            Navigator.pop(dialogContext);

                            if (mounted) {
                              setState(() {});
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primaryDark.withOpacity(0.7),
                                  AppColors.secondaryDark.withOpacity(0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text(
                                "Apply",
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
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _headerCell(String text, double width, double fontSize) {
    return SizedBox(
      width: width,
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  InputDecoration _cellDecoration() {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(0),
        borderSide: const BorderSide(color: Colors.grey, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(0),
        borderSide: const BorderSide(color: Colors.blue, width: 1.5),
      ),
    );
  }

  Future<void> updateCastingHeating(
      int voucherId,
      List<Map<String, dynamic>> items,
      ) async {
    final Map<String, dynamic> itemData = {};

    for (final item in items) {
      if (item["selected"] != true) {
        continue;
      }

      final dynamic voucherItemId = item["vacuum_voucher_item_id"];

      if (voucherItemId == null) {
        continue;
      }

      final String key = voucherItemId.toString();

      final double officeCutWt = double.tryParse(
        item["tree_bhuko"]?.toString() ??
            item["office_cut_wt"]?.toString() ??
            "0",
      ) ??
          0;

      itemData[key] = {
        "office_cut_wt": officeCutWt.toStringAsFixed(3),
        "group_checked": item["selected"] ?? false,
      };
    }

    final Map<String, dynamic> body = {
      "items": itemData,
    };

    debugPrint("📤 FINAL REQUEST BODY => $body");

    if (itemData.isEmpty) {
      AppMessage.error(
        context,
        "Please select at least one item.",
      );
      return;
    }


    bool loaderOpened = false;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PopScope(
          canPop: false,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );

      loaderOpened = true;

      final response = await OfflineApiHelper.instance.putRequest(
        "${ApiConstants.tree_cutting_office}/$voucherId",
        body,
      );

      if (loaderOpened && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loaderOpened = false;
      }

      if (response == null) {
        if (mounted) {
          AppMessage.error(
            context,
            "No response from server.",
          );
        }
        return;
      }

      final int statusCode = response.statusCode ?? 0;

      if (statusCode == 202) {
        if (mounted) {
          AppMessage.success(
            context,
            "No Internet. Update saved offline.",
          );
        }

        await _offlineDraft.clearCastingDraft(voucherId);
        return;
      }

      if (statusCode == 200 && response.data["success"] == true) {
        if (mounted) {
          AppMessage.success(
            context,
            response.data["message"] ??
                "Updated Successfully",
          );
        }

        await _offlineDraft.clearCastingDraft(voucherId);

        final r = _apiRange();
        await category(fromDate: r.from, toDate: r.to);

        return;
      }

      if (mounted) {
        AppMessage.error(
          context,
          response.data?["message"] ??
              "Something went wrong",
        );
      }
    } catch (e, stackTrace) {
      debugPrint("updateCastingHeating error: $e");
      debugPrintStack(stackTrace: stackTrace);

      if (loaderOpened && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (mounted) {
        AppMessage.error(
          context,
          "Update failed. Please try again.",
        );
      }
    }
  }

  void calculateLoss(Map<String, dynamic> c, StateSetter setStateDialog) {
    double issueSilver =
        double.tryParse(c["issue_silver_wt"]?.toString() ?? "0") ?? 0;

    double releaseTree =
        double.tryParse(c["release_tree_wt"]?.toString() ?? "0") ?? 0;

    double bhuko =
        double.tryParse(c["release_tree_bhuko"]?.toString() ?? "0") ?? 0;

    double loss = issueSilver - releaseTree - bhuko;

    c["loss"] = loss.toStringAsFixed(3);

    lossControllers[c["id"].toString()]?.text = c["loss"].toString();

    setStateDialog(() {});
  }

  Widget workerDropdown(
      Map<String, dynamic> c,
      List<Map<String, dynamic>> jobWorkers,
      StateSetter setStateDialog, {
        required int voucherId,
        required List<Map<String, dynamic>> items,
        double width = 160,
        double height = 50,
      }) {
    return SizedBox(
      width: width,
      height: height,
      child: DropdownSearch<Map<String, dynamic>>(
        items: jobWorkers,

        selectedItem:
        jobWorkers.where((e) => e["id"] == c["job_worker_id"]).isNotEmpty
            ? jobWorkers.firstWhere((e) => e["id"] == c["job_worker_id"])
            : null,

        itemAsString: (item) => item["name"].toString(),

        /// 🔥 Premium Popup
        popupProps: PopupProps.dialog(
          showSearchBox: true,
          showSelectedItems: false,

          dialogProps: DialogProps(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0),
            ),
          ),

          containerBuilder: (context, popupWidget) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: popupWidget,
            );
          },

          itemBuilder: (context, item, isSelected) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.person, size: 18, color: Colors.blue),
                  const SizedBox(width: 5),

                  Expanded(
                    child: Text(
                      item["name"],
                      style: const TextStyle(color: Colors.black, fontSize: 14),
                    ),
                  ),
                ],
              ),
            );
          },

          searchFieldProps: TextFieldProps(
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              hintText: "Search Worker...",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: const Color(0xffF5F5F5),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        /// 🔥 Field Design
        dropdownDecoratorProps: DropDownDecoratorProps(
          dropdownSearchDecoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
            filled: true,
            fillColor: Colors.white,

            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(0),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(0),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(0),
              borderSide: const BorderSide(color: Colors.blue),
            ),
          ),
        ),

        /// 🔥 Selected Item (Icon + Center)
        dropdownBuilder: (context, selectedItem) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person, size: 16, color: Colors.blue),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  selectedItem?["name"] ?? "Select Worker",
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          );
        },

        onChanged: (worker) {
          if (worker == null) return;

          setStateDialog(() {
            c["job_worker_id"] = worker["id"];
            c["worker_name"] = worker["name"];
          });

          _offlineDraft.saveCastingDraft(voucherId, items); // 👈 ADD

          print("Selected Worker => ${worker["id"]}");
          print("Current Item => $c");
        },
      ),
    );
  }

  Widget _treeTotalRow({
    required String title,
    required double value,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        Text(
          value.toStringAsFixed(3),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _treeTotalBox({
    required String title,
    required double value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Column(
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.toStringAsFixed(3),
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color getGroupColor(String? groupId) {
    if (groupId == null) {
      return Colors.white;
    }

    final colors = [
      Colors.blue.shade50,
      Colors.green.shade50,
      Colors.orange.shade50,
      Colors.purple.shade50,
      Colors.red.shade50,
      Colors.cyan.shade50,
    ];

    return colors[groupId.hashCode.abs() % colors.length];
  }

  /// 📅 Date + 👤 Worker + 🔍 Search — badha filter ek sathe
  void applyAllFilters() {
    List filtered = List.from(allUsers);

    /// 📅 DATE RANGE (voucher_date, nahi to created_at)
    DateTime? fromDate;
    DateTime? toDate;
    try {
      if (fromDateController.text.trim().isNotEmpty) {
        fromDate = DateFormat("dd-MM-yyyy").parse(fromDateController.text.trim());
      }
      if (toDateController.text.trim().isNotEmpty) {
        toDate = DateFormat("dd-MM-yyyy").parse(toDateController.text.trim());
      }
    } catch (_) {
      fromDate = null;
      toDate = null;
    }

    if (fromDate != null && toDate != null) {
      final DateTime start = DateTime(fromDate.year, fromDate.month, fromDate.day);
      final DateTime end = DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59);

      filtered = filtered.where((user) {
        final DateTime? d = _rowDate(user);
        if (d == null) return true; // date na hoy to chhupavo nahi
        return !d.isBefore(start) && !d.isAfter(end);
      }).toList();
    }

    /// 👤 WORKER
    if (selectedRole != null && selectedRole!.isNotEmpty) {
      filtered = filtered.where((e) {
        return e["worker_id"]?.toString() == selectedRole;
      }).toList();
    }

    /// 🔍 SEARCH (voucher no / worker / process)
    final String q = searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      filtered = filtered.where((e) {
        return [
          e["voucher_no"],
          e["worker_name"],
          e["process_name"],
        ].any((v) => (v ?? "").toString().toLowerCase().contains(q));
      }).toList();
    }

    if (!mounted) return;
    setState(() => userlist = filtered);
  }

  /// "2026-10-21", "21-10-2026", "2026-10-21T10:00:00" — badha chale
  DateTime? _rowDate(Map row) {
    final String s =
    (row["voucher_date"] ?? row["created_at"] ?? "").toString().trim();
    if (s.isEmpty || s == "null") return null;

    final DateTime? iso = DateTime.tryParse(s.length >= 10 ? s.substring(0, 10) : s);
    if (iso != null) return iso;

    try {
      return DateFormat("dd-MM-yyyy").parse(s.substring(0, 10));
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    fromDateController.dispose();
    toDateController.dispose();
    super.dispose();
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
            child: Icon(
              Icons.close_rounded,
              size: 13,
              color: Colors.red.shade700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _dropdownLabel(String label, {bool required = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          if (required)
            const Text(
              " *",
              style: TextStyle(
                color: Colors.red,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}
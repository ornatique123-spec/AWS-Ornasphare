import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pecifician_sysytem/User/CreteUserScreen.dart';
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
import '../../Offline Data/offline_api_helper.dart';
// 🏢 Branch Reports (Sale Summary jevu j)
import 'package:pecifician_sysytem/Settings/BranchManagementScreen.dart'
    show BranchApi, Company, BranchTypeX;
import 'package:pecifician_sysytem/Reports/BranchAccess.dart';

class Castingheatingscreen extends StatefulWidget {
  const Castingheatingscreen({super.key});

  @override
  State<Castingheatingscreen> createState() => _CastingheatingscreenState();
}

class _CastingheatingscreenState extends State<Castingheatingscreen> {
  TextEditingController searchController = TextEditingController();
  TextEditingController fromDateController = TextEditingController();
  TextEditingController toDateController = TextEditingController();
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

  String? selectedRole;
  List allUsers = []; // 🔥 original data store
  bool isSearchOpen = false;

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

  /// casting_heating?management_branches[]=1&management_branches[]=2 (branch mode only)
  String _br(String url) => _branchMode
      ? "$url${url.contains('?') ? '&' : '?'}$_branchQuery"
      : url;

  /// heating → branch name (company_id / branch / company_name)
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




  void searchUser(String value) {
    if (value.trim().isEmpty) {
      setState(() {
        userlist = List.from(allUsers); // reset
      });
      return;
    }

    final String query = value.trim().toLowerCase();

    List filteredList = allUsers.where((user) {
      final String voucherNo =
          user["voucher_no"]?.toString().toLowerCase() ?? "";
      final String workerName =
          user["worker_name"]?.toString().toLowerCase() ?? "";
      final String processName =
          user["process_name"]?.toString().toLowerCase() ?? "";

      return voucherNo.contains(query) ||
          workerName.contains(query) ||
          processName.contains(query);
    }).toList();

    setState(() {
      userlist = filteredList;
    });
  }

  List userlist = [];

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
    if (!(hasPermission("casting-heating-view") ||
        hasPermission("casting-heating-manage"))) {
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
              ],
            ),

            /// ✅ APPBAR (OVERLAY)
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
                        autofocus: true,
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
                        "Casting Heating",
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
                            userlist = List.from(allUsers);
                          } else {
                            isSearchOpen = true;
                          }
                        });
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

  int? expandedHeatingId;
  Widget buildUserCard(Map user, int index) {
    final size = MediaQuery.of(context).size;
    final bool isTablet = size.width >= 600;

    /// =========================================================
    /// UNIQUE ID
    /// =========================================================
    final int id = int.tryParse(user["id"]?.toString() ?? "0") ?? 0;

    /// એક સમયે એક જ card open રહેશે
    final bool isExpanded = expandedHeatingId == id;

    /// =========================================================
    /// DATA
    /// =========================================================
    final String voucherNo = user["voucher_no"]?.toString() ?? "-";

    final String formulaValue = user["formula_value"]?.toString() ?? "";

    final String voucherDate = user["voucher_date"]?.toString() ?? "";

    final String processName = user["process_name"]?.toString() ?? "-";

    final String workerName = user["worker_name"]?.toString() ?? "-";

    final String totalPcs = user["total_pcs"]?.toString() ?? "-";

    final String bhatiPcs = user["in_bhati_pcs"]?.toString() ?? "-";

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
            /// HEADER
            /// ALWAYS VISIBLE
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
                  /// VOUCHER NO + FORMULA
                  /// =================================================
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// =================================================
                        /// VOUCHER NUMBER
                        /// =================================================
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

                        /// =================================================
                        /// BHATTI PCS + TOTAL PCS
                        /// =================================================
                        Row(
                          children: [
                            /// Bhatti Pcs
                            Icon(
                              Icons.local_fire_department_outlined,
                              size: 13,
                              color: Colors.grey.shade600,
                            ),

                            const SizedBox(width: 4),

                            Text(
                              "Bhatti: $bhatiPcs",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const SizedBox(width: 10),

                            /// Small Divider
                            Container(
                              width: 1,
                              height: 12,
                              color: Colors.grey.shade300,
                            ),

                            const SizedBox(width: 10),

                            /// Total Pcs
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 13,
                              color: Colors.grey.shade600,
                            ),

                            const SizedBox(width: 4),

                            Flexible(
                              child: Text(
                                "Total: $totalPcs",
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
                  if (hasPermission("casting-heating-view") ||
                      hasPermission("casting-heating-manage")) ...[
                    pdfBtn(() {
                      openPdf(user["id"]);
                    }),

                    SizedBox(width: isTablet ? 8 : 5),
                  ],

                  /// =================================================
                  /// EDIT
                  /// =================================================
                  if (hasPermission("casting-heating-edit") ||
                      hasPermission("casting-heating-manage")) ...[
                    premiumIconBtn(
                      Icons.edit_rounded,
                      Colors.blue,
                      onTap: () async {
                        await getApprovalDetails(
                          int.parse(user["id"].toString()),
                        );
                      },
                    ),

                    SizedBox(width: isTablet ? 8 : 5),
                  ],

                  /// =================================================
                  /// EXPAND BUTTON
                  /// =================================================
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (expandedHeatingId == id) {
                          /// Same card click
                          /// Close
                          expandedHeatingId = null;
                        } else {
                          /// New card open
                          /// Previous automatically close
                          expandedHeatingId = id;
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

            /// =====================================================
            /// EXPANDED CONTENT
            /// =====================================================
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),

              firstChild: const SizedBox(width: double.infinity, height: 0),

              secondChild: Container(
                width: double.infinity,

                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),

                child: Column(
                  children: [
                    /// =================================================
                    /// DIVIDER
                    /// =================================================
                    Divider(height: 1, color: AppColors.border),

                    const SizedBox(height: 10),

                    /// =================================================
                    /// ERP DETAILS
                    /// =================================================
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(6),

                        border: Border.all(color: AppColors.border, width: 1.2),
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

                          Divider(height: 1, color: AppColors.border),

                          /// =============================================
                          /// WORKER / PCS
                          /// =============================================
                          _erpRow("W Name", workerName, "Pcs", totalPcs),

                          Divider(height: 1, color: AppColors.border),

                          /// =============================================
                          /// BHATI PCS
                          /// =============================================
                          _erpRow("Bhati Pcs", bhatiPcs, "", ""),
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
    String url = ApiConstants.casting_heating;

    if (fromDate != null &&
        toDate != null &&
        fromDate.isNotEmpty &&
        toDate.isNotEmpty) {
      url += "?from_date=$fromDate&to_date=$toDate";
    }

    // 🏢 Branch mode → &management_branches[]=1&management_branches[]=2
    url = _br(url);

    final response = await ApiHelper().getRequest(url);

    print("heating API URL: $url");
    print("heating Raw Response: ${response.toString()}");

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
      });
      print("❌ userlist API failed");
      AppMessage.error(context, "Failed to load data");
    }
  }

  /// =========================================================
  /// 📄 EXPORT — PDF / EXCEL (getPdfRequest → bytes)
  /// casting_heating?management_branches[]=1&...&from_date=..&to_date=..&export=pdf
  /// =========================================================

  static String get _exportUrl => ApiConstants.casting_heating;

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
      final file = File("${dir.path}/Casting_Heating_$stamp.$ext");
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

  /// Heating list farithi (branch + date mujab)
  Future<void> _reloadHeating() async {
    setState(() {
      expandedHeatingId = null;
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
      await _reloadHeating();
    } finally {
      if (mounted) setState(() => branchReportLoading = false);
    }
  }

  /// Branch report bandh kari ne potani company ni gallery
  Future<void> clearBranchReport() async {
    setState(() => appliedCompanyIds = []);
    await _reloadHeating();
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
                    "Select one or more branches to see their casting heating.",
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
                              "Showing casting heating of "
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
                          setState(() {
                            final String? val = selectedData?["id"]?.toString();

                            selectedRole = val;

                            if (val == null || val.isEmpty) {
                              userlist = List.from(allUsers);
                            } else {
                              userlist = allUsers.where((e) {
                                return e["worker_id"].toString() == val;
                              }).toList();
                            }
                          });
                        },
                      ),

                      /// ❌ CLEAR — onChanged ma null aave tyare je thay e j
                      if (selectedWorkerData != null)
                        _clearIcon(
                              () {
                            setState(() {
                              selectedRole = null;
                              userlist = List.from(allUsers);
                            });
                          },
                          right: 40, // 🔥 aa widget mate tamaro customer vado value
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
                    String from = DateFormat("yyyy-MM-dd").format(
                      DateFormat("dd-MM-yyyy").parse(fromDateController.text),
                    );

                    String to = DateFormat("yyyy-MM-dd").format(
                      DateFormat("dd-MM-yyyy").parse(toDateController.text),
                    );

                    category(fromDate: from, toDate: to);

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

              /// CLEAR
              Expanded(
                child: InkWell(
                  onTap: () {
                    searchController.clear();
                    fromDateController.clear();
                    toDateController.clear();

                    setState(() {
                      userlist = allUsers; // reset list
                    });
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
    if (fromDateController.text.isEmpty || toDateController.text.isEmpty) {
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
    final parts = input.split("-");
    return DateTime(
      int.parse(parts[2]), // year
      int.parse(parts[1]), // month
      int.parse(parts[0]), // day
    );
  }

  Widget twoFieldRow(Widget left, Widget right) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [Expanded(child: left)]),
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

  Future<void> openPdf(int id) async {
    final response = await ApiHelper().getRequestWithId(
      ApiConstants.vacuum_voucherspdf,
      id,
      responseType: ResponseType.bytes,
    );

    if (response != null && response.statusCode == 200) {
      final dir = await getTemporaryDirectory();

      final file = File("${dir.path}/Voucher$id.pdf");

      await file.writeAsBytes(response.data);

      OpenFile.open(file.path);
    } else {
      print("PDF Download Failed");
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

  Future<void> getApprovalDetails(int id) async {
    final response = await ApiHelper().getRequestWithId(
      ApiConstants.casting_heating,
      id,
    );

    if (response != null &&
        response.statusCode == 200 &&
        response.data["success"] == true) {
      final data = response.data["data"];

      /// response items
      List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(
        data["items"] ?? [],
      );

      /// checkbox value
      for (var item in items) {
        item["checked"] = item["in_bhati"] ?? false;
        item["check_time"] = item["checked_at_view"] ?? "-";
      }

      /// dialog open
      showCastingDialog1(context, data, items);
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
      builder: (dialogOuterContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return LayoutBuilder(
              builder: (context, outerConstraints) {
                final double screenWidth = MediaQuery.of(context).size.width;
                final double screenHeight = MediaQuery.of(context).size.height;

                final double keyboardInset = MediaQuery.of(
                  context,
                ).viewInsets.bottom;

                /// =========================================================
                /// 🔥 RESPONSIVE BREAKPOINTS (pixel-based, not fixed ratio)
                /// =========================================================

                final bool isVerySmall = screenWidth < 360; // small phones
                final bool isMobile = screenWidth < 600;
                final bool isTablet = screenWidth >= 600 && screenWidth < 1000;
                // ignore: unused_local_variable
                final bool isDesktop = screenWidth >= 1000;

                /// =========================================================
                /// 🔥 DIALOG SIZE
                /// Desktop/tablet par max width cap rakhi, mobile par
                /// almost full width. Height keyboard-aware.
                /// =========================================================

                final double maxDialogWidth = isMobile
                    ? screenWidth
                    : (screenWidth * 0.7).clamp(420.0, 720.0);

                final double dialogWidth = maxDialogWidth;

                final double availableHeight = screenHeight - keyboardInset;

                final double dialogHeight = isMobile
                    ? (availableHeight * 0.94).clamp(320.0, availableHeight)
                    : (availableHeight * 0.86).clamp(360.0, availableHeight);

                /// =========================================================
                /// 🔥 TABLE COLUMN WIDTHS
                /// Fakt content padding minus (Dialog padding) mathi
                /// avelo actual available width vaparyo, jethi table
                /// koi device par overflow ke bahu chhoto na thay.
                /// =========================================================

                final double dialogHorizontalPadding = isVerySmall
                    ? 8
                    : (isMobile ? 10 : 16);

                final double innerWidth =
                    dialogWidth - (dialogHorizontalPadding * 2);

                final double baseFont = isVerySmall ? 11 : (isMobile ? 12 : 13);

                final double headerFont = isVerySmall
                    ? 10
                    : (isMobile ? 11 : 12);

                /// Minimum usable column widths (aa thi ochu na thay)
                const double minSr = 30;
                const double minBuch = 70;
                const double minBhati = 50;
                const double minCheckTime = 100;

                final double minTotal =
                    minSr + minBuch + minBhati + minCheckTime;

                /// Jo available width minimum thi vadhu hoy to proportionally
                /// stretch karo, nahi to horizontal scroll thavu padse.
                final bool needsHorizontalScroll = innerWidth < minTotal;

                final double tableBaseWidth = needsHorizontalScroll
                    ? minTotal
                    : innerWidth;

                final double stretchFactor = needsHorizontalScroll
                    ? 1.0
                    : (innerWidth / minTotal);

                final double sSr = minSr * stretchFactor;
                final double sBuch = minBuch * stretchFactor;
                final double sBhati = minBhati * stretchFactor;
                final double sCheckTime = minCheckTime * stretchFactor;

                /// =========================================================
                /// LIST HEIGHT (remaining space after header+info+padding)
                /// Fixed % na badle, ratio thi calculate — chhota screen
                /// par pan list dekhay + scroll thay, motu screen par
                /// vadhu space male.
                /// =========================================================

                final double listHeight =
                (dialogHeight * (isMobile ? 0.34 : 0.40)).clamp(
                  120.0,
                  480.0,
                );

                return Dialog(
                  insetPadding: EdgeInsets.symmetric(
                    horizontal: isVerySmall ? 4 : (isMobile ? 6 : 20),
                    vertical: isMobile ? 8 : 24,
                  ),
                  backgroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: dialogWidth,
                      maxHeight: dialogHeight,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(dialogHorizontalPadding),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  /// 🔝 HEADER
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final bool veryNarrow =
                                          constraints.maxWidth < 320;

                                      /// =========================================
                                      /// 🔥 OVERFLOW FIX
                                      /// PDF button + Back button combined
                                      /// width kyarek available space thi
                                      /// vadhu thay che (jem 320-400px range
                                      /// screens par), etle horizontal scroll
                                      /// wrap karyu che ane padding/font thodu
                                      /// ochu karyu che, jethi crash na thay
                                      /// ane koi device par overflow na dekhay.
                                      /// =========================================
                                      final Widget
                                      actionRow = SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            pdfBtn(() {
                                              openPdf(voucher["id"]);
                                            }),
                                            const SizedBox(width: 8),
                                            InkWell(
                                              onTap: () =>
                                                  Navigator.pop(context),
                                              child: Container(
                                                padding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black,
                                                  borderRadius:
                                                  BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  "Back",
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );

                                      final Widget titleText = Text(
                                        "Casting Heating Details",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: isVerySmall ? 14 : 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );

                                      /// 🔥 Very narrow screen → title upar,
                                      /// buttons niche (2 lines)
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

                                      /// 🔥 Normal case → title left, buttons
                                      /// right, same line
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

                                  /// ================= INFO CARDS =================
                                  SizedBox(height: isMobile ? 14 : 20),

                                  /// 🔥 Very small screens: 1 column stack,
                                  /// jethi info card ni text kapai na jay.
                                  isVerySmall
                                      ? Column(
                                    children: [
                                      _infoCard(
                                        title: "Process",
                                        value:
                                        voucher["process_name"] ??
                                            "-",
                                        icon: Icons.settings,
                                        color: Colors.blue,
                                      ),
                                      const SizedBox(height: 8),
                                      _infoCard(
                                        title: "Worker",
                                        value:
                                        voucher["worker_name"] ?? "-",
                                        icon: Icons.person,
                                        color: Colors.orange,
                                      ),
                                      const SizedBox(height: 8),
                                      _infoCard(
                                        title: "Created Date",
                                        value:
                                        voucher["voucher_date"] ??
                                            "-",
                                        icon: Icons.calendar_today,
                                        color: Colors.green,
                                      ),
                                      const SizedBox(height: 8),
                                      _infoCard(
                                        title: "Total Pcs",
                                        value:
                                        "${voucher["total_pcs"] ?? 0}",
                                        icon: Icons.inventory_2,
                                        color: Colors.purple,
                                      ),
                                    ],
                                  )
                                      : Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _infoCard(
                                              title: "Process",
                                              value:
                                              voucher["process_name"] ??
                                                  "-",
                                              icon: Icons.settings,
                                              color: Colors.blue,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _infoCard(
                                              title: "Worker",
                                              value:
                                              voucher["worker_name"] ??
                                                  "-",
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
                                              value:
                                              "${voucher["total_pcs"] ?? 0}",
                                              icon: Icons.inventory_2,
                                              color: Colors.purple,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  SizedBox(height: isMobile ? 12 : 15),

                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            "Buch Status",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        "${items.length} Rows",
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 10),

                                  /// 🔹 TABLE
                                  Builder(
                                    builder: (context) {
                                      Widget tableContent = Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          /// HEADER ROW
                                          Container(
                                            width: tableBaseWidth,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                              horizontal: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  AppColors.primaryDark
                                                      .withOpacity(0.7),
                                                  AppColors.secondaryDark
                                                      .withOpacity(0.7),
                                                ],
                                              ),
                                              borderRadius:
                                              BorderRadius.circular(6),
                                            ),
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: SizedBox(
                                                width:
                                                sSr +
                                                    sBuch +
                                                    sBhati +
                                                    sCheckTime,
                                                child: Row(
                                                  mainAxisSize:
                                                  MainAxisSize.min,
                                                  children: [
                                                    _headerCell(
                                                      "Sr. No",
                                                      sSr,
                                                      headerFont,
                                                    ),
                                                    _headerCell(
                                                      "Buch No",
                                                      sBuch,
                                                      headerFont,
                                                    ),
                                                    _headerCell(
                                                      "In Bhati",
                                                      sBhati,
                                                      headerFont,
                                                    ),
                                                    _headerCell(
                                                      "Check Time",
                                                      sCheckTime,
                                                      headerFont,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),

                                          const SizedBox(height: 8),

                                          /// LIST
                                          SizedBox(
                                            height: listHeight,
                                            width: tableBaseWidth,
                                            child: items.isEmpty
                                                ? const Center(
                                              child: Text(
                                                "No Buch Found",
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            )
                                                : ListView.builder(
                                              itemCount: items.length,
                                              itemBuilder: (context, index) {
                                                var c = items[index];

                                                return Container(
                                                  margin:
                                                  const EdgeInsets.only(
                                                    bottom: 5,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                    BorderRadius.circular(
                                                      5,
                                                    ),
                                                    border: Border.all(
                                                      color: Colors
                                                          .grey
                                                          .shade200,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      SizedBox(
                                                        width: sSr,
                                                        child: Padding(
                                                          padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal:
                                                            4,
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
                                                        width: sBuch,
                                                        child: TextFormField(
                                                          initialValue:
                                                          c["buch_no"],
                                                          style: TextStyle(
                                                            fontSize:
                                                            baseFont,
                                                            fontWeight:
                                                            FontWeight
                                                                .bold,
                                                            color: Colors
                                                                .black,
                                                          ),
                                                          onChanged: (v) {
                                                            c["amount"] =
                                                                v;
                                                            setStateDialog(
                                                                  () {},
                                                            );
                                                          },
                                                          keyboardType:
                                                          TextInputType
                                                              .number,
                                                          textAlign:
                                                          TextAlign
                                                              .center,
                                                          decoration: const InputDecoration(
                                                            border:
                                                            InputBorder
                                                                .none,
                                                            isDense: true,
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width: sBhati,
                                                        child: Checkbox(
                                                          value:
                                                          c["in_bhati"] ??
                                                              false,
                                                          onChanged: (val) {
                                                            setStateDialog(() {
                                                              c["in_bhati"] =
                                                                  val ??
                                                                      false;

                                                              if (val ==
                                                                  true) {
                                                                c["checked_at_view"] =
                                                                    DateFormat(
                                                                      "dd-MM-yyyy / hh:mm a",
                                                                    ).format(
                                                                      DateTime.now(),
                                                                    );
                                                              } else {
                                                                c["checked_at_view"] =
                                                                null;
                                                              }
                                                            });
                                                          },
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width:
                                                        90,
                                                        child: Padding(
                                                          padding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                              horizontal:
                                                              2),
                                                          child: Text(
                                                            c["checked_at_view"]
                                                                ?.toString()
                                                                .isNotEmpty ==
                                                                true
                                                                ? c["checked_at_view"]
                                                                .toString()
                                                                : "-",
                                                            textAlign:
                                                            TextAlign
                                                                .center,
                                                            maxLines: 2,
                                                            overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                            softWrap:
                                                            true,
                                                            style:
                                                            TextStyle(
                                                              color: Colors
                                                                  .black,
                                                              fontSize:
                                                              baseFont *
                                                                  0.92,
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

                                      // Jo scroll ni jarur hoy to horizontal
                                      // scroll, nahi to direct full-width
                                      return needsHorizontalScroll
                                          ? SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: tableContent,
                                      )
                                          : tableContent;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),

                          /// APPLY BUTTON — bottom fixed rahyu
                          SafeArea(
                            top: false,
                            child: Container(
                              padding: const EdgeInsets.only(top: 10),
                              width: double.infinity,
                              child: InkWell(
                                onTap: () async {
                                  FocusManager.instance.primaryFocus?.unfocus();

                                  await updateCastingHeating(
                                    voucher["id"],
                                    items,
                                  );

                                  Navigator.pop(context);
                                  setState(() {});
                                },
                                child: Container(
                                  height: 52,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.primaryDark.withOpacity(0.7),
                                        AppColors.secondaryDark.withOpacity(
                                          0.7,
                                        ),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      "Apply",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
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
      },
    );
  }

  /// 🔥 Reusable header cell (jo pahela add nathi karyu)
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

  Future<void> updateCastingHeating(
      int voucherId,
      List<Map<String, dynamic>> items,
      ) async {
    List<int> itemIds = items
        .where((e) => e["in_bhati"] == true)
        .map<int>((e) => int.parse(e["id"].toString()))
        .toList();

    final response = await OfflineApiHelper.instance.putRequest(
      "${ApiConstants.casting_heating}/$voucherId",
      {"items": itemIds},
    );

    print("PUT API URL : ${ApiConstants.casting_heating}/$voucherId");
    print("PUT Request : ${{"items": itemIds}}");
    print("PUT Response : ${response.toString()}");

    if (response != null && response.statusCode == 200 ||
        response!.statusCode == 202) {
      final data = response.data;

      if (response.statusCode == 202) {
        AppMessage.success(context, "No Internet. Update saved offline.");
      }

      if (data["success"] == true) {
        AppMessage.success(context, data["message"] ?? "Updated Successfully");

        // List Refresh
        String from = DateFormat(
          "yyyy-MM-dd",
        ).format(DateFormat("dd-MM-yyyy").parse(fromDateController.text));

        String to = DateFormat(
          "yyyy-MM-dd",
        ).format(DateFormat("dd-MM-yyyy").parse(toDateController.text));

        category(fromDate: from, toDate: to);
      } else {
        AppMessage.error(context, data["message"] ?? "Something went wrong");
      }
    } else {
      AppMessage.error(context, "Failed to update data");
    }
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
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pecifician_sysytem/Item_Mangement/Label_Items/Create_label_screen.dart';
import 'package:pecifician_sysytem/Job%20Work/Job%20Work%20Issue/Create_jobWork_Issue.dart';
import 'package:pecifician_sysytem/Job%20Work/JobWork%20Receive/AddJobWorkReceiveScreen.dart';
import 'package:pecifician_sysytem/Job%20Work/JobWork%20Receive/DirectJobWorkRecieve.dart';
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
import '../../Extra/PremiumSearchableDropdown.dart';
import 'ReceiveJobWorkScreen.dart';

import 'package:pecifician_sysytem/Settings/BranchManagementScreen.dart'
    show BranchApi, Company, BranchTypeX;
import 'package:pecifician_sysytem/Reports/BranchAccess.dart';

class Jobworkreceivescreen extends StatefulWidget {
  const Jobworkreceivescreen({super.key});

  @override
  State<Jobworkreceivescreen> createState() => _JobworkreceivescreenState();
}

class _JobworkreceivescreenState extends State<Jobworkreceivescreen> {
  List userlist = [];
  String? selectedItem;
  List<Map<String, dynamic>> tableRows = [];
  Timer? _huidTimer;
  int apiRowCount = 0;
  String? selectedRole;
  String? selectedJobWorker;
  String? selectedStatus = "all"; // 🔥 default: All Status

  /// 🔥 Fixed status filter options (matches the "status" values returned by the API)
  final List<Map<String, dynamic>> statusOptions = const [
    {"id": "all", "name": "All Status"},
    {"id": "pending", "name": "Pending"},
    {"id": "partial", "name": "Partial"},
    {"id": "completed", "name": "Completed"},
    {"id": "direct", "name": "Direct"},
  ];

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
      controller.text =
      "${picked.day.toString().padLeft(2, '0')}-"
          "${picked.month.toString().padLeft(2, '0')}-"
          "${picked.year}";

      /// 🔥 Banne date hoy to turat list reload
      if (fromDateController.text.isNotEmpty &&
          toDateController.text.isNotEmpty) {
        await _reloadList();
      }
    }
  }

  List allUsers = []; // 🔥 original data store

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

  /// jobwork_receive?management_branches[]=1&management_branches[]=2 (branch mode only)
  String _br(String url) => _branchMode
      ? "$url${url.contains('?') ? '&' : '?'}$_branchQuery"
      : url;

  /// job work receive → branch name (company_id / branch / company_name)
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

  /// ✅ Aa job work receive main company no chhe? (fakt eno j edit / delete)
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

  void searchUser(String value) {
    if (value.isEmpty) {
      setState(() {
        userlist = allUsers;
      });
      return;
    }

    List filteredList = allUsers.where((user) {
      final item = user["item"] ?? {};

      final name = item["item_name"]?.toString().toLowerCase() ?? "";
      final code = item["item_code"]?.toString().toLowerCase() ?? "";
      final metal = item["metal"]?.toString().toLowerCase() ?? "";

      return name.contains(value.toLowerCase()) ||
          code.contains(value.toLowerCase()) ||
          metal.contains(value.toLowerCase());
    }).toList();

    setState(() {
      userlist = filteredList;
    });
  }



  /// 🔥 Applies Worker + Status filters together on top of allUsers
  void _applyFilters() {
    List filtered = List.from(allUsers);

    if (selectedRole != null && selectedRole!.trim().isNotEmpty) {
      filtered = filtered.where((e) {
        final String jobWorkerId = e["job_worker_id"]?.toString() ?? "";
        return jobWorkerId == selectedRole;
      }).toList();
    }

    if (selectedStatus != null &&
        selectedStatus!.trim().isNotEmpty &&
        selectedStatus != "all") {
      filtered = filtered.where((e) {
        final String status =
        (e["status"]?.toString() ?? "").toLowerCase();
        return status == selectedStatus;
      }).toList();
    }

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

    String from = DateFormat("yyyy-MM-dd").format(
      DateFormat("dd-MM-yyyy").parse(fromDateController.text),
    );

    String to = DateFormat("yyyy-MM-dd").format(
      DateFormat("dd-MM-yyyy").parse(toDateController.text),
    );
    loadItemDetails("", from, to);
    _loadBranches();
  }

  @override
  Widget build(BuildContext context) {
    if(!(
        hasPermission("jobwork-receive-view") ||
            hasPermission("jobwork-receive-manage")
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
                Expanded(
                  child: userlist.isEmpty
                      ? const Center(
                    child: Text(
                      "No data found",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  )
                      : ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      12,
                      12,
                      12,
                      MediaQuery.of(
                        context,
                      ).viewInsets.bottom, // 🔥 MAGIC
                    ),
                    itemCount: userlist.length,
                    itemBuilder: (context, index) {
                      return buildItemCard(userlist[index], index);
                    },
                  ),
                ),
                if (hasPermission("jobwork-receive-create"))
                  InkWell(
                    onTap: () async {


                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const Receivejobworkscreen(),
                        ),
                      );

                      debugPrint("🔙 CREATE → PRODUCTION COST");
                      debugPrint("RESULT => $result");

                      if (!mounted) return;

                      if (result == true) {
                        await _refreshList();
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient:LinearGradient(
                            colors: [
                              AppColors.primaryDark.withOpacity(0.7),
                              AppColors.secondaryDark.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text(
                            "+ Create JobWork Receive",
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
                // ✅ Row — title vachche ni jagya ma j rahe, button ni niche na jay
                child: Row(
                  children: [
                    // LEFT BACK ICON
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

                    const SizedBox(width: 8),

                    // CENTER TITLE (jagya ochhi hoy to nanu thay)
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "JobWork Receive",
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: isMobile ? 15 : 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // RIGHT — EXCEL + PDF + ADD
                    _exportBtn(
                      icon: Icons.table_chart_rounded,
                      color: const Color(0xff16A34A),
                      tooltip: "Excel",
                      busy: _exporting == "excel",
                      onTap: () => _export("excel"),
                      isMobile: isMobile,
                    ),

                    SizedBox(width: isMobile ? 4 : 6),

                    _exportBtn(
                      icon: Icons.picture_as_pdf_rounded,
                      color: const Color(0xffDC2626),
                      tooltip: "PDF",
                      busy: _exporting == "pdf",
                      onTap: () => _export("pdf"),
                      isMobile: isMobile,
                    ),

                    SizedBox(width: isMobile ? 4 : 6),

                    // + ADD BUTTON
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const Directjobworkrecieve(),
                          ),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 12,
                          vertical: isMobile ? 7 : 9,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add,
                              color: Colors.white,
                              size: isMobile ? 16 : 18,
                            ),
                            const Text(
                              "Add",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
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
          ],
        ),
        //bottomNavigationBar: _buildSaveButton(),
      ),
    );
  }
  int? expandedJobworkReceiveId;
  Widget buildItemCard(Map user, int index) {
    final size = MediaQuery.of(context).size;
    final bool isTablet = size.width >= 600;

    /// =========================================================
    /// UNIQUE ID
    /// =========================================================
    final int id =
        int.tryParse(user["id"]?.toString() ?? "0") ?? 0;

    final bool isExpanded = expandedJobworkReceiveId == id;

    /// =========================================================
    /// DATA
    /// =========================================================
    final String workerName =
        user["jobworker_name"]?.toString() ?? "-";

    final String voucherNo =
        user["voucher_no"]?.toString() ?? "-";

    final String productionStep =
        user["production_step_name"]?.toString() ?? "-";

    final String voucherDate =
        user["voucher_date"]?.toString() ?? "";

    final String issueNetWt =
        user["issue_net_wt"]?.toString() ?? "-";

    final String receiveNetWt =
        user["receive_net_wt"]?.toString() ?? "-";

    final String pendingNetWt =
        user["pending_net_wt"]?.toString() ?? "-";

    final String status =
        user["status"]?.toString() ?? "-";

    final String statusLower = status.toLowerCase();

    final String processName =
        user["process"]?["name"]?.toString() ??
            user["process_name"]?.toString() ??
            "-";

    /// =========================================================
    /// STATUS COLORS
    /// =========================================================
    final Color statusColor =
    statusLower == "pending"
        ? Colors.redAccent
        : statusLower == "completed"
        ? Colors.green
        : Colors.blue;

    final Color statusBackground =
    statusLower == "pending"
        ? Colors.orange.withOpacity(0.12)
        : statusLower == "completed"
        ? Colors.green.withOpacity(0.12)
        : Colors.blue.withOpacity(0.12);

    /// 🔐 Main company sivay ni branch no data → edit / delete nahi
    final bool canModify = _isMainData(user);

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
                  /// WORKER NAME + VOUCHER NO
                  /// =================================================
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        /// WORKER NAME
                        Text(
                          workerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 3),

                        /// VOUCHER NO
                        Row(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 13,
                              color: Colors.grey.shade600,
                            ),

                            const SizedBox(width: 4),

                            Expanded(
                              child: Text(
                                voucherNo,
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

                        const SizedBox(height: 3),

                        /// PROCESS
                        Row(
                          children: [
                            Icon(
                              Icons.settings_outlined,
                              size: 13,
                              color: Colors.grey.shade600,
                            ),

                            const SizedBox(width: 4),

                            Expanded(
                              child: Text(
                                "$productionStep",
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

                  const SizedBox(width: 5),

                  /// =================================================
                  /// STATUS
                  /// =================================================
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),

                    decoration: BoxDecoration(
                      color: statusBackground,
                      borderRadius: BorderRadius.circular(5),

                      border: Border.all(
                        color: statusColor,
                      ),
                    ),

                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),

                  SizedBox(
                    width: isTablet ? 8 : 4,
                  ),

                  /// =================================================
                  /// PDF
                  /// =================================================
                  pdfBtn(() {
                    if (statusLower == "direct") {
                      openDirectPdf(id, row: user);
                    } else {
                      openPdf(id, row: user);
                    }
                  }),

                  /// =================================================
                  /// EYE / DETAILS
                  /// =================================================
                  if (canModify && hasPermission("jobwork-receive-edit")) ...[
                    SizedBox(
                      width: isTablet ? 8 : 4,
                    ),

                    premiumIconBtn(
                      Icons.remove_red_eye_rounded,
                      Colors.blue,
                      onTap: () async {
                        if (id <= 0) return;

                        if (statusLower == "direct") {
                          /// 🔥 Direct receive → open Directjobworkrecieve
                          /// screen in edit mode
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Directjobworkrecieve(
                                userData: user,
                              ),
                            ),
                          );

                          if (!mounted) return;

                          if (result == true) {
                            await _refreshList();
                          }
                        } else {
                          await getApprovalDetails(id);
                        }
                      },
                    ),
                  ],

                  /// =================================================
                  /// DELETE (direct receives only)
                  /// =================================================
                  if (canModify &&
                      statusLower == "direct" &&
                      hasPermission("jobwork-receive-edit")) ...[
                    SizedBox(
                      width: isTablet ? 8 : 4,
                    ),

                    premiumIconBtn(
                      Icons.delete_outline_rounded,
                      Colors.red,
                      onTap: () async {
                        if (id <= 0) return;
                        await _confirmAndDeleteDirectReceive(id);
                      },
                    ),
                  ],

                  SizedBox(
                    width: isTablet ? 8 : 4,
                  ),

                  /// =================================================
                  /// EXPAND BUTTON
                  /// =================================================
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (expandedJobworkReceiveId == id) {
                          /// Same card click -> close
                          expandedJobworkReceiveId = null;
                        } else {
                          /// New card open
                          /// Previous automatically close
                          expandedJobworkReceiveId = id;
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
                          color:
                          AppColors.primaryDark.withOpacity(0.08),
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

                    /// =================================================
                    /// DIVIDER
                    /// =================================================
                    Divider(
                      height: 1,
                      color: AppColors.border,
                    ),

                    const SizedBox(height: 10),

                    /// =================================================
                    /// ERP DETAILS
                    /// =================================================
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

                          /// ===========================================
                          /// PRODUCTION STEP / DATE
                          /// ===========================================
                          _erpRow(
                            "P Steps",
                            productionStep,

                            "Date",
                            voucherDate.isNotEmpty
                                ? formatDate(voucherDate)
                                : "-",
                          ),

                          Divider(
                            height: 1,
                            color: AppColors.border,
                          ),

                          /// ===========================================
                          /// ISSUE / RECEIVE NET WT
                          /// ===========================================
                          _erpRow(
                            "Issue Net Wt",
                            issueNetWt,

                            "Receive Net Wt",
                            receiveNetWt,
                          ),

                          Divider(
                            height: 1,
                            color: AppColors.border,
                          ),

                          /// ===========================================
                          /// STATUS / PENDING NET WT
                          /// ===========================================
                          _erpRow(
                            "Status",
                            status,

                            "Pending Net Wt",
                            pendingNetWt,
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

  // Future<void> loadItemDetails(String itemId) async {
  //   final response = await ApiHelper().getRequest(ApiConstants.jobwork_issues);
  //
  //   if (response!.statusCode == 200 && response.data["data"] != null) {
  //     final data = response.data;
  //
  //     // ✅ success check
  //     final List categories = data['data'];
  //
  //     setState(() {
  //       tableRows.clear();
  //
  //       userlist = categories;
  //       allUsers = categories; // 🔥 store original
  //     });
  //     AppMessage.success(
  //       context,
  //       data["message"] ?? "Data Loaded Successfully",
  //     );
  //     applyDateFilter();
  //   } else {
  //     setState(() {
  //       userlist = [];
  //       allUsers = [];
  //     });
  //     print("❌ userlist API failed");
  //
  //     /// ❌ ERROR MESSAGE
  //     AppMessage.error(context, "Failed to load data");
  //   }
  // }

  Future<void> loadItemDetails(
      String itemId,
      String from,
      String to,
      ) async {

    // 🔥 Branch mode → &management_branches[]=1&management_branches[]=2
    final String url =
    _br("${ApiConstants.jobwork_receive}?from=$from&to=$to");
    debugPrint("📋 JOBWORK RECEIVE URL => $url");

    final response = await ApiHelper().getRequest(url);

    if (!mounted) return;

    if (response?.statusCode == 200 && response?.data["data"] != null) {
      final data = response!.data;

      // 🔥 Voucher pramane sort (navo upar)
      final List categories = _sortByVoucher(data['data']);

      setState(() {
        tableRows.clear();
        userlist = categories;
        allUsers = categories;
      });

      _applyFilters(); // 🔥 Worker + Status filter fari lagu karo

      AppMessage.success(
        context,
        data["message"] ?? "Data Loaded Successfully",
      );

    } else {
      setState(() {
        userlist = [];
        allUsers = [];
      });

      AppMessage.error(context, "Failed to load data");
    }
  }

  /// From / To date (dd-MM-yyyy → yyyy-MM-dd), khotu ke khali hoy to null
  ({String? from, String? to}) _apiRange() {
    String? conv(String s) {
      try {
        if (s.trim().isEmpty) return null;
        return DateFormat("yyyy-MM-dd")
            .format(DateFormat("d-M-yyyy").parse(s.trim()));
      } catch (_) {
        return null;
      }
    }

    return (from: conv(fromDateController.text), to: conv(toDateController.text));
  }

  /// ✅ Edit / Delete / Create pachhi refresh — date khali hoy to crash nahi
  Future<void> _refreshList() async {
    final r = _apiRange();
    if (r.from == null || r.to == null) return;
    await loadItemDetails("", r.from!, r.to!);
  }

  /// =========================================================
  /// 📄 EXPORT — PDF / EXCEL (getPdfRequest → bytes)
  /// jobwork_receive?from=..&to=..&management_branches[]=1&management_branches[]=2&export=pdf
  /// =========================================================

  static String get _exportUrl => ApiConstants.jobwork_receive;

  /// "pdf" / "excel" chalu hoy tyare (bijo tap na thay)
  String? _exporting;

  Future<void> _export(String type) async {
    if (_exporting != null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _exporting = type);

    try {
      // List ma je date + branch chhe e j export ma pan
      final r = _apiRange();
      String base = _exportUrl;
      if (r.from != null && r.to != null) {
        base += "?from=${r.from}&to=${r.to}";
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
      final file = File("${dir.path}/JobWork_Receive_$stamp.$ext");
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


  /// 🔥 Confirms then deletes a "direct" jobwork receive via
  /// DELETE https://ornasphere.com/api/jobwork-receive/direct/{id}
  Future<void> _confirmAndDeleteDirectReceive(int id) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text("Delete Receive"),
          content: const Text(
            "Are you sure you want to delete this jobwork receive? This action cannot be undone.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                "Delete",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await deleteJobworkReceiveDirect(id);
  }

  Future<void> deleteJobworkReceiveDirect(int id) async {
    try {
      final response = await ApiHelper().deleteRequest(
        "${ApiConstants.jobwork_receive_direct}/$id",
      );

      debugPrint("🗑 DELETE DIRECT RECEIVE => id=$id status=${response?.statusCode}");

      if (!mounted) return;

      if (response != null &&
          (response.statusCode == 200 || response.statusCode == 204)) {
        AppMessage.success(context, "Deleted successfully");

        await _refreshList();
      } else {
        AppMessage.error(context, "Failed to delete");
      }
    } catch (e) {
      debugPrint("❌ Delete direct receive exception: $e");
      if (mounted) {
        AppMessage.error(context, "Failed to delete");
      }
    }
  }

  Future<void> deleteUser(String ID) async {
    try {
      final response = await ApiHelper().deleteRequest(
        "${ApiConstants.jobwork_issues_delete}/$ID",
      );

      if (response?.statusCode == 200) {
        print("✅ Deleted Successfully");
        print("Response: ${response?.data}");

        String from = DateFormat("yyyy-MM-dd").format(
          DateFormat("dd-MM-yyyy").parse(fromDateController.text),
        );

        String to = DateFormat("yyyy-MM-dd").format(
          DateFormat("dd-MM-yyyy").parse(toDateController.text),
        );

        loadItemDetails("", from, to);
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
          /// 👷 WORKER DROPDOWN
          Consumer<ItemProvider>(
            builder: (context, provider, child) {
              // ============================================
              // 🔥 Fakt ACTIVE workers
              // (select thayelo worker inactive hoy to pan dekhay)
              // ============================================
              final List<Map<String, dynamic>> workers = provider.Job_worker
                  .where((e) =>
              _isActive(e["is_active"]) ||
                  e["id"]?.toString() == selectedRole)
                  .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
                  .toList();

              Map<String, dynamic>? selectedWorker;

              if (selectedRole != null && selectedRole!.trim().isNotEmpty) {
                for (final worker in workers) {
                  if (worker["id"]?.toString() == selectedRole) {
                    selectedWorker = worker;
                    break;
                  }
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dropdownLabel("Worker"),
                  Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      PremiumItemSearchDropdown(
                        label: "", // 🔥 label upar bahar chhe
                        hint: "Select Worker",
                        width: double.infinity,
                        items: workers,
                        value: selectedWorker,
                        requiredField: true,
                        onChanged: (worker) {
                          selectedRole = worker == null ? null : worker["id"]?.toString();

                          debugPrint("SELECTED WORKER => $selectedRole");

                          _applyFilters();
                        },
                      ),

                      /// ❌ CLEAR
                      if (selectedWorker != null)
                        _clearIcon(() {
                          selectedRole = null;
                          _applyFilters();
                        }),
                    ],
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 5),

          /// 🔥 STATUS DROPDOWN
          Builder(
            builder: (context) {
              Map<String, dynamic>? selectedStatusObj;

              if (selectedStatus != null && selectedStatus!.trim().isNotEmpty) {
                try {
                  selectedStatusObj = statusOptions.firstWhere(
                        (e) => e["id"] == selectedStatus,
                  );
                } catch (_) {
                  selectedStatusObj = null;
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dropdownLabel("Status", required: false),
                  Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      PremiumItemSearchDropdown(
                        label: "",
                        hint: "Select Status",
                        requiredField: false,
                        width: double.infinity,
                        items: statusOptions,
                        value: selectedStatusObj,
                        onChanged: (status) {
                          selectedStatus =
                          status == null ? null : status["id"]?.toString();

                          debugPrint("SELECTED STATUS => $selectedStatus");

                          _applyFilters();
                        },
                      ),

                      /// ❌ CLEAR
                      if (selectedStatusObj != null)
                        _clearIcon(() {
                          selectedStatus = null;
                          _applyFilters();
                        }),
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
                  onTap: () async {
                    final DateTime today = DateTime.now();
                    final DateTime sevenDaysAgo = today.subtract(const Duration(days: 7));
                    final f = DateFormat("dd-MM-yyyy");

                    searchController.clear();
                    fromDateController.text = f.format(sevenDaysAgo);
                    toDateController.text = f.format(today);

                    setState(() {
                      selectedRole = null;
                      selectedStatus = "all";
                    });

                    await _reloadList();
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

                  borderRadius: BorderRadius.circular(5),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color:AppColors.border),
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
          )
        ],
      ),
    );
  }

  void applyDateFilter() {

    if (fromDateController.text.isEmpty ||
        toDateController.text.isEmpty) {

      setState(() {
        userlist = allUsers;
      });

      return;
    }

    DateTime fromDate =
    _convertToDate(fromDateController.text);

    DateTime toDate =
    _convertToDate(toDateController.text);

    List filtered = allUsers.where((user) {

      /// 🔥 USE MAIN created_at
      if (user["created_at"] == null) {
        return false;
      }

      DateTime userDate =
      DateTime.parse(user["created_at"]);

      return userDate.isAfter(
          fromDate.subtract(const Duration(days: 1))) &&
          userDate.isBefore(
              toDate.add(const Duration(days: 1)));

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
    try {
      return DateFormat("d-M-yyyy").parse(input.trim());
    } catch (_) {
      return DateTime.now();
    }
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

  Widget excelBtn(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xff66BB6A), // light green
              Color(0xff66BB6A), // dark green
              Color(0xff66BB6A), // light green
            ],
          ),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              "assets/static/excel.png", // 👈 tamari image path
              width: 18,
              height: 18,
              //color: Colors.white, // optional (agar PNG support kare to)
            ),
            // SizedBox(width: 4),
            // Text(
            //   "Excel",
            //   style: TextStyle(
            //       color: Colors.white,
            //       fontWeight: FontWeight.w500,
            //       fontSize: 16
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  /// 📄 Card nu PDF
  /// Branch mode: jobwork_receive_pdf/378?management_branches[]=21 (fakt e card ni branch)
  /// Normal: pehla jevu j (getRequestWithId)
  Future<void> openPdf(int id, {Map? row}) async {
    await _openCardFile(
      id: id,
      row: row,
      endpoint: ApiConstants.jobwork_receive_pdf,
      fileName: "Job Work Receive$id.pdf",
      label: "PDF",
    );
  }

  /// 🔥 Direct receives use a separate PDF endpoint:
  /// https://ornasphere.com/api/jobwork-receive/direct/pdf/{id}
  /// Branch mode: .../direct/pdf/378?management_branches[]=21
  Future<void> openDirectPdf(int id, {Map? row}) async {
    await _openCardFile(
      id: id,
      row: row,
      endpoint: "${ApiConstants.jobwork_receive_direct}/pdf",
      fileName: "Job Work Receive Direct $id.pdf",
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

  Future<void> openExel(int id) async {
    final response = await ApiHelper().getRequestWithId(
      ApiConstants.jobwork_issues_exel,
      id,
      responseType: ResponseType.bytes,
    );

    if (response != null && response.statusCode == 200) {
      final dir = await getTemporaryDirectory();

      final file = File("${dir.path}/return_$id.pdf");

      await file.writeAsBytes(response.data);

      OpenFile.open(file.path);
    } else {
      print("PDF Download Failed");
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

  Future<void> getApprovalDetails(int id) async {

    final response = await ApiHelper().getRequestWithId(
      ApiConstants.jobwork_receive,
      id,
    );

    /// 🔥 RAW response — koi processing pehla j print karo
    print("🔍🔍🔍 RAW API RESPONSE: ${response?.data}");

    if (response != null &&
        response.statusCode == 200 &&
        response.data["success"] == true) {

      final data = response.data["data"];

      /// response items
      List<Map<String, dynamic>> items =
      List<Map<String, dynamic>>.from(data["items"] ?? []);

      /// 🔥 Item 454 specifically check karo
      final item454 = items.firstWhere(
            (i) => i["id"].toString() == "454",
        orElse: () => {},
      );
      print("🔍🔍🔍 ITEM 454 FROM API (before draft merge): $item454");

      /// checkbox value
      for (var item in items) {
        item["checked"] = item["in_bhati"] ?? false;
        item["check_time"] = item["checked_at_view"] ?? "-";
      }


      /// Direct screen open
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Addjobworkreceivescreen(
            voucher: data,
            items: items,
          ),
        ),
      );

      if (!mounted) return;

      /// ============================================
      /// 6. REFRESH AFTER RETURN
      /// ============================================
      if (result == true) {
        await _refreshList();
      }
    }
  }

  /// 🔹 Dropdown label (widget ni andar jevu j)
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

  /// ❌ CLEAR ICON — dropdown ni andar, arrow ni dabi baju
  Widget _clearIcon(VoidCallback onClear) {
    return Positioned(
      right: 37, // 🔥 jarur mujab 35–42 karo
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

  /// 🔹 API ma is_active true / 1 / "1" / "true" koi pan rite aave, badhu sambhale
  bool _isActive(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    final s = v.toString().toLowerCase().trim();
    return s == "1" || s == "true";
  }

  /// 🔥 "JI26-3" → [26, 3]  (year, serial)
  List<int> _voucherKey(dynamic voucherNo) {
    final String s = voucherNo?.toString().trim() ?? "";
    final List<String> parts = s.split("-");

    final int serial =
        int.tryParse(parts.last.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    final int year = parts.length > 1
        ? int.tryParse(parts.first.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0
        : 0;

    return [year, serial];
  }

  /// 🔥 Navo voucher upar: year DESC → serial DESC → id DESC
  List _sortByVoucher(List list) {
    final List sorted = List.from(list);

    sorted.sort((a, b) {
      final List<int> ka = _voucherKey(a["voucher_no"]);
      final List<int> kb = _voucherKey(b["voucher_no"]);

      if (ka[0] != kb[0]) return kb[0].compareTo(ka[0]); // year
      if (ka[1] != kb[1]) return kb[1].compareTo(ka[1]); // serial

      final int ia = int.tryParse(a["id"]?.toString() ?? "") ?? 0;
      final int ib = int.tryParse(b["id"]?.toString() ?? "") ?? 0;
      return ib.compareTo(ia); // same voucher hoy to navo id upar
    });

    return sorted;
  }

  /// 🔥 Date pramane API thi data lavo, pachhi Worker + Status filter lagu karo
  Future<void> _reloadList() async {
    if (fromDateController.text.isEmpty || toDateController.text.isEmpty) {
      AppMessage.error(context, "Please select From and To date");
      return;
    }
    try {
      final String from = DateFormat("yyyy-MM-dd").format(
        DateFormat("d-M-yyyy").parse(fromDateController.text),
      );
      final String to = DateFormat("yyyy-MM-dd").format(
        DateFormat("d-M-yyyy").parse(toDateController.text),
      );

      await loadItemDetails("", from, to);
    } catch (e) {
      debugPrint("❌ Date parse error: $e");
      AppMessage.error(context, "Invalid date");
    }
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

  /// Job work receive list farithi (branch mujab)
  Future<void> _reloadJobworkReceive() async {
    setState(() => expandedJobworkReceiveId = null);
    // Date khali hoy to "Please select From and To date" message aave
    await _reloadList();
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
      await _reloadJobworkReceive();
    } finally {
      if (mounted) setState(() => branchReportLoading = false);
    }
  }

  /// Branch report bandh kari ne potani company ni gallery
  Future<void> clearBranchReport() async {
    setState(() => appliedCompanyIds = []);
    await _reloadJobworkReceive();
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
                    "Select one or more branches to see their job work receives.",
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
                              "Showing job work receives of "
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
}
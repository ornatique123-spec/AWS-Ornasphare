import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pecifician_sysytem/Item_Mangement/Label_Items/Create_label_screen.dart';
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

import 'package:pecifician_sysytem/Settings/BranchManagementScreen.dart'
    show BranchApi, Company, BranchTypeX;
import 'package:pecifician_sysytem/Reports/BranchAccess.dart';

class label_item_screen extends StatefulWidget {
  const label_item_screen({super.key});

  @override
  State<label_item_screen> createState() => _label_item_screenState();
}

class _label_item_screenState extends State<label_item_screen> {
  List userlist = [];
  String? selectedItem;
  List<Map<String, dynamic>> tableRows = [];
  final FocusNode labelSearchFocusNode = FocusNode();
  Timer? _huidTimer;
  int apiRowCount = 0;
  Timer? _labelSearchTimer;
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

  String selectedView = "list";
  List allUsers = []; // 🔥 original data store
  bool isGridView = false;
  final ImagePicker _imagePicker = ImagePicker();

  File? selectedImageFile;
  int currentPage = 1;
  int lastPage = 1;
  bool isLoadingMore = false;

  // Load More button same filters sathe next page fetch kare
  // tya mate last used item/from/to yaad rakhvu.
  String _lastItemId = "";
  String _lastFromDate = "";
  String _lastToDate = "";

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

  /// label_item_list?management_branches[]=1&management_branches[]=2 (branch mode only)
  String _br(String url) => _branchMode
      ? "$url${url.contains('?') ? '&' : '?'}$_branchQuery"
      : url;

  /// label item → branch name (company_id / branch / company_name)
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

  /// ✅ Aa label item main company no chhe? (fakt eno j edit / delete)
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

  List gridUsers = [];

  List<String> userPermissions = []; // 🔥 ADD
  final TextEditingController labelSearchController = TextEditingController();

  List<Map<String, dynamic>> allLabelItems = [];

  List<Map<String, dynamic>> searchResults = [];
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
    Future.microtask(() {
      Provider.of<ItemProvider>(context, listen: false).loadItems();
    });

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

    loadItemDetails("", from, to);
    _loadBranches();
  }

  @override
  Widget build(BuildContext context) {
    if (!(hasPermission("item-set-view") || hasPermission("item-set-manage"))) {
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

        // Navigator.pushReplacement(
        //   context,
        //   MaterialPageRoute(
        //     builder: (_) => const HomeScreen(),
        //   ),
        // );
        Navigator.pop(context, true);
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false, // 🔥 IMPORTANT
        backgroundColor: AppColors.white,
        body: Stack(
          children: [
            /// ✅ Background Image
            // Positioned.fill(
            //   child: Image.asset("assets/static/img_3.png", fit: BoxFit.fill),
            // ),

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
                      MediaQuery.of(context).viewInsets.bottom,
                    ),
                    itemCount:
                    userlist.length +
                        (selectedView == "list"
                            ? 1
                            : 0), // 🔥 footer row for Load More
                    itemBuilder: (context, index) {
                      if (index == userlist.length) {
                        return _buildLoadMoreButton(); // 🔥 last row = button
                      }

                      final item = userlist[index];

                      if (selectedView == "list") {
                        return buildItemCard(item, index);
                      } else {
                        return buildGridCard(item, index);
                      }
                    },
                  ),
                ),

                /// 🔥 BOTTOM SUMMARY
                buildSummaryRow(),

                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateLabelScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
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
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          "+ Create Item",
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
                      "Label Items",
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
                          // Navigator.push(
                          //   context,
                          //   MaterialPageRoute(
                          //     builder: (context) => const HomeScreen(),
                          //   ),
                          // );
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

  int? expandedItemId;
  Widget buildItemCard(Map user, int index) {
    final size = MediaQuery.of(context).size;
    final bool isTablet = size.width >= 600;

    final int id = int.tryParse(user["id"]?.toString() ?? "0") ?? 0;

    final bool isExpanded = expandedItemId == id;

    final String itemName = user["item"]?["item_name"]?.toString() ?? "";

    final String metal = user["item"]?["metal"]?.toString() ?? "";

    final String qrCode = user["qr_code"]?.toString() ?? "";

    final String imageUrl = user["image_url"]?.toString().trim() ?? "";
    final int reuse =
        int.tryParse(user["item"]?["reuse"]?.toString() ?? "0") ?? 0;

    /// 🔐 Main company sivay ni branch no data → upload / edit / delete nahi
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
            /// TOP HEADER
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
                  /// ITEM NAME
                  /// HN001
                  /// =================================================
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          itemName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 3),

                        Row(
                          children: [
                            Icon(
                              Icons.qr_code_2_rounded,
                              size: 13,
                              color: Colors.grey.shade600,
                            ),

                            const SizedBox(width: 4),

                            Expanded(
                              child: Text(
                                qrCode.isEmpty ? "-" : qrCode,
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

                  const SizedBox(width: 6),

                  /// =================================================
                  /// IMAGE / UPLOAD
                  /// =================================================
                  if (canModify &&
                      (hasPermission("item-set-edit") ||
                          hasPermission("item-set-manage")))
                    _buildImageUploadButton(user),

                  /// =================================================
                  /// DOWNLOAD
                  /// =================================================
                  if (imageUrl.isNotEmpty) ...[
                    SizedBox(width: isTablet ? 8 : 5),

                    premiumIconBtn(
                      Icons.download_rounded,
                      Colors.green,
                      onTap: () {
                        downloadItemImage(user);
                      },
                    ),
                  ],

                  /// =================================================
                  /// EDIT
                  /// =================================================
                  if (canModify &&
                      (hasPermission("item-set-edit") ||
                          hasPermission("item-set-manage"))) ...[
                    SizedBox(width: isTablet ? 8 : 5),

                    premiumIconBtn(
                      Icons.edit_rounded,
                      Colors.blue,
                      onTap: () {
                        openEditDialog(index);
                      },
                    ),
                  ],

                  /// =================================================
                  /// DELETE
                  /// =================================================
                  if (canModify && hasPermission("item-set-delete")) ...[
                    SizedBox(width: isTablet ? 8 : 5),

                    premiumIconBtn(
                      Icons.delete_outline_rounded,
                      Colors.red,
                      onTap: () {
                        if (id > 0) {
                          _showDeleteDialog(user);
                        }
                      },
                    ),
                  ],

                  const SizedBox(width: 5),

                  /// =================================================
                  /// EXPAND BUTTON
                  /// =================================================
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (expandedItemId == id) {
                          /// Same card પર ફરી click
                          /// એટલે close
                          expandedItemId = null;
                        } else {
                          /// બીજો card click થાય
                          /// previous automatically close
                          expandedItemId = id;
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
            /// EXPAND DATA
            /// =====================================================
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),

              firstChild: const SizedBox(width: double.infinity, height: 0),

              secondChild: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),

                child: Column(
                  children: [
                    /// Divider
                    Divider(height: 1, color: AppColors.border),

                    const SizedBox(height: 10),

                    // /// =================================================
                    // /// QR / LABEL CODE
                    // /// =================================================
                    // Container(
                    //   width: double.infinity,
                    //   padding: const EdgeInsets.symmetric(
                    //     horizontal: 10,
                    //     vertical: 8,
                    //   ),
                    //   decoration: BoxDecoration(
                    //     color: AppColors.primaryDark
                    //         .withOpacity(0.04),
                    //     borderRadius: BorderRadius.circular(6),
                    //   ),
                    //
                    //   child: Row(
                    //     children: [
                    //       /// =================================================
                    //       /// METAL
                    //       /// Silver
                    //       /// =================================================
                    //       statusChip(metal),
                    //
                    //       const SizedBox(width: 8),
                    //
                    //       Expanded(
                    //         child: Text(
                    //           qrCode.isEmpty ? "-" : qrCode,
                    //           textAlign: TextAlign.right,
                    //           style: const TextStyle(
                    //             fontSize: 13,
                    //             color: Colors.black,
                    //             fontWeight: FontWeight.w600,
                    //           ),
                    //         ),
                    //       ),
                    //     ],
                    //   ),
                    // ),
                    //
                    // const SizedBox(height: 8),

                    /// =================================================
                    /// ERP DATA
                    /// =================================================
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border, width: 1.2),
                      ),

                      child: Column(
                        children: [
                          /// Gross / Net
                          _erpRow(
                            "Gross",
                            user["gross_weight"]?.toString() ?? "0",
                            "Net",
                            user["net_weight"]?.toString() ?? "0",
                          ),

                          Divider(height: 1, color: AppColors.border),

                          /// Other / OC
                          _erpRow(
                            "O.Wt",
                            user["other"]?.toString() ?? "0",
                            "OC",
                            user["sale_other"]?.toString() ?? "0",
                          ),

                          Divider(height: 1, color: AppColors.border),

                          /// Date / Qty
                          _erpRow(
                            "Date",
                            formatDate(user["created_at"]?.toString() ?? ""),
                            "Qty",
                            "1",
                          ),
                          Divider(height: 1, color: AppColors.border),
                          _erpRow(
                            "Print Date",
                            user["print_date_time"] != null
                                ? formatDateTime(
                              user["print_date_time"].toString(),
                            )
                                : "-",
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

  Widget buildGridCard(Map user, int index) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;
    final isDesktop = size.width >= 1000;
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: EdgeInsets.all(isTablet ? 16 : 12),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// STATUS + ACTIONS ROW
                    /// STATUS + ACTIONS ROW
                    Row(
                      children: [
                        /// DATE (REPLACED STATUS CHIP)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: 20.0,
                            ), // 👈 LEFT SPACE
                            child: Text(
                              formatDate(user["date"]?.toString() ?? ""),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),

                        /// ACTION BUTTONS
                        Row(
                          children: [
                            premiumIconBtn(
                              Icons.edit,
                              Colors.blue,
                              onTap: () async {
                                FocusScope.of(context).unfocus();

                                /// ============================================
                                /// GRID ROW DATA
                                /// ============================================
                                final String itemId =
                                    user["item_id"]?.toString() ?? "";

                                final String itemName =
                                    user["item_name"]?.toString() ?? "";

                                final String rowDate =
                                    user["date"]?.toString() ?? "";

                                /// details_params hoy to eni date prefer karishu
                                final Map<String, dynamic> detailsParams =
                                user["details_params"] is Map
                                    ? Map<String, dynamic>.from(
                                  user["details_params"],
                                )
                                    : {};

                                final String fromDate =
                                    detailsParams["from_date"]?.toString() ??
                                        rowDate;

                                final String toDate =
                                    detailsParams["to_date"]?.toString() ??
                                        rowDate;

                                if (itemId.isEmpty) {
                                  AppMessage.error(
                                    context,
                                    "Item ID not found",
                                  );
                                  return;
                                }

                                debugPrint("================================");
                                debugPrint("GRID EDIT CLICK");
                                debugPrint("ITEM ID   => $itemId");
                                debugPrint("ITEM NAME => $itemName");
                                debugPrint("FROM DATE => $fromDate");
                                debugPrint("TO DATE   => $toDate");
                                debugPrint("================================");

                                /// ============================================
                                /// 1. DROPDOWN MA ITEM AUTO SELECT
                                /// ============================================
                                setState(() {
                                  selectedItem = itemId;

                                  /// Grid -> List
                                  selectedView = "list";

                                  /// Search clear
                                  labelSearchController.clear();

                                  /// Grid ni date filter ma pan set kari do
                                  try {
                                    fromDateController.text = DateFormat(
                                      "dd-MM-yyyy",
                                    ).format(DateTime.parse(fromDate));

                                    toDateController.text = DateFormat(
                                      "dd-MM-yyyy",
                                    ).format(DateTime.parse(toDate));
                                  } catch (e) {
                                    debugPrint("DATE SET ERROR => $e");
                                  }
                                });

                                /// ============================================
                                /// 2. DIRECT LIST API CALL
                                ///
                                /// IMPORTANT:
                                /// itemId direct API ma mokliye chhiye
                                /// ============================================
                                await loadItemDetails(itemId, fromDate, toDate);

                                /// ============================================
                                /// 3. EXTRA LOCAL FILTER NI JARUR NATHI
                                ///
                                /// API already:
                                /// item_id + from + to
                                /// thi filtered response aapse
                                /// ============================================

                                debugPrint("GRID EDIT -> LIST COMPLETE");
                              },
                            ),
                            SizedBox(width: isTablet ? 10 : 8),

                            if (_isMainData(user))
                              premiumIconBtn(
                                Icons.delete,
                                Colors.red,
                                onTap: () {
                                  int id =
                                      int.tryParse(
                                        user["id"]?.toString() ?? "0",
                                      ) ??
                                          0;
                                  if (id > 0) {
                                    _showDeleteDialog(user);
                                    //deleteUser(id.toString());
                                  }
                                },
                              ),

                            SizedBox(width: isTablet ? 10 : 8),

                            pdfBtn(() {
                              openPdf(user["id"]);
                            }),
                          ],
                        ),
                      ],
                    ),

                    SizedBox(height: isTablet ? 10 : 8),

                    Row(
                      children: [
                        Text(
                          user["item_name"]?.toString() ?? "",
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black, // ✅ FIX
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          user["item_code"]?.toString() ?? "",
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black, // ✅ FIX
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    /// 🔥 ERP GRID (MAIN FIX)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        border: Border.all(color: AppColors.border, width: 1.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        children: [
                          _erpRow(
                            "T.Gwt",
                            user["total_gross_weight"]?.toString() ?? "0",
                            "Net",
                            user["total_net_weight"]?.toString() ?? "0",
                          ),

                          Divider(height: 1, color: AppColors.border),

                          _erpRow(
                            "O.Wt",
                            user["total_other_weight"]?.toString() ?? "0",
                            "OC",
                            user["total_other_charges"]?.toString() ?? "0",
                          ),

                          Divider(height: 1, color: AppColors.border),

                          _erpRow(
                            "Date",
                            formatDate(user["date"].toString()),
                            "Qty",
                            user["total_pcs"]?.toString() ?? "0",
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isTablet ? 10 : 8),

                    /// PERMISSIONS
                  ],
                ),
              ),
            ],
          ),
        ),

        /// 🔥 TOP LEFT INDEX BADGE
        Positioned(
          top: 5,
          left: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.gradientBlue,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(5),
                bottomRight: Radius.circular(5),
              ),
            ),
            child: Text(
              "${index + 1}", // 🔥 હવે અહીં સ
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> saveBulkItems() async {
    if (selectedItem == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select item")));
      return;
    }

    List<Map<String, dynamic>> rows = [];

    for (int i = apiRowCount; i < tableRows.length; i++) {
      var row = tableRows[i];

      if (row["gross"]!.text.isEmpty &&
          row["net"]!.text.isEmpty &&
          row["size"]!.text.isEmpty &&
          row["huid"]!.text.isEmpty) {
        continue;
      }

      rows.add({
        "gross_weight": double.tryParse(row["gross"]!.text),
        "other": double.tryParse(row["other"]!.text),
        "net_weight": double.tryParse(row["net"]!.text),
        "labour_rate": double.tryParse(row["labourRate"]!.text),
        "labour_amount": double.tryParse(row["labourAmount"]!.text),
        "size": int.tryParse(row["size"]!.text),
        "HUID": row["huid"]!.text.isNotEmpty ? row["huid"]!.text : null,
      });
    }

    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter at least one row")),
      );
      return;
    }

    Map<String, dynamic> body = {
      "item_id": int.parse(selectedItem!),
      "rows": rows,
    };

    print("📤 REQUEST BODY: $body");

    final response = await ApiHelper().postRequest(
      ApiConstants.multiple_items_label_configs, // 👈 your endpoint
      body,
    );

    if (response != null && response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Multiple rows saved successfully")),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to Save Data")));
    }
  }

  Future<void> savefinalizeBulkItems() async {
    if (selectedItem == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select item")));
      return;
    }

    Map<String, dynamic> body = {"item_id": int.parse(selectedItem!)};

    print("📤 REQUEST BODY: $body");

    final response = await ApiHelper().postRequest(
      ApiConstants.finalize_items_label_configs,
      body,
    );

    if (response != null && response.statusCode == 200) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Saved successfully")));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to Save Data")));
    }
  }

  Future<void> loadItemDetails(
      String itemId,
      String from,
      String to, {
        bool loadMore = false,
        int page = 1,
      }) async {
    try {
      /// Filters yaad rakho — Load More same filters sathe next page mangse
      _lastItemId = itemId;
      _lastFromDate = from;
      _lastToDate = to;

      if (loadMore) {
        if (isLoadingMore) return;
        if (currentPage >= lastPage) return;

        setState(() {
          isLoadingMore = true;
        });
      }

      /// ============================================
      /// API URL (+ page param)
      /// ============================================
      final String url =
          "${ApiConstants.label_item_list}"
          "?item_id=$itemId"
          "&from=$from"
          "&to=$to"
          "&page=$page";

      // 🔥 Branch mode → &management_branches[]=1&management_branches[]=2
      final String branchUrl = _br(url);

      debugPrint("========================================");
      debugPrint("LABEL ITEM API => $url");
      debugPrint("ITEM ID => $itemId");
      debugPrint("FROM => $from");
      debugPrint("TO => $to");
      debugPrint("PAGE => $page");
      debugPrint("========================================");

      debugPrint("LABEL ITEM BRANCH URL => $branchUrl");

      final response = await ApiHelper().getRequest(branchUrl);

      if (response == null) {
        if (!loadMore) {
          AppMessage.error(context, "No response from server");
        }
        return;
      }

      debugPrint("LABEL ITEM RESPONSE => ${response.data}");

      if (response.statusCode == 200 && response.data["data"] != null) {
        final data = response.data;

        final List<dynamic> apiData = data["data"] is List ? data["data"] : [];

        final List<Map<String, dynamic>> categories = apiData
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .toList();

        final DateTime fromDate = DateFormat("yyyy-MM-dd").parse(from);
        final DateTime toDate = DateFormat("yyyy-MM-dd").parse(to);

        final List<Map<String, dynamic>> dateFiltered = categories.where((row) {
          try {
            dynamic rawDate;

            if (row["created_at"] != null) {
              rawDate = row["created_at"];
            } else if (row["date"] != null) {
              rawDate = row["date"];
            } else if (row["voucher_date"] != null) {
              rawDate = row["voucher_date"];
            } else {
              return false;
            }

            if (rawDate == null || rawDate.toString().trim().isEmpty) {
              return false;
            }

            final DateTime parsedDate = DateTime.parse(rawDate.toString());

            final DateTime itemDate = DateTime(
              parsedDate.year,
              parsedDate.month,
              parsedDate.day,
            );

            final DateTime startDate = DateTime(
              fromDate.year,
              fromDate.month,
              fromDate.day,
            );

            final DateTime endDate = DateTime(
              toDate.year,
              toDate.month,
              toDate.day,
            );

            return !itemDate.isBefore(startDate) && !itemDate.isAfter(endDate);
          } catch (e) {
            debugPrint(
              "DATE PARSE ERROR => "
                  "${row["created_at"] ?? row["date"]} | $e",
            );
            return false;
          }
        }).toList();

        List<Map<String, dynamic>> finalData = dateFiltered;

        if (itemId.isNotEmpty) {
          finalData = dateFiltered.where((row) {
            return row["item_id"]?.toString() == itemId.toString();
          }).toList();
        }

        /// ============================================
        /// PAGINATION
        /// ============================================
        final Map<String, dynamic> pagination = data["pagination"] is Map
            ? Map<String, dynamic>.from(data["pagination"])
            : {};

        final int apiCurrentPage =
            int.tryParse(pagination["current_page"]?.toString() ?? "1") ?? page;

        final int apiLastPage =
            int.tryParse(pagination["last_page"]?.toString() ?? "1") ?? 1;

        debugPrint("API TOTAL DATA => ${categories.length}");
        debugPrint("DATE FILTERED DATA => ${dateFiltered.length}");
        debugPrint("FINAL DATA => ${finalData.length}");
        debugPrint("PAGE => $apiCurrentPage / $apiLastPage");

        if (!mounted) return;

        setState(() {
          currentPage = apiCurrentPage;
          lastPage = apiLastPage;

          if (loadMore) {
            /// New page's filtered rows APPEND karo
            allLabelItems.addAll(finalData);
            searchResults.addAll(finalData);
            userlist.addAll(finalData);
            allUsers.addAll(finalData);
          } else {
            tableRows.clear();

            allLabelItems = List<Map<String, dynamic>>.from(finalData);
            searchResults = List<Map<String, dynamic>>.from(finalData);
            userlist = List.from(finalData);
            allUsers = List.from(finalData);

            labelSearchController.clear();
          }
        });

        if (!loadMore) {
          AppMessage.success(
            context,
            data["message"] ?? "Data Loaded Successfully",
          );
        }
      } else {
        if (!mounted) return;

        if (!loadMore) {
          setState(() {
            tableRows.clear();
            allLabelItems.clear();
            searchResults.clear();
            userlist = [];
            allUsers = [];
          });

          AppMessage.error(
            context,
            response.data?["message"] ?? "Failed to load data",
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint("LOAD LABEL ITEM ERROR => $e");
      debugPrint("STACK TRACE => $stackTrace");

      if (!loadMore) {
        AppMessage.error(context, "Something went wrong");
      }
    } finally {
      if (mounted && loadMore) {
        setState(() {
          isLoadingMore = false;
        });
      }
    }
  }

  Future<void> loadbulkItemDetails(String itemId) async {
    try {
      debugPrint("🔥 BULK API => ${ApiConstants.label_item_bulk_list}");

      // 🔥 Branch mode → ?management_branches[]=1&management_branches[]=2
      final String bulkUrl = _br(ApiConstants.label_item_bulk_list);
      debugPrint("🔥 BULK BRANCH URL => $bulkUrl");

      final response = await ApiHelper().getRequest(bulkUrl);

      if (response == null) {
        AppMessage.error(context, "No response from server");
        return;
      }

      debugPrint("🔥 BULK RESPONSE => ${response.data}");

      if (response.statusCode == 200 &&
          response.data["data"] != null &&
          response.data["data"] is List) {
        final List<dynamic> apiData = response.data["data"];

        final List<Map<String, dynamic>> categories = apiData
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .toList();

        /// ============================================
        /// FROM / TO DATE
        /// ============================================

        final DateTime fromDate = DateFormat(
          "dd-MM-yyyy",
        ).parse(fromDateController.text);

        final DateTime toDate = DateFormat(
          "dd-MM-yyyy",
        ).parse(toDateController.text);

        /// Only date part
        final DateTime startDate = DateTime(
          fromDate.year,
          fromDate.month,
          fromDate.day,
        );

        final DateTime endDate = DateTime(
          toDate.year,
          toDate.month,
          toDate.day,
        );

        debugPrint("🔥 GRID FROM => $startDate");

        debugPrint("🔥 GRID TO => $endDate");

        /// ============================================
        /// DATE FILTER
        /// ============================================

        List<Map<String, dynamic>> filteredData = categories.where((row) {
          try {
            /// Bulk response:
            ///
            /// date: 2026-08-12
            ///
            final String rawDate = row["date"]?.toString() ?? "";

            if (rawDate.isEmpty) {
              return false;
            }

            final DateTime parsed = DateTime.parse(rawDate);

            final DateTime itemDate = DateTime(
              parsed.year,
              parsed.month,
              parsed.day,
            );

            /// Inclusive date range
            return !itemDate.isBefore(startDate) && !itemDate.isAfter(endDate);
          } catch (e) {
            debugPrint(
              "❌ GRID DATE ERROR => "
                  "${row["date"]} | $e",
            );

            return false;
          }
        }).toList();

        debugPrint(
          "🔥 BULK TOTAL BEFORE DATE FILTER => "
              "${categories.length}",
        );

        debugPrint(
          "🔥 BULK TOTAL AFTER DATE FILTER => "
              "${filteredData.length}",
        );

        /// ============================================
        /// ITEM FILTER
        /// ============================================

        if (itemId.isNotEmpty) {
          filteredData = filteredData.where((row) {
            return row["item_id"]?.toString() == itemId.toString();
          }).toList();

          debugPrint("🔥 GRID ITEM ID => $itemId");

          debugPrint(
            "🔥 AFTER ITEM FILTER => "
                "${filteredData.length}",
          );
        }

        if (!mounted) return;

        /// ============================================
        /// UPDATE UI
        /// ============================================

        setState(() {
          tableRows.clear();

          /// IMPORTANT:
          /// Grid mate filtered data j store karvu
          allUsers = List.from(filteredData);

          userlist = List.from(filteredData);

          searchResults = List<Map<String, dynamic>>.from(filteredData);

          labelSearchController.clear();
        });

        AppMessage.success(
          context,
          response.data["message"] ?? "Bulk Data Loaded Successfully",
        );
      } else {
        if (!mounted) return;

        setState(() {
          tableRows.clear();

          userlist = [];
          allUsers = [];
          searchResults = [];
        });

        AppMessage.error(
          context,
          response.data?["message"] ?? "Failed to load bulk data",
        );
      }
    } catch (e, stackTrace) {
      debugPrint("❌ BULK LOAD ERROR => $e");

      debugPrint("❌ STACK => $stackTrace");

      AppMessage.error(context, "Something went wrong");
    }
  }

  /// =========================================================
  /// 📄 EXPORT — PDF / EXCEL (getPdfRequest → bytes)
  /// label_item_list?item_id=..&from=..&to=..&management_branches[]=1&export=pdf
  /// =========================================================

  static String get _exportUrl => ApiConstants.label_item_list;

  /// "pdf" / "excel" chalu hoy tyare (bijo tap na thay)
  String? _exporting;

  Future<void> _export(String type) async {
    if (_exporting != null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _exporting = type);

    try {
      // List ma je item + date + branch chhe e j export ma pan
      String base = "$_exportUrl"
          "?item_id=$_lastItemId"
          "&from=$_lastFromDate"
          "&to=$_lastToDate";
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
      final file = File("${dir.path}/Label_Items_$stamp.$ext");
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


  Future<void> deleteUser(String id) async {
    try {
      final response = await ApiHelper().deleteRequest(
        "${ApiConstants.label_item_delete}/$id",
      );

      if (!mounted) return;

      await _handleDeleteResponse(response?.statusCode, response?.data);
    } on DioException catch (e) {
      /// ApiHelper 409 ને exception તરીકે ફેંકે તો પણ message બતાવો
      debugPrint("❌ DELETE DIO ERROR => ${e.response?.statusCode} ${e.response?.data}");

      if (!mounted) return;

      await _handleDeleteResponse(e.response?.statusCode, e.response?.data);
    } catch (e) {
      debugPrint("❌ DELETE ERROR => $e");

      if (!mounted) return;

      await _showMessageDialog(
        title: "Delete Failed",
        message: "Something went wrong. Please try again.",
      );
    }
  }

  /// 🔥 Delete response — success / 409 / બીજી error
  Future<void> _handleDeleteResponse(int? statusCode, dynamic data) async {
    final Map body = data is Map ? data : {};

    final bool isSuccess = (statusCode == 200 || statusCode == 204) &&
        body["success"] != false &&
        body["status"] != false;

    /// ✅ SUCCESS
    if (isSuccess) {
      AppMessage.success(
        context,
        body["message"]?.toString() ?? "Item deleted successfully",
      );
      await _reloadCurrentList();
      return;
    }

    /// ❌ ERROR (409 ITEM_ALREADY_USED વગેરે)
    final String code = body["code"]?.toString() ?? "";
    final String message =
        body["message"]?.toString() ?? "Failed to delete item";

    await _showMessageDialog(
      title: code == "ITEM_ALREADY_USED" ? "Item Already Used" : "Delete Failed",
      message: message,
    );

    /// Server એ "Please reload" કહ્યું → OK પછી fresh list
    if (code == "ITEM_ALREADY_USED" && mounted) {
      await _reloadCurrentList();
    }
  }

  /// 🔄 હાલના filters (item + date) સાથે list ફરી લાવો
  Future<void> _reloadCurrentList() async {
    if (selectedView == "grid") {
      await loadbulkItemDetails(selectedItem ?? "");
      return;
    }

    // ✅ Date khotu / khali hoy to crash nahi
    String from = _lastFromDate;
    String to = _lastToDate;
    try {
      from = DateFormat("yyyy-MM-dd")
          .format(DateFormat("dd-MM-yyyy").parse(fromDateController.text));
      to = DateFormat("yyyy-MM-dd")
          .format(DateFormat("dd-MM-yyyy").parse(toDateController.text));
    } catch (_) {}

    await loadItemDetails(selectedItem ?? "", from, to);
  }

  void openEditDialog(int index) {
    var row = userlist[index];

    TextEditingController grossController = TextEditingController(
      text: row["gross_weight"]?.toString() ?? "",
    );

    TextEditingController otherController = TextEditingController(
      text: row["other"]?.toString() ?? "",
    );

    TextEditingController netController = TextEditingController(
      text: row["net_weight"]?.toString() ?? "",
    );

    TextEditingController sizeController = TextEditingController(
      text: row["size"]?.toString() ?? "",
    );

    TextEditingController huidController = TextEditingController(
      text: row["sale_other"]?.toString() ?? "",
    );

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
          ),

          child: Container(
            width: 350,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              //border: Border.all(color: Colors.white24),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.15),
                  Colors.white.withOpacity(0.05),
                ],
              ),
            ),
            child: SingleChildScrollView(
              // ✅ FIX OVERFLOW
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  /// Title
                  const Text(
                    "Edit Item",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 15),

                  _glassField("Gross Weight", grossController),
                  const SizedBox(height: 10),

                  _glassField("Other", otherController),
                  const SizedBox(height: 10),

                  _glassField("Net Weight", netController, readOnly: true),
                  const SizedBox(height: 10),

                  _glassField("Size", sizeController),
                  const SizedBox(height: 10),

                  _glassField("Other Charge", huidController),

                  const SizedBox(height: 20),

                  /// Buttons
                  Row(
                    children: [
                      /// ❌ Cancel Button
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            height: 45,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade700),
                              color: Colors.white.withOpacity(0.05),
                            ),
                            child: const Text(
                              "Cancel",
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      /// ✅ Save Button (Glass + Gradient)
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            setState(() {
                              row["gross_weight"] = grossController.text;
                              row["other_weight"] = otherController.text;
                              row["net_weight"] = netController.text;
                              row["size"] = sizeController.text;
                              row["sale_other"] = huidController.text;
                            });

                            Navigator.pop(context);

                            updateItem(row);
                          },

                          child: Container(
                            height: 45,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: const LinearGradient(
                                colors: [Color(0xffC9A44A), Color(0xffE6C36A)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Text(
                              "Save",
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
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
    );

    /// 🔥 Auto Net Calculation
    void calculate() {
      double gross = double.tryParse(grossController.text) ?? 0;
      double other = double.tryParse(otherController.text) ?? 0;
      netController.text = (gross - other).toStringAsFixed(3);
    }

    grossController.addListener(calculate);
    otherController.addListener(calculate);
  }

  Widget _glassField(
      String label,
      TextEditingController controller, {
        bool readOnly = false,
      }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          //border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: TextField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.black),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> updateItem(Map<String, dynamic> row) async {
    try {
      int id = int.tryParse(row["id"]?.toString() ?? "0") ?? 0;

      if (id == 0) {
        print("❌ Invalid ID");
        return;
      }

      Map<String, dynamic> body = {
        "gross_weight": row["gross_weight"]?.toString() ?? "0",
        "other": row["other_weight"]?.toString() ?? "0",
        "net_weight": row["net_weight"]?.toString() ?? "0",
        "size": row["size"]?.toString() ?? "",
        "other_charges": row["sale_other"]?.toString() ?? "",
      };

      final response = await ApiHelper().postRequest(
        "${ApiConstants.label_item_update}/$id",
        body,
      );

      print(body);
      print("${ApiConstants.label_item_update}/$id");

      if (response != null && response.statusCode == 200) {
        print("✅ Updated Successfully");
        String from = DateFormat(
          "yyyy-MM-dd",
        ).format(DateFormat("dd-MM-yyyy").parse(fromDateController.text));

        String to = DateFormat(
          "yyyy-MM-dd",
        ).format(DateFormat("dd-MM-yyyy").parse(toDateController.text));
        loadItemDetails("", from, to);
      } else {
        print("❌ Update Failed");
      }
    } catch (e) {
      print("❌ Update Error: $e");
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
          /// =========================================================
          /// ITEM DROPDOWN
          /// =========================================================
          Consumer<ItemProvider>(
            builder: (context, provider, child) {
              final List<Map<String, dynamic>> itemList = provider.items
                  .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
                  .toList();

              /// CURRENT SELECTED ITEM
              Map<String, dynamic>? selectedDropdownItem;

              if (selectedItem != null) {
                for (final e in itemList) {
                  if (e["id"]?.toString() == selectedItem) {
                    selectedDropdownItem = e;
                    break;
                  }
                }
              }

              return Stack(
                alignment: Alignment.centerRight,
                children: [
                  PremiumSearchableDropdown<Map<String, dynamic>>(
                    label: "",
                    hint: "Select Item",
                    items: itemList,
                    value: selectedDropdownItem,
                    prefixIcon: Icons.inventory_2_outlined,
                    dropdownMaxHeight: 350,

                    itemLabel: (item) => item["item_name"]?.toString() ?? "-",

                    /// SEARCH — Name / Code / Metal / ID
                    searchText: (item) {
                      return [
                        item["item_name"]?.toString() ?? "",
                        item["item_code"]?.toString() ?? "",
                        item["metal"]?.toString() ?? "",
                        item["id"]?.toString() ?? "",
                      ].join(" ");
                    },

                    onChanged: (item) => _setItemFilter(item),
                  ),

                  /// ❌ CLEAR — item select હોય ત્યારે જ
                  if (selectedDropdownItem != null)
                    Positioned(
                      right: 40, // 🔥 arrow થી અંતર — જરૂર મુજબ 32–48 કરો
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            _setItemFilter(null);
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

          const SizedBox(height: 8),

          /// =========================================================
          /// LABEL SEARCH
          /// =========================================================
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: labelSearchController,

              /// 🔥 IMPORTANT
              focusNode: labelSearchFocusNode,

              /// Keyboard config
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.search,

              autocorrect: false,
              enableSuggestions: false,

              style: const TextStyle(color: Colors.black, fontSize: 14),

              /// ==========================================
              /// IMPORTANT
              /// Debounced search
              /// ==========================================
              onChanged: searchByLabel,

              onSubmitted: (value) {
                _labelSearchTimer?.cancel();

                /// Immediate search
                searchByLabel(value);
              },

              decoration: InputDecoration(
                hintText: selectedItem == null
                    ? "Select Item First"
                    : "Search QR / Label / HUID",

                hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),

                prefixIcon: const Icon(
                  Icons.search,
                  size: 20,
                  color: AppColors.primaryDark,
                ),

                /// ❌ suffixIcon dynamic condition remove
                ///
                /// labelSearchController.text.isNotEmpty
                /// check karva mate screen rebuild karvi padti hati.
                ///
                /// Always clear icon rakhie.
                suffixIcon: IconButton(
                  splashRadius: 18,
                  onPressed: () {
                    _labelSearchTimer?.cancel();

                    labelSearchController.clear();

                    searchByLabel("");

                    FocusScope.of(context).unfocus();
                  },
                  icon: Icon(
                    Icons.close,
                    size: 19,
                    color: Colors.grey.shade600,
                  ),
                ),

                border: InputBorder.none,

                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          /// =========================================================
          /// DATE ROW
          /// =========================================================
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

          /// =========================================================
          /// SHOW + LIST / GRID VIEW ROW
          /// =========================================================
          Row(
            children: [
              /// =====================================================
              /// SHOW BUTTON
              /// =====================================================
              Expanded(
                child: SizedBox(
                  height: 45,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      FocusScope.of(context).unfocus();

                      _labelSearchTimer?.cancel();
                      labelSearchController.clear();

                      if (fromDateController.text.isEmpty ||
                          toDateController.text.isEmpty) {
                        AppMessage.error(
                          context,
                          "Please select From Date and To Date",
                        );
                        return;
                      }

                      try {
                        final String from = DateFormat("yyyy-MM-dd").format(
                          DateFormat(
                            "dd-MM-yyyy",
                          ).parse(fromDateController.text),
                        );

                        final String to = DateFormat("yyyy-MM-dd").format(
                          DateFormat("dd-MM-yyyy").parse(toDateController.text),
                        );

                        final DateTime fromDate = DateTime.parse(from);

                        final DateTime toDate = DateTime.parse(to);

                        if (fromDate.isAfter(toDate)) {
                          AppMessage.error(
                            context,
                            "From Date cannot be greater than To Date",
                          );
                          return;
                        }

                        debugPrint("==========================");
                        debugPrint("VIEW => $selectedView");
                        debugPrint("ITEM => ${selectedItem ?? ""}");
                        debugPrint("FROM => $from");
                        debugPrint("TO => $to");
                        debugPrint("==========================");

                        if (selectedView == "list") {
                          /// LIST API
                          await loadItemDetails(selectedItem ?? "", from, to);
                        } else {
                          /// GRID / BULK API
                          await loadbulkItemDetails(selectedItem ?? "");
                        }
                      } catch (e) {
                        debugPrint("SHOW ERROR => $e");

                        AppMessage.error(context, "Invalid date");
                      }
                    },

                    icon: const Icon(
                      Icons.filter_alt_outlined,
                      size: 19,
                      color: Colors.white,
                    ),

                    label: const Text(
                      "SHOW",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              /// =====================================================
              /// LIST / GRID VIEW
              /// =====================================================
              Expanded(
                child: Row(
                  children: [
                    /// =================================================
                    /// LIST VIEW
                    /// =================================================
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          /// Keyboard close
                          FocusScope.of(context).unfocus();

                          /// First UI change
                          setState(() {
                            selectedView = "list";
                          });

                          /// Date convert
                          final String from = DateFormat("yyyy-MM-dd").format(
                            DateFormat(
                              "dd-MM-yyyy",
                            ).parse(fromDateController.text),
                          );

                          final String to = DateFormat("yyyy-MM-dd").format(
                            DateFormat(
                              "dd-MM-yyyy",
                            ).parse(toDateController.text),
                          );

                          /// LIST API CALL
                          await loadItemDetails("", from, to);

                          /// Selected item hoy to filter
                          if (selectedItem != null &&
                              selectedItem!.isNotEmpty) {
                            filterByItem(selectedItem);
                          }
                        },

                        borderRadius: BorderRadius.circular(5),

                        child: Container(
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: selectedView == "list"
                                ? LinearGradient(
                              colors: [
                                AppColors.gradientBlue.withOpacity(0.7),
                                AppColors.border.withOpacity(0.7),
                                AppColors.secondaryDark.withOpacity(0.7),
                              ],
                            )
                                : null,

                            color: selectedView == "list"
                                ? null
                                : Colors.grey.shade200,

                            borderRadius: BorderRadius.circular(5),

                            border: Border.all(
                              color: selectedView == "list"
                                  ? AppColors.iconBlue
                                  : Colors.grey.shade300,
                            ),
                          ),

                          child: Icon(
                            Icons.view_list_rounded,
                            size: 22,
                            color: selectedView == "list"
                                ? Colors.black
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    /// =================================================
                    /// GRID VIEW
                    /// =================================================
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          /// Keyboard close
                          FocusScope.of(context).unfocus();

                          /// Search timer cancel
                          _labelSearchTimer?.cancel();

                          /// Search clear
                          labelSearchController.clear();

                          /// Grid view active
                          setState(() {
                            selectedView = "grid";
                          });

                          /// =========================================
                          /// DATE CONVERT
                          /// dd-MM-yyyy -> yyyy-MM-dd
                          /// =========================================
                          final String from = DateFormat("yyyy-MM-dd").format(
                            DateFormat(
                              "dd-MM-yyyy",
                            ).parse(fromDateController.text),
                          );

                          final String to = DateFormat("yyyy-MM-dd").format(
                            DateFormat(
                              "dd-MM-yyyy",
                            ).parse(toDateController.text),
                          );

                          /// =========================================
                          /// BULK API CALL
                          /// =========================================
                          await loadbulkItemDetails(selectedItem ?? "");

                          /// ❌ IMPORTANT
                          /// Ahiya filterByItem(selectedItem) call
                          /// karvano nathi.
                          ///
                          /// Bulk API already required data ape che.
                        },

                        borderRadius: BorderRadius.circular(5),

                        child: Container(
                          height: 42,
                          alignment: Alignment.center,

                          decoration: BoxDecoration(
                            gradient: selectedView == "grid"
                                ? LinearGradient(
                              colors: [
                                AppColors.gradientBlue.withOpacity(0.7),
                                AppColors.border.withOpacity(0.7),
                                AppColors.secondaryDark.withOpacity(0.7),
                              ],
                            )
                                : null,

                            color: selectedView == "grid"
                                ? null
                                : Colors.grey.shade200,

                            borderRadius: BorderRadius.circular(5),

                            border: Border.all(
                              color: selectedView == "grid"
                                  ? AppColors.iconBlue
                                  : Colors.grey.shade300,
                            ),
                          ),

                          child: Icon(
                            Icons.grid_view_rounded,
                            size: 21,
                            color: selectedView == "grid"
                                ? Colors.black
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          /// TAMARO EXISTING SHOW / LIST / GRID ROW
          /// ahi same code rakhvano
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
      String? dateValue;

      if (user["created_at"] != null) {
        dateValue = user["created_at"].toString();
      } else if (user["date"] != null) {
        dateValue = user["date"].toString();
      } else {
        return false;
      }

      DateTime userDate = DateTime.parse(dateValue);

      return userDate.isAfter(fromDate.subtract(const Duration(days: 1))) &&
          userDate.isBefore(toDate.add(const Duration(days: 1)));
    }).toList();

    setState(() {
      userlist = filtered;
    });
  }

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

    return Padding(
      padding: const EdgeInsets.only(left: 15.0),
      child: Container(
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
      ApiConstants.item_sets_pdf,
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

  String getText(dynamic value) {
    if (value is TextEditingController) {
      return value.text;
    } else if (value is String) {
      return value;
    } else {
      return "";
    }
  }

  Widget buildSummaryRow() {
    final totals = calculateTotals();
    final gridTotals = calculateTotals1();

    final data = selectedView == "grid" ? gridTotals : totals;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border, width: 1.5),
        //borderRadius: BorderRadius.circular(6),
      ),

      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,

        child: Row(
          children: [
            _summaryBox("Gross", data["gross"]!.toStringAsFixed(3)),

            const SizedBox(width: 5),

            _summaryBox("Other", data["other"]!.toStringAsFixed(3)),

            const SizedBox(width: 5),

            _summaryBox("Net", data["net"]!.toStringAsFixed(3)),

            const SizedBox(width: 5),

            _summaryBox("OC", data["otherAmt"]!.toStringAsFixed(2)),
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
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
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

  Map<String, double> calculateTotals() {
    double gross = 0;
    double other = 0;
    double net = 0;
    double oc = 0;
    double qty = 0;

    for (var item in userlist) {
      gross += double.tryParse(item["gross_weight"]?.toString() ?? "0") ?? 0;

      other += double.tryParse(item["other"]?.toString() ?? "0") ?? 0;

      net += double.tryParse(item["net_weight"]?.toString() ?? "0") ?? 0;

      oc += double.tryParse(item["sale_other"]?.toString() ?? "0") ?? 0;

      qty += 1;
    }

    return {
      "gross": gross,

      "other": other,

      "net": net,

      "otherAmt": oc,

      "qty": qty,
    };
  }

  Map<String, double> calculateTotals1() {
    double gross = 0;
    double other = 0;
    double net = 0;
    double oc = 0;
    double qty = 0;

    for (var item in userlist) {
      gross +=
          double.tryParse(item["total_gross_weight"]?.toString() ?? "0") ?? 0;

      other +=
          double.tryParse(item["total_other_weight"]?.toString() ?? "0") ?? 0;

      net += double.tryParse(item["total_net_weight"]?.toString() ?? "0") ?? 0;

      oc +=
          double.tryParse(item["total_other_charges"]?.toString() ?? "0") ?? 0;

      qty += 1;
    }

    return {
      "gross": gross,

      "other": other,

      "net": net,

      "otherAmt": oc,

      "qty": qty,
    };
  }

  void filterByItem(String? itemId) {
    /// Search timer cancel
    _labelSearchTimer?.cancel();

    /// Search clear
    labelSearchController.clear();

    List<Map<String, dynamic>> filteredList;

    if (itemId == null || itemId.isEmpty) {
      filteredList = List<Map<String, dynamic>>.from(allLabelItems);
    } else {
      filteredList = allLabelItems.where((row) {
        return row["item_id"]?.toString() == itemId.toString();
      }).toList();
    }

    setState(() {
      searchResults = List<Map<String, dynamic>>.from(filteredList);

      userlist = List.from(filteredList);
    });
  }

  void _showDeleteDialog(Map user) {
    final String itemName =
    (user["item"]?["item_name"] ?? user["item_name"] ?? "Item").toString();
    final String qrCode = user["qr_code"]?.toString().trim() ?? "";
    final String gross = user["gross_weight"]?.toString() ?? "";

    showGeneralDialog(
      context: context,
      barrierLabel: "Delete",
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.45),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, anim1, anim2) {
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
                    /// =============================================
                    /// BLUE GRADIENT HEADER
                    /// =============================================
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
                            "Delete Item?",
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

                    /// =============================================
                    /// ITEM DETAILS
                    /// =============================================
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
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.gradientBlue.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.inventory_2_outlined,
                                size: 20,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    itemName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      if (qrCode.isNotEmpty) ...[
                                        const Icon(
                                          Icons.qr_code_2_rounded,
                                          size: 13,
                                          color: AppColors.primaryDark,
                                        ),
                                        const SizedBox(width: 3),
                                        Flexible(
                                          child: Text(
                                            qrCode,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primaryDark,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (qrCode.isNotEmpty && gross.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                          ),
                                          child: Text(
                                            "•",
                                            style: TextStyle(
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                        ),
                                      if (gross.isNotEmpty)
                                        Text(
                                          "Gross: $gross",
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                    ],
                                  ),
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
                        "Are you sure you want to delete this item?",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    /// =============================================
                    /// BUTTONS
                    /// =============================================
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppColors.border),
                        ),
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
                                    deleteUser(user["id"].toString());
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

  void searchByLabel(String value) {
    /// Previous search cancel
    _labelSearchTimer?.cancel();

    /// 250ms wait - typing smooth rehse
    _labelSearchTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;

      final String query = value.trim().toLowerCase();

      /// ==========================================
      /// FIRST FILTER BY SELECTED ITEM
      /// ==========================================

      List<Map<String, dynamic>> baseList;

      if (selectedItem != null && selectedItem!.isNotEmpty) {
        baseList = allLabelItems.where((row) {
          return row["item_id"]?.toString() == selectedItem.toString();
        }).toList();
      } else {
        baseList = List<Map<String, dynamic>>.from(allLabelItems);
      }

      /// ==========================================
      /// EMPTY SEARCH
      /// ==========================================

      if (query.isEmpty) {
        setState(() {
          searchResults = List<Map<String, dynamic>>.from(baseList);

          userlist = List.from(baseList);
        });

        return;
      }

      /// ==========================================
      /// SEARCH
      /// ==========================================

      final List<Map<String, dynamic>> filtered = baseList.where((row) {
        final String qrCode =
            row["qr_code"]?.toString().trim().toLowerCase() ?? "";

        final String barcode =
            row["barcode"]?.toString().trim().toLowerCase() ?? "";

        final String serialNo =
            row["serial_no"]?.toString().trim().toLowerCase() ?? "";

        final String huid =
            (row["HUID"] ?? row["huid"])?.toString().trim().toLowerCase() ?? "";

        /// Nested item
        final Map<String, dynamic> item = row["item"] is Map
            ? Map<String, dynamic>.from(row["item"])
            : {};

        final String itemName =
            item["item_name"]?.toString().trim().toLowerCase() ?? "";

        final String itemCode =
            item["item_code"]?.toString().trim().toLowerCase() ?? "";

        /// ========================================
        /// LABEL SEARCH
        /// ========================================

        return qrCode == query ||
            barcode == query ||
            huid == query ||
            serialNo == query ||
            itemName.contains(query) ||
            itemCode.contains(query);
      }).toList();

      if (!mounted) return;

      setState(() {
        searchResults = filtered;
        userlist = List.from(filtered);
      });

      debugPrint("SEARCH QUERY => $query");

      debugPrint("FOUND => ${filtered.length}");
    });
  }

  @override
  void dispose() {
    _labelSearchTimer?.cancel();
    _huidTimer?.cancel();

    searchController.dispose();
    fromDateController.dispose();
    toDateController.dispose();
    labelSearchController.dispose();

    super.dispose();
  }

  void openImageUploadBottomSheet(Map user) {
    /// Every time new item open thay tyare
    /// previous selected local image clear
    selectedImageFile = null;

    final String itemName =
        user["item"]?["item_name"]?.toString() ??
            user["item_name"]?.toString() ??
            "";

    final String labelCode =
        user["qr_code"]?.toString() ?? user["label_code"]?.toString() ?? "";

    final String imageUrl = user["image_url"]?.toString().trim() ?? "";

    final String uploadedAt =
        user["image_uploaded_at_formatted"]?.toString().trim() ??
            user["image_uploaded_at"]?.toString().trim() ??
            "";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    /// ==========================================
                    /// HEADER
                    /// ==========================================
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.image_outlined,
                            color: AppColors.primaryDark,
                          ),

                          const SizedBox(width: 8),

                          const Text(
                            "Item Image",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),

                          const Spacer(),

                          InkWell(
                            onTap: () async {
                              FocusScope.of(context).unfocus();

                              await Future.delayed(
                                const Duration(milliseconds: 150),
                              );

                              if (!mounted) return;
                              Navigator.pop(bottomSheetContext);
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.close, color: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Divider(height: 1, color: AppColors.border),

                    /// ==========================================
                    /// BODY
                    /// ==========================================
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// ====================================
                            /// IMAGE PREVIEW
                            /// ====================================
                            Container(
                              width: double.infinity,
                              height: 260,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child:
                                /// =========================================
                                /// NEW SELECTED IMAGE
                                /// =========================================
                                selectedImageFile != null
                                    ? Image.file(
                                  selectedImageFile!,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.contain,
                                )
                                /// =========================================
                                /// API EXISTING IMAGE
                                /// =========================================
                                    : imageUrl.isNotEmpty
                                    ? Image.network(
                                  imageUrl,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.contain,

                                  /// Loading
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) {
                                      return child;
                                    }

                                    return const Center(
                                      child:
                                      CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    );
                                  },

                                  /// Invalid / unavailable image
                                  errorBuilder:
                                      (context, error, stackTrace) {
                                    debugPrint(
                                      "IMAGE LOAD ERROR => $error",
                                    );

                                    debugPrint(
                                      "IMAGE URL => $imageUrl",
                                    );

                                    return _noImageWidget();
                                  },
                                )
                                /// =========================================
                                /// NO IMAGE
                                /// =========================================
                                    : _noImageWidget(),
                              ),
                            ),

                            const SizedBox(height: 18),

                            /// ====================================
                            /// ITEM
                            /// ====================================
                            _imageInfoField(title: "Item", value: itemName),

                            const SizedBox(height: 12),

                            /// ====================================
                            /// LABEL CODE
                            /// ====================================
                            _imageInfoField(
                              title: "Label Code",
                              value: labelCode,
                            ),

                            const SizedBox(height: 16),

                            /// ====================================
                            /// UPLOAD IMAGE TITLE
                            /// ====================================
                            const Text(
                              "Upload Image",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),

                            const SizedBox(height: 7),

                            /// ====================================
                            /// CHOOSE IMAGE
                            /// ====================================
                            InkWell(
                              onTap: () {
                                /// Camera / Gallery popup
                                showImageSourceOptions(setSheetState);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: double.infinity,
                                height: 48,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryDark
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.add_photo_alternate_outlined,
                                        size: 20,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),

                                    const SizedBox(width: 10),

                                    /// =============================
                                    /// FILE NAME
                                    /// =============================
                                    Expanded(
                                      child: Text(
                                        selectedImageFile == null
                                            ? "Choose Image"
                                            : selectedImageFile!.path
                                            .split("/")
                                            .last,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: selectedImageFile == null
                                              ? Colors.black87
                                              : AppColors.primaryDark,
                                          fontWeight: selectedImageFile == null
                                              ? FontWeight.normal
                                              : FontWeight.w600,
                                        ),
                                      ),
                                    ),

                                    Icon(
                                      selectedImageFile == null
                                          ? Icons.chevron_right
                                          : Icons.check_circle,
                                      color: selectedImageFile == null
                                          ? Colors.grey.shade600
                                          : Colors.green,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 6),

                            Text(
                              "JPG, PNG or WebP up to 20 MB.",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),

                            /// ====================================
                            /// SELECTED IMAGE REMOVE
                            /// ====================================
                            if (selectedImageFile != null) ...[
                              const SizedBox(height: 10),

                              InkWell(
                                onTap: () {
                                  setSheetState(() {
                                    selectedImageFile = null;
                                  });
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.red.withOpacity(0.30),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.close,
                                        size: 17,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        "Remove Selected Image",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.red,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],

                            /// ====================================
                            /// UPLOADED DATE
                            /// ====================================
                            if (uploadedAt.isNotEmpty) ...[
                              const SizedBox(height: 16),

                              _imageInfoField(
                                title: "Uploaded",
                                value: formatUploadedDate(uploadedAt),
                              ),
                            ],

                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),

                    /// ==========================================
                    /// BOTTOM BUTTONS
                    /// ==========================================
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          /// =====================================
                          /// REMOVE EXISTING SERVER IMAGE
                          /// =====================================
                          if (imageUrl.isNotEmpty)
                            Expanded(
                              child: SizedBox(
                                height: 46,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();

                                    final bool success = await removeItemImage(
                                      user,
                                    );

                                    if (!mounted) return;

                                    if (success) {
                                      /// Local UI mathi image remove
                                      setState(() {
                                        user["image"] = null;
                                        user["image_url"] = null;
                                      });

                                      // અથવા
                                      // await loadItems();
                                    }
                                  },

                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 19,
                                    color: Colors.white,
                                  ),

                                  label: const Text(
                                    "Remove",
                                    style: TextStyle(color: Colors.white),
                                  ),

                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          if (imageUrl.isNotEmpty) const SizedBox(width: 8),

                          // /// =====================================
                          // /// CANCEL
                          // /// =====================================
                          // Expanded(
                          //   child: SizedBox(
                          //     height: 46,
                          //     child: OutlinedButton(
                          //       onPressed: () {
                          //         Navigator.pop(
                          //           bottomSheetContext,
                          //         );
                          //       },
                          //       style:
                          //       OutlinedButton.styleFrom(
                          //         side: BorderSide(
                          //           color: AppColors.border,
                          //         ),
                          //         shape:
                          //         RoundedRectangleBorder(
                          //           borderRadius:
                          //           BorderRadius.circular(
                          //             7,
                          //           ),
                          //         ),
                          //       ),
                          //       child: const Text(
                          //         "Cancel",
                          //         style: TextStyle(
                          //           color: Colors.black,
                          //         ),
                          //       ),
                          //     ),
                          //   ),
                          // ),
                          //
                          // const SizedBox(width: 8),

                          /// =====================================
                          /// UPLOAD
                          /// =====================================
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  if (selectedImageFile == null) {
                                    AppMessage.error(
                                      context,
                                      "Please choose image",
                                    );

                                    return;
                                  }

                                  debugPrint("ITEM => $itemName");

                                  debugPrint("LABEL => $labelCode");

                                  debugPrint(
                                    "IMAGE => ${selectedImageFile!.path}",
                                  );

                                  /// =================================
                                  /// API CALL LATER
                                  /// =================================

                                  uploadItemImage(user, selectedImageFile!);
                                },
                                icon: const Icon(
                                  Icons.cloud_upload_outlined,
                                  size: 19,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  "Submit",
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryDark,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(7),
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
    ).whenComplete(() {
      /// Sheet close thay pachi temporary image clear
      selectedImageFile = null;
    });
  }

  Widget _imageInfoField({required String title, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),

        const SizedBox(height: 5),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            value.isEmpty ? "-" : value,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _noImageWidget() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 45,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            "No Image",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  String formatUploadedDate(String value) {
    try {
      final date = DateTime.parse(value);

      return DateFormat("dd-MM-yyyy hh:mm a").format(date);
    } catch (e) {
      return value;
    }
  }

  void showImageSourceOptions(StateSetter setSheetState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sourceContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 15, 20, 25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                /// TOP HANDLE
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 15),

                const Text(
                  "Choose Image From",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    /// =========================================
                    /// CAMERA
                    /// =========================================
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          Navigator.pop(sourceContext);

                          await pickItemImage(
                            ImageSource.camera,
                            setSheetState,
                          );
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 105,
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(11),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryDark.withOpacity(
                                    0.12,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_outlined,
                                  size: 28,
                                  color: AppColors.primaryDark,
                                ),
                              ),

                              const SizedBox(height: 8),

                              const Text(
                                "Camera",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    /// =========================================
                    /// GALLERY
                    /// =========================================
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          Navigator.pop(sourceContext);

                          await pickItemImage(
                            ImageSource.gallery,
                            setSheetState,
                          );
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 105,
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(11),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryDark.withOpacity(
                                    0.12,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.photo_library_outlined,
                                  size: 28,
                                  color: AppColors.primaryDark,
                                ),
                              ),

                              const SizedBox(height: 8),

                              const Text(
                                "Gallery",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> pickItemImage(
      ImageSource source,
      StateSetter setSheetState,
      ) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,

        /// Compression
        imageQuality: 85,

        /// Large image control
        maxWidth: 1600,
        maxHeight: 1600,
      );

      /// User camera/gallery cancel kare
      if (pickedFile == null) {
        return;
      }

      final File file = File(pickedFile.path);

      /// File check
      final bool exists = await file.exists();

      if (!exists) {
        if (!mounted) return;

        AppMessage.error(context, "Selected image not found");

        return;
      }

      /// ============================================
      /// BOTTOM SHEET REFRESH
      /// ============================================
      setSheetState(() {
        selectedImageFile = file;
      });

      debugPrint("IMAGE SELECTED => ${file.path}");
    } catch (e) {
      debugPrint("IMAGE PICK ERROR => $e");

      if (!mounted) return;

      AppMessage.error(context, "Unable to select image");
    }
  }

  Future<void> uploadItemImage(Map user, File imageFile) async {
    try {
      /// ============================================
      /// ITEM SET ID
      /// ============================================
      final int id = int.tryParse(user["id"]?.toString() ?? "0") ?? 0;

      if (id <= 0) {
        AppMessage.error(context, "Invalid item ID");
        return;
      }

      /// Keyboard close
      FocusManager.instance.primaryFocus?.unfocus();

      /// ============================================
      /// FILE NAME
      /// ============================================
      final String fileName = imageFile.path.split("/").last;

      /// ============================================
      /// MULTIPART FORM DATA
      /// ============================================
      final FormData formData = FormData.fromMap({
        "image": await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });

      debugPrint("======================================");
      debugPrint("IMAGE UPLOAD");
      debugPrint("ID => $id");
      debugPrint("FILE => ${imageFile.path}");
      debugPrint("FILE NAME => $fileName");
      debugPrint("======================================");

      /// ============================================
      /// API CALL
      /// item-sets/7/image
      /// ============================================
      final response = await ApiHelper().postRequest(
        "${ApiConstants.itemset}/$id/image",
        formData,
      );

      debugPrint("IMAGE UPLOAD RESPONSE => ${response?.data}");

      if (!mounted) return;

      if (response != null &&
          (response.statusCode == 200 || response.statusCode == 201)) {
        AppMessage.success(
          context,
          response.data?["message"] ?? "Image uploaded successfully",
        );

        /// Bottom sheet close
        Navigator.pop(context);

        /// Focus remove
        labelSearchFocusNode.unfocus();
        FocusManager.instance.primaryFocus?.unfocus();

        /// ============================================
        /// REFRESH LIST
        /// ============================================
        final String from = DateFormat(
          "yyyy-MM-dd",
        ).format(DateFormat("dd-MM-yyyy").parse(fromDateController.text));

        final String to = DateFormat(
          "yyyy-MM-dd",
        ).format(DateFormat("dd-MM-yyyy").parse(toDateController.text));

        await loadItemDetails("", from, to);
      } else {
        AppMessage.error(
          context,
          response?.data?["message"] ?? "Image upload failed",
        );
      }
    } catch (e) {
      debugPrint("IMAGE UPLOAD ERROR => $e");

      if (!mounted) return;

      AppMessage.error(context, "Image upload failed");
    }
  }

  Widget _buildImageUploadButton(Map user) {
    final String imageUrl = user["image_url"]?.toString().trim() ?? "";

    final int id = int.tryParse(user["id"]?.toString() ?? "0") ?? 0;

    final String itemName = user["item"]?["item_name"]?.toString() ?? "";

    final String qrCode = user["qr_code"]?.toString() ?? "";

    return InkWell(
      /// =====================================================
      /// SINGLE TAP => UPLOAD BOTTOM SHEET
      /// =====================================================
      onTap: () async {
        debugPrint("UPLOAD IMAGE CLICK");
        debugPrint("ID => $id");
        debugPrint("ITEM => $itemName");
        debugPrint("QR => $qrCode");
        debugPrint("IMAGE => $imageUrl");

        if (id <= 0) {
          AppMessage.error(context, "Invalid item id");
          return;
        }

        /// Keyboard close
        labelSearchFocusNode.unfocus();
        FocusManager.instance.primaryFocus?.unfocus();

        openImageUploadBottomSheet(user);

        if (!mounted) return;

        /// Bottom sheet close થયા પછી focus પાછું ના આવે
        labelSearchFocusNode.unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },

      /// =====================================================
      /// DOUBLE TAP => FULL IMAGE PREVIEW
      /// =====================================================
      onDoubleTap: imageUrl.isNotEmpty
          ? () {
        labelSearchFocusNode.unfocus();
        FocusManager.instance.primaryFocus?.unfocus();

        _openPremiumImagePreview(
          imageUrl: imageUrl,
          itemName: itemName,
          qrCode: qrCode,
          heroTag: "item_image_$id",
        );
      }
          : null,

      borderRadius: BorderRadius.circular(6),

      child: imageUrl.isNotEmpty
      /// =================================================
      /// IMAGE AVAILABLE
      /// =================================================
          ? Hero(
        tag: "item_image_$id",
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Image.network(
              imageUrl,
              width: 34,
              height: 34,
              fit: BoxFit.cover,

              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }

                return const Center(
                  child: SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },

              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.broken_image_outlined,
                  size: 20,
                  color: Colors.deepPurple,
                );
              },
            ),
          ),
        ),
      )
      /// =================================================
      /// NO IMAGE
      /// =================================================
          : Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.deepPurple.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(
          Icons.add_photo_alternate_outlined,
          color: Colors.deepPurple,
          size: 20,
        ),
      ),
    );
  }

  Future<void> downloadItemImage(Map user) async {
    try {
      labelSearchFocusNode.unfocus();
      FocusManager.instance.primaryFocus?.unfocus();

      /// ============================================
      /// IMAGE URL
      /// ============================================
      final String imageUrl = user["image_url"]?.toString().trim() ?? "";

      debugPrint("========================================");
      debugPrint("DOWNLOAD IMAGE START");
      debugPrint("IMAGE URL => $imageUrl");
      debugPrint("========================================");

      if (imageUrl.isEmpty) {
        AppMessage.error(context, "Image URL not available");
        return;
      }

      /// ============================================
      /// ITEM DATA
      /// ============================================
      final String qrCode = user["qr_code"]?.toString().trim() ?? "";

      final String itemName =
          user["item"]?["item_name"]?.toString().trim() ??
              user["item_name"]?.toString().trim() ??
              "item";

      final String mime = user["image_mime"]?.toString().toLowerCase() ?? "";

      debugPrint("ITEM => $itemName");
      debugPrint("QR => $qrCode");
      debugPrint("MIME => $mime");

      /// ============================================
      /// EXTENSION
      /// ============================================
      String extension = "jpg";

      if (mime.contains("webp")) {
        extension = "webp";
      } else if (mime.contains("png")) {
        extension = "png";
      } else if (mime.contains("jpeg") || mime.contains("jpg")) {
        extension = "jpg";
      }

      /// ============================================
      /// SAFE FILE NAME
      /// ============================================
      final String safeItemName = itemName.replaceAll(
        RegExp(r'[^a-zA-Z0-9_-]'),
        "_",
      );

      final String safeQr = qrCode.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), "_");

      final String fileName =
          "${safeItemName}_${safeQr.isNotEmpty ? safeQr : DateTime.now().millisecondsSinceEpoch}.$extension";

      /// ============================================
      /// TEMP PATH
      /// ============================================
      final Directory tempDir = await getTemporaryDirectory();

      final String tempPath = "${tempDir.path}/$fileName";

      debugPrint("FILE NAME => $fileName");
      debugPrint("TEMP PATH => $tempPath");

      /// ============================================
      /// STEP 1 : DOWNLOAD
      /// ============================================
      try {
        debugPrint("STEP 1 => Download starting...");

        final Dio dio = Dio();

        final Response response = await dio.download(
          imageUrl,
          tempPath,
          options: Options(
            followRedirects: true,
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 30),
          ),
          onReceiveProgress: (received, total) {
            if (total > 0) {
              final int percentage = ((received / total) * 100).round();

              debugPrint("DOWNLOAD PROGRESS => $percentage%");
            }
          },
        );

        debugPrint("DOWNLOAD STATUS => ${response.statusCode}");
      } on DioException catch (e) {
        debugPrint("❌ DIO DOWNLOAD ERROR");
        debugPrint("TYPE => ${e.type}");
        debugPrint("MESSAGE => ${e.message}");
        debugPrint("STATUS => ${e.response?.statusCode}");
        debugPrint("RESPONSE => ${e.response?.data}");

        if (!mounted) return;

        AppMessage.error(
          context,
          "Download failed: ${e.response?.statusCode ?? e.message}",
        );

        return;
      }

      /// ============================================
      /// STEP 2 : CHECK FILE
      /// ============================================
      final File downloadedFile = File(tempPath);

      final bool exists = await downloadedFile.exists();

      debugPrint("FILE EXISTS => $exists");

      if (!exists) {
        if (!mounted) return;

        AppMessage.error(context, "Downloaded file not found");

        return;
      }

      final int fileSize = await downloadedFile.length();

      debugPrint("FILE SIZE => $fileSize bytes");

      if (fileSize <= 0) {
        if (!mounted) return;

        AppMessage.error(context, "Downloaded image is empty");

        return;
      }

      /// ============================================
      /// STEP 3 : GALLERY PERMISSION
      /// ============================================
      try {
        debugPrint("STEP 3 => Checking gallery access...");

        bool hasAccess = await Gal.hasAccess();

        debugPrint("GALLERY ACCESS => $hasAccess");

        if (!hasAccess) {
          hasAccess = await Gal.requestAccess();

          debugPrint("GALLERY ACCESS AFTER REQUEST => $hasAccess");
        }

        if (!hasAccess) {
          if (!mounted) return;

          AppMessage.error(context, "Gallery permission denied");

          return;
        }
      } catch (e) {
        debugPrint("❌ PERMISSION ERROR => $e");
      }

      /// ============================================
      /// STEP 4 : SAVE TO GALLERY
      /// ============================================
      try {
        debugPrint("STEP 4 => Saving to gallery...");

        await Gal.putImage(tempPath, album: "Ornasphere");

        debugPrint("✅ SAVED TO GALLERY");
      } on GalException catch (e) {
        debugPrint("❌ GAL ERROR => ${e.type.message}");

        if (!mounted) return;

        AppMessage.error(context, "Gallery save failed: ${e.type.message}");

        return;
      } catch (e) {
        debugPrint("❌ GALLERY SAVE ERROR => $e");

        if (!mounted) return;

        AppMessage.error(context, "Gallery save failed: $e");

        return;
      }

      /// ============================================
      /// SUCCESS
      /// ============================================
      if (!mounted) return;

      AppMessage.success(context, "Image saved to Gallery");
    } catch (e, stackTrace) {
      debugPrint("❌ DOWNLOAD IMAGE MAIN ERROR => $e");

      debugPrint("STACK TRACE => $stackTrace");

      if (!mounted) return;

      AppMessage.error(context, "Image download failed: $e");
    }
  }

  void _openPremiumImagePreview({
    required String imageUrl,
    required String itemName,
    required String qrCode,
    required String heroTag,
  }) {
    showGeneralDialog(
      context: context,

      barrierDismissible: true,
      barrierLabel: "Image Preview",

      barrierColor: Colors.black.withOpacity(0.92),

      transitionDuration: const Duration(milliseconds: 280),

      pageBuilder: (context, animation, secondaryAnimation) {
        return Material(
          color: Colors.transparent,
          child: SafeArea(
            child: Stack(
              children: [
                /// =============================================
                /// FULL IMAGE
                /// =============================================
                Positioned.fill(
                  child: Center(
                    child: Hero(
                      tag: heroTag,
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 5.0,
                        panEnabled: true,
                        scaleEnabled: true,
                        child: Image.network(
                          imageUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.contain,

                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              return child;
                            }

                            return const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            );
                          },

                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.broken_image_outlined,
                                    size: 55,
                                    color: Colors.white54,
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    "Unable to load image",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                /// =============================================
                /// TOP BAR
                /// =============================================
                Positioned(
                  top: 12,
                  left: 14,
                  right: 14,
                  child: Row(
                    children: [
                      /// Item details
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.12),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                itemName.isEmpty ? "Item Image" : itemName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),

                              if (qrCode.isNotEmpty) ...[
                                const SizedBox(height: 3),

                                Text(
                                  "Label: $qrCode",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.65),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      /// CLOSE
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(50),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.15),
                            ),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                /// =============================================
                /// BOTTOM HINT
                /// =============================================
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 20,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.10),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.pinch_outlined,
                            color: Colors.white70,
                            size: 16,
                          ),

                          SizedBox(width: 6),

                          Text(
                            "Pinch to zoom",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },

      /// =====================================================
      /// PREMIUM OPEN ANIMATION
      /// =====================================================
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curvedAnimation,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.94,
              end: 1.0,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }

  Future<bool> removeItemImage(Map user) async {
    try {
      final int itemSetId = int.tryParse(user["id"]?.toString() ?? "0") ?? 0;

      if (itemSetId == 0) {
        AppMessage.error(context, "Invalid Item Set ID");
        return false;
      }

      debugPrint("==========================================");
      debugPrint("🗑 REMOVE ITEM IMAGE");
      debugPrint("ITEM SET ID => $itemSetId");
      debugPrint("API => ${ApiConstants.itemset}/$itemSetId/image");
      debugPrint("==========================================");

      final response = await ApiHelper().deleteRequest(
        "${ApiConstants.itemset}/$itemSetId/image",
      );

      debugPrint("REMOVE IMAGE STATUS => ${response?.statusCode}");
      debugPrint("REMOVE IMAGE RESPONSE => ${response?.data}");

      if (!mounted) return false;

      if (response != null &&
          (response.statusCode == 200 ||
              response.statusCode == 201 ||
              response.statusCode == 204)) {
        AppMessage.success(
          context,
          response.data is Map
              ? response.data["message"]?.toString() ??
              "Image removed successfully"
              : "Image removed successfully",
        );
        Navigator.pop(context);
        final String from = DateFormat(
          "yyyy-MM-dd",
        ).format(DateFormat("dd-MM-yyyy").parse(fromDateController.text));

        final String to = DateFormat(
          "yyyy-MM-dd",
        ).format(DateFormat("dd-MM-yyyy").parse(toDateController.text));

        /// Jo list API reload karvi hoy to:
        await loadItemDetails("", from, to);

        return true;
      }

      AppMessage.error(
        context,
        response?.data is Map
            ? response?.data["message"]?.toString() ?? "Failed to remove image"
            : "Failed to remove image",
      );

      return false;
    } catch (e, stackTrace) {
      debugPrint("❌ REMOVE IMAGE ERROR => $e");
      debugPrint("❌ STACK => $stackTrace");

      if (mounted) {
        AppMessage.error(context, "Failed to remove image");
      }

      return false;
    }
  }

  String formatDateTime(String value) {
    try {
      final date = DateFormat('dd-MM-yyyy hh:mm a').parse(value);

      return DateFormat('dd-MM-yyyy hh:mm a').format(date);
    } catch (e) {
      return value;
    }
  }

  Widget _buildLoadMoreButton() {
    if (currentPage >= lastPage) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            "All items loaded",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton(
          onPressed: isLoadingMore
              ? null
              : () {
            loadItemDetails(
              _lastItemId,
              _lastFromDate,
              _lastToDate,
              loadMore: true,
              page: currentPage + 1,
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryDark,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: isLoadingMore
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Text(
            "Load More",
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  /// 🔥 Message popup — OK દબાવતાં જ બંધ
  Future<void> _showMessageDialog({
    required String title,
    required String message,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false, // બહાર tap થી બંધ ના થાય, OK જ દબાવવું
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

  /// 🔥 Item filter select / clear
  void _setItemFilter(Map<String, dynamic>? item) {
    _labelSearchTimer?.cancel();

    setState(() {
      selectedItem = item?["id"]?.toString();

      /// Item બદલાય ત્યારે જૂની label search clear
      labelSearchController.clear();
    });

    /// null → filterByItem બધી items બતાવે છે
    filterByItem(selectedItem);

    debugPrint("ITEM FILTER => ${item?["item_name"] ?? "ALL"}");
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

  /// Label item list farithi (branch mujab)
  Future<void> _reloadLabelItems() async {
    setState(() {
      expandedItemId = null;
      currentPage = 1;
      lastPage = 1;
    });
    await _reloadCurrentList();
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
      await _reloadLabelItems();
    } finally {
      if (mounted) setState(() => branchReportLoading = false);
    }
  }

  /// Branch report bandh kari ne potani company ni gallery
  Future<void> clearBranchReport() async {
    setState(() => appliedCompanyIds = []);
    await _reloadLabelItems();
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
                    "Select one or more branches to see their label items.",
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
                              "Showing label items of "
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
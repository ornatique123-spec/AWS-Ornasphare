import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pecifician_sysytem/Dashboard/PremiumScannerScreen.dart';
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
import 'LabelPreviewScreen.dart';

import 'package:pecifician_sysytem/Settings/BranchManagementScreen.dart'
    show BranchApi, Company, BranchTypeX;
import 'package:pecifician_sysytem/Reports/BranchAccess.dart';

class LabelPrintScreen extends StatefulWidget {
  const LabelPrintScreen({super.key});

  @override
  State<LabelPrintScreen> createState() => _LabelPrintScreenState();
}

class _LabelPrintScreenState extends State<LabelPrintScreen> {
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
  List cartItems = [];
  List allUsers = []; // 🔥 original data store
  Set<int> selectedItems = {};
  List searchResults = [];
  List allItems = []; // 🔥 full data (API mathi)
  String selectedLabelType = "Default";
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
      setState(() {
        // ✅ hammesha dd-MM-yyyy (01-05-2026)
        controller.text = DateFormat("dd-MM-yyyy").format(picked);
      });
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

  /// label_print?management_branches[]=1&management_branches[]=2 (branch mode only)
  String _br(String url) => _branchMode
      ? "$url${url.contains('?') ? '&' : '?'}$_branchQuery"
      : url;

  /// label → branch name (company_id / branch / company_name)
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

  /// ✅ Aa label main company no chhe? (fakt eno j edit / delete)
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
    print(
      "🔥 Checking '$permissionName' in $userPermissions => ${userPermissions.contains(permissionName)}",
    );
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

    getCartItems(fromDate: from, toDate: to);
    _loadBranches();
  }

  Future<void> getCartItems({String? fromDate, String? toDate}) async {
    String url = ApiConstants.label_print;

    if (fromDate != null &&
        toDate != null &&
        fromDate.isNotEmpty &&
        toDate.isNotEmpty) {
      url += "?from_date=$fromDate&to_date=$toDate";
    }

    // 🔥 Branch mode → &management_branches[]=1&management_branches[]=2
    url = _br(url);

    debugPrint("==========================================");
    debugPrint("🌐 LABEL PRINT REQUEST");
    debugPrint("URL => $url");
    debugPrint("FROM DATE => $fromDate");
    debugPrint("TO DATE => $toDate");
    debugPrint("==========================================");

    // 🔥 ONLY THIS API GETS LONG TIMEOUT
    final response = await ApiHelper().getRequest(
      url,
      receiveTimeout: const Duration(minutes: 3),
    );

    debugPrint("==========================================");
    debugPrint("📥 LABEL PRINT RESPONSE");
    debugPrint("STATUS => ${response?.statusCode}");
    debugPrint("==========================================");

    if (!mounted) return;

    if (response != null && response.statusCode == 200) {
      final data = response.data;

      final List categories = data["data"] is List ? data["data"] : [];

      if (data["success"] == true) {
        AppMessage.success(
          context,
          data["message"] ?? "Data Loaded Successfully",
        );
      }

      setState(() {
        tableRows.clear();

        searchResults = List.from(categories);
        allItems = List.from(categories);

        // 🔥 AUTO SELECT
        selectedItems = searchResults
            .where((e) => e["is_printed"]?.toString() == "0")
            .map<int>((e) => int.tryParse(e["id"].toString()) ?? 0)
            .where((id) => id > 0)
            .toSet();
      });

      applyDateFilter();

      debugPrint("✅ LABEL ITEMS LOADED => ${categories.length}");
    } else {
      AppMessage.error(context, "Failed to load data");

      debugPrint("❌ LABEL PRINT API FAILED => ${response?.statusCode}");
    }
  }

  Future<void> savefinalizeBulkItems() async {
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one item")),
      );
      return;
    }

    Map<String, dynamic> body = {"ids": selectedItems.toList()};

    print("📤 REQUEST BODY: $body");

    final response = await ApiHelper().postRequest1(ApiConstants.Qr_pdf, body);

    if (response != null && response.statusCode == 200) {
      // 🔥 SAFE STORAGE PATH
      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/qr_labels.pdf");

      await file.writeAsBytes(response.data);

      OpenFile.open(file.path);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to Save Data")));
    }
  }

  dynamic expandedItemId;
  @override
  Widget build(BuildContext context) {
    if (!(hasPermission("label-print-view") ||
        hasPermission("label-print-manage"))) {
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
        resizeToAvoidBottomInset: false,
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

                Padding(
                  padding: const EdgeInsets.only(left: 10.0, right: 10),
                  child: Row(
                    children: [
                      /// 🔥 CHECKBOX
                      Expanded(
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,

                          title: Text(
                            "[ ${searchResults.where((e) => selectedItems.contains(e["id"])).length}/${searchResults.length} ]",
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 13,
                            ),
                          ),

                          /// 🔥 CHECKBOX START MA
                          controlAffinity: ListTileControlAffinity.leading,
                          value:
                          searchResults.isNotEmpty &&
                              searchResults
                                  .where(
                                    (e) => selectedItems.contains(e["id"]),
                              )
                                  .length ==
                                  searchResults.length,

                          activeColor: AppColors.border,

                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                /// 🔥 ALL SELECT
                                selectedItems = searchResults
                                    .map<int>((e) => e["id"] as int)
                                    .toSet();
                              } else {
                                /// 🔥 CLEAR
                                selectedItems.clear();
                              }
                            });
                          },
                        ),
                      ),

                      const SizedBox(width: 10),

                      /// 🔥 DROPDOWN
                      Container(
                        width: MediaQuery.of(context).size.width * 0.56,
                        padding: const EdgeInsets.symmetric(horizontal: 12),

                        decoration: BoxDecoration(
                          color: Colors.white,

                          borderRadius: BorderRadius.circular(8),

                          border: Border.all(color: Colors.grey.shade300),
                        ),

                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedLabelType,

                            //isExpanded: true,
                            dropdownColor: Colors.white,

                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.black,
                            ),

                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),

                            items: const [
                              DropdownMenuItem(
                                value: "Default",

                                child: Text(
                                  "Default",

                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),

                              DropdownMenuItem(
                                value: "Two Barcode + Name/Gross",

                                child: Text(
                                  "Two Barcode + Name/Gross",

                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),

                              DropdownMenuItem(
                                value: "50-50",

                                child: Text(
                                  "50-50",

                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],

                            onChanged: (value) {
                              if (value == null) return;

                              setState(() {
                                selectedLabelType = value;
                              });

                              print(selectedLabelType);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                /// 🔥 Dynamic Bottom Section
                Expanded(
                  child: searchResults.isEmpty
                      ? const Center(
                    child: Text(
                      "No Data Found",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final item = searchResults[index];

                      final id = item["id"];

                      final String itemName =
                          item["item_name"]?.toString() ?? "Item";

                      final String huid = item["HUID"]?.toString() ?? "-";

                      final String qr =
                          item["qr_code"]?.toString() ?? "-";

                      Uint8List? imageBytes = getQrImage(
                        item["qr_image"],
                      );

                      final bool isSelected = selectedItems.contains(id);

                      /// 🔥 EXPAND CHECK
                      final bool isExpanded = expandedItemId == id;

                      final size = MediaQuery.of(context).size;

                      final bool isTablet = size.width >= 600;

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),

                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,

                          borderRadius: BorderRadius.circular(6),

                          border: Border.all(
                            color: isExpanded
                                ? AppColors.primaryDark.withOpacity(0.45)
                                : AppColors.border,
                            width: isExpanded ? 1.5 : 1,
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
                          borderRadius: BorderRadius.circular(6),

                          child: Column(
                            children: [
                              /// =====================================================
                              /// HEADER
                              /// =====================================================
                              InkWell(
                                onTap: () {
                                  /// 🔥 CARD TAP = SELECT / UNSELECT
                                  setState(() {
                                    if (isSelected) {
                                      selectedItems.remove(id);
                                    } else {
                                      selectedItems.add(id);
                                    }
                                  });
                                },

                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isTablet ? 14 : 8,
                                    vertical: isTablet ? 12 : 8,
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
                                          borderRadius:
                                          BorderRadius.circular(5),
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

                                      const SizedBox(width: 5),

                                      /// =================================================
                                      /// CHECKBOX
                                      /// =================================================
                                      SizedBox(
                                        width: 36,
                                        height: 36,

                                        child: Checkbox(
                                          value: isSelected,

                                          activeColor:
                                          AppColors.primaryDark,

                                          materialTapTargetSize:
                                          MaterialTapTargetSize
                                              .shrinkWrap,

                                          onChanged: (value) {
                                            setState(() {
                                              if (value == true) {
                                                selectedItems.add(id);
                                              } else {
                                                selectedItems.remove(id);
                                              }
                                            });
                                          },
                                        ),
                                      ),

                                      const SizedBox(width: 3),

                                      /// =================================================
                                      /// ITEM NAME + QR
                                      /// =================================================
                                      Expanded(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,

                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,

                                          children: [
                                            /// ITEM NAME
                                            Text(
                                              itemName,

                                              maxLines: 1,

                                              overflow:
                                              TextOverflow.ellipsis,

                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight:
                                                FontWeight.w700,
                                                color: Colors.black87,
                                              ),
                                            ),

                                            const SizedBox(height: 4),

                                            /// QR CODE TEXT
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.qr_code_2,
                                                  size: 13,
                                                  color: Colors
                                                      .grey
                                                      .shade600,
                                                ),

                                                const SizedBox(width: 4),

                                                Expanded(
                                                  child: Text(
                                                    qr,

                                                    maxLines: 1,

                                                    overflow: TextOverflow
                                                        .ellipsis,

                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors
                                                          .grey
                                                          .shade600,
                                                      fontWeight:
                                                      FontWeight.w500,
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

                                            /// HUID
                                            if (huid != "-" &&
                                                huid.isNotEmpty) ...[
                                              const SizedBox(height: 2),

                                              Text(
                                                "HUID: $huid",
                                                maxLines: 1,
                                                overflow:
                                                TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors
                                                      .grey
                                                      .shade500,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 6),

                                      /// =================================================
                                      /// QR IMAGE
                                      /// =================================================
                                      Container(
                                        width: 46,
                                        height: 46,
                                        padding: const EdgeInsets.all(4),

                                        decoration: BoxDecoration(
                                          color: Colors.white,

                                          borderRadius:
                                          BorderRadius.circular(5),

                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),

                                        child: imageBytes != null
                                            ? Image.memory(
                                          imageBytes,
                                          fit: BoxFit.contain,
                                        )
                                            : const Icon(
                                          Icons.qr_code_2,
                                          size: 34,
                                          color: Colors.black54,
                                        ),
                                      ),

                                      const SizedBox(width: 6),

                                      /// =================================================
                                      /// EXPAND BUTTON
                                      /// =================================================
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            if (expandedItemId == id) {
                                              /// Same card close
                                              expandedItemId = null;
                                            } else {
                                              /// New card open
                                              /// Old automatically close
                                              expandedItemId = id;
                                            }
                                          });
                                        },

                                        borderRadius:
                                        BorderRadius.circular(20),

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
                                              Icons
                                                  .keyboard_arrow_down_rounded,
                                              size: 22,
                                              color:
                                              AppColors.primaryDark,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              /// =====================================================
                              /// EXPANDED DETAILS
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
                                      /// DIVIDER
                                      Divider(
                                        height: 1,
                                        color: AppColors.border,
                                      ),

                                      const SizedBox(height: 10),

                                      /// =================================================
                                      /// ERP DETAILS
                                      /// =================================================
                                      Container(
                                        padding:
                                        const EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),

                                        decoration: BoxDecoration(
                                          color: AppColors.background,

                                          border: Border.all(
                                            color: AppColors.border,
                                            width: 1.5,
                                          ),

                                          borderRadius:
                                          BorderRadius.circular(6),
                                        ),

                                        child: Column(
                                          children: [
                                            /// =========================================
                                            /// DATE / GROSS
                                            /// =========================================
                                            _erpRow(
                                              "Date",
                                              item["created_at"] != null
                                                  ? formatDate(
                                                item["created_at"]
                                                    .toString(),
                                              )
                                                  : "-",

                                              "G.Wt",
                                              item["gross_weight"]
                                                  ?.toString() ??
                                                  "-",
                                            ),

                                            Divider(
                                              height: 1,
                                              color: AppColors.border,
                                            ),

                                            /// =========================================
                                            /// NET / OTHER
                                            /// =========================================
                                            _erpRow(
                                              "N.Wt",
                                              item["net_weight"]
                                                  ?.toString() ??
                                                  "-",

                                              "O.Wt",
                                              item["other_weight"]
                                                  ?.toString() ??
                                                  "-",
                                            ),
                                            Divider(
                                              height: 1,
                                              color: AppColors.border,
                                            ),
                                            _erpRow(
                                              "Print Date",
                                              item["printed_at"] != null
                                                  ? formatDateTime(item["printed_at"].toString())
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
                    },
                  ),
                ),

                if (hasPermission("label-print-create"))
                /// Bottom Button
                  InkWell(
                    onTap: () {
                      final selectedData = searchResults.where((item) {
                        return selectedItems.contains(item["id"]);
                      }).toList();

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LabelPreviewScreen(
                            selectedData: selectedData,
                            selectedLabelType: selectedLabelType,
                          ),
                        ),
                      );
                      //savefinalizeBulkItems();
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
                            "Label Print",
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
                      "Label Print List",
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
            "size": TextEditingController(),
            "huid": TextEditingController(),
          });
        }
      });
    }
  }

  /// =========================================================
  /// 📄 EXPORT — PDF / EXCEL (getPdfRequest → bytes)
  /// label_print?from_date=..&to_date=..&management_branches[]=1&export=pdf
  /// =========================================================

  static String get _exportUrl => ApiConstants.label_print;

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
      final file = File("${dir.path}/Label_Print_$stamp.$ext");
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


  Widget filterWidget() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final width = MediaQuery.of(context).size.width;

    final isTablet = width >= 600;
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
          SizedBox(
            width: double.infinity,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border.all(color: AppColors.border, width: 1.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Consumer<ItemProvider>(
                builder: (context, provider, child) {
                  final items = provider.items;

                  return DropdownButton<String>(
                    isExpanded: true,
                    underline: SizedBox(), // ⭐ important
                    value:
                    selectedItem != null &&
                        items.any((e) => e["id"].toString() == selectedItem)
                        ? selectedItem
                        : null, // ⭐ Important Fix
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.black,
                    ),
                    dropdownColor: Colors.white, // 🔥 ADD THIS
                    hint: Text(
                      "Select Item",
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

                    /// 🔥 Selected Value Style
                    items: items.map<DropdownMenuItem<String>>((item) {
                      return DropdownMenuItem<String>(
                        value: item["id"].toString(),
                        child: Text(item["item_name"] ?? ""),
                      );
                    }).toList(),

                    onChanged: (value) {
                      setState(() {
                        selectedItem = value;

                        final selectedItemData = Provider.of<ItemProvider>(
                          context,
                          listen: false,
                        ).items.firstWhere((e) => e["id"].toString() == value);

                        final selectedName = selectedItemData["item_name"];

                        searchResults = allItems.where((item) {
                          return item["item_name"] == selectedName;
                        }).toList();
                      });
                    },
                  );
                },
              ),
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
                    getCartItems(fromDate: r.from, toDate: r.to);
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

              /// CLEAR
              Expanded(
                child: InkWell(
                  onTap: () {
                    fromDateController.clear();
                    toDateController.clear();

                    setState(() {
                      selectedItem = null;
                      expandedItemId = null;
                    });

                    // ✅ Date vagar badha records farithi
                    getCartItems();
                  },

                  borderRadius: BorderRadius.circular(5),
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
        searchResults = allItems; // 🔥 correct list use karo
      });
      return;
    }

    DateTime fromDate = _convertToDate(fromDateController.text);
    DateTime toDate = _convertToDate(toDateController.text);

    List filtered = allItems.where((item) {
      if (item["created_at"] == null || item["created_at"].toString().isEmpty) {
        return false;
      }

      try {
        /// 🔥 Convert "08-04-2026 03:24 PM" → DateTime
        String datePart = item["created_at"].split(" ").first; // 08-04-2026
        DateTime itemDate = _convertToDate(datePart);

        return itemDate.isAfter(fromDate.subtract(const Duration(days: 1))) &&
            itemDate.isBefore(toDate.add(const Duration(days: 1)));
      } catch (e) {
        return false;
      }
    }).toList();

    setState(() {
      searchResults = filtered;
    });
  }

  String formatDate(String? date) {
    if (date == null || date.isEmpty) {
      return "-"; // or "Not Printed"
    }

    return date.split(" ").first;
  }

  DateTime _convertToDate(String input) {
    try {
      return DateFormat("d-M-yyyy").parse(input.trim());
    } catch (_) {
      return DateTime.now();
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

  Uint8List? getQrImage(String? base64String) {
    try {
      if (base64String == null || base64String.isEmpty) {
        return null;
      }

      // 🔥 Check if prefix exists
      if (base64String.contains(',')) {
        return base64Decode(base64String.split(',').last);
      } else {
        return base64Decode(base64String);
      }
    } catch (e) {
      print("QR Decode Error: $e"); // debug
      return null;
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

  @override
  void dispose() {
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

  /// Label print list farithi (branch mujab)
  Future<void> _reloadLabelPrint() async {
    setState(() {
      expandedItemId = null;
      selectedItem = null;
    });
    final r = _apiRange();
    await getCartItems(fromDate: r.from, toDate: r.to);
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
      await _reloadLabelPrint();
    } finally {
      if (mounted) setState(() => branchReportLoading = false);
    }
  }

  /// Branch report bandh kari ne potani company ni gallery
  Future<void> clearBranchReport() async {
    setState(() => appliedCompanyIds = []);
    await _reloadLabelPrint();
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
                    "Select one or more branches to see their label print list.",
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
                              "Showing label print of "
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
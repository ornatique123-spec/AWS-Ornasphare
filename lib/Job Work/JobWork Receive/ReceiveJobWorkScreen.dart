import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pecifician_sysytem/Item_Mangement/Label_Items/Create_label_screen.dart';
import 'package:pecifician_sysytem/Job%20Work/Job%20Work%20Issue/Create_jobWork_Issue.dart';
import 'package:pecifician_sysytem/Job%20Work/JobWork%20Receive/AddJobWorkReceiveScreen.dart';
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

class Receivejobworkscreen extends StatefulWidget {
  const Receivejobworkscreen({super.key});

  @override
  State<Receivejobworkscreen> createState() => _ReceivejobworkscreenState();
}

class _ReceivejobworkscreenState extends State<Receivejobworkscreen> {
  List userlist = [];
  String? selectedItem;
  List<Map<String, dynamic>> tableRows = [];
  Timer? _huidTimer;
  int apiRowCount = 0;
  String? selectedRole;

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

  List allUsers = []; // 🔥 original data store
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
                     20
                    ),
                    itemCount: userlist.length,
                    itemBuilder: (context, index) {
                      return buildItemCard(userlist[index], index);
                    },
                  ),
                ),
                // if (hasPermission("jobwork-receive-create"))
                //   InkWell(
                //     onTap: () {
                //       Navigator.push(
                //         context,
                //         MaterialPageRoute(
                //           builder: (context) => const Receivejobworkscreen( ),
                //         ),
                //       );
                //     },
                //     borderRadius: BorderRadius.circular(10),
                //     child: Padding(
                //       padding: const EdgeInsets.only(bottom: 8.0),
                //       child: Container(
                //         margin: const EdgeInsets.all(16),
                //         padding: const EdgeInsets.symmetric(vertical: 14),
                //         decoration: BoxDecoration(
                //           gradient:LinearGradient(
                //             colors: [
                //               AppColors.primaryDark.withOpacity(0.7),
                //               AppColors.secondaryDark.withOpacity(0.7),
                //             ],
                //           ),
                //           borderRadius: BorderRadius.circular(10),
                //         ),
                //         child: const Center(
                //           child: Text(
                //             "+ Create JobWork Receive",
                //             style: TextStyle(
                //               fontWeight: FontWeight.bold,
                //               color: Colors.white,
                //               fontSize: 16,
                //             ),
                //           ),
                //         ),
                //       ),
                //     ),
                //   ),
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
                      "JobWork Receive",
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
                    openPdf(user["id"]);
                  }),

                  /// =================================================
                  /// EYE / DETAILS
                  /// =================================================
                  if (hasPermission("jobwork-receive-edit")) ...[
                    SizedBox(
                      width: isTablet ? 8 : 4,
                    ),

                    premiumIconBtn(
                      Icons.remove_red_eye_rounded,
                      Colors.blue,
                      onTap: () async {
                        if (id > 0) {
                          await getApprovalDetails(id);
                        }
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

    final response = await ApiHelper().getRequest(
      "${ApiConstants.jobwork_receive}?from=$from&to=$to",
    );

    if (response?.statusCode == 200 && response?.data["data"] != null) {
      final data = response!.data;

      final List categories = data['data'];

      setState(() {
        tableRows.clear();
        userlist = categories;
        allUsers = categories;
      });

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
          /// 🔍 SEARCH FIELD
          Consumer<ItemProvider>(
            builder: (context, provider, child) {

              // ============================================
              // SELECTED WORKER FIND
              // ============================================
              Map<String, dynamic>? selectedWorker;

              if (selectedRole != null &&
                  selectedRole!.trim().isNotEmpty) {

                for (final worker in provider.Job_worker) {
                  if (worker["id"]?.toString() == selectedRole) {
                    selectedWorker =
                    Map<String, dynamic>.from(worker);
                    break;
                  }
                }
              }

              // ============================================
              // PREMIUM WORKER SEARCH DROPDOWN
              // ============================================
              return PremiumItemSearchDropdown(
                label: "Worker",
                hint: "Select Worker",

                items: provider.Job_worker
                    .map<Map<String, dynamic>>(
                      (e) => Map<String, dynamic>.from(e),
                )
                    .toList(),

                value: selectedWorker,

                requiredField: true,

                onChanged: (worker) {

                  setState(() {

                    // ========================================
                    // CLEAR WORKER
                    // ========================================
                    if (worker == null) {
                      selectedRole = null;

                      userlist = List.from(allUsers);

                      return;
                    }

                    // ========================================
                    // SELECT WORKER
                    // ========================================
                    selectedRole =
                        worker["id"]?.toString();

                    debugPrint(
                      "SELECTED WORKER ID => $selectedRole",
                    );

                    debugPrint(
                      "SELECTED WORKER => $worker",
                    );

                    // ========================================
                    // FILTER JOBWORK RECEIVE LIST
                    // ========================================
                    userlist = allUsers.where((e) {

                      final String jobWorkerId =
                          e["job_worker_id"]?.toString() ?? "";

                      return jobWorkerId == selectedRole;

                    }).toList();

                    debugPrint(
                      "FILTERED RECEIVE COUNT => ${userlist.length}",
                    );
                  });
                },
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
                  onTap: () {
                    String from = DateFormat("yyyy-MM-dd").format(
                      DateFormat("dd-MM-yyyy").parse(fromDateController.text),
                    );

                    String to = DateFormat("yyyy-MM-dd").format(
                      DateFormat("dd-MM-yyyy").parse(toDateController.text),
                    );
                    loadItemDetails("", from, to);
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

  Future<void> openPdf(int id) async {
    final response = await ApiHelper().getRequestWithId(
      ApiConstants.jobwork_receive_pdf,
      id,
      responseType: ResponseType.bytes,
    );

    if (response != null && response.statusCode == 200) {
      final dir = await getTemporaryDirectory();

      final file = File("${dir.path}/Job Work Receive$id.pdf");

      await file.writeAsBytes(response.data);

      OpenFile.open(file.path);
    } else {
      print("PDF Download Failed");
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
        String from = DateFormat("yyyy-MM-dd").format(
          DateFormat("dd-MM-yyyy").parse(fromDateController.text),
        );

        String to = DateFormat("yyyy-MM-dd").format(
          DateFormat("dd-MM-yyyy").parse(toDateController.text),
        );

        loadItemDetails("", from, to);
      }
    }
  }
}

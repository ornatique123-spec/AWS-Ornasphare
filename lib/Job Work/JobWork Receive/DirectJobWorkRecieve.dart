import 'dart:async';
import 'dart:ui';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:pecifician_sysytem/Item_Mangement/Item/ItemScreen.dart';
import 'package:pecifician_sysytem/Item_Mangement/Label/CreateLabelScreen.dart';
import 'package:pecifician_sysytem/Item_Mangement/Label_Items/label_item_screen.dart';
import 'package:pecifician_sysytem/Job%20Work/Job%20Work%20Issue/Jobwork_issue_Screen.dart';
import 'package:pecifician_sysytem/User/CreteUserScreen.dart';
import 'package:provider/provider.dart';
import '../../Api_Constant/ApiConstants.dart';
import '../../Api_Constant/api_helper.dart';
import '../../Extra/AppColors.dart';
import '../../Extra/AppMessage.dart';
import '../../Extra/ItemProvider.dart';
import '../../Extra/PremiumSearchableDropdown.dart';
import '../../Offline Data/offline_api_helper.dart';

class Directjobworkrecieve extends StatefulWidget {
  final Map? userData;

  const Directjobworkrecieve({super.key, this.userData});

  @override
  State<Directjobworkrecieve> createState() => CreateJobworkIssueState();
}

class CreateJobworkIssueState extends State<Directjobworkrecieve> {
  final TextEditingController Carat_Controller = TextEditingController();
  final TextEditingController purity_Controller = TextEditingController();
  TextEditingController fromDateController = TextEditingController();
  final TextEditingController remarksController = TextEditingController();
  Map<String, FocusNode> focusNodes = {}; // 🔥 NEW
  List userlist = [];
  String? selectedItem;
  String? selectedJobWorker;
  List<Map<String, dynamic>> tableRows = [];
  Timer? _huidTimer;
  int apiRowCount = 0;
  List searchResults = [];

  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> allItems = [];
  Timer? _grossTimer;
  Map<String, Timer> rowTimers = {};
  Set<String> triggerFields = {
    "purity",
    "gross_weight",
    "other",
    "net_weight",
    "fine_weight",
    "qty",
    "net_purity",
    "remarks",
    "total_amount",
  };
  bool get isEditMode => widget.userData != null;

  Map<String, dynamic> _defaultItem() {
    return {
      "id": DateTime.now().microsecondsSinceEpoch.toString(), // 🔥 IMPORTANT

      // ITEM
      "item": "",
      "item_id": null,

      // QTY
      "qty": "",

      // PURITY
      "outward_carat": "", // Purity
      "waste": "", // Waste %
      "net_purity": "", // Net Purity (purity + waste)

      // WEIGHTS
      "gross_weight": "", // Gross Wt
      "other": "", // Other Wt
      "net_weight": "", // Net Wt (gross - other)
      "fine_weight": "", // Fine Wt (net × net_purity / 100)

      // METAL
      "metal_rate": "",
      "metal_amount": "",

      // LABOUR
      "sale_labour_rate": "",
      "sale_labour_amount": "",

      // OTHER CHARGE
      "other_charge_id": null,
      "other_amount": "", // Other Amt

      // REMARKS
      "remarks": "",

      // TOTAL
      "total_amount": "", // Total Amt (metal + labour + other)
    };
  }

  // 🔥 NEW: FocusNode getter with auto-clear-on-focus logic
  FocusNode getFocusNode(Map item, String key) {
    final uniqueKey = "${item["id"]}_$key";

    if (!focusNodes.containsKey(uniqueKey)) {
      final node = FocusNode();

      node.addListener(() {
        if (node.hasFocus) {
          final controller = getController(item, key);
          if (_isZeroValue(controller.text)) {
            controller.clear();
          }
        }
      });

      focusNodes[uniqueKey] = node;
    }

    return focusNodes[uniqueKey]!;
  }

// 🔥 NEW: check karo ke text "0", "0.0", "0.000" jevu zero-only value che ke nai
  bool _isZeroValue(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    final val = double.tryParse(trimmed);
    return val != null && val == 0;
  }

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

  @override
  void initState() {
    super.initState();

    DateTime today = DateTime.now();
    String formattedDate = "${today.day}-${today.month}-${today.year}";

    fromDateController.text = formattedDate;

    Future.microtask(() async {
      final provider = Provider.of<ItemProvider>(context, listen: false);

      await provider.refreshItems();

      await provider.refreshCustomers();

      // await provider.refreshProductionsteps();

      if (isEditMode) {
        final user = widget.userData!;

        setState(() {
          // 🔥 Row data already has customer_id — use it immediately
          // so the Customer dropdown paints correctly while the full
          // details load in the background.
          selectedJobWorker = user["customer_id"]?.toString() ??
              user["job_worker"]?["id"]?.toString();

          selectedItem = user["production_step"]?["id"]?.toString();
        });

        loadInitialData(user["id"]);
      }
    });
  }

  Future<void> loadInitialData(int id) async {
    final response = await ApiHelper().getRequestWithId(
      ApiConstants.jobwork_receive_direct,
      id,
    );

    if (response != null &&
        response.statusCode == 200 &&
        response.data != null) {
      final data = response.data["data"];

      final List apiItems = data["items"] ?? [];

      // ============================================================
      // HEADER DATA — https://ornasphere.com/api/jobwork-receive/direct/{id}
      // ============================================================
      selectedJobWorker = data["customer_id"]?.toString();

      remarksController.text = data["remarks"]?.toString() ?? "";

      // API gives dd-MM-yyyy in receive_date_view
      fromDateController.text = data["receive_date_view"]?.toString() ??
          data["voucher_date_view"]?.toString() ??
          "";

      // ============================================================
      // ITEM DATA
      // ============================================================
      searchResults = apiItems.map<Map<String, dynamic>>((e) {
        final int apiItemId = int.tryParse(e["id"]?.toString() ?? "0") ?? 0;

        final double gross =
            double.tryParse(e["receive_gross_wt"]?.toString() ?? "0") ?? 0;

        final double otherWt =
            double.tryParse(e["other_wt"]?.toString() ?? "0") ?? 0;

        final double netWt = (gross - otherWt) < 0 ? 0 : (gross - otherWt);

        return {
          // UI controller unique key
          "id": "api_$apiItemId",

          // For update/delete reference on this specific receive item
          "receive_item_id": e["id"],

          // ITEM
          "item_id": e["item_id"],

          "item": e["item"]?["item_name"]?.toString() ??
              e["item_name"]?.toString() ??
              "",

          // QTY
          "qty": e["receive_qty_pcs"]?.toString() ?? "0",

          // PURITY
          "outward_carat": e["purity"]?.toString() ?? "0",

          "waste": e["waste_percent"]?.toString() ?? "0",

          "net_purity": e["net_purity"]?.toString() ?? "0",

          // WEIGHTS
          "gross_weight": e["receive_gross_wt"]?.toString() ?? "0",

          "other": e["other_wt"]?.toString() ?? "0",

          "net_weight": netWt.toStringAsFixed(3),

          "fine_weight": e["receive_fine_wt"]?.toString() ?? "0",

          // METAL
          "metal_rate": e["metal_rate"]?.toString() ?? "0",

          "metal_amount": e["metal_amount"]?.toString() ?? "0",

          // LABOUR
          "sale_labour_rate": e["labour_rate"]?.toString() ?? "0",

          "sale_labour_amount": e["labour_amount"]?.toString() ?? "0",

          // OTHER CHARGE
          "other_charge_id": e["other_charge_id"],

          "other_amount": e["other_amt"]?.toString() ?? "0",

          // REMARKS
          "remarks": e["remarks"]?.toString() ?? "",

          // TOTAL
          "total_amount": e["total_amount"]?.toString() ?? "0",
        };
      }).toList();

      if (mounted) {
        setState(() {});
      }

      debugPrint("======================================");
      debugPrint("EDIT JOBWORK RECEIVE (DIRECT) LOADED");
      debugPrint("Customer => $selectedJobWorker");
      debugPrint("Date => ${fromDateController.text}");
      debugPrint("Items => ${searchResults.length}");
      debugPrint("======================================");
    }
  }



  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final isMobile = width < 600;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.white,

      body: SafeArea(
        child: Column(
          children: [
            // =========================================================
            // FIXED APPBAR
            // =========================================================
            Container(
              width: double.infinity,
              color: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // TITLE
                  Text(
                    isEditMode
                        ? "Ditect Job Work Recieve"
                        : "Ditect Job Work Recieve",
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  // BACK BUTTON
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(8),
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
                  ),

                  // ADD ROW BUTTON
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: () {
                        //FocusManager.instance.primaryFocus?.unfocus();

                        final Map<String, dynamic> newRow = _defaultItem();

                        setState(() {
                          searchResults.add(newRow);
                        });

                        debugPrint("➕ Blank row added");
                        debugPrint("Total Rows: ${searchResults.length}");
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: EdgeInsets.all(isMobile ? 6 : 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.shadow,
                              blurRadius: 12,
                              offset: const Offset(3, 5),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          size: isMobile ? 22 : 24,
                          color: AppColors.gradientBlue,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // =========================================================
            // ONLY THIS SECTION WILL SCROLL
            // =========================================================
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.manual,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  children: [
                    // =================================================
                    // FILTER
                    // =================================================
                    filterWidget(),

                    // =================================================
                    // DIVIDER
                    // =================================================
                    Container(
                      margin: const EdgeInsets.only(
                        top: 10,
                        left: 10,
                        right: 10,
                      ),
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

                    const SizedBox(height: 8),

                    // =================================================
                    // ITEMS
                    // =================================================
                    if (searchResults.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                          child: Text(
                            "No Data Found",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0),
                        child: Column(
                          children: List.generate(searchResults.length, (
                              index,
                              ) {
                            return approvalItemCard(
                              searchResults[index],
                              index,
                            );
                          }),
                        ),
                      ),

                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),

            _buildBottomSummary(),

            const SizedBox(height: 0),
            // =========================================================
            // FIXED BOTTOM CREATE / UPDATE BUTTON
            // =========================================================
            Container(
              width: double.infinity,
              color: AppColors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: InkWell(
                onTap: () async {
                  FocusManager.instance.primaryFocus?.unfocus();

                  if (isEditMode) {
                    await Updatejobwork(searchResults);
                  } else {
                    await Createjobwork(searchResults);
                  }
                },
                borderRadius: BorderRadius.circular(10),
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
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      isEditMode
                          ? "Ditect Job Work Recieve"
                          : "Ditect Job Work Recieve",
                      style: const TextStyle(
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
  }

  Future<void> Createjobwork(List itemsList) async {
    if (selectedJobWorker == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select Customer")));
      return;
    }

    // if (selectedItem == null) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text("Please select Production Step")),
    //   );
    //   return;
    // }

    /// 🔥 MAIN BODY — https://ornasphere.com/api/jobwork-receive/direct
    Map<String, dynamic> body = {
      "receive_date": formatDateForApi(fromDateController.text),
      "customer_id": int.parse(selectedJobWorker ?? "0"),
      "remarks": remarksController.text,

      /// 🔥 ITEMS LIST
      "items": itemsList.map((item) {
        return {
          "item_id": item["item_id"] ?? "",
          "receive_qty_pcs": int.tryParse(item["qty"].toString()) ?? 0,
          "receive_gross_wt":
          double.tryParse(item["gross_weight"].toString()) ?? 0,
          "other_wt": double.tryParse(item["other"].toString()) ?? 0,
          "purity": double.tryParse(item["outward_carat"].toString()) ?? 0,
          "waste_percent": double.tryParse(item["waste"].toString()) ?? 0,
          "net_purity": double.tryParse(item["net_purity"].toString()) ?? 0,
          "receive_fine_wt":
          double.tryParse(item["fine_weight"].toString()) ?? 0,
          "metal_rate": double.tryParse(item["metal_rate"].toString()) ?? 0,
          "metal_amount":
          double.tryParse(item["metal_amount"].toString()) ?? 0,
          "labour_rate":
          double.tryParse(item["sale_labour_rate"].toString()) ?? 0,
          "labour_amount":
          double.tryParse(item["sale_labour_amount"].toString()) ?? 0,
          "other_amt": double.tryParse(item["other_amount"].toString()) ?? 0,
          "total_amount":
          double.tryParse(item["total_amount"].toString()) ?? 0,
          "remarks": item["remarks"] ?? "",
          "other_charge_id": item["other_charge_id"] ?? "",
        };
      }).toList(),
    };

    print("📤 REQUEST BODY: $body");

    final response = await OfflineApiHelper.instance.postRequest(
      ApiConstants.jobwork_receive_direct,
      body,
    );

    if (response != null && response.statusCode == 200 ||
        response!.statusCode == 202) {
      if (response.statusCode == 202) {
        AppMessage.success(context, "No Internet. Update saved offline.");
      }

      Navigator.pop(context, true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Saved successfully")));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to Save Data")));
    }
  }

  Future<void> Updatejobwork(List itemsList) async {
    // if (selectedItem == null) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text("Please select Production Step")),
    //   );
    //   return;
    // }

    if (selectedJobWorker == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select Customer")));
      return;
    }

    /// 🔥 MAIN BODY — https://ornasphere.com/api/jobwork-receive/direct/{id}
    Map<String, dynamic> body = {
      "receive_date": formatDateForApi(fromDateController.text),
      "customer_id": int.parse(selectedJobWorker ?? "0"),
      "remarks": remarksController.text,

      /// 🔥 ITEMS LIST
      "items": itemsList.map((item) {
        return {
          "item_id": item["item_id"] ?? "",
          "receive_qty_pcs": int.tryParse(item["qty"].toString()) ?? 0,
          "receive_gross_wt":
          double.tryParse(item["gross_weight"].toString()) ?? 0,
          "other_wt": double.tryParse(item["other"].toString()) ?? 0,
          "purity": double.tryParse(item["outward_carat"].toString()) ?? 0,
          "waste_percent": double.tryParse(item["waste"].toString()) ?? 0,
          "net_purity": double.tryParse(item["net_purity"].toString()) ?? 0,
          "receive_fine_wt":
          double.tryParse(item["fine_weight"].toString()) ?? 0,
          "metal_rate": double.tryParse(item["metal_rate"].toString()) ?? 0,
          "metal_amount":
          double.tryParse(item["metal_amount"].toString()) ?? 0,
          "labour_rate":
          double.tryParse(item["sale_labour_rate"].toString()) ?? 0,
          "labour_amount":
          double.tryParse(item["sale_labour_amount"].toString()) ?? 0,
          "other_amt": double.tryParse(item["other_amount"].toString()) ?? 0,
          "total_amount":
          double.tryParse(item["total_amount"].toString()) ?? 0,
          "remarks": item["remarks"] ?? "",
          "other_charge_id": item["other_charge_id"] ?? "",
        };
      }).toList(),
    };

    print("📤 REQUEST BODY: $body");

    final userId = widget.userData!["id"];

    final response = await ApiHelper().putRequest(
      "${ApiConstants.jobwork_receive_direct}/$userId",
      body,
    );

    if (response != null && response.statusCode == 200) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Saved successfully")));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to Save Data")));
    }
  }

  Future<void> loadItemDetails(String itemId) async {
    Map<String, dynamic> body = {"item_id": int.parse(selectedItem!)};

    print("📤 REQUEST BODY: $body");

    final response = await ApiHelper().postRequest(
      ApiConstants.Create_label_item_list,
      body,
    );

    List categories = [];

    if (response != null && response.statusCode == 200) {
      final data = response.data;

      /// ✅ CHECK: data null OR empty
      if (data["data"] != null && data["data"].isNotEmpty) {
        categories = data["data"];
      } else {
        /// 🔥 DEFAULT ITEM (WHEN NULL / EMPTY)
        categories = [_defaultItem()];
      }
    } else {
      /// 🔥 API ERROR CASE
      categories = [_defaultItem()];
    }

    setState(() {
      tableRows.clear();
      searchResults = categories;
    });
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
        color: AppColors.background,
        border: Border.all(color: AppColors.border, width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          /// 🔍 SEARCH FIELD
          InkWell(
            onTap: () => _selectDate(fromDateController),
            child: IgnorePointer(
              child: TextField(
                controller: fromDateController,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: "Select Date",
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

          const SizedBox(height: 5),
          Consumer<ItemProvider>(
            builder: (context, provider, child) {
              final List<Map<String, dynamic>> jobWorkers =
              List<Map<String, dynamic>>.from(provider.customers);

              /// Selected Job Worker full object
              Map<String, dynamic>? selectedJobWorkerObj;

              if (selectedJobWorker != null) {
                try {
                  selectedJobWorkerObj = jobWorkers.firstWhere(
                        (e) => e["id"].toString() == selectedJobWorker.toString(),
                  );
                } catch (_) {
                  selectedJobWorkerObj = null;
                }
              }

              return PremiumItemSearchDropdown(
                label: "Customer",
                hint: "Select Customer",
                requiredField: true,
                width: double.infinity,

                /// List
                items: jobWorkers,

                /// Selected full object
                value: selectedJobWorkerObj,

                /// Selection
                onChanged: (item) async {
                  setState(() {
                    if (item == null) {
                      selectedJobWorker = null;
                      return;
                    }

                    selectedJobWorker = item["id"]?.toString();

                    print("Job Worker ID: $selectedJobWorker");

                    print("Job Worker Name: ${item["name"]}");
                  });

                  // jo API call karvi hoy:
                  // await loadItemDetails(selectedJobWorker!);
                },
              );
            },
          ),
          const SizedBox(height: 5),


          TextField(
            controller: remarksController,
            maxLines: 1,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              hintText: "Enter Remarks",
              hintStyle: TextStyle(color: Colors.grey.shade600),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 5),
        ],
      ),
    );
  }

  // Widget approvalItemCard(Map<String, dynamic> item, int index) {
  //   bool isExpanded = item["expanded"] ?? false;
  //
  //   return Stack(
  //     children: [
  //       Container(
  //         margin: const EdgeInsets.symmetric(vertical: 4),
  //         padding: const EdgeInsets.only(left: 12, right: 12, top: 3),
  //         decoration: BoxDecoration(
  //           color: AppColors.primaryDark.withOpacity(0.3),
  //           borderRadius: BorderRadius.circular(5),
  //           border: Border.all(color: AppColors.border),
  //           boxShadow: [
  //             BoxShadow(
  //               color: Colors.black.withOpacity(0.05),
  //               blurRadius: 8,
  //               offset: const Offset(0, 3),
  //             ),
  //           ],
  //         ),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             /// 🔝 HEADER
  //             Row(
  //               children: [
  //                 const Spacer(),
  //
  //                 InkWell(
  //                   onTap: () async {
  //                     // ============================================================
  //                     // EDIT MODE
  //                     // ============================================================
  //                     if (isEditMode) {
  //                       final String? jobworkIssueId = item["jobwork_issue_id"]
  //                           ?.toString();
  //
  //                       final String? jobworkIssueItemId =
  //                       item["jobwork_issue_item_id"]?.toString();
  //
  //                       debugPrint("JobWork Issue ID => $jobworkIssueId");
  //                       debugPrint(
  //                         "JobWork Issue Item ID => $jobworkIssueItemId",
  //                       );
  //
  //                       // API mathi aveli existing row
  //                       if (jobworkIssueItemId != null &&
  //                           jobworkIssueItemId.isNotEmpty) {
  //                         await deleteJobworkItem(
  //                           jobworkIssueId.toString(),
  //                           jobworkIssueItemId,
  //                         );
  //                       }
  //                     }
  //
  //                     // ============================================================
  //                     // 🔥 CONTROLLERS + FOCUS NODES CLEANUP (row delete before)
  //                     // ============================================================
  //                     final String rowId = item["id"].toString();
  //
  //                     controllers.removeWhere((key, controller) {
  //                       if (key.startsWith("${rowId}_")) {
  //                         controller.dispose();
  //                         return true;
  //                       }
  //                       return false;
  //                     });
  //
  //                     focusNodes.removeWhere((key, node) {
  //                       if (key.startsWith("${rowId}_")) {
  //                         node.dispose();
  //                         return true;
  //                       }
  //                       return false;
  //                     });
  //
  //                     // ============================================================
  //                     // UI MATHI REMOVE
  //                     // ============================================================
  //                     if (mounted) {
  //                       setState(() {
  //                         searchResults.removeAt(index);
  //                       });
  //                     }
  //                   },
  //                   borderRadius: BorderRadius.circular(5),
  //                   child: Container(
  //                     padding: const EdgeInsets.all(4),
  //                     decoration: BoxDecoration(
  //                       gradient: const LinearGradient(
  //                         colors: [
  //                           Color(0xffFF8A80), // light red
  //                           Color(0xffD32F2F), // deep red
  //                         ],
  //                         begin: Alignment.topLeft,
  //                         end: Alignment.bottomRight,
  //                       ),
  //                       borderRadius: BorderRadius.circular(5),
  //                     ),
  //                     child: const Icon(
  //                       Icons.delete,
  //                       color: Colors.white,
  //                       size: 14,
  //                     ),
  //                   ),
  //                 ),
  //                 const SizedBox(width: 0),
  //               ],
  //             ),
  //
  //             const SizedBox(height: 5),
  //
  //             /// 🔥 COLLAPSED = HORIZONTAL SCROLL
  //             if (!isExpanded)
  //               SingleChildScrollView(
  //                 scrollDirection: Axis.horizontal,
  //                 child: Row(
  //                   children: [
  //                     _miniField("Item", item, "item"),
  //                     _miniField("Qty", item, "qty"),
  //                     _miniField("Purity", item, "outward_carat"),
  //                     _miniField("Waste %", item, "waste"),
  //                     _miniField("Net Purity", item, "net_purity"),
  //                     _miniField("Gross Wt", item, "gross_weight"),
  //                     _miniField("Other Wt", item, "other"),
  //                     _miniField("Net Wt", item, "net_weight"),
  //                     _miniField("Fine Wt", item, "fine_weight"),
  //                     _miniField("Metal Rate", item, "metal_rate"),
  //                     _miniField("Metal Amt", item, "metal_amount"),
  //                     _miniField("Labour Rate", item, "sale_labour_rate"),
  //                     _miniField("Labour Amt", item, "sale_labour_amount"),
  //                     _miniField("Other Amt", item, "other_amount"),
  //                     _miniField("Total Amt", item, "total_amount"),
  //                     _miniField("Remarks", item, "remarks"),
  //                   ],
  //                 ),
  //               ),
  //
  //             //const SizedBox(height: 8),
  //             const SizedBox(height: 10),
  //           ],
  //         ),
  //       ),
  //
  //       /// 🔥 TOP LEFT INDEX BADGE
  //       Positioned(
  //         top: 5,
  //         left: 0,
  //         child: Container(
  //           padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
  //           decoration: BoxDecoration(
  //             color: AppColors.gradientBlue,
  //             borderRadius: BorderRadius.only(
  //               topLeft: Radius.circular(5),
  //               bottomRight: Radius.circular(5),
  //             ),
  //           ),
  //           child: Text(
  //             "${index + 1}", // 🔥 1,2,3...
  //             style: const TextStyle(
  //               color: Colors.white,
  //               fontWeight: FontWeight.bold,
  //               fontSize: 12,
  //             ),
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget approvalItemCard(Map<String, dynamic> item, int index) {
    bool isExpanded = item["expanded"] ?? false;

    /// =========================================================
    /// HEADER DISPLAY VALUES (ONLY UI, data same j che)
    /// =========================================================
    final dynamic rawItem = item["item"];

    String itemName =
        (item["name"] ??
            item["item_name"] ??
            (rawItem is Map ? rawItem["item_name"] : rawItem))
            ?.toString()
            .trim() ??
            "";

    if (itemName.isEmpty || itemName == "null") {
      itemName = "Item";
    }

    final dynamic rawItemset = item["itemset"];

    String qrCode =
    (item["qr_code"] ??
        item["code"] ??
        (rawItemset is Map ? rawItemset["qr_code"] : null) ??
        "")
        .toString()
        .trim();

    if (qrCode == "null") qrCode = "";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// =========================================================
          /// HEADER
          /// =========================================================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withOpacity(0.10),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                /// INDEX
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.gradientBlue,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    "${index + 1}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                /// ITEM NAME
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "ITEM",
                        style: TextStyle(
                          color: Colors.black45,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 1),

                      Text(
                        itemName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                /// QR CODE (jo hoy to j batavo)
                if (qrCode.isNotEmpty) ...[
                  const SizedBox(width: 8),

                  Container(
                    constraints: const BoxConstraints(maxWidth: 130),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.qr_code_2,
                          size: 14,
                          color: AppColors.primaryDark,
                        ),

                        const SizedBox(width: 4),

                        Flexible(
                          child: Text(
                            qrCode,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(width: 7),

                /// DELETE  (🔥 LOGIC BILKUL SAME, fakt UI badlyu che)
                InkWell(
                  onTap: () async {
                    // ============================================================
                    // EDIT MODE
                    // ============================================================
                    if (isEditMode) {
                      final String? jobworkIssueId =
                      item["jobwork_issue_id"]?.toString();

                      final String? jobworkIssueItemId =
                      item["jobwork_issue_item_id"]?.toString();

                      debugPrint("JobWork Issue ID => $jobworkIssueId");
                      debugPrint(
                        "JobWork Issue Item ID => $jobworkIssueItemId",
                      );

                      // API mathi aveli existing row
                      if (jobworkIssueItemId != null &&
                          jobworkIssueItemId.isNotEmpty) {
                        await deleteJobworkItem(
                          jobworkIssueId.toString(),
                          jobworkIssueItemId,
                        );
                      }
                    }

                    // ============================================================
                    // 🔥 CONTROLLERS + FOCUS NODES CLEANUP (row delete before)
                    // ============================================================
                    final String rowId = item["id"].toString();

                    controllers.removeWhere((key, controller) {
                      if (key.startsWith("${rowId}_")) {
                        controller.dispose();
                        return true;
                      }
                      return false;
                    });

                    focusNodes.removeWhere((key, node) {
                      if (key.startsWith("${rowId}_")) {
                        node.dispose();
                        return true;
                      }
                      return false;
                    });

                    // ============================================================
                    // UI MATHI REMOVE
                    // ============================================================
                    if (mounted) {
                      setState(() {
                        searchResults.removeAt(index);
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(5),
                  child: Container(
                    width: 27,
                    height: 27,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xffFF8A80), Color(0xffD32F2F)],
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// =========================================================
          /// HORIZONTAL ITEM DETAILS
          /// =========================================================
          if (!isExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _miniField("Item", item, "item"),
                    _miniField("Qty", item, "qty"),
                    _miniField("Purity", item, "outward_carat"),
                    _miniField("Waste %", item, "waste"),
                    _miniField("Net Purity", item, "net_purity"),
                    _miniField("Gross Wt", item, "gross_weight"),
                    _miniField("Other Wt", item, "other"),
                    _miniField("Net Wt", item, "net_weight"),
                    _miniField("Fine Wt", item, "fine_weight"),
                    _miniField("Metal Rate", item, "metal_rate"),
                    _miniField("Metal Amt", item, "metal_amount"),
                    _miniField("Labour Rate", item, "sale_labour_rate"),
                    _miniField("Labour Amt", item, "sale_labour_amount"),
                    _miniField("Other Amt", item, "other_amount"),
                    _miniField("Total Amt", item, "total_amount"),
                    _miniField("Remarks", item, "remarks"),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniField(String title, Map<String, dynamic> item, String key) {
    final bool isOtherField = key == "other_amount";
    final bool isRemarksField = key == "remarks";
    final bool editable = isEditableField(key);

    final TextEditingController controller = getController(item, key);

    /// ITEM DROPDOWN
    if (key == "item") {
      return _labourDropdown(item);
    }

    return Container(
      width: isRemarksField ? 140 : 105,
      margin: const EdgeInsets.only(right: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// =====================================================
          /// LABEL
          /// =====================================================
          Padding(
            padding: const EdgeInsets.only(left: 2, right: 2, bottom: 4),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          /// =====================================================
          /// FIELD (BORDER SATHE)
          /// =====================================================
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: editable ? Colors.white : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: AppColors.border),
            ),
            child: Stack(
              alignment: Alignment.centerRight,
              children: [
                TextFormField(
                  controller: controller,
                  focusNode: getFocusNode(item, key), // 🔥 SAME
                  /// =====================================================
                  /// EDITABLE / READ ONLY
                  /// =====================================================
                  readOnly: !editable,

                  keyboardType: key == "remarks"
                      ? TextInputType.text
                      : const TextInputType.numberWithOptions(decimal: true),

                  textInputAction: key == "remarks"
                      ? TextInputAction.next
                      : TextInputAction.done,

                  enableInteractiveSelection: editable,
                  showCursor: editable,
                  canRequestFocus: editable,

                  style: TextStyle(
                    color: editable ? Colors.black : Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),

                  /// =====================================================
                  /// KEYBOARD LAG FIX
                  /// =====================================================
                  onChanged: (val) {
                    item[key] = val;

                    // ============================================================
                    // LIVE WEIGHT CALCULATION
                    // ============================================================
                    if (key == "gross_weight" ||
                        key == "other" ||
                        key == "outward_carat" ||
                        key == "waste" ||
                        key == "metal_rate" ||
                        key == "sale_labour_rate") {
                      final String timerKey = "${item["id"]}_calculation";

                      rowTimers[timerKey]?.cancel();

                      rowTimers[timerKey] = Timer(
                        const Duration(milliseconds: 100),
                            () {
                          if (!mounted) return;

                          calculateItem(item);
                        },
                      );
                    }
                  },

                  /// =====================================================
                  /// CALCULATE AFTER FIELD EDIT COMPLETE
                  /// =====================================================
                  onEditingComplete: () {
                    item[key] = controller.text;

                    calculateItem(item);

                    /// Whole screen rebuild ni normally need nathi,
                    /// because calculateItem controllers update kare chhe.
                    ///
                    /// Keyboard close
                    FocusScope.of(context).unfocus();
                  },

                  /// =====================================================
                  /// USER SUBMIT
                  /// =====================================================
                  onFieldSubmitted: (value) {
                    item[key] = value;

                    calculateItem(item);

                    FocusScope.of(context).unfocus();
                  },

                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.only(
                      left: 8,
                      right: isOtherField ? 30 : 8,
                      top: 9,
                      bottom: 9,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),

                /// =====================================================
                /// OTHER CHARGE BUTTON
                /// =====================================================
                if (isOtherField)
                  Positioned(
                    right: 4,
                    child: InkWell(
                      onTap: () async {
                        FocusManager.instance.primaryFocus?.unfocus();

                        await getApprovalDetails(item["id"], item);

                        Future.delayed(const Duration(milliseconds: 100), () {
                          FocusManager.instance.primaryFocus?.unfocus();
                        });

                        calculateItem(item);

                        if (mounted) {
                          setState(() {});
                        }
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xffC8A96A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 15,
                          color: Colors.white,
                        ),
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

  Future<void> getApprovalDetails(
      dynamic id,
      Map<String, dynamic> mainItem,
      ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final response = await ApiHelper().getRequest(
      ApiConstants.jobwork_issues_other_charges,
    );

    Navigator.pop(context);

    if (response != null && response.statusCode == 200) {
      /// 🔥 BYTES → STRING → JSON
      final data = response.data;

      final item = data["data"] is List ? data["data"][0] : data["data"];

      showOtherChargesPopup(
        mainItem, // 🔥 ORIGINAL ITEM
        data["data"], // 🔥 API LIST
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to load details")));
    }
  }

  void showOtherChargesPopup(Map<String, dynamic> item, List apiList) {
    /// ============================================================
    /// 🔥 EXISTING SELECTED CHARGE ID (Edit mode / already saved item)
    /// Jo item ma pehla thi j other_charge_id save thai chuklo hoy,
    /// to popup khulta j e charge pre-selected (checkbox ✓) dekhadvu.
    /// ============================================================
    final int? existingChargeId = int.tryParse(
      item["other_charge_id"]?.toString() ?? "",
    );

    /// ============================================================
    /// MAP API -> UI STRUCTURE
    /// ============================================================
    List<Map<String, dynamic>> charges = apiList.map<Map<String, dynamic>>((e) {
      final int chargeId = int.tryParse(e["id"]?.toString() ?? "") ?? 0;

      return {
        "id": e["id"],
        "charge": e["name"]?.toString() ?? "",
        "amount": (e["default_amount"] ?? 0).toString(),
        "qty": (e["quantity_pcs"] ?? 1).toString(),
        "weight": (e["default_weight"] ?? 0).toString(),
        "wt_formula": (e["weight_formula"]?.toString().toLowerCase() == "per_quantity")
            ? "per_qty"
            : (e["weight_formula"]?.toString().toLowerCase() == "per_weight")
            ? "per_weight"
            : "flat",
        "amt_formula_type": (e["other_amt_formula"]?.toString().toLowerCase() == "per_quantity")
            ? "per_qty"
            : (e["other_amt_formula"]?.toString().toLowerCase() == "per_weight")
            ? "per_weight"
            : (e["other_amt_formula"]?.toString().toLowerCase() == "per_qty_weight")
            ? "per_qty_weight"
            : "flat",
        "total_weight": "0.000",
        "total_amt": "0.00",

        /// 🔥 FIX: existing other_charge_id sathe match thay to pre-select
        "is_selected": existingChargeId != null && existingChargeId == chargeId,
      };
    }).toList();

    /// ============================================================
    /// 🔥 PERSISTENT CONTROLLERS
    /// (initialValue vaparta hata etle typing lag/cursor jump thato
    /// hato — have controller-based, dialog khulo rahe tya sudhi
    /// ek j vaar banave)
    /// ============================================================
    final Map<int, Map<String, TextEditingController>> rowControllers = {};

    for (int i = 0; i < charges.length; i++) {
      rowControllers[i] = {
        "amount": TextEditingController(text: charges[i]["amount"]?.toString() ?? "0"),
        "qty": TextEditingController(text: charges[i]["qty"]?.toString() ?? "1"),
        "weight": TextEditingController(text: charges[i]["weight"]?.toString() ?? "0"),
      };
    }

    /// ============================================================
    /// SINGLE-ROW CALCULATION (akhi list nahi, EK j row)
    /// ============================================================
    void calculateSingleCharge(Map<String, dynamic> c) {
      double amt = double.tryParse(c["amount"]?.toString() ?? "0") ?? 0;
      double qty = double.tryParse(c["qty"]?.toString() ?? "1") ?? 1;
      double weight = double.tryParse(c["weight"]?.toString() ?? "1") ?? 1;

      String amtFormula = c["amt_formula_type"] ?? "flat";
      String wtFormula = c["wt_formula"] ?? "flat";

      double totalAmt = 0;
      double totalWeight = 0;

      switch (wtFormula) {
        case "per_qty":
          totalWeight = weight * qty;
          break;
        case "per_weight":
          totalWeight = weight * qty;
          break;
        default:
          totalWeight = weight;
      }

      c["total_weight"] = totalWeight.toStringAsFixed(2);

      switch (amtFormula) {
        case "per_qty":
          totalAmt = amt * qty;
          c["amt_formula"] = "$amt × $qty";
          break;
        case "per_weight":
          totalAmt = amt * totalWeight;
          c["amt_formula"] = "$amt × $totalWeight";
          break;
        case "per_qty_weight":
          totalAmt = amt * qty * weight;
          c["amt_formula"] = "$amt × $qty × $weight";
          break;
        default:
          totalAmt = amt;
          c["amt_formula"] = "$amt";
      }

      c["total_amt"] = totalAmt.toStringAsFixed(2);
    }

    /// Initial calculation — dialog khule tyare ek j vaar
    for (final c in charges) {
      calculateSingleCharge(c);
    }

    double calcTotal() {
      double total = 0;
      for (final c in charges) {
        if (c["is_selected"] == true) {
          total += double.tryParse(c["total_amt"]?.toString() ?? "0") ?? 0;
        }
      }
      return total;
    }

    /// 🔥 FIX: pehla thi j selected charge no index find karo (SINGLE)
    int? initialSelectedIndex;
    for (int i = 0; i < charges.length; i++) {
      if (charges[i]["is_selected"] == true) {
        initialSelectedIndex = i;
        break;
      }
    }

    /// ============================================================
    /// 🔥 ValueNotifiers — akhu dialog rebuild na thay e mate
    /// SINGLE-SELECT: Set<int> na badle int?
    /// ============================================================
    final ValueNotifier<double> totalNotifier = ValueNotifier<double>(calcTotal());
    final ValueNotifier<int?> selectedIndexNotifier =
    ValueNotifier<int?>(initialSelectedIndex);

    void disposeControllers() {
      for (final ctrls in rowControllers.values) {
        for (final c in ctrls.values) {
          c.dispose();
        }
      }
    }

    // ==================================================
    // PREMIUM INPUT DECORATION (BLUE THEME)
    // ==================================================
    InputDecoration premiumInputDecoration() {
      return InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.gradientBlue, width: 1.4),
        ),
      );
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.50),
      builder: (dialogContext) {
        final Size screenSize = MediaQuery.of(dialogContext).size;
        final bool isTablet = screenSize.width >= 600;

        Widget headerCell(String title, double width) {
          return SizedBox(
            width: width,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }

        return Dialog(
          elevation: 0,
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: isTablet ? 30 : 12,
            vertical: 18,
          ),
          child: Container(
            width: isTablet ? 1050 : double.infinity,
            constraints: BoxConstraints(maxHeight: screenSize.height * 0.88),
            decoration: BoxDecoration(
              color: const Color(0xffF5F8FC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.gradientBlue.withOpacity(0.20)),
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
                  // ============================================================
                  // HEADER — PREMIUM BLUE GRADIENT
                  // ============================================================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primaryDark, AppColors.gradientBlue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.13),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withOpacity(0.18)),
                          ),
                          child: const Icon(Icons.receipt_long_outlined, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Other Charges",
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                              SizedBox(height: 2),
                              Text("Manage item charges and calculation",
                                  style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text("${charges.length} Charges",
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              disposeControllers();
                              Navigator.pop(dialogContext);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ============================================================
                  // BODY
                  // ============================================================
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ============================================================
                          // SECTION TITLE
                          // ============================================================
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.gradientBlue.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.tune_rounded, size: 15, color: AppColors.gradientBlue),
                              ),
                              const SizedBox(width: 7),
                              const Text("Charge Details",
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
                              const Spacer(),
                              ValueListenableBuilder<int?>(
                                valueListenable: selectedIndexNotifier,
                                builder: (context, selectedIndex, _) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.gradientBlue.withOpacity(0.07),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      "${selectedIndex != null ? 1 : 0} Selected",
                                      style: const TextStyle(
                                          color: AppColors.primaryDark, fontSize: 9.5, fontWeight: FontWeight.w600),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 9),

                          // ============================================================
                          // TABLE
                          // ============================================================
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Container(
                              width: 900,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: AppColors.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // ============================================================
                                  // TABLE HEADER — BLUE GRADIENT STRIP
                                  // ============================================================
                                  Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [AppColors.primaryDark, AppColors.gradientBlue],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(8),
                                        topRight: Radius.circular(8),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 106,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6),
                                            child: Text(
                                              "Charge",
                                              style: const TextStyle(
                                                  color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                        ),
                                        headerCell("Amt", 80),
                                        headerCell("Qty", 70),
                                        headerCell("Weight", 90),
                                        headerCell("Wt Formula", 105),
                                        headerCell("Total Wt", 105),
                                        headerCell("Amt Formula", 110),
                                        headerCell("Total Amt", 105),
                                        const SizedBox(
                                          width: 45,
                                          child: Center(
                                            child: Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 16),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  Divider(height: 1, color: AppColors.border),

                                  // ============================================================
                                  // LIST
                                  // ============================================================
                                  SizedBox(
                                    height: 230,
                                    child: charges.isEmpty
                                        ? const Center(
                                      child: Text(
                                        "No charges available",
                                        style: TextStyle(color: Colors.black45, fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    )
                                        : ListView.separated(
                                      padding: const EdgeInsets.symmetric(vertical: 5),
                                      itemCount: charges.length,
                                      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border),
                                      itemBuilder: (context, index) {
                                        final c = charges[index];

                                        /// ========================================================
                                        /// 🔥 KEY FIX: har row ni potani StatefulBuilder
                                        /// → matra AA row rebuild thay, akhu dialog nahi
                                        /// ========================================================
                                        return StatefulBuilder(
                                          builder: (context, setStateRow) {
                                            void onFieldChanged() {
                                              c["amount"] = rowControllers[index]!["amount"]!.text;
                                              c["qty"] = rowControllers[index]!["qty"]!.text;
                                              c["weight"] = rowControllers[index]!["weight"]!.text;

                                              calculateSingleCharge(c);

                                              setStateRow(() {});

                                              totalNotifier.value = calcTotal();
                                            }

                                            return ValueListenableBuilder<int?>(
                                              valueListenable: selectedIndexNotifier,
                                              builder: (context, selectedIndex, _) {
                                                final bool selected = selectedIndex == index;

                                                return AnimatedContainer(
                                                  duration: const Duration(milliseconds: 150),
                                                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                                  decoration: BoxDecoration(
                                                    color: selected
                                                        ? AppColors.gradientBlue.withOpacity(0.035)
                                                        : Colors.white,
                                                    border: Border(
                                                      left: BorderSide(
                                                        color: selected ? AppColors.gradientBlue : Colors.transparent,
                                                        width: 3,
                                                      ),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      // ===================
                                                      // CHARGE
                                                      // ===================
                                                      SizedBox(
                                                        width: 106,
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 5),
                                                          child: Row(
                                                            children: [
                                                              Container(
                                                                width: 24,
                                                                height: 24,
                                                                alignment: Alignment.center,
                                                                decoration: BoxDecoration(
                                                                  color: selected
                                                                      ? AppColors.gradientBlue.withOpacity(0.15)
                                                                      : AppColors.gradientBlue.withOpacity(0.06),
                                                                  borderRadius: BorderRadius.circular(6),
                                                                ),
                                                                child: Text(
                                                                  "${index + 1}",
                                                                  style: const TextStyle(
                                                                    color: AppColors.primaryDark,
                                                                    fontSize: 9,
                                                                    fontWeight: FontWeight.w700,
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(width: 5),
                                                              Expanded(
                                                                child: Text(
                                                                  c["charge"]?.toString() ?? "",
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                  style: TextStyle(
                                                                    fontSize: 10.5,
                                                                    fontWeight:
                                                                    selected ? FontWeight.w700 : FontWeight.w600,
                                                                    color: AppColors.primaryDark,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),

                                                      // ===================
                                                      // AMOUNT
                                                      // ===================
                                                      SizedBox(
                                                        width: 80,
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 3),
                                                          child: TextFormField(
                                                            controller: rowControllers[index]!["amount"],
                                                            keyboardType:
                                                            const TextInputType.numberWithOptions(decimal: true),
                                                            textAlign: TextAlign.center,
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w600,
                                                              color: AppColors.primaryDark,
                                                            ),
                                                            onChanged: (_) => onFieldChanged(),
                                                            decoration: premiumInputDecoration(),
                                                          ),
                                                        ),
                                                      ),

                                                      // ===================
                                                      // QTY
                                                      // ===================
                                                      SizedBox(
                                                        width: 70,
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 3),
                                                          child: TextFormField(
                                                            controller: rowControllers[index]!["qty"],
                                                            keyboardType:
                                                            const TextInputType.numberWithOptions(decimal: true),
                                                            textAlign: TextAlign.center,
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w600,
                                                              color: AppColors.primaryDark,
                                                            ),
                                                            onChanged: (_) => onFieldChanged(),
                                                            decoration: premiumInputDecoration(),
                                                          ),
                                                        ),
                                                      ),

                                                      // ===================
                                                      // WEIGHT
                                                      // ===================
                                                      SizedBox(
                                                        width: 90,
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 3),
                                                          child: TextFormField(
                                                            controller: rowControllers[index]!["weight"],
                                                            keyboardType:
                                                            const TextInputType.numberWithOptions(decimal: true),
                                                            textAlign: TextAlign.center,
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w600,
                                                              color: AppColors.primaryDark,
                                                            ),
                                                            onChanged: (_) => onFieldChanged(),
                                                            decoration: premiumInputDecoration(),
                                                          ),
                                                        ),
                                                      ),

                                                      // ===================
                                                      // WT FORMULA
                                                      // ===================
                                                      SizedBox(
                                                        width: 105,
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 3),
                                                          child: DropdownButtonFormField<String>(
                                                            value: c["wt_formula"],
                                                            isExpanded: true,
                                                            dropdownColor: Colors.white,
                                                            icon: const Icon(
                                                              Icons.keyboard_arrow_down_rounded,
                                                              color: AppColors.gradientBlue,
                                                              size: 17,
                                                            ),
                                                            style: const TextStyle(
                                                              fontSize: 10,
                                                              color: AppColors.primaryDark,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                            decoration: premiumInputDecoration(),
                                                            items: const [
                                                              DropdownMenuItem(value: "flat", child: Text("Flat")),
                                                              DropdownMenuItem(value: "per_qty", child: Text("Per Qty")),
                                                              DropdownMenuItem(value: "per_weight", child: Text("Per Wt")),
                                                            ],
                                                            onChanged: (v) {
                                                              if (v == null) return;
                                                              c["wt_formula"] = v;
                                                              onFieldChanged();
                                                            },
                                                          ),
                                                        ),
                                                      ),

                                                      // ===================
                                                      // TOTAL WEIGHT
                                                      // ===================
                                                      SizedBox(
                                                        width: 105,
                                                        child: Center(
                                                          child: Container(
                                                            constraints: const BoxConstraints(minWidth: 66),
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                                                            decoration: BoxDecoration(
                                                              color: AppColors.gradientBlue.withOpacity(0.06),
                                                              borderRadius: BorderRadius.circular(6),
                                                              border: Border.all(color: AppColors.border),
                                                            ),
                                                            child: Text(
                                                              c["total_weight"]?.toString() ?? "0.00",
                                                              textAlign: TextAlign.center,
                                                              style: const TextStyle(
                                                                fontSize: 10.5,
                                                                fontWeight: FontWeight.w700,
                                                                color: AppColors.primaryDark,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),

                                                      // ===================
                                                      // AMT FORMULA
                                                      // ===================
                                                      SizedBox(
                                                        width: 110,
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 3),
                                                          child: DropdownButtonFormField<String>(
                                                            value: c["amt_formula_type"] ?? "flat",
                                                            isExpanded: true,
                                                            dropdownColor: Colors.white,
                                                            icon: const Icon(
                                                              Icons.keyboard_arrow_down_rounded,
                                                              color: AppColors.gradientBlue,
                                                              size: 17,
                                                            ),
                                                            style: const TextStyle(
                                                              fontSize: 9.8,
                                                              color: AppColors.primaryDark,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                            decoration: premiumInputDecoration(),
                                                            items: const [
                                                              DropdownMenuItem(value: "flat", child: Text("Flat")),
                                                              DropdownMenuItem(value: "per_qty", child: Text("Per Qty")),
                                                              DropdownMenuItem(value: "per_weight", child: Text("Per Wt")),
                                                              DropdownMenuItem(
                                                                  value: "per_qty_weight", child: Text("Qty × Wt")),
                                                            ],
                                                            onChanged: (v) {
                                                              if (v == null) return;
                                                              c["amt_formula_type"] = v;
                                                              onFieldChanged();
                                                            },
                                                          ),
                                                        ),
                                                      ),

                                                      // ===================
                                                      // TOTAL AMOUNT
                                                      // ===================
                                                      SizedBox(
                                                        width: 105,
                                                        child: Center(
                                                          child: Container(
                                                            constraints: const BoxConstraints(minWidth: 70),
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                                                            decoration: BoxDecoration(
                                                              color: const Color(0xFFEAF1FF),
                                                              borderRadius: BorderRadius.circular(6),
                                                              border: Border.all(
                                                                color: AppColors.gradientBlue.withOpacity(0.15),
                                                              ),
                                                            ),
                                                            child: Text(
                                                              c["total_amt"]?.toString() ?? "0.00",
                                                              textAlign: TextAlign.center,
                                                              style: const TextStyle(
                                                                fontSize: 10.5,
                                                                fontWeight: FontWeight.w800,
                                                                color: AppColors.primaryDark,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),

                                                      // ===================
                                                      // CHECKBOX (SINGLE-SELECT)
                                                      // ===================
                                                      SizedBox(
                                                        width: 45,
                                                        child: Center(
                                                          child: Transform.scale(
                                                            scale: 0.88,
                                                            child: Checkbox(
                                                              value: selected,
                                                              activeColor: AppColors.gradientBlue,
                                                              checkColor: Colors.white,
                                                              side: BorderSide(
                                                                color: AppColors.gradientBlue.withOpacity(0.6),
                                                                width: 1.3,
                                                              ),
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              onChanged: (val) {
                                                                /// 🔥 SINGLE SELECT LOGIC
                                                                /// Pehla je selected hato tene deselect karo
                                                                if (selectedIndexNotifier.value != null) {
                                                                  charges[selectedIndexNotifier.value!]
                                                                  ["is_selected"] = false;
                                                                }

                                                                if (val == true) {
                                                                  c["is_selected"] = true;
                                                                  selectedIndexNotifier.value = index;
                                                                } else {
                                                                  c["is_selected"] = false;
                                                                  selectedIndexNotifier.value = null;
                                                                }

                                                                totalNotifier.value = calcTotal();
                                                              },
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // ============================================================
                          // TOTAL SUMMARY — PREMIUM BLUE CARD
                          // ============================================================
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF3F7FF), Color(0xFFEAF1FF)],
                              ),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: AppColors.gradientBlue.withOpacity(0.15)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.calculate_outlined, size: 18, color: AppColors.gradientBlue),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Selected Charges Total",
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: AppColors.primaryDark,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      ValueListenableBuilder<int?>(
                                        valueListenable: selectedIndexNotifier,
                                        builder: (context, selectedIndex, _) {
                                          return Text(
                                            "${selectedIndex != null ? 1 : 0} of ${charges.length} charges selected",
                                            style: const TextStyle(fontSize: 9.5, color: Colors.black54),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                ValueListenableBuilder<double>(
                                  valueListenable: totalNotifier,
                                  builder: (context, total, _) {
                                    return Text(
                                      total.toStringAsFixed(2),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        color: AppColors.primaryDark,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ============================================================
                  // BOTTOM ACTION BAR
                  // ============================================================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      children: [
                        // ===============================
                        // CANCEL
                        // ===============================
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: OutlinedButton(
                              onPressed: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                disposeControllers();
                                Navigator.pop(dialogContext);
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                side: BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                              ),
                              child: const Text(
                                "Cancel",
                                style: TextStyle(color: AppColors.primaryDark, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        // ===============================
                        // APPLY
                        // ===============================
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 42,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(7),
                                onTap: () {
                                  double selectedTotal = 0;
                                  int selectedChargeId = 0;

                                  for (final c in charges) {
                                    if (c["is_selected"] == true) {
                                      selectedTotal += double.tryParse(c["total_amt"]?.toString() ?? "0") ?? 0;
                                      selectedChargeId = int.tryParse(c["id"].toString()) ?? 0;
                                    }
                                  }

                                  /// 🔥 STORE IN ITEM — only the amount goes into
                                  /// Other Amt; Other Wt is left untouched.
                                  item["other_charge_id"] = selectedChargeId;
                                  item["other_amount"] = selectedTotal.toStringAsFixed(2);

                                  updateController(item, "other_amount");

                                  calculateItem(item);

                                  FocusManager.instance.primaryFocus?.unfocus();

                                  disposeControllers();

                                  Navigator.pop(dialogContext);

                                  setState(() {});
                                },
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [AppColors.primaryDark, AppColors.gradientBlue],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(7),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.gradientBlue.withOpacity(0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 17),
                                      SizedBox(width: 6),
                                      Text(
                                        "Apply Charges",
                                        style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
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
        );
      },
    );
  }

  void calculateItem(Map<String, dynamic> item) {
    // ============================================================
    // GROSS WEIGHT
    // ============================================================
    final double gross =
        double.tryParse(getController(item, "gross_weight").text.trim()) ?? 0.0;

    // ============================================================
    // OTHER WEIGHT
    // ============================================================
    final double other =
        double.tryParse(getController(item, "other").text.trim()) ?? 0.0;

    // ============================================================
    // NET WEIGHT
    //
    // API:
    // gross_wt - other_wt = net_wt
    // ============================================================
    double net = gross - other;

    if (net < 0) {
      net = 0;
    }

    // ============================================================
    // PURITY
    // API field = purity
    // UI field  = outward_carat
    // ============================================================
    final double purity =
        double.tryParse(getController(item, "outward_carat").text.trim()) ??
            0.0;

    // ============================================================
    // WASTE %
    // ============================================================
    final double waste =
        double.tryParse(getController(item, "waste").text.trim()) ?? 0.0;

    // ============================================================
    // NET PURITY
    //
    // net_purity = purity + waste
    // ============================================================
    final double netPurity = purity + waste;

    // ============================================================
    // FINE WEIGHT
    //
    // fine_wt = net_wt × net_purity / 100
    //
    // Example:
    // 50 × 95 / 100 = 47.500
    // ============================================================
    final double fineWeight = net * (netPurity / 100);

    // ============================================================
    // METAL AMOUNT
    //
    // metal_amt = fine_wt × metal_rate
    // ============================================================
    final double metalRate =
        double.tryParse(getController(item, "metal_rate").text.trim()) ?? 0.0;

    final double metalAmount = fineWeight * metalRate;

    // ============================================================
    // LABOUR AMOUNT
    //
    // labour_amt = net_wt × labour_rate
    // ============================================================
    final double labourRate =
        double.tryParse(getController(item, "sale_labour_rate").text.trim()) ??
            0.0;

    final double labourAmount = net * labourRate;

    // ============================================================
    // OTHER AMOUNT (from Other Charges popup / manual entry)
    // ============================================================
    final double otherAmount =
        double.tryParse(getController(item, "other_amount").text.trim()) ??
            0.0;

    // ============================================================
    // TOTAL AMOUNT
    //
    // total_amt = metal_amt + labour_amt + other_amt
    // ============================================================
    final double totalAmount = metalAmount + labourAmount + otherAmount;

    // ============================================================
    // STORE IN ITEM
    // ============================================================
    item["gross_weight"] = gross == 0
        ? getController(item, "gross_weight").text
        : gross.toString();

    item["other"] = getController(item, "other").text;

    item["net_weight"] = net.toStringAsFixed(3);

    item["net_purity"] = netPurity.toStringAsFixed(2);

    item["fine_weight"] = fineWeight.toStringAsFixed(3);

    item["metal_amount"] = metalAmount.toStringAsFixed(2);

    item["sale_labour_amount"] = labourAmount.toStringAsFixed(2);

    item["other_amount"] = otherAmount.toStringAsFixed(2);

    item["total_amount"] = totalAmount.toStringAsFixed(2);

    // ============================================================
    // UPDATE READ ONLY CONTROLLERS
    // ============================================================
    updateController(item, "net_weight");

    updateController(item, "net_purity");

    updateController(item, "fine_weight");

    updateController(item, "metal_amount");

    updateController(item, "sale_labour_amount");

    updateController(item, "other_amount");

    updateController(item, "total_amount");

    debugPrint(
      "CALC => "
          "Gross=$gross | Other=$other | Net=${net.toStringAsFixed(3)} | "
          "Purity=$purity | Waste=$waste | NetPurity=${netPurity.toStringAsFixed(2)} | "
          "Fine=${fineWeight.toStringAsFixed(3)} | MetalAmt=${metalAmount.toStringAsFixed(2)} | "
          "LabourAmt=${labourAmount.toStringAsFixed(2)} | OtherAmt=${otherAmount.toStringAsFixed(2)} | "
          "Total=${totalAmount.toStringAsFixed(2)}",
    );
  }

  void updateController(Map item, String key) {
    String uniqueKey = "${item["id"]}_$key";

    if (controllers.containsKey(uniqueKey)) {
      String newVal = item[key]?.toString() ?? "";

      if (controllers[uniqueKey]!.text != newVal) {
        controllers[uniqueKey]!.text = newVal;
      }
    }
  }

  Map<String, TextEditingController> controllers = {};

  TextEditingController getController(Map item, String key) {
    final uniqueKey = "${item["id"]}_$key";

    if (!controllers.containsKey(uniqueKey)) {
      controllers[uniqueKey] = TextEditingController(
        text: item[key]?.toString() ?? "",
      );
    }

    return controllers[uniqueKey]!;
  }

  bool isEditableField(String key) {
    return [
      "gross_weight",
      "other",
      "outward_carat",
      "waste",
      "sale_labour_rate",
      "metal_rate",
      "qty",
      "remarks",
    ].contains(key);
  }

  Widget _labourDropdown(Map<String, dynamic> item) {
    final provider = Provider.of<ItemProvider>(context);

    /// Current selected item name
    final String selectedValue = (item["item"] ?? "").toString().trim();

    /// ============================================================
    /// UNIQUE ITEM LIST
    /// ============================================================
    final List<String> options = provider.items
        .map<String>((e) => (e["item_name"] ?? "").toString().trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    /// Edit mode ma selected value API list ma na hoy
    /// to pan dropdown ma show thase.
    if (selectedValue.isNotEmpty && !options.contains(selectedValue)) {
      options.insert(0, selectedValue);
    }

    return Container(
      width: 155,
      height: 55,
      margin: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// ======================================================
          /// LABEL
          /// ======================================================
          const Text(
            "Item Name",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 3),

          /// ======================================================
          /// DROPDOWN
          /// ======================================================
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: DropdownSearch<String>(
                items: options,

                /// =================================================
                /// SELECTED ITEM
                /// =================================================
                selectedItem: selectedValue.isNotEmpty ? selectedValue : null,

                /// =================================================
                /// POPUP
                /// =================================================
                popupProps: PopupProps.bottomSheet(
                  showSearchBox: true,
                  showSelectedItems: true,

                  /// Popup height
                  constraints: const BoxConstraints(maxHeight: 500),

                  /// =================================================
                  /// SEARCH FIELD
                  /// =================================================
                  searchFieldProps: TextFieldProps(
                    style: const TextStyle(color: Colors.black87, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "Search item...",

                      hintStyle: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),

                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: AppColors.primaryDark,
                      ),

                      filled: true,
                      fillColor: Colors.grey.shade50,

                      isDense: true,

                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),

                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide: BorderSide(color: AppColors.border),
                      ),

                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide: BorderSide(color: AppColors.border),
                      ),

                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide: const BorderSide(
                          color: AppColors.primaryDark,
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),

                  /// =================================================
                  /// POPUP CONTAINER
                  /// =================================================
                  containerBuilder: (context, popupWidget) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: popupWidget,
                      ),
                    );
                  },

                  /// =================================================
                  /// ITEM UI
                  /// =================================================
                  itemBuilder: (context, itemName, isSelected) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      color: isSelected
                          ? AppColors.primaryDark.withOpacity(0.06)
                          : Colors.transparent,
                      child: Row(
                        children: [
                          /// ICON
                          Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryDark
                                  : AppColors.primaryDark.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.inventory_2_outlined,
                              size: 16,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.primaryDark,
                            ),
                          ),

                          const SizedBox(width: 9),

                          /// NAME
                          Expanded(
                            child: Text(
                              itemName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ),

                          /// SELECTED CHECK
                          if (isSelected)
                            Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryDark,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    );
                  },

                  emptyBuilder: (context, searchEntry) {
                    return Center(
                      child: Text(
                        "No Item Found",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  },
                ),

                /// =================================================
                /// MAIN FIELD DECORATION
                /// =================================================
                dropdownDecoratorProps: const DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    isDense: true,

                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),

                    hintText: "Select Item",

                    hintStyle: TextStyle(color: Colors.grey, fontSize: 11),

                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),

                /// =================================================
                /// SELECTED VALUE UI
                /// =================================================
                dropdownBuilder: (context, selectedItem) {
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedItem ?? "Select Item",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selectedItem == null
                                ? Colors.grey.shade500
                                : Colors.black87,
                            fontSize: 13,
                            fontWeight: selectedItem == null
                                ? FontWeight.w400
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  );
                },

                /// =================================================
                /// ON CHANGE
                /// =================================================
                onChanged: (val) {
                  if (val == null) {
                    return;
                  }

                  /// Selected API item
                  final Map<String, dynamic> selectedItem = provider.items
                      .firstWhere(
                        (e) =>
                    (e["item_name"] ?? "").toString().trim() ==
                        val.trim(),
                    orElse: () => <String, dynamic>{},
                  );

                  if (selectedItem.isEmpty) {
                    return;
                  }

                  /// =================================================
                  /// STORE NAME
                  /// =================================================
                  item["item"] = val;

                  /// =================================================
                  /// STORE ITEM ID
                  /// =================================================
                  item["item_id"] = selectedItem["id"];

                  /// =================================================
                  /// OUTWARD CARAT
                  /// =================================================
                  final String outwardCarat =
                      selectedItem["outward_carat"]?.toString() ?? "0";

                  /// =================================================
                  /// OUTWARD PURITY
                  /// =================================================
                  final String outwardPurity =
                      selectedItem["outward_purity"]?.toString() ?? "0";

                  /// UI data
                  item["outward_carat"] = outwardCarat;

                  item["net_purity"] = outwardPurity;

                  /// Controllers
                  getController(item, "outward_carat").text = outwardCarat;

                  getController(item, "net_purity").text = outwardPurity;

                  /// Recalculate
                  calculateItem(item);

                  setState(() {});

                  debugPrint("Item ID: ${item["item_id"]}");

                  debugPrint("Item Name: ${item["item"]}");

                  debugPrint("Outward Carat: $outwardCarat");

                  debugPrint("Outward Purity: $outwardPurity");
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String formatDateForApi(String date) {
    if (date.isEmpty) return "";

    final parts = date.split("-");

    if (parts.length != 3) return "";

    return "${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}";
  }

  Future<bool> deleteJobworkItem(
      String jobworkIssueId,
      String jobworkIssueItemId,
      ) async {
    try {
      final response = await ApiHelper().deleteRequest(
        "${ApiConstants.jobwork_issues}/$jobworkIssueId/items/$jobworkIssueItemId",
      );

      print(
        "🗑 DELETE API => "
            "${ApiConstants.jobwork_issues}/$jobworkIssueId/items/$jobworkIssueItemId",
      );

      print("DELETE STATUS => ${response?.statusCode}");
      print("DELETE RESPONSE => ${response?.data}");

      if (response?.statusCode == 200 || response?.statusCode == 204) {
        print("✅ Item Deleted Successfully");
        return true;
      }

      print("❌ Delete Failed");
      return false;
    } catch (e) {
      print("❌ Delete exception: $e");
      return false;
    }
  }

  Widget _buildBottomSummary() {
    double totalGross = 0;
    double totalOther = 0;
    double totalNet = 0;
    double totalFine = 0;
    double totalAmount = 0;
    int totalQty = 0;

    // ============================================================
    // CALCULATE ALL ROW TOTALS
    // ============================================================
    for (final item in searchResults) {
      totalGross +=
          double.tryParse(item["gross_weight"]?.toString() ?? "0") ?? 0;

      totalOther += double.tryParse(item["other"]?.toString() ?? "0") ?? 0;

      totalNet += double.tryParse(item["net_weight"]?.toString() ?? "0") ?? 0;

      totalFine += double.tryParse(item["fine_weight"]?.toString() ?? "0") ?? 0;

      totalQty += int.tryParse(item["qty"]?.toString() ?? "0") ?? 0;

      totalAmount +=
          double.tryParse(item["total_amount"]?.toString() ?? "0") ?? 0;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(0, 5, 0, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withOpacity(0.08),
        borderRadius: BorderRadius.circular(0),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _summaryItem("Gross", totalGross.toStringAsFixed(3)),

            _summaryDivider(),

            _summaryItem("Other", totalOther.toStringAsFixed(3)),

            _summaryDivider(),

            _summaryItem("Net", totalNet.toStringAsFixed(3)),

            _summaryDivider(),

            _summaryItem("Fine", totalFine.toStringAsFixed(3)),

            _summaryDivider(),

            _summaryItem("Qty", totalQty.toString()),

            _summaryDivider(),

            _summaryItem("Amount", totalAmount.toStringAsFixed(2)),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String title, String value) {
    return Container(
      constraints: const BoxConstraints(minWidth: 72),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider() {
    return Container(width: 1, height: 30, color: AppColors.border);
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    for (final f in focusNodes.values) {
      f.dispose();
    }
    Carat_Controller.dispose();
    purity_Controller.dispose();
    fromDateController.dispose();
    remarksController.dispose();
    super.dispose();
  }
}

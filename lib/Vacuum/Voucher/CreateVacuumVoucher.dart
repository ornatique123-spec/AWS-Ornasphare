import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:pecifician_sysytem/Vacuum/Voucher/VoucherScreen.dart';
import 'package:provider/provider.dart';
import '../../Api_Constant/ApiConstants.dart';
import '../../Api_Constant/api_helper.dart';
import '../../Extra/AppColors.dart';
import '../../Extra/AppMessage.dart';
import '../../Extra/ItemProvider.dart';
import '../../Extra/PremiumSearchableDropdown.dart';
import '../../Offline Data/offline_api_helper.dart';

class Createvacuumvoucher extends StatefulWidget {
  final Map? userData;

  const Createvacuumvoucher({super.key, this.userData});

  @override
  State<Createvacuumvoucher> createState() => _CreatevacuumvoucherState();
}

class _CreatevacuumvoucherState extends State<Createvacuumvoucher> {
  /// =========================================================
  /// 🔥 MINI FIELD SIZES — બધા fields એક જ shape માં
  /// =========================================================
  static const double _miniRowH = 55; // Buch / Item dropdown જેટલી
  static const double _miniLabelH = 15;
  static const double _miniGap = 4;
  static const double _miniBoxH = _miniRowH - _miniLabelH - _miniGap; // 36

  double _miniWidth(String key) {
    switch (key) {
      case "item":
        return 130; // Buch No
      case "item_name":
        return 160; // Item (થોડી વધારે)
      case "remarks":
        return 160;
      default:
        return 90;
    }
  }

  /// =========================================================
  /// CONTROLLERS
  /// =========================================================
  final TextEditingController silverFormulaController = TextEditingController(
    text: "11",
  );
  final TextEditingController fromDateController = TextEditingController();
  final TextEditingController remarks = TextEditingController();

  bool get isEditMode => widget.userData != null;

  String? selectedRole; // Worker id
  String? selectedProcess; // Process id
  DateTime? fromDate;

  List searchResults = [];
  Map<String, TextEditingController> controllers = {};

  /// 🔥 Unique row id માટે counter (loop માં same id ના બને)
  int _rowCounter = 0;

  @override
  void initState() {
    super.initState();

    final DateTime today = DateTime.now();
    fromDateController.text = "${today.day}-${today.month}-${today.year}";

    Future.microtask(() async {
      final provider = Provider.of<ItemProvider>(context, listen: false);
      await provider.refreshJobWorker();
      await provider.refreshProcess();
      await provider.refreshbuchlist();

      /// 🔥 ITEM LIST LOAD
      /// TODO: તમારા ItemProvider માં items load કરતા function નું નામ અહીં મૂકો
      await provider.refreshItems();
    });

    if (isEditMode) {
      final user = widget.userData!;
      silverFormulaController.text =
          user["formula_value"]?.toString() ?? "11";
      remarks.text = user["remarks"]?.toString() ?? "";
      selectedRole = user["job_worker_id"]?.toString();
      selectedProcess = user["vacuum_process_id"]?.toString();

      loadInitialData(user["id"]);
    }
  }

  @override
  void dispose() {
    silverFormulaController.dispose();
    fromDateController.dispose();
    remarks.dispose();
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// =========================================================
  /// EDIT MODE — LOAD DATA
  /// =========================================================
  Future<void> loadInitialData(int id) async {
    final response = await ApiHelper().getRequestWithId(
      ApiConstants.vacuum_vouchers,
      id,
    );

    if (response == null ||
        response.statusCode != 200 ||
        response.data == null) {
      return;
    }

    final data = response.data["data"];

    /// HEADER
    selectedRole = data["job_worker_id"]?.toString();
    selectedProcess = data["vacuum_process_id"]?.toString();
    silverFormulaController.text = data["formula_value"]?.toString() ?? "11";
    remarks.text = data["remarks"]?.toString() ?? "";

    /// DATE
    if (data["voucher_date"] != null) {
      fromDate = DateTime.tryParse(data["voucher_date"].toString());
      if (fromDate != null) {
        fromDateController.text =
        "${fromDate!.day}-${fromDate!.month}-${fromDate!.year}";
      }
    }

    /// CLEAR OLD
    searchResults.clear();
    for (final c in controllers.values) {
      c.dispose();
    }
    controllers.clear();

    /// API ITEMS
    final List apiItems = data["items"] ?? [];

    searchResults = apiItems.asMap().entries.map<Map<String, dynamic>>((
        entry,
        ) {
      final int index = entry.key;
      final dynamic e = entry.value;

      /// 🔥 Item — API માં object હોય કે direct field, બંને handle
      final dynamic itemObj = e["item"];
      final String itemId =
          (e["item_id"] ?? (itemObj is Map ? itemObj["id"] : null))
              ?.toString() ??
              "";
      final String itemName = itemObj is Map
          ? (itemObj["item_name"] ?? itemObj["name"] ?? "").toString()
          : (e["item_name"] ?? "").toString();

      return {
        "id": "edit_${e["id"] ?? index}_${_rowCounter++}",
        "is_new_row": false,
        "detail_id": e["id"],

        /// Buch
        "item": e["buch_no"]?.toString() ??
            e["buch"]?["buch_no"]?.toString() ??
            "",
        "buch_id": e["vacuum_buch_id"] ?? e["buch"]?["id"],

        /// 🔥 Item
        "item_id": itemId,
        "item_name": itemName,

        /// Weight
        "gross_weight": e["gross_wt"]?.toString() ?? "",
        "weight": e["buch_wt"]?.toString() ?? "",
        "net_weight": e["net_wt"]?.toString() ?? "",
        "fine_weight": e["silver_wt"]?.toString() ?? "",

        /// 🔥 Remarks
        "remarks": e["remarks"]?.toString() ?? "",
      };
    }).toList();

    /// EDIT MODE — એક blank row
    searchResults.add(_defaultItem());

    /// CONTROLLERS
    for (final item in searchResults) {
      for (final key in [
        "gross_weight",
        "weight",
        "net_weight",
        "fine_weight",
        "remarks",
      ]) {
        getController(item, key).text = item[key]?.toString() ?? "";
      }
    }

    if (mounted) setState(() {});
  }

  /// =========================================================
  /// BUILD
  /// =========================================================
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top + 40),

                _buildRecentScansList(context),

                searchResults.isEmpty
                    ? const Padding(
                  padding: EdgeInsets.all(20),
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
                    : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: searchResults.length,
                  itemBuilder: (context, index) {
                    final item = searchResults[index];
                    return KeyedSubtree(
                      key: ValueKey("voucher_row_${item["id"]}"),
                      child: approvalItemCard(item, index),
                    );
                  },
                ),
              ],
            ),
          ),

          /// APPBAR (OVERLAY)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.only(
                top: 30,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    isEditMode ? "Edit Voucher" : "Create Voucher",
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      onTap: () => Navigator.pop(context, true),
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
                ],
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildSummaryBar(),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: InkWell(
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  if (isEditMode) {
                    update_user();
                  } else {
                    create_user();
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: [AppColors.primaryDark, AppColors.secondaryDark],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      isEditMode ? "Update" : "Save",
                      style: const TextStyle(
                        color: Colors.white,
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
    );
  }

  /// =========================================================
  /// HEADER FORM
  /// =========================================================
  Widget _buildRecentScansList(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final isTablet = width > 700;

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 5, 10, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          Text(
            "Add Voucher Details",
            style: TextStyle(
              fontSize: isTablet ? width * 0.03 : width * 0.04,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),

          SizedBox(height: height * 0.01),

          Consumer<ItemProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              /// ACTIVE WORKERS
              final List<Map<String, dynamic>> activeWorkers =
              provider.Job_worker.whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .where((e) => e["is_active"] == true)
                  .toList();

              /// ACTIVE PROCESSES
              final List<Map<String, dynamic>> activeProcesses =
              provider.Vacuum_Process.whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();

              final Map<String, dynamic>? selectedWorkerMap =
              _findById(activeWorkers, selectedRole);
              final Map<String, dynamic>? selectedProcessMap =
              _findById(activeProcesses, selectedProcess);

              return twoFieldRow(
                /// ================= WORKER =================
                Column(
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
                          items: activeWorkers,
                          value: selectedWorkerMap,
                          requiredField: true,
                          onChanged: (worker) {
                            if (worker == null) return;

                            final String workerId =
                                worker["id"]?.toString().trim() ?? "";
                            if (workerId.isEmpty) return;

                            setState(() {
                              selectedRole = workerId;

                              /// Create mode માં fresh 10 rows
                              if (!isEditMode) {
                                for (final c in controllers.values) {
                                  c.dispose();
                                }
                                controllers.clear();
                                searchResults =
                                    List.generate(10, (_) => _defaultItem());
                              }
                            });
                          },
                        ),

                        /// ❌ CLEAR WORKER
                        if (selectedWorkerMap != null)
                          _clearIcon(() {
                            setState(() => selectedRole = null);
                          }),
                      ],
                    ),
                  ],
                ),

                /// ================= PROCESS =================
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _dropdownLabel("Process"),
                    Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        PremiumItemSearchDropdown(
                          label: "",
                          hint: "Select Process",
                          width: double.infinity,
                          items: activeProcesses,
                          value: selectedProcessMap,
                          requiredField: true,
                          onChanged: (process) {
                            if (process == null) return;

                            final String processId =
                                process["id"]?.toString().trim() ?? "";
                            if (processId.isEmpty) return;

                            setState(() => selectedProcess = processId);
                          },
                        ),

                        /// ❌ CLEAR PROCESS
                        if (selectedProcessMap != null)
                          _clearIcon(() {
                            setState(() => selectedProcess = null);
                          }),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          Padding(
            padding: EdgeInsets.only(bottom: height * 0.01),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "From Date",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => _selectDate(fromDateController),
                        child: IgnorePointer(
                          child: TextField(
                            controller: fromDateController,
                            style: const TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              hintText: "From Date",
                              hintStyle:
                              TextStyle(color: Colors.grey.shade600),
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
                                borderSide:
                                BorderSide(color: AppColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                BorderSide(color: AppColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                BorderSide(color: AppColors.border),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: width * 0.03),
                Expanded(
                  child: _buildTextField(
                    context,
                    "Silver Formula Value",
                    controller: silverFormulaController,
                    isNumber: true,
                    isRequired: true,
                    onChanged: (value) {
                      for (final item in searchResults) {
                        calculateItem(item);
                      }
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
          ),

          _buildTextField(
            context,
            "Remarks",
            controller: remarks,
            isNumber: false,
            isRequired: false,
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _findById(
      List<Map<String, dynamic>> list,
      String? id,
      ) {
    if (id == null || id.trim().isEmpty) return null;
    for (final e in list) {
      if ((e["id"]?.toString().trim() ?? "") == id.trim()) return e;
    }
    return null;
  }

  Widget _buildTextField(
      BuildContext context,
      String label, {
        String? hint,
        TextEditingController? controller,
        bool isRequired = false,
        bool isNumber = false,
        Function(String)? onChanged,
      }) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width > 700;
    final isDesktop = width >= 1000;
    final double fontSize = isDesktop
        ? 16
        : isTablet
        ? 14
        : 13;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
            children: [
              if (isRequired)
                TextSpan(
                  text: " *",
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: isTablet ? 8 : 6),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 14 : 10,
            vertical: isTablet ? 4 : 2,
          ),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.border, width: 1.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: TextField(
            controller: controller,
            style: TextStyle(fontSize: fontSize, color: Colors.black),
            keyboardType: isNumber
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint ?? "Enter $label",
              hintStyle: TextStyle(
                color: Colors.grey.shade600,
                fontSize: fontSize,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  /// =========================================================
  /// 🔥 API ITEMS PAYLOAD (item_id + remarks સાથે)
  /// Buch select ના થયેલી blank rows મોકલતા નથી
  /// =========================================================
  List<Map<String, dynamic>> _buildItemsPayload() {
    return searchResults
        .where((item) =>
    item["buch_id"] != null &&
        item["buch_id"].toString().trim().isNotEmpty)
        .map<Map<String, dynamic>>((item) {
      return {
        if (item["detail_id"] != null) "id": item["detail_id"],
        "vacuum_buch_id": item["buch_id"],
        "item_name": item["item_name"]?.toString().trim() ?? "", // 🔥 નામ, id નહીં
        "gross_wt":
        double.tryParse(item["gross_weight"]?.toString() ?? "0") ?? 0,
        "buch_wt": double.tryParse(item["weight"]?.toString() ?? "0") ?? 0,
        "remarks": item["remarks"]?.toString().trim() ?? "",
      };
    }).toList();
  }

  Map<String, dynamic> _buildBody() {
    return {
      "voucher_date": formatDateForApi(fromDateController.text),
      "vacuum_process_id": int.parse(selectedProcess!),
      "job_worker_id": int.parse(selectedRole!),
      "formula_value": double.tryParse(silverFormulaController.text) ?? 11,
      "remarks": remarks.text.trim(),
      "items": _buildItemsPayload(),
    };
  }

  /// =========================================================
  /// CREATE
  /// =========================================================
  Future<void> create_user() async {
    if (!validateFields()) return;

    try {
      /// connectivity_plus જૂનું (single) અને નવું (List) બંને handle
      final dynamic result = await Connectivity().checkConnectivity();
      final bool hasInternet = result is List
          ? result.isNotEmpty && !result.contains(ConnectivityResult.none)
          : result != ConnectivityResult.none;

      final body = _buildBody();
      debugPrint("Request Body => $body");

      dynamic response;
      if (hasInternet) {
        response = await ApiHelper().postRequest(
          ApiConstants.vacuum_vouchers,
          body,
        );
      } else {
        response = await OfflineApiHelper.instance.postRequest(
          ApiConstants.vacuum_vouchers,
          body,
        );
      }

      if (response == null) {
        showError("No response from server");
        return;
      }

      final data = response.data;
      debugPrint("Create Voucher Response: $data");

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        AppMessage.success(
          context,
          data["message"] ?? "Voucher Created Successfully",
        );
        _goToList();
      } else if (response.statusCode == 202) {
        AppMessage.success(context, "No Internet. Voucher saved offline.");
        _goToList();
      } else {
        _handleError(response.statusCode, data);
      }
    } catch (e) {
      debugPrint("Create Voucher Exception: $e");
      showError("Something went wrong. Please try again.");
    }
  }

  /// =========================================================
  /// UPDATE
  /// =========================================================
  Future<void> update_user() async {
    if (!validateFields()) return;

    try {
      final userId = widget.userData!["id"];
      final body = _buildBody();
      debugPrint("Request Body => $body");

      final response = await ApiHelper().putRequest(
        "${ApiConstants.vacuum_vouchers}/$userId",
        body,
      );

      if (response == null) {
        showError("No response from server");
        return;
      }

      final data = response.data;
      debugPrint("Update Voucher Response: $data");

      if (!mounted) return;

      if (response.statusCode == 200) {
        AppMessage.success(
          context,
          data["message"] ?? "Voucher Updated Successfully",
        );
        _goToList();
      } else {
        _handleError(response.statusCode, data);
      }
    } catch (e) {
      debugPrint("Update Voucher Exception: $e");
      showError("Something went wrong. Please try again.");
    }
  }

  void _goToList() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const Voucherscreen()),
          (route) => route.isFirst,
    );
  }

  void _handleError(int? statusCode, dynamic data) {
    if (statusCode == 401) {
      showError(data?['message'] ?? "Invalid credentials");
    } else if (statusCode == 422) {
      String errorMessage = "";
      if (data?['errors'] is Map) {
        (data['errors'] as Map).forEach((key, value) {
          errorMessage += "${value is List ? value.first : value}\n";
        });
      } else {
        errorMessage = data?['message'] ?? "Validation error";
      }
      showError(errorMessage.trim());
    } else {
      showError(data?['message'] ?? "Server error ($statusCode)");
    }
  }

  String formatDateForApi(String date) {
    if (date.isEmpty) return "";
    final parts = date.split("-");
    if (parts.length != 3) return "";
    return "${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}";
  }

  void showError(String? message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message ?? "Something went wrong"),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget twoFieldRow(Widget left, Widget right) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 10),
          Expanded(child: right),
        ],
      ),
    );
  }

  bool validateFields() {
    if (selectedRole == null || selectedRole!.isEmpty) {
      showError("Please select Worker");
      return false;
    }

    if (selectedProcess == null || selectedProcess!.isEmpty) {
      showError("Please select Process");
      return false;
    }

    final filledRows = searchResults.where((e) =>
    e["buch_id"] != null && e["buch_id"].toString().trim().isNotEmpty);

    if (filledRows.isEmpty) {
      showError("Please add at least one Buch");
      return false;
    }

    /// 🔥 Buch select હોય એ દરેક row માં Item જરૂરી
    /// (Item optional રાખવું હોય તો આ loop કાઢી નાખો)
    int rowNo = 0;
    for (final e in searchResults) {
      rowNo++;
      final bool hasBuch =
          e["buch_id"] != null && e["buch_id"].toString().trim().isNotEmpty;
      final bool hasItem =
          (e["item_name"]?.toString().trim() ?? "").isNotEmpty;

      if (hasBuch && !hasItem) {
        showError("Please select Item in row $rowNo");
        return false;
      }
    }

    return true;
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        fromDate = picked;
        controller.text = "${picked.day}-${picked.month}-${picked.year}";
      });
    }
  }

  /// =========================================================
  /// ROW CARD
  /// =========================================================
  Widget approvalItemCard(Map<String, dynamic> item, int index) {
    /// 🔥 Edit mode: id ની જગ્યાએ સાચું item નામ
    _resolveItem(item, _itemsList());

    final bool isExpanded = item["expanded"] ?? false;
    final String buchNo = (item["item"]?.toString() ?? "").isEmpty
        ? "-"
        : item["item"].toString();
    final String itemName = item["item_name"]?.toString() ?? "";

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
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
          /// HEADER
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "BUCH NO",
                        style: TextStyle(
                          color: Colors.black45,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        itemName.isEmpty ? buchNo : "$buchNo  |  $itemName",
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
                const SizedBox(width: 8),

                /// DELETE
                InkWell(
                  onTap: () {
                    setState(() {
                      final rowId = item["id"].toString();
                      controllers.removeWhere((k, c) {
                        if (k.startsWith("${rowId}_")) {
                          c.dispose();
                          return true;
                        }
                        return false;
                      });
                      searchResults.removeAt(index);
                    });
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

          /// FIELDS — બધા એક જ height / shape
          if (!isExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _miniField("Buch No", item, "item"),
                    _miniField("Item", item, "item_name"),
                    _miniField("Gross", item, "gross_weight"),
                    _miniField("Buch Wt", item, "weight"),
                    _miniField("Net Wt", item, "net_weight"),
                    _miniField("Silver wt", item, "fine_weight"),
                    _miniField("Remarks", item, "remarks"),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// =========================================================
  /// 🔥 MINI FIELD — SAME SHAPE
  /// =========================================================
  Widget _miniField(String title, Map<String, dynamic> item, String key) {
    if (key == "item") return _labourDropdown(item);
    if (key == "item_name") return _itemDropdown(item);

    final bool isOtherField = key == "other";
    final bool editable = isEditableField(key);
    final controller = getController(item, key);

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(5),
      borderSide: BorderSide(color: AppColors.border),
    );

    return Container(
      width: _miniWidth(key),
      height: _miniRowH,
      margin: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _miniLabelH,
            child: Text(
              title,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ),
          const SizedBox(height: _miniGap),
          SizedBox(
            height: _miniBoxH,
            child: Stack(
              alignment: Alignment.centerRight,
              children: [
                TextFormField(
                  controller: controller,
                  readOnly: !editable,
                  enableInteractiveSelection: editable,
                  showCursor: editable,
                  canRequestFocus: editable,

                  /// 🔥 box ની પૂરી height fill કરે
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  textAlignVertical: TextAlignVertical.center,

                  keyboardType: key == "remarks"
                      ? TextInputType.text
                      : const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(color: Colors.black, fontSize: 12),

                  onChanged: (val) {
                    item[key] = val;
                    if (key == "gross_weight" || key == "weight") {
                      calculateItem(item);
                    }
                    setState(() {});
                  },

                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.only(
                      left: 6,
                      right: isOtherField ? 24 : 6,
                    ),
                    filled: true,
                    fillColor:
                    editable ? Colors.white : const Color(0xffF6F6F6),
                    border: border,
                    enabledBorder: border,
                    disabledBorder: border,
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: const BorderSide(
                        color: AppColors.primaryDark,
                        width: 1.2,
                      ),
                    ),
                  ),
                ),

                if (isOtherField)
                  Positioned(
                    right: 4,
                    child: InkWell(
                      onTap: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        controller.text = item["other_amount"] ?? "0";
                        setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: const Color(0xffC8A96A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 14,
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
      "weight",
      "sale_labour_rate",
      "metal_rate",
      "qty",
      "remarks",
    ].contains(key);
  }

  /// =========================================================
  /// BUCH DROPDOWN WRAPPER
  /// =========================================================
  Widget _labourDropdown(Map<String, dynamic> item) {
    return _buchDropdown(item);
  }

  Map<String, dynamic> _defaultItem() {
    final String uniqueId =
        "new_${DateTime.now().microsecondsSinceEpoch}_${_rowCounter++}";

    return {
      "id": uniqueId,
      "is_new_row": true,
      "detail_id": null,

      /// Buch
      "item": "",
      "buch_id": null,

      /// 🔥 Item
      "item_id": "",
      "item_name": "",

      "gross_weight": "",
      "weight": "",
      "net_weight": "",
      "fine_weight": "",

      /// 🔥 Remarks
      "remarks": "",
    };
  }

  void calculateItem(Map<String, dynamic> item) {
    final double gross =
        double.tryParse(item["gross_weight"]?.toString() ?? "0") ?? 0;
    final double buch =
        double.tryParse(item["weight"]?.toString() ?? "0") ?? 0;
    final double formula =
        double.tryParse(silverFormulaController.text.trim()) ?? 11;

    final double net = gross - buch;
    final double silver = net * formula;

    item["net_weight"] = net.toStringAsFixed(3);
    item["fine_weight"] = silver.toStringAsFixed(3);

    getController(item, "net_weight").text = net.toStringAsFixed(3);
    getController(item, "fine_weight").text = silver.toStringAsFixed(3);
  }

  /// =========================================================
  /// SUMMARY
  /// =========================================================
  Widget buildSummaryBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryItem(
                "Gross Wt", totalGrossWeight.toStringAsFixed(3), Colors.black),
          ),
          Expanded(
            child: _summaryItem(
                "Buch Wt", totalBuchWeight.toStringAsFixed(3), Colors.black),
          ),
          Expanded(
            child: _summaryItem(
                "Net Wt", totalNetWeight.toStringAsFixed(3), Colors.black),
          ),
          Expanded(
            child: _summaryItem(
                "Silver Wt", totalFineWeight.toStringAsFixed(3), Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String title, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  double _sum(String key) {
    return searchResults.fold(0.0, (sum, item) {
      return sum + (double.tryParse(item[key]?.toString() ?? "0") ?? 0);
    });
  }

  double get totalGrossWeight => _sum("gross_weight");
  double get totalBuchWeight => _sum("weight");
  double get totalNetWeight => _sum("net_weight");
  double get totalFineWeight => _sum("fine_weight");

  /// =========================================================
  /// 🔥 COMMON MINI DROPDOWN BOX
  /// TextField જેવું જ: label 15 + gap 4 + box 36 + same border
  /// =========================================================
  Widget _miniDropdownBox({
    required String title,
    required double width,
    required String text,
    required String hint,
    required VoidCallback onTap,
  }) {
    final bool isEmpty = text.trim().isEmpty;

    return Container(
      width: width,
      height: _miniRowH,
      margin: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _miniLabelH,
            child: Text(
              title,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ),
          const SizedBox(height: _miniGap),
          SizedBox(
            height: _miniBoxH,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
              child: InkWell(
                borderRadius: BorderRadius.circular(5),
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  onTap();
                },
                child: Container(
                  padding: const EdgeInsets.only(left: 6, right: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: AppColors.border), // 🔥 BORDER
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          isEmpty ? hint : text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isEmpty ? Colors.black38 : Colors.black,
                            fontWeight:
                            isEmpty ? FontWeight.normal : FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        size: 18,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// =========================================================
  /// 🔥 PREMIUM SEARCH BOTTOM SHEET
  /// =========================================================
  Future<Map<String, dynamic>?> _openSearchSheet({
    required String title,
    required List<Map<String, dynamic>> items,
    required String Function(Map<String, dynamic>) labelOf,
    required String Function(Map<String, dynamic>) searchOf,
    String Function(Map<String, dynamic>)? subtitleOf,
    IconData icon = Icons.inventory_2_outlined,
    String? selectedId,
  }) {
    final TextEditingController searchCtrl = TextEditingController();
    String query = "";

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final q = query.trim().toLowerCase();
            final filtered = q.isEmpty
                ? items
                : items
                .where((e) => searchOf(e).toLowerCase().contains(q))
                .toList();

            return AnimatedPadding(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(ctx).size.height * 0.72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    /// HANDLE
                    const SizedBox(height: 10),
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    /// HEADER
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primaryDark,
                                  AppColors.secondaryDark,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(icon, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Select $title",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "${filtered.length} of ${items.length} available",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => Navigator.pop(ctx),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    /// SEARCH
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: searchCtrl,
                        onChanged: (v) => setSheet(() => query = v),
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: "Search $title...",
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          prefixIcon: const Icon(
                            Icons.search,
                            size: 20,
                            color: AppColors.primaryDark,
                          ),
                          suffixIcon: query.isEmpty
                              ? null
                              : IconButton(
                            icon: const Icon(Icons.cancel, size: 18),
                            color: Colors.grey.shade500,
                            onPressed: () {
                              searchCtrl.clear();
                              setSheet(() => query = "");
                            },
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primaryDark,
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),
                    Divider(height: 1, color: Colors.grey.shade200),

                    /// LIST
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "No $title found",
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Try a different search",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                          : ListView.builder(
                        padding:
                        const EdgeInsets.fromLTRB(12, 10, 12, 16),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final e = filtered[i];
                          final bool isSel = selectedId != null &&
                              selectedId.isNotEmpty &&
                              e["id"]?.toString() == selectedId;
                          final String label = labelOf(e);
                          final String sub =
                              subtitleOf?.call(e).trim() ?? "";
                          final String initial = label.isNotEmpty
                              ? label[0].toUpperCase()
                              : "?";

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: isSel
                                  ? AppColors.primaryDark
                                  .withOpacity(0.07)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => Navigator.pop(ctx, e),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius:
                                    BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSel
                                          ? AppColors.primaryDark
                                          : AppColors.border,
                                      width: isSel ? 1.3 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          gradient: isSel
                                              ? LinearGradient(
                                            colors: [
                                              AppColors
                                                  .primaryDark,
                                              AppColors
                                                  .secondaryDark,
                                            ],
                                          )
                                              : null,
                                          color: isSel
                                              ? null
                                              : AppColors.primaryDark
                                              .withOpacity(0.10),
                                          borderRadius:
                                          BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          initial,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isSel
                                                ? Colors.white
                                                : AppColors.primaryDark,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              label,
                                              maxLines: 1,
                                              overflow:
                                              TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: isSel
                                                    ? FontWeight.w700
                                                    : FontWeight.w600,
                                                color: Colors.black,
                                              ),
                                            ),
                                            if (sub.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                sub,
                                                maxLines: 1,
                                                overflow: TextOverflow
                                                    .ellipsis,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors
                                                      .grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        isSel
                                            ? Icons.check_circle
                                            : Icons.chevron_right,
                                        size: 20,
                                        color: isSel
                                            ? AppColors.primaryDark
                                            : Colors.grey.shade400,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
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
  }

  /// =========================================================
  /// BUCH DROPDOWN
  /// =========================================================
  Widget _buchDropdown(Map<String, dynamic> item) {
    final provider = Provider.of<ItemProvider>(context);

    final String selectedValue = (item["item"] ?? "").toString().trim();

    /// બીજી rows માં select થયેલા Buch (current row સિવાય)
    final Set<String> alreadySelected = searchResults
        .where((e) => e["id"].toString() != item["id"].toString())
        .map<String>((e) => (e["item"] ?? "").toString().trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();

    final List<Map<String, dynamic>> available = provider.Buch_list
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .where((e) {
      final no = (e["buch_no"] ?? "").toString().trim().toLowerCase();
      return no.isNotEmpty && !alreadySelected.contains(no);
    }).toList();

    return _miniDropdownBox(
      title: "Buch No",
      width: _miniWidth("item"),
      text: selectedValue,
      hint: "Select Buch",
      onTap: () async {
        final picked = await _openSearchSheet(
          title: "Buch",
          items: available,
          selectedId: item["buch_id"]?.toString(),
          icon: Icons.view_module_outlined,
          labelOf: (d) => d["buch_no"]?.toString() ?? "-",
          subtitleOf: (d) {
            final w = d["weight"]?.toString() ?? "";
            return (w.isEmpty || w == "null") ? "" : "Weight: $w";
          },
          searchOf: (d) => [
            d["buch_no"]?.toString() ?? "",
            d["id"]?.toString() ?? "",
          ].join(" "),
        );

        if (picked == null || !mounted) return;
        _onBuchSelected(item, picked);
      },
    );
  }

  void _onBuchSelected(
      Map<String, dynamic> item,
      Map<String, dynamic> selectedBuch,
      ) {
    final bool wasNewRow = item["is_new_row"] == true;

    setState(() {
      item["item"] = selectedBuch["buch_no"]?.toString() ?? "";
      item["buch_id"] = selectedBuch["id"];

      final String weight = selectedBuch["weight"]?.toString() ?? "0";
      item["weight"] = weight;
      getController(item, "weight").text = weight;

      calculateItem(item);

      item["is_new_row"] = false;

      /// EDIT MODE — નવી blank row
      if (isEditMode && wasNewRow) {
        searchResults.add(_defaultItem());
      }

      /// CREATE MODE — last row select થાય તો નવી row
      if (!isEditMode) {
        final int currentIndex = searchResults.indexWhere(
              (e) => e["id"].toString() == item["id"].toString(),
        );
        if (currentIndex != -1 && currentIndex == searchResults.length - 1) {
          searchResults.add(_defaultItem());
        }
      }
    });
  }

  /// =========================================================
  /// 🔥 ITEM LIST (provider માંથી)
  /// =========================================================
  List<Map<String, dynamic>> _itemsList() {
    final provider = Provider.of<ItemProvider>(context);
    return provider.items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
    // .where((e) => e["is_active"] == true) // જરૂર હોય તો
        .toList();
  }

  String _itemLabel(Map<String, dynamic> d) =>
      (d["item_name"] ?? d["name"] ?? "").toString();

  /// =========================================================
  /// 🔥 EDIT MODE FIX
  /// જૂના vouchers માં item_name ની જગ્યાએ id save થયું હોય,
  /// તો list માંથી સાચું નામ અને item_id set કરે
  /// =========================================================
  void _resolveItem(
      Map<String, dynamic> item,
      List<Map<String, dynamic>> list,
      ) {
    if (list.isEmpty) return;

    final String id = item["item_id"]?.toString().trim() ?? "";
    final String name = item["item_name"]?.toString().trim() ?? "";

    Map<String, dynamic>? match;

    /// 1) item_id થી
    if (id.isNotEmpty && id != "null") match = _findById(list, id);

    /// 2) નામ exact match
    if (match == null && name.isNotEmpty) {
      for (final e in list) {
        if (_itemLabel(e).trim().toLowerCase() == name.toLowerCase()) {
          match = e;
          break;
        }
      }
    }

    /// 3) નામ માં number (id) save થયું હોય
    if (match == null && int.tryParse(name) != null) {
      match = _findById(list, name);
    }

    if (match != null) {
      item["item_id"] = match["id"]?.toString() ?? "";
      item["item_name"] = _itemLabel(match);
    }
  }

  /// =========================================================
  /// 🔥 ITEM DROPDOWN — Buch જેવું જ
  /// =========================================================
  Widget _itemDropdown(Map<String, dynamic> item) {
    final itemsList = _itemsList();
    _resolveItem(item, itemsList);

    return _miniDropdownBox(
      title: "Item",
      width: _miniWidth("item_name"),
      text: item["item_name"]?.toString() ?? "",
      hint: "Select Item",
      onTap: () async {
        final picked = await _openSearchSheet(
          title: "Item",
          icon: Icons.category_outlined,
          items: itemsList,
          selectedId: item["item_id"]?.toString(),
          labelOf: (d) {
            final l = _itemLabel(d);
            return l.isEmpty ? "-" : l;
          },
          subtitleOf: (d) {
            final code = d["item_code"]?.toString() ?? "";
            return (code.isEmpty || code == "null") ? "" : "Code: $code";
          },
          searchOf: (d) => [
            _itemLabel(d),
            d["item_code"]?.toString() ?? "",
            d["id"]?.toString() ?? "",
          ].join(" "),
        );

        if (picked == null || !mounted) return;

        setState(() {
          item["item_id"] = picked["id"]?.toString() ?? "";
          item["item_name"] = _itemLabel(picked);
        });
      },
    );
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
}

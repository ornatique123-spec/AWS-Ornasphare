import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Api_Constant/ApiConstants.dart';
import '../../Api_Constant/api_helper.dart';
import '../../Dashboard/HomeScreen.dart';
import '../../Extra/AppColors.dart';
import '../../Extra/AppMessage.dart';
import '../../Extra/ItemProvider.dart';
import '../../Extra/PermissionDeniedWidget.dart';
import '../../Offline Data/OfflineValueSave.dart';
import '../../Offline Data/offline_api_helper.dart';

class Addcastingmetalrecivescreen extends StatefulWidget {
  final Map<String, dynamic> voucher;
  final List<Map<String, dynamic>> items;

  const Addcastingmetalrecivescreen({
    super.key,
    required this.voucher,
    required this.items,
  });

  @override
  State<Addcastingmetalrecivescreen> createState() =>
      _AddcastingmetalrecivescreenState();
}

class _AddcastingmetalrecivescreenState
    extends State<Addcastingmetalrecivescreen> {
  /// =========================================================
  /// 🔥 MINI FIELD SIZES — Voucher screen જેવા, બધા એક જ shape
  /// =========================================================
  static const double _miniRowH = 55;
  static const double _miniLabelH = 15;
  static const double _miniGap = 4;
  static const double _miniBoxH = _miniRowH - _miniLabelH - _miniGap; // 36

  late Map<String, dynamic> voucher;
  late List<Map<String, dynamic>> items;

  final Map<String, TextEditingController> buchNoControllers = {};
  final Map<String, TextEditingController> issueSilverControllers = {};
  final Map<String, TextEditingController> treeWtControllers = {};
  final Map<String, TextEditingController> bhukoControllers = {};
  final Map<String, TextEditingController> lossControllers = {};

  int _customCounter = 0;
  bool _isSaving = false;

  final Offlinevaluesave _offlineDraft = Offlinevaluesave();
  List<String> userPermissions = [];

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      Provider.of<ItemProvider>(context, listen: false).loadJobWorker();
    });

    loadPermissions();

    voucher = Map<String, dynamic>.from(widget.voucher);
    items = widget.items.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  void dispose() {
    for (final map in [
      buchNoControllers,
      issueSilverControllers,
      treeWtControllers,
      bhukoControllers,
      lossControllers,
    ]) {
      for (final c in map.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Future<void> loadPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> perms = prefs.getStringList("user_permissions") ?? [];

    if (!mounted) return;
    setState(() => userPermissions = perms);
  }

  bool hasPermission(String permissionName) {
    return userPermissions.contains(permissionName);
  }

  /// null / "null" / ખાલી → "-"
  String _txt(dynamic v) {
    final s = v?.toString().trim() ?? "";
    return (s.isEmpty || s == "null") ? "-" : s;
  }

  /// null / "null" → "" (TextField માટે)
  String _val(dynamic v) {
    final s = v?.toString().trim() ?? "";
    return s == "null" ? "" : s;
  }

  double _num(dynamic v) => double.tryParse(_val(v)) ?? 0.0;

  double _total(String field) =>
      items.fold<double>(0.0, (sum, item) => sum + _num(item[field]));

  String _rowKey(Map<String, dynamic> item) => item["is_custom"] == true
      ? "custom_${item["id"]}"
      : "normal_${item["id"]}";

  /// =========================================================
  /// BUILD
  /// =========================================================
  @override
  Widget build(BuildContext context) {
    if (!(hasPermission("casting-release-view") ||
        hasPermission("casting-release-manage"))) {
      return Scaffold(
        body: PermissionDeniedWidget(onBack: () => Navigator.pop(context)),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: Stack(
          children: [
            /// WHOLE PAGE SCROLL
            SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  SizedBox(height: MediaQuery.of(context).padding.top + 45),

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

                  const SizedBox(height: 5),

                  /// ITEMS
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return KeyedSubtree(
                        key: ValueKey("receive_row_${_rowKey(item)}"),
                        child: castingMetalItemCard(item, index),
                      );
                    },
                  ),
                ],
              ),
            ),

            /// FIXED APP BAR
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
                    const Text(
                      "Add Casting Receive",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
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
                    Align(
                      alignment: Alignment.centerRight,
                      child: pdfBtn(() => openPdf(voucher["id"])),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        /// FIXED BOTTOM TOTAL
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                /// ALL TOTALS IN ONE ROW
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _bottomTotalItem(
                          "Issue Silver",
                          _total("issue_silver_wt").toStringAsFixed(3),
                        ),
                      ),
                      _bottomDivider(),
                      Expanded(
                        child: _bottomTotalItem(
                          "Tree Wt",
                          _total("release_tree_wt").toStringAsFixed(3),
                        ),
                      ),
                      _bottomDivider(),
                      Expanded(
                        child: _bottomTotalItem(
                          "Bhuko",
                          _total("release_tree_bhuko").toStringAsFixed(3),
                        ),
                      ),
                      _bottomDivider(),
                      Expanded(
                        child: _bottomTotalItem(
                          "Loss",
                          _total("loss").toStringAsFixed(3),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                /// APPLY BUTTON
                InkWell(
                  onTap: _isSaving
                      ? null
                      : () async {
                    FocusManager.instance.primaryFocus?.unfocus();

                    final bool ok =
                    await updateCastingReceive(voucher["id"], items);

                    if (!mounted) return;

                    /// 🔥 Success / offline save થાય તો જ back
                    if (ok) Navigator.pop(context, true);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryDark.withOpacity(0.7),
                          AppColors.secondaryDark.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: _isSaving
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Text(
                        "Apply",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// =========================================================
  /// ITEM CARD
  /// =========================================================
  Widget castingMetalItemCard(Map<String, dynamic> item, int index) {
    final bool isCustom = item["is_custom"] == true;
    final String key = _rowKey(item);
    final String customType = item["custom_type"]?.toString() ?? "bhuko";

    /// Controllers
    buchNoControllers.putIfAbsent(
      key,
          () => TextEditingController(text: _val(item["buch_no"])),
    );
    issueSilverControllers.putIfAbsent(
      key,
          () => TextEditingController(text: _val(item["issue_silver_wt"])),
    );
    treeWtControllers.putIfAbsent(
      key,
          () => TextEditingController(text: _val(item["release_tree_wt"])),
    );
    bhukoControllers.putIfAbsent(
      key,
          () => TextEditingController(text: _val(item["release_tree_bhuko"])),
    );
    lossControllers.putIfAbsent(
      key,
          () => TextEditingController(text: _val(item["loss"])),
    );

    final String buchNo = _txt(item["buch_no"]);
    final String itemName = _txt(item["item_name"]);
    final String voucherRemarks = _txt(item["voucher_remarks"]);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
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
                topLeft: Radius.circular(5),
                topRight: Radius.circular(5),
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

                /// BUCH NO | ITEM
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
                        (isCustom || itemName == "-")
                            ? buchNo
                            : "$buchNo  |  $itemName",
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

                /// TYPE BADGE
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    isCustom ? "Custom" : "Casting Receive",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                /// DELETE — ફક્ત Custom item માટે
                if (isCustom) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      setState(() => items.removeAt(index));

                      buchNoControllers.remove(key)?.dispose();
                      issueSilverControllers.remove(key)?.dispose();
                      treeWtControllers.remove(key)?.dispose();
                      bhukoControllers.remove(key)?.dispose();
                      lossControllers.remove(key)?.dispose();

                      _saveReceiveDraft();
                    },
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      width: 26,
                      height: 26,
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
                        size: 15,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          /// MINI FIELDS — બધા એક જ height / shape
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// TYPE (custom item)
                  if (isCustom)
                    _receiveMiniTypeDropdown(
                      value: customType,
                      onChanged: (value) {
                        if (value == null) return;

                        setState(() {
                          item["custom_type"] = value;

                          /// Type બદલાય તો સામેનું field clear
                          if (value == "bhuko") {
                            item["release_tree_wt"] = "";
                            treeWtControllers[key]?.clear();
                          } else {
                            item["release_tree_bhuko"] = "";
                            bhukoControllers[key]?.clear();
                          }

                          _calculateReceiveLoss(item);
                        });

                        _saveReceiveDraft();
                      },
                    ),

                  /// BUCH NO
                  _receiveMiniField(
                    label: "Buch No",
                    controller: buchNoControllers[key]!,
                    width: 80,
                    readOnly: !isCustom,
                    keyboardType:
                    isCustom ? TextInputType.text : TextInputType.number,
                    onChanged: (value) {
                      item["buch_no"] = value;
                      item["custom_buch_no"] = value;
                      _saveReceiveDraft();
                    },
                  ),

                  /// 🔥 ITEM (normal item)
                  if (!isCustom) _receiveMiniText("Item", itemName, width: 150),

                  /// ISSUE SILVER
                  _receiveMiniField(
                    label: "Issue Silver",
                    controller: issueSilverControllers[key]!,
                    width: 100,
                    readOnly: isCustom,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      item["issue_silver_wt"] = value;
                      _calculateReceiveLoss(item);
                      _saveReceiveDraft();
                      setState(() {});
                    },
                  ),

                  /// TREE WT  (Custom: PC Weight → editable)
                  _receiveMiniField(
                    label: "Tree Wt",
                    controller: treeWtControllers[key]!,
                    width: 90,
                    readOnly: isCustom ? customType != "pc_weight" : false,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      item["release_tree_wt"] = value;
                      _calculateReceiveLoss(item);
                      _saveReceiveDraft();
                      setState(() {});
                    },
                  ),

                  /// BHUKO  (Custom: Bhuko → editable)
                  _receiveMiniField(
                    label: "Bhuko",
                    controller: bhukoControllers[key]!,
                    width: 90,
                    readOnly: isCustom ? customType == "pc_weight" : false,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      item["release_tree_bhuko"] = value;
                      _calculateReceiveLoss(item);
                      _saveReceiveDraft();
                      setState(() {});
                    },
                  ),

                  /// LOSS
                  _receiveMiniField(
                    label: "Loss",
                    controller: lossControllers[key]!,
                    width: 90,
                    readOnly: true,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) {},
                  ),

                  /// 🔥 VOUCHER REMARKS (normal item)
                  if (!isCustom)
                    _receiveMiniText(
                      "Voucher Remarks",
                      voucherRemarks,
                      width: 150,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// =========================================================
  /// 🔥 COMMON MINI SHELL — label 15 + gap 4 + box 36 = 55
  /// =========================================================
  Widget _miniShell({
    required String label,
    required double width,
    required Widget box,
  }) {
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
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: _miniGap),
          SizedBox(height: _miniBoxH, child: box),
        ],
      ),
    );
  }

  BoxDecoration _miniBoxDecoration({bool readOnly = false}) {
    return BoxDecoration(
      color: readOnly ? const Color(0xffF6F6F6) : Colors.white,
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: AppColors.border),
    );
  }

  /// READ-ONLY TEXT (long-press પર પૂરું text)
  Widget _receiveMiniText(String title, String value, {double width = 90}) {
    return _miniShell(
      label: title,
      width: width,
      box: Tooltip(
        message: value,
        triggerMode: TooltipTriggerMode.longPress,
        child: Container(
          width: double.infinity,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: _miniBoxDecoration(readOnly: true),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  /// INPUT FIELD
  Widget _receiveMiniField({
    required String label,
    required TextEditingController controller,
    double width = 90,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    required ValueChanged<String> onChanged,
  }) {
    return _miniShell(
      label: label,
      width: width,
      box: Container(
        decoration: _miniBoxDecoration(readOnly: readOnly),
        child: TextFormField(
          controller: controller,
          readOnly: readOnly,
          enableInteractiveSelection: !readOnly,
          showCursor: !readOnly,
          canRequestFocus: !readOnly,
          expands: true,
          maxLines: null,
          minLines: null,
          textAlignVertical: TextAlignVertical.center,
          keyboardType: keyboardType,
          textInputAction: TextInputAction.done,
          style: TextStyle(
            color: readOnly ? Colors.black54 : Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          onTap: () {
            if (readOnly) return;
            if (controller.text == "0" ||
                controller.text == "0.0" ||
                controller.text == "0.00" ||
                controller.text == "0.000") {
              controller.clear();
            } else {
              controller.selection = TextSelection(
                baseOffset: 0,
                extentOffset: controller.text.length,
              );
            }
          },
          onChanged: onChanged,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 8),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }

  /// TYPE DROPDOWN (Bhuko / PC Weight)
  Widget _receiveMiniTypeDropdown({
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    const itemStyle = TextStyle(
      color: Colors.black,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );

    return _miniShell(
      label: "Type",
      width: 110,
      box: Container(
        padding: const EdgeInsets.only(left: 8, right: 4),
        decoration: _miniBoxDecoration(),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            isDense: true,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(8),
            style: itemStyle,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.black54,
              size: 18,
            ),
            items: const [
              DropdownMenuItem(
                value: "bhuko",
                child: Text("Bhuko", style: itemStyle),
              ),
              DropdownMenuItem(
                value: "pc_weight",
                child: Text("PC Weight", style: itemStyle),
              ),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  /// =========================================================
  /// TOP INFO + CUSTOM BUTTON
  /// =========================================================
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
          Row(
            children: [
              Expanded(
                child: _infoCard(
                  title: "Process",
                  value: _txt(voucher["process_name"]),
                  icon: Icons.settings,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _infoCard(
                  title: "Worker",
                  value: _txt(voucher["worker_name"]),
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
                  value: _txt(voucher["voucher_date"]),
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

          const SizedBox(height: 10),

          /// CUSTOM BHUKO BUTTON
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              borderRadius: BorderRadius.circular(5),
              onTap: _addCustomItem,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryDark.withOpacity(0.7),
                      AppColors.secondaryDark.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 17),
                    SizedBox(width: 5),
                    Text(
                      "Custom Bhuko",
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
          ),
        ],
      ),
    );
  }

  void _addCustomItem() {
    final String customId =
        "${DateTime.now().millisecondsSinceEpoch}_${_customCounter++}";

    setState(() {
      items.add({
        "id": customId,
        "vacuum_voucher_item_id": null,
        "is_custom": true,
        "selected": false,
        "group_id": null,
        "custom_type": "bhuko",
        "buch_no": "",
        "custom_buch_no": "",
        "issue_silver_wt": "",
        "release_tree_wt": "",
        "release_tree_bhuko": "",
        "loss": "",
        "office_cut_wt": "0.000",
        "remaining_tree_wt": "",
        "job_worker_id": null,
        "worker_name": "",
      });
    });

    _saveReceiveDraft();
  }

  /// PDF BUTTON
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
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
      ApiConstants.casting_receive_pdf,
      id,
      responseType: ResponseType.bytes,
    );

    if (response != null && response.statusCode == 200) {
      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/Casting_Receive_$id.pdf");
      await file.writeAsBytes(response.data);
      OpenFile.open(file.path);
    } else {
      if (mounted) AppMessage.error(context, "PDF download failed");
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

  /// =========================================================
  /// 🔥 API — normal items માં item_name + voucher_remarks
  /// true = success / offline save
  /// =========================================================
  Future<bool> updateCastingReceive(
      int voucherId,
      List<Map<String, dynamic>> items,
      ) async {
    final Map<String, dynamic> itemData = {};
    final List<Map<String, dynamic>> customItems = [];

    for (final item in items) {
      /// CUSTOM ITEM
      if (item["is_custom"] == true) {
        final String customType =
            item["custom_type"]?.toString().trim() ?? "bhuko";
        final String customBuchNo = _val(item["buch_no"]);

        if (customType == "pc_weight") {
          customItems.add({
            "custom_type": "pc_weight",
            "custom_buch_no": customBuchNo,
            "release_tree_wt":
            _num(item["release_tree_wt"]).toStringAsFixed(3),
          });
        } else {
          customItems.add({
            "custom_type": "bhuko",
            "custom_buch_no": customBuchNo,
            "release_tree_bhuko":
            _num(item["release_tree_bhuko"]).toStringAsFixed(3),
          });
        }
        continue;
      }

      /// NORMAL ITEM
      itemData[item["id"].toString()] = {
        "release_tree_wt": _num(item["release_tree_wt"]).toStringAsFixed(3),
        "release_tree_bhuko":
        _num(item["release_tree_bhuko"]).toStringAsFixed(3),

        /// 🔥 NEW
        "item_name": _val(item["item_name"]),
        "voucher_remarks": _val(item["voucher_remarks"]),
      };
    }

    final Map<String, dynamic> body = {"items": itemData};
    if (customItems.isNotEmpty) body["custom_items"] = customItems;

    debugPrint("📤 CASTING RECEIVE BODY: $body");

    setState(() => _isSaving = true);

    try {
      final response = await OfflineApiHelper.instance.putRequest(
        "${ApiConstants.casting_receive}/$voucherId",
        body,
      );

      debugPrint("PUT Response : ${response?.data}");

      if (!mounted) return false;

      if (response == null) {
        AppMessage.error(context, "No response from server.");
        return false;
      }

      /// OFFLINE SAVED
      if (response.statusCode == 202) {
        AppMessage.success(context, "No Internet. Update saved offline.");
        return true;
      }

      /// SUCCESS
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data["success"] == true) {
          AppMessage.success(
            context,
            data["message"] ?? "Updated Successfully",
          );
          return true;
        }
        AppMessage.error(
          context,
          (data is Map ? data["message"] : null) ?? "Something went wrong",
        );
        return false;
      }

      /// VALIDATION / OTHER ERROR
      final data = response.data;
      String msg = "Failed to update data";
      if (data is Map) {
        if (data["errors"] is Map) {
          msg = (data["errors"] as Map)
              .values
              .map((v) => v is List ? v.first.toString() : v.toString())
              .join("\n");
        } else if (data["message"] != null) {
          msg = data["message"].toString();
        }
      }
      AppMessage.error(context, msg);
      return false;
    } catch (e) {
      debugPrint("❌ Casting Receive Error: $e");
      if (mounted) AppMessage.error(context, "Failed to update data");
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _saveReceiveDraft() {
    _offlineDraft.saveCastingDraft(voucher["id"], items);
  }

  /// =========================================================
  /// LOSS CALCULATION
  /// Custom PC Weight → Loss = Tree Wt
  /// Custom Bhuko     → Loss = Bhuko
  /// Normal           → Loss = (Tree Wt + Bhuko) - Issue Silver
  /// =========================================================
  void _calculateReceiveLoss(Map<String, dynamic> item) {
    final bool isCustom = item["is_custom"] == true;
    final double treeWt = _num(item["release_tree_wt"]);
    final double bhuko = _num(item["release_tree_bhuko"]);

    double loss;

    if (isCustom) {
      final String customType = item["custom_type"]?.toString() ?? "bhuko";
      loss = customType == "pc_weight" ? treeWt : bhuko;
    } else {
      loss = (treeWt + bhuko) - _num(item["issue_silver_wt"]);
    }

    item["loss"] = loss.toStringAsFixed(3);
    lossControllers[_rowKey(item)]?.text = loss.toStringAsFixed(3);
  }

  Widget _bottomTotalItem(String title, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _bottomDivider() {
    return Container(width: 1, height: 35, color: Colors.grey.shade300);
  }
}
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Api_Constant/ApiConstants.dart';
import '../../Api_Constant/api_helper.dart';
import '../../Extra/AppColors.dart';
import '../../Extra/AppMessage.dart';
import '../../Extra/ItemProvider.dart';
import '../../Extra/PermissionDeniedWidget.dart';
import '../../Extra/PremiumSearchableDropdown.dart';
import '../../Offline Data/OfflineValueSave.dart';
import '../../Offline Data/offline_api_helper.dart';

class Addtreecuttingissue extends StatefulWidget {
  final Map<String, dynamic> voucher;
  final List<Map<String, dynamic>> items;

  const Addtreecuttingissue({
    super.key,
    required this.voucher,
    required this.items,
  });

  @override
  State<Addtreecuttingissue> createState() => _AddtreecuttingissueState();
}

class _AddtreecuttingissueState extends State<Addtreecuttingissue> {
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
  final Map<String, TextEditingController> treeWtControllers = {};
  final Map<String, TextEditingController> bhukoControllers = {};

  String? selectedRole; // Global worker id
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
    for (final map in [buchNoControllers, treeWtControllers, bhukoControllers]) {
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

  /// Receive Tree Wt → remaining_tree_wt (fallback receive_tree_wt)
  double _receiveWt(Map<String, dynamic> item) {
    final String r = _val(item["remaining_tree_wt"]);
    return double.tryParse(r.isNotEmpty ? r : _val(item["receive_tree_wt"])) ??
        0.0;
  }

  String _rowKey(Map<String, dynamic> item, int index) =>
      item["id"]?.toString() ??
          item["vacuum_voucher_item_id"]?.toString() ??
          "item_$index";

  bool _hasWorker(Map<String, dynamic> item) =>
      _val(item["job_worker_id"]).isNotEmpty;

  void _saveDraft() {
    _offlineDraft.saveCastingDraft(voucher["id"], items);
  }

  /// =========================================================
  /// BUILD
  /// =========================================================
  @override
  Widget build(BuildContext context) {
    if (!(hasPermission("tree-cutting-issue-view") ||
        hasPermission("tree-cutting-issue-manage"))) {
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
        Navigator.pop(context, true);
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: AppColors.white,
        body: Stack(
          children: [
            /// WHOLE PAGE SCROLL
            SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 10,
              ),
              child: Column(
                children: [
                  SizedBox(height: MediaQuery.of(context).padding.top + 55),

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
                        key: ValueKey("tree_issue_${_rowKey(item, index)}"),
                        child: treeItemCard(item, index),
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
                      "Tree Cutting Issue",
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
                          "Office Cut Wt",
                          items
                              .fold<double>(
                            0.0,
                                (sum, item) =>
                            sum + _num(item["office_cut_wt"]),
                          )
                              .toStringAsFixed(3),
                        ),
                      ),
                      _bottomDivider(),
                      Expanded(
                        child: _bottomTotalItem(
                          "Receive Tree Wt",
                          items
                              .fold<double>(
                            0.0,
                                (sum, item) => sum + _receiveWt(item),
                          )
                              .toStringAsFixed(3),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                /// APPLY BUTTON
                InkWell(
                  onTap: _isSaving ? null : _onApply,
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
  /// APPLY — validation પછી API
  /// =========================================================
  Future<void> _onApply() async {
    FocusManager.instance.primaryFocus?.unfocus();

    /// 🔥 બધા નહીં, ઓછામાં ઓછી એક item માં worker જરૂરી
    final bool anyAssigned = items.any((item) {
      if (item["is_custom"] == true) {
        final String buchNo =
        _val(item["custom_buch_no"] ?? item["buch_no"]);
        return buchNo.isNotEmpty && _hasWorker(item);
      }
      return _hasWorker(item);
    });

    if (!anyAssigned) {
      AppMessage.error(
        context,
        "Please select worker for at least one item.",
      );
      return;
    }

    /// Custom items (Buch No ભરેલું હોય) માં worker જરૂરી
    final bool customMissing = items.any((item) {
      if (item["is_custom"] != true) return false;
      final String buchNo =
      _val(item["custom_buch_no"] ?? item["buch_no"]);
      return buchNo.isNotEmpty && !_hasWorker(item);
    });

    if (customMissing) {
      AppMessage.error(
        context,
        "Please select worker for all custom items before applying.",
      );
      return;
    }

    final bool ok = await updateTreeCuttingIssue(voucher["id"], items);

    if (!mounted) return;

    /// 🔥 Success / offline save થાય તો જ back
    if (ok) Navigator.pop(context, true);
  }

  /// =========================================================
  /// ITEM CARD
  /// =========================================================
  Widget treeItemCard(Map<String, dynamic> item, int index) {
    final String key = _rowKey(item, index);
    final bool isCustom = item["is_custom"] == true;
    final bool isOfficeGroup = item["is_office_group"] == true;
    final bool isSelected = isOfficeGroup || item["selected"] == true;
    final bool hasGroup = _val(item["group_id"]).isNotEmpty;

    /// Controllers
    buchNoControllers.putIfAbsent(
      key,
          () => TextEditingController(text: _val(item["buch_no"])),
    );

    /// Receive Tree Wt → remaining_tree_wt
    treeWtControllers.putIfAbsent(
      key,
          () => TextEditingController(text: _val(item["remaining_tree_wt"])),
    );

    /// Office Cut Wt
    bhukoControllers.putIfAbsent(
      key,
          () => TextEditingController(
        text: _num(item["office_cut_wt"]).toStringAsFixed(3),
      ),
    );

    final String buchNo = _txt(item["buch_no"]);
    final String itemName = _txt(item["item_name"]);
    final String voucherRemarks = _txt(item["voucher_remarks"]);

    /// Header color: group → group color, selected → થોડું ઘાટું
    final Color headerColor = hasGroup
        ? getGroupColor(item["group_id"]?.toString(), items)
        : AppColors.primaryDark.withOpacity(isSelected ? 0.18 : 0.10);

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
              color: headerColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(5),
                topRight: Radius.circular(5),
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
                        maxLines: 1,
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

                /// CUSTOM BADGE / SELECT CHECKBOX
                if (isCustom) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade700,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      "Custom",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  /// નવી custom row delete કરી શકાય
                  if (key.startsWith("custom_")) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        setState(() => items.removeAt(index));
                        buchNoControllers.remove(key)?.dispose();
                        treeWtControllers.remove(key)?.dispose();
                        bhukoControllers.remove(key)?.dispose();
                        _saveDraft();
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
                ] else ...[
                  const Text(
                    "Select",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(width: 3),
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: Checkbox(
                      value: isSelected,
                      activeColor: Colors.white,
                      checkColor: AppColors.primaryDark,
                      fillColor: WidgetStateProperty.all(Colors.white),
                      side: BorderSide(
                        color: Colors.grey.shade400,
                        width: 1.5,
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: isOfficeGroup
                          ? null
                          : (value) {
                        /// group_id preserve રહે છે
                        setState(() => item["selected"] = value ?? false);
                        _saveDraft();
                      },
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
                  /// 1. BUCH NO
                  _treeMiniField(
                    label: "Buch No",
                    controller: buchNoControllers[key]!,
                    width: 90,
                    readOnly: !isCustom,
                    keyboardType:
                    isCustom ? TextInputType.text : TextInputType.number,
                    onChanged: (value) {
                      if (!isCustom) return;
                      item["buch_no"] = value;
                      item["custom_buch_no"] = value;
                      _saveDraft();
                      setState(() {});
                    },
                  ),

                  /// 🔥 2. ITEM (normal)
                  if (!isCustom) _treeMiniText("Item", itemName, width: 150),

                  /// 3. OFFICE CUT WT (read-only)
                  _treeMiniField(
                    label: "Office Cut Wt",
                    controller: bhukoControllers[key]!,
                    width: 110,
                    readOnly: true,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) {},
                  ),

                  /// 4. RECEIVE TREE WT
                  _treeMiniField(
                    label: "Receive Tree Wt",
                    controller: treeWtControllers[key]!,
                    width: 110,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      item["remaining_tree_wt"] = value;
                      _saveDraft();
                      setState(() {});
                    },
                  ),

                  /// 5. ASSIGN WORKER
                  _workerMiniDropdown(item),

                  /// 🔥 6. VOUCHER REMARKS (normal)
                  if (!isCustom)
                    _treeMiniText(
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
  Widget _treeMiniText(String title, String value, {double width = 90}) {
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
  Widget _treeMiniField({
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    required TextInputType keyboardType,
    double width = 90,
    bool readOnly = false,
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

  /// =========================================================
  /// 🔥 ROW WORKER DROPDOWN — same shape + premium sheet
  /// =========================================================
  Widget _workerMiniDropdown(Map<String, dynamic> item) {
    final String currentId = _val(item["job_worker_id"]);
    final String currentName = _val(item["worker_name"]);
    final bool isEmpty = currentName.isEmpty;

    return _miniShell(
      label: "Assign Worker",
      width: 170,
      box: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        child: InkWell(
          borderRadius: BorderRadius.circular(5),
          onTap: () async {
            FocusManager.instance.primaryFocus?.unfocus();

            /// Voucher ના job workers
            final List<Map<String, dynamic>> workers =
            (voucher["job_workers"] as List? ?? [])
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();

            /// Current worker list માં ના હોય તો ઉપર ઉમેરો
            if (currentId.isNotEmpty &&
                currentName.isNotEmpty &&
                !workers.any((e) => e["id"]?.toString() == currentId)) {
              workers.insert(0, {"id": item["job_worker_id"], "name": currentName});
            }

            final picked = await _openSearchSheet(
              title: "Worker",
              icon: Icons.person_outline_rounded,
              items: workers,
              selectedId: currentId,
              labelOf: (w) => _val(w["name"]).isEmpty ? "-" : _val(w["name"]),
              searchOf: (w) => _val(w["name"]),
            );

            if (picked == null || !mounted) return;

            setState(() {
              item["job_worker_id"] = picked["id"];
              item["worker_name"] = _val(picked["name"]);
            });

            _saveDraft();
          },
          child: Container(
            padding: const EdgeInsets.only(left: 8, right: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person,
                  size: 15,
                  color: isEmpty ? Colors.black38 : AppColors.primaryDark,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    isEmpty ? "Select Worker" : currentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isEmpty ? Colors.black38 : Colors.black,
                      fontWeight: isEmpty ? FontWeight.normal : FontWeight.w600,
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
                                        child: Text(
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
  /// TOP: GLOBAL WORKER + INFO + BUTTONS
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
          /// GLOBAL WORKER
          Consumer<ItemProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              /// ACTIVE WORKERS ONLY
              final List<Map<String, dynamic>> activeWorkers = provider
                  .Job_worker
                  .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
                  .where((e) {
                final dynamic flag = e["is_active"] ?? e["is_used"];
                if (flag == null) return true;
                return flag == true || flag.toString() == "1";
              }).toList();

              Map<String, dynamic>? selectedWorker;
              for (final w in activeWorkers) {
                if (w["id"]?.toString() == selectedRole) {
                  selectedWorker = w;
                  break;
                }
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: const TextSpan(
                        text: "Worker",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        children: [
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
                    const SizedBox(height: 6),
                    Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        PremiumSearchableDropdown<Map<String, dynamic>>(
                          label: "",
                          hint: "Select Worker",
                          items: activeWorkers,
                          value: selectedWorker,
                          prefixIcon: Icons.person_outline_rounded,
                          dropdownMaxHeight: 350,
                          itemLabel: (w) => w["name"]?.toString() ?? "",
                          searchText: (w) => w["name"]?.toString() ?? "",
                          onChanged: (worker) {
                            if (worker == null) {
                              setState(() => selectedRole = null);
                              return;
                            }

                            final int? workerId =
                            int.tryParse(worker["id"].toString());
                            final String workerName =
                                worker["name"]?.toString() ?? "";

                            setState(() {
                              selectedRole = worker["id"]?.toString();

                              /// Checked items (office group સિવાય) માં same worker
                              for (final item in items) {
                                if (item["selected"] == true &&
                                    item["is_office_group"] != true) {
                                  item["job_worker_id"] = workerId;
                                  item["worker_name"] = workerName;
                                }
                              }
                            });

                            _saveDraft();
                          },
                        ),

                        /// ❌ CLEAR — onChanged na null vada case jevu j
                        if (selectedWorker != null)
                          _clearIcon(
                                () => setState(() => selectedRole = null),
                            right: 40,
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          /// INFO CARDS
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

          /// CUSTOM (left) + APPLY TO CHECKED (right)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _gradientBtn(
                icon: Icons.add,
                text: "Custom",
                onTap: _addCustomItem,
              ),
              _gradientBtn(
                icon: Icons.check_circle_outline,
                text: "Apply to Checked",
                onTap: _applyToChecked,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _gradientBtn({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(5),
      onTap: onTap,
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 17),
            const SizedBox(width: 5),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addCustomItem() {
    /// "custom_" prefix → API માં નવી custom item તરીકે જાય
    final String customId =
        "custom_${DateTime.now().millisecondsSinceEpoch}_${_customCounter++}";

    setState(() {
      items.add({
        "id": customId,
        "is_custom": true,
        "selected": false,
        "group_id": null,
        "buch_no": "",
        "custom_buch_no": "",
        "office_cut_wt": "0.000",
        "remaining_tree_wt": "",
        "job_worker_id": null,
        "worker_name": "",
      });
    });

    _saveDraft();
  }

  void _applyToChecked() {
    final List<Map<String, dynamic>> selectedItems = items
        .where((item) =>
    item["is_custom"] != true &&
        item["is_office_group"] != true &&
        item["selected"] == true)
        .toList();

    if (selectedItems.isEmpty) {
      AppMessage.error(context, "ઓછામાં ઓછી એક Buch select કરો.");
      return;
    }

    if (selectedRole == null || selectedRole!.isEmpty) {
      AppMessage.error(context, "Worker select કરો.");
      return;
    }

    final int? workerId = int.tryParse(selectedRole!);
    if (workerId == null) {
      AppMessage.error(context, "Valid Worker select કરો.");
      return;
    }

    /// Worker name
    final provider = Provider.of<ItemProvider>(context, listen: false);
    String workerName = "";
    for (final w in provider.Job_worker) {
      if (w["id"].toString() == selectedRole) {
        workerName = w["name"]?.toString() ?? "";
        break;
      }
    }

    /// UI color માટે નવો local group
    final String newGroupId = "new_${DateTime.now().millisecondsSinceEpoch}";

    setState(() {
      /// બધા non-office items પહેલા false
      for (final item in items) {
        if (item["is_custom"] != true && item["is_office_group"] != true) {
          item["is_group_checked"] = false;
        }
      }

      /// Selected items → group
      for (final item in selectedItems) {
        item["is_group_checked"] = true;
        item["job_worker_id"] = workerId;
        item["worker_name"] = workerName;
        item["group_id"] = newGroupId;
        item["is_new_group"] = true;
        item["selected"] = false;
      }
    });

    _saveDraft();
    debugPrint(
      "NEW GROUP => $newGroupId | WORKER => $workerId | "
          "ITEMS => ${selectedItems.map((e) => e["vacuum_voucher_item_id"]).toList()}",
    );
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
      ApiConstants.tree_cutting_issue_pdf,
      id,
      responseType: ResponseType.bytes,
    );

    if (response != null && response.statusCode == 200) {
      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/Tree_Cutting_Issue_$id.pdf");
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
  Future<bool> updateTreeCuttingIssue(
      int voucherId,
      List<Map<String, dynamic>> items,
      ) async {
    final Map<String, dynamic> itemData = {};
    final List<Map<String, dynamic>> customItems = [];
    final List<int> groupItemIds = [];
    int? groupWorkerId;

    for (final item in items) {
      final String itemId = _val(item["id"]);
      final double receiveTreeWt = _receiveWt(item);

      /// CUSTOM ITEM
      if (item["is_custom"] == true) {
        final String buchNo =
        _val(item["custom_buch_no"] ?? item["buch_no"]);
        if (buchNo.isEmpty) continue;

        final Map<String, dynamic> custom = {
          "custom_buch_no": buchNo,
          "receive_tree_wt": receiveTreeWt.toStringAsFixed(3),
          "job_worker_id": item["job_worker_id"],
        };

        /// Existing custom → id સાથે
        if (!itemId.startsWith("custom_")) {
          final int? customId = int.tryParse(itemId);
          if (customId == null) continue;
          custom["id"] = customId;
        }

        customItems.add(custom);
        continue;
      }

      /// NORMAL ITEM
      final String rawId = _val(item["vacuum_voucher_item_id"]);
      final int? normalItemId = int.tryParse(rawId);
      if (normalItemId == null) continue;

      /// 🔥 Worker assign નથી → આ item API માં ના મોકલો
      if (!_hasWorker(item)) continue;

      final bool isGroupChecked = item["is_group_checked"] == true;

      if (isGroupChecked) {
        groupItemIds.add(normalItemId);
        groupWorkerId ??= int.tryParse(_val(item["job_worker_id"]));
      }

      itemData[rawId] = {
        "receive_tree_wt": receiveTreeWt.toStringAsFixed(3),
        "job_worker_id": item["job_worker_id"],
        "is_group_checked": isGroupChecked,
        "item_name": _val(item["item_name"]),
        "voucher_remarks": _val(item["voucher_remarks"]),
      };
    }

    /// 🔥 Safety: કંઈ મોકલવાનું જ ના હોય તો API call ના કરો
    if (itemData.isEmpty && customItems.isEmpty) {
      AppMessage.error(context, "Please select worker for at least one item.");
      return false;
    }

    final bool autoGroup = groupItemIds.isNotEmpty && groupWorkerId != null;

    final Map<String, dynamic> body = {
      "auto_group": autoGroup,
      if (autoGroup) "group_worker_id": groupWorkerId,
      if (autoGroup) "group_item_ids": groupItemIds,
      "items": itemData,
      if (customItems.isNotEmpty) "custom_items": customItems,
    };

    debugPrint("📤 TREE CUTTING ISSUE BODY => $body");

    setState(() => _isSaving = true);

    try {
      final response = await OfflineApiHelper.instance.putRequest(
        "${ApiConstants.tree_cutting_issue}/$voucherId",
        body,
      );

      debugPrint("STATUS => ${response?.statusCode}");
      debugPrint("RESPONSE => ${response?.data}");

      if (!mounted) return false;

      if (response == null) {
        AppMessage.error(context, "No response from server.");
        return false;
      }

      /// OFFLINE
      if (response.statusCode == 202) {
        AppMessage.success(context, "No Internet. Update saved offline.");
        return true;
      }

      /// SUCCESS
      final data = response.data;
      if (response.statusCode == 200 && data is Map && data["success"] == true) {
        await _offlineDraft.clearCastingDraft(voucherId);
        if (mounted) {
          AppMessage.success(
            context,
            data["message"] ?? "Updated Successfully",
          );
        }
        return true;
      }

      /// VALIDATION / OTHER ERROR
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
    } catch (e, stackTrace) {
      debugPrint("❌ Tree Cutting Issue Error => $e");
      debugPrint("$stackTrace");
      if (mounted) AppMessage.error(context, "Failed to update data");
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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

  /// =========================================================
  /// GROUP COLOR
  /// Existing API group → ઘાટા shades
  /// New local group    → હળવા shades
  /// =========================================================
  Color getGroupColor(String? groupId, List items) {
    if (groupId == null || groupId.isEmpty) {
      return AppColors.primaryDark.withOpacity(0.10);
    }

    final groupItems =
    items.where((e) => e["group_id"]?.toString() == groupId).toList();

    if (groupItems.isEmpty) return AppColors.primaryDark.withOpacity(0.10);

    final int hash = groupId.hashCode.abs();

    if (groupItems.any((e) => e["is_office_group"] == true)) {
      final List<Color> existingColors = [
        Colors.blue.shade100,
        Colors.green.shade100,
        Colors.orange.shade100,
        Colors.purple.shade100,
      ];
      return existingColors[hash % existingColors.length];
    }

    if (groupItems.any((e) => e["is_new_group"] == true)) {
      final List<Color> newGroupColors = [
        Colors.teal.shade50,
        Colors.pink.shade50,
        Colors.amber.shade50,
        Colors.cyan.shade50,
        Colors.lime.shade50,
        Colors.indigo.shade50,
      ];
      return newGroupColors[hash % newGroupColors.length];
    }

    return AppColors.primaryDark.withOpacity(0.10);
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
}
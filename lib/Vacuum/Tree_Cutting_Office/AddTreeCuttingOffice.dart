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
import '../../Offline Data/OfflineValueSave.dart';
import '../../Offline Data/offline_api_helper.dart';

class Addtreecuttingoffice extends StatefulWidget {
  final Map<String, dynamic> voucher;
  final List<Map<String, dynamic>> items;

  const Addtreecuttingoffice({
    super.key,
    required this.voucher,
    required this.items,
  });

  @override
  State<Addtreecuttingoffice> createState() => _AddtreecuttingofficeState();
}

class _AddtreecuttingofficeState extends State<Addtreecuttingoffice> {
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
  final Map<String, TextEditingController> remainingTreeWtControllers = {};

  final Offlinevaluesave _offlineDraft = Offlinevaluesave();
  List<String> userPermissions = [];

  bool _isSaving = false;

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
      treeWtControllers,
      bhukoControllers,
      remainingTreeWtControllers,
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

  String _rowKey(Map<String, dynamic> item, int index) =>
      item["id"]?.toString() ??
          item["vacuum_voucher_item_id"]?.toString() ??
          "item_$index";

  void _saveDraft() {
    _offlineDraft.saveCastingDraft(voucher["id"], items);
  }

  /// =========================================================
  /// BUILD
  /// =========================================================
  @override
  Widget build(BuildContext context) {
    if (!(hasPermission("tree-cutting-office-view") ||
        hasPermission("tree-cutting-office-manage"))) {
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      return treeItemCard(items[index], index);
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
                      "Tree Cutting Office",
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
                          "Tree Wt",
                          _total("tree_wt").toStringAsFixed(3),
                        ),
                      ),
                      _bottomDivider(),
                      Expanded(
                        child: _bottomTotalItem(
                          "Tree Bhuko",
                          _total("tree_bhuko").toStringAsFixed(3),
                        ),
                      ),
                      _bottomDivider(),
                      Expanded(
                        child: _bottomTotalItem(
                          "Remaining Tree Wt",
                          _total("remaining_tree_wt").toStringAsFixed(3),
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
                    await updateTreeCutting(voucher["id"], items);

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
  Widget treeItemCard(Map<String, dynamic> item, int index) {
    final String key = _rowKey(item, index);
    final bool isCustom = item["is_custom"] == true;
    final bool isSelected = item["selected"] == true;
    final bool hasGroup = _val(item["group_id"]).isNotEmpty;

    /// Controllers
    buchNoControllers.putIfAbsent(
      key,
          () => TextEditingController(text: _val(item["buch_no"])),
    );
    treeWtControllers.putIfAbsent(
      key,
          () => TextEditingController(text: _val(item["tree_wt"])),
    );
    bhukoControllers.putIfAbsent(
      key,
          () => TextEditingController(text: _val(item["tree_bhuko"])),
    );
    remainingTreeWtControllers.putIfAbsent(
      key,
          () => TextEditingController(
        text: _num(item["remaining_tree_wt"]).toStringAsFixed(3),
      ),
    );

    final String buchNo = _txt(item["buch_no"]);
    final String itemName = _txt(item["item_name"]);
    final String voucherRemarks = _txt(item["voucher_remarks"]);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
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
          /// HEADER (group હોય તો group color)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: hasGroup
                  ? getGroupColor(item["group_id"])
                  : AppColors.primaryDark.withOpacity(0.10),
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
                        itemName == "-" ? buchNo : "$buchNo  |  $itemName",
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

                /// TYPE BADGE
                Container(
                  constraints: const BoxConstraints(maxWidth: 100),
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
                      Icon(
                        isCustom ? Icons.add_circle_outline : Icons.qr_code_2,
                        size: 14,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          isCustom ? "Custom" : "Office",
                          maxLines: 1,
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
                const SizedBox(width: 7),

                /// SELECT CHECKBOX
                SizedBox(
                  width: 30,
                  height: 30,
                  child: Checkbox(
                    value: isSelected,
                    activeColor: Colors.white,
                    checkColor: AppColors.primaryDark,
                    fillColor: WidgetStateProperty.all(Colors.white),
                    side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (value) {
                      setState(() {
                        item["selected"] = value ?? false;
                        if (value == false) item["group_id"] = null;
                      });
                      _saveDraft();
                    },
                  ),
                ),
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
                  /// BUCH NO
                  _treeMiniField(
                    label: "Buch No",
                    controller: buchNoControllers[key]!,
                    width: 80,
                    readOnly: !isCustom,
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      item["buch_no"] = value;
                      _saveDraft();
                      setState(() {});
                    },
                  ),

                  /// 🔥 ITEM
                  _treeMiniText("Item", itemName, width: 150),

                  /// TREE WT
                  _treeMiniField(
                    label: "Tree Wt",
                    controller: treeWtControllers[key]!,
                    width: 100,
                    readOnly: true,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) {},
                  ),

                  /// TREE BHUKO
                  _treeMiniField(
                    label: "Tree Bhuko",
                    controller: bhukoControllers[key]!,
                    width: 100,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      item["tree_bhuko"] = value;
                      item["office_cut_wt"] = value;
                      _calculateTreeRemaining(item, key);
                      _saveDraft();
                      setState(() {});
                    },
                  ),

                  /// REMAINING
                  _treeMiniField(
                    label: "Remaining",
                    controller: remainingTreeWtControllers[key]!,
                    width: 110,
                    readOnly: true,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) {},
                  ),

                  /// 🔥 VOUCHER REMARKS
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
  /// TOP INFO + APPLY TO CHECKED
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

          /// APPLY TO CHECKED
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              borderRadius: BorderRadius.circular(5),
              onTap: _applyToChecked,
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
                    Icon(
                      Icons.check_circle_outline,
                      color: Colors.white,
                      size: 17,
                    ),
                    SizedBox(width: 5),
                    Text(
                      "Apply to Checked",
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

  void _applyToChecked() {
    final bool hasSelectedItem = items.any((e) => e["selected"] == true);

    if (!hasSelectedItem) {
      AppMessage.error(context, "ઓછામાં ઓછી એક Buch select કરો.");
      return;
    }

    final String groupId = DateTime.now().millisecondsSinceEpoch.toString();

    setState(() {
      for (final item in items) {
        if (item["selected"] == true && _val(item["group_id"]).isEmpty) {
          item["group_id"] = groupId;
        }
      }
    });

    _saveDraft();
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
      ApiConstants.tree_cutting_office_pdf,
      id,
      responseType: ResponseType.bytes,
    );

    if (response != null && response.statusCode == 200) {
      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/Tree_Cutting_Office_$id.pdf");
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
  /// 🔥 API — item_name + voucher_remarks સાથે
  /// true = success / offline save
  /// =========================================================
  Future<bool> updateTreeCutting(
      int voucherId,
      List<Map<String, dynamic>> items,
      ) async {
    final Map<String, dynamic> itemData = {};

    for (final item in items) {
      final dynamic voucherItemId = item["vacuum_voucher_item_id"];
      if (voucherItemId == null) continue;

      itemData[voucherItemId.toString()] = {
        /// Tree Bhuko → office_cut_wt
        "office_cut_wt": _num(item["tree_bhuko"]).toStringAsFixed(3),
        "group_checked": item["selected"] == true,

        /// 🔥 NEW
        "item_name": _val(item["item_name"]),
        "voucher_remarks": _val(item["voucher_remarks"]),
      };
    }

    if (itemData.isEmpty) {
      AppMessage.error(context, "No items found.");
      return false;
    }

    final Map<String, dynamic> body = {"items": itemData};
    debugPrint("📤 TREE CUTTING BODY => $body");

    setState(() => _isSaving = true);

    try {
      final response = await OfflineApiHelper.instance.putRequest(
        "${ApiConstants.tree_cutting_office}/$voucherId",
        body,
      );

      debugPrint("PUT Response : ${response?.data}");

      if (!mounted) return false;

      if (response == null) {
        AppMessage.error(context, "No response from server.");
        return false;
      }

      final int statusCode = response.statusCode ?? 0;

      /// OFFLINE SAVED
      if (statusCode == 202) {
        AppMessage.success(context, "No Internet. Update saved offline.");
        await _offlineDraft.clearCastingDraft(voucherId);
        return true;
      }

      /// SUCCESS
      final data = response.data;
      if (statusCode == 200 && data is Map && data["success"] == true) {
        AppMessage.success(context, data["message"] ?? "Updated Successfully");
        await _offlineDraft.clearCastingDraft(voucherId);
        return true;
      }

      /// VALIDATION / OTHER ERROR
      String msg = "Something went wrong";
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
      debugPrint("updateTreeCutting error: $e");
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        AppMessage.error(context, "Update failed. Please try again.");
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// =========================================================
  /// REMAINING = Tree Wt - Tree Bhuko (0 થી ઓછું નહીં)
  /// =========================================================
  void _calculateTreeRemaining(Map<String, dynamic> item, String key) {
    double remaining = _num(item["tree_wt"]) - _num(item["tree_bhuko"]);
    if (remaining < 0) remaining = 0;

    final String value = remaining.toStringAsFixed(3);
    item["remaining_tree_wt"] = value;
    remainingTreeWtControllers[key]?.text = value;
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

  /// Same group → same color
  Color getGroupColor(dynamic groupId) {
    final String id = _val(groupId);
    if (id.isEmpty) return AppColors.primaryDark.withOpacity(0.10);

    const List<Color> groupColors = [
      Color(0xFFE3F2FD), // blue
      Color(0xFFE8F5E9), // green
      Color(0xFFFFF3E0), // orange
      Color(0xFFF3E5F5), // purple
      Color(0xFFE0F2F1), // teal
      Color(0xFFFCE4EC), // pink
      Color(0xFFFFF8E1), // amber
      Color(0xFFE0F7FA), // cyan
    ];

    return groupColors[id.hashCode.abs() % groupColors.length];
  }
}
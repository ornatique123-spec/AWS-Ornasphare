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

class Addcatingmetalscreen extends StatefulWidget {
  final Map<String, dynamic> voucher;
  final List<Map<String, dynamic>> items;

  const Addcatingmetalscreen({
    super.key,
    required this.voucher,
    required this.items,
  });

  @override
  State<Addcatingmetalscreen> createState() => _AddcatingmetalscreenState();
}

class _AddcatingmetalscreenState extends State<Addcatingmetalscreen> {
  /// =========================================================
  /// 🔥 MINI FIELD SIZES — Voucher screen જેવા, બધા એક જ shape
  /// =========================================================
  static const double _miniRowH = 55;
  static const double _miniLabelH = 15;
  static const double _miniGap = 4;
  static const double _miniBoxH = _miniRowH - _miniLabelH - _miniGap; // 36

  late Map<String, dynamic> voucher;
  late List<Map<String, dynamic>> items;

  final TextEditingController meltingController = TextEditingController(
    text: "93",
  );

  final Map<String, TextEditingController> metalWeightControllers = {};
  final Map<String, TextEditingController> otherMetalControllers = {};
  final Map<String, TextEditingController> pureFineControllers = {};
  final Map<String, TextEditingController> meltingControllers = {};

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
    meltingController.dispose();
    for (final map in [
      metalWeightControllers,
      otherMetalControllers,
      pureFineControllers,
      meltingControllers,
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

  /// =========================================================
  /// BUILD
  /// =========================================================
  @override
  Widget build(BuildContext context) {
    if (!(hasPermission("casting-metal-issue-view") ||
        hasPermission("casting-metal-issue-manage"))) {
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
                      return castingMetalItemCard(items[index], index);
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
                      "Add Casting Detail",
                      style: TextStyle(
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
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
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
                /// TOTAL SILVER WEIGHT
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "Total Silver Wt",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Text(
                        items
                            .fold<double>(
                          0.0,
                              (sum, item) =>
                          sum +
                              (double.tryParse(
                                _val(item["silver_wt"]),
                              ) ??
                                  0),
                        )
                            .toStringAsFixed(3),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
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
                    await updateCastingHeating(voucher["id"], items);

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
    final String key = item["id"].toString();
    final bool isIF = item["is_if"] == true;
    final bool inBhati = item["in_bhati"] == true;

    /// Controllers
    meltingControllers.putIfAbsent(
      key,
          () => TextEditingController(text: _val(item["if_percentage"])),
    );
    pureFineControllers.putIfAbsent(
      key,
          () => TextEditingController(text: _val(item["pure_fine"])),
    );
    otherMetalControllers.putIfAbsent(
      key,
          () => TextEditingController(text: _val(item["other_metal"])),
    );
    metalWeightControllers.putIfAbsent(
      key,
          () => TextEditingController(text: _val(item["metal_weight"])),
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
                        itemName == "-" ? buchNo : "$buchNo  |  $itemName",
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

                /// IN BHATI STATUS
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: inBhati ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    inBhati ? "In Bhati" : "Not Bhati",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
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
                  /// 🔥 ITEM
                  _castingMiniText("Item", itemName, width: 150),

                  /// SILVER WT
                  _castingMiniText(
                    "Silver Wt",
                    _txt(item["silver_wt"]),
                    width: 90,
                  ),

                  /// I/F
                  _castingMiniCheckbox(
                    label: "I/F",
                    value: isIF,
                    width: 55,
                    onChanged: (value) {
                      setState(() {
                        item["is_if"] = value ?? false;

                        if (value == true) {
                          final double melting =
                              double.tryParse(meltingController.text) ?? 0;

                          item["if_percentage"] = melting.toString();
                          meltingControllers[key]?.text =
                              melting.toStringAsFixed(2);

                          calculateMetalWeight(item, melting, setState);
                        } else {
                          _clearIF(item, key);
                        }
                      });

                      _offlineDraft.saveCastingDraft(voucher["id"], items);
                    },
                  ),

                  /// MELTING
                  _castingMiniField(
                    label: "Melting %",
                    controller: meltingControllers[key]!,
                    width: 90,
                    readOnly: !isIF,
                    onChanged: (value) {
                      item["if_percentage"] = value;
                      final double melting = double.tryParse(value) ?? 0;
                      calculateMetalWeight(item, melting, setState);
                      _offlineDraft.saveCastingDraft(voucher["id"], items);
                    },
                  ),

                  /// PURE FINE
                  _castingMiniField(
                    label: "Pure Fine",
                    controller: pureFineControllers[key]!,
                    width: 90,
                    readOnly: !isIF,
                    onChanged: (value) {
                      item["pure_fine"] = value;

                      final double pureFine = double.tryParse(value) ?? 0;
                      final double melting = double.tryParse(
                        meltingControllers[key]?.text ?? "0",
                      ) ??
                          0;

                      if (pureFine > 0 && melting > 0) {
                        final double metalWeight = pureFine / (melting / 100);
                        final double otherMetal = metalWeight - pureFine;

                        item["metal_weight"] = metalWeight.toStringAsFixed(3);
                        item["other_metal"] = otherMetal.toStringAsFixed(3);

                        metalWeightControllers[key]?.text =
                            metalWeight.toStringAsFixed(3);
                        otherMetalControllers[key]?.text =
                            otherMetal.toStringAsFixed(3);
                      } else {
                        item["metal_weight"] = "";
                        item["other_metal"] = "";
                        metalWeightControllers[key]?.clear();
                        otherMetalControllers[key]?.clear();
                      }

                      _offlineDraft.saveCastingDraft(voucher["id"], items);
                      setState(() {});
                    },
                  ),

                  /// OTHER METAL
                  _castingMiniField(
                    label: "O/M",
                    controller: otherMetalControllers[key]!,
                    width: 85,
                    readOnly: !isIF,
                    onChanged: (value) {
                      item["other_metal"] = value;
                      _offlineDraft.saveCastingDraft(voucher["id"], items);
                    },
                  ),

                  /// METAL WEIGHT
                  _castingMiniField(
                    label: "Metal Wt",
                    controller: metalWeightControllers[key]!,
                    width: 100,
                    readOnly: !isIF,
                    onChanged: (value) {
                      item["metal_weight"] = value;
                      _offlineDraft.saveCastingDraft(voucher["id"], items);
                    },
                  ),

                  /// ISSUE SILVER
                  _castingMiniInitialField(
                    label: "Issue Silver",
                    value: _val(item["issue_silver_wt"]),
                    width: 100,
                    onChanged: (value) {
                      item["issue_silver_wt"] = value;
                      _offlineDraft.saveCastingDraft(voucher["id"], items);
                    },
                  ),

                  /// 🔥 VOUCHER REMARKS (read-only)
                  _castingMiniText(
                    "Voucher Remarks",
                    voucherRemarks,
                    width: 150,
                  ),

                  /// REMARKS
                  _castingMiniInitialField(
                    label: "Remarks",
                    value: _val(item["remarks"]),
                    width: 150,
                    numberKeyboard: false,
                    onChanged: (value) {
                      item["remarks"] = value;
                      _offlineDraft.saveCastingDraft(voucher["id"], items);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _clearIF(Map<String, dynamic> item, String key) {
    item["if_percentage"] = "";
    item["pure_fine"] = "";
    item["other_metal"] = "";
    item["metal_weight"] = "";

    meltingControllers[key]?.clear();
    pureFineControllers[key]?.clear();
    otherMetalControllers[key]?.clear();
    metalWeightControllers[key]?.clear();
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
  Widget _castingMiniText(String title, String value, {double width = 90}) {
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

  /// CONTROLLER વાળું FIELD
  Widget _castingMiniField({
    required String label,
    required TextEditingController controller,
    double width = 90,
    bool readOnly = false,
    bool numberKeyboard = true,
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
          keyboardType: numberKeyboard
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
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
                controller.text == "0.00") {
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

  /// INITIAL VALUE વાળું FIELD
  Widget _castingMiniInitialField({
    required String label,
    required String value,
    double width = 90,
    bool numberKeyboard = true,
    required ValueChanged<String> onChanged,
  }) {
    return _miniShell(
      label: label,
      width: width,
      box: Container(
        decoration: _miniBoxDecoration(),
        child: TextFormField(
          initialValue: value,
          expands: true,
          maxLines: null,
          minLines: null,
          textAlignVertical: TextAlignVertical.center,
          keyboardType: numberKeyboard
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          textInputAction: TextInputAction.done,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
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

  /// CHECKBOX
  Widget _castingMiniCheckbox({
    required String label,
    required bool value,
    double width = 55,
    required ValueChanged<bool?> onChanged,
  }) {
    return _miniShell(
      label: label,
      width: width,
      box: Container(
        alignment: Alignment.center,
        decoration: _miniBoxDecoration(),
        child: Transform.scale(
          scale: 0.85,
          child: Checkbox(
            value: value,
            activeColor: AppColors.gradientBlue,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  /// =========================================================
  /// TOP INFO + GLOBAL MELTING
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

          /// GLOBAL MELTING
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextFormField(
              controller: meltingController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                labelText: "Melting",
                hintText: "Enter Melting",
                labelStyle: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
                floatingLabelStyle: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
                prefixIcon: const Icon(
                  Icons.local_fire_department,
                  color: Colors.black,
                ),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
              ),
              onChanged: (value) {
                final double melting = double.tryParse(value) ?? 0;

                for (final item in items) {
                  final String key = item["id"].toString();

                  if (item["is_if"] == true) {
                    item["if_percentage"] = value;
                    meltingControllers[key]?.text = value;
                    calculateMetalWeight(item, melting, setState);
                  } else {
                    _clearIF(item, key);
                  }
                }

                if (items.isNotEmpty) {
                  items.first["_melting_value"] = value;
                }

                _offlineDraft.saveCastingDraft(voucher["id"], items);
                setState(() {});
              },
            ),
          ),
        ],
      ),
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
      ApiConstants.casting_metal_issue_pdf,
      id,
      responseType: ResponseType.bytes,
    );

    if (response != null && response.statusCode == 200) {
      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/Casting_Metal$id.pdf");
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
  Future<bool> updateCastingHeating(
      int voucherId,
      List<Map<String, dynamic>> items,
      ) async {
    final Map<String, dynamic> itemData = {};

    for (final item in items) {
      if (item["in_bhati"] != true) continue;

      itemData[item["id"].toString()] = {
        "issue_silver_wt":
        double.tryParse(_val(item["issue_silver_wt"])) ?? 0,
        "is_if": item["is_if"] ?? false,
        "pure_fine": double.tryParse(_val(item["pure_fine"])) ?? 0,
        "if_percentage": double.tryParse(_val(item["if_percentage"])) ?? 0,
        "remarks": _val(item["remarks"]),

        /// 🔥 NEW
        "item_name": _val(item["item_name"]),
        "voucher_remarks": _val(item["voucher_remarks"]),
      };
    }

    final body = {"melting": meltingController.text, "items": itemData};
    debugPrint("PUT Request : $body");

    setState(() => _isSaving = true);

    try {
      final response = await OfflineApiHelper.instance.putRequest(
        "${ApiConstants.casting_metal_issue}/$voucherId",
        body,
      );

      debugPrint("PUT Response : ${response?.data}");
      debugPrint("Status Code : ${response?.statusCode}");

      if (!mounted) return false;

      if (response == null) {
        AppMessage.error(context, "No response from server");
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
      debugPrint("Casting update exception: $e");
      if (mounted) {
        AppMessage.error(context, "Something went wrong. Please try again.");
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// =========================================================
  /// CALCULATION
  /// =========================================================
  void calculateMetalWeight(
      Map<String, dynamic> c,
      double melting,
      StateSetter setStateDialog,
      ) {
    final String key = c["id"].toString();
    final double silverWeight = double.tryParse(_val(c["silver_wt"])) ?? 0;

    if (silverWeight > 0 && melting > 0) {
      final double pureFine = silverWeight * (melting / 100);
      final double metalWeight = silverWeight;
      final double otherMetal = metalWeight - pureFine;

      c["pure_fine"] = pureFine.toStringAsFixed(3);
      c["metal_weight"] = metalWeight.toStringAsFixed(3);
      c["other_metal"] = otherMetal.toStringAsFixed(3);

      pureFineControllers[key]?.text = c["pure_fine"];
      metalWeightControllers[key]?.text = c["metal_weight"];
      otherMetalControllers[key]?.text = c["other_metal"];
    } else {
      c["pure_fine"] = "";
      c["metal_weight"] = "";
      c["other_metal"] = "";

      pureFineControllers[key]?.clear();
      metalWeightControllers[key]?.clear();
      otherMetalControllers[key]?.clear();
    }

    setStateDialog(() {});
  }
}
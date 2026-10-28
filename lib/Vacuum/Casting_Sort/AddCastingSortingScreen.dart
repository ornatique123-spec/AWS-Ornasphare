import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dropdown_search/dropdown_search.dart';
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

class Addcastingsortingscreen extends StatefulWidget {
  final Map<String, dynamic> voucher;
  final List<Map<String, dynamic>> items;

  const Addcastingsortingscreen({
    super.key,
    required this.voucher,
    required this.items,
  });

  @override
  State<Addcastingsortingscreen> createState() =>
      _AddcastingsortingscreenState();
}

class _AddcastingsortingscreenState extends State<Addcastingsortingscreen> {
  /// =========================================================
  /// DATA
  /// =========================================================

  late Map<String, dynamic> voucher;

  late List<Map<String, dynamic>> items;

  List<String> userPermissions = [];

  bool isSaving = false;

  /// =========================================================
  /// INIT
  /// =========================================================
  bool isVoucherDetailsExpanded = false;
  @override
  void initState() {
    super.initState();

    voucher = Map<String, dynamic>.from(widget.voucher);

    /// 🔥 FIX: har row ne UNIQUE "_row_key" aapyo che.
    /// Aa key thi Flutter row delete/add thay tyare sacho state
    /// reuse kare che (TextFormField initialValue bug fix).
    items = widget.items.asMap().entries.map((entry) {
      final Map<String, dynamic> item =
      Map<String, dynamic>.from(entry.value);

      /// -----------------------------------------
      /// UNIQUE ROW KEY (UI only, API ma jase nahi)
      /// -----------------------------------------
      item["_row_key"] =
      "row_${DateTime.now().microsecondsSinceEpoch}_${entry.key}";

      /// -----------------------------------------
      /// ITEM DATA NORMALIZE
      /// -----------------------------------------

      item["item_id"] ??= item["item"]?["id"];

      item["item_name"] ??=
          item["item"]?["item_name"] ??
              item["name"] ??
              "";

      /// -----------------------------------------
      /// STOCK TYPE
      /// -----------------------------------------
      item["stock_type"] =
          item["stock_type"]?.toString() ?? "";

      /// -----------------------------------------
      /// WEIGHT
      /// -----------------------------------------
      item["weight"] =
          item["weight"]?.toString() ?? "";

      /// -----------------------------------------
      /// QUANTITY
      /// -----------------------------------------
      item["quantity"] =
          item["quantity"]?.toString() ?? "";

      return item;
    }).toList();
    /// 🔥 Hammesha last ma ek blank row hovi joie
    if (items.isEmpty || !_isRowEmpty(items.last)) {
      items.add(_createBlankRow());
    }

    loadPermissions();

    Future.microtask(() {
      final provider = Provider.of<ItemProvider>(context, listen: false);

      /// જો provider.items પહેલાથી load હોય
      /// તો ફરી API call કરવાની જરૂર નથી.
      ///
      /// જો તમારે items API load કરવી હોય તો
      /// અહીં તમારું function call કરો.
      ///
      /// Example:
      ///
      /// provider.loadItems();
    });

    debugPrint("======================================");

    debugPrint("🔥 CASTING SORTING VOUCHER");

    debugPrint(voucher.toString());

    debugPrint("🔥 CASTING SORTING ITEMS");

    debugPrint(items.toString());

    debugPrint("======================================");
  }

  /// =========================================================
  /// PERMISSION
  /// =========================================================

  Future<void> loadPermissions() async {
    final prefs = await SharedPreferences.getInstance();

    final List<String> permissions =
        prefs.getStringList("user_permissions") ?? [];

    if (!mounted) return;

    setState(() {
      userPermissions = permissions;
    });
  }

  bool hasPermission(String permissionName) {
    return userPermissions.contains(permissionName);
  }

  /// =========================================================
  /// 🔥 EMPTY ROW CHECK
  ///
  /// Row ma item, weight, quantity, stock type badhu khali hoy
  /// to te row khali gani ne validation / API ma skip karvi.
  /// =========================================================

  bool _isRowEmpty(Map<String, dynamic> item) {
    final dynamic itemId =
        item["item_id"] ?? (item["item"] is Map ? item["item"]["id"] : null);

    final bool hasItem = itemId != null &&
        itemId.toString().trim().isNotEmpty &&
        itemId.toString().toLowerCase() != "null";

    final double weight = double.tryParse(item["weight"]?.toString() ?? "") ?? 0.0;
    final double quantity = double.tryParse(item["quantity"]?.toString() ?? "") ?? 0.0;

    // 🔥 stock_type ignore: default value hoy to pan row khali gani
    return !hasItem && weight <= 0 && quantity <= 0;
  }

  /// =========================================================
  /// BUILD
  /// =========================================================

  @override
  Widget build(BuildContext context) {
    /// ============================================
    /// PERMISSION
    /// Change permission name if your API uses
    /// different casting sorting permissions.
    /// ============================================

    final bool canView =
        hasPermission("casting-sorting-view") ||
            hasPermission("casting-sorting-manage");

    /// જો permissions હજુ load થઈ રહી હોય
    if (userPermissions.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!canView) {
      return Scaffold(
        body: PermissionDeniedWidget(
          onBack: () {
            Navigator.pop(context);
          },
        ),
      );
    }

    final Size size = MediaQuery.of(context).size;

    final bool isMobile = size.width < 600;

    return PopScope(
      canPop: false,

      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        Navigator.pop(context, true);
      },

      child: Scaffold(
        resizeToAvoidBottomInset: true,

        backgroundColor: AppColors.white,

        /// =================================================
        /// APP BAR
        /// =================================================
        appBar: AppBar(
          automaticallyImplyLeading: false,

          backgroundColor: Colors.white,

          surfaceTintColor: Colors.white,

          elevation: 0,

          centerTitle: true,

          title: const Text(
            "Casting Sorting",
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),

          leadingWidth: 60,

          leading: Padding(
            padding: const EdgeInsets.only(left: 13, top: 10, bottom: 10,right: 13),
            child: InkWell(
              onTap: () {
                Navigator.pop(context);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: isMobile ? 20 : 23,
                ),
              ),
            ),
          ),

          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: pdfBtn(() {
                  final dynamic id = voucher["id"];

                  if (id != null) {
                    openPdf(int.parse(id.toString()));
                  }
                }),
              ),
            ),
          ],
        ),

        /// =================================================
        /// BODY
        /// =================================================
        body: Column(
          children: [
            /// =============================================
            /// VOUCHER INFO
            /// =============================================
            filterWidget(),

            Container(
              margin: const EdgeInsets.only(top: 10, left: 10, right: 10),
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

            /// =============================================
            /// ITEM LIST
            /// =============================================
            Expanded(
              child: items.isEmpty
                  ? _emptyWidget()
                  : ListView.builder(
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,

                padding: const EdgeInsets.fromLTRB(8, 5, 8, 15),

                itemCount: items.length,

                itemBuilder: (context, index) {
                  return castingSortingItemCard(items[index], index);
                },
              ),
            ),
          ],
        ),

        /// =================================================
        /// BOTTOM
        /// =================================================
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
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
                /// =========================================
                /// TOTALS
                /// =========================================
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
                      /// TOTAL ITEMS
                      Expanded(
                        child: _bottomTotalItem(
                          "Total Items",
                          items.where((e) => !_isRowEmpty(e)).length.toString(),
                        ),
                      ),

                      _bottomDivider(),

                      /// TOTAL WEIGHT
                      Expanded(
                        child: _bottomTotalItem(
                          "Total Weight",
                          getTotalWeight().toStringAsFixed(3),
                        ),
                      ),

                      _bottomDivider(),

                      /// TOTAL QUANTITY
                      Expanded(
                        child: _bottomTotalItem(
                          "Total Quantity",
                          getTotalQuantity().toStringAsFixed(0),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                /// =========================================
                /// APPLY
                /// =========================================
                InkWell(
                  onTap: isSaving
                      ? null
                      : () async {
                    FocusManager.instance.primaryFocus?.unfocus();

                    final bool success = await updateCastingSorting();

                    if (!mounted) return;

                    if (success) {
                      Navigator.pop(context, true);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    height: 45,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryDark.withOpacity(
                            isSaving ? 0.4 : 0.8,
                          ),
                          AppColors.secondaryDark.withOpacity(
                            isSaving ? 0.4 : 0.8,
                          ),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: isSaving
                        ? const SizedBox(
                      width: 20,
                      height: 20,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// =========================================================
  /// FILTER / VOUCHER INFO
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
                  value: voucher["process_name"]?.toString() ?? "-",
                  icon: Icons.settings,
                  color: Colors.blue,
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: _infoCard(
                  title: "Worker",
                  value: voucher["worker_name"]?.toString() ?? "-",
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
                  value:
                  voucher["voucher_date"]?.toString() ??
                      voucher["voucher_date_view"]?.toString() ??
                      "-",
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
          const SizedBox(height: 8),

          /// 🔥 VOUCHER DETAILS TAB
          _voucherDetailsTab(),
        ],
      ),
    );
  }

  /// =========================================================
  /// SORTING ITEM CARD
  /// =========================================================

  // Widget castingSortingItemCard(Map<String, dynamic> item, int index) {
  //   return Container(
  //     /// 🔥 FIX: stable key — row delete thay to sacho state reuse thay
  //     key: ValueKey(item["_row_key"] ?? "row_$index"),
  //     margin: const EdgeInsets.symmetric(vertical: 4),
  //     padding: const EdgeInsets.fromLTRB(12, 7, 12, 12),
  //     decoration: BoxDecoration(
  //       color: AppColors.primaryDark.withOpacity(0.10),
  //       borderRadius: BorderRadius.circular(6),
  //       border: Border.all(color: AppColors.border),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withOpacity(0.04),
  //           blurRadius: 6,
  //           offset: const Offset(0, 2),
  //         ),
  //       ],
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         /// =========================================
  //         /// HEADER
  //         /// =========================================
  //         Row(
  //           children: [
  //             /// =====================================
  //             /// INDEX
  //             /// =====================================
  //             Container(
  //               width: 27,
  //               height: 27,
  //               alignment: Alignment.center,
  //               decoration: BoxDecoration(
  //                 color: AppColors.primaryDark,
  //                 borderRadius: BorderRadius.circular(5),
  //               ),
  //               child: Text(
  //                 "${index + 1}",
  //                 style: const TextStyle(
  //                   color: Colors.white,
  //                   fontSize: 11,
  //                   fontWeight: FontWeight.bold,
  //                 ),
  //               ),
  //             ),
  //
  //             const SizedBox(width: 8),
  //
  //             /// =====================================
  //             /// ITEM NAME
  //             /// =====================================
  //             Expanded(
  //               child: Text(
  //                 item["item_name"]?.toString().trim().isNotEmpty == true
  //                     ? item["item_name"].toString()
  //                     : "Casting Sorting Item",
  //                 maxLines: 1,
  //                 overflow: TextOverflow.ellipsis,
  //                 style: const TextStyle(
  //                   color: Colors.black,
  //                   fontSize: 12,
  //                   fontWeight: FontWeight.bold,
  //                 ),
  //               ),
  //             ),
  //
  //             /// =====================================
  //             /// SORTING BADGE
  //             /// =====================================
  //             Container(
  //               padding: const EdgeInsets.symmetric(
  //                 horizontal: 8,
  //                 vertical: 3,
  //               ),
  //               decoration: BoxDecoration(
  //                 color: AppColors.primaryDark,
  //                 borderRadius: BorderRadius.circular(3),
  //               ),
  //               child: const Text(
  //                 "Sorting",
  //                 style: TextStyle(
  //                   color: Colors.white,
  //                   fontSize: 9,
  //                   fontWeight: FontWeight.bold,
  //                 ),
  //               ),
  //             ),
  //
  //             const SizedBox(width: 6),
  //
  //             /// =====================================
  //             /// DELETE BUTTON
  //             /// =====================================
  //             InkWell(
  //               onTap: () {
  //                 FocusManager.instance.primaryFocus?.unfocus();
  //
  //                 setState(() {
  //                   /// Current row remove (reference thi, index thi nahi)
  //                   items.remove(item);
  //                 });
  //
  //                 debugPrint("🗑️ Sorting item removed => index: $index");
  //               },
  //               borderRadius: BorderRadius.circular(5),
  //               child: Container(
  //                 width: 27,
  //                 height: 27,
  //                 alignment: Alignment.center,
  //                 decoration: BoxDecoration(
  //                   color: Colors.red.shade50,
  //                   borderRadius: BorderRadius.circular(5),
  //                   border: Border.all(color: Colors.red.shade200),
  //                 ),
  //                 child: Icon(
  //                   Icons.delete_outline_rounded,
  //                   size: 17,
  //                   color: Colors.red.shade700,
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //
  //         const SizedBox(height: 10),
  //
  //         /// =========================================
  //         /// ITEM + WEIGHT + QUANTITY
  //         /// =========================================
  //         SingleChildScrollView(
  //           scrollDirection: Axis.horizontal,
  //           child: Row(
  //             crossAxisAlignment: CrossAxisAlignment.end,
  //             children: [
  //               /// =====================================
  //               /// ITEM SELECTED
  //               /// =====================================
  //               Consumer<ItemProvider>(
  //                 builder: (context, provider, child) {
  //                   return itemDropdown(
  //                     item,
  //                     provider.items.cast<Map<String, dynamic>>(),
  //                         (VoidCallback fn) {
  //                       setState(fn);
  //                     },
  //                     width: 180,
  //                     height: 35,
  //                   );
  //                 },
  //               ),
  //
  //               const SizedBox(width: 8),
  //
  //               /// =====================================
  //               /// STOCK TYPE
  //               /// =====================================
  //               _stockTypeDropdown(item, width: 140, height: 35),
  //
  //               const SizedBox(width: 8),
  //
  //               /// =====================================
  //               /// WEIGHT
  //               /// =====================================
  //               _sortingField(
  //                 key: ValueKey("weight_${item["_row_key"] ?? index}"),
  //                 label: "Weight",
  //                 value: item["weight"]?.toString() ?? "",
  //                 width: 110,
  //                 keyboardType: const TextInputType.numberWithOptions(
  //                   decimal: true,
  //                 ),
  //                 onChanged: (value) {
  //                   item["weight"] = value;
  //
  //                   setState(() {});
  //                 },
  //               ),
  //
  //               /// =====================================
  //               /// QUANTITY
  //               /// =====================================
  //               _sortingField(
  //                 key: ValueKey("quantity_${item["_row_key"] ?? index}"),
  //                 label: "Quantity",
  //                 value: item["quantity"]?.toString() ?? "",
  //                 width: 110,
  //                 keyboardType: TextInputType.number,
  //                 onChanged: (value) {
  //                   item["quantity"] = value;
  //
  //                   setState(() {});
  //                 },
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }


  Widget castingSortingItemCard(Map<String, dynamic> item, int index) {
    return Container(
      /// 🔥 FIX: stable key — row delete thay to sacho state reuse thay
      key: ValueKey(item["_row_key"] ?? "row_$index"),
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 5),

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
          /// ============================================
          /// HEADER
          /// ============================================
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),

            decoration: BoxDecoration(
              color: AppColors.primaryDark.withOpacity(0.10),

              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(5),
                topRight: Radius.circular(5),
              ),
            ),

            child: Row(
              children: [
                /// INDEX BADGE
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
                        item["item_name"]?.toString().trim().isNotEmpty ==
                            true
                            ? item["item_name"].toString()
                            : "Casting Sorting Item",
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

                /// SORTING BADGE
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
                      const Icon(
                        Icons.category_outlined,
                        size: 14,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(width: 4),
                      const Flexible(
                        child: Text(
                          "Sorting",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
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

                /// DELETE BUTTON
                InkWell(
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();

                    setState(() {
                      /// Current row remove (reference thi, index thi nahi)
                      items.remove(item);
                    });

                    debugPrint("🗑️ Sorting item removed => index: $index");
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

          /// ============================================
          /// FIELDS
          /// ============================================
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),

            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  /// =====================================
                  /// ITEM SELECTED
                  /// =====================================
                  Consumer<ItemProvider>(
                    builder: (context, provider, child) {
                      return itemDropdown(
                        item,
                        provider.items.cast<Map<String, dynamic>>(),
                            (VoidCallback fn) {
                          setState(fn);
                        },
                        width: 180,
                        height: 35,
                      );
                    },
                  ),

                  const SizedBox(width: 8),

                  /// =====================================
                  /// STOCK TYPE
                  /// =====================================
                  _stockTypeDropdown(item, width: 140, height: 35),

                  const SizedBox(width: 8),

                  /// =====================================
                  /// WEIGHT
                  /// =====================================
                  _sortingField(
                    key: ValueKey("weight_${item["_row_key"] ?? index}"),
                    label: "Weight",
                    value: item["weight"]?.toString() ?? "",
                    width: 110,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (value) {
                      item["weight"] = value;

                      setState(() {});
                    },
                  ),

                  /// =====================================
                  /// QUANTITY
                  /// =====================================
                  _sortingField(
                    key: ValueKey("quantity_${item["_row_key"] ?? index}"),
                    label: "Quantity",
                    value: item["quantity"]?.toString() ?? "",
                    width: 110,
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      item["quantity"] = value;

                      setState(() {});
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
  /// =========================================================
  /// ITEM DROPDOWN
  /// =========================================================

  Widget itemDropdown(
      Map<String, dynamic> currentItem,
      List<Map<String, dynamic>> itemOptions,
      void Function(VoidCallback) setStateLocal, {
        double width = 180,
        double height = 35,
      }) {
    /// =========================================================
    /// CURRENT SELECTED ITEM ID
    /// =========================================================
    String? selectedId = currentItem["item_id"]?.toString();

    selectedId ??= currentItem["item"]?["id"]?.toString();

    /// =========================================================
    /// UNIQUE ITEMS
    /// =========================================================
    final Map<String, Map<String, dynamic>> uniqueItems = {};

    for (final data in itemOptions) {
      final dynamic rawItem = data["item"] ?? data;

      if (rawItem is! Map<String, dynamic>) {
        continue;
      }

      final String? id = rawItem["id"]?.toString();

      if (id == null || id.isEmpty) {
        continue;
      }

      uniqueItems[id] = Map<String, dynamic>.from(rawItem);
    }

    /// =========================================================
    /// CURRENT ITEM API LIST MA NA HOY
    /// TO TEMPORARY ADD KARO
    /// =========================================================
    if (selectedId != null &&
        selectedId.isNotEmpty &&
        !uniqueItems.containsKey(selectedId)) {
      uniqueItems[selectedId] = {
        "id": selectedId,
        "item_name":
        currentItem["item_name"] ??
            currentItem["item"]?["item_name"] ??
            "Item $selectedId",
      };
    }

    /// =========================================================
    /// INVALID SELECTED ID
    /// =========================================================
    if (selectedId != null && !uniqueItems.containsKey(selectedId)) {
      selectedId = null;
    }

    /// =========================================================
    /// DROPDOWN IDS
    /// =========================================================
    final List<String> dropdownIds = uniqueItems.keys.toList();

    return Container(
      width: width,
      margin: const EdgeInsets.only(right: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// =====================================================
          /// LABEL
          /// =====================================================
          const Text(
            "Item Selected",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 3),

          /// =====================================================
          /// PREMIUM SEARCH DROPDOWN
          /// =====================================================
          SizedBox(
            height: height,
            child: DropdownSearch<String>(
              /// =================================================
              /// ITEMS
              /// =================================================
              items: dropdownIds,

              /// =================================================
              /// CURRENT SELECTED VALUE
              /// =================================================
              selectedItem: selectedId,

              /// =================================================
              /// ITEM NAME SHOW
              /// =================================================
              itemAsString: (String id) {
                final Map<String, dynamic>? data = uniqueItems[id];

                if (data == null) {
                  return "";
                }

                return data["item_name"]?.toString() ??
                    data["name"]?.toString() ??
                    "Item $id";
              },

              /// =================================================
              /// SELECT CHANGE
              /// =================================================
              // onChanged: (String? value) {
              //   if (value == null) {
              //     return;
              //   }
              //
              //   final Map<String, dynamic>? selectedItem = uniqueItems[value];
              //
              //   if (selectedItem == null) {
              //     return;
              //   }
              //
              //   setStateLocal(() {
              //     currentItem["item_id"] = selectedItem["id"];
              //
              //     currentItem["item_name"] =
              //         selectedItem["item_name"]?.toString() ??
              //             selectedItem["name"]?.toString() ??
              //             "";
              //
              //     currentItem["item"] = Map<String, dynamic>.from(
              //       selectedItem,
              //     );
              //   });
              //
              //   debugPrint(
              //     "🔥 Selected Item => "
              //         "${currentItem["item_id"]} "
              //         "${currentItem["item_name"]}",
              //   );
              // },
              onChanged: (String? value) {
                if (value == null) return;

                final Map<String, dynamic>? selectedItem = uniqueItems[value];

                if (selectedItem == null) return;

                /// 🔥 Item set karta pehla check karo ke aa LAST row che ke nahi
                final bool isLastRow =
                    items.isNotEmpty && identical(items.last, currentItem);

                setStateLocal(() {
                  currentItem["item_id"] = selectedItem["id"];

                  currentItem["item_name"] =
                      selectedItem["item_name"]?.toString() ??
                          selectedItem["name"]?.toString() ??
                          "";

                  currentItem["item"] = Map<String, dynamic>.from(selectedItem);

                  /// 🔥 Last row ma item select thay to niche nava blank row add karo
                  if (isLastRow) {
                    items.add(_createBlankRow());
                  }
                });

                debugPrint(
                  "🔥 Selected Item => ${currentItem["item_id"]} ${currentItem["item_name"]}",
                );
              },
              /// =================================================
              /// MAIN FIELD PREMIUM DESIGN
              /// =================================================
              dropdownDecoratorProps: DropDownDecoratorProps(
                baseStyle: const TextStyle(
                  fontSize: 12,
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
                dropdownSearchDecoration: InputDecoration(
                  hintText: "Select Item",

                  hintStyle: const TextStyle(
                    fontSize: 11,
                    color: Colors.black45,
                    fontWeight: FontWeight.w500,
                  ),

                  isDense: true,

                  filled: true,

                  fillColor: Colors.white,

                  contentPadding: const EdgeInsets.only(
                    left: 10,
                    right: 6,
                    top: 7,
                    bottom: 7,
                  ),

                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: AppColors.border),
                  ),

                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: AppColors.border),
                  ),

                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                      color: AppColors.primaryDark,
                      width: 1.4,
                    ),
                  ),
                ),
              ),

              /// =================================================
              /// DROPDOWN BUTTON DESIGN
              /// =================================================
              dropdownButtonProps: DropdownButtonProps(
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: AppColors.primaryDark,
                ),
              ),

              /// =================================================
              /// POPUP
              /// =================================================
              popupProps: PopupProps.bottomSheet(
                showSearchBox: true,
                showSelectedItems: true,

                /// ============================================
                /// SEARCH
                /// ============================================
                searchFieldProps: TextFieldProps(
                  autofocus: false,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: "Search item...",

                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),

                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppColors.primaryDark,
                      size: 21,
                    ),

                    filled: true,
                    fillColor: Colors.grey.shade50,

                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),

                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),

                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: AppColors.primaryDark,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),

                /// ============================================
                /// BOTTOM SHEET DESIGN
                /// ============================================
                bottomSheetProps: BottomSheetProps(
                  backgroundColor: Colors.white,
                  elevation: 15,

                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                  ),
                ),

                /// ============================================
                /// ITEM DESIGN
                /// ============================================
                itemBuilder:
                    (BuildContext context, String id, bool isSelected) {
                  final Map<String, dynamic>? data = uniqueItems[id];

                  final String name =
                      data?["item_name"]?.toString() ??
                          data?["name"]?.toString() ??
                          "Item $id";

                  final String code =
                      data?["item_code"]?.toString() ??
                          data?["code"]?.toString() ??
                          "";

                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 3,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryDark.withOpacity(0.08)
                          : Colors.white,

                      borderRadius: BorderRadius.circular(8),

                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryDark.withOpacity(0.35)
                            : Colors.grey.shade200,
                      ),
                    ),

                    child: Row(
                      children: [
                        /// ICON
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.inventory_2_outlined,
                            size: 19,
                            color: AppColors.primaryDark,
                          ),
                        ),

                        const SizedBox(width: 10),

                        /// NAME + CODE
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),

                              if (code.isNotEmpty) ...[
                                const SizedBox(height: 2),

                                Text(
                                  code,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: AppColors.primaryDark,
                            size: 20,
                          ),
                      ],
                    ),
                  );
                },

                /// ============================================
                /// NO RESULT
                /// ============================================
                emptyBuilder: (BuildContext context, String searchEntry) {
                  return Padding(
                    padding: const EdgeInsets.all(30),
                    child: Center(
                      child: Text(
                        "No Item Found",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// =========================================================
  /// SORTING FIELD
  /// =========================================================

  Widget _sortingField({
    required Key key,
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    required TextInputType keyboardType,
    double width = 100,
  }) {
    return Container(
      key: key,
      width: width,
      margin: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 3),

          SizedBox(
            height: 35,
            child: TextFormField(
              initialValue: value,

              keyboardType: keyboardType,

              textAlign: TextAlign.center,

              style: const TextStyle(
                fontSize: 12,
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),

              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white,

                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 9,
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
                  borderRadius: BorderRadius.circular(5),
                  borderSide: BorderSide(
                    color: AppColors.primaryDark,
                    width: 1.5,
                  ),
                ),
              ),

              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  /// =========================================================
  /// TOTAL WEIGHT
  /// =========================================================

  double getTotalWeight() {
    return items.fold<double>(0.0, (sum, item) {
      return sum + (double.tryParse(item["weight"]?.toString() ?? "0") ?? 0.0);
    });
  }

  /// =========================================================
  /// TOTAL QUANTITY
  /// =========================================================

  double getTotalQuantity() {
    return items.fold<double>(0.0, (sum, item) {
      return sum +
          (double.tryParse(item["quantity"]?.toString() ?? "0") ?? 0.0);
    });
  }

  /// =========================================================
  /// VALIDATION
  ///
  /// 🔥 FIX: khali rows skip thay che.
  /// =========================================================

  bool validateItems() {
    if (items.isEmpty) {
      AppMessage.error(context, "No items found.");

      return false;
    }
    _resolveMissingItemIds();   // 🔥 ADD

    int validCount = 0;

    for (int i = 0; i < items.length; i++) {
      final item = items[i];

      /// 🔥 Khali row skip
      if (_isRowEmpty(item)) continue;

      validCount++;

      final dynamic itemId = item["item_id"] ?? item["item"]?["id"];

      final double weight =
          double.tryParse(item["weight"]?.toString() ?? "") ?? 0.0;

      final double quantity =
          double.tryParse(item["quantity"]?.toString() ?? "") ?? 0.0;

      if (itemId == null || itemId.toString().isEmpty) {
        AppMessage.error(context, "Please select item in row ${i + 1}.");

        return false;
      }

      /// Jo stock type mandatory hoy to aa uncomment karo:
      /// final String stockType = item["stock_type"]?.toString().trim() ?? "";
      /// if (stockType.isEmpty) {
      ///   AppMessage.error(context, "Please select stock type in row ${i + 1}.");
      ///   return false;
      /// }

      if (weight <= 0) {
        AppMessage.error(context, "Please enter weight in row ${i + 1}.");

        return false;
      }

      if (quantity <= 0) {
        AppMessage.error(context, "Please enter quantity in row ${i + 1}.");

        return false;
      }
    }

    if (validCount == 0) {
      AppMessage.error(context, "Please fill at least one row.");

      return false;
    }

    return true;
  }

  /// =========================================================
  /// UPDATE CASTING SORTING
  /// =========================================================

  Future<bool> updateCastingSorting() async {
    if (!validateItems()) {
      return false;
    }

    final dynamic voucherId = voucher["id"];

    if (voucherId == null) {
      AppMessage.error(context, "Voucher ID not found.");

      return false;
    }

    /// =====================================================
    /// CREATE REQUEST ITEMS
    /// =====================================================
    final List<Map<String, dynamic>> requestItems = [];

    for (final item in items) {
      /// 🔥 Khali row API ma na moklo
      if (_isRowEmpty(item)) continue;

      /// =========================================
      /// ITEM ID
      /// =========================================
      final dynamic itemId = item["item_id"] ?? item["item"]?["id"];

      /// =========================================
      /// STOCK TYPE
      /// =========================================
      String stockType = item["stock_type"]?.toString().trim() ?? "";

      /// UI value hoy:
      /// Raw Material / Finished Item / Scrap / Repair
      ///
      /// API value banavse:
      /// raw_material / finished_item / scrap / repair

      stockType = stockType.toLowerCase().replaceAll(" ", "_");

      /// =========================================
      /// WEIGHT
      /// API wants String: "125.500"
      /// =========================================
      final double weight =
          double.tryParse(item["weight"]?.toString() ?? "0") ?? 0.0;

      /// =========================================
      /// QUANTITY
      /// API wants integer
      /// =========================================
      final int quantity =
          double.tryParse(item["quantity"]?.toString() ?? "0")?.toInt() ?? 0;

      /// =========================================
      /// ADD REQUEST ITEM
      /// =========================================
      requestItems.add({
        "item_id": itemId,
        "stock_type": stockType,
        "weight": weight.toStringAsFixed(3),
        "quantity": quantity,
      });
    }

    /// =====================================================
    /// REQUEST BODY
    /// =====================================================
    final Map<String, dynamic> body = {"items": requestItems};

    debugPrint("======================================");

    debugPrint("📤 CASTING SORTING UPDATE");

    debugPrint("Voucher ID => $voucherId");

    debugPrint("Items => $requestItems");

    debugPrint("Body => $body");

    debugPrint("======================================");

    setState(() {
      isSaving = true;
    });

    try {
      /// =====================================================
      /// API CALL
      /// =====================================================
      final response = await ApiHelper().putRequest(
        "${ApiConstants.casting_sorting}/$voucherId",
        body,
      );

      debugPrint("🔥 CASTING SORTING RESPONSE => ${response?.data}");

      if (!mounted) {
        return false;
      }

      /// =====================================================
      /// NO RESPONSE
      /// =====================================================
      if (response == null) {
        AppMessage.error(context, "No response from server.");

        return false;
      }

      final dynamic data = response.data;

      /// =====================================================
      /// SUCCESS
      /// =====================================================
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          data is Map &&
          data["success"] == true) {
        AppMessage.success(
          context,
          data["message"]?.toString() ??
              "Casting Sorting Updated Successfully",
        );

        return true;
      }

      /// =====================================================
      /// API ERROR MESSAGE
      /// =====================================================
      String message = "Failed to update Casting Sorting.";

      if (data is Map && data["message"] != null) {
        message = data["message"].toString();
      }

      AppMessage.error(context, message);

      return false;
    } catch (e) {
      debugPrint("❌ CASTING SORTING ERROR => $e");

      if (mounted) {
        AppMessage.error(context, "Failed to update Casting Sorting.");
      }

      return false;
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  /// =========================================================
  /// INFO CARD
  /// =========================================================

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
  /// TOTAL ITEM
  /// =========================================================

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
  /// EMPTY
  /// =========================================================

  Widget _emptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 55,
            color: Colors.grey.shade400,
          ),

          const SizedBox(height: 10),

          Text(
            "No Sorting Items Found",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// =========================================================
  /// PDF BUTTON
  /// =========================================================

  Widget pdfBtn(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// =========================================================
  /// OPEN PDF
  /// =========================================================

  Future<void> openPdf(int id) async {
    try {
      /// ⚠️ અહીં Casting Sorting PDF constant હોય
      /// તો casting_receive_pdf ના બદલે એ મુકજો.

      final response = await ApiHelper().getRequestWithId(
        ApiConstants.casting_receive_pdf,
        id,
        responseType: ResponseType.bytes,
      );

      if (response != null && response.statusCode == 200) {
        final dir = await getTemporaryDirectory();

        final file = File("${dir.path}/CastingSorting_$id.pdf");

        await file.writeAsBytes(response.data);

        await OpenFile.open(file.path);
      } else {
        if (!mounted) return;

        AppMessage.error(
          context,
          response?.data?["message"]?.toString() ?? "PDF Download Failed",
        );
      }
    } catch (e) {
      debugPrint("❌ PDF ERROR => $e");

      if (!mounted) return;

      AppMessage.error(context, "PDF Download Failed");
    }
  }

  /// =========================================================
  /// STOCK TYPE DROPDOWN
  /// =========================================================

  Widget _stockTypeDropdown(
      Map<String, dynamic> item, {
        double width = 140,
        double height = 35,
      }) {
    /// ============================================
    /// STOCK TYPES
    ///
    /// KEY   = API VALUE
    /// VALUE = DISPLAY VALUE
    /// ============================================
    const Map<String, String> stockTypes = {
      "raw_material": "Raw Material",
      "finished_item": "Finished Item",
      "scrap": "Scrap",
      "repair": "Repair",
    };

    /// ============================================
    /// CURRENT SELECTED VALUE
    /// ============================================
    String? selectedValue = item["stock_type"]?.toString().trim();

    /// Empty / invalid value handle
    if (selectedValue == null ||
        selectedValue.isEmpty ||
        !stockTypes.containsKey(selectedValue)) {
      selectedValue = null;
    }

    return Container(
      width: width,
      margin: const EdgeInsets.only(right: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// ============================================
          /// LABEL
          /// ============================================
          const Text(
            "Stock Type",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 3),

          /// ============================================
          /// DROPDOWN
          /// ============================================
          SizedBox(
            height: height,
            child: DropdownButtonFormField<String>(
              value: selectedValue,

              isExpanded: true,

              dropdownColor: Colors.white,

              /// ========================================
              /// HINT
              /// ========================================
              hint: const Text(
                "Select Type",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.black45,
                  fontWeight: FontWeight.w500,
                ),
              ),

              /// ========================================
              /// SELECTED TEXT STYLE
              /// ========================================
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),

              /// ========================================
              /// ICON
              /// ========================================
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: AppColors.primaryDark,
              ),

              /// ========================================
              /// DECORATION
              /// ========================================
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white,

                contentPadding: const EdgeInsets.only(
                  left: 10,
                  right: 6,
                  top: 7,
                  bottom: 7,
                ),

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: AppColors.border),
                ),

                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: AppColors.border),
                ),

                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: AppColors.primaryDark,
                    width: 1.4,
                  ),
                ),
              ),

              /// ========================================
              /// DROPDOWN ITEMS
              /// ========================================
              items: stockTypes.entries.map((entry) {
                final String apiValue = entry.key;

                final String displayValue = entry.value;

                return DropdownMenuItem<String>(
                  value: apiValue,
                  child: Text(
                    displayValue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),

              /// ========================================
              /// SELECTED ITEM
              /// ========================================
              selectedItemBuilder: (context) {
                return stockTypes.entries.map((entry) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      entry.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList();
              },

              /// ========================================
              /// ON CHANGE
              /// ========================================
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  /// Direct API value save thase
                  item["stock_type"] = value;
                });

                debugPrint("🔥 Stock Type API Value => ${item["stock_type"]}");

                debugPrint("🔥 Stock Type Display => ${stockTypes[value]}");
              },
            ),
          ),
        ],
      ),
    );
  }

  void _resolveMissingItemIds() {
    final provider = Provider.of<ItemProvider>(context, listen: false);

    for (final item in items) {
      final dynamic id = item["item_id"];

      if (id != null &&
          id.toString().trim().isNotEmpty &&
          id.toString().toLowerCase() != "null") {
        continue;
      }

      final String name =
          item["item_name"]?.toString().trim().toLowerCase() ?? "";

      if (name.isEmpty) continue;

      for (final raw in provider.items) {
        if (raw is! Map) continue;

        final Map m = raw["item"] is Map ? raw["item"] : raw;

        if ((m["item_name"] ?? "").toString().trim().toLowerCase() == name) {
          item["item_id"] = m["id"];
          item["item"] = Map<String, dynamic>.from(m);
          break;
        }
      }
    }
  }

  Map<String, dynamic> _createBlankRow() {
    return {
      "_row_key": "row_${DateTime.now().microsecondsSinceEpoch}_new",
      "item_id": null,
      "item_name": "",
      "stock_type": "",
      "weight": "",
      "quantity": "",
    };
  }

  /// =========================================================
  /// 🔥 VOUCHER DETAILS — EXPANDABLE TAB
  /// voucher["voucher_items"] → Buch No / Item / Remarks
  /// =========================================================
  Widget _voucherDetailsTab() {
    final List<Map<String, dynamic>> voucherItems =
    (voucher["voucher_items"] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    String txt(dynamic v) {
      final s = v?.toString().trim() ?? "";
      return (s.isEmpty || s == "null") ? "-" : s;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isVoucherDetailsExpanded
              ? AppColors.primaryDark.withOpacity(0.45)
              : Colors.grey.shade300,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            /// ============== HEADER ==============
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  setState(() {
                    isVoucherDetailsExpanded = !isVoucherDetailsExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor:
                        AppColors.primaryDark.withOpacity(0.12),
                        child: const Icon(
                          Icons.receipt_long_outlined,
                          color: AppColors.primaryDark,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Voucher Details",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${voucher["voucher_no"] ?? "-"}  •  "
                                  "${voucherItems.length} Buch",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      /// COUNT BADGE
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "${voucherItems.length}",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),

                      const SizedBox(width: 6),

                      /// ARROW
                      AnimatedRotation(
                        turns: isVoucherDetailsExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            /// ============== BODY ==============
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              sizeCurve: Curves.easeInOut,
              crossFadeState: isVoucherDetailsExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: voucherItems.isEmpty
                  ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  "No voucher details found",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              )
                  : Column(
                children: [
                  Divider(height: 1, color: Colors.grey.shade200),

                  /// TABLE HEADER
                  Container(
                    color: Colors.grey.shade50,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    child: const Row(
                      children: [
                        SizedBox(width: 26),
                        SizedBox(width: 8),
                        Expanded(flex: 2, child: _VHead("Buch No")),
                        Expanded(flex: 3, child: _VHead("Item")),
                        Expanded(flex: 2, child: _VHead("Remarks")),
                      ],
                    ),
                  ),

                  /// ROWS (લાંબું list હોય તો અંદર scroll)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: voucherItems.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (_, i) {
                        final v = voucherItems[i];
                        final String remarks = txt(v["remarks"]);

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
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
                                  "${i + 1}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              /// BUCH NO
                              Expanded(
                                flex: 2,
                                child: Text(
                                  txt(v["buch_no"]),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                              ),

                              /// ITEM
                              Expanded(
                                flex: 3,
                                child: Text(
                                  txt(v["item_name"]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),

                              /// REMARKS (long-press પર પૂરું)
                              Expanded(
                                flex: 2,
                                child: Tooltip(
                                  message: remarks,
                                  triggerMode: TooltipTriggerMode.longPress,
                                  child: Text(
                                    remarks,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: remarks == "-"
                                          ? Colors.grey.shade400
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
/// Voucher Details table heading
class _VHead extends StatelessWidget {
  final String text;
  const _VHead(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Colors.black54,
      ),
    );
  }
}
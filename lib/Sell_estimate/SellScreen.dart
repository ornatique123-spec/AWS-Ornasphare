//
// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'dart:ui';
// import 'package:device_info_plus/device_info_plus.dart';
// import 'package:dio/dio.dart';
// import 'package:flutter/material.dart';
// import 'package:mobile_scanner/mobile_scanner.dart';
// import 'package:pecifician_sysytem/Dashboard/PremiumScannerScreen.dart';
// import 'package:pecifician_sysytem/User/CreteUserScreen.dart';
// import 'package:provider/provider.dart';
// import '../Api_Constant/ApiConstants.dart';
// import '../Api_Constant/api_helper.dart';
// import '../Dashboard/HomeScreen.dart';
// import '../Extra/AppColors.dart';
// import '../Extra/AppMessage.dart';
// import '../Extra/ItemProvider.dart';
// import '../Extra/PremiumSearchableDropdown.dart';
// import '../Offline Data/offline_api_helper.dart';
// import 'Sell_list.dart';
//
// class Sellscreen extends StatefulWidget {
//   final Map<String, dynamic>? userData;
//   const Sellscreen({Key? key, this.userData}) : super(key: key);
//
//   @override
//   State<Sellscreen> createState() => _SellscreenState();
// }
//
// class _SellscreenState extends State<Sellscreen> {
//   TextEditingController searchController = TextEditingController();
//   final MobileScannerController _scannerController = MobileScannerController(
//     detectionSpeed: DetectionSpeed.unrestricted,
//     formats: [BarcodeFormat.qrCode],
//   );
//   List userlist = [];
//   String? selectedItem;
//   bool _approvalManuallyCleared = false;
//   final Map<String, int> _approvalIdByQr = {};
//   String? selectedapprovalItem;
//   String? CustomerID;
//   List<Map<String, TextEditingController>> tableRows = [];
//   Timer? _huidTimer;
//   int apiRowCount = 0;
//   List customerlist = [];
//   String? selectedUser;
//   String? selectedCompanyId;
//   String? selectedUserId;
//   bool isSalePaymentExpanded = false;
//   String? selectedApprovalCompanyId;
//   String? selectedApprovalUserId;
//   DateTime? birthDate;
//   DateTime? anniversaryDate;
//   List cartItems = [];
//   Set<int> selectedItems = {}; // ✅ MUST BE int
//   List approvalAddedItems = []; // 🔥 new list
//   bool isLoading = false;
//   List<Map<String, dynamic>> items = [];
//   List<Map<String, dynamic>> allItems = [];
//   List searchResults = [];
//   List combinedItems = [];
//   List<Map<String, dynamic>> finalItems = [];
//   bool showScannerFull = false;
//   FocusNode searchFocusNode = FocusNode();
//   bool isSearchEnabled = false;
//   bool get isEditMode => widget.userData != null;
//   TextEditingController receivedAmountController = TextEditingController();
//
//   TextEditingController paymentRefController = TextEditingController();
//
//   TextEditingController pendingAmountController = TextEditingController(
//     text: "0.00",
//   );
//   TextEditingController remarksController = TextEditingController();
//   TextEditingController recived_amount_Controller = TextEditingController();
//   TextEditingController payment_ref_Controller = TextEditingController();
//   TextEditingController payment_pending_Controller = TextEditingController();
//   TextEditingController add_payment_Controller = TextEditingController();
//   String? selectedPaymentMode;
//   double cashBalance = 0.0;
//   double goldBalance = 0.0;
//   double silverBalance = 0.0;
//   bool showBalance = false;
//   /// =========================================================
//   /// 🔥 EDIT MODE ADVANCE USAGE (loadEditData API response mathi)
//   /// =========================================================
//   double editCashBalance = 0.0;
//   double editCashPayableTotal = 0.0;
//   double editCashPending = 0.0;
//
//   double editSilverOpening = 0.0;
//   double editSilverUsed = 0.0;
//   double editSilverClosing = 0.0;
//   double editSilverDebit = 0.0;
//   double editSilverCredit = 0.0;
//
//   double editGoldFineRequired = 0.0;
//   double editSilverFineRequired = 0.0;
//   double editOtherFineRequired = 0.0;
//   bool customerChangedByUser = false;
//   bool useSilverBalance = false; // ✅ Adjust Fine Balance checkbox
//
//   bool get _useEditBalance => isEditMode && !customerChangedByUser;
//
//   String? deviceId;
//
//   /// Aa screen khule tyare j ek vaar generate thay (session unique)
//   String? voucherSessionId;
//   @override
//   void initState() {
//     // TODO: implement initState
//     super.initState();
//     Future.microtask(() {
//       Provider.of<ItemProvider>(context, listen: false).refreshItems();
//       Provider.of<ItemProvider>(context, listen: false).refreshCustomers();
//       Provider.of<ItemProvider>(context, listen: false).refreshapprovalCustomers();
//     });
//     /// 🔥 voucher_session_id — screen khule tyare j ek vaar generate
//     voucherSessionId = 'APP-${DateTime.now().millisecondsSinceEpoch}';
//     if (isEditMode) {
//       final user = widget.userData!;
//       selectedItem = user["customer_id"]?.toString();
//       selectedUserId = user["customer_id"]?.toString();
//       selectedapprovalItem ??= selectedItem;
//
//       selectedApprovalCompanyId ??= selectedCompanyId;
//
//       selectedApprovalUserId ??= selectedUserId;
//       loadEditData(user["id"]);
//     }
//
//
//
//     //getCartItems();
//   }
//
//   List<Map<String, dynamic>> uniqueItems = [];
//   // Future<void> loadEditData(int id) async {
//   //   final response = await ApiHelper().getRequestWithId(
//   //     ApiConstants.sale_item_update,
//   //     id,
//   //     //responseType: ResponseType.bytes,
//   //   );
//   //
//   //   print("DETAIL API => ${response?.data}");
//   //
//   //   if (response != null && response.statusCode == 200) {
//   //     final data = response.data["data"];
//   //
//   //     List apiItems = data["sale_items"] ?? [];
//   //     AppMessage.success(
//   //       context,
//   //       data["message"] ?? "Data Loaded Successfully",
//   //     );
//   //     setState(() {
//   //       items.clear();
//   //       uniqueItems.clear(); // 🔥 ADD THIS
//   //       controllers.clear();
//   //
//   //       // ✅ Payment Fields Load કરો
//   //       recived_amount_Controller.text =
//   //           data["received_amount"]?.toString() ?? "";
//   //
//   //       // add_payment_Controller.text =
//   //       //     data["received_amount"]?.toString() ?? "";
//   //
//   //       payment_ref_Controller.text =
//   //           data["payment_reference"]?.toString() ?? "";
//   //
//   //       payment_pending_Controller.text =
//   //           data["payment_note"]?.toString() ?? "";
//   //
//   //       selectedPaymentMode = data["payment_mode"]?.toString();
//   //
//   //       // ✅ Remarks Load કરો
//   //       remarksController.text = data["remarks"]?.toString() ?? "";
//   //
//   //       for (var e in apiItems) {
//   //         final itemData = {
//   //           "id": e['itemset']["id"],
//   //           "item_name": e['itemset']['item']["item_name"] ?? "",
//   //           "huid": e["HUID"] ?? "",
//   //           "qr_code": e['itemset']["qr_code"] ?? "",
//   //           "gross_weight": e["gross_weight"] ?? "",
//   //           "other_weight": e["other_weight"] ?? "",
//   //           "net_weight": e["net_weight"] ?? "",
//   //           "purity": e["purity"] ?? "",
//   //           "waste": e["waste_percent"] ?? "",
//   //           "net_purity": e["net_purity"] ?? "",
//   //           "fine_weight": e["fine_weight"] ?? "",
//   //           "metal_rate": e["metal_rate"] ?? "",
//   //           "metal_amount": e["metal_amount"] ?? "",
//   //           "labour_rate": e["labour_rate"] ?? "",
//   //           "labour_amount": e["labour_amount"] ?? "",
//   //           "other_amount": e["other_amount"] ?? "",
//   //           "total_amount": e["total_amount"] ?? "",
//   //           "expanded": false,
//   //         };
//   //
//   //         //items.add(itemData); // 🔹 for calculation / controller
//   //         items.insert(
//   //           0,
//   //           itemData,
//   //         ); // આનાથી નવી આઈટમ લિસ્ટમાં પહેલા નંબર પર આવશે
//   //         uniqueItems.add(itemData); // 🔹 for UI display
//   //       }
//   //     });
//   //   }
//   // }
//
//   Future<void> loadEditData(int id) async {
//     final response = await ApiHelper().getRequestWithId(
//       ApiConstants.sale_item_update,
//       id,
//     );
//
//     print("DETAIL API => ${response?.data}");
//
//     if (response != null && response.statusCode == 200) {
//       final data = response.data["data"];
//
//       final List apiItems = data["sale_items"] ?? [];
//
//       AppMessage.success(
//         context,
//         data["message"] ?? "Data Loaded Successfully",
//       );
//
//       setState(() {
//         /// =========================================================
//         /// CLEAR OLD DATA
//         /// =========================================================
//
//         items.clear();
//         uniqueItems.clear();
//         approvalAddedItems.clear();
//         finalItems.clear();
//         controllers.clear();
//
//         /// =========================================================
//         /// PAYMENT
//         /// =========================================================
//
//         recived_amount_Controller.text =
//             data["received_amount"]?.toString() ?? "";
//
//         payment_ref_Controller.text =
//             data["payment_reference"]?.toString() ?? "";
//
//         payment_pending_Controller.text =
//             data["payment_note"]?.toString() ?? "";
//
//         selectedPaymentMode = data["payment_mode"]?.toString();
//
//         remarksController.text = data["remarks"]?.toString() ?? "";
//
//         final dynamic usb = data["use_silver_balance"];
//         useSilverBalance = usb == true ||
//             usb == 1 ||
//             usb.toString() == "1" ||
//             usb.toString() == "true";
//
//         /// =========================================================
//         /// 🔥 EDIT MODE ADVANCE USAGE SET
//         /// =========================================================
//         final Map<String, dynamic> advanceUsage =
//         (data["advance_usage"] is Map)
//             ? Map<String, dynamic>.from(data["advance_usage"])
//             : {};
//
//         double _d(dynamic v) => double.tryParse(v?.toString() ?? "0") ?? 0;
//
//         editCashBalance      = _d(advanceUsage["cash_balance"]);
//         editCashPayableTotal = _d(advanceUsage["cash_payable_total"]);
//         editCashPending      = _d(advanceUsage["cash_pending"]);
//
//         editSilverOpening = _d(advanceUsage["silver_opening"]);
//         editSilverUsed    = _d(advanceUsage["silver_debit"]);
//         editSilverClosing = _d(advanceUsage["silver_closing"]);
//         editSilverDebit   = _d(advanceUsage["silver_debit"]);
//         editSilverCredit  = _d(advanceUsage["silver_credit"]);
//
//         final Map<String, dynamic> fineRequired =
//         (advanceUsage["fine_required"] is Map)
//             ? Map<String, dynamic>.from(advanceUsage["fine_required"])
//             : {};
//
//         editGoldFineRequired   = _d(fineRequired["gold"]);
//         editSilverFineRequired = _d(fineRequired["silver"]);
//         editOtherFineRequired  = _d(fineRequired["other"]);
//
//         /// =========================================================
//         /// SALE ITEMS
//         /// =========================================================
//
//         for (var e in apiItems) {
//           /// =======================================================
//           /// ITEMSET
//           /// =======================================================
//
//           final dynamic itemset = e["itemset"];
//
//           final bool hasItemset =
//               itemset != null && itemset is Map && itemset["id"] != null;
//
//           /// =======================================================
//           /// MASTER ITEM
//           ///
//           /// itemset null હોય ત્યારે:
//           /// e["item"] / product / item_master માંથી data લેવાનું
//           /// =======================================================
//
//           final dynamic masterItem =
//               e["item"] ?? e["product"] ?? e["item_master"];
//
//           /// =======================================================
//           /// ITEMSET ID
//           /// =======================================================
//
//           final dynamic itemsetId = hasItemset
//               ? itemset["id"]
//               : e["itemset_id"];
//
//           /// =======================================================
//           /// ITEM ID
//           ///
//           /// itemset null હોય તો product/master item id લેવાશે
//           /// =======================================================
//
//           final dynamic itemId =
//               e["item_id"] ??
//                   (masterItem is Map ? masterItem["id"] : null) ??
//                   (hasItemset && itemset["item"] is Map
//                       ? itemset["item"]["id"]
//                       : null);
//
//           /// =======================================================
//           /// 🔥 SAVED MANUAL ITEM
//           ///
//           /// itemset નથી
//           /// પરંતુ item_id છે
//           /// એટલે dropdownમાંથી select કરીને save થયેલો item
//           /// =======================================================
//
//           final bool isSavedManualItem = itemsetId == null && itemId != null;
//
//           /// =======================================================
//           /// ITEM NAME
//           /// =======================================================
//
//           String itemName = "";
//
//           if (hasItemset) {
//             if (itemset["item"] is Map) {
//               itemName = itemset["item"]["item_name"]?.toString() ?? "";
//             }
//           } else {
//             if (masterItem is Map) {
//               itemName = masterItem["item_name"]?.toString() ?? "";
//             }
//
//             if (itemName.trim().isEmpty) {
//               itemName = e["item_name"]?.toString() ?? "";
//             }
//           }
//
//           /// =======================================================
//           /// QR CODE
//           /// =======================================================
//
//           final String qrCode = hasItemset
//               ? itemset["qr_code"]?.toString() ?? ""
//               : e["qr_code"]?.toString() ?? "";
//
//           /// =======================================================
//           /// MASTER ITEM EXTRA DATA
//           /// =======================================================
//
//           dynamic getMasterValue(String key) {
//             if (masterItem is Map && masterItem[key] != null) {
//               return masterItem[key];
//             }
//
//             if (hasItemset &&
//                 itemset["item"] is Map &&
//                 itemset["item"][key] != null) {
//               return itemset["item"][key];
//             }
//
//             return e[key];
//           }
//
//           /// =======================================================
//           /// CREATE UI ITEM
//           /// =======================================================
//
//           final Map<String, dynamic> itemData = {
//             /// Sale Item DB ID
//             "sale_item_id": e["id"],
//
//             /// =====================================================
//             /// IDs
//             /// =====================================================
//             "id": itemsetId ?? itemId,
//
//             "itemset_id": itemsetId,
//
//             "item_id": itemId,
//
//             "approval_item_id": e["approval_item_id"],
//
//             /// =====================================================
//             /// ITEM
//             /// =====================================================
//             "item": itemName,
//
//             "item_name": itemName,
//
//             "item_code": getMasterValue("item_code"),
//
//             "metal": getMasterValue("metal"),
//
//             "huid": e["HUID"]?.toString() ?? e["huid"]?.toString() ?? "",
//
//             "qr_code": qrCode,
//
//             /// =====================================================
//             /// WEIGHT
//             /// =====================================================
//             "gross_weight": e["gross_weight"]?.toString() ?? "0",
//
//             "other_weight": e["other_weight"]?.toString() ?? "0",
//
//             "net_weight": e["net_weight"]?.toString() ?? "0",
//
//             /// =====================================================
//             /// PURITY
//             /// =====================================================
//             "purity": e["purity"]?.toString() ?? "0",
//
//             "waste":
//             e["waste_percent"]?.toString() ?? e["waste"]?.toString() ?? "0",
//
//             "outward_carat": getMasterValue("outward_carat")?.toString() ?? "0",
//
//             "outward_purity":
//             getMasterValue("outward_purity")?.toString() ?? "0",
//
//             "net_purity": e["net_purity"]?.toString() ?? "0",
//
//             "fine_weight": e["fine_weight"]?.toString() ?? "0",
//
//             /// =====================================================
//             /// METAL
//             /// =====================================================
//             "metal_formula": getMasterValue("metal_formula"),
//
//             "metal_rate": e["metal_rate"]?.toString() ?? "0",
//
//             "metal_amount": e["metal_amount"]?.toString() ?? "0",
//
//             /// =====================================================
//             /// LABOUR
//             /// =====================================================
//             "labour_type": getMasterValue("labour_type"),
//
//             "labour_unit": getMasterValue("labour_unit"),
//
//             "labour_rate":
//             e["labour_rate"]?.toString() ??
//                 getMasterValue("labour_rate")?.toString() ??
//                 "0",
//
//             "labour_amount": e["labour_amount"]?.toString() ?? "0",
//
//             /// =====================================================
//             /// QTY / REMARKS
//             /// =====================================================
//             "qty": e["qty"]?.toString() ?? "1",
//
//             "remarks": e["remarks"]?.toString() ?? "",
//
//             /// =====================================================
//             /// OTHER
//             /// =====================================================
//             "other_amount": e["other_amount"]?.toString() ?? "0",
//
//             "total_amount": e["total_amount"]?.toString() ?? "0",
//
//             /// =====================================================
//             /// HSN
//             /// =====================================================
//             "hsn": getMasterValue("hsn"),
//
//             "sac_code": getMasterValue("sac_code"),
//
//             "export_hsn": getMasterValue("export_hsn"),
//
//             /// =====================================================
//             /// 🔥 UI FLAGS
//             /// =====================================================
//             "expanded": false,
//
//             /// 🔥 IMPORTANT
//             ///
//             /// Edit API માંથી આવેલો કોઈપણ saved item
//             /// dropdown તરીકે બતાવવાનો નથી.
//             ///
//             /// itemset હોય → false
//             /// item_id હોય → false
//             ///
//             /// Dropdown ફક્ત createApprovalBlankItemRow()
//             /// માટે આવશે.
//             "show_item_dropdown": false,
//
//             /// Already saved એટલે fresh નથી
//             "is_fresh": false,
//
//             /// itemset null + item_id available
//             /// એટલે saved manual/master item
//             "is_manual_item": isSavedManualItem,
//
//             /// Optional identification
//             "is_saved_item": true,
//           };
//
//           /// =======================================================
//           /// CONTROLLERS
//           /// =======================================================
//
//           setController(itemData, "gross_weight", itemData["gross_weight"]);
//
//           setController(itemData, "other_weight", itemData["other_weight"]);
//
//           setController(itemData, "net_weight", itemData["net_weight"]);
//
//           setController(itemData, "purity", itemData["purity"]);
//
//           setController(itemData, "waste", itemData["waste"]);
//
//           setController(itemData, "outward_carat", itemData["outward_carat"]);
//
//           setController(itemData, "net_purity", itemData["net_purity"]);
//
//           setController(itemData, "fine_weight", itemData["fine_weight"]);
//
//           setController(itemData, "metal_rate", itemData["metal_rate"]);
//
//           setController(itemData, "metal_amount", itemData["metal_amount"]);
//
//           setController(itemData, "labour_rate", itemData["labour_rate"]);
//
//           setController(itemData, "labour_amount", itemData["labour_amount"]);
//
//           setController(itemData, "qty", itemData["qty"]);
//
//           setController(itemData, "remarks", itemData["remarks"]);
//
//           setController(itemData, "other_amount", itemData["other_amount"]);
//
//           setController(itemData, "total_amount", itemData["total_amount"]);
//
//           /// =======================================================
//           /// ADD SAVED ITEM
//           /// =======================================================
//
//           items.insert(0, itemData);
//
//           uniqueItems.add(itemData);
//
//           debugPrint(
//             "EDIT ITEM => "
//                 "itemset_id=$itemsetId | "
//                 "item_id=$itemId | "
//                 "manual=$isSavedManualItem | "
//                 "dropdown=${itemData["show_item_dropdown"]} | "
//                 "name=$itemName",
//           );
//         }
//
//         /// =========================================================
//         /// 🔥 EDIT SCREEN MA NEW FRESH ROW
//         ///
//         /// Saved items ઉપર dropdown નહીં આવે.
//         /// ફક્ત આ નવી row માં dropdown આવશે.
//         /// =========================================================
//
//         // final Map<String, dynamic> freshRow = createApprovalBlankItemRow();
//         //
//         // approvalAddedItems.add(freshRow);
//
//         /// =========================================================
//         /// FINAL ITEMS
//         /// =========================================================
//
//         updateFinalItems();
//       });
//     }
//   }
//
//   int _itemOrderCounter = 0;
//   final Map<String, int> _itemOrderMap = {};
//
//   String? _orderKeyFor(Map item) {
//     final dynamic key =
//         item["approval_item_id"] ?? item["id"] ?? item["code"];
//     if (key == null) return null;
//     return key.toString();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     final height = size.height;
//     final width = size.width;
//     final isMobile = width < 600;
//
//     /// 🔥 UNIFIED LIST: Combine all sources
//     List combinedItemsList = [
//       ...items, // From Manual Search
//       ...approvalAddedItems, // From Return Approval Dialog
//       ...cartItems.map((e) {
//         final itemset = e["itemset"] ?? {};
//         final itemData = itemset["item"] ?? {};
//
//         /// =========================================================
//         /// 🔥 FIX: FULL ITEM SPREAD
//         ///
//         /// Pehla ahi ek NAVU trimmed Map banaviyu hatu jema fakt
//         /// gross/net/other/purity j hata — metal_rate, metal_amount,
//         /// labour_rate, labour_amount, waste, net_purity, fine_weight,
//         /// other_amount, total_amount BADHU MISSING hatu.
//         ///
//         /// calculateTotals() aa j list par loop kari ne summary
//         /// banave che, etle Scan items na totals hammesha 0 ganta
//         /// hata.
//         ///
//         /// Have `...e` spread kari ne cartItems na BADHA fields
//         /// (je getCartItems() + calculateItem() thi already sachi
//         /// rite calculate thai chuke che) as-is pass thay che.
//         /// =========================================================
//         return {
//           ...e,
//           "name": itemData["item_name"] ?? e["item_name"] ?? "",
//           "code":
//           itemset["qr_code"] ??
//               itemset["HUID"] ??
//               e["qr_code"] ??
//               e["huid"] ??
//               "-",
//           "source": "sale",
//           "expanded": false,
//         };
//       }).toList(),
//     ];
//
// // ============================================================
// // 🔥 DEDUPLICATE + RECENCY-BASED SORT
// // (Navu scan/search/approval item automatically TOP ma aave)
// // ============================================================
//
//     final Map<String, dynamic> dedupMap = {};
//
//     for (var item in combinedItemsList) {
//       final String? key = _orderKeyFor(item);
//
//       if (key == null || key.isEmpty) continue;
//
//       dedupMap[key] = item;
//
//       /// 🔥 Navi key hoy (pehli vaar dekhay) to next sequence assign karo.
//       /// Already assigned hoy (existing/old item) to same number j rahe.
//       _itemOrderMap.putIfAbsent(key, () => _itemOrderCounter++);
//     }
//
//     final List<MapEntry<String, dynamic>> sortedEntries =
//     dedupMap.entries.toList()
//       ..sort((a, b) {
//         final int orderA = _itemOrderMap[a.key] ?? 0;
//         final int orderB = _itemOrderMap[b.key] ?? 0;
//         return orderB.compareTo(orderA); // 🔥 DESCENDING → naya top ma
//       });
//
//     /// =========================================================
//     /// 🔥 FIX: CLASS-LEVEL uniqueItems DIRECT ASSIGN
//     ///
//     /// Pehla ahi "final uniqueItems = ..." local variable banti
//     /// hati, je class-level `uniqueItems` field ne SHADOW karti
//     /// hati. calculateTotals() ane buildSummaryRow() (je build()
//     /// ni bahar j alag methods che) hammesha class-level field j
//     /// vapre che — je fakt loadEditData() ma set thatu, Scan/
//     /// Manual/Approval thi item add thay tyare kadi update nathi
//     /// thatu. Etle Summary Total/Metal Amt/Labour Amt hammesha
//     /// stale/0 aavtu hatu.
//     ///
//     /// Have "final" hatavi didhu, seedhu class field assign
//     /// karie chiye — jethi calculateTotals() ne pan taju,
//     /// dedupe+sorted (Scan+Manual+Approval badhu) data male.
//     /// =========================================================
//     uniqueItems = sortedEntries
//         .map((e) => (e.value as Map).cast<String, dynamic>())
//         .toList();
//
//     return PopScope(
//       canPop: false,
//       onPopInvokedWithResult: (didPop, result) {
//         if (didPop) return;
//
//         Navigator.pop(context,true);
//       },
//       child: Scaffold(
//         // resizeToAvoidBottomInset: false, // ⭐ IMPORTANT FIX
//         backgroundColor: AppColors.white,
//         body: Stack(
//           children: [
//             /// ✅ Main Content
//             Column(
//               children: [
//                 /// IMPORTANT: top padding space leave karvu (AppBar mate)
//                 SizedBox(height: MediaQuery.of(context).padding.top + 40),
//                 Expanded(
//                   child: showScannerFull
//                       ? Column(
//                     children: [
//                       const SizedBox(height: 10),
//
//                       Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 10,
//                           vertical: 5,
//                         ),
//                         child: Consumer<ItemProvider>(
//                           builder: (context, provider, child) {
//                             final customers = provider.customers;
//
//                             return DropdownButtonFormField<String>(
//                               value:
//                               (selectedItem != null &&
//                                   customers.any(
//                                         (e) =>
//                                     e["id"].toString() ==
//                                         selectedItem,
//                                   ))
//                                   ? selectedItem
//                                   : null,
//
//                               icon: const Icon(
//                                 Icons.keyboard_arrow_down,
//                                 color: Colors.black,
//                               ),
//                               dropdownColor: Colors.white,
//                               hint: Text(
//                                 "Select Customer",
//                                 style: TextStyle(
//                                   color: Colors.grey.shade600,
//                                 ),
//                               ),
//                               style: const TextStyle(
//                                 color: Colors.black,
//                                 fontSize: 14,
//                               ),
//
//                               decoration: InputDecoration(
//                                 filled: true,
//                                 fillColor: Colors.white,
//
//                                 contentPadding:
//                                 const EdgeInsets.symmetric(
//                                   horizontal: 12,
//                                   vertical: 0,
//                                 ),
//
//                                 border: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                   borderSide: BorderSide(
//                                     color: Colors.grey.shade300,
//                                   ),
//                                 ),
//
//                                 enabledBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                   borderSide: BorderSide(
//                                     color: Colors.grey.shade300,
//                                   ),
//                                 ),
//
//                                 focusedBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                   borderSide: BorderSide(
//                                     color: Colors.grey.shade300,
//                                   ),
//                                 ),
//                               ),
//
//                               items: customers
//                                   .map<DropdownMenuItem<String>>((item) {
//                                 return DropdownMenuItem<String>(
//                                   value: item["id"].toString(),
//                                   child: Text(
//                                     item["name"] ?? "",
//                                     style: const TextStyle(
//                                       color: Colors.black,
//                                     ),
//                                   ),
//                                 );
//                               })
//                                   .toList(),
//
//                               onChanged: (value) {
//                                 setState(() {
//                                   selectedItem = value;
//
//                                   final selectedData = customers
//                                       .firstWhere(
//                                         (user) =>
//                                     user["id"].toString() ==
//                                         value,
//                                     orElse: () => {},
//                                   );
//                                   provider.setCustomerAdvance(
//                                     selectedData,
//                                   );
//                                   if (selectedData.isNotEmpty) {
//                                     selectedCompanyId =
//                                         selectedData["company_id"]
//                                             ?.toString();
//                                     selectedUserId = selectedData["id"]
//                                         ?.toString();
//
//                                     print(
//                                       "Selected Company ID: $selectedCompanyId",
//                                     );
//                                     print(
//                                       "Selected User ID: $selectedUserId",
//                                     );
//                                   } else {
//                                     print("⚠️ Customer not found");
//                                   }
//                                 });
//                               },
//                             );
//                           },
//                         ),
//                       ),
//                       const SizedBox(height: 10),
//
//                       /// 🔥 FULL SCANNER
//                       Center(
//                         child: Stack(
//                           children: [
//                             /// 🔥 SCANNER BOX
//                             Container(
//                               height: 150,
//                               width: 150,
//                               decoration: BoxDecoration(
//                                 borderRadius: BorderRadius.circular(16),
//                                 color: Colors.black,
//                                 boxShadow: [
//                                   BoxShadow(
//                                     color: Colors.greenAccent.withOpacity(
//                                       0.4,
//                                     ),
//                                     blurRadius: 20,
//                                   ),
//                                 ],
//                               ),
//                               child: Stack(
//                                 children: [
//                                   _buildScannerSection(),
//                                   _ScannerLineAnimation(),
//                                 ],
//                               ),
//                             ),
//
//                             /// ❌ CLOSE ICON (TOP RIGHT)
//                             Positioned(
//                               top: 6,
//                               right: 6,
//                               child: GestureDetector(
//                                 onTap: () {
//                                   setState(() {
//                                     showScannerFull = false;
//                                   });
//                                 },
//                                 child: Container(
//                                   padding: const EdgeInsets.all(4),
//                                   decoration: BoxDecoration(
//                                     color: Colors.black.withOpacity(0.5),
//                                     shape: BoxShape.circle,
//                                     border: Border.all(
//                                       color: Colors.white,
//                                       width: 1.5,
//                                     ),
//                                   ),
//
//                                   child: const Icon(
//                                     Icons.close,
//                                     size: 10,
//                                     color: Colors.white,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//
//                       const SizedBox(height: 5),
//
//                       Container(
//                         margin: const EdgeInsets.only(top: 10),
//                         width: double.infinity,
//                         height: 2,
//                         decoration: BoxDecoration(
//                           gradient: LinearGradient(
//                             colors: [
//                               AppColors.primaryDark.withOpacity(0.1),
//                               AppColors.primaryDark,
//                               AppColors.secondaryDark.withOpacity(0.4),
//                               AppColors.primaryDark.withOpacity(0.1),
//                             ],
//                           ),
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                       ),
//
//                       /// 🔽 LIST
//                       Expanded(
//                         child: uniqueItems.isEmpty
//                             ? const Center(child: Text("No Data Added"))
//                             : ListView.builder(
//                           padding: EdgeInsets.fromLTRB(
//                             12,
//                             12,
//                             12,
//                             12,
//                           ),
//                           itemCount: uniqueItems.length,
//                           itemBuilder: (context, index) {
//                             return approvalItemCard(
//                               uniqueItems[index],
//                               index,
//                               uniqueItems.length,
//                             );
//                           },
//                         ),
//                       ),
//                     ],
//                   )
//                       : Column(
//                     children: [
//                       Expanded(
//                         child: CustomScrollView(
//                           physics: const BouncingScrollPhysics(),
//                           slivers: [
//                             // filterWidget + divider
//                             SliverToBoxAdapter(
//                               child: Column(
//                                 children: [
//                                   filterWidget(),
//                                   Container(
//                                     margin: const EdgeInsets.only(top: 5),
//                                     width: double.infinity,
//                                     height: 2,
//                                     decoration: BoxDecoration(
//                                       gradient: LinearGradient(
//                                         colors: [
//                                           AppColors.primaryDark
//                                               .withOpacity(0.1),
//                                           AppColors.primaryDark,
//                                           AppColors.secondaryDark
//                                               .withOpacity(0.4),
//                                           AppColors.primaryDark
//                                               .withOpacity(0.1),
//                                         ],
//                                       ),
//                                       borderRadius: BorderRadius.circular(
//                                         10,
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//
//                             // Empty state
//                             if (uniqueItems.isEmpty)
//                               const SliverToBoxAdapter(
//                                 child: Padding(
//                                   padding: EdgeInsets.only(top: 50),
//                                   child: Center(
//                                     child: Text(
//                                       "No Data Found",
//                                       style: TextStyle(
//                                         fontSize: 16,
//                                         fontWeight: FontWeight.w500,
//                                         color: Colors.grey,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               )
//                             else
//                             // ✅ Real lazy-loading list — no shrinkWrap, no NeverScrollableScrollPhysics
//                               SliverPadding(
//                                 padding: const EdgeInsets.fromLTRB(
//                                   0,
//                                   12,
//                                   0,
//                                   0,
//                                 ),
//                                 sliver: SliverList(
//                                   delegate: SliverChildBuilderDelegate((
//                                       context,
//                                       index,
//                                       ) {
//                                     return approvalItemCard(
//                                       uniqueItems[index],
//                                       index,
//                                       uniqueItems.length,
//                                     );
//                                   }, childCount: uniqueItems.length),
//                                 ),
//                               ),
//
//                             // Bottom spacing (Save button jetli height)
//                             const SliverToBoxAdapter(
//                               child: SizedBox(height: 80),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//
//                 /// 🔥 BOTTOM SUMMARY
//                 buildSummaryRow(),
//
//                 /// Bottom Button
//                 InkWell(
//                   onTap: () {
//                     if (isEditMode) {
//                       savefinalizeBulkItemsUpdate();
//                     } else {
//                       savefinalizeBulkItems();
//                     }
//                   },
//                   borderRadius: BorderRadius.circular(10),
//                   child: Padding(
//                     padding: const EdgeInsets.only(bottom: 8.0),
//                     child: Container(
//                       margin: const EdgeInsets.all(16),
//                       padding: const EdgeInsets.symmetric(vertical: 14),
//                       decoration: BoxDecoration(
//                         gradient: LinearGradient(
//                           colors: [
//                             AppColors.primaryDark.withOpacity(0.7),
//                             AppColors.secondaryDark.withOpacity(0.7),
//                           ],
//                         ),
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       child: Center(
//                         child: Text(
//                           isEditMode ? "Update Sale" : "Save Sale",
//                           style: TextStyle(
//                             fontWeight: FontWeight.bold,
//                             color: Colors.white,
//                             fontSize: 16,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//
//             /// ✅ APPBAR (OVERLAY)
//             Positioned(
//               top: 0,
//               left: 0,
//               right: 0,
//               child: Container(
//                 padding: const EdgeInsets.only(
//                   top: 30,
//                   left: 16,
//                   right: 16,
//                   bottom: 16,
//                 ),
//                 color: AppColors.white,
//                 child: SizedBox(
//                   height: isMobile ? 36 : 40,
//                   child: Stack(
//                     alignment: Alignment.center,
//                     children: [
//                       const Center(
//                         child: Text(
//                           "Create Sale",
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                           style: TextStyle(
//                             color: Colors.black,
//                             fontSize: 16,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//
//                       Align(
//                         alignment: Alignment.centerLeft,
//                         child: InkWell(
//                           onTap: () {
//                             FocusManager.instance.primaryFocus?.unfocus();
//
//                             Navigator.pop(context,true);
//                           },
//                           borderRadius: BorderRadius.circular(8),
//                           child: Container(
//                             width: isMobile ? 36 : 40,
//                             height: isMobile ? 36 : 40,
//                             alignment: Alignment.center,
//                             decoration: BoxDecoration(
//                               color: AppColors.primaryDark,
//                               borderRadius: BorderRadius.circular(8),
//                               border: Border.all(color: Colors.grey.shade300),
//                             ),
//                             child: Icon(
//                               Icons.arrow_back_rounded,
//                               color: Colors.white,
//                               size: isMobile ? 20 : 22,
//                             ),
//                           ),
//                         ),
//                       ),
//
//                       Align(
//                         alignment: Alignment.centerRight,
//                         child: Tooltip(
//                           message: "Add Label From Approval",
//                           child: InkWell(
//                             onTap: () {
//                               FocusManager.instance.primaryFocus?.unfocus();
//
//                               if (selectedapprovalItem == null ||
//                                   selectedapprovalItem
//                                       .toString()
//                                       .trim()
//                                       .isEmpty) {
//                                 ScaffoldMessenger.of(context)
//                                   ..hideCurrentSnackBar()
//                                   ..showSnackBar(
//                                     SnackBar(
//                                       content: const Row(
//                                         children: [
//                                           Icon(
//                                             Icons.info_outline_rounded,
//                                             color: Colors.white,
//                                             size: 19,
//                                           ),
//                                           SizedBox(width: 8),
//                                           Expanded(
//                                             child: Text(
//                                               "Please select approval person first",
//                                               style: TextStyle(
//                                                 color: Colors.white,
//                                                 fontSize: 13,
//                                                 fontWeight: FontWeight.w500,
//                                               ),
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                       backgroundColor: Colors.red.shade700,
//                                       behavior: SnackBarBehavior.floating,
//                                       duration: const Duration(seconds: 2),
//                                       margin: const EdgeInsets.all(12),
//                                       shape: RoundedRectangleBorder(
//                                         borderRadius: BorderRadius.circular(8),
//                                       ),
//                                     ),
//                                   );
//
//                                 return;
//                               }
//
//                               getApprovalDetails(
//                                 int.parse(selectedapprovalItem.toString()),
//                               );
//                             },
//                             borderRadius: BorderRadius.circular(8),
//                             child: Container(
//                               width: isMobile ? 36 : 40,
//                               height: isMobile ? 36 : 40,
//                               alignment: Alignment.center,
//                               decoration: BoxDecoration(
//                                 color: AppColors.primaryDark.withOpacity(0.08),
//                                 borderRadius: BorderRadius.circular(8),
//                                 border: Border.all(color: AppColors.border),
//                               ),
//                               child: Icon(
//                                 Icons.add_rounded,
//                                 size: isMobile ? 21 : 23,
//                                 color: AppColors.primaryDark,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Future<void> saveBulkItems() async {
//     if (selectedItem == null) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text("Please select item")));
//       return;
//     }
//
//     List<Map<String, dynamic>> rows = [];
//
//     for (int i = apiRowCount; i < tableRows.length; i++) {
//       var row = tableRows[i];
//
//       if (row["gross"]!.text.isEmpty &&
//           row["net"]!.text.isEmpty &&
//           row["size"]!.text.isEmpty &&
//           row["huid"]!.text.isEmpty) {
//         continue;
//       }
//
//       rows.add({
//         "gross_weight": double.tryParse(row["gross"]!.text),
//         "other": double.tryParse(row["other"]!.text),
//         "net_weight": double.tryParse(row["net"]!.text),
//         "labour_rate": double.tryParse(row["labourRate"]!.text),
//         "labour_amount": double.tryParse(row["labourAmount"]!.text),
//         "purity": double.tryParse(row["labourAmount"]!.text),
//         "size": int.tryParse(row["size"]!.text),
//         "HUID": row["huid"]!.text.isNotEmpty ? row["huid"]!.text : null,
//       });
//     }
//
//     if (rows.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Please enter at least one row")),
//       );
//       return;
//     }
//
//     Map<String, dynamic> body = {
//       "item_id": int.parse(selectedItem!),
//       "rows": rows,
//     };
//
//     print("📤 REQUEST BODY: $body");
//
//     final response = await ApiHelper().postRequest(
//       ApiConstants.multiple_items_label_configs, // 👈 your endpoint
//       body,
//     );
//
//     if (response != null && response.statusCode == 200) {
//       AppMessage.success(
//         context,
//         response.data["message"] ?? "Data Saved Successfully",
//       );
//     } else {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text("Failed to Save Data")));
//     }
//   }
//
//   Future<void> savefinalizeBulkItems() async {
//     if (selectedUserId == null) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text("Please select Customer")));
//       return;
//     }
//
//     /// ============================================================
//     /// FIRST PREPARE FINAL ITEMS
//     /// ============================================================
//
//     updateFinalItems();
//
//     final List<Map<String, dynamic>> allItemsToSave = finalItems
//         .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
//         .toList();
//
//     if (allItemsToSave.isEmpty) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text("No items to save")));
//       return;
//     }
//
//     /// ============================================================
//     /// DEBUG EACH ITEM
//     /// ============================================================
//
//     // for (int i = 0; i < allItemsToSave.length; i++) {
//     //   debugPrint(
//     //     "🔥 SAVE ITEM ${i + 1} => ${allItemsToSave[i]}",
//     //   );
//     // }
//
//     /// ============================================================
//     /// BODY
//     /// ============================================================
//
//     final Map<String, dynamic> body = {
//       "customer_id": int.parse(selectedUserId!),
//       if (_approvalPersonId != null) "approval_customer_id": _approvalPersonId,
//       "items": allItemsToSave,
//
//       "received_amount": recived_amount_Controller.text.trim().isEmpty
//           ? null
//           : double.tryParse(recived_amount_Controller.text.trim()),
//
//       "payment_mode": selectedPaymentMode,
//
//       "payment_reference": payment_ref_Controller.text.trim(),
//
//       "payment_note": payment_pending_Controller.text.trim().isEmpty
//           ? null
//           : payment_pending_Controller.text.trim(),
//
//       "remarks": remarksController.text.trim(),
//       "use_silver_balance": useSilverBalance,
//     };
//
//     // debugPrint(
//     //   "==============================================",
//     // );
//     //
//     // debugPrint(
//     //   "📤 SALES REQUEST BODY",
//     // );
//     //
//     // debugPrint(
//     //   body.toString(),
//     // );
//     //
//     // debugPrint(
//     //   "==============================================",
//     // );
//
//     /// ============================================================
//     /// API
//     /// ============================================================
//
//     final response = await OfflineApiHelper.instance.postRequest(
//       ApiConstants.sales_store,
//       body,
//     );
//
//     /// ============================================================
//     /// RESPONSE
//     /// ============================================================
//
//     if (response != null &&
//         (response.statusCode == 200 || response.statusCode == 202)) {
//       if (response.statusCode == 202) {
//         AppMessage.success(context, "No Internet. Update saved offline.");
//       } else {
//         AppMessage.success(
//           context,
//           response.data?["message"] ?? "Data Save Successfully",
//         );
//       }
//
//       if (!mounted) return;
//
//       setState(() {
//         finalItems.clear();
//         cartItems.clear();
//         approvalAddedItems.clear();
//         _itemOrderMap.clear();     // 🔥 ADD
//         _itemOrderCounter = 0;     // 🔥 ADD
//       });
//
//
//
//       Navigator.pushAndRemoveUntil(
//         context,
//         MaterialPageRoute(
//           builder: (_) => const SellList(),
//         ),
//             (route) => route.isFirst,
//       );
//     } else {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text("Failed to Save Data")));
//     }
//   }
//
//   Future<void> savefinalizeBulkItemsUpdate() async {
//     /// ============================================================
//     /// CLOSE KEYBOARD
//     /// ============================================================
//
//     FocusManager.instance.primaryFocus?.unfocus();
//
//     /// ============================================================
//     /// CUSTOMER VALIDATION
//     /// ============================================================
//
//     if (selectedUserId == null || selectedUserId.toString().trim().isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text("Please select Customer"),
//           backgroundColor: Colors.red,
//         ),
//       );
//       return;
//     }
//
//     /// ============================================================
//     /// FIRST UPDATE FINAL ITEMS
//     /// ============================================================
//
//     updateFinalItems();
//
//     /// ============================================================
//     /// PREPARE VALID ITEMS
//     ///
//     /// 🔥 FIX: itemset_id ne item_id sathe FORCE equal na karo.
//     /// Tamara data ma multiple physical items (itemsets) EK j master
//     /// item (item_id) share kari shake che (dhat/design same, pan
//     /// alag-alag piece). itemset_id ne item_id sathe overwrite karta
//     /// badha items same itemset_id mokle che, ane backend te badha
//     /// ne SAME row samji ne overwrite kare che — etle matra last item
//     /// j save thato hato.
//     ///
//     /// Have itemset_id = item ni actual itemset_id (jo hoy to), nahi
//     /// to item_id fallback tarike.
//     /// ============================================================
//
//     double _toD(dynamic v) {
//       if (v == null) return 0;
//       return double.tryParse(v.toString()) ?? 0;
//     }
//
//     final List<Map<String, dynamic>> allItemsToSave = finalItems
//         .where((item) {
//       final dynamic itemId = item["item_id"];
//       final dynamic itemsetId = item["itemset_id"];
//
//       final bool hasItemId =
//           itemId != null &&
//               itemId.toString().trim().isNotEmpty &&
//               itemId.toString().toLowerCase() != "null";
//
//       final bool hasItemsetId =
//           itemsetId != null &&
//               itemsetId.toString().trim().isNotEmpty &&
//               itemsetId.toString().toLowerCase() != "null";
//
//       return hasItemId || hasItemsetId;
//     })
//         .map<Map<String, dynamic>>((item) {
//       final int? parsedItemId = int.tryParse(item["item_id"]?.toString() ?? "");
//
//       final int? parsedItemsetId =
//       int.tryParse(item["itemset_id"]?.toString() ?? "");
//
//       /// 🔥 FIX: approval_item_id pan sachvo, nahi to update payload ma
//       /// approval reference kadhaai jay che ane backend approval item
//       /// ne link nathi kari shakto.
//       final int? parsedApprovalItemId =
//       int.tryParse(item["approval_item_id"]?.toString() ?? "");
//
//       return {
//         "item_id": parsedItemId ?? item["item_id"],
//         if (_approvalPersonId != null) "approval_customer_id": _approvalPersonId,
//         "itemset_id": int.tryParse(item["itemset_id"]?.toString() ?? "") ??
//             parsedItemId ??
//             item["item_id"],
//
//         /// 🔥 FIX: only jo valid (>0) hoy tyare j add karo, nahi to
//         /// manual/scan items ma null/0 na moklai jay.
//         if (parsedApprovalItemId != null && parsedApprovalItemId > 0)
//           "approval_item_id": parsedApprovalItemId,
//
//         "qty": int.tryParse(item["qty"]?.toString() ?? "1") ?? 1,
//
//         "gross_weight": _toD(item["gross_weight"]),
//         "other_weight": _toD(item["other_weight"] ?? item["other"]),
//         "net_weight": _toD(item["net_weight"]),
//         "purity": _toD(item["purity"]),
//         "waste": _toD(item["waste"]),
//         "net_purity": _toD(item["net_purity"]),
//         "fine_weight": _toD(item["fine_weight"]),
//         "metal_rate": _toD(item["metal_rate"]),
//         "metal_amount": _toD(item["metal_amount"]),
//         "labour_rate": _toD(item["labour_rate"]),
//         "labour_amount": _toD(item["labour_amount"]),
//         "other_amount": _toD(item["other_amount"]),
//         "total_amount": _toD(item["total_amount"]),
//
//         "remarks": item["remarks"]?.toString() ?? "",
//       };
//     })
//         .toList();
//
//     /// ============================================================
//     /// ITEMS VALIDATION
//     /// ============================================================
//
//     if (allItemsToSave.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text("No valid items to save"),
//           backgroundColor: Colors.red,
//         ),
//       );
//
//       return;
//     }
//
//     /// ============================================================
//     /// DEBUG EACH ITEM
//     /// ============================================================
//
//     debugPrint("================================================");
//     debugPrint("🔥 UPDATE ITEMS COUNT => ${allItemsToSave.length}");
//
//     for (int i = 0; i < allItemsToSave.length; i++) {
//       final Map<String, dynamic> item = allItemsToSave[i];
//       debugPrint("🔥 UPDATE ITEM ${i + 1}");
//       debugPrint("item_id => ${item["item_id"]}");
//       debugPrint("itemset_id => ${item["itemset_id"]}");
//       debugPrint("FULL DATA => $item");
//       debugPrint("------------------------------------------------");
//     }
//
//     /// ============================================================
//     /// SALE ID
//     /// ============================================================
//
//     final dynamic userId = widget.userData!["id"];
//
//     /// ============================================================
//     /// PAYMENT VALUES
//     /// ============================================================
//
//     final String receivedText = recived_amount_Controller.text.trim();
//     final String additionalReceivedText = add_payment_Controller.text.trim();
//
//     /// ============================================================
//     /// REQUEST BODY
//     /// ============================================================
//
//     final Map<String, dynamic> body = {
//       "customer_id": int.parse(selectedUserId.toString()),
//       "items": allItemsToSave,
//       "received_amount": receivedText.isEmpty ? null : double.tryParse(receivedText),
//       "additional_received_amount":
//       additionalReceivedText.isEmpty ? null : double.tryParse(additionalReceivedText),
//       "payment_mode": selectedPaymentMode,
//       "payment_reference": payment_ref_Controller.text.trim(),
//       "payment_note": payment_pending_Controller.text.trim(),
//       "remarks": remarksController.text.trim(),
//       "use_silver_balance": useSilverBalance,
//     };
//
//     /// ============================================================
//     /// DEBUG BODY
//     /// ============================================================
//
//     debugPrint("================================================");
//     debugPrint("📤 UPDATE SALE ID => $userId");
//     debugPrint("📤 UPDATE REQUEST BODY => $body");
//     debugPrint("================================================");
//
//     for (final item in allItemsToSave) {
//       debugPrint(
//         "📦 ITEM => item_id: ${item["item_id"]} | itemset_id: ${item["itemset_id"]}",
//       );
//     }
//
//     /// ============================================================
//     /// API CALL
//     /// ============================================================
//
//     final response = await ApiHelper().putRequest(
//       "${ApiConstants.Sale_update}/$userId",
//       body,
//     );
//
//     if (!mounted) return;
//
//     /// ============================================================
//     /// SUCCESS
//     /// ============================================================
//
//     if (response != null && response.statusCode == 200) {
//       AppMessage.success(
//         context,
//         response.data?["message"] ?? "Data Update Successfully",
//       );
//
//       setState(() {
//         finalItems.clear();
//         cartItems.clear();
//         approvalAddedItems.clear();
//         items.clear();
//         _itemOrderMap.clear();
//         _itemOrderCounter = 0;
//       });
//
//       Navigator.pushAndRemoveUntil(
//         context,
//         MaterialPageRoute(builder: (_) => const SellList()),
//             (route) => route.isFirst,
//       );
//     } else {
//       final String message =
//           response?.data?["message"]?.toString() ?? "Failed to Update Data";
//
//       ScaffoldMessenger.of(context)
//         ..hideCurrentSnackBar()
//         ..showSnackBar(
//           SnackBar(content: Text(message), backgroundColor: Colors.red),
//         );
//     }
//   }
//
//   void calculateNetWeight(int index) {
//     double gross = double.tryParse(tableRows[index]["gross"]!.text) ?? 0;
//
//     double other = double.tryParse(tableRows[index]["other"]!.text) ?? 0;
//
//     double net = gross - other;
//
//     tableRows[index]["net"]!.text = net.toStringAsFixed(3);
//   }
//
//   Widget filterWidget() {
//     return Container(
//       margin: const EdgeInsets.fromLTRB(10, 12, 10, 0),
//       padding: const EdgeInsets.all(10),
//       decoration: BoxDecoration(
//         color: AppColors.cardBackground,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: AppColors.border.withOpacity(0.8)),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.04),
//             blurRadius: 10,
//             offset: const Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Consumer<ItemProvider>(
//         builder: (context, provider, child) {
//           final customers = provider.customers;
//           final approvalCustomers = provider.Approval_customers;
//
//           return LayoutBuilder(
//             builder: (context, constraints) {
//               final bool isMobile = constraints.maxWidth < 700;
//
//               // ============================================================
//               // CUSTOMER
//               // ============================================================
//
//               Widget customerField() {
//                 Map? selectedCustomer;
//
//                 if (selectedItem != null) {
//                   for (final customer in customers) {
//                     if (customer["id"]?.toString() == selectedItem.toString()) {
//                       selectedCustomer = customer;
//                       break;
//                     }
//                   }
//                 }
//
//                 return _premiumFieldWrapper(
//                   label: "Customer",
//                   child: _dropdownWithClear(
//                     showClear: selectedCustomer != null,
//                     onClear: () => _setCustomer(provider, null, approvalCustomers),
//                     dropdown: PremiumSearchableDropdown<Map>(
//                       label: "",
//                       hint: "Select Customer",
//                       items: List<Map>.from(customers),
//                       value: selectedCustomer,
//                       prefixIcon: Icons.person_outline,
//                       itemLabel: (item) => item["name"]?.toString() ?? "-",
//                       searchText: (item) {
//                         return [
//                           item["name"]?.toString() ?? "",
//                           item["mobile_no"]?.toString() ?? "",
//                           item["email"]?.toString() ?? "",
//                           item["id"]?.toString() ?? "",
//                         ].join(" ");
//                       },
//                       onChanged: (selectedData) =>
//                           _setCustomer(provider, selectedData, approvalCustomers),
//                     ),
//                   ),
//                 );
//               }
//
//               // ============================================================
//               // APPROVAL PERSON
//               // ============================================================
//
//               Widget approvalField() {
//                 Map? selectedApprovalCustomer;
//
//                 /// 1. પસંદ થયેલો Approval Person
//                 if (selectedapprovalItem != null) {
//                   for (final customer in approvalCustomers) {
//                     if (customer["id"]?.toString() == selectedapprovalItem.toString()) {
//                       selectedApprovalCustomer = customer;
//                       break;
//                     }
//                   }
//                 }
//
//                 /// 2. EDIT MODE default — user એ જાતે clear ના કર્યો હોય ત્યારે જ
//                 if (selectedApprovalCustomer == null &&
//                     isEditMode &&
//                     selectedItem != null &&
//                     !_approvalManuallyCleared) {
//                   for (final customer in approvalCustomers) {
//                     if (customer["id"]?.toString() == selectedItem.toString()) {
//                       selectedApprovalCustomer = customer;
//                       break;
//                     }
//                   }
//                 }
//
//                 return _premiumFieldWrapper(
//                   label: "Approval Person",
//                   child: _dropdownWithClear(
//                     showClear: selectedApprovalCustomer != null,
//                     onClear: () => _setApprovalPerson(null),
//                     dropdown: PremiumSearchableDropdown<Map>(
//                       label: "",
//                       hint: "Select Approval Person",
//                       items: List<Map>.from(approvalCustomers),
//                       value: selectedApprovalCustomer,
//                       prefixIcon: Icons.verified_user_outlined,
//                       itemLabel: (item) => item["name"]?.toString() ?? "-",
//                       searchText: (item) {
//                         return [
//                           item["name"]?.toString() ?? "",
//                           item["mobile_no"]?.toString() ?? "",
//                           item["mobile"]?.toString() ?? "",
//                           item["email"]?.toString() ?? "",
//                           item["id"]?.toString() ?? "",
//                         ].join(" ");
//                       },
//                       onChanged: (selectedData) => _setApprovalPerson(selectedData),
//                     ),
//                   ),
//                 );
//               }
//
//               // ============================================================
//               // SEARCH
//               // ============================================================
//
//               Widget searchField() {
//                 return _premiumFieldWrapper(
//                   label: "Scan / Search",
//                   child: TextField(
//                     controller: searchController,
//
//                     onChanged: (value) {
//                       setState(() {});
//                       searchItemsApi(value);
//                     },
//
//                     style: const TextStyle(color: Colors.black87, fontSize: 13),
//
//                     decoration: _premiumInputDecoration(
//                       hint: "HUID / QR / Item",
//
//                       /// SEARCH ICON
//                       prefixIcon: const Icon(
//                         Icons.search_rounded,
//                         size: 20,
//                         color: Colors.black45,
//                       ),
//
//                       /// ==========================================
//                       /// PREMIUM SCANNER BUTTON
//                       /// ==========================================
//                       suffixIcon: Padding(
//                         padding: const EdgeInsets.all(4),
//                         child: InkWell(
//                           onTap: () {
//                             FocusManager.instance.primaryFocus?.unfocus();
//
//                             setState(() {
//                               showScannerFull = true;
//                             });
//                           },
//                           borderRadius: BorderRadius.circular(6),
//                           child: Container(
//                             width: 42,
//                             height: 38,
//                             alignment: Alignment.center,
//                             decoration: BoxDecoration(
//                               gradient: LinearGradient(
//                                 colors: [
//                                   AppColors.primaryDark.withOpacity(0.7),
//                                   AppColors.border.withOpacity(0.7),
//                                   AppColors.secondaryDark.withOpacity(0.7),
//                                 ],
//                               ),
//                               borderRadius: BorderRadius.circular(6),
//                             ),
//                             child: const Icon(
//                               Icons.qr_code_scanner_rounded,
//                               color: Colors.black87,
//                               size: 21,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 );
//               }
//
//               // ============================================================
//               // MAIN UI
//               // ============================================================
//
//               return Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // ========================================================
//                   // ROW 1
//                   // CUSTOMER | APPROVAL | SEARCH
//                   // ========================================================
//                   Column(
//                     children: [
//                       // Customer + Approval same row
//                       Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           // ============================================================
//                           // CUSTOMER
//                           // ============================================================
//                           customerField(),
//
//                           const SizedBox(height: 8),
//
//                           // ============================================================
//                           // APPROVAL PERSON - EXPANDABLE
//                           // ============================================================
//                           // Container(
//                           //   decoration: BoxDecoration(
//                           //     color: AppColors.primaryDark.withOpacity(0.035),
//                           //     borderRadius: BorderRadius.circular(6),
//                           //     border: Border.all(
//                           //       color: AppColors.border.withOpacity(0.8),
//                           //     ),
//                           //   ),
//                           //   child: Theme(
//                           //     data: Theme.of(context).copyWith(
//                           //       dividerColor: Colors.transparent,
//                           //       splashColor: Colors.transparent,
//                           //       highlightColor: Colors.transparent,
//                           //     ),
//                           //     child: ExpansionTile(
//                           //       initiallyExpanded: false,
//                           //
//                           //       dense: true,
//                           //
//                           //       visualDensity: const VisualDensity(
//                           //         horizontal: -2,
//                           //         vertical: -4,
//                           //       ),
//                           //
//                           //       minTileHeight: 42,
//                           //
//                           //       tilePadding: const EdgeInsets.symmetric(
//                           //         horizontal: 8,
//                           //       ),
//                           //
//                           //       childrenPadding: const EdgeInsets.fromLTRB(
//                           //         8,
//                           //         2,
//                           //         8,
//                           //         8,
//                           //       ),
//                           //
//                           //       shape: const Border(),
//                           //       collapsedShape: const Border(),
//                           //
//                           //       // ============================================================
//                           //       // SMALL ICON
//                           //       // ============================================================
//                           //       leading: Container(
//                           //         width: 25,
//                           //         height: 25,
//                           //         alignment: Alignment.center,
//                           //         decoration: BoxDecoration(
//                           //           color: AppColors.gradientBlue.withOpacity(0.10),
//                           //           borderRadius: BorderRadius.circular(5),
//                           //         ),
//                           //         child: const Icon(
//                           //           Icons.verified_user_outlined,
//                           //           size: 15,
//                           //           color: AppColors.gradientBlue,
//                           //         ),
//                           //       ),
//                           //
//                           //       // ============================================================
//                           //       // TITLE
//                           //       // ============================================================
//                           //       title: const Text(
//                           //         "Approval Person",
//                           //         style: TextStyle(
//                           //           fontSize: 11.5,
//                           //           fontWeight: FontWeight.w600,
//                           //           color: Colors.black87,
//                           //         ),
//                           //       ),
//                           //
//                           //       // ============================================================
//                           //       // TAP TEXT
//                           //       // ============================================================
//                           //       subtitle: Text(
//                           //         selectedapprovalItem == null
//                           //             ? "Tap to select approval person"
//                           //             : "Approval person selected",
//                           //         maxLines: 1,
//                           //         overflow: TextOverflow.ellipsis,
//                           //         style: TextStyle(
//                           //           fontSize: 9,
//                           //           height: 1.0,
//                           //           color: selectedapprovalItem == null
//                           //               ? Colors.black45
//                           //               : Colors.green.shade600,
//                           //           fontWeight: FontWeight.w500,
//                           //         ),
//                           //       ),
//                           //
//                           //       iconColor: AppColors.gradientBlue,
//                           //       collapsedIconColor: Colors.black45,
//                           //
//                           //       // ============================================================
//                           //       // EXPANDED DROPDOWN
//                           //       // ============================================================
//                           //       children: [
//                           //         approvalField(),
//                           //       ],
//                           //     ),
//                           //   ),
//                           // ),
//
//                           approvalField(),
//                         ],
//                       ),
//
//                       const SizedBox(height: 5),
//
//                       // Search below, full width
//                       SizedBox(width: double.infinity, child: searchField()),
//                     ],
//                   ),
//
//                   // ========================================================
//                   // SEARCH RESULT
//                   // ========================================================
//                   if (searchController.text.trim().isNotEmpty)
//                     Padding(
//                       padding: const EdgeInsets.only(top: 4),
//                       child: _searchResultDropdown(),
//                     ),
//
//                   const SizedBox(height: 5),
//
//                   // ========================================================
//                   // BALANCE ROW
//                   // ========================================================
//                   Card(
//                     elevation: 0,
//                     margin: EdgeInsets.zero,
//                     color: AppColors.primaryDark.withOpacity(0.05),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(6),
//                       side: BorderSide(color: AppColors.border),
//                     ),
//                     child: Theme(
//                       data: Theme.of(context).copyWith(
//                         dividerColor: Colors.transparent,
//                         splashColor: Colors.transparent,
//                         highlightColor: Colors.transparent,
//                       ),
//                       child: ExpansionTile(
//                         initiallyExpanded: false,
//
//                         tilePadding: const EdgeInsets.symmetric(
//                           horizontal: 14,
//                           vertical: 1,
//                         ),
//
//                         childrenPadding: const EdgeInsets.fromLTRB(
//                           10,
//                           4,
//                           10,
//                           10,
//                         ),
//
//                         shape: const Border(),
//                         collapsedShape: const Border(),
//
//                         leading: Container(
//                           width: 34,
//                           height: 30,
//                           decoration: BoxDecoration(
//                             color: AppColors.gradientBlue.withOpacity(0.10),
//                             borderRadius: BorderRadius.circular(6),
//                           ),
//                           child: const Icon(
//                             Icons.account_balance_wallet_outlined,
//                             size: 19,
//                             color: AppColors.gradientBlue,
//                           ),
//                         ),
//
//                         title: const Text(
//                           "Sale & Payment Details",
//                           style: TextStyle(
//                             fontSize: 13,
//                             fontWeight: FontWeight.w600,
//                             color: Colors.black87,
//                           ),
//                         ),
//
//                         subtitle: const Text(
//                           "Balance, remarks and payment information",
//                           style: TextStyle(fontSize: 10, color: Colors.black45),
//                         ),
//
//                         iconColor: AppColors.gradientBlue,
//                         collapsedIconColor: Colors.black54,
//                         onExpansionChanged: (value) {
//                           setState(() {
//                             isSalePaymentExpanded = value;
//                           });
//                         },
//                         trailing: Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//
//                             // ============================================================
//                             // EXPAND ARROW
//                             // ============================================================
//                             AnimatedRotation(
//                               turns: isSalePaymentExpanded ? 0.5 : 0,
//                               duration: const Duration(milliseconds: 200),
//                               child: const Icon(
//                                 Icons.keyboard_arrow_down_rounded,
//                                 size: 22,
//                                 color: Colors.black54,
//                               ),
//                             ),
//
//                             const SizedBox(width: 5),
//                             // ============================================================
//                             // + ADD ITEM
//                             // ============================================================
//                             InkWell(
//                               onTap: () {
//                                 FocusManager.instance.primaryFocus?.unfocus();
//
//                                 final Map<String, dynamic> freshRow =
//                                 createApprovalBlankItemRow();
//
//                                 setState(() {
//                                   if (isEditMode) {
//                                     approvalAddedItems.add(freshRow);
//                                   } else {
//                                     items.add(freshRow);
//                                   }
//                                 });
//                               },
//                               borderRadius: BorderRadius.circular(20),
//                               child: Container(
//                                 width: 27,
//                                 height: 27,
//                                 alignment: Alignment.center,
//                                 decoration: BoxDecoration(
//                                   color: AppColors.gradientBlue.withOpacity(0.10),
//                                   shape: BoxShape.circle,
//                                   border: Border.all(
//                                     color: AppColors.gradientBlue.withOpacity(0.25),
//                                   ),
//                                 ),
//                                 child: const Icon(
//                                   Icons.add_rounded,
//                                   size: 18,
//                                   color: AppColors.gradientBlue,
//                                 ),
//                               ),
//                             ),
//
//
//
//
//                           ],
//                         ),
//
//                         children: [
//                           // ============================================================
//                           // BALANCE SECTION
//                           // ============================================================
//                           _buildBalanceBoxes(provider, isMobile),
//
//                           const SizedBox(height: 16),
//
//                           // ============================================================
//                           // REMARKS + ADJUST FINE BALANCE
//                           // ============================================================
//                           Builder(
//                             builder: (_) {
//                               final Widget remarksField = _premiumFieldWrapper(
//                                 label: "Voucher Remarks",
//                                 child: TextFormField(
//                                   controller: remarksController,
//                                   minLines: 2,
//                                   maxLines: 3,
//                                   style: const TextStyle(
//                                     color: Colors.black87,
//                                     fontSize: 13,
//                                     fontWeight: FontWeight.w500,
//                                   ),
//                                   decoration: _premiumInputDecoration(
//                                     hint: "Enter remarks for this sale",
//                                   ),
//                                 ),
//                               );
//
//                               if (!isMobile) {
//                                 return Row(
//                                   crossAxisAlignment: CrossAxisAlignment.end,
//                                   children: [
//                                     Expanded(flex: 3, child: remarksField),
//                                     const SizedBox(width: 14),
//                                     Expanded(
//                                       flex: 2,
//                                       child: _adjustFineBalanceTile(),
//                                     ),
//                                   ],
//                                 );
//                               }
//
//                               return Column(
//                                 children: [
//                                   remarksField,
//                                   const SizedBox(height: 10),
//                                   _adjustFineBalanceTile(),
//                                 ],
//                               );
//                             },
//                           ),
//
//                           const SizedBox(height: 16),
//
//                           // ============================================================
//                           // PAYMENT SECTION
//                           // ============================================================
//                           if (!isMobile)
//                             Row(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 // RECEIVED AMOUNT
//                                 Expanded(
//                                   child: _premiumFieldWrapper(
//                                     label: "Received Amount",
//                                     child: TextFormField(
//                                       controller: recived_amount_Controller,
//
//                                       keyboardType:
//                                       const TextInputType.numberWithOptions(
//                                         decimal: true,
//                                       ),
//
//                                       onChanged: (value) {
//                                         final total =
//                                             calculateTotals()["total"] ?? 0;
//
//                                         final received =
//                                             double.tryParse(value) ?? 0;
//
//                                         final pending = total - received;
//
//                                         payment_pending_Controller.text =
//                                             pending.toStringAsFixed(2);
//                                       },
//
//                                       style: const TextStyle(
//                                         color: Colors.black87,
//                                         fontSize: 13,
//                                         fontWeight: FontWeight.w500,
//                                       ),
//
//                                       decoration: _premiumInputDecoration(
//                                         hint: "0.00",
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//
//                                 const SizedBox(width: 14),
//
//                                 // PAYMENT MODE
//                                 Expanded(
//                                   child: _premiumFieldWrapper(
//                                     label: "Payment Mode",
//                                     child: DropdownButtonFormField<String>(
//                                       isExpanded: true,
//
//                                       value:
//                                       [
//                                         "Cash",
//                                         "Online",
//                                         "UPI",
//                                         "Bank",
//                                         "Other",
//                                       ].contains(selectedPaymentMode)
//                                           ? selectedPaymentMode
//                                           : null,
//
//                                       hint: const Text(
//                                         "Select Mode",
//                                         style: TextStyle(
//                                           color: Colors.black45,
//                                           fontSize: 13,
//                                         ),
//                                       ),
//
//                                       icon: const Icon(
//                                         Icons.keyboard_arrow_down_rounded,
//                                         color: Colors.black45,
//                                       ),
//
//                                       dropdownColor: Colors.white,
//
//                                       style: const TextStyle(
//                                         color: Colors.black87,
//                                         fontSize: 13,
//                                       ),
//
//                                       decoration: _premiumInputDecoration(),
//
//                                       items: const [
//                                         DropdownMenuItem(
//                                           value: "Cash",
//                                           child: Text("Cash"),
//                                         ),
//                                         DropdownMenuItem(
//                                           value: "Online",
//                                           child: Text("Online"),
//                                         ),
//                                         DropdownMenuItem(
//                                           value: "UPI",
//                                           child: Text("UPI"),
//                                         ),
//                                         DropdownMenuItem(
//                                           value: "Bank",
//                                           child: Text("Bank"),
//                                         ),
//                                         DropdownMenuItem(
//                                           value: "Other",
//                                           child: Text("Other"),
//                                         ),
//                                       ],
//
//                                       onChanged: (value) {
//                                         setState(() {
//                                           selectedPaymentMode = value;
//                                         });
//                                       },
//                                     ),
//                                   ),
//                                 ),
//
//                                 const SizedBox(width: 14),
//
//                                 // PAYMENT REF
//                                 Expanded(
//                                   child: _premiumFieldWrapper(
//                                     label: "Payment Ref No",
//                                     child: TextFormField(
//                                       controller: payment_ref_Controller,
//
//                                       style: const TextStyle(
//                                         color: Colors.black87,
//                                         fontSize: 13,
//                                         fontWeight: FontWeight.w500,
//                                       ),
//
//                                       decoration: _premiumInputDecoration(
//                                         hint: "Txn/Ref No",
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//
//                                 const SizedBox(width: 14),
//
//                                 // PENDING
//                                 Expanded(
//                                   child: _premiumFieldWrapper(
//                                     label: "Pending Amount",
//                                     child: TextFormField(
//                                       controller: payment_pending_Controller,
//
//                                       readOnly: true,
//
//                                       keyboardType:
//                                       const TextInputType.numberWithOptions(
//                                         decimal: true,
//                                       ),
//
//                                       style: const TextStyle(
//                                         color: Colors.black87,
//                                         fontSize: 13,
//                                         fontWeight: FontWeight.w500,
//                                       ),
//
//                                       decoration: _premiumInputDecoration(
//                                         hint: "0.00",
//                                         readOnly: true,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             )
//                           // ============================================================
//                           // MOBILE PAYMENT
//                           // ============================================================
//                           else
//                             Column(
//                               children: [
//                                 Row(
//                                   children: [
//                                     Expanded(
//                                       child: _premiumFieldWrapper(
//                                         label: "Received Amount",
//                                         child: TextFormField(
//                                           controller: recived_amount_Controller,
//
//                                           keyboardType:
//                                           const TextInputType.numberWithOptions(
//                                             decimal: true,
//                                           ),
//
//                                           onChanged: (value) {
//                                             final total =
//                                                 calculateTotals()["total"] ?? 0;
//
//                                             final received =
//                                                 double.tryParse(value) ?? 0;
//
//                                             payment_pending_Controller.text =
//                                                 (total - received)
//                                                     .toStringAsFixed(2);
//                                           },
//
//                                           decoration: _premiumInputDecoration(
//                                             hint: "0.00",
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//
//                                     const SizedBox(width: 8),
//
//                                     Expanded(
//                                       child: _premiumFieldWrapper(
//                                         label: "Payment Mode",
//                                         child: DropdownButtonFormField<String>(
//                                           isExpanded: true,
//
//                                           value:
//                                           [
//                                             "Cash",
//                                             "Online",
//                                             "UPI",
//                                             "Bank",
//                                             "Other",
//                                           ].contains(selectedPaymentMode)
//                                               ? selectedPaymentMode
//                                               : null,
//
//                                           hint: const Text(
//                                             "Select Mode",
//                                             style: TextStyle(
//                                               fontSize: 12,
//                                               color: Colors.black45,
//                                             ),
//                                           ),
//
//                                           dropdownColor: Colors.white,
//
//                                           decoration: _premiumInputDecoration(),
//
//                                           items: const [
//                                             DropdownMenuItem(
//                                               value: "Cash",
//                                               child: Text("Cash"),
//                                             ),
//                                             DropdownMenuItem(
//                                               value: "Online",
//                                               child: Text("Online"),
//                                             ),
//                                             DropdownMenuItem(
//                                               value: "UPI",
//                                               child: Text("UPI"),
//                                             ),
//                                             DropdownMenuItem(
//                                               value: "Bank",
//                                               child: Text("Bank"),
//                                             ),
//                                             DropdownMenuItem(
//                                               value: "Other",
//                                               child: Text("Other"),
//                                             ),
//                                           ],
//
//                                           onChanged: (value) {
//                                             setState(() {
//                                               selectedPaymentMode = value;
//                                             });
//                                           },
//                                         ),
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//
//                                 const SizedBox(height: 10),
//
//                                 Row(
//                                   children: [
//                                     Expanded(
//                                       child: _premiumFieldWrapper(
//                                         label: "Payment Ref No",
//                                         child: TextFormField(
//                                           controller: payment_ref_Controller,
//
//                                           decoration: _premiumInputDecoration(
//                                             hint: "Txn/Ref No",
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//
//                                     const SizedBox(width: 8),
//
//                                     Expanded(
//                                       child: _premiumFieldWrapper(
//                                         label: "Pending Amount",
//                                         child: TextFormField(
//                                           controller:
//                                           payment_pending_Controller,
//
//                                           readOnly: true,
//
//                                           decoration: _premiumInputDecoration(
//                                             hint: "0.00",
//                                             readOnly: true,
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ],
//                             ),
//
//                           // ============================================================
//                           // EDIT MODE ADD PAYMENT
//                           // ============================================================
//                           if (isEditMode) ...[
//                             const SizedBox(height: 14),
//
//                             Align(
//                               alignment: Alignment.centerLeft,
//                               child: SizedBox(
//                                 width: isMobile
//                                     ? double.infinity
//                                     : constraints.maxWidth / 4,
//
//                                 child: _premiumFieldWrapper(
//                                   label: "Add Payment",
//                                   child: TextFormField(
//                                     controller: add_payment_Controller,
//
//                                     keyboardType:
//                                     const TextInputType.numberWithOptions(
//                                       decimal: true,
//                                     ),
//
//                                     decoration: _premiumInputDecoration(
//                                       hint: "Add Payment (Later)",
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ],
//
//                           const SizedBox(height: 16),
//                         ],
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 10),
//                   // ============================================================
//                   // ACTION BUTTONS
//                   // ============================================================
//                   const SizedBox(height: 0),
//
// // ============================================================
// // BOTTOM ADD BUTTON
// // ============================================================
//
//                   // Row(
//                   //   children: [
//                   //
//                   //     // SCAN
//                   //     SizedBox(
//                   //       width: 52,
//                   //       height: 44,
//                   //       child: InkWell(
//                   //         onTap: () {
//                   //           setState(() {
//                   //             showScannerFull = true;
//                   //           });
//                   //         },
//                   //
//                   //         borderRadius: BorderRadius.circular(6),
//                   //
//                   //         child: Container(
//                   //           decoration: BoxDecoration(
//                   //             gradient: LinearGradient(
//                   //               colors: [
//                   //                 AppColors.primaryDark
//                   //                     .withOpacity(0.7),
//                   //                 AppColors.border
//                   //                     .withOpacity(0.7),
//                   //                 AppColors.secondaryDark
//                   //                     .withOpacity(0.7),
//                   //               ],
//                   //             ),
//                   //             borderRadius:
//                   //             BorderRadius.circular(6),
//                   //           ),
//                   //
//                   //           child: const Icon(
//                   //             Icons.qr_code_scanner_rounded,
//                   //             color: Colors.black87,
//                   //             size: 22,
//                   //           ),
//                   //         ),
//                   //       ),
//                   //     ),
//                   //
//                   //     const SizedBox(width: 10),
//                   //
//                   //     // // ADD LABEL
//                   //     // Expanded(
//                   //     //   child: InkWell(
//                   //     //     onTap: () {
//                   //     //       if (selectedapprovalItem == null) {
//                   //     //         ScaffoldMessenger.of(context)
//                   //     //             .showSnackBar(
//                   //     //           const SnackBar(
//                   //     //             content: Text(
//                   //     //               "Please select approval person first",
//                   //     //             ),
//                   //     //             backgroundColor: Colors.red,
//                   //     //           ),
//                   //     //         );
//                   //     //
//                   //     //         return;
//                   //     //       }
//                   //     //
//                   //     //       getApprovalDetails(
//                   //     //         int.parse(
//                   //     //           selectedapprovalItem.toString(),
//                   //     //         ),
//                   //     //       );
//                   //     //     },
//                   //     //
//                   //     //     borderRadius: BorderRadius.circular(6),
//                   //     //
//                   //     //     child: Container(
//                   //     //       height: 44,
//                   //     //       decoration: BoxDecoration(
//                   //     //         color: Colors.white,
//                   //     //         borderRadius:
//                   //     //         BorderRadius.circular(6),
//                   //     //         border: Border.all(
//                   //     //           color: AppColors.border,
//                   //     //         ),
//                   //     //       ),
//                   //     //
//                   //     //       child: const Row(
//                   //     //         mainAxisAlignment:
//                   //     //         MainAxisAlignment.center,
//                   //     //         children: [
//                   //     //           Icon(
//                   //     //             Icons.add_rounded,
//                   //     //             size: 18,
//                   //     //             color: Colors.black87,
//                   //     //           ),
//                   //     //
//                   //     //           SizedBox(width: 6),
//                   //     //
//                   //     //           Text(
//                   //     //             "Add Label From Approval",
//                   //     //             style: TextStyle(
//                   //     //               fontSize: 13,
//                   //     //               fontWeight: FontWeight.w600,
//                   //     //               color: Colors.black87,
//                   //     //             ),
//                   //     //           ),
//                   //     //         ],
//                   //     //       ),
//                   //     //     ),
//                   //     //   ),
//                   //     // ),
//                   //   ],
//                   // ),
//                 ],
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
//
//   Future<void> getApprovalDetails(int? customerId) async {
//     if (customerId == null) {
//       print("CustomerId NULL");
//       return;
//     }
//
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => const Center(child: CircularProgressIndicator()),
//     );
//
//     final response = await ApiHelper().getRequest(
//       "${ApiConstants.label_Approval_list}?approval_customer_id=$customerId",
//       //responseType: ResponseType.bytes,
//     );
//
//     Navigator.pop(context);
//
//     if (response != null && response.statusCode == 200) {
//       final data = response.data;
//       List items = data["data"]; // ✅ direct list
//
//       if (items.isNotEmpty) {
//         /// 🔥 already added ids
//         Set<int> addedIds = approvalAddedItems.map<int>((e) {
//           return int.tryParse(e["approval_item_id"].toString()) ?? 0;
//         }).toSet();
//
//         /// 🔥 filter items
//         List filteredItems = items.where((item) {
//           int id = int.tryParse(item["approval_item_id"].toString()) ?? 0;
//           return !addedIds.contains(id); // ❌ remove already added
//         }).toList();
//
//         /// 👉 now open dialog with filtered list
//         final selectedIds = await showApprovalDialog(filteredItems);
//
//         if (selectedIds != null && selectedIds.isNotEmpty) {
//           addSelectedItems(selectedIds, items);
//
//           updateFinalItems(); // ✅ parent ma call
//           setState(() {});
//         }
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text("Data Not Found"),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   }
//
//   void addSelectedItems(Set<int> selectedIds, List allItems) {
//     final List selectedData = allItems.where((item) {
//       final int id =
//           int.tryParse(item["approval_item_id"]?.toString() ?? "0") ?? 0;
//
//       return selectedIds.contains(id);
//     }).toList();
//
//     setState(() {
//       approvalAddedItems.removeWhere((e) => e["is_fresh"] == true);
//
//       for (var rawItem in selectedData) {
//         final Map<String, dynamic> item = Map<String, dynamic>.from(rawItem);
//
//         final dynamic itemsetId = item["itemset_id"];
//         final dynamic approvalId = item["approval_item_id"];
//
//         item["show_item_dropdown"] = false;
//         item["is_fresh"] = false;
//
//         final String itemName =
//             item["item_name"]?.toString() ??
//                 item["name"]?.toString() ??
//                 item["item"]?["item_name"]?.toString() ??
//                 "";
//
//         item["item_name"] = itemName;
//         item["item"] = itemName;
//
//         item["item_id"] = item["item_id"] ?? item["item"]?["id"];
//
//         /// =========================================================
//         /// 🔥 FIX: NORMALIZE FIELD NAMES + SET CONTROLLERS
//         ///
//         /// Approval API na field names manual/scan items karta alag
//         /// hoy che (e.g. "waste_percent" instead of "waste"), etle
//         /// controller pehla thi j sahi value thi initialize karvo
//         /// jaruri che — exactly jem addItemToCard() / loadEditData()
//         /// ma thay che. Aa vagar rate/labour rate change karta
//         /// amount update j nathi thatu, kem ke fine_weight hammesha
//         /// 0 rehto (purity/waste missing hova thi).
//         /// =========================================================
//
//         item["gross_weight"] = item["gross_weight"]?.toString() ?? "0";
//         item["other_weight"] = item["other_weight"]?.toString() ?? "0";
//         item["net_weight"]   = item["net_weight"]?.toString() ?? "0";
//
//         item["purity"] =
//             item["purity"]?.toString() ??
//                 item["outward_carat"]?.toString() ??
//                 "0";
//
//         item["waste"] =
//             item["waste_percent"]?.toString() ??
//                 item["waste"]?.toString() ??
//                 "0";
//
//         item["outward_carat"] = item["outward_carat"]?.toString() ?? "0";
//         item["net_purity"]    = item["net_purity"]?.toString() ?? "0";
//         item["fine_weight"]   = item["fine_weight"]?.toString() ?? "0";
//
//         item["metal_rate"]   = item["metal_rate"]?.toString() ?? "0";
//         item["metal_amount"] = item["metal_amount"]?.toString() ?? "0";
//
//         item["labour_rate"] =
//             item["labour_rate"]?.toString() ??
//                 item["item"]?["labour_rate"]?.toString() ??
//                 "0";
//         item["labour_amount"] = item["labour_amount"]?.toString() ?? "0";
//
//         /// 🔥 QTY / REMARKS
//         item["qty"] = item["qty"]?.toString() ?? "1";
//         item["remarks"] = item["remarks"]?.toString() ?? "";
//
//         item["other_amount"] = item["other_amount"]?.toString() ?? "0";
//         item["total_amount"] = item["total_amount"]?.toString() ?? "0";
//
//         /// Rate field editable / manual calculation enable rakhva mate
//         item["manual_metal"]  = item["manual_metal"] ?? true;
//         item["manual_labour"] = item["manual_labour"] ?? true;
//
//         setController(item, "gross_weight", item["gross_weight"]);
//         setController(item, "other_weight", item["other_weight"]);
//         setController(item, "net_weight", item["net_weight"]);
//         setController(item, "purity", item["purity"]);
//         setController(item, "waste", item["waste"]);
//         setController(item, "outward_carat", item["outward_carat"]);
//         setController(item, "net_purity", item["net_purity"]);
//         setController(item, "fine_weight", item["fine_weight"]);
//         setController(item, "metal_rate", item["metal_rate"]);
//         setController(item, "metal_amount", item["metal_amount"]);
//         setController(item, "labour_rate", item["labour_rate"]);
//         setController(item, "labour_amount", item["labour_amount"]);
//         setController(item, "qty", item["qty"]);
//         setController(item, "remarks", item["remarks"]);
//         setController(item, "other_amount", item["other_amount"]);
//         setController(item, "total_amount", item["total_amount"]);
//
//         /// 🔥 Add thata j sahi calculated value dekhay
//         calculateItem(item);
//
//         if (!finalItems.any(
//               (e) => e["itemset_id"]?.toString() == itemsetId?.toString(),
//         )) {
//           finalItems.add({
//             "itemset_id": itemsetId,
//             "approval_item_id": approvalId,
//           });
//         }
//
//         if (!approvalAddedItems.any(
//               (e) => e["approval_item_id"]?.toString() == approvalId?.toString(),
//         )) {
//           approvalAddedItems.add(item);
//         }
//       }
//
//       updateFinalItems();
//     });
//   }
//
//   Future<Set<int>?> showApprovalDialog(List items) async {
//     // String val(dynamic v) => v == null ? "-" : v.toString();
//     //
//     // List items = item["items"] ?? []; // ✅ correct list
//     selectedItems.clear(); // ✅ IMPORTANT
//     bool isScannerOpen = false;
//     List filteredItems = List.from(items);
//     TextEditingController approvesearchController = TextEditingController();
//     bool showScanner = false;
//     late AnimationController scannerController;
//     return showDialog<Set<int>>(
//       context: context,
//       builder: (context) {
//         return StatefulBuilder(
//           builder: (context, setState) {
//             return Dialog(
//               backgroundColor: const Color(0xffFAF7F2),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(14),
//               ),
//               insetPadding: const EdgeInsets.symmetric(
//                 horizontal: 16,
//                 vertical: 24,
//               ),
//               child: Container(
//                 width: MediaQuery.of(context).size.width * 0.92,
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 16,
//                   vertical: 14,
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     /// 🔝 HEADER
//                     Row(
//                       children: [
//                         const Text(
//                           "Approval Items",
//                           style: TextStyle(
//                             fontSize: 18,
//                             color: Colors.black,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         const Spacer(),
//                         InkWell(
//                           onTap: () {
//                             setState(() {
//                               showScanner = !showScanner;
//                             });
//                           },
//                           borderRadius: BorderRadius.circular(5),
//                           child: Container(
//                             padding: const EdgeInsets.symmetric(
//                               vertical: 5,
//                               horizontal: 5,
//                             ),
//                             decoration: BoxDecoration(
//                               gradient: const LinearGradient(
//                                 colors: [Color(0xffE6C58A), Color(0xffC8A96A)],
//                               ),
//                               borderRadius: BorderRadius.circular(5),
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: const Color(
//                                     0xffC8A96A,
//                                   ).withOpacity(0.4),
//                                   blurRadius: 8,
//                                   offset: const Offset(0, 3),
//                                 ),
//                               ],
//                             ),
//                             child: const Center(
//                               child: Icon(
//                                 Icons.qr_code_scanner,
//                                 color: Colors.white,
//                                 size: 20,
//                               ),
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 8),
//                         InkWell(
//                           onTap: () => Navigator.pop(context),
//                           child: Container(
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 12,
//                               vertical: 6,
//                             ),
//                             decoration: BoxDecoration(
//                               color: Colors.black,
//                               borderRadius: BorderRadius.circular(6),
//                             ),
//                             child: const Text(
//                               "Back",
//                               style: TextStyle(color: Colors.white),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//
//                     const SizedBox(height: 12),
//
//                     /// 🔍 SEARCH FIELD
//                     TextField(
//                       controller: approvesearchController,
//                       onChanged: (value) {
//                         setState(() {
//                           if (value.isEmpty) {
//                             filteredItems = items;
//                           } else {
//                             filteredItems = items.where((item) {
//                               final name =
//                                   item["name"]?.toString().toLowerCase() ?? "";
//                               final code =
//                                   item["code"]?.toString().toLowerCase() ?? "";
//                               final huid =
//                                   item["HUID"]?.toString().toLowerCase() ?? "";
//
//                               return name.contains(value.toLowerCase()) ||
//                                   code.contains(value.toLowerCase()) ||
//                                   huid.contains(value.toLowerCase());
//                             }).toList();
//                           }
//                         });
//                       },
//                       decoration: InputDecoration(
//                         hintText: "Search Item",
//                         hintStyle: TextStyle(color: Colors.grey.shade600),
//                         prefixIcon: const Icon(
//                           Icons.search,
//                           color: Colors.black54,
//                         ),
//                         filled: true,
//                         fillColor: Colors.white,
//                         contentPadding: const EdgeInsets.symmetric(vertical: 0),
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(8),
//                           borderSide: BorderSide(color: Colors.grey.shade300),
//                         ),
//                         enabledBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(8),
//                           borderSide: BorderSide(color: Colors.grey.shade300),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 12),
//
//                     /// 🔥 SCANNER (BETWEEN SEARCH & LIST)
//                     AnimatedSwitcher(
//                       duration: const Duration(milliseconds: 300),
//                       transitionBuilder: (child, animation) {
//                         final offsetAnimation = Tween<Offset>(
//                           begin: const Offset(0, -1), // TOP thi start
//                           end: Offset.zero, // normal position
//                         ).animate(animation);
//
//                         return ClipRRect(
//                           borderRadius: BorderRadius.circular(12),
//                           child: SlideTransition(
//                             position: offsetAnimation,
//                             child: child,
//                           ),
//                         );
//                       },
//                       child: showScanner
//                           ? Center(
//                         child: Container(
//                           key: const ValueKey("scanner"),
//                           height: 150,
//                           width: 150,
//                           margin: const EdgeInsets.only(bottom: 12),
//                           decoration: BoxDecoration(
//                             color: Colors.black,
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           child: Stack(
//                             children: [
//                               _buildScannerSection(),
//                               _ScannerLineAnimation(),
//                             ],
//                           ),
//                         ),
//                       )
//                           : const SizedBox(key: ValueKey("empty")),
//                     ),
//
//                     /// 🔥 LIST
//                     Expanded(
//                       child: ListView.builder(
//                         // shrinkWrap: true,
//                         // physics: const NeverScrollableScrollPhysics(),
//                         itemCount: filteredItems.length, // ✅ FIX
//                         itemBuilder: (context, index) {
//                           final item = filteredItems[index];
//
//                           final id =
//                               int.tryParse(
//                                 item["approval_item_id"].toString(),
//                               ) ??
//                                   0;
//                           final code = item["code"] ?? "-";
//                           final name = item["name"] ?? "-";
//                           final gross = item["gross_weight"]?.toString() ?? "-";
//
//                           final isSelected = selectedItems.contains(id);
//
//                           return Stack(
//                             children: [
//                               Container(
//                                 margin: const EdgeInsets.symmetric(vertical: 4),
//                                 padding: const EdgeInsets.all(10),
//                                 decoration: BoxDecoration(
//                                   color: Colors.white,
//                                   borderRadius: BorderRadius.circular(8),
//                                   border: Border.all(
//                                     color: Colors.grey.shade300,
//                                   ),
//                                 ),
//                                 child: Row(
//                                   children: [
//                                     /// ✅ CHECKBOX
//                                     Checkbox(
//                                       value: isSelected,
//                                       activeColor: const Color(0xffC8A96A),
//                                       onChanged: (value) {
//                                         setState(() {
//                                           if (value == true) {
//                                             selectedItems.add(id);
//                                           } else {
//                                             selectedItems.remove(id);
//                                           }
//                                         });
//                                       },
//                                     ),
//
//                                     /// 🔹 TEXT
//                                     Expanded(
//                                       child: Column(
//                                         crossAxisAlignment:
//                                         CrossAxisAlignment.start,
//                                         children: [
//                                           /// Row 1
//                                           Row(
//                                             children: [
//                                               Expanded(
//                                                 child: Text(
//                                                   "Name: $name",
//                                                   style: TextStyle(
//                                                     fontSize: 12,
//                                                     color:
//                                                     Colors.black, // ✅ FIX
//                                                   ),
//                                                   overflow:
//                                                   TextOverflow.ellipsis,
//                                                 ),
//                                               ),
//                                               const SizedBox(height: 4),
//                                               Expanded(
//                                                 child: Text(
//                                                   "Code: $code",
//                                                   style: TextStyle(
//                                                     fontSize: 12,
//                                                     color:
//                                                     Colors.black, // ✅ FIX
//                                                   ),
//                                                 ),
//                                               ),
//                                             ],
//                                           ),
//
//                                           /// Row 2
//                                           Text(
//                                             "Gross: $gross",
//                                             style: TextStyle(
//                                               fontSize: 12,
//                                               color: Colors.black, // ✅ FIX
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//
//                               /// 🔥 Index Count
//                               Positioned(
//                                 top: 5,
//                                 right: 0,
//                                 child: Container(
//                                   padding: const EdgeInsets.symmetric(
//                                     horizontal: 6,
//                                     vertical: 3,
//                                   ),
//                                   decoration: const BoxDecoration(
//                                     color: Color(0xffC8A96A),
//                                     borderRadius: BorderRadius.only(
//                                       topLeft: Radius.circular(5),
//                                       bottomRight: Radius.circular(5),
//                                     ),
//                                   ),
//                                   child: Text(
//                                     "${index + 1}",
//                                     style: const TextStyle(
//                                       color: Colors.white,
//                                       fontWeight: FontWeight.bold,
//                                       fontSize: 12,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           );
//                         },
//                       ),
//                     ),
//
//                     const SizedBox(height: 12),
//
//                     /// CLOSE BUTTON
//                     InkWell(
//                       onTap: () async {
//                         FocusManager.instance.primaryFocus?.unfocus();
//
//                         if (selectedItems.isEmpty) {
//                           ScaffoldMessenger.of(context).showSnackBar(
//                             const SnackBar(
//                               content: Text("Please select at least one item"),
//                               backgroundColor: Colors.red,
//                             ),
//                           );
//                           return;
//                         }
//
//                         /// 🔥 Selected items ni list (qr_code sahit) kadho
//                         final List<dynamic> itemsToAdd = items.where((item) {
//                           final int id = int.tryParse(
//                             item["approval_item_id"].toString(),
//                           ) ??
//                               0;
//
//                           return selectedItems.contains(id);
//                         }).toList();
//
//                         /// 🔥 IMPORTANT: navi API na badle EXISTING
//                         /// scanApiCall() flow reuse karo — server par
//                         /// cart add (sales_add_to_cart) + getCartItems()
//                         /// refresh + delete-ready state automatically
//                         /// male che.
//                         for (final item in itemsToAdd) {
//                           final String? qrCode =
//                               item["code"]?.toString() ??
//                                   item["qr_code"]?.toString();
//
//                           if (qrCode == null || qrCode.trim().isEmpty) {
//                             continue;
//                           }
//
//                           await scanApiCall(qrCode);
//                         }
//
//                         if (!context.mounted) return;
//
//                         Navigator.pop(context, selectedItems);
//                       },
//                       child: Center(
//                         child: Container(
//                           width: 100,
//                           height: 40,
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 12,
//                             vertical: 6,
//                           ),
//                           decoration: BoxDecoration(
//                             gradient: const LinearGradient(
//                               colors: [Color(0xffC8A96A), Color(0xffE6C58A)],
//                               begin: Alignment.topLeft,
//                               end: Alignment.bottomRight,
//                             ),
//                             borderRadius: BorderRadius.circular(6),
//                           ),
//                           child: Center(
//                             child: const Text(
//                               "Add",
//                               style: TextStyle(
//                                 color: Colors.black,
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
//
//   Widget _erpRow(String t1, String v1, String t2, String v2) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
//       child: Row(
//         children: [
//           /// Left Field
//           Expanded(
//             child: Row(
//               children: [
//                 Expanded(
//                   flex: 2,
//                   child: Text(
//                     t1,
//                     style: TextStyle(
//                       fontSize: 12,
//                       color: Colors.black, // ✅ FIX
//                     ),
//                   ),
//                 ),
//                 Expanded(
//                   flex: 3,
//                   child: Text(
//                     v1,
//                     style: const TextStyle(
//                       fontSize: 13,
//                       color: Colors.black, // ✅ FIX
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//           /// Right Field
//           Expanded(
//             child: Row(
//               children: [
//                 Expanded(
//                   flex: 2,
//                   child: Text(
//                     t2,
//                     style: TextStyle(
//                       fontSize: 12,
//                       color: Colors.black, // ✅ FIX
//                     ),
//                   ),
//                 ),
//                 Expanded(
//                   flex: 3,
//                   child: Text(
//                     v2,
//                     style: const TextStyle(
//                       fontSize: 13,
//                       color: Colors.black, // ✅ FIX
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget approvalItemCard(
//       Map<String, dynamic> item,
//       int index,
//       int totalCount,
//       ) {
//     bool isExpanded = item["expanded"] ?? false;
//
//     final String itemName =
//         item["name"]?.toString() ?? item["item_name"]?.toString() ?? "Item";
//
//     final String qrCode =
//         item["qr_code"]?.toString() ??
//             item["itemset"]?["qr_code"]?.toString() ??
//             item["code"]?.toString() ??
//             item["itemset"]?["barcode"]?.toString() ??
//             "-";
//
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: AppColors.border),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.04),
//             blurRadius: 8,
//             offset: const Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           /// =========================================================
//           /// HEADER
//           /// =========================================================
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
//             decoration: BoxDecoration(
//               color: AppColors.primaryDark.withOpacity(0.10),
//               borderRadius: const BorderRadius.only(
//                 topLeft: Radius.circular(8),
//                 topRight: Radius.circular(8),
//               ),
//             ),
//             child: Row(
//               children: [
//                 /// INDEX
//                 Container(
//                   width: 26,
//                   height: 26,
//                   alignment: Alignment.center,
//                   decoration: BoxDecoration(
//                     color: AppColors.gradientBlue,
//                     borderRadius: BorderRadius.circular(5),
//                   ),
//                   child: Text(
//                     "${totalCount - index}",
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontWeight: FontWeight.bold,
//                       fontSize: 11,
//                     ),
//                   ),
//                 ),
//
//                 const SizedBox(width: 8),
//
//                 /// ITEM NAME
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       const Text(
//                         "ITEM",
//                         style: TextStyle(
//                           color: Colors.black45,
//                           fontSize: 9,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//
//                       const SizedBox(height: 1),
//
//                       Text(
//                         itemName,
//                         overflow: TextOverflow.ellipsis,
//                         style: const TextStyle(
//                           color: Colors.black,
//                           fontSize: 13,
//                           fontWeight: FontWeight.w700,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//
//                 const SizedBox(width: 8),
//
//                 /// QR CODE
//                 Container(
//                   constraints: const BoxConstraints(maxWidth: 130),
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 8,
//                     vertical: 5,
//                   ),
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(5),
//                     border: Border.all(color: AppColors.border),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       const Icon(
//                         Icons.qr_code_2,
//                         size: 14,
//                         color: AppColors.primaryDark,
//                       ),
//
//                       const SizedBox(width: 4),
//
//                       Flexible(
//                         child: Text(
//                           qrCode,
//                           overflow: TextOverflow.ellipsis,
//                           style: const TextStyle(
//                             color: Colors.black87,
//                             fontSize: 11,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//
//                 const SizedBox(width: 7),
//
//                 /// DELETE
//                 // InkWell(
//                 //   onTap: () async {
//                 //     setState(()  {
//                 //       final approvalId = item["approval_item_id"];
//                 //
//                 //       final itemId = item["id"];
//                 //
//                 //       final itemsetId = item["itemset_id"];
//                 //
//                 //       if (isEditMode && item["is_saved_item"] == true) {
//                 //         final String saleId = widget.userData!["id"].toString(); // ✅ actual sale id
//                 //         final saleItemsetId = item["itemset_id"].toString();
//                 //
//                 //         print("🗑️ DELETE SAVED SALE ITEM");
//                 //         print("SALE ID     => $saleId");
//                 //         print("ITEMSET ID  => $saleItemsetId");
//                 //
//                 //         deleteSaleItem(
//                 //         saleId: saleId,
//                 //         itemsetId: saleItemsetId,
//                 //         );
//                 //       }
//                 //
//                 //       if (approvalId != null) {
//                 //         /// Return Approval Item
//                 //         approvalAddedItems.removeWhere(
//                 //           (e) => e["approval_item_id"] == approvalId,
//                 //         );
//                 //       } else if (item["source"] == "sale") {
//                 //         /// SALE CART ITEM
//                 //         final cartItem = cartItems.firstWhere(
//                 //           (e) =>
//                 //               e["itemset_id"]?.toString() ==
//                 //               itemsetId?.toString(),
//                 //           orElse: () => {},
//                 //         );
//                 //
//                 //         final cartId = cartItem["cart_id"]?.toString() ?? "";
//                 //
//                 //         print("🗑️ DELETE cart_id: $cartId");
//                 //
//                 //         if (cartId.isNotEmpty) {
//                 //           deleteUser(cartId);
//                 //         }
//                 //
//                 //         cartItems.removeWhere(
//                 //           (e) =>
//                 //               e["itemset_id"]?.toString() ==
//                 //               itemsetId?.toString(),
//                 //         );
//                 //       } else {
//                 //         /// MANUAL SEARCH ITEM
//                 //         items.removeWhere(
//                 //           (e) => e["id"] == (itemId ?? itemsetId),
//                 //         );
//                 //       }
//                 //
//                 //       updateFinalItems();
//                 //     });
//                 //   },
//                 //
//                 //   borderRadius: BorderRadius.circular(5),
//                 //   child: Container(
//                 //     width: 27,
//                 //     height: 27,
//                 //     alignment: Alignment.center,
//                 //     decoration: BoxDecoration(
//                 //       gradient: const LinearGradient(
//                 //         colors: [Color(0xffFF8A80), Color(0xffD32F2F)],
//                 //       ),
//                 //       borderRadius: BorderRadius.circular(5),
//                 //     ),
//                 //     child: const Icon(
//                 //       Icons.delete_outline,
//                 //       color: Colors.white,
//                 //       size: 16,
//                 //     ),
//                 //   ),
//                 // ),
//
//                 InkWell(
//                   onTap: () async {
//                     final approvalId = item["approval_item_id"];
//                     final itemId = item["id"];
//                     final itemsetId = item["itemset_id"];
//
//                     // ============================================================
//                     // 🔥 ONLY loaded/saved sale item (from loadEditData) mate
//                     // delete API call karo — approval/cart/manual/fresh items ne
//                     // touch j na karo.
//                     // ============================================================
//
//                     if (isEditMode && item["is_saved_item"] == true) {
//                       final String saleId = widget.userData!["id"].toString(); // ✅ actual sale id
//                       final saleItemsetId = item["itemset_id"].toString();
//
//                       print("🗑️ DELETE SAVED SALE ITEM");
//                       print("SALE ID     => $saleId");
//                       print("ITEMSET ID  => $saleItemsetId");
//
//                       await deleteSaleItem(
//                         saleId: saleId,
//                         itemsetId: saleItemsetId,
//                       );
//                     }
//
//                     setState(() {
//                       // Remove from ALL possible source lists sharing this itemset_id,
//                       // not just the one matching this card's "source"/"approval_item_id".
//                       if (itemsetId != null) {
//                         final cartItem = cartItems.firstWhere(
//                               (e) => e["itemset_id"]?.toString() == itemsetId.toString(),
//                           orElse: () => {},
//                         );
//                         final cartId = cartItem["cart_id"]?.toString() ?? "";
//                         if (cartId.isNotEmpty) deleteUser(cartId);
//
//                         cartItems.removeWhere((e) => e["itemset_id"]?.toString() == itemsetId.toString());
//                         approvalAddedItems.removeWhere((e) => e["itemset_id"]?.toString() == itemsetId.toString());
//                       } else if (approvalId != null) {
//                         approvalAddedItems.removeWhere((e) => e["approval_item_id"] == approvalId);
//                       } else {
//                         items.removeWhere((e) => e["id"] == (itemId ?? itemsetId));
//                       }
//
//                       updateFinalItems();
//                     });
//                   },
//                   borderRadius: BorderRadius.circular(5),
//                   child: Container(
//                     width: 27,
//                     height: 27,
//                     alignment: Alignment.center,
//                     decoration: BoxDecoration(
//                       gradient: const LinearGradient(
//                         colors: [
//                           Color(0xffFF8A80),
//                           Color(0xffD32F2F),
//                         ],
//                       ),
//                       borderRadius: BorderRadius.circular(5),
//                     ),
//                     child: const Icon(
//                       Icons.delete_outline,
//                       color: Colors.white,
//                       size: 16,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//           /// =========================================================
//           /// HORIZONTAL ITEM DETAILS
//           /// =========================================================
//           if (!isExpanded)
//             Container(
//               padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
//               child: SingleChildScrollView(
//                 scrollDirection: Axis.horizontal,
//                 physics: const BouncingScrollPhysics(),
//                 child: Row(
//                   crossAxisAlignment: CrossAxisAlignment.end,
//                   children: [
//                     /// ITEM DROPDOWN
//                     if (item["show_item_dropdown"] == true) ...[
//                       _labourDropdown(item),
//                       const SizedBox(width: 0),
//                     ],
//
//                     _miniField("Qty", item, "qty",index),
//
//                     _miniField("Gross", item, "gross_weight",index),
//
//                     _miniField("Other", item, "other_weight",index),
//
//                     _miniField("Net", item, "net_weight",index),
//
//                     _miniField("Purity", item, "purity",index),
//
//                     _miniField("Waste", item, "waste",index),
//
//                     _miniField("Net Purity", item, "net_purity",index),
//
//                     _miniField("Fine", item, "fine_weight",index),
//
//                     _miniField("Metal Rate", item, "metal_rate",index),
//
//                     _miniField("Metal Amount", item, "metal_amount",index),
//
//                     _miniField("Labour Rate", item, "labour_rate",index),
//
//                     _miniField("Labour Amount", item, "labour_amount",index),
//
//                     _miniField("Other Amount", item, "other_amount",index),
//
//                     _miniField("Total Amount", item, "total_amount",index),
//
//                     _miniField("Remarks", item, "remarks",index),
//                   ],
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _miniField(String title, Map<String, dynamic> item, String key, int index,) {
//     final bool isOtherField = key == "other_amount";
//
//     final bool isMetalRateField = key == "metal_rate";
//
//     final bool isLabourRateField = key == "labour_rate";
//
//     final bool isPurityField = key == "purity";
//     final bool isWasteField = key == "waste";
//
//     final bool isRemarksField = key == "remarks";
//
//     final controller = getController(item, key);
//
//     /// Existing editable logic
//     final bool editable = key == "metal_rate"
//         ? (item["manual_metal"] ?? true)
//         : key == "labour_rate"
//         ? (item["manual_labour"] ?? true)
//         : isEditableField(key);
//
//     return Container(
//       width: isRemarksField ? 140 : 105,
//       margin: const EdgeInsets.only(right: 7),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // ============================================================
//           Padding(
//             padding: const EdgeInsets.only(
//               left: 2,
//               right: 2,
//               bottom: 4,
//             ),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: Text(
//                     title,
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                     style: const TextStyle(
//                       fontSize: 10,
//                       color: Colors.black54,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                 ),
//
//                 // ========================================================
//                 // ONLY FIRST ROW + METAL/LABOUR RATE
//                 // ========================================================
//
//                 if (index == 0 &&
//                     (isMetalRateField ||
//                         isLabourRateField ||
//                         isOtherField ||
//                         isPurityField ||
//                         isWasteField))
//                   InkWell(
//                     onTap: () async {
//                       await applyRateToAllItems(
//                         sourceItem: item,
//                         key: key,
//                       );
//                     },
//                     borderRadius: BorderRadius.circular(4),
//                     child: Container(
//                       height: 18,
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 5,
//                       ),
//                       alignment: Alignment.center,
//                       decoration: BoxDecoration(
//                         color: const Color(0xffC8A96A),
//                         borderRadius: BorderRadius.circular(4),
//                       ),
//                       child: const Text(
//                         "All",
//                         style: TextStyle(
//                           fontSize: 8,
//                           color: Colors.white,
//                           fontWeight: FontWeight.w700,
//                         ),
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//
//           /// FIELD
//           Container(
//             height: 36,
//             decoration: BoxDecoration(
//               color: editable ? Colors.white : Colors.grey.shade50,
//               borderRadius: BorderRadius.circular(5),
//               border: Border.all(color: AppColors.border),
//             ),
//             child: Stack(
//               alignment: Alignment.centerRight,
//               children: [
//                 TextFormField(
//                   controller: controller,
//
//                   /// SAME READONLY LOGIC
//                   readOnly: key == "metal_rate"
//                       ? !(item["manual_metal"] ?? true)
//                       : key == "labour_rate"
//                       ? !(item["manual_labour"] ?? true)
//                       : !isEditableField(key),
//
//                   keyboardType: isRemarksField
//                       ? TextInputType.text
//                       : const TextInputType.numberWithOptions(
//                     decimal: true,
//                   ),
//
//                   enableInteractiveSelection: isEditableField(key),
//
//                   showCursor: isEditableField(key),
//
//                   canRequestFocus: isEditableField(key),
//
//                   textAlign: TextAlign.left,
//
//                   style: TextStyle(
//                     color: editable ? Colors.black : Colors.black54,
//                     fontSize: 12,
//                     fontWeight: FontWeight.w600,
//                   ),
//
//                   /// SAME FUNCTIONALITY
//                   onTap: () {
//                     if (isRemarksField) return;
//
//                     if (controller.text == "0" ||
//                         controller.text == "0.0" ||
//                         controller.text == "0.00") {
//                       controller.clear();
//                     } else {
//                       controller.selection = TextSelection(
//                         baseOffset: 0,
//                         extentOffset: controller.text.length,
//                       );
//                     }
//                   },
//
//                   onEditingComplete: () {
//                     if (!isRemarksField && controller.text.isEmpty) {
//                       controller.text = "0";
//                     }
//
//                     FocusScope.of(context).unfocus();
//                   },
//
//                   /// SAME CALCULATION
//                   onChanged: (val) {
//                     item[key] = val;
//
//                     // 🔥 source cartItems ma pan sync karo (jo aa cart item hoy to)
//                     if (item["source"] == "sale") {
//                       final cartIndex = cartItems.indexWhere(
//                             (c) => c["itemset_id"]?.toString() == item["itemset_id"]?.toString(),
//                       );
//                       if (cartIndex != -1) {
//                         cartItems[cartIndex][key] = val;
//                       }
//                     }
//
//                     calculateItem(item);
//                     updateFinalItems();
//                     setState(() {});
//                   },
//
//                   decoration: InputDecoration(
//                     isDense: true,
//
//                     contentPadding: EdgeInsets.only(
//                       left: 8,
//
//                       /// Buttons માટે space
//                       right:
//                       (isOtherField ||
//                           isMetalRateField ||
//                           isLabourRateField)
//                           ? 30
//                           : 8,
//
//                       top: 9,
//                       bottom: 9,
//                     ),
//
//                     border: InputBorder.none,
//
//                     enabledBorder: InputBorder.none,
//
//                     focusedBorder: InputBorder.none,
//                   ),
//                 ),
//
//                 /// =====================================================
//                 /// OTHER AMOUNT +
//                 /// =====================================================
//                 if (isOtherField)
//                   Positioned(
//                     right: 4,
//                     child: InkWell(
//                       onTap: () async {
//                         FocusManager.instance.primaryFocus?.unfocus();
//
//                         await getreturnDetails(item["id"], item);
//
//                         Future.delayed(const Duration(milliseconds: 100), () {
//                           FocusManager.instance.primaryFocus?.unfocus();
//                         });
//
//                         controller.text =
//                             item["other_amount"]?.toString() ?? "0";
//
//                         calculateItem(item);
//
//                         updateFinalItems();
//
//                         setState(() {});
//                       },
//                       borderRadius: BorderRadius.circular(4),
//                       child: Container(
//                         width: 22,
//                         height: 22,
//                         alignment: Alignment.center,
//                         decoration: BoxDecoration(
//                           color: const Color(0xffC8A96A),
//                           borderRadius: BorderRadius.circular(4),
//                         ),
//                         child: const Icon(
//                           Icons.add,
//                           size: 15,
//                           color: Colors.white,
//                         ),
//                       ),
//                     ),
//                   ),
//
//                 /// =====================================================
//                 /// METAL RATE CHECKBOX
//                 /// =====================================================
//                 if (isMetalRateField)
//                   Positioned(
//                     right: 3,
//                     child: SizedBox(
//                       height: 25,
//                       width: 25,
//                       child: Transform.scale(
//                         scale: 0.78,
//                         child: Checkbox(
//                           materialTapTargetSize:
//                           MaterialTapTargetSize.shrinkWrap,
//
//                           value:
//                           (double.tryParse(
//                             controller.text.isEmpty
//                                 ? "0"
//                                 : controller.text,
//                           ) ??
//                               0) >
//                               0,
//
//                           onChanged: (val) {
//                             setState(() {
//                               if (val == true) {
//                                 if ((double.tryParse(
//                                   controller.text.isEmpty
//                                       ? "0"
//                                       : controller.text,
//                                 ) ??
//                                     0) ==
//                                     0) {
//                                   controller.text = "1";
//
//                                   item["metal_rate"] = "1";
//                                 }
//                               } else {
//                                 controller.text = "0.00";
//
//                                 item["metal_rate"] = "0.00";
//                               }
//
//                               updateController(item, "metal_rate");
//
//                               calculateItem(item);
//
//                               updateFinalItems();
//                             });
//                           },
//                         ),
//                       ),
//                     ),
//                   ),
//
//                 /// =====================================================
//                 /// LABOUR RATE CHECKBOX
//                 /// =====================================================
//                 if (isLabourRateField)
//                   Positioned(
//                     right: 3,
//                     child: SizedBox(
//                       height: 25,
//                       width: 25,
//                       child: Transform.scale(
//                         scale: 0.78,
//                         child: Checkbox(
//                           materialTapTargetSize:
//                           MaterialTapTargetSize.shrinkWrap,
//
//                           value:
//                           (double.tryParse(
//                             controller.text.isEmpty
//                                 ? "0"
//                                 : controller.text,
//                           ) ??
//                               0) >
//                               0,
//
//                           onChanged: (val) {
//                             setState(() {
//                               if (val == false) {
//                                 controller.text = "0.00";
//
//                                 item["labour_rate"] = "0.00";
//                               } else {
//                                 if ((double.tryParse(
//                                   controller.text.isEmpty
//                                       ? "0"
//                                       : controller.text,
//                                 ) ??
//                                     0) ==
//                                     0) {
//                                   controller.clear();
//                                 }
//                               }
//
//                               updateController(item, "labour_rate");
//
//                               calculateItem(item);
//
//                               updateFinalItems();
//                             });
//                           },
//                         ),
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Future<void> searchItemsApi(String keyword) async {
//     if (keyword.isEmpty) {
//       setState(() {
//         searchResults = [];
//       });
//       return;
//     }
//
//     final response = await ApiHelper().getRequest(
//       "${ApiConstants.Approval_search}?keyword=$keyword",
//       showLoading: false,
//     );
//
//     if (response != null && response.statusCode == 200) {
//       List allResults = response.data["data"] ?? [];
//
//       // 🔥 Badha added IDs bhega karo (Manual, Scan, ane Approval mathi)
//       Set<String> addedIds = {
//         ...items.map((e) => e["id"].toString()),
//         ...cartItems.map((e) => e["itemset_id"].toString()),
//         ...approvalAddedItems.map((e) => e["itemset_id"].toString()),
//       };
//
//       setState(() {
//         // 🔥 Fakt e j result batavo je pahle thi added nathi
//         searchResults = allResults.where((resItem) {
//           return !addedIds.contains(resItem["id"].toString());
//         }).toList();
//       });
//     } else {
//       print("Search API Failed");
//     }
//   }
//
//   void addItemToCard(dynamic e) {
//     setState(() {
//       final itemsetId = e["id"]; // 🔥 IMPORTANT
//
//       // ✅ Check if item already exists in ANY list
//       bool isDuplicate =
//           items.any((item) => item["id"] == itemsetId) ||
//               approvalAddedItems.any(
//                     (item) =>
//                 item["itemset_id"] == itemsetId ||
//                     item["approval_item_id"] == itemsetId,
//               ) ||
//               cartItems.any(
//                     (item) =>
//                 item["id"] == itemsetId || item["itemset_id"] == itemsetId,
//               );
//
//       if (isDuplicate) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text("Item already added to the list"),
//             backgroundColor: Colors.orange,
//           ),
//         );
//         searchController.clear();
//         searchResults.clear();
//         return;
//       }
//
//       /// 🔥 ૧. નવો આઈટમ ઓબ્જેક્ટ તૈયાર કરો (સાચા કી-નામ સાથે)
//       Map<String, dynamic> newItem = {
//         "id": e["id"],
//         "itemset_id": e["id"],
//
//         "item_name": e["item"]?["item_name"] ?? "",
//         "item_id": e["item"]?["id"],
//
//         /// 🔥 Search API thi item aavyo che
//         /// etle dropdown na batavvo
//         "show_item_dropdown": false,
//
//         "huid": e["HUID"] ?? "",
//         "qr_code": e["qr_code"] ?? "",
//
//         "gross_weight": e["gross_weight"]?.toString() ?? "0",
//
//         "other_weight": e["other_weight"]?.toString() ?? "0",
//
//         "net_weight": e["net_weight"]?.toString() ?? "0",
//
//         "purity": e["purity"]?.toString() ?? "0",
//
//         "waste": "0",
//
//         "net_purity": e["net_purity"]?.toString() ?? "0",
//         "fine_weight": e["fine_weight"]?.toString() ?? "0",
//         "metal_rate": e["metal_rate"]?.toString() ?? "0",
//         "metal_amount": e["metal_amount"]?.toString() ?? "0",
//
//         "labour_rate": e["item"]?["labour_rate"]?.toString() ?? "0",
//
//         "labour_amount": "0",
//
//         "qty": e["qty"]?.toString() ?? "1",
//
//         "remarks": e["remarks"]?.toString() ?? "",
//
//         "other_amount": e["sale_other"]?.toString() ?? "0",
//
//         "total_amount": e["sale_other"]?.toString() ?? "0",
//
//         "expanded": false,
//       };
//
//       /// 🔥 ૨. કંટ્રોલર્સ સેટ કરો (આના વગર સમરીમાં ડેટા નહીં આવે)
//       setController(newItem, "gross_weight", newItem["gross_weight"]);
//       setController(newItem, "other_weight", newItem["other_weight"]);
//       setController(newItem, "purity", newItem["purity"]);
//       setController(newItem, "labour_rate", newItem["labour_rate"]);
//       setController(newItem, "qty", newItem["qty"]);
//       setController(newItem, "remarks", newItem["remarks"]);
//       setController(newItem, "other_amount", newItem["other_amount"]);
//       setController(newItem, "total_amount", newItem["other_amount"]);
//
//       /// 🔥 ૩. આઈટમની ગણતરી ટ્રિગર કરો
//       calculateItem(newItem);
//
//       /// 🔥 ૪. UI અને API લિસ્ટમાં ઉમેરો
//       items.add(newItem);
//
//       /// =========================================================
//       /// 🔥 NEW BLANK ROW ADD
//       /// =========================================================
//       ///
//       // Map<String, dynamic> createBlankItemRow() {
//       //   final String tempId =
//       //       "new_${DateTime.now().microsecondsSinceEpoch}";
//       //
//       //   Map<String, dynamic> newItem = {
//       //     /// Temporary unique ID
//       //     "id": tempId,
//       //     "itemset_id": null,
//       //
//       //     /// ==========================================
//       //     /// ITEM
//       //     /// ==========================================
//       //     "item": "",
//       //     "item_name": "",
//       //     "item_id": null,
//       //
//       //     /// 🔥 Fresh row = dropdown show
//       //     "show_item_dropdown": true,
//       //
//       //     /// ==========================================
//       //     /// WEIGHT
//       //     /// ==========================================
//       //     "gross_weight": "0",
//       //     "other_weight": "0",
//       //     "net_weight": "0",
//       //
//       //     /// ==========================================
//       //     /// PURITY
//       //     /// ==========================================
//       //     "purity": "0",
//       //     "waste": "0",
//       //     "outward_carat": "0",
//       //     "net_purity": "0",
//       //     "fine_weight": "0",
//       //
//       //     /// ==========================================
//       //     /// METAL
//       //     /// ==========================================
//       //     "metal_rate": "0",
//       //     "metal_amount": "0",
//       //
//       //     /// ==========================================
//       //     /// LABOUR
//       //     /// ==========================================
//       //     "labour_rate": "0",
//       //     "labour_amount": "0",
//       //
//       //     /// ==========================================
//       //     /// OTHER
//       //     /// ==========================================
//       //     "other_amount": "0",
//       //
//       //     /// ==========================================
//       //     /// TOTAL
//       //     /// ==========================================
//       //     "total_amount": "0",
//       //
//       //     /// UI
//       //     "expanded": false,
//       //
//       //     /// Optional flag
//       //     "is_fresh": true,
//       //   };
//       //
//       //   /// ==========================================
//       //   /// CONTROLLERS
//       //   /// ==========================================
//       //
//       //   setController(
//       //     newItem,
//       //     "gross_weight",
//       //     "0",
//       //   );
//       //
//       //   setController(
//       //     newItem,
//       //     "other_weight",
//       //     "0",
//       //   );
//       //
//       //   setController(
//       //     newItem,
//       //     "net_weight",
//       //     "0",
//       //   );
//       //
//       //   setController(
//       //     newItem,
//       //     "purity",
//       //     "0",
//       //   );
//       //
//       //   setController(
//       //     newItem,
//       //     "waste",
//       //     "0",
//       //   );
//       //
//       //   setController(
//       //     newItem,
//       //     "outward_carat",
//       //     "0",
//       //   );
//       //
//       //   setController(
//       //     newItem,
//       //     "net_purity",
//       //     "0",
//       //   );
//       //
//       //   setController(
//       //     newItem,
//       //     "fine_weight",
//       //     "0",
//       //   );
//       //
//       //   setController(
//       //     newItem,
//       //     "metal_rate",
//       //     "0",
//       //   );
//       //
//       //   setController(
//       //     newItem,
//       //     "metal_amount",
//       //     "0",
//       //   );
//       //
//       //   setController(
//       //     newItem,
//       //     "labour_rate",
//       //     "0",
//       //   );
//       //
//       //   setController(
//       //     newItem,
//       //     "labour_amount",
//       //     "0",
//       //   );
//       //
//       //   setController(
//       //     newItem,
//       //     "other_amount",
//       //     "0",
//       //   );
//       //
//       //   setController(
//       //     newItem,
//       //     "total_amount",
//       //     "0",
//       //   );
//       //
//       //   return newItem;
//       // }
//       //
//       // items.add(
//       //   createBlankItemRow(),
//       // );
//
//       if (!finalItems.any((item) => item["itemset_id"] == itemsetId)) {
//         finalItems.add({"itemset_id": itemsetId});
//       }
//
//       /// 🔥 ૫. ગ્લોબલ લિસ્ટ અને સમરી અપડેટ કરો
//       updateFinalItems();
//
//       /// 🔥 CLEAR SEARCH & CLOSE KEYBOARD
//       searchController.clear();
//       searchResults.clear();
//       FocusManager.instance.primaryFocus?.unfocus();
//     });
//   }
//
//   bool isProcessing = false;
//
//   String? lastCode;
//   bool isBusy = false;
//
//   Widget _buildScannerSection() {
//     double scannerSize = MediaQuery.of(context).size.width * 0.4;
//     if (MediaQuery.of(context).size.width > 600) scannerSize = 350;
//
//     return Container(
//       width: scannerSize,
//       height: scannerSize,
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(color: Colors.white10),
//       ),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(20),
//         child: MobileScanner(
//           controller: _scannerController,
//           onDetect: (barcodeCapture) async {
//             for (final barcode in barcodeCapture.barcodes) {
//               final String? code = barcode.rawValue?.trim();
//
//               if (code == null || code.isEmpty) continue;
//
//               /// એ જ QR camera સામે હોય ત્યારે વારંવાર call ટાળો
//               if (lastCode == code) continue;
//
//               /// API ચાલુ હોય ત્યારે બીજો scan નહીં
//               if (isBusy) return;
//
//               lastCode = code;
//               isBusy = true;
//
//               debugPrint("⚡ SCAN: $code");
//
//               try {
//                 /// 🔥 API પૂરી થાય ત્યાં સુધી રાહ
//                 await scanApiCall(code);
//               } finally {
//                 isBusy = false;
//
//                 /// 🔥 2 સેકન્ડ પછી એ જ QR ફરી scan થઈ શકે
//                 Future.delayed(const Duration(seconds: 2), () {
//                   if (lastCode == code) lastCode = null;
//                 });
//               }
//
//               return; // એક detect માં એક જ code
//             }
//           },
//         ),
//       ),
//     );
//   }
//
//   Widget buildUserCard(Map item) {
//     final size = MediaQuery.of(context).size;
//     final isTablet = size.width >= 600;
//
//     final itemset = item["itemset"] ?? {};
//     final itemData = itemset["item"] ?? {};
//
//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 6),
//       padding: EdgeInsets.all(isTablet ? 16 : 12),
//       decoration: BoxDecoration(
//         color: const Color(0xffFAF7F2).withOpacity(0.9),
//         borderRadius: BorderRadius.circular(15),
//         border: Border.all(color: Colors.grey.shade300),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           /// STATUS + ACTIONS ROW
//           Row(
//             children: [
//               statusChip(itemData["metal"]?.toString() ?? "-"),
//               const Spacer(),
//
//               Row(
//                 children: [
//                   premiumIconBtn(Icons.edit, Colors.blue, onTap: () {}),
//                   SizedBox(width: isTablet ? 10 : 8),
//                   premiumIconBtn(
//                     Icons.delete,
//                     Colors.red,
//                     onTap: () {
//                       setState(() {
//                         _showDeleteDialog(item);
//                       });
//                     },
//                   ),
//                 ],
//               ),
//             ],
//           ),
//
//           SizedBox(height: isTablet ? 10 : 8),
//
//           /// NAME + QR
//           Row(
//             children: [
//               SizedBox(
//                 width: 100,
//                 child: Text(
//                   itemData["item_name"] ?? "",
//                   overflow: TextOverflow.ellipsis,
//                   style: const TextStyle(
//                     fontSize: 15,
//                     color: Colors.black,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//               const Spacer(),
//               Text(
//                 itemset["qr_code"] ?? "",
//                 style: const TextStyle(
//                   fontSize: 15,
//                   color: Colors.black,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ],
//           ),
//
//           const SizedBox(height: 10),
//
//           /// ERP GRID
//           Container(
//             padding: const EdgeInsets.symmetric(vertical: 6),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               border: Border.all(color: Colors.grey.shade200, width: 1.5),
//               borderRadius: BorderRadius.circular(6),
//             ),
//             child: Column(
//               children: [
//                 _erpRow(
//                   "Gross",
//                   itemset["gross_weight"] ?? "-",
//                   "Net",
//                   (itemset["net_weight"] == "0.000" ||
//                       itemset["net_weight"] == null)
//                       ? "-"
//                       : itemset["net_weight"],
//                 ),
//                 Divider(height: 1, color: Colors.grey.shade200),
//                 _erpRow(
//                   "Purity",
//                   itemData["outward_carat"] ?? "-",
//                   "Amount",
//                   "₹ ${itemset["sale_labour_amount"] ?? 0}",
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget statusChip(String status) {
//     Color startColor;
//     Color endColor;
//     String label;
//
//     switch (status.toLowerCase()) {
//       case "gold":
//         startColor = const Color(0xffC8A96A);
//         endColor = const Color(0xffE6C58A);
//         label = "Gold";
//         break;
//
//       case "silver":
//         startColor = const Color(0xffD9534F);
//         endColor = const Color(0xffF28B82);
//         label = "Silver";
//         break;
//
//       case "platinum":
//         startColor = const Color(0xffB07A3F);
//         endColor = const Color(0xffE0A96D);
//         label = "Platinum";
//         break;
//
//       case "other":
//         startColor = const Color(0xff7B5E57);
//         endColor = const Color(0xffBCAAA4);
//         label = "Other";
//         break;
//
//       default:
//         startColor = const Color(0xff9E9E9E);
//         endColor = const Color(0xffCFCFCF);
//         label = "Unknown";
//     }
//
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(colors: [startColor, endColor]),
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: Colors.white.withOpacity(0.4), width: 0.8),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.08),
//             blurRadius: 6,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           /// dot
//           Container(
//             width: 6,
//             height: 6,
//             decoration: const BoxDecoration(
//               color: Colors.white,
//               shape: BoxShape.circle,
//             ),
//           ),
//
//           const SizedBox(width: 6),
//
//           /// label
//           Text(
//             label,
//             style: const TextStyle(
//               color: Colors.black,
//               fontWeight: FontWeight.w600,
//               fontSize: 12,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget premiumIconBtn(
//       IconData icon,
//       Color color, {
//         required VoidCallback onTap,
//       }) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(10),
//       child: Container(
//         padding: const EdgeInsets.all(6),
//         decoration: BoxDecoration(
//           color: color.withOpacity(0.12),
//           borderRadius: BorderRadius.circular(10),
//         ),
//         child: Icon(icon, color: color, size: 20),
//       ),
//     );
//   }
//
//   void _showDeleteDialog(Map user) {
//     showGeneralDialog(
//       context: context,
//       barrierLabel: "Delete",
//       barrierDismissible: true,
//       barrierColor: Colors.black.withOpacity(0.4),
//       transitionDuration: const Duration(milliseconds: 300),
//       pageBuilder: (context, anim1, anim2) {
//         final screenWidth = MediaQuery.of(context).size.width;
//
//         return BackdropFilter(
//           filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
//           child: Center(
//             child: Container(
//               width: screenWidth * 0.85,
//               padding: const EdgeInsets.all(22),
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(25),
//                 color: Colors.white.withOpacity(0.1),
//                 border: Border.all(color: Colors.white.withOpacity(0.2)),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.25),
//                     blurRadius: 20,
//                     offset: const Offset(0, 10),
//                   ),
//                 ],
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   /// 🔥 Delete Icon
//                   Container(
//                     padding: const EdgeInsets.all(14),
//                     decoration: const BoxDecoration(
//                       shape: BoxShape.circle,
//                       gradient: LinearGradient(
//                         colors: [Color(0xffff4e50), Color(0xfff00000)],
//                       ),
//                     ),
//                     child: const Icon(
//                       Icons.delete,
//                       size: 32,
//                       color: Colors.white,
//                     ),
//                   ),
//
//                   const SizedBox(height: 18),
//
//                   const Text(
//                     "Delete User?",
//                     style: TextStyle(
//                       fontSize: 20,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.white,
//                       decoration: TextDecoration.none,
//                     ),
//                   ),
//
//                   const SizedBox(height: 10),
//
//                   Text(
//                     "Are you sure you want to delete ${user["name"]}?",
//                     textAlign: TextAlign.center,
//                     style: const TextStyle(
//                       fontSize: 14,
//                       color: Colors.white70,
//                       decoration: TextDecoration.none,
//                     ),
//                   ),
//
//                   const SizedBox(height: 25),
//
//                   Row(
//                     children: [
//                       /// Cancel Button
//                       Expanded(
//                         child: ElevatedButton(
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.grey.shade800,
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                             padding: const EdgeInsets.symmetric(vertical: 12),
//                           ),
//                           onPressed: () {
//                             Navigator.pop(context);
//                           },
//                           child: const Text(
//                             "Cancel",
//                             style: TextStyle(color: Colors.white),
//                           ),
//                         ),
//                       ),
//
//                       const SizedBox(width: 12),
//
//                       /// Delete Button
//                       Expanded(
//                         child: ElevatedButton(
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: const Color(0xfff00000),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                             padding: const EdgeInsets.symmetric(vertical: 12),
//                           ),
//                           onPressed: () async {
//                             Navigator.pop(context); // close dialog
//
//                             deleteUser(user["id"].toString()); // Your API call
//                           },
//                           child: const Text(
//                             "Delete",
//                             style: TextStyle(
//                               color: Colors.white,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         );
//       },
//       transitionBuilder: (context, anim, _, child) {
//         return FadeTransition(
//           opacity: anim,
//           child: ScaleTransition(
//             scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
//             child: child,
//           ),
//         );
//       },
//     );
//   }
//
//   Future<void> deleteUser(String ID) async {
//     try {
//       final response = await ApiHelper().deleteRequest(
//         "${ApiConstants.sale_cart_remove}/$ID",
//       );
//
//       if (response?.statusCode == 200) {
//         print("✅ Deleted Successfully");
//         print("Response: ${response?.data}");
//
//         getCartItems();
//       } else {
//         print("❌ Logout failed | Status: ${response?.statusCode}");
//       }
//     } catch (e) {
//       print("❌ Logout exception: $e");
//     }
//   }
//
//   Future<void> deleteSaleItem({
//     required String saleId,
//     required String itemsetId,
//   }) async {
//     try {
//       final response = await ApiHelper().deleteRequest(
//         "/sales/$saleId/items/$itemsetId",
//       );
//
//       print("DELETE SALE ITEM RESPONSE => ${response!.data}");
//     } catch (e) {
//       print("DELETE SALE ITEM ERROR => $e");
//     }
//   }
//
//   // ============================================================
// // 🔥 SCAN INFO — QR → { approval_item_id, itemset_id }
// // ============================================================
//   final Map<String, Map<String, int>> _scanInfoByQr = {};
//
//   /// કયા Approval Person ની pending items load થઈ છે
//   String? _scanInfoLoadedFor;
//
//   String _qrKey(String qr) => qr.trim().toLowerCase();
//
//   int? _toPositiveInt(dynamic v) {
//     final int? n = int.tryParse(v?.toString() ?? "");
//     return (n != null && n > 0) ? n : null;
//   }
//
//   /// 🔥 Approval Person select હોય તો એનો id, નહીં તો null
//   int? get _approvalPersonId => _toPositiveInt(selectedApprovalUserId);
//
//   /// QR માટે approval / itemset id યાદ રાખો
//   void _rememberScanInfo(
//       String? qr, {
//         dynamic approvalItemId,
//         dynamic itemsetId,
//       }) {
//     if (qr == null || qr.trim().isEmpty) return;
//
//     final Map<String, int> info = _scanInfoByQr[_qrKey(qr)] ?? {};
//
//     final int? aid = _toPositiveInt(approvalItemId);
//     final int? isid = _toPositiveInt(itemsetId);
//
//     if (aid != null) info["approval_item_id"] = aid;
//     if (isid != null) info["itemset_id"] = isid;
//
//     if (info.isNotEmpty) _scanInfoByQr[_qrKey(qr)] = info;
//   }
//
//   /// Customer / Approval Person બદલાય ત્યારે જૂની info હટાવો
//   void _clearScanInfo() {
//     _scanInfoByQr.clear();
//     _scanInfoLoadedFor = null;
//   }
//
//   /// 🔥 Camera scan માટે: Approval Person ની pending items → map
//   Future<void> _loadApprovalScanInfo() async {
//     final int? approvalId = _approvalPersonId;
//     if (approvalId == null) return;
//     if (_scanInfoLoadedFor == approvalId.toString()) return;
//
//     try {
//       final response = await ApiHelper().getRequest(
//         "${ApiConstants.label_Approval_list}?approval_customer_id=$approvalId",
//         showLoading: false,
//       );
//
//       if (response == null || response.statusCode != 200) return;
//
//       final List list = response.data["data"] ?? [];
//
//       for (final item in list) {
//         _rememberScanInfo(
//           (item["code"] ?? item["qr_code"])?.toString(),
//           approvalItemId: item["approval_item_id"],
//           itemsetId: item["itemset_id"],
//         );
//       }
//
//       _scanInfoLoadedFor = approvalId.toString();
//       debugPrint("🔥 Approval scan info loaded => ${_scanInfoByQr.length}");
//     } catch (e) {
//       debugPrint("Approval scan info error => $e");
//     }
//   }
//
// // ============================================================
// // 🔥 SCAN API
// // ============================================================
//   Future<void> scanApiCall(String code) async {
//     /// Customer ફરજિયાત
//     final int? customerId = _toPositiveInt(selectedUserId);
//
//     if (customerId == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text("Please select Customer first"),
//           backgroundColor: Colors.red,
//         ),
//       );
//       return;
//     }
//
//     /// DEVICE ID (એક જ વાર)
//     if (deviceId == null || deviceId!.trim().isEmpty) {
//       try {
//         final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
//
//         if (Platform.isAndroid) {
//           deviceId = (await deviceInfo.androidInfo).id;
//         } else if (Platform.isIOS) {
//           deviceId = (await deviceInfo.iosInfo).identifierForVendor ?? "";
//         }
//       } catch (e) {
//         debugPrint("DeviceInfo Error => $e");
//       }
//     }
//
//     /// Camera scan: map માં ના હોય તો approval items load કરો
//     if (!_scanInfoByQr.containsKey(_qrKey(code))) {
//       await _loadApprovalScanInfo();
//       if (!mounted) return;
//     }
//
//     final Map<String, int>? info = _scanInfoByQr[_qrKey(code)];
//     final int? approvalItemId = info?["approval_item_id"];
//     final int? itemsetId = info?["itemset_id"];
//     final int? approvalCustomerId = _approvalPersonId;
//
//     final Map<String, dynamic> body = {
//       "qr_code": code,
//       "customer_id": customerId,
//       if (approvalCustomerId != null) "approval_customer_id": approvalCustomerId,
//       if (approvalItemId != null) "approval_item_id": approvalItemId,
//       if (itemsetId != null) "itemset_id": itemsetId,
//       "device_id": deviceId,
//       "voucher_session_id": voucherSessionId,
//       "device_entry_id": _generateDeviceEntryId(),
//     };
//
//     debugPrint("📤 SCAN => $body");
//
//     final response = await ApiHelper().postRequest(
//       ApiConstants.sales_add_to_cart,
//       body,
//     );
//
//     if (!mounted) return;
//
//     if (response == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text("Server Response Error"),
//           backgroundColor: Colors.red,
//         ),
//       );
//       return;
//     }
//
//     debugPrint("📥 SCAN ${response.statusCode} => ${response.data}");
//
//     final data = response.data;
//
//     if (response.statusCode == 200 && data is Map && data["success"] == true) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text("Item Scan Successfully"),
//           backgroundColor: Colors.green,
//           duration: Duration(seconds: 2),
//         ),
//       );
//
//       await getCartItems(customerId: customerId.toString());
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             (data is Map ? data["message"]?.toString() : null) ?? "Scan Failed",
//           ),
//           backgroundColor: Colors.red,
//           duration: const Duration(seconds: 2),
//         ),
//       );
//     }
//   }
//   int _cartRequestId = 0;
//   Future<void> getCartItems({String? customerId}) async {
//     final int requestId = ++_cartRequestId;
//
//     /// Parameter ના આપ્યો હોય તો હાલનો selected customer
//     final String? cid = customerId ?? selectedUserId;
//
//     String url = ApiConstants.sales_cart_items;
//     if (cid != null && cid.trim().isNotEmpty) {
//       url += "${url.contains('?') ? '&' : '?'}customer_id=$cid";
//     }
//
//     debugPrint("📤 CART URL => $url");
//
//     final response = await ApiHelper().getRequest(url);
//
//     /// વચ્ચે customer બદલાયો / screen બંધ → આ response ignore
//     if (!mounted || requestId != _cartRequestId) return;
//
//     debugPrint("Cart Raw Response: ${response?.data}");
//
//     if (response == null || response.statusCode != 200) {
//       setState(() {
//         cartItems = [];
//         updateFinalItems();
//       });
//       debugPrint("Cart API Failed");
//       return;
//     }
//
//     final List resData = response.data["data"] ?? [];
//
//     // ============================================================
//     // Edit mode: saved sale items માં જે itemset_id પહેલેથી છે,
//     // એ cart માં પણ આવે તો duplicate card ના બને
//     // ============================================================
//     final Set<String> existingItemsetIds = items
//         .map((e) => (e["itemset_id"] ?? e["id"])?.toString())
//         .where((id) => id != null && id.trim().isNotEmpty)
//         .cast<String>()
//         .toSet();
//
//     final List filteredCartData = resData.where((item) {
//       /// 🔥 Safety: API customer filter ના કરે તો અહીં filter
//       final String rowCustomer = item["customer_id"]?.toString() ?? "";
//       if (cid != null && rowCustomer.isNotEmpty && rowCustomer != cid) {
//         return false;
//       }
//
//       final String? cartItemsetId =
//       (item["itemset_id"] ?? item["itemset"]?["id"])?.toString();
//
//       if (cartItemsetId == null || cartItemsetId.trim().isEmpty) return true;
//
//       return !existingItemsetIds.contains(cartItemsetId);
//     }).toList();
//
//     // ============================================================
//     // 🔥 Refresh પહેલાં local other-charge values યાદ રાખો
//     // (નહીં તો બીજી item scan કરતાં પહેલાનો applied charge ગુમાય)
//     // ============================================================
//     final Map<String, Map<String, dynamic>> keepLocal = {};
//     for (final c in cartItems) {
//       final String? key = (c["itemset_id"] ?? c["id"])?.toString();
//       if (key == null || c["other_charge_id"] == null) continue;
//
//       keepLocal[key] = {
//         "other_charge_id": c["other_charge_id"],
//         "other_charge_detail": c["other_charge_detail"],
//         "other_amount": c["other_amount"],
//       };
//     }
//
//     setState(() {
//       cartItems = filteredCartData;
//
//       for (var item in cartItems) {
//         final itemset = item["itemset"] ?? {};
//         final itemData = itemset["item"] ?? {};
//
//         /// IDs
//         item["cart_id"] = item["id"];
//         item["id"] = item["itemset_id"] ?? item["id"];
//
//         /// APPROVAL ITEM ID
//         final int? cartApprovalId =
//         int.tryParse(item["approval_item_id"]?.toString() ?? "");
//         item["approval_item_id"] =
//         (cartApprovalId != null && cartApprovalId > 0) ? cartApprovalId : null;
//
//         /// WEIGHT
//         item["gross_weight"] =
//             (item["gross_weight"] ?? itemset["gross_weight"])?.toString() ?? "0";
//         item["other_weight"] =
//             (item["other_weight"] ?? itemset["other"])?.toString() ?? "0";
//         item["net_weight"] =
//             (item["net_weight"] ?? itemset["net_weight"])?.toString() ?? "0";
//
//         /// PURITY
//         item["purity"] =
//             (item["purity"] ?? itemData["outward_carat"])?.toString() ?? "0";
//         item["waste"] =
//             (item["waste_percent"] ?? item["waste"])?.toString() ?? "0";
//
//         /// LABOUR
//         item["labour_rate"] =
//             (item["labour_rate"] ?? itemset["sale_labour_rate"])?.toString() ??
//                 "0";
//         item["labour_amount"] =
//             (item["labour_amount"] ?? itemset["sale_labour_amount"])
//                 ?.toString() ??
//                 "0";
//
//         /// METAL
//         item["metal_rate"] = item["metal_rate"]?.toString() ?? "0";
//         item["metal_amount"] = item["metal_amount"]?.toString() ?? "0";
//
//         /// QTY / REMARKS
//         item["qty"] = item["qty"]?.toString() ?? "1";
//         item["remarks"] = item["remarks"]?.toString() ?? "";
//
//         /// OTHER / TOTAL
//         item["other_amount"] =
//             (item["other_amount"] ?? itemset["sale_other"])?.toString() ?? "0";
//         item["total_amount"] = item["total_amount"]?.toString() ?? "0";
//
//         /// 🔥 પહેલાં Apply કરેલો other charge પાછો મૂકો
//         final String? localKey = item["itemset_id"]?.toString();
//         if (localKey != null && keepLocal.containsKey(localKey)) {
//           item.addAll(keepLocal[localKey]!);
//         }
//
//         /// NAME / QR / HUID
//         item["item_name"] =
//         (item["item_name"]?.toString().trim().isNotEmpty == true)
//             ? item["item_name"]
//             : (itemData["item_name"] ?? "");
//         item["qr_code"] = item["qr_code"] ?? itemset["qr_code"] ?? "";
//         item["huid"] = item["huid"] ?? item["HUID"] ?? itemset["HUID"] ?? "";
//
//         /// CONTROLLERS
//         setController(item, "gross_weight", item["gross_weight"]);
//         setController(item, "net_weight", item["net_weight"]);
//         setController(item, "other_weight", item["other_weight"]);
//         setController(item, "purity", item["purity"]);
//         setController(item, "waste", item["waste"]);
//         setController(item, "metal_rate", item["metal_rate"]);
//         setController(item, "labour_rate", item["labour_rate"]);
//         setController(item, "qty", item["qty"]);
//         setController(item, "remarks", item["remarks"]);
//         setController(item, "other_amount", item["other_amount"].toString());
//
//         calculateItem(item);
//       }
//
//       updateFinalItems();
//     });
//
//     debugPrint("🛒 Cart Items (customer $cid): ${cartItems.length}");
//   }
//
//   void setController(Map<String, dynamic> item, String key, String value) {
//     final controller = getController(item, key);
//     controller.text = value;
//   }
//
//   void calculateItem(Map<String, dynamic> item) {
//     double gross =
//         double.tryParse(getController(item, "gross_weight").text) ?? 0;
//
//     double other =
//         double.tryParse(getController(item, "other_weight").text) ?? 0;
//
//     double net = gross - other;
//
//     double purity = double.tryParse(getController(item, "purity").text) ?? 0;
//
//     double waste = double.tryParse(getController(item, "waste").text) ?? 0;
//
//     double netPurity = purity + waste;
//
//     double fineWeight = net * (netPurity / 100);
//
//     double metalRate =
//         double.tryParse(getController(item, "metal_rate").text) ?? 0;
//
//     double labourRate =
//         double.tryParse(getController(item, "labour_rate").text) ?? 0;
//
//     double otherAmount =
//         double.tryParse(getController(item, "other_amount").text) ?? 0;
//
//     /// 🔥 METAL CHECKBOX LOGIC
//     bool isManualMetal = item["manual_metal"] ?? true;
//
//     double metalAmount;
//
//     if (!isManualMetal) {
//       /// ❌ UNCHECK → 0 FIX
//       metalAmount = 0;
//     } else {
//       /// ✅ NORMAL CALCULATION
//       metalAmount = fineWeight * metalRate;
//     }
//
//     bool isManualLabour = item["manual_labour"] ?? true;
//
//     double labourAmount;
//
//     if (!isManualLabour) {
//       labourAmount = 0;
//     } else {
//       labourAmount = net * labourRate;
//     }
//
//     //double metalAmount = net * metalRate;
//     // double labourAmount = net * labourRate;
//
//     double totalAmount = metalAmount + labourAmount + otherAmount;
//
//     /// 🔥 UPDATE ITEM
//     item["net_weight"] = net.toStringAsFixed(3);
//     item["net_purity"] = netPurity.toStringAsFixed(2);
//     item["fine_weight"] = fineWeight.toStringAsFixed(3);
//     item["metal_amount"] = metalAmount.toStringAsFixed(2);
//     item["labour_amount"] = labourAmount.toStringAsFixed(2);
//     item["total_amount"] = totalAmount.toStringAsFixed(2);
//
//     /// 🔥 UPDATE UI
//     updateController(item, "net_weight");
//     updateController(item, "net_purity");
//     updateController(item, "fine_weight");
//     updateController(item, "metal_amount");
//     updateController(item, "labour_amount");
//     updateController(item, "total_amount");
//   }
//
//   void updateController(Map item, String key) {
//     /// 🔥 FIX: itemset_id use કર
//     final uniqueKey = "${item["itemset_id"] ?? item["id"]}_$key";
//
//     if (controllers.containsKey(uniqueKey)) {
//       String newVal = item[key]?.toString() ?? "";
//
//       if (controllers[uniqueKey]!.text != newVal) {
//         controllers[uniqueKey]!.text = newVal;
//       }
//     }
//   }
//
//   Map<String, TextEditingController> controllers = {};
//
//   String? get _cartCustomerId {
//     final String approval = selectedApprovalUserId?.trim() ?? "";
//     if (approval.isNotEmpty && approval != "null") return approval;
//
//     final String customer = selectedUserId?.trim() ?? "";
//     if (customer.isNotEmpty && customer != "null") return customer;
//
//     return null;
//   }
//
//   /// 🔥 Approval Person select હોય તો એનો id (int), નહીં તો null
//   // int? get _approvalPersonId {
//   //   final String raw = selectedApprovalUserId?.trim() ?? "";
//   //   if (raw.isEmpty || raw == "null") return null;
//   //   return int.tryParse(raw);
//   // }
//
//   TextEditingController getController(Map item, String key) {
//     /// 🔥 FIX: itemset_id use કર
//     final uniqueKey = "${item["itemset_id"] ?? item["id"]}_$key";
//
//     if (!controllers.containsKey(uniqueKey)) {
//       controllers[uniqueKey] = TextEditingController(
//         text: item[key]?.toString() ?? "",
//       );
//     }
//
//     return controllers[uniqueKey]!;
//   }
//
//   bool isEditableField(String key) {
//     return [
//       "gross_weight",
//       "other_weight",
//       "purity",
//       "waste",
//       "labour_rate",
//       "metal_rate",
//       "qty",
//       "remarks",
//       //"other_amount"
//     ].contains(key);
//   }
//
//   Future<void> getreturnDetails(
//       dynamic id,
//       Map<String, dynamic> mainItem,
//       ) async {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => const Center(child: CircularProgressIndicator()),
//     );
//
//     final response = await ApiHelper().getRequest(ApiConstants.other_charge);
//
//     Navigator.pop(context);
//
//     if (response != null && response.statusCode == 200) {
//       /// 🔥 BYTES → STRING → JSON
//       final data = response.data;
//
//       final item = data["data"] is List ? data["data"][0] : data["data"];
//
//       showOtherChargesPopup(
//         mainItem, // 🔥 ORIGINAL ITEM
//         data["data"], // 🔥 API LIST
//       );
//     } else {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text("Failed to load details")));
//     }
//   }
//
//   void showOtherChargesPopup(
//       Map<String, dynamic> item,
//       List apiList,
//       ) {
//     // ============================================================
//     // 1. પહેલાં Apply કરેલી values
//     // ============================================================
//     final int? existingChargeId =
//     int.tryParse(item["other_charge_id"]?.toString() ?? "");
//     final double? existingOtherAmount =
//     double.tryParse(item["other_amount"]?.toString() ?? "");
//
//     /// Apply વખતે સાચવેલી selected charge ની edit કરેલી values
//     final Map savedDetail =
//     item["other_charge_detail"] is Map ? item["other_charge_detail"] : {};
//
//     // ============================================================
//     // 2. FORMULA MAPPING (API → dropdown value)
//     // ============================================================
//     String amtFormula(dynamic f) {
//       switch (f?.toString().toLowerCase()) {
//         case "per_quantity":
//         case "per_qty":
//           return "per_qty";
//         case "per_weight":
//           return "per_weight";
//         case "per_qty_weight":
//           return "per_qty_weight";
//         default:
//           return "flat";
//       }
//     }
//
//     /// Wt dropdown માં "per_qty_weight" option નથી
//     String wtFormula(dynamic f) {
//       final v = amtFormula(f);
//       return v == "per_qty_weight" ? "flat" : v;
//     }
//
//     // ============================================================
//     // 3. API → UI CHARGES
//     // ============================================================
//     final List<Map<String, dynamic>> charges =
//     apiList.map<Map<String, dynamic>>((e) {
//       final int chargeId = int.tryParse(e["id"]?.toString() ?? "") ?? 0;
//
//       final bool isSaved = existingChargeId != null &&
//           existingChargeId > 0 &&
//           existingChargeId == chargeId;
//
//       /// Saved હોય તો સાચવેલી value, નહીં તો API default
//       String pick(String key, dynamic fallback) =>
//           (isSaved && savedDetail[key] != null ? savedDetail[key] : fallback)
//               .toString();
//
//       return {
//         "id": e["id"],
//         "charge": e["name"] ?? "",
//         "amount": pick("amount", e["default_amount"] ?? 0),
//         "qty": pick("qty", e["quantity_pcs"] ?? 1),
//         "weight": pick("weight", e["default_weight"] ?? 0),
//         "wt_formula": pick("wt_formula", wtFormula(e["weight_formula"])),
//         "amt_formula_type":
//         pick("amt_formula_type", amtFormula(e["other_amt_formula"])),
//         "total_weight": "0.0",
//         "total_amt": "0.00",
//         "is_selected": isSaved,
//       };
//     }).toList();
//
//     // ============================================================
//     // 4. ROW CONTROLLERS
//     // ============================================================
//     final Map<int, Map<String, TextEditingController>> rowControllers = {};
//
//     for (int i = 0; i < charges.length; i++) {
//       rowControllers[i] = {
//         "amount": TextEditingController(text: charges[i]["amount"]),
//         "qty": TextEditingController(text: charges[i]["qty"]),
//         "weight": TextEditingController(text: charges[i]["weight"]),
//       };
//     }
//
//     // ============================================================
//     // 5. SINGLE CHARGE CALCULATION
//     // ============================================================
//     void calculateSingleCharge(Map<String, dynamic> c) {
//       final double amt = double.tryParse(c["amount"]?.toString() ?? "0") ?? 0;
//       final double qty = double.tryParse(c["qty"]?.toString() ?? "1") ?? 1;
//       final double weight =
//           double.tryParse(c["weight"]?.toString() ?? "0") ?? 0;
//
//       final double totalWeight =
//       c["wt_formula"] == "per_qty" ? weight * qty : weight;
//
//       c["total_weight"] = totalWeight.toStringAsFixed(2);
//
//       double totalAmt;
//       switch (c["amt_formula_type"] ?? "flat") {
//         case "per_qty":
//           totalAmt = amt * qty;
//           break;
//         case "per_weight":
//           totalAmt = amt * totalWeight;
//           break;
//         case "per_qty_weight":
//           totalAmt = amt * qty * weight;
//           break;
//         default:
//           totalAmt = amt;
//       }
//
//       c["total_amt"] = totalAmt.toStringAsFixed(2);
//     }
//
//     for (final c in charges) {
//       calculateSingleCharge(c);
//     }
//
//     // ============================================================
//     // 6. FALLBACK: id નથી પણ amount match થાય તો select
//     // ============================================================
//     if (!charges.any((c) => c["is_selected"] == true) &&
//         existingOtherAmount != null &&
//         existingOtherAmount > 0) {
//       for (final c in charges) {
//         final double t = double.tryParse(c["total_amt"].toString()) ?? 0;
//         if ((t - existingOtherAmount).abs() < 0.01) {
//           c["is_selected"] = true;
//           break;
//         }
//       }
//     }
//
//     double calcTotal() {
//       double total = 0;
//       for (final c in charges) {
//         if (c["is_selected"] == true) {
//           total += double.tryParse(c["total_amt"].toString()) ?? 0;
//         }
//       }
//       return total;
//     }
//
//     final ValueNotifier<double> totalNotifier = ValueNotifier(calcTotal());
//
//     final int initialIndex = charges.indexWhere((c) => c["is_selected"] == true);
//     final ValueNotifier<int?> selectedIndexNotifier =
//     ValueNotifier(initialIndex == -1 ? null : initialIndex);
//
//     // ============================================================
//     // 7. APPLY → item + 🔥 મૂળ cartItems બંનેમાં સાચવો
//     // ============================================================
//     void applyCharges() {
//       Map<String, dynamic>? selected;
//       for (final c in charges) {
//         if (c["is_selected"] == true) {
//           selected = c;
//           break;
//         }
//       }
//
//       final Map<String, dynamic> values = {
//         "other_charge_id": selected == null
//             ? 0
//             : (int.tryParse(selected["id"].toString()) ?? 0),
//         "other_charge_detail": selected == null
//             ? null
//             : {
//           "amount": selected["amount"],
//           "qty": selected["qty"],
//           "weight": selected["weight"],
//           "wt_formula": selected["wt_formula"],
//           "amt_formula_type": selected["amt_formula_type"],
//         },
//         "other_amount": totalNotifier.value.toStringAsFixed(2),
//       };
//
//       /// Card ને મળેલી item (cart માટે આ copy હોય છે)
//       item.addAll(values);
//
//       /// 🔥 Cart items build() માં copy થાય છે → મૂળ cartItems માં પણ સાચવો
//       final String? key = (item["itemset_id"] ?? item["id"])?.toString();
//       if (key != null) {
//         for (final c in cartItems) {
//           if ((c["itemset_id"] ?? c["id"])?.toString() == key) {
//             (c as Map).addAll(values);
//             break;
//           }
//         }
//       }
//
//       updateController(item, "other_amount");
//       calculateItem(item);
//       updateFinalItems();
//     }
//
//     // ============================================================
//     // SMALL UI HELPERS
//     // ============================================================
//     Widget headerCell(String title, double width, {bool left = false}) {
//       return SizedBox(
//         width: width,
//         child: Padding(
//           padding: EdgeInsets.symmetric(horizontal: left ? 8 : 0),
//           child: Text(
//             title,
//             textAlign: left ? TextAlign.left : TextAlign.center,
//             style: const TextStyle(
//               color: AppColors.primaryDark,
//               fontSize: 11,
//               fontWeight: FontWeight.w700,
//             ),
//           ),
//         ),
//       );
//     }
//
//     Widget numberField(TextEditingController controller, VoidCallback onChanged) {
//       return Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 3),
//         child: TextFormField(
//           controller: controller,
//           keyboardType: const TextInputType.numberWithOptions(decimal: true),
//           textAlign: TextAlign.center,
//           style: const TextStyle(
//             fontSize: 11,
//             fontWeight: FontWeight.w600,
//             color: Colors.black87,
//           ),
//           onChanged: (_) => onChanged(),
//           decoration: _premiumChargeInputDecoration(),
//         ),
//       );
//     }
//
//     Widget formulaDropdown({
//       required String value,
//       required List<DropdownMenuItem<String>> items,
//       required ValueChanged<String> onChanged,
//     }) {
//       return Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 3),
//         child: DropdownButtonFormField<String>(
//           value: items.any((e) => e.value == value) ? value : "flat",
//           isExpanded: true,
//           dropdownColor: Colors.white,
//           icon: const Icon(
//             Icons.keyboard_arrow_down_rounded,
//             color: AppColors.primaryDark,
//             size: 17,
//           ),
//           style: const TextStyle(
//             fontSize: 10.5,
//             color: Colors.black87,
//             fontWeight: FontWeight.w500,
//           ),
//           decoration: _premiumChargeInputDecoration(),
//           items: items,
//           onChanged: (v) {
//             if (v != null) onChanged(v);
//           },
//         ),
//       );
//     }
//
//     // ============================================================
//     // DIALOG
//     // ============================================================
//     showDialog(
//       context: context,
//       barrierColor: Colors.black.withOpacity(0.50),
//       builder: (dialogContext) {
//         final size = MediaQuery.of(dialogContext).size;
//         final bool isTablet = size.width >= 600;
//
//         return Dialog(
//           elevation: 0,
//           backgroundColor: Colors.transparent,
//           insetPadding: EdgeInsets.symmetric(
//             horizontal: isTablet ? 30 : 10,
//             vertical: 18,
//           ),
//           child: Container(
//             width: isTablet ? 1050 : double.infinity,
//             constraints: BoxConstraints(maxHeight: size.height * 0.88),
//             decoration: BoxDecoration(
//               color: const Color(0xffF5F8FC),
//               borderRadius: BorderRadius.circular(14),
//               border: Border.all(color: AppColors.gradientBlue.withOpacity(0.20)),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.20),
//                   blurRadius: 28,
//                   offset: const Offset(0, 10),
//                 ),
//               ],
//             ),
//             child: ClipRRect(
//               borderRadius: BorderRadius.circular(14),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   // ====================================================
//                   // HEADER
//                   // ====================================================
//                   Container(
//                     width: double.infinity,
//                     padding:
//                     const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
//                     decoration: const BoxDecoration(
//                       gradient: LinearGradient(
//                         colors: [AppColors.primaryDark, AppColors.gradientBlue],
//                         begin: Alignment.topLeft,
//                         end: Alignment.bottomRight,
//                       ),
//                     ),
//                     child: Row(
//                       children: [
//                         Container(
//                           width: 38,
//                           height: 38,
//                           alignment: Alignment.center,
//                           decoration: BoxDecoration(
//                             color: Colors.white.withOpacity(0.13),
//                             borderRadius: BorderRadius.circular(8),
//                             border: Border.all(
//                               color: Colors.white.withOpacity(0.18),
//                             ),
//                           ),
//                           child: const Icon(
//                             Icons.receipt_long_outlined,
//                             color: Colors.white,
//                             size: 20,
//                           ),
//                         ),
//                         const SizedBox(width: 10),
//                         const Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 "Other Charges",
//                                 style: TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.w700,
//                                 ),
//                               ),
//                               SizedBox(height: 2),
//                               Text(
//                                 "Manage item charges and calculation",
//                                 style: TextStyle(
//                                   color: Colors.white70,
//                                   fontSize: 10,
//                                   fontWeight: FontWeight.w500,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                         Container(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 9,
//                             vertical: 5,
//                           ),
//                           decoration: BoxDecoration(
//                             color: Colors.white.withOpacity(0.12),
//                             borderRadius: BorderRadius.circular(20),
//                           ),
//                           child: Text(
//                             "${charges.length} Charges",
//                             style: const TextStyle(
//                               color: Colors.white,
//                               fontSize: 10,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 8),
//                         Material(
//                           color: Colors.transparent,
//                           child: InkWell(
//                             onTap: () => Navigator.pop(dialogContext),
//                             borderRadius: BorderRadius.circular(8),
//                             child: Container(
//                               width: 36,
//                               height: 36,
//                               alignment: Alignment.center,
//                               decoration: BoxDecoration(
//                                 color: Colors.white.withOpacity(0.12),
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               child: const Icon(
//                                 Icons.close_rounded,
//                                 color: Colors.white,
//                                 size: 20,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//
//                   // ====================================================
//                   // BODY
//                   // ====================================================
//                   Flexible(
//                     child: SingleChildScrollView(
//                       padding: const EdgeInsets.all(12),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           /// SECTION TITLE
//                           Row(
//                             children: [
//                               Container(
//                                 width: 28,
//                                 height: 28,
//                                 alignment: Alignment.center,
//                                 decoration: BoxDecoration(
//                                   color: AppColors.gradientBlue.withOpacity(0.08),
//                                   borderRadius: BorderRadius.circular(6),
//                                 ),
//                                 child: const Icon(
//                                   Icons.tune_rounded,
//                                   size: 15,
//                                   color: AppColors.gradientBlue,
//                                 ),
//                               ),
//                               const SizedBox(width: 7),
//                               const Text(
//                                 "Charge Details",
//                                 style: TextStyle(
//                                   fontSize: 13,
//                                   fontWeight: FontWeight.w700,
//                                   color: AppColors.primaryDark,
//                                 ),
//                               ),
//                               const Spacer(),
//                               ValueListenableBuilder<int?>(
//                                 valueListenable: selectedIndexNotifier,
//                                 builder: (context, selectedIndex, _) {
//                                   return Container(
//                                     padding: const EdgeInsets.symmetric(
//                                       horizontal: 8,
//                                       vertical: 4,
//                                     ),
//                                     decoration: BoxDecoration(
//                                       color: AppColors.gradientBlue
//                                           .withOpacity(0.07),
//                                       borderRadius: BorderRadius.circular(20),
//                                     ),
//                                     child: Text(
//                                       "${selectedIndex != null ? 1 : 0} Selected",
//                                       style: const TextStyle(
//                                         color: AppColors.primaryDark,
//                                         fontSize: 9.5,
//                                         fontWeight: FontWeight.w600,
//                                       ),
//                                     ),
//                                   );
//                                 },
//                               ),
//                             ],
//                           ),
//
//                           const SizedBox(height: 8),
//
//                           /// TABLE
//                           SingleChildScrollView(
//                             scrollDirection: Axis.horizontal,
//                             child: Container(
//                               width: 700,
//                               decoration: BoxDecoration(
//                                 color: Colors.white,
//                                 borderRadius: BorderRadius.circular(8),
//                                 border: Border.all(color: AppColors.border),
//                               ),
//                               child: Column(
//                                 children: [
//                                   /// TABLE HEADER
//                                   Container(
//                                     padding:
//                                     const EdgeInsets.symmetric(vertical: 9),
//                                     decoration: BoxDecoration(
//                                       color: AppColors.gradientBlue
//                                           .withOpacity(0.08),
//                                       borderRadius: const BorderRadius.only(
//                                         topLeft: Radius.circular(7),
//                                         topRight: Radius.circular(7),
//                                       ),
//                                     ),
//                                     child: Row(
//                                       children: [
//                                         headerCell("Charge", 130, left: true),
//                                         headerCell("Amount", 90),
//                                         headerCell("Qty", 80),
//                                         headerCell("Wt Formula", 120),
//                                         headerCell("Amt Formula", 130),
//                                         headerCell("Total Amt", 90),
//                                         const SizedBox(
//                                           width: 45,
//                                           child: Center(
//                                             child: Icon(
//                                               Icons.check_circle_outline_rounded,
//                                               color: AppColors.primaryDark,
//                                               size: 16,
//                                             ),
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//
//                                   Divider(height: 1, color: AppColors.border),
//
//                                   /// ROWS
//                                   SizedBox(
//                                     height: 230,
//                                     child: ListView.separated(
//                                       padding:
//                                       const EdgeInsets.symmetric(vertical: 5),
//                                       itemCount: charges.length,
//                                       separatorBuilder: (_, __) => Divider(
//                                         height: 1,
//                                         color: AppColors.border,
//                                       ),
//                                       itemBuilder: (context, index) {
//                                         final c = charges[index];
//
//                                         return StatefulBuilder(
//                                           builder: (context, setStateRow) {
//                                             void onFieldChanged() {
//                                               c["amount"] = rowControllers[index]![
//                                               "amount"]!
//                                                   .text;
//                                               c["qty"] =
//                                                   rowControllers[index]!["qty"]!
//                                                       .text;
//                                               c["weight"] = rowControllers[index]![
//                                               "weight"]!
//                                                   .text;
//
//                                               calculateSingleCharge(c);
//                                               setStateRow(() {});
//                                               totalNotifier.value = calcTotal();
//                                             }
//
//                                             return ValueListenableBuilder<int?>(
//                                               valueListenable:
//                                               selectedIndexNotifier,
//                                               builder:
//                                                   (context, selectedIndex, _) {
//                                                 final bool selected =
//                                                     selectedIndex == index;
//
//                                                 return Container(
//                                                   padding:
//                                                   const EdgeInsets.symmetric(
//                                                     vertical: 6,
//                                                   ),
//                                                   color: selected
//                                                       ? AppColors.gradientBlue
//                                                       .withOpacity(0.025)
//                                                       : Colors.white,
//                                                   child: Row(
//                                                     children: [
//                                                       /// CHARGE NAME
//                                                       SizedBox(
//                                                         width: 130,
//                                                         child: Padding(
//                                                           padding:
//                                                           const EdgeInsets
//                                                               .symmetric(
//                                                             horizontal: 8,
//                                                           ),
//                                                           child: Row(
//                                                             children: [
//                                                               Container(
//                                                                 width: 24,
//                                                                 height: 24,
//                                                                 alignment:
//                                                                 Alignment
//                                                                     .center,
//                                                                 decoration:
//                                                                 BoxDecoration(
//                                                                   color: AppColors
//                                                                       .gradientBlue
//                                                                       .withOpacity(
//                                                                     selected
//                                                                         ? 0.12
//                                                                         : 0.06,
//                                                                   ),
//                                                                   borderRadius:
//                                                                   BorderRadius
//                                                                       .circular(
//                                                                     5,
//                                                                   ),
//                                                                 ),
//                                                                 child: Text(
//                                                                   "${index + 1}",
//                                                                   style:
//                                                                   const TextStyle(
//                                                                     color: AppColors
//                                                                         .primaryDark,
//                                                                     fontSize: 9,
//                                                                     fontWeight:
//                                                                     FontWeight
//                                                                         .w700,
//                                                                   ),
//                                                                 ),
//                                                               ),
//                                                               const SizedBox(
//                                                                 width: 5,
//                                                               ),
//                                                               Expanded(
//                                                                 child: Text(
//                                                                   c["charge"]
//                                                                       ?.toString() ??
//                                                                       "",
//                                                                   maxLines: 1,
//                                                                   overflow:
//                                                                   TextOverflow
//                                                                       .ellipsis,
//                                                                   style:
//                                                                   const TextStyle(
//                                                                     fontSize: 11,
//                                                                     fontWeight:
//                                                                     FontWeight
//                                                                         .w600,
//                                                                     color: Colors
//                                                                         .black87,
//                                                                   ),
//                                                                 ),
//                                                               ),
//                                                             ],
//                                                           ),
//                                                         ),
//                                                       ),
//
//                                                       /// AMOUNT
//                                                       SizedBox(
//                                                         width: 90,
//                                                         child: numberField(
//                                                           rowControllers[index]![
//                                                           "amount"]!,
//                                                           onFieldChanged,
//                                                         ),
//                                                       ),
//
//                                                       /// QTY
//                                                       SizedBox(
//                                                         width: 80,
//                                                         child: numberField(
//                                                           rowControllers[index]![
//                                                           "qty"]!,
//                                                           onFieldChanged,
//                                                         ),
//                                                       ),
//
//                                                       /// WT FORMULA
//                                                       SizedBox(
//                                                         width: 120,
//                                                         child: formulaDropdown(
//                                                           value: c["wt_formula"],
//                                                           items: const [
//                                                             DropdownMenuItem(
//                                                               value: "flat",
//                                                               child: Text("Flat"),
//                                                             ),
//                                                             DropdownMenuItem(
//                                                               value: "per_qty",
//                                                               child:
//                                                               Text("Per Qty"),
//                                                             ),
//                                                             DropdownMenuItem(
//                                                               value: "per_weight",
//                                                               child:
//                                                               Text("Per Wt"),
//                                                             ),
//                                                           ],
//                                                           onChanged: (v) {
//                                                             c["wt_formula"] = v;
//                                                             onFieldChanged();
//                                                           },
//                                                         ),
//                                                       ),
//
//                                                       /// AMT FORMULA
//                                                       SizedBox(
//                                                         width: 130,
//                                                         child: formulaDropdown(
//                                                           value: c[
//                                                           "amt_formula_type"],
//                                                           items: const [
//                                                             DropdownMenuItem(
//                                                               value: "flat",
//                                                               child: Text("Flat"),
//                                                             ),
//                                                             DropdownMenuItem(
//                                                               value: "per_qty",
//                                                               child:
//                                                               Text("Per Qty"),
//                                                             ),
//                                                             DropdownMenuItem(
//                                                               value: "per_weight",
//                                                               child:
//                                                               Text("Per Wt"),
//                                                             ),
//                                                             DropdownMenuItem(
//                                                               value:
//                                                               "per_qty_weight",
//                                                               child: Text(
//                                                                   "Qty × Wt"),
//                                                             ),
//                                                           ],
//                                                           onChanged: (v) {
//                                                             c["amt_formula_type"] =
//                                                                 v;
//                                                             onFieldChanged();
//                                                           },
//                                                         ),
//                                                       ),
//
//                                                       /// TOTAL AMOUNT
//                                                       SizedBox(
//                                                         width: 90,
//                                                         child: Center(
//                                                           child: Container(
//                                                             padding:
//                                                             const EdgeInsets
//                                                                 .symmetric(
//                                                               horizontal: 8,
//                                                               vertical: 6,
//                                                             ),
//                                                             decoration:
//                                                             BoxDecoration(
//                                                               color: const Color(
//                                                                   0xffEAF4FF),
//                                                               borderRadius:
//                                                               BorderRadius
//                                                                   .circular(
//                                                                   5),
//                                                               border: Border.all(
//                                                                 color: AppColors
//                                                                     .gradientBlue
//                                                                     .withOpacity(
//                                                                     0.10),
//                                                               ),
//                                                             ),
//                                                             child: Text(
//                                                               c["total_amt"] ??
//                                                                   "0",
//                                                               style:
//                                                               const TextStyle(
//                                                                 fontSize: 11,
//                                                                 fontWeight:
//                                                                 FontWeight
//                                                                     .w700,
//                                                                 color: AppColors
//                                                                     .primaryDark,
//                                                               ),
//                                                             ),
//                                                           ),
//                                                         ),
//                                                       ),
//
//                                                       /// CHECKBOX (SINGLE SELECT)
//                                                       SizedBox(
//                                                         width: 45,
//                                                         child: Transform.scale(
//                                                           scale: 0.90,
//                                                           child: Checkbox(
//                                                             value: selected,
//                                                             activeColor: AppColors
//                                                                 .gradientBlue,
//                                                             shape:
//                                                             RoundedRectangleBorder(
//                                                               borderRadius:
//                                                               BorderRadius
//                                                                   .circular(
//                                                                   4),
//                                                             ),
//                                                             onChanged: (val) {
//                                                               final prev =
//                                                                   selectedIndexNotifier
//                                                                       .value;
//                                                               if (prev != null) {
//                                                                 charges[prev][
//                                                                 "is_selected"] =
//                                                                 false;
//                                                               }
//
//                                                               if (val == true) {
//                                                                 c["is_selected"] =
//                                                                 true;
//                                                                 selectedIndexNotifier
//                                                                     .value = index;
//                                                               } else {
//                                                                 c["is_selected"] =
//                                                                 false;
//                                                                 selectedIndexNotifier
//                                                                     .value = null;
//                                                               }
//
//                                                               totalNotifier
//                                                                   .value =
//                                                                   calcTotal();
//                                                             },
//                                                           ),
//                                                         ),
//                                                       ),
//                                                     ],
//                                                   ),
//                                                 );
//                                               },
//                                             );
//                                           },
//                                         );
//                                       },
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//
//                           const SizedBox(height: 12),
//
//                           /// TOTAL SUMMARY
//                           Container(
//                             width: double.infinity,
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 12,
//                               vertical: 10,
//                             ),
//                             decoration: BoxDecoration(
//                               color: AppColors.gradientBlue.withOpacity(0.06),
//                               borderRadius: BorderRadius.circular(8),
//                               border: Border.all(
//                                 color: AppColors.gradientBlue.withOpacity(0.12),
//                               ),
//                             ),
//                             child: Row(
//                               children: [
//                                 Container(
//                                   width: 32,
//                                   height: 32,
//                                   alignment: Alignment.center,
//                                   decoration: BoxDecoration(
//                                     color:
//                                     AppColors.gradientBlue.withOpacity(0.10),
//                                     shape: BoxShape.circle,
//                                   ),
//                                   child: const Icon(
//                                     Icons.calculate_outlined,
//                                     size: 17,
//                                     color: AppColors.gradientBlue,
//                                   ),
//                                 ),
//                                 const SizedBox(width: 9),
//                                 const Expanded(
//                                   child: Text(
//                                     "Selected Charges Total",
//                                     style: TextStyle(
//                                       fontSize: 11,
//                                       color: Colors.black54,
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                   ),
//                                 ),
//                                 ValueListenableBuilder<double>(
//                                   valueListenable: totalNotifier,
//                                   builder: (context, total, _) {
//                                     return Text(
//                                       total.toStringAsFixed(2),
//                                       style: const TextStyle(
//                                         fontSize: 17,
//                                         color: AppColors.primaryDark,
//                                         fontWeight: FontWeight.w800,
//                                       ),
//                                     );
//                                   },
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//
//                   // ====================================================
//                   // BOTTOM BAR
//                   // ====================================================
//                   Container(
//                     width: double.infinity,
//                     padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       border: Border(top: BorderSide(color: AppColors.border)),
//                     ),
//                     child: Row(
//                       children: [
//                         /// CANCEL
//                         Expanded(
//                           child: SizedBox(
//                             height: 42,
//                             child: OutlinedButton(
//                               onPressed: () {
//                                 FocusManager.instance.primaryFocus?.unfocus();
//                                 Navigator.pop(dialogContext);
//                               },
//                               style: OutlinedButton.styleFrom(
//                                 side: BorderSide(color: AppColors.border),
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(7),
//                                 ),
//                               ),
//                               child: const Text(
//                                 "Cancel",
//                                 style: TextStyle(
//                                   color: Colors.black87,
//                                   fontSize: 12,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ),
//
//                         const SizedBox(width: 10),
//
//                         /// APPLY
//                         Expanded(
//                           flex: 2,
//                           child: SizedBox(
//                             height: 42,
//                             child: Material(
//                               color: Colors.transparent,
//                               child: InkWell(
//                                 borderRadius: BorderRadius.circular(7),
//                                 onTap: () {
//                                   FocusManager.instance.primaryFocus?.unfocus();
//                                   applyCharges();
//                                   Navigator.pop(dialogContext);
//                                   if (mounted) setState(() {});
//                                 },
//                                 child: Ink(
//                                   decoration: BoxDecoration(
//                                     gradient: const LinearGradient(
//                                       colors: [
//                                         AppColors.primaryDark,
//                                         AppColors.gradientBlue,
//                                       ],
//                                     ),
//                                     borderRadius: BorderRadius.circular(7),
//                                     boxShadow: [
//                                       BoxShadow(
//                                         color: AppColors.gradientBlue
//                                             .withOpacity(0.20),
//                                         blurRadius: 7,
//                                         offset: const Offset(0, 3),
//                                       ),
//                                     ],
//                                   ),
//                                   child: const Row(
//                                     mainAxisAlignment: MainAxisAlignment.center,
//                                     children: [
//                                       Icon(
//                                         Icons.check_circle_outline_rounded,
//                                         color: Colors.white,
//                                         size: 17,
//                                       ),
//                                       SizedBox(width: 6),
//                                       Text(
//                                         "Apply Charges",
//                                         style: TextStyle(
//                                           color: Colors.white,
//                                           fontSize: 12.5,
//                                           fontWeight: FontWeight.w700,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         );
//       },
//     ).then((_) {
//       /// 🔥 Dialog બંધ થયા પછી (Apply / Cancel / ❌ / બહાર tap — ગમે તે રીતે)
//       /// close animation પૂરું થાય એટલે controllers dispose
//       Future.delayed(const Duration(milliseconds: 400), () {
//         for (final ctrls in rowControllers.values) {
//           for (final c in ctrls.values) {
//             c.dispose();
//           }
//         }
//         totalNotifier.dispose();
//         selectedIndexNotifier.dispose();
//       });
//     });
//   }
//
//
//
//
//   void printFinalData() {
//     List<Map<String, dynamic>> finalData = items.map((item) {
//       return {
//         "itemset_id": item["id"],
//         "gross_weight": getController(item, "gross_weight").text,
//         "other_weight": getController(item, "other_weight").text,
//         "net_weight": getController(item, "net_weight").text,
//         "metal_rate": getController(item, "metal_rate").text,
//         "labour_rate": getController(item, "labour_rate").text,
//         "other_amount": getController(item, "other_amount").text,
//         "metal_amount": item["metal_amount"],
//         "labour_amount": item["labour_amount"],
//         "total_amount": item["total_amount"],
//       };
//     }).toList();
//
//     print("🔥 FINAL ARRAY: $finalData");
//   }
//
//   // void updateFinalItems() {
//   //   List<Map<String, dynamic>> updatedList = [];
//   //
//   //   /// 🔹 Manual Items
//   //   for (var item in items) {
//   //     if (item["id"] != null) {
//   //       updatedList.add(buildItemData(item, "manual"));
//   //     }
//   //   }
//   //
//   //   /// 🔹 Approval Items
//   //   for (var item in approvalAddedItems) {
//   //     if (item["itemset_id"] != null && item["approval_item_id"] != null) {
//   //       /// 🔥 Duplicate avoid (same itemset_id + approval_id)
//   //       bool alreadyExists = updatedList.any(
//   //         (e) =>
//   //             e["itemset_id"] == item["itemset_id"] &&
//   //             e["approval_item_id"] == item["approval_item_id"],
//   //       );
//   //
//   //       if (!alreadyExists) {
//   //         updatedList.add(buildItemData(item, "approval"));
//   //       }
//   //     }
//   //   }
//   //
//   //   /// 🔹 Scanner Items (Cart Items) - અહીં સુધારો છે
//   //   for (var item in cartItems) {
//   //     // Scan આઈટમમાં ક્યારેક id હોય છે તો ક્યારેક itemset_id
//   //     var currentId = (item["itemset_id"] ?? item["id"]).toString();
//   //
//   //     if (currentId != "null") {
//   //       bool alreadyExists = updatedList.any(
//   //         (e) => (e["itemset_id"] ?? e["id"]).toString() == currentId,
//   //       );
//   //
//   //       if (!alreadyExists) {
//   //         // 🔥 buildItemData ને "Scan" સોર્સ આપો
//   //         updatedList.add(buildItemData(item, "Scan"));
//   //       }
//   //     }
//   //   }
//   //
//   //   // finalItems = updatedList;
//   //
//   //   /// 🔥 IMPORTANT CHANGE
//   //   setState(() {
//   //     finalItems = updatedList;
//   //     uniqueItems = List.from(updatedList); // 🔥 summary mate
//   //   });
//   //   //print("🔥 LIVE FINAL ITEMS: $finalItems");
//   // }
//
//   void updateFinalItems() {
//     finalItems.clear();
//
//     /// Duplicate tracker
//     final Set<String> addedKeys = <String>{};
//
//     // ============================================================
//     // HELPERS
//     // ============================================================
//
//     /// Controller (user એ edit કરેલી value) first, પછી map value
//     String latest(Map<String, dynamic> item, String key, {String def = "0"}) {
//       try {
//         final text = getController(item, key).text.trim();
//         if (text.isNotEmpty) return text;
//       } catch (_) {}
//
//       final value = item[key]?.toString().trim() ?? "";
//       return (value.isEmpty || value == "null") ? def : value;
//     }
//
//     double num(Map<String, dynamic> item, String key) =>
//         double.tryParse(latest(item, key)) ?? 0;
//
//     int? toId(dynamic v) {
//       final id = int.tryParse(v?.toString() ?? "");
//       return (id != null && id > 0) ? id : null;
//     }
//
//     String? uniqueKey({
//       int? itemId,
//       int? itemsetId,
//       int? approvalItemId,
//       String qrCode = "",
//       String huid = "",
//     }) {
//       if (itemsetId != null) return "ITEMSET_$itemsetId";
//       if (approvalItemId != null) return "APPROVAL_$approvalItemId";
//       if (qrCode.isNotEmpty) return "QR_${qrCode.toLowerCase()}";
//       if (huid.isNotEmpty) return "HUID_${huid.toLowerCase()}";
//       if (itemId != null) return "ITEM_$itemId";
//       return null;
//     }
//
//     // ============================================================
//     // SINGLE ITEM → FINAL PAYLOAD (manual / approval / cart — બધા માટે)
//     // ============================================================
//
//     void addFinal(Map<String, dynamic> item, String source) {
//       final int? itemId = toId(item["item_id"] ?? item["selected_item_id"]);
//       final int? itemsetId = toId(item["itemset_id"] ?? item["item_set_id"]);
//       final int? approvalItemId = toId(item["approval_item_id"]);
//
//       final String qrCode =
//       (item["qr_code"] ?? item["code"] ?? "").toString().trim();
//       final String huid =
//       (item["huid"] ?? item["HUID"] ?? "").toString().trim();
//
//       if (itemId == null &&
//           itemsetId == null &&
//           approvalItemId == null &&
//           qrCode.isEmpty &&
//           huid.isEmpty) {
//         debugPrint("⚠️ [$source] SKIPPED => કોઈ id / QR / HUID નથી");
//         return;
//       }
//
//       final String? key = uniqueKey(
//         itemId: itemId,
//         itemsetId: itemsetId,
//         approvalItemId: approvalItemId,
//         qrCode: qrCode,
//         huid: huid,
//       );
//
//       if (key != null) {
//         if (addedKeys.contains(key)) {
//           debugPrint("🚫 [$source] DUPLICATE SKIPPED => $key");
//           return;
//         }
//         addedKeys.add(key);
//       }
//
//       final double otherWeight = num(item, "other_weight");
//       final double waste = num(item, "waste");
//       final double labourAmount = num(item, "labour_amount");
//
//       final String itemName = (item["item_name"]?.toString().trim().isNotEmpty ==
//           true)
//           ? item["item_name"].toString()
//           : (item["name"] ?? item["itemset"]?["item"]?["item_name"] ?? "")
//           .toString();
//
//       final String metal = (item["metal"] ??
//           item["itemset"]?["item"]?["metal"] ??
//           item["itemset"]?["metal"] ??
//           "")
//           .toString();
//
//       final Map<String, dynamic> finalItem = {
//         if (itemId != null) "item_id": itemId,
//         if (itemsetId != null) "itemset_id": itemsetId,
//
//         /// 🔥 approval_item_id હોય તો જ (manual / approval / cart — ત્રણેયમાં)
//         if (approvalItemId != null) "approval_item_id": approvalItemId,
//
//         if (qrCode.isNotEmpty) "qr_code": qrCode,
//         if (huid.isNotEmpty) "huid": huid,
//         "item_name": itemName,
//         "metal": metal,
//         "gross_weight": num(item, "gross_weight"),
//         "other": otherWeight,
//         "other_weight": otherWeight,
//         "net_weight": num(item, "net_weight"),
//         "purity": num(item, "purity"),
//         if (isEditMode) "waste": waste else "waste_percent": waste,
//         "outward_carat": num(item, "outward_carat"),
//         "net_purity": num(item, "net_purity"),
//         "fine_weight": num(item, "fine_weight"),
//         "metal_rate": num(item, "metal_rate"),
//         "metal_amount": num(item, "metal_amount"),
//         "labour_rate": num(item, "labour_rate"),
//         "labour_amount": labourAmount,
//         "sale_labour_amount":
//         double.tryParse(item["sale_labour_amount"]?.toString() ?? "") ??
//             labourAmount,
//         "other_amount": num(item, "other_amount"),
//         "total_amount": num(item, "total_amount"),
//         "qty": int.tryParse(latest(item, "qty", def: "1")) ?? 1,
//         "remarks": latest(item, "remarks", def: ""),
//       };
//
//       finalItems.add(finalItem);
//       debugPrint("✅ [$source] ${finalItems.length} => $finalItem");
//     }
//
//     // ============================================================
//     // ORDER: Manual → Approval → Cart
//     // (એક જ itemset બે list માં હોય તો પહેલું જીતે, બીજું skip)
//     // ============================================================
//
//     for (final e in items) {
//       addFinal(Map<String, dynamic>.from(e), "MANUAL");
//     }
//
//     for (final e in approvalAddedItems) {
//       addFinal(Map<String, dynamic>.from(e), "APPROVAL");
//     }
//
//     for (final e in cartItems) {
//       addFinal(Map<String, dynamic>.from(e), "CART");
//     }
//
//     debugPrint(
//       "🔥 FINAL ITEMS => ${finalItems.length} "
//           "(manual ${items.length}, approval ${approvalAddedItems.length}, cart ${cartItems.length})",
//     );
//   }
//
//
//   double getValue(Map item, String key) {
//     /// 🔥 FIX: id નહીં હોય તો itemset_id use કર
//     final uniqueKey = "${item["id"] ?? item["itemset_id"]}_$key";
//
//     if (controllers.containsKey(uniqueKey)) {
//       return double.tryParse(controllers[uniqueKey]!.text) ?? 0;
//     } else {
//       return double.tryParse(item[key]?.toString() ?? "0") ?? 0;
//     }
//   }
//
//   Widget buildSummaryRow() {
//     final totals = calculateTotals();
//
//     // ✅ Total Amount → Pending Amount controller માં set કરો
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       // ✅ Edit mode માં પહેલી વાર load થાય ત્યારે override ન કરો
//       // ✅ ફક્ત ત્યારે set કરો જ્યારે received amount change થાય
//       if (!isEditMode || uniqueItems.isNotEmpty) {
//         final received = double.tryParse(recived_amount_Controller.text) ?? 0;
//         final pending = totals["total"]! - received;
//         final pendingStr = pending.toStringAsFixed(2);
//
//         if (payment_pending_Controller.text != pendingStr) {
//           payment_pending_Controller.text = pendingStr;
//         }
//       }
//     });
//
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
//       decoration: BoxDecoration(
//         color: AppColors.background,
//         border: Border.all(color: AppColors.border, width: 1.5),
//         borderRadius: BorderRadius.circular(6),
//       ),
//       child: SingleChildScrollView(
//         scrollDirection: Axis.horizontal,
//         child: Row(
//           children: [
//             _summaryBox("Items", "${uniqueItems.length}"),
//             _summaryBox("Gross", totals["gross"]!.toStringAsFixed(3)),
//             _summaryBox("Other", totals["other"]!.toStringAsFixed(3)),
//             _summaryBox("Net", totals["net"]!.toStringAsFixed(3)),
//
//             // _summaryBox("Purity", totals["purity"]!.toStringAsFixed(2)),
//             // _summaryBox("Waste", totals["waste"]!.toStringAsFixed(2)),
//             // _summaryBox("Net Purity", totals["netPurity"]!.toStringAsFixed(2)),
//
//             _summaryBox("Fine", totals["fine"]!.toStringAsFixed(3)),
//
//             _summaryBox("Metal Rate", totals["metalRate"]!.toStringAsFixed(2)),
//             _summaryBox("Metal Amt", totals["metal"]!.toStringAsFixed(2)),
//
//             _summaryBox(
//               "Labour Rate",
//               totals["labourRate"]!.toStringAsFixed(2),
//             ),
//             _summaryBox("Labour Amt", totals["labour"]!.toStringAsFixed(2)),
//
//             _summaryBox("Other Amt", totals["otherAmt"]!.toStringAsFixed(2)),
//             _summaryBox("Total", totals["total"]!.toStringAsFixed(2)),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Map<String, double> calculateTotals() {
//     double gross = 0;
//     double other = 0;
//     double net = 0;
//     double purity = 0;
//     double waste = 0;
//     double netPurity = 0;
//     double fine = 0;
//     double metalRate = 0;
//     double metal = 0;
//     double labourRate = 0;
//     double labour = 0;
//     double otherAmt = 0;
//     double total = 0;
//
//     for (var item in uniqueItems) {
//       gross += double.tryParse(item["gross_weight"]?.toString() ?? "0") ?? 0;
//       other += double.tryParse(item["other_weight"]?.toString() ?? "0") ?? 0;
//       net += double.tryParse(item["net_weight"]?.toString() ?? "0") ?? 0;
//
//       purity += double.tryParse(item["purity"]?.toString() ?? "0") ?? 0;
//       waste += double.tryParse(item["waste"]?.toString() ?? "0") ?? 0;
//       netPurity += double.tryParse(item["net_purity"]?.toString() ?? "0") ?? 0;
//
//       fine += double.tryParse(item["fine_weight"]?.toString() ?? "0") ?? 0;
//       metalRate += double.tryParse(item["metal_rate"]?.toString() ?? "0") ?? 0;
//
//       /// 🔥 IMPORTANT (ONLY SUM)
//       metal += double.tryParse(item["metal_amount"]?.toString() ?? "0") ?? 0;
//
//       labourRate +=
//           double.tryParse(item["labour_rate"]?.toString() ?? "0") ?? 0;
//       labour += double.tryParse(item["labour_amount"]?.toString() ?? "0") ?? 0;
//
//       otherAmt += double.tryParse(item["other_amount"]?.toString() ?? "0") ?? 0;
//       total += double.tryParse(item["total_amount"]?.toString() ?? "0") ?? 0;
//     }
//
//     return {
//       "gross": gross,
//       "other": other,
//       "net": net,
//       "purity": purity,
//       "waste": waste,
//       "netPurity": netPurity,
//       "fine": fine,
//       "metalRate": metalRate,
//       "metal": metal, // ✅ ONLY SUM
//       "labourRate": labourRate,
//       "labour": labour,
//       "otherAmt": otherAmt,
//       "total": total,
//     };
//   }
//
//   Widget _summaryBox(String title, String value) {
//     return Container(
//       width: 90,
//       margin: const EdgeInsets.only(right: 8),
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(6),
//         border: Border.all(color: Colors.grey.shade300),
//       ),
//       child: Column(
//         children: [
//           Text(
//             title,
//             style: const TextStyle(fontSize: 11, color: Colors.black54),
//           ),
//           const SizedBox(height: 4),
//           Text(
//             value,
//             style: const TextStyle(
//               fontSize: 13,
//               fontWeight: FontWeight.bold,
//               color: Colors.black,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _balanceBox({required String title, required String amount}) {
//     return Container(
//       padding: const EdgeInsets.only(left: 10, right: 10, top: 6, bottom: 6),
//       decoration: BoxDecoration(
//         color: const Color(0xff2C3148),
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: Colors.white24),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title,
//             style: const TextStyle(
//               color: Colors.white70,
//               fontSize: 13,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//
//           const SizedBox(height: 8),
//
//           Text(
//             amount,
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 20,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _premiumFieldWrapper({required String label, required Widget child}) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Padding(
//           padding: const EdgeInsets.only(left: 1, bottom: 5),
//           child: Text(
//             label,
//             style: const TextStyle(
//               fontSize: 12,
//               fontWeight: FontWeight.w500,
//               color: Colors.black54,
//             ),
//           ),
//         ),
//         child,
//       ],
//     );
//   }
//
//   InputDecoration _premiumInputDecoration({
//     String? hint,
//     Widget? prefixIcon,
//     Widget? suffixIcon,
//     bool readOnly = false,
//   }) {
//     return InputDecoration(
//       hintText: hint,
//
//       hintStyle: const TextStyle(
//         color: Colors.black38,
//         fontSize: 13,
//         fontWeight: FontWeight.w400,
//       ),
//
//       prefixIcon: prefixIcon,
//       suffixIcon: suffixIcon,
//
//       filled: true,
//
//       fillColor: readOnly ? const Color(0xffF5F5F5) : Colors.white,
//
//       isDense: true,
//
//       contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
//
//       border: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(5),
//         borderSide: BorderSide(color: AppColors.border),
//       ),
//
//       enabledBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(5),
//         borderSide: BorderSide(color: AppColors.border),
//       ),
//
//       focusedBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(5),
//         borderSide: BorderSide(color: AppColors.gradientBlue, width: 1.2),
//       ),
//     );
//   }
//
//   Widget _premiumReadOnlyBox({
//     required String title,
//     required String value,
//     String? type,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Padding(
//           padding: const EdgeInsets.only(left: 1, bottom: 5),
//           child: Row(
//             children: [
//               Flexible(
//                 child: Text(
//                   title,
//                   overflow: TextOverflow.ellipsis,
//                   style: const TextStyle(
//                     fontSize: 12,
//                     fontWeight: FontWeight.w500,
//                     color: Colors.black54,
//                   ),
//                 ),
//               ),
//
//               if (type != null) ...[
//                 const SizedBox(width: 4),
//
//                 Text(
//                   type,
//                   style: TextStyle(
//                     fontSize: 10,
//                     fontWeight: FontWeight.w600,
//                     color: type == "Credit"
//                         ? Colors.green.shade700
//                         : Colors.red.shade700,
//                   ),
//                 ),
//               ],
//             ],
//           ),
//         ),
//
//         Container(
//           width: double.infinity,
//           height: 43,
//           padding: const EdgeInsets.symmetric(horizontal: 12),
//           alignment: Alignment.centerLeft,
//           decoration: BoxDecoration(
//             color: const Color(0xffF7F7F8),
//             borderRadius: BorderRadius.circular(5),
//             border: Border.all(color: AppColors.border),
//           ),
//           child: Text(
//             value,
//             style: const TextStyle(
//               fontSize: 13,
//               fontWeight: FontWeight.w600,
//               color: Colors.black87,
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   String _getSilverUsedFineWt(ItemProvider provider) {
//     return provider.silverUsedFineWeight.toStringAsFixed(3);
//   }
//
//   String _getSilverBalanceAfterUse(ItemProvider provider) {
//     return provider.silverBalanceAfterUse.toStringAsFixed(3);
//   }
//
//   Widget _searchResultDropdown() {
//     return Container(
//       constraints: const BoxConstraints(maxHeight: 200),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(5),
//         border: Border.all(color: AppColors.border),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.08),
//             blurRadius: 8,
//             offset: const Offset(0, 3),
//           ),
//         ],
//       ),
//       child: isLoading
//           ? const SizedBox(
//         height: 60,
//         child: Center(
//           child: SizedBox(
//             width: 22,
//             height: 22,
//             child: CircularProgressIndicator(strokeWidth: 2),
//           ),
//         ),
//       )
//           : searchResults.isEmpty
//           ? const SizedBox(
//         height: 55,
//         child: Center(
//           child: Text(
//             "No items found",
//             style: TextStyle(color: Colors.black45, fontSize: 12),
//           ),
//         ),
//       )
//           : ListView.separated(
//         shrinkWrap: true,
//         padding: EdgeInsets.zero,
//         itemCount: searchResults.length,
//
//         separatorBuilder: (_, __) {
//           return Divider(height: 1, color: Colors.grey.shade200);
//         },
//
//         itemBuilder: (context, index) {
//           final item = searchResults[index];
//
//           final itemName = item["item"]?["item_name"] ?? "Item";
//
//           final huid = item["HUID"] ?? "-";
//
//           final qr = item["qr_code"] ?? "-";
//
//           return InkWell(
//             onTap: () async {
//               FocusManager.instance.primaryFocus?.unfocus();
//
//               final String? qrCode = item["qr_code"]?.toString();
//
//               if (qrCode == null || qrCode.trim().isEmpty) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(
//                     content: Text("This item has no QR code"),
//                     backgroundColor: Colors.red,
//                   ),
//                 );
//                 return;
//               }
//
//               /// 🔥 IMPORTANT: existing scanApiCall() flow reuse karo —
//               /// server par cart add (sales_add_to_cart API) +
//               /// getCartItems() refresh + delete-ready state (source:
//               /// "sale") automatically male che. addItemToCard() (local
//               /// only) na badle have aa j vaparvanu.
//               await scanApiCall(qrCode);
//
//               if (!mounted) return;
//
//               // searchController.clear();
//
//               setState(() {
//                 searchResults.removeWhere(
//                       (e) => e["id"]?.toString() == item["id"]?.toString(),
//                 );
//               });
//             },
//
//             child: Padding(
//               padding: const EdgeInsets.symmetric(
//                 horizontal: 12,
//                 vertical: 9,
//               ),
//
//               child: Row(
//                 children: [
//                   Container(
//                     width: 32,
//                     height: 32,
//                     decoration: BoxDecoration(
//                       color: AppColors.primaryDark.withOpacity(0.08),
//                       borderRadius: BorderRadius.circular(5),
//                     ),
//                     child: const Icon(
//                       Icons.inventory_2_outlined,
//                       size: 17,
//                       color: Colors.black54,
//                     ),
//                   ),
//
//                   const SizedBox(width: 10),
//
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           itemName,
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                           style: const TextStyle(
//                             fontSize: 13,
//                             fontWeight: FontWeight.w600,
//                             color: Colors.black87,
//                           ),
//                         ),
//
//                         const SizedBox(height: 2),
//
//                         Text(
//                           "HUID: $huid  •  QR: $qr",
//                           style: const TextStyle(
//                             fontSize: 10,
//                             color: Colors.black45,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//
//                   const Icon(
//                     Icons.add_circle_outline_rounded,
//                     size: 20,
//                     color: Colors.black54,
//                   ),
//                 ],
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     searchController.dispose();
//     recived_amount_Controller.dispose();
//     payment_ref_Controller.dispose();
//     payment_pending_Controller.dispose();
//     remarksController.dispose();
//     add_payment_Controller.dispose();
//     searchFocusNode.dispose();
//     _scannerController.dispose();
//     for (var c in controllers.values) {
//       c.dispose();
//     }
//     _huidTimer?.cancel();
//     super.dispose();
//   }
//
//   Widget _labourDropdown(Map<String, dynamic> item) {
//     final provider = Provider.of<ItemProvider>(context, listen: false);
//
//     final String selectedValue = (item["item"] ?? item["item_name"] ?? "")
//         .toString();
//
//     Map<String, dynamic>? selectedItemData;
//
//     /// ============================================================
//     /// CURRENT SELECTED ITEM FIND
//     /// ============================================================
//
//     if (selectedValue.isNotEmpty) {
//       for (final rawData in provider.items) {
//         final Map<String, dynamic> data = Map<String, dynamic>.from(rawData);
//
//         if ((data["item_name"] ?? "").toString().trim().toLowerCase() ==
//             selectedValue.trim().toLowerCase()) {
//           selectedItemData = data;
//           break;
//         }
//       }
//     }
//
//     final List<Map<String, dynamic>> allItems = provider.items
//         .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
//         .toList();
//
//     /// ============================================================
//     /// 🔥 DROPDOWN (BORDER સાથે)
//     /// ============================================================
//
//     return _miniDropdownBox(
//       title: "Item Name",
//       width: 155,
//       text: selectedItemData?["item_name"]?.toString() ?? selectedValue,
//       hint: "Select Item",
//       onTap: () async {
//         final Map<String, dynamic>? selectedItem = await _openSearchSheet(
//           title: "Item",
//           icon: Icons.category_outlined,
//           items: allItems,
//           selectedId: selectedItemData?["id"]?.toString(),
//
//           /// DISPLAY
//           labelOf: (data) => data["item_name"]?.toString() ?? "-",
//
//           /// SUB TEXT
//           subtitleOf: (data) {
//             final code = data["item_code"]?.toString() ?? "";
//             return (code.isEmpty || code == "null") ? "" : "Code: $code";
//           },
//
//           /// SEARCH
//           searchOf: (data) => [
//             data["item_name"]?.toString() ?? "",
//             data["item_code"]?.toString() ?? "",
//             data["metal"]?.toString() ?? "",
//             data["id"]?.toString() ?? "",
//           ].join(" "),
//         );
//
//         if (selectedItem == null || !mounted) return;
//
//         /// ========================================================
//         /// MASTER ITEM VALUES
//         /// ========================================================
//
//         final String itemName = selectedItem["item_name"]?.toString() ?? "";
//
//         final String outwardCarat =
//             selectedItem["outward_carat"]?.toString() ?? "0";
//
//         final String outwardPurity =
//             selectedItem["outward_purity"]?.toString() ?? "0";
//
//         final String labourRate =
//             selectedItem["labour_rate"]?.toString() ?? "0";
//
//         setState(() {
//           /// BASIC ITEM DATA
//           item["item_id"] = selectedItem["id"];
//           item["item"] = itemName;
//           item["item_name"] = itemName;
//           item["company_id"] = selectedItem["company_id"];
//           item["item_code"] = selectedItem["item_code"];
//           item["metal"] = selectedItem["metal"];
//
//           /// PURITY / CARAT
//           item["outward_carat"] = selectedItem["outward_carat"];
//           item["inward_carat"] = selectedItem["inward_carat"];
//           item["outward_purity"] = selectedItem["outward_purity"];
//           item["inward_purity"] = selectedItem["inward_purity"];
//
//           /// FORMULA
//           item["metal_formula"] = selectedItem["metal_formula"];
//           item["issue_type"] = selectedItem["issue_type"];
//           item["jobwork_item_type"] = selectedItem["jobwork_item_type"];
//
//           /// LABOUR
//           item["labour_type"] = selectedItem["labour_type"];
//           item["labour_rate"] = selectedItem["labour_rate"] ?? "0";
//           item["labour_unit"] = selectedItem["labour_unit"];
//
//           /// TAX / HSN
//           item["tax_type"] = selectedItem["tax_type"];
//           item["hsn"] = selectedItem["hsn"];
//           item["sac_code"] = selectedItem["sac_code"];
//           item["export_hsn"] = selectedItem["export_hsn"];
//
//           /// CONFIGURATION
//           item["auto_load_purity"] = selectedItem["auto_load_purity"];
//           item["auto_create_label_purchase"] =
//           selectedItem["auto_create_label_purchase"];
//           item["auto_create_label_config"] =
//           selectedItem["auto_create_label_config"];
//           item["reuse"] = selectedItem["reuse"];
//           item["numeric_length"] = selectedItem["numeric_length"];
//           item["item_group"] = selectedItem["item_group"];
//           item["remarks"] = selectedItem["remarks"];
//
//           /// COMPLETE MASTER OBJECT
//           item["selected_item_data"] = Map<String, dynamic>.from(selectedItem);
//
//           /// SALE CALCULATION VALUES
//           item["purity"] = outwardCarat;
//           item["net_purity"] = outwardPurity;
//
//           /// CONTROLLERS
//           getController(item, "outward_carat").text = outwardCarat;
//           getController(item, "purity").text = outwardCarat;
//           getController(item, "net_purity").text = outwardPurity;
//           getController(item, "labour_rate").text = labourRate;
//
//           /// CALCULATION
//           calculateItem(item);
//           updateFinalItems();
//         });
//
//         debugPrint("========================================");
//         debugPrint("SELECTED MASTER ITEM => $selectedItem");
//         debugPrint("UPDATED FRESH ROW => $item");
//         debugPrint("ITEM ID => ${item["item_id"]}");
//         debugPrint("ITEM NAME => ${item["item_name"]}");
//         debugPrint("========================================");
//       },
//     );
//   }
//
//   Map<String, dynamic> createApprovalBlankItemRow() {
//     final String tempId = "fresh_${DateTime.now().microsecondsSinceEpoch}";
//
//     final Map<String, dynamic> newItem = {
//       /// =========================================================
//       /// TEMP ID
//       /// =========================================================
//       "id": tempId,
//
//       /// Actual itemset હજુ select નથી
//       "itemset_id": null,
//
//       /// Approval item નથી
//       "approval_item_id": null,
//
//       /// =========================================================
//       /// 🔥 ITEM DROPDOWN
//       /// =========================================================
//       "item": "",
//       "item_name": "",
//       "item_id": null,
//
//       /// 🔥 આ row માં જ dropdown આવશે
//       "show_item_dropdown": true,
//
//       /// ઓળખવા માટે
//       "is_fresh": true,
//
//       /// =========================================================
//       /// WEIGHT
//       /// =========================================================
//       "gross_weight": "0",
//       "other_weight": "0",
//       "net_weight": "0",
//
//       /// =========================================================
//       /// PURITY
//       /// =========================================================
//       "purity": "0",
//       "waste": "0",
//       "outward_carat": "0",
//       "net_purity": "0",
//       "fine_weight": "0",
//
//       /// =========================================================
//       /// METAL
//       /// =========================================================
//       "metal_rate": "0",
//       "metal_amount": "0",
//
//       /// =========================================================
//       /// LABOUR
//       /// =========================================================
//       "labour_rate": "0",
//       "labour_amount": "0",
//
//       /// =========================================================
//       /// QTY / REMARKS
//       /// =========================================================
//       "qty": "1",
//       "remarks": "",
//
//       /// =========================================================
//       /// OTHER
//       /// =========================================================
//       "other_amount": "0",
//
//       /// =========================================================
//       /// TOTAL
//       /// =========================================================
//       "total_amount": "0",
//
//       /// UI
//       "expanded": false,
//     };
//
//     /// ===========================================================
//     /// CONTROLLERS
//     /// ===========================================================
//
//     setController(newItem, "gross_weight", "0");
//
//     setController(newItem, "other_weight", "0");
//
//     setController(newItem, "net_weight", "0");
//
//     setController(newItem, "purity", "0");
//
//     setController(newItem, "waste", "0");
//
//     setController(newItem, "outward_carat", "0");
//
//     setController(newItem, "net_purity", "0");
//
//     setController(newItem, "fine_weight", "0");
//
//     setController(newItem, "metal_rate", "0");
//
//     setController(newItem, "metal_amount", "0");
//
//     setController(newItem, "labour_rate", "0");
//
//     setController(newItem, "labour_amount", "0");
//
//     setController(newItem, "qty", "1");
//
//     setController(newItem, "remarks", "");
//
//     setController(newItem, "other_amount", "0");
//
//     setController(newItem, "total_amount", "0");
//
//     return newItem;
//   }
//
//   Map<String, dynamic> createBlankItemRow() {
//     final String tempId =
//         "new_${DateTime.now().microsecondsSinceEpoch}";
//
//     final Map<String, dynamic> newItem = {
//       // ==========================================
//       // ID
//       // ==========================================
//       "id": tempId,
//       "itemset_id": null,
//
//       // ==========================================
//       // ITEM
//       // ==========================================
//       "item": "",
//       "item_name": "",
//       "item_id": null,
//
//       // Fresh manual row
//       "show_item_dropdown": true,
//       "is_fresh": true,
//
//       // ==========================================
//       // WEIGHT
//       // ==========================================
//       "gross_weight": "0",
//       "other_weight": "0",
//       "net_weight": "0",
//
//       // ==========================================
//       // PURITY
//       // ==========================================
//       "purity": "0",
//       "waste": "0",
//       "outward_carat": "0",
//       "net_purity": "0",
//       "fine_weight": "0",
//
//       // ==========================================
//       // METAL
//       // ==========================================
//       "metal_rate": "0",
//       "metal_amount": "0",
//
//       // ==========================================
//       // LABOUR
//       // ==========================================
//       "labour_rate": "0",
//       "labour_amount": "0",
//
//       // ==========================================
//       // QTY / REMARKS
//       // ==========================================
//       "qty": "1",
//       "remarks": "",
//
//       // ==========================================
//       // OTHER
//       // ==========================================
//       "other_amount": "0",
//
//       // ==========================================
//       // TOTAL
//       // ==========================================
//       "total_amount": "0",
//
//       // ==========================================
//       // UI
//       // ==========================================
//       "expanded": false,
//     };
//
//     // ==========================================
//     // CONTROLLERS
//     // ==========================================
//     setController(newItem, "gross_weight", "0");
//     setController(newItem, "other_weight", "0");
//     setController(newItem, "net_weight", "0");
//
//     setController(newItem, "purity", "0");
//     setController(newItem, "waste", "0");
//     setController(newItem, "outward_carat", "0");
//     setController(newItem, "net_purity", "0");
//     setController(newItem, "fine_weight", "0");
//
//     setController(newItem, "metal_rate", "0");
//     setController(newItem, "metal_amount", "0");
//
//     setController(newItem, "labour_rate", "0");
//     setController(newItem, "labour_amount", "0");
//
//     setController(newItem, "qty", "1");
//     setController(newItem, "remarks", "");
//
//     setController(newItem, "other_amount", "0");
//     setController(newItem, "total_amount", "0");
//
//     return newItem;
//   }
//
//   // Future<void> applyRateToAllItems({
//   //   required Map<String, dynamic> sourceItem,
//   //   required String key,
//   // }) async {
//   //   FocusManager.instance.primaryFocus?.unfocus();
//   //
//   //   final String value = getController(sourceItem, key).text.trim();
//   //
//   //   final double rate = double.tryParse(value) ?? 0;
//   //
//   //   debugPrint("==============================================");
//   //   debugPrint("🔥 APPLY RATE TO ALL");
//   //   debugPrint("KEY => $key");
//   //   debugPrint("RATE => $rate");
//   //   debugPrint("items => ${items.length}");
//   //   debugPrint("approvalAddedItems => ${approvalAddedItems.length}");
//   //   debugPrint("cartItems => ${cartItems.length}");
//   //   debugPrint("==============================================");
//   //
//   //   // ============================================================
//   //   // NORMAL ITEMS
//   //   // ============================================================
//   //
//   //   for (final item in items) {
//   //     item[key] = rate.toString();
//   //
//   //     if (key == "metal_rate") {
//   //       item["manual_metal"] = true;
//   //     }
//   //
//   //     if (key == "labour_rate") {
//   //       item["manual_labour"] = true;
//   //     }
//   //
//   //     final controller = getController(item, key);
//   //
//   //     controller.text = rate.toString();
//   //
//   //     calculateItem(item);
//   //   }
//   //
//   //   // ============================================================
//   //   // APPROVAL ITEMS
//   //   // ============================================================
//   //
//   //   for (final item in approvalAddedItems) {
//   //     item[key] = rate.toString();
//   //
//   //     if (key == "metal_rate") {
//   //       item["manual_metal"] = true;
//   //     }
//   //
//   //     if (key == "labour_rate") {
//   //       item["manual_labour"] = true;
//   //     }
//   //
//   //     final controller = getController(item, key);
//   //
//   //     controller.text = rate.toString();
//   //
//   //     calculateItem(item);
//   //   }
//   //
//   //   // ============================================================
//   //   // CART ITEMS
//   //   // ============================================================
//   //
//   //   for (final item in cartItems) {
//   //     item[key] = rate.toString();
//   //
//   //     if (key == "metal_rate") {
//   //       item["manual_metal"] = true;
//   //     }
//   //
//   //     if (key == "labour_rate") {
//   //       item["manual_labour"] = true;
//   //     }
//   //
//   //     final controller = getController(item, key);
//   //
//   //     controller.text = rate.toString();
//   //
//   //     calculateItem(item);
//   //
//   //     debugPrint(
//   //       "✅ CART => "
//   //           "itemset=${item["itemset_id"]} "
//   //           "$key=$rate "
//   //           "metalAmount=${item["metal_amount"]} "
//   //           "labourAmount=${item["labour_amount"]} "
//   //           "total=${item["total_amount"]}",
//   //     );
//   //   }
//   //
//   //   // ============================================================
//   //   // FINAL PAYLOAD UPDATE
//   //   // ============================================================
//   //
//   //   updateFinalItems();
//   //
//   //   if (!mounted) return;
//   //
//   //   setState(() {});
//   //
//   //   debugPrint("==============================================");
//   //   debugPrint("✅ APPLY RATE TO ALL COMPLETED");
//   //   debugPrint("==============================================");
//   // }
//
//
//
//   Future<void> applyRateToAllItems({
//     required Map<String, dynamic> sourceItem,
//     required String key,
//   }) async {
//     FocusManager.instance.primaryFocus?.unfocus();
//
//     final sourceController = getController(sourceItem, key);
//     final String value = sourceController.text.trim().isEmpty
//         ? "0"
//         : sourceController.text.trim();
//
//     int updatedCount = 0;
//
//     /// ============================================================
//     /// MANUAL ITEMS
//     /// ============================================================
//     for (final item in items) {
//       final controller = getController(item, key);
//       controller.text = value;
//       item[key] = value;
//
//       if (key == "metal_rate") item["manual_metal"] = true;
//       if (key == "labour_rate") item["manual_labour"] = true;
//
//       calculateItem(item);
//       updatedCount++;
//     }
//
//     /// ============================================================
//     /// APPROVAL ITEMS
//     /// ============================================================
//     for (final item in approvalAddedItems) {
//       final controller = getController(item, key);
//       controller.text = value;
//       item[key] = value;
//
//       if (key == "metal_rate") item["manual_metal"] = true;
//       if (key == "labour_rate") item["manual_labour"] = true;
//
//       calculateItem(item);
//       updatedCount++;
//     }
//
//     /// ============================================================
//     /// 🔥 CART / SCAN ITEMS — FIX: controller + calculateItem MISSING hatu
//     /// ============================================================
//     for (final cartItem in cartItems) {
//       final controller = getController(cartItem, key);
//       controller.text = value;
//       cartItem[key] = value;
//
//       if (key == "metal_rate") cartItem["manual_metal"] = true;
//       if (key == "labour_rate") cartItem["manual_labour"] = true;
//
//       calculateItem(cartItem);
//       updatedCount++;
//     }
//
//     updateFinalItems();
//
//     if (!mounted) return;
//
//     setState(() {});
//
//     /// ============================================================
//     /// 🔥 CONFIRMATION MESSAGE
//     /// ============================================================
//     ScaffoldMessenger.of(context)
//       ..hideCurrentSnackBar()
//       ..showSnackBar(
//         SnackBar(
//           content: Row(
//             children: [
//               const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: Text(
//                   "Applied to all $updatedCount items",
//                   style: const TextStyle(color: Colors.white, fontSize: 13),
//                 ),
//               ),
//             ],
//           ),
//           backgroundColor: Colors.green.shade700,
//           behavior: SnackBarBehavior.floating,
//           duration: const Duration(seconds: 2),
//           margin: const EdgeInsets.all(12),
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//         ),
//       );
//   }
//
//   InputDecoration _premiumChargeInputDecoration() {
//     return InputDecoration(
//       isDense: true,
//
//       contentPadding:
//       const EdgeInsets.symmetric(
//         horizontal: 7,
//         vertical: 9,
//       ),
//
//       filled: true,
//       fillColor: Colors.white,
//
//       border: OutlineInputBorder(
//         borderRadius:
//         BorderRadius.circular(5),
//         borderSide:
//         BorderSide(
//           color: AppColors.border,
//         ),
//       ),
//
//       enabledBorder:
//       OutlineInputBorder(
//         borderRadius:
//         BorderRadius.circular(5),
//         borderSide:
//         BorderSide(
//           color: AppColors.border,
//         ),
//       ),
//
//       focusedBorder:
//       OutlineInputBorder(
//         borderRadius:
//         BorderRadius.circular(5),
//         borderSide: const BorderSide(
//           color: AppColors.gradientBlue,
//           width: 1.3,
//         ),
//       ),
//     );
//   }
//
//   Widget _premiumChargeField({
//     required dynamic initialValue,
//     required ValueChanged<String>
//     onChanged,
//   }) {
//     return Padding(
//       padding:
//       const EdgeInsets.symmetric(
//         horizontal: 3,
//       ),
//
//       child: TextFormField(
//         initialValue:
//         initialValue?.toString() ?? "",
//
//         keyboardType:
//         const TextInputType.numberWithOptions(
//           decimal: true,
//         ),
//
//         textAlign:
//         TextAlign.center,
//
//         style: const TextStyle(
//           fontSize: 11,
//           fontWeight:
//           FontWeight.w600,
//           color: Colors.black87,
//         ),
//
//         onChanged: onChanged,
//
//         decoration:
//         _premiumChargeInputDecoration(),
//       ),
//     );
//   }
//
//   Widget _buildBalanceBoxes(ItemProvider provider, bool isMobile) {
//     final bool useEdit = _useEditBalance;
//     final String metalName =
//     useEdit ? "Silver" : provider.activeMetalDisplayName;
//
//     /// Opening balance (signed: Credit = +, Debit = -)
//     double opening;
//     if (useEdit) {
//       opening = editSilverOpening;
//     } else {
//       final double b = provider.activeMetalBalance.abs();
//       opening = provider.activeMetalBalanceType == "Debit" ? -b : b;
//     }
//
//     /// Items no live total fine weight (checkbox tick hoy to j minus thase)
//     final double totalFine = calculateTotals()["fine"] ?? 0;
//     final double used = useSilverBalance ? totalFine : 0;
//     final double after = opening - used;
//
//     final Widget cashBox = _premiumReadOnlyBox(
//       title: "Advance Cash Balance",
//       type: useEdit ? "Credit" : provider.cashType,
//       value:
//       (useEdit ? editCashBalance : provider.cashBalance).toStringAsFixed(2),
//     );
//
//     final Widget balanceBox = _premiumReadOnlyBox(
//       title: useEdit ? "Silver Fine Balance" : provider.activeMetalLabel,
//       type: opening >= 0 ? "Credit" : "Debit",
//       value: opening.abs().toStringAsFixed(3),
//     );
//
//     final Widget usedBox = _premiumReadOnlyBox(
//       title: "$metalName Used (Fine Wt)",
//       value: useSilverBalance
//           ? used.toStringAsFixed(3)
//           : "$metalName Used Not Adjusted",
//     );
//
//     final Widget afterBox = _premiumReadOnlyBox(
//       title: "$metalName Balance After Use",
//       type: after >= 0 ? "Credit" : "Debit",
//       value: after.abs().toStringAsFixed(3),
//     );
//
//     if (!isMobile) {
//       return Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Expanded(child: cashBox),
//           const SizedBox(width: 14),
//           Expanded(child: balanceBox),
//           const SizedBox(width: 14),
//           Expanded(child: usedBox),
//           const SizedBox(width: 14),
//           Expanded(child: afterBox),
//         ],
//       );
//     }
//
//     return Column(
//       children: [
//         Row(
//           children: [
//             Expanded(child: cashBox),
//             const SizedBox(width: 8),
//             Expanded(child: balanceBox),
//           ],
//         ),
//         const SizedBox(height: 10),
//         Row(
//           children: [
//             Expanded(child: usedBox),
//             const SizedBox(width: 8),
//             Expanded(child: afterBox),
//           ],
//         ),
//       ],
//     );
//   }
//
//   Widget _adjustFineBalanceTile() {
//     return InkWell(
//       onTap: () => setState(() => useSilverBalance = !useSilverBalance),
//       borderRadius: BorderRadius.circular(6),
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
//         decoration: BoxDecoration(
//           color: useSilverBalance
//               ? AppColors.gradientBlue.withOpacity(0.06)
//               : Colors.white,
//           borderRadius: BorderRadius.circular(6),
//           border: Border.all(
//             color: useSilverBalance ? AppColors.gradientBlue : AppColors.border,
//           ),
//         ),
//         child: Row(
//           children: [
//             SizedBox(
//               width: 24,
//               height: 24,
//               child: Checkbox(
//                 value: useSilverBalance,
//                 activeColor: AppColors.gradientBlue,
//                 materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                 onChanged: (v) =>
//                     setState(() => useSilverBalance = v ?? false),
//               ),
//             ),
//             const SizedBox(width: 8),
//             const Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     "Adjust Fine Balance",
//                     style: TextStyle(
//                       fontSize: 12.5,
//                       fontWeight: FontWeight.w700,
//                       color: Colors.black87,
//                     ),
//                   ),
//                   SizedBox(height: 2),
//                   Text(
//                     "Deduct sale fine from customer metal balance.",
//                     style: TextStyle(fontSize: 10.5, color: Colors.black54),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   String _generateDeviceEntryId() {
//     final String base = deviceId ?? 'unknown-device';
//
//     return "$base-${DateTime.now().microsecondsSinceEpoch}";
//   }
//
//   /// =========================================================
//   /// 🔥 BORDER વાળું DROPDOWN BOX (label 15 + gap 4 + box 36)
//   /// =========================================================
//   Widget _miniDropdownBox({
//     required String title,
//     required double width,
//     required String text,
//     required String hint,
//     required VoidCallback onTap,
//   }) {
//     final bool isEmpty = text.trim().isEmpty;
//
//     return Container(
//       width: width,
//       height: 55,
//       margin: const EdgeInsets.only(right: 8),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           SizedBox(
//             height: 15,
//             child: Text(
//               title,
//               style: const TextStyle(fontSize: 11, color: Colors.black54),
//             ),
//           ),
//           const SizedBox(height: 4),
//           SizedBox(
//             height: 36,
//             child: Material(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(5),
//               child: InkWell(
//                 borderRadius: BorderRadius.circular(5),
//                 onTap: () {
//                   FocusManager.instance.primaryFocus?.unfocus();
//                   onTap();
//                 },
//                 child: Container(
//                   padding: const EdgeInsets.only(left: 6, right: 2),
//                   decoration: BoxDecoration(
//                     borderRadius: BorderRadius.circular(5),
//                     border: Border.all(color: AppColors.border), // 🔥 BORDER
//                   ),
//                   child: Row(
//                     children: [
//                       Expanded(
//                         child: Text(
//                           isEmpty ? hint : text,
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                           style: TextStyle(
//                             fontSize: 12,
//                             color: isEmpty ? Colors.black38 : Colors.black,
//                             fontWeight:
//                             isEmpty ? FontWeight.normal : FontWeight.w600,
//                           ),
//                         ),
//                       ),
//                       const Icon(
//                         Icons.keyboard_arrow_down,
//                         size: 18,
//                         color: Colors.black54,
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   /// =========================================================
//   /// 🔥 PREMIUM SEARCH BOTTOM SHEET
//   /// =========================================================
//   Future<Map<String, dynamic>?> _openSearchSheet({
//     required String title,
//     required List<Map<String, dynamic>> items,
//     required String Function(Map<String, dynamic>) labelOf,
//     required String Function(Map<String, dynamic>) searchOf,
//     String Function(Map<String, dynamic>)? subtitleOf,
//     IconData icon = Icons.inventory_2_outlined,
//     String? selectedId,
//   }) {
//     final TextEditingController searchCtrl = TextEditingController();
//     String query = "";
//
//     return showModalBottomSheet<Map<String, dynamic>>(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       barrierColor: Colors.black.withOpacity(0.45),
//       builder: (ctx) {
//         return StatefulBuilder(
//           builder: (ctx, setSheet) {
//             final q = query.trim().toLowerCase();
//             final filtered = q.isEmpty
//                 ? items
//                 : items
//                 .where((e) => searchOf(e).toLowerCase().contains(q))
//                 .toList();
//
//             return AnimatedPadding(
//               duration: const Duration(milliseconds: 150),
//               padding: EdgeInsets.only(
//                 bottom: MediaQuery.of(ctx).viewInsets.bottom,
//               ),
//               child: Container(
//                 height: MediaQuery.of(ctx).size.height * 0.72,
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius:
//                   const BorderRadius.vertical(top: Radius.circular(22)),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(0.12),
//                       blurRadius: 20,
//                       offset: const Offset(0, -4),
//                     ),
//                   ],
//                 ),
//                 child: Column(
//                   children: [
//                     const SizedBox(height: 10),
//                     Container(
//                       width: 42,
//                       height: 4,
//                       decoration: BoxDecoration(
//                         color: Colors.grey.shade300,
//                         borderRadius: BorderRadius.circular(2),
//                       ),
//                     ),
//
//                     /// HEADER
//                     Padding(
//                       padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
//                       child: Row(
//                         children: [
//                           Container(
//                             width: 42,
//                             height: 42,
//                             decoration: BoxDecoration(
//                               gradient: LinearGradient(
//                                 colors: [
//                                   AppColors.primaryDark,
//                                   AppColors.secondaryDark,
//                                 ],
//                                 begin: Alignment.topLeft,
//                                 end: Alignment.bottomRight,
//                               ),
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                             child: Icon(icon, color: Colors.white, size: 22),
//                           ),
//                           const SizedBox(width: 12),
//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   "Select $title",
//                                   style: const TextStyle(
//                                     fontSize: 16,
//                                     fontWeight: FontWeight.bold,
//                                     color: Colors.black,
//                                   ),
//                                 ),
//                                 const SizedBox(height: 2),
//                                 Text(
//                                   "${filtered.length} of ${items.length} available",
//                                   style: TextStyle(
//                                     fontSize: 12,
//                                     color: Colors.grey.shade600,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                           InkWell(
//                             onTap: () => Navigator.pop(ctx),
//                             borderRadius: BorderRadius.circular(20),
//                             child: Container(
//                               padding: const EdgeInsets.all(6),
//                               decoration: BoxDecoration(
//                                 color: Colors.grey.shade100,
//                                 shape: BoxShape.circle,
//                               ),
//                               child: const Icon(
//                                 Icons.close,
//                                 size: 18,
//                                 color: Colors.black54,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//
//                     /// SEARCH
//                     Padding(
//                       padding: const EdgeInsets.symmetric(horizontal: 16),
//                       child: TextField(
//                         controller: searchCtrl,
//                         onChanged: (v) => setSheet(() => query = v),
//                         style: const TextStyle(fontSize: 13.5, color: Colors.black),
//                         decoration: InputDecoration(
//                           hintText: "Search $title...",
//                           hintStyle: TextStyle(color: Colors.grey.shade500),
//                           prefixIcon: const Icon(
//                             Icons.search,
//                             size: 20,
//                             color: AppColors.primaryDark,
//                           ),
//                           suffixIcon: query.isEmpty
//                               ? null
//                               : IconButton(
//                             icon: const Icon(Icons.cancel, size: 18),
//                             color: Colors.grey.shade500,
//                             onPressed: () {
//                               searchCtrl.clear();
//                               setSheet(() => query = "");
//                             },
//                           ),
//                           isDense: true,
//                           filled: true,
//                           fillColor: Colors.grey.shade100,
//                           contentPadding: const EdgeInsets.symmetric(vertical: 12),
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                             borderSide: BorderSide.none,
//                           ),
//                           enabledBorder: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                             borderSide: BorderSide.none,
//                           ),
//                           focusedBorder: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                             borderSide: const BorderSide(
//                               color: AppColors.primaryDark,
//                               width: 1.2,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//
//                     const SizedBox(height: 10),
//                     Divider(height: 1, color: Colors.grey.shade200),
//
//                     /// LIST
//                     Expanded(
//                       child: filtered.isEmpty
//                           ? Center(
//                         child: Column(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             Icon(
//                               Icons.search_off_rounded,
//                               size: 48,
//                               color: Colors.grey.shade400,
//                             ),
//                             const SizedBox(height: 8),
//                             Text(
//                               "No $title found",
//                               style: const TextStyle(
//                                 fontSize: 14,
//                                 fontWeight: FontWeight.w600,
//                                 color: Colors.black54,
//                               ),
//                             ),
//                           ],
//                         ),
//                       )
//                           : ListView.builder(
//                         padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
//                         itemCount: filtered.length,
//                         itemBuilder: (_, i) {
//                           final e = filtered[i];
//                           final bool isSel = selectedId != null &&
//                               selectedId.isNotEmpty &&
//                               e["id"]?.toString() == selectedId;
//                           final String label = labelOf(e);
//                           final String sub =
//                               subtitleOf?.call(e).trim() ?? "";
//                           final String initial = label.isNotEmpty
//                               ? label[0].toUpperCase()
//                               : "?";
//
//                           return Padding(
//                             padding: const EdgeInsets.only(bottom: 8),
//                             child: Material(
//                               color: isSel
//                                   ? AppColors.primaryDark.withOpacity(0.07)
//                                   : Colors.white,
//                               borderRadius: BorderRadius.circular(12),
//                               child: InkWell(
//                                 borderRadius: BorderRadius.circular(12),
//                                 onTap: () => Navigator.pop(ctx, e),
//                                 child: Container(
//                                   padding: const EdgeInsets.symmetric(
//                                     horizontal: 12,
//                                     vertical: 10,
//                                   ),
//                                   decoration: BoxDecoration(
//                                     borderRadius: BorderRadius.circular(12),
//                                     border: Border.all(
//                                       color: isSel
//                                           ? AppColors.primaryDark
//                                           : AppColors.border,
//                                       width: isSel ? 1.3 : 1,
//                                     ),
//                                   ),
//                                   child: Row(
//                                     children: [
//                                       Container(
//                                         width: 36,
//                                         height: 36,
//                                         alignment: Alignment.center,
//                                         decoration: BoxDecoration(
//                                           gradient: isSel
//                                               ? LinearGradient(colors: [
//                                             AppColors.primaryDark,
//                                             AppColors.secondaryDark,
//                                           ])
//                                               : null,
//                                           color: isSel
//                                               ? null
//                                               : AppColors.primaryDark
//                                               .withOpacity(0.10),
//                                           borderRadius:
//                                           BorderRadius.circular(10),
//                                         ),
//                                         child: Text(
//                                           initial,
//                                           style: TextStyle(
//                                             fontSize: 14,
//                                             fontWeight: FontWeight.bold,
//                                             color: isSel
//                                                 ? Colors.white
//                                                 : AppColors.primaryDark,
//                                           ),
//                                         ),
//                                       ),
//                                       const SizedBox(width: 12),
//                                       Expanded(
//                                         child: Column(
//                                           crossAxisAlignment:
//                                           CrossAxisAlignment.start,
//                                           children: [
//                                             Text(
//                                               label,
//                                               maxLines: 1,
//                                               overflow: TextOverflow.ellipsis,
//                                               style: TextStyle(
//                                                 fontSize: 13.5,
//                                                 fontWeight: isSel
//                                                     ? FontWeight.w700
//                                                     : FontWeight.w600,
//                                                 color: Colors.black,
//                                               ),
//                                             ),
//                                             if (sub.isNotEmpty) ...[
//                                               const SizedBox(height: 2),
//                                               Text(
//                                                 sub,
//                                                 maxLines: 1,
//                                                 overflow:
//                                                 TextOverflow.ellipsis,
//                                                 style: TextStyle(
//                                                   fontSize: 11,
//                                                   color: Colors.grey.shade600,
//                                                 ),
//                                               ),
//                                             ],
//                                           ],
//                                         ),
//                                       ),
//                                       Icon(
//                                         isSel
//                                             ? Icons.check_circle
//                                             : Icons.chevron_right,
//                                         size: 20,
//                                         color: isSel
//                                             ? AppColors.primaryDark
//                                             : Colors.grey.shade400,
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           );
//                         },
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
//
//   /// ❌ વાળું dropdown — બધા dropdowns માટે એક જ
//   Widget _dropdownWithClear({
//     required Widget dropdown,
//     required bool showClear,
//     required VoidCallback onClear,
//   }) {
//     return Stack(
//       alignment: Alignment.centerRight,
//       children: [
//         dropdown,
//         if (showClear)
//           Positioned(
//             right: 40, // 🔥 arrow થી અંતર — જરૂર મુજબ 32–48 કરો
//             top: 0,
//             bottom: 0,
//             child: Center(
//               child: InkWell(
//                 borderRadius: BorderRadius.circular(20),
//                 onTap: () {
//                   FocusManager.instance.primaryFocus?.unfocus();
//                   onClear();
//                 },
//                 child: Container(
//                   width: 20,
//                   height: 20,
//                   alignment: Alignment.center,
//                   decoration: BoxDecoration(
//                     color: Colors.red.shade50,
//                     shape: BoxShape.circle,
//                     border: Border.all(color: Colors.red.shade200),
//                   ),
//                   child: Icon(
//                     Icons.close_rounded,
//                     size: 13,
//                     color: Colors.red.shade700,
//                   ),
//                 ),
//               ),
//             ),
//           ),
//       ],
//     );
//   }
//
//   /// 🔥 Customer select / clear → Approval Person પણ sync
//   void _setCustomer(
//       ItemProvider provider,
//       Map? customer,
//       List approvalCustomers,
//       ) {
//     /// ❌ CLEAR
//     if (customer == null) {
//       /// 🔥 NEW: ચાલુ cart request હોય તો એનો response ignore
//       _cartRequestId++;
//
//       setState(() {
//         /// Approval Person customer જેવો જ હતો (auto-sync) તો એ પણ clear.
//         /// User એ જાતે અલગ person પસંદ કર્યો હોય તો એને રહેવા દો.
//         if (selectedapprovalItem == selectedItem) {
//           selectedapprovalItem = null;
//           selectedApprovalCompanyId = null;
//           selectedApprovalUserId = null;
//         }
//
//         selectedItem = null;
//         selectedCompanyId = null;
//         selectedUserId = null;
//         customerChangedByUser = false;
//
//         /// 🔥 NEW: Customer નથી → cart પણ નહીં
//         cartItems = [];
//         updateFinalItems();
//       });
//
//       /// TODO: provider માં advance/balance reset નું method હોય તો અહીં call કરો
//       return;
//     }
//
//     final String? id = customer["id"]?.toString();
//     if (id == null || id.isEmpty) return;
//
//     /// Approval list માં આ જ customer શોધો
//     Map? matchApproval;
//     for (final c in approvalCustomers) {
//       if (c["id"]?.toString() == id) {
//         matchApproval = c;
//         break;
//       }
//     }
//
//     setState(() {
//       selectedItem = id;
//       selectedCompanyId = customer["company_id"]?.toString();
//       selectedUserId = id;
//
//       /// 🔥 USER E CUSTOMER BADLYO — have provider (live) balance vaparo
//       customerChangedByUser = true;
//       provider.setCustomerAdvance(Map<String, dynamic>.from(customer));
//
//       /// 🔥 NEW: જૂના customer ના cart items તરત હટાવો
//       cartItems = [];
//       updateFinalItems();
//
//       /// 🔥 AUTO: Approval Person = એ જ customer
//       if (matchApproval != null) {
//         selectedapprovalItem = id;
//         selectedApprovalCompanyId = matchApproval["company_id"]?.toString();
//         selectedApprovalUserId = id;
//       } else {
//         /// Approval list માં આ customer નથી → ખાલી, user જાતે પસંદ કરે
//         selectedapprovalItem = null;
//         selectedApprovalCompanyId = null;
//         selectedApprovalUserId = null;
//       }
//       _approvalManuallyCleared = false;
//     });
//
//     debugPrint("Selected Customer => ${customer["name"]} ($id)");
//     debugPrint("Auto Approval Person => ${matchApproval?["name"] ?? "-"}");
//
//     /// 🔥 NEW: આ customer નો pending cart લાવો
//     getCartItems(customerId: id);
//   }
//
//   /// Approval Person select / clear (user જાતે)
//   void _setApprovalPerson(Map? person) {
//     setState(() {
//       selectedapprovalItem = person?["id"]?.toString();
//       selectedApprovalCompanyId = person?["company_id"]?.toString();
//       selectedApprovalUserId = person?["id"]?.toString();
//       _approvalManuallyCleared = person == null;
//     });
//
//     debugPrint("Selected Approval Person => ${person?["name"] ?? "-"}");
//   }
// }
//
// class _ScannerLineAnimation extends StatefulWidget {
//   const _ScannerLineAnimation({super.key});
//
//   @override
//   State<_ScannerLineAnimation> createState() => _ScannerLineAnimationState();
// }
//
// class _ScannerLineAnimationState extends State<_ScannerLineAnimation>
//     with SingleTickerProviderStateMixin {
//   late AnimationController controller;
//   late Animation<double> animation;
//
//   @override
//   void initState() {
//     super.initState();
//
//     controller = AnimationController(
//       vsync: this,
//       duration: const Duration(seconds: 2),
//     )..repeat(reverse: true);
//
//     animation = Tween<double>(
//       begin: 0,
//       end: 1,
//     ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return AnimatedBuilder(
//       animation: animation,
//       builder: (context, child) {
//         return Align(
//           alignment: Alignment(0, animation.value * 2 - 1),
//           child: Container(
//             width: double.infinity,
//             height: 3,
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [
//                   Colors.transparent,
//                   Colors.greenAccent,
//                   Colors.transparent,
//                 ],
//               ),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.greenAccent.withOpacity(0.6),
//                   blurRadius: 10,
//                   spreadRadius: 1,
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   @override
//   void dispose() {
//     controller.dispose();
//     super.dispose();
//   }
// }

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pecifician_sysytem/Dashboard/PremiumScannerScreen.dart';
import 'package:pecifician_sysytem/User/CreteUserScreen.dart';
import 'package:provider/provider.dart';
import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import '../Dashboard/HomeScreen.dart';
import '../Extra/AppColors.dart';
import '../Extra/AppMessage.dart';
import '../Extra/ItemProvider.dart';
import '../Extra/PremiumSearchableDropdown.dart';
import '../Offline Data/offline_api_helper.dart';
import 'Sell_list.dart';

const TextStyle _blackFieldStyle = TextStyle(
  color: Colors.black,
  fontSize: 13,
  fontWeight: FontWeight.w600,
);
class Sellscreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const Sellscreen({Key? key, this.userData}) : super(key: key);

  @override
  State<Sellscreen> createState() => _SellscreenState();
}

class _SellscreenState extends State<Sellscreen> {
  TextEditingController searchController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.unrestricted,
    formats: [BarcodeFormat.qrCode],
  );
  List userlist = [];
  String? selectedItem;
  bool _approvalManuallyCleared = false;
  final Map<String, int> _approvalIdByQr = {};
  String? selectedapprovalItem;
  String? CustomerID;
  List<Map<String, TextEditingController>> tableRows = [];
  Timer? _huidTimer;
  int apiRowCount = 0;
  List customerlist = [];
  String? selectedUser;
  String? selectedCompanyId;
  String? selectedUserId;
  bool isSalePaymentExpanded = false;
  String? selectedApprovalCompanyId;
  String? selectedApprovalUserId;
  DateTime? birthDate;
  DateTime? anniversaryDate;
  List cartItems = [];
  Set<int> selectedItems = {}; // ✅ MUST BE int
  List approvalAddedItems = []; // 🔥 new list
  bool isLoading = false;
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> allItems = [];
  List searchResults = [];
  List combinedItems = [];
  List<Map<String, dynamic>> finalItems = [];
  bool showScannerFull = false;
  FocusNode searchFocusNode = FocusNode();
  bool isSearchEnabled = false;
  bool get isEditMode => widget.userData != null;
  TextEditingController receivedAmountController = TextEditingController();

  TextEditingController paymentRefController = TextEditingController();

  TextEditingController pendingAmountController = TextEditingController(
    text: "0.00",
  );
  TextEditingController remarksController = TextEditingController();
  TextEditingController recived_amount_Controller = TextEditingController();
  TextEditingController payment_ref_Controller = TextEditingController();
  TextEditingController payment_pending_Controller = TextEditingController();
  TextEditingController add_payment_Controller = TextEditingController();
  String? selectedPaymentMode;
  double cashBalance = 0.0;
  double goldBalance = 0.0;
  double silverBalance = 0.0;
  bool showBalance = false;

 
  /// =========================================================
  /// 🔥 EDIT MODE ADVANCE USAGE (loadEditData API response mathi)
  /// =========================================================
  double editCashBalance = 0.0;
  double editCashPayableTotal = 0.0;
  double editCashPending = 0.0;

  double editSilverOpening = 0.0;
  double editSilverUsed = 0.0;
  double editSilverClosing = 0.0;
  double editSilverDebit = 0.0;
  double editSilverCredit = 0.0;

  double editGoldFineRequired = 0.0;
  double editSilverFineRequired = 0.0;
  double editOtherFineRequired = 0.0;
  bool customerChangedByUser = false;
  bool useSilverBalance = false; // ✅ Adjust Fine Balance checkbox
  bool showPreviousBills = false; /// ✅ Invoice PDF ma juna pending bills batavva (balance par asar nahi)

  bool get _useEditBalance => isEditMode && !customerChangedByUser;

  String? deviceId;

  /// Aa screen khule tyare j ek vaar generate thay (session unique)
  String? voucherSessionId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<ItemProvider>(context, listen: false).refreshItems();
      Provider.of<ItemProvider>(context, listen: false).refreshCustomers();
      Provider.of<ItemProvider>(context, listen: false)
          .refreshapprovalCustomers();
    });

    /// 🔥 voucher_session_id — screen khule tyare j ek vaar generate
    voucherSessionId = 'APP-${DateTime.now().millisecondsSinceEpoch}';
    if (isEditMode) {
      final user = widget.userData!;
      selectedItem = user["customer_id"]?.toString();
      selectedUserId = user["customer_id"]?.toString();
      selectedapprovalItem ??= selectedItem;

      selectedApprovalCompanyId ??= selectedCompanyId;

      selectedApprovalUserId ??= selectedUserId;
      loadEditData(user["id"]);
    }
  }

  List<Map<String, dynamic>> uniqueItems = [];

  // ============================================================
  // 🔥 APPBAR LIST SEARCH
  // ============================================================
  bool _showListSearch = false;
  final TextEditingController _listFilterController = TextEditingController();
  String _listFilter = "";

  /// એક row ની ઓળખ (controllers માં પણ આ જ key વપરાય છે)
  String _rowKey(dynamic item) => (item["itemset_id"] ?? item["id"]).toString();

  /// 🔥 હાલ screen પર દેખાતી items (search પછી)
  List<Map<String, dynamic>> get _visibleItems {
    final String q = _listFilter.trim().toLowerCase();
    if (q.isEmpty) return uniqueItems;

    return uniqueItems.where((item) {
      final String text = [
        item["item_name"],
        item["name"],
        item["qr_code"],
        item["code"],
        item["huid"],
        item["item_code"],
        item["metal"],
      ].map((e) => e?.toString().toLowerCase() ?? "").join(" ");

      return text.contains(q);
    }).toList();
  }

  /// Search બંધ કરો + filter હટાવો
  void _closeListSearch() {
    FocusManager.instance.primaryFocus?.unfocus();
    _listFilterController.clear();
    setState(() {
      _listFilter = "";
      _showListSearch = false;
    });
  }

  Future<void> loadEditData(int id) async {
    final response = await ApiHelper().getRequestWithId(
      ApiConstants.sale_item_update,
      id,
    );

    print("DETAIL API => ${response?.data}");

    if (response != null && response.statusCode == 200) {
      final data = response.data["data"];

      final List apiItems = data["sale_items"] ?? [];

      AppMessage.success(
        context,
        data["message"] ?? "Data Loaded Successfully",
      );

      setState(() {
        /// =========================================================
        /// CLEAR OLD DATA
        /// =========================================================

        items.clear();
        uniqueItems.clear();
        approvalAddedItems.clear();
        finalItems.clear();
        controllers.clear();

        /// =========================================================
        /// PAYMENT
        /// =========================================================

        recived_amount_Controller.text =
            data["received_amount"]?.toString() ?? "";

        payment_ref_Controller.text =
            data["payment_reference"]?.toString() ?? "";

        payment_pending_Controller.text =
            data["payment_note"]?.toString() ?? "";

        selectedPaymentMode = data["payment_mode"]?.toString();

        remarksController.text = data["remarks"]?.toString() ?? "";

        final dynamic usb = data["use_silver_balance"];
        useSilverBalance = usb == true ||
            usb == 1 ||
            usb.toString() == "1" ||
            usb.toString() == "true";

        /// ✅ Previous bills checkbox (edit mode)
        final dynamic spb = data["show_previous_bills"];
        showPreviousBills = spb == true ||
            spb == 1 ||
            spb.toString() == "1" ||
            spb.toString() == "true";

        /// =========================================================
        /// 🔥 EDIT MODE ADVANCE USAGE SET
        /// =========================================================
        final Map<String, dynamic> advanceUsage =
        (data["advance_usage"] is Map)
            ? Map<String, dynamic>.from(data["advance_usage"])
            : {};

        double _d(dynamic v) => double.tryParse(v?.toString() ?? "0") ?? 0;

        editCashBalance = _d(advanceUsage["cash_balance"]);
        editCashPayableTotal = _d(advanceUsage["cash_payable_total"]);
        editCashPending = _d(advanceUsage["cash_pending"]);

        editSilverOpening = _d(advanceUsage["silver_opening"]);
        editSilverUsed = _d(advanceUsage["silver_debit"]);
        editSilverClosing = _d(advanceUsage["silver_closing"]);
        editSilverDebit = _d(advanceUsage["silver_debit"]);
        editSilverCredit = _d(advanceUsage["silver_credit"]);

        final Map<String, dynamic> fineRequired =
        (advanceUsage["fine_required"] is Map)
            ? Map<String, dynamic>.from(advanceUsage["fine_required"])
            : {};

        editGoldFineRequired = _d(fineRequired["gold"]);
        editSilverFineRequired = _d(fineRequired["silver"]);
        editOtherFineRequired = _d(fineRequired["other"]);

        /// =========================================================
        /// SALE ITEMS
        /// =========================================================

        for (var e in apiItems) {
          final dynamic itemset = e["itemset"];

          final bool hasItemset =
              itemset != null && itemset is Map && itemset["id"] != null;

          final dynamic masterItem =
              e["item"] ?? e["product"] ?? e["item_master"];

          final dynamic itemsetId =
          hasItemset ? itemset["id"] : e["itemset_id"];

          final dynamic itemId = e["item_id"] ??
              (masterItem is Map ? masterItem["id"] : null) ??
              (hasItemset && itemset["item"] is Map
                  ? itemset["item"]["id"]
                  : null);

          final bool isSavedManualItem = itemsetId == null && itemId != null;

          /// ITEM NAME
          String itemName = "";

          if (hasItemset) {
            if (itemset["item"] is Map) {
              itemName = itemset["item"]["item_name"]?.toString() ?? "";
            }
          } else {
            if (masterItem is Map) {
              itemName = masterItem["item_name"]?.toString() ?? "";
            }

            if (itemName.trim().isEmpty) {
              itemName = e["item_name"]?.toString() ?? "";
            }
          }

          /// QR CODE
          final String qrCode = hasItemset
              ? itemset["qr_code"]?.toString() ?? ""
              : e["qr_code"]?.toString() ?? "";

          /// MASTER ITEM EXTRA DATA
          dynamic getMasterValue(String key) {
            if (masterItem is Map && masterItem[key] != null) {
              return masterItem[key];
            }

            if (hasItemset &&
                itemset["item"] is Map &&
                itemset["item"][key] != null) {
              return itemset["item"][key];
            }

            return e[key];
          }

          final Map<String, dynamic> itemData = {
            "sale_item_id": e["id"],
            "id": itemsetId ?? itemId,
            "itemset_id": itemsetId,
            "item_id": itemId,
            "approval_item_id": e["approval_item_id"],
            "item": itemName,
            "item_name": itemName,
            "item_code": getMasterValue("item_code"),
            "metal": getMasterValue("metal"),
            "huid": e["HUID"]?.toString() ?? e["huid"]?.toString() ?? "",
            "qr_code": qrCode,
            "gross_weight": e["gross_weight"]?.toString() ?? "0",
            "other_weight": e["other_weight"]?.toString() ?? "0",
            "net_weight": e["net_weight"]?.toString() ?? "0",
            "purity": e["purity"]?.toString() ?? "0",
            "waste":
            e["waste_percent"]?.toString() ?? e["waste"]?.toString() ?? "0",
            "outward_carat":
            getMasterValue("outward_carat")?.toString() ?? "0",
            "outward_purity":
            getMasterValue("outward_purity")?.toString() ?? "0",
            "net_purity": e["net_purity"]?.toString() ?? "0",
            "fine_weight": e["fine_weight"]?.toString() ?? "0",
            "metal_formula": getMasterValue("metal_formula"),
            "metal_rate": e["metal_rate"]?.toString() ?? "0",
            "metal_amount": e["metal_amount"]?.toString() ?? "0",
            "labour_type": getMasterValue("labour_type"),
            "labour_unit": getMasterValue("labour_unit"),
            "labour_rate": e["labour_rate"]?.toString() ??
                getMasterValue("labour_rate")?.toString() ??
                "0",
            "labour_amount": e["labour_amount"]?.toString() ?? "0",
            "qty": e["qty"]?.toString() ?? "1",
            "remarks": e["remarks"]?.toString() ?? "",
            "other_amount": e["other_amount"]?.toString() ?? "0",
            "total_amount": e["total_amount"]?.toString() ?? "0",
            "hsn": getMasterValue("hsn"),
            "sac_code": getMasterValue("sac_code"),
            "export_hsn": getMasterValue("export_hsn"),
            "expanded": false,
            "show_item_dropdown": false,
            "is_fresh": false,
            "is_manual_item": isSavedManualItem,
            "is_saved_item": true,
          };

          /// CONTROLLERS
          setController(itemData, "gross_weight", itemData["gross_weight"]);
          setController(itemData, "other_weight", itemData["other_weight"]);
          setController(itemData, "net_weight", itemData["net_weight"]);
          setController(itemData, "purity", itemData["purity"]);
          setController(itemData, "waste", itemData["waste"]);
          setController(itemData, "outward_carat", itemData["outward_carat"]);
          setController(itemData, "net_purity", itemData["net_purity"]);
          setController(itemData, "fine_weight", itemData["fine_weight"]);
          setController(itemData, "metal_rate", itemData["metal_rate"]);
          setController(itemData, "metal_amount", itemData["metal_amount"]);
          setController(itemData, "labour_rate", itemData["labour_rate"]);
          setController(itemData, "labour_amount", itemData["labour_amount"]);
          setController(itemData, "qty", itemData["qty"]);
          setController(itemData, "remarks", itemData["remarks"]);
          setController(itemData, "other_amount", itemData["other_amount"]);
          setController(itemData, "total_amount", itemData["total_amount"]);

          items.insert(0, itemData);
          uniqueItems.add(itemData);

          debugPrint(
            "EDIT ITEM => "
                "itemset_id=$itemsetId | "
                "item_id=$itemId | "
                "manual=$isSavedManualItem | "
                "dropdown=${itemData["show_item_dropdown"]} | "
                "name=$itemName",
          );
        }

        updateFinalItems();
      });
    }
  }

  int _itemOrderCounter = 0;
  final Map<String, int> _itemOrderMap = {};

  String? _orderKeyFor(Map item) {
    final dynamic key = item["approval_item_id"] ?? item["id"] ?? item["code"];
    if (key == null) return null;
    return key.toString();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final isMobile = width < 600;

    /// 🔥 UNIFIED LIST: Combine all sources
    List combinedItemsList = [
      ...items,
      ...approvalAddedItems,
      ...cartItems.map((e) {
        final itemset = e["itemset"] ?? {};
        final itemData = itemset["item"] ?? {};

        return {
          ...e,
          "name": itemData["item_name"] ?? e["item_name"] ?? "",
          "code": itemset["qr_code"] ??
              itemset["HUID"] ??
              e["qr_code"] ??
              e["huid"] ??
              "-",
          "source": "sale",
          "expanded": false,
        };
      }).toList(),
    ];

    // ============================================================
    // 🔥 DEDUPLICATE + RECENCY-BASED SORT
    // ============================================================

    final Map<String, dynamic> dedupMap = {};

    for (var item in combinedItemsList) {
      final String? key = _orderKeyFor(item);

      if (key == null || key.isEmpty) continue;

      dedupMap[key] = item;

      _itemOrderMap.putIfAbsent(key, () => _itemOrderCounter++);
    }

    final List<MapEntry<String, dynamic>> sortedEntries =
    dedupMap.entries.toList()
      ..sort((a, b) {
        final int orderA = _itemOrderMap[a.key] ?? 0;
        final int orderB = _itemOrderMap[b.key] ?? 0;
        return orderB.compareTo(orderA);
      });

    uniqueItems = sortedEntries
        .map((e) => (e.value as Map).cast<String, dynamic>())
        .toList();

    /// 🔥 Search પછી દેખાતી items
    final List<Map<String, dynamic>> visibleItems = _visibleItems;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        Navigator.pop(context, true);
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: Stack(
          children: [
            /// ✅ Main Content
            Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top + 40),
                Expanded(
                  child: showScannerFull
                      ? Column(
                    children: [
                      const SizedBox(height: 10),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: Consumer<ItemProvider>(
                          builder: (context, provider, child) {
                            final customers = provider.customers;

                            return DropdownButtonFormField<String>(
                              value: (selectedItem != null &&
                                  customers.any(
                                        (e) =>
                                    e["id"].toString() ==
                                        selectedItem,
                                  ))
                                  ? selectedItem
                                  : null,
                              icon: const Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.black,
                              ),
                              dropdownColor: Colors.white,
                              hint: Text(
                                "Select Customer",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding:
                                const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 0,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                              ),
                              items: customers
                                  .map<DropdownMenuItem<String>>((item) {
                                return DropdownMenuItem<String>(
                                  value: item["id"].toString(),
                                  child: Text(
                                    item["name"] ?? "",
                                    style: const TextStyle(
                                      color: Colors.black,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedItem = value;

                                  final selectedData =
                                  customers.firstWhere(
                                        (user) =>
                                    user["id"].toString() == value,
                                    orElse: () => {},
                                  );
                                  provider
                                      .setCustomerAdvance(selectedData);
                                  if (selectedData.isNotEmpty) {
                                    selectedCompanyId =
                                        selectedData["company_id"]
                                            ?.toString();
                                    selectedUserId =
                                        selectedData["id"]?.toString();

                                    print(
                                      "Selected Company ID: $selectedCompanyId",
                                    );
                                    print(
                                      "Selected User ID: $selectedUserId",
                                    );
                                  } else {
                                    print("⚠️ Customer not found");
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),

                      /// 🔥 FULL SCANNER
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              height: 150,
                              width: 150,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: Colors.black,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.greenAccent
                                        .withOpacity(0.4),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  _buildScannerSection(),
                                  _ScannerLineAnimation(),
                                ],
                              ),
                            ),

                            /// ❌ CLOSE ICON (TOP RIGHT)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    showScannerFull = false;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 5),

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

                      /// 🔽 LIST
                      Expanded(
                        child: visibleItems.isEmpty
                            ? Center(
                          child: Text(
                            uniqueItems.isEmpty
                                ? "No Data Added"
                                : "No matching items",
                          ),
                        )
                            : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                              12, 12, 12, 12),
                          itemCount: visibleItems.length,
                          itemBuilder: (context, index) {
                            return approvalItemCard(
                              visibleItems[index],
                              index,
                              visibleItems.length,
                            );
                          },
                        ),
                      ),
                    ],
                  )
                      : Column(
                    children: [
                      Expanded(
                        child: CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(
                              child: Column(
                                children: [
                                  filterWidget(),
                                  Container(
                                    margin: const EdgeInsets.only(top: 5),
                                    width: double.infinity,
                                    height: 2,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.primaryDark
                                              .withOpacity(0.1),
                                          AppColors.primaryDark,
                                          AppColors.secondaryDark
                                              .withOpacity(0.4),
                                          AppColors.primaryDark
                                              .withOpacity(0.1),
                                        ],
                                      ),
                                      borderRadius:
                                      BorderRadius.circular(10),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Empty state
                            if (visibleItems.isEmpty)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 50),
                                  child: Center(
                                    child: Text(
                                      uniqueItems.isEmpty
                                          ? "No Data Found"
                                          : "No matching items",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            else
                              SliverPadding(
                                padding:
                                const EdgeInsets.fromLTRB(0, 12, 0, 0),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                        (context, index) {
                                      return approvalItemCard(
                                        visibleItems[index],
                                        index,
                                        visibleItems.length,
                                      );
                                    },
                                    childCount: visibleItems.length,
                                  ),
                                ),
                              ),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 80),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                /// 🔥 BOTTOM SUMMARY
                buildSummaryRow(),

                /// Bottom Button
                InkWell(
                  onTap: () {
                    if (isEditMode) {
                      savefinalizeBulkItemsUpdate();
                    } else {
                      savefinalizeBulkItems();
                    }
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
                      child: Center(
                        child: Text(
                          isEditMode ? "Update Sale" : "Save Sale",
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
                color: AppColors.white,
                child: SizedBox(
                  height: isMobile ? 36 : 40,
                  child: Row(
                    children: [
                      /// ⬅️ BACK
                      InkWell(
                        onTap: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          Navigator.pop(context, true);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: isMobile ? 36 : 40,
                          height: isMobile ? 36 : 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: isMobile ? 20 : 22,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      /// 🔥 TITLE અથવા SEARCH FIELD
                      Expanded(
                        child: _showListSearch
                            ? TextField(
                          controller: _listFilterController,
                          autofocus: false,
                          onChanged: (v) =>
                              setState(() => _listFilter = v),
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: "Search item / QR / HUID",
                            hintStyle: const TextStyle(
                              color: Colors.black38,
                              fontSize: 12.5,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 18,
                              color: Colors.black45,
                            ),
                            prefixIconConstraints:
                            const BoxConstraints(minWidth: 34),
                            suffixIcon: InkWell(
                              onTap: _closeListSearch,
                              child: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: Colors.black54,
                              ),
                            ),
                            suffixIconConstraints:
                            const BoxConstraints(minWidth: 34),
                            filled: true,
                            fillColor: Colors.white,
                            isDense: true,
                            contentPadding:
                            const EdgeInsets.symmetric(vertical: 9),
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
                              borderSide: const BorderSide(
                                color: AppColors.gradientBlue,
                                width: 1.2,
                              ),
                            ),
                          ),
                        )
                            : const Center(
                          child: Text(
                            "Create Sale",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      /// 🔍 SEARCH TOGGLE
                      if (!_showListSearch) ...[
                        InkWell(
                          onTap: () => setState(() => _showListSearch = true),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: isMobile ? 36 : 40,
                            height: isMobile ? 36 : 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.primaryDark.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Icon(
                              Icons.search_rounded,
                              size: isMobile ? 20 : 22,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      /// ➕ ADD LABEL FROM APPROVAL
                      Tooltip(
                        message: "Add Label From Approval",
                        child: InkWell(
                          onTap: () {
                            FocusManager.instance.primaryFocus?.unfocus();

                            if (selectedapprovalItem == null ||
                                selectedapprovalItem
                                    .toString()
                                    .trim()
                                    .isEmpty) {
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(
                                    content: const Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline_rounded,
                                          color: Colors.white,
                                          size: 19,
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            "Please select approval person first",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: Colors.red.shade700,
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 2),
                                    margin: const EdgeInsets.all(12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                );

                              return;
                            }

                            getApprovalDetails(
                              int.parse(selectedapprovalItem.toString()),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: isMobile ? 36 : 40,
                            height: isMobile ? 36 : 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.primaryDark.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              size: isMobile ? 21 : 23,
                              color: AppColors.primaryDark,
                            ),
                          ),
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
  }

  Future<void> saveBulkItems() async {
    if (selectedItem == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Please select item")));
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
        "purity": double.tryParse(row["labourAmount"]!.text),
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
      ApiConstants.multiple_items_label_configs,
      body,
    );

    if (response != null && response.statusCode == 200) {
      AppMessage.success(
        context,
        response.data["message"] ?? "Data Saved Successfully",
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Failed to Save Data")));
    }
  }

  Future<void> savefinalizeBulkItems() async {
    if (selectedUserId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Please select Customer")));
      return;
    }

    updateFinalItems();

    final List<Map<String, dynamic>> allItemsToSave = finalItems
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();

    if (allItemsToSave.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("No items to save")));
      return;
    }

    final Map<String, dynamic> body = {
      "customer_id": int.parse(selectedUserId!),
      if (_approvalPersonId != null) "approval_customer_id": _approvalPersonId,
      "items": allItemsToSave,
      "received_amount": recived_amount_Controller.text.trim().isEmpty
          ? null
          : double.tryParse(recived_amount_Controller.text.trim()),
      "payment_mode": selectedPaymentMode,
      "payment_reference": payment_ref_Controller.text.trim(),
      "payment_note": payment_pending_Controller.text.trim().isEmpty
          ? null
          : payment_pending_Controller.text.trim(),
      "remarks": remarksController.text.trim(),
      "use_silver_balance": useSilverBalance,
      "show_previous_bills": showPreviousBills,
    };
    final int seconds = (60 + allItemsToSave.length).clamp(60, 180);
    final response = await OfflineApiHelper.instance.postRequest(
      ApiConstants.sales_store,
      body,
      receiveTimeout: Duration(seconds: seconds),
    );

    if (response != null &&
        (response.statusCode == 200 || response.statusCode == 202)) {
      if (response.statusCode == 202) {
        AppMessage.success(context, "No Internet. Update saved offline.");
      } else {
        AppMessage.success(
          context,
          response.data?["message"] ?? "Data Save Successfully",
        );
      }

      if (!mounted) return;

      setState(() {
        finalItems.clear();
        cartItems.clear();
        approvalAddedItems.clear();
        _itemOrderMap.clear();
        _itemOrderCounter = 0;
      });

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SellList()),
            (route) => route.isFirst,
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Failed to Save Data")));
    }
  }

  Future<void> savefinalizeBulkItemsUpdate() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (selectedUserId == null || selectedUserId.toString().trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select Customer"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    updateFinalItems();

    double _toD(dynamic v) {
      if (v == null) return 0;
      return double.tryParse(v.toString()) ?? 0;
    }

    final List<Map<String, dynamic>> allItemsToSave = finalItems.where((item) {
      final dynamic itemId = item["item_id"];
      final dynamic itemsetId = item["itemset_id"];

      final bool hasItemId = itemId != null &&
          itemId.toString().trim().isNotEmpty &&
          itemId.toString().toLowerCase() != "null";

      final bool hasItemsetId = itemsetId != null &&
          itemsetId.toString().trim().isNotEmpty &&
          itemsetId.toString().toLowerCase() != "null";

      return hasItemId || hasItemsetId;
    }).map<Map<String, dynamic>>((item) {
      final int? parsedItemId = int.tryParse(item["item_id"]?.toString() ?? "");

      final int? parsedApprovalItemId =
      int.tryParse(item["approval_item_id"]?.toString() ?? "");

      return {
        "item_id": parsedItemId ?? item["item_id"],
        if (_approvalPersonId != null) "approval_customer_id": _approvalPersonId,
        "itemset_id": int.tryParse(item["itemset_id"]?.toString() ?? "") ??
            parsedItemId ??
            item["item_id"],
        if (parsedApprovalItemId != null && parsedApprovalItemId > 0)
          "approval_item_id": parsedApprovalItemId,
        "qty": int.tryParse(item["qty"]?.toString() ?? "1") ?? 1,
        "gross_weight": _toD(item["gross_weight"]),
        "other_weight": _toD(item["other_weight"] ?? item["other"]),
        "net_weight": _toD(item["net_weight"]),
        "purity": _toD(item["purity"]),
        "waste": _toD(item["waste"]),
        "net_purity": _toD(item["net_purity"]),
        "fine_weight": _toD(item["fine_weight"]),
        "metal_rate": _toD(item["metal_rate"]),
        "metal_amount": _toD(item["metal_amount"]),
        "labour_rate": _toD(item["labour_rate"]),
        "labour_amount": _toD(item["labour_amount"]),
        "other_amount": _toD(item["other_amount"]),
        "total_amount": _toD(item["total_amount"]),
        "remarks": item["remarks"]?.toString() ?? "",
      };
    }).toList();

    if (allItemsToSave.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No valid items to save"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    debugPrint("================================================");
    debugPrint("🔥 UPDATE ITEMS COUNT => ${allItemsToSave.length}");

    for (int i = 0; i < allItemsToSave.length; i++) {
      final Map<String, dynamic> item = allItemsToSave[i];
      debugPrint("🔥 UPDATE ITEM ${i + 1}");
      debugPrint("item_id => ${item["item_id"]}");
      debugPrint("itemset_id => ${item["itemset_id"]}");
      debugPrint("FULL DATA => $item");
      debugPrint("------------------------------------------------");
    }

    final dynamic userId = widget.userData!["id"];

    final String receivedText = recived_amount_Controller.text.trim();
    final String additionalReceivedText = add_payment_Controller.text.trim();
    final int seconds = (60 + allItemsToSave.length).clamp(60, 180);
    final Map<String, dynamic> body = {
      "customer_id": int.parse(selectedUserId.toString()),
      "items": allItemsToSave,
      "received_amount":
      receivedText.isEmpty ? null : double.tryParse(receivedText),
      "additional_received_amount": additionalReceivedText.isEmpty
          ? null
          : double.tryParse(additionalReceivedText),
      "payment_mode": selectedPaymentMode,
      "payment_reference": payment_ref_Controller.text.trim(),
      "payment_note": payment_pending_Controller.text.trim(),
      "remarks": remarksController.text.trim(),
      "use_silver_balance": useSilverBalance,
      "show_previous_bills": showPreviousBills,
    };

    debugPrint("================================================");
    debugPrint("📤 UPDATE SALE ID => $userId");
    debugPrint("📤 UPDATE REQUEST BODY => $body");
    debugPrint("================================================");

    final response = await ApiHelper().putRequest(
      "${ApiConstants.Sale_update}/$userId",
      body,
      receiveTimeout: Duration(seconds: seconds),
    );

    if (!mounted) return;

    if (response != null && response.statusCode == 200) {
      AppMessage.success(
        context,
        response.data?["message"] ?? "Data Update Successfully",
      );

      setState(() {
        finalItems.clear();
        cartItems.clear();
        approvalAddedItems.clear();
        items.clear();
        _itemOrderMap.clear();
        _itemOrderCounter = 0;
      });

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SellList()),
            (route) => route.isFirst,
      );
    } else {
      final String message =
          response?.data?["message"]?.toString() ?? "Failed to Update Data";

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
    }
  }

  void calculateNetWeight(int index) {
    double gross = double.tryParse(tableRows[index]["gross"]!.text) ?? 0;
    double other = double.tryParse(tableRows[index]["other"]!.text) ?? 0;
    double net = gross - other;
    tableRows[index]["net"]!.text = net.toStringAsFixed(3);
  }

  Widget filterWidget() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 12, 10, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Consumer<ItemProvider>(
        builder: (context, provider, child) {
          final customers = provider.customers;
          final approvalCustomers = provider.Approval_customers;

          return LayoutBuilder(
            builder: (context, constraints) {
              final bool isMobile = constraints.maxWidth < 700;

              // ============================================================
              // CUSTOMER
              // ============================================================

              Widget customerField() {
                Map? selectedCustomer;

                if (selectedItem != null) {
                  for (final customer in customers) {
                    if (customer["id"]?.toString() == selectedItem.toString()) {
                      selectedCustomer = customer;
                      break;
                    }
                  }
                }

                return _premiumFieldWrapper(
                  label: "Customer",
                  child: _dropdownWithClear(
                    showClear: selectedCustomer != null,
                    onClear: () =>
                        _setCustomer(provider, null, approvalCustomers),
                    dropdown: PremiumSearchableDropdown<Map>(
                      label: "",
                      hint: "Select Customer",
                      items: List<Map>.from(customers),
                      value: selectedCustomer,
                      prefixIcon: Icons.person_outline,
                      itemLabel: (item) => item["name"]?.toString() ?? "-",
                      searchText: (item) {
                        return [
                          item["name"]?.toString() ?? "",
                          item["mobile_no"]?.toString() ?? "",
                          item["email"]?.toString() ?? "",
                          item["id"]?.toString() ?? "",
                        ].join(" ");
                      },
                      onChanged: (selectedData) => _setCustomer(
                          provider, selectedData, approvalCustomers),
                    ),
                  ),
                );
              }

              // ============================================================
              // APPROVAL PERSON
              // ============================================================

              Widget approvalField() {
                Map? selectedApprovalCustomer;

                if (selectedapprovalItem != null) {
                  for (final customer in approvalCustomers) {
                    if (customer["id"]?.toString() ==
                        selectedapprovalItem.toString()) {
                      selectedApprovalCustomer = customer;
                      break;
                    }
                  }
                }

                if (selectedApprovalCustomer == null &&
                    isEditMode &&
                    selectedItem != null &&
                    !_approvalManuallyCleared) {
                  for (final customer in approvalCustomers) {
                    if (customer["id"]?.toString() == selectedItem.toString()) {
                      selectedApprovalCustomer = customer;
                      break;
                    }
                  }
                }

                return _premiumFieldWrapper(
                  label: "Approval Person",
                  child: _dropdownWithClear(
                    showClear: selectedApprovalCustomer != null,
                    onClear: () => _setApprovalPerson(null),
                    dropdown: PremiumSearchableDropdown<Map>(
                      label: "",
                      hint: "Select Approval Person",
                      items: List<Map>.from(approvalCustomers),
                      value: selectedApprovalCustomer,
                      prefixIcon: Icons.verified_user_outlined,
                      itemLabel: (item) => item["name"]?.toString() ?? "-",
                      searchText: (item) {
                        return [
                          item["name"]?.toString() ?? "",
                          item["mobile_no"]?.toString() ?? "",
                          item["mobile"]?.toString() ?? "",
                          item["email"]?.toString() ?? "",
                          item["id"]?.toString() ?? "",
                        ].join(" ");
                      },
                      onChanged: (selectedData) =>
                          _setApprovalPerson(selectedData),
                    ),
                  ),
                );
              }

              // ============================================================
              // SEARCH
              // ============================================================

              Widget searchField() {
                return _premiumFieldWrapper(
                  label: "Scan / Search",
                  child: TextField(
                    controller: searchController,
                    onChanged: (value) {
                      setState(() {});
                      searchItemsApi(value);
                    },
                    style: const TextStyle(color: Colors.black87, fontSize: 13),
                    decoration: _premiumInputDecoration(
                      hint: "HUID / QR / Item",
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: Colors.black45,
                      ),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.all(4),
                        child: InkWell(
                          onTap: () {
                            FocusManager.instance.primaryFocus?.unfocus();

                            setState(() {
                              showScannerFull = true;
                            });
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            width: 42,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primaryDark.withOpacity(0.7),
                                  AppColors.border.withOpacity(0.7),
                                  AppColors.secondaryDark.withOpacity(0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.qr_code_scanner_rounded,
                              color: Colors.black87,
                              size: 21,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }

              // ============================================================
              // MAIN UI
              // ============================================================

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          customerField(),
                          const SizedBox(height: 8),
                          approvalField(),
                        ],
                      ),
                      const SizedBox(height: 5),
                      SizedBox(width: double.infinity, child: searchField()),
                    ],
                  ),

                  // SEARCH RESULT
                  if (searchController.text.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _searchResultDropdown(),
                    ),

                  const SizedBox(height: 5),

                  // BALANCE ROW
                  Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    color: AppColors.primaryDark.withOpacity(0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: BorderSide(color: AppColors.border),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        initiallyExpanded: false,
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 1,
                        ),
                        childrenPadding:
                        const EdgeInsets.fromLTRB(10, 4, 10, 10),
                        shape: const Border(),
                        collapsedShape: const Border(),
                        leading: Container(
                          width: 34,
                          height: 30,
                          decoration: BoxDecoration(
                            color: AppColors.gradientBlue.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 19,
                            color: AppColors.gradientBlue,
                          ),
                        ),
                        title: const Text(
                          "Sale & Payment Details",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        subtitle: const Text(
                          "Balance, remarks and payment information",
                          style: TextStyle(fontSize: 10, color: Colors.black45),
                        ),
                        iconColor: AppColors.gradientBlue,
                        collapsedIconColor: Colors.black54,
                        onExpansionChanged: (value) {
                          setState(() {
                            isSalePaymentExpanded = value;
                          });
                        },
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedRotation(
                              turns: isSalePaymentExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 22,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(width: 5),

                            /// + ADD ITEM
                            InkWell(
                              onTap: () {
                                FocusManager.instance.primaryFocus?.unfocus();

                                final Map<String, dynamic> freshRow =
                                createApprovalBlankItemRow();

                                setState(() {
                                  if (isEditMode) {
                                    approvalAddedItems.add(freshRow);
                                  } else {
                                    items.add(freshRow);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 27,
                                height: 27,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color:
                                  AppColors.gradientBlue.withOpacity(0.10),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.gradientBlue
                                        .withOpacity(0.25),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.add_rounded,
                                  size: 18,
                                  color: AppColors.gradientBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        children: [
                          _buildBalanceBoxes(provider, isMobile),

                          const SizedBox(height: 16),

                          Builder(
                            builder: (_) {
                              final Widget remarksField = _premiumFieldWrapper(
                                label: "Voucher Remarks",
                                child: TextFormField(
                                  controller: remarksController,
                                  minLines: 2,
                                  maxLines: 3,
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: _premiumInputDecoration(
                                    hint: "Enter remarks for this sale",
                                  ),
                                ),
                              );

                              if (!isMobile) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(flex: 3, child: remarksField),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        children: [
                                          _adjustFineBalanceTile(),
                                          const SizedBox(height: 8),
                                          _previousBillsTile(),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }

                              return Column(
                                children: [
                                  remarksField,
                                  const SizedBox(height: 10),
                                  _adjustFineBalanceTile(),
                                  const SizedBox(height: 8),
                                  _previousBillsTile(),
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 16),

                          // PAYMENT SECTION
                          if (!isMobile)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _premiumFieldWrapper(
                                    label: "Received Amount",
                                    child: TextFormField(
                                      controller: recived_amount_Controller,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      onChanged: (value) {
                                        final total = calculateTotals()["total"] ?? 0;
                                        final received = double.tryParse(value) ?? 0;
                                        payment_pending_Controller.text = (total - received).toStringAsFixed(2);
                                      },
                                      style: _blackFieldStyle,
                                      cursorColor: Colors.black,
                                      decoration: _premiumInputDecoration(hint: "0.00"),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _premiumFieldWrapper(
                                    label: "Payment Mode",
                                    child: DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      value: ["Cash", "Online", "UPI", "Bank", "Other"].contains(selectedPaymentMode)
                                          ? selectedPaymentMode
                                          : null,
                                      hint: const Text("Select Mode",
                                          style: TextStyle(color: Colors.black45, fontSize: 13)),
                                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black45),
                                      dropdownColor: Colors.white,
                                      style: _blackFieldStyle,
                                      decoration: _premiumInputDecoration(),
                                      items: _paymentModeItems(),
                                      onChanged: (value) => setState(() => selectedPaymentMode = value),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _premiumFieldWrapper(
                                    label: "Payment Ref No",
                                    child: TextFormField(
                                      controller: payment_ref_Controller,
                                      style: _blackFieldStyle,
                                      cursorColor: Colors.black,
                                      decoration: _premiumInputDecoration(hint: "Txn/Ref No"),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _premiumFieldWrapper(
                                    label: "Pending Amount",
                                    child: TextFormField(
                                      controller: payment_pending_Controller,
                                      readOnly: true,
                                      style: _blackFieldStyle,
                                      decoration: _premiumInputDecoration(hint: "0.00", readOnly: true),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _premiumFieldWrapper(
                                        label: "Received Amount",
                                        child: TextFormField(
                                          controller: recived_amount_Controller,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          onChanged: (value) {
                                            final total = calculateTotals()["total"] ?? 0;
                                            final received = double.tryParse(value) ?? 0;
                                            payment_pending_Controller.text = (total - received).toStringAsFixed(2);
                                          },
                                          style: _blackFieldStyle,
                                          cursorColor: Colors.black,
                                          decoration: _premiumInputDecoration(hint: "0.00"),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _premiumFieldWrapper(
                                        label: "Payment Mode",
                                        child: DropdownButtonFormField<String>(
                                          isExpanded: true,
                                          value: ["Cash", "Online", "UPI", "Bank", "Other"].contains(selectedPaymentMode)
                                              ? selectedPaymentMode
                                              : null,
                                          hint: const Text("Select Mode",
                                              style: TextStyle(fontSize: 12, color: Colors.black45)),
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black45),
                                          dropdownColor: Colors.white,
                                          style: _blackFieldStyle,
                                          decoration: _premiumInputDecoration(),
                                          items: _paymentModeItems(),
                                          onChanged: (value) => setState(() => selectedPaymentMode = value),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _premiumFieldWrapper(
                                        label: "Payment Ref No",
                                        child: TextFormField(
                                          controller: payment_ref_Controller,
                                          style: _blackFieldStyle,
                                          cursorColor: Colors.black,
                                          decoration: _premiumInputDecoration(hint: "Txn/Ref No"),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _premiumFieldWrapper(
                                        label: "Pending Amount",
                                        child: TextFormField(
                                          controller: payment_pending_Controller,
                                          readOnly: true,
                                          style: _blackFieldStyle,
                                          decoration: _premiumInputDecoration(hint: "0.00", readOnly: true),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

// EDIT MODE ADD PAYMENT
                          if (isEditMode) ...[
                            const SizedBox(height: 14),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: isMobile ? double.infinity : constraints.maxWidth / 4,
                                child: _premiumFieldWrapper(
                                  label: "Add Payment",
                                  child: TextFormField(
                                    controller: add_payment_Controller,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: _blackFieldStyle,
                                    cursorColor: Colors.black,
                                    decoration: _premiumInputDecoration(hint: "Add Payment (Later)"),
                                  ),
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> getApprovalDetails(int? customerId) async {
    if (customerId == null) {
      print("CustomerId NULL");
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final response = await ApiHelper().getRequest(
      "${ApiConstants.label_Approval_list}?approval_customer_id=$customerId",
    );

    Navigator.pop(context);

    if (response != null && response.statusCode == 200) {
      final data = response.data;
      List items = data["data"];

      if (items.isNotEmpty) {
        Set<int> addedIds = approvalAddedItems.map<int>((e) {
          return int.tryParse(e["approval_item_id"].toString()) ?? 0;
        }).toSet();

        List filteredItems = items.where((item) {
          int id = int.tryParse(item["approval_item_id"].toString()) ?? 0;
          return !addedIds.contains(id);
        }).toList();

        final selectedIds = await showApprovalDialog(filteredItems);

        if (selectedIds != null && selectedIds.isNotEmpty) {
          addSelectedItems(selectedIds, items);

          updateFinalItems();
          setState(() {});
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Data Not Found"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void addSelectedItems(Set<int> selectedIds, List allItems) {
    final List selectedData = allItems.where((item) {
      final int id =
          int.tryParse(item["approval_item_id"]?.toString() ?? "0") ?? 0;

      return selectedIds.contains(id);
    }).toList();

    setState(() {
      approvalAddedItems.removeWhere((e) => e["is_fresh"] == true);

      for (var rawItem in selectedData) {
        final Map<String, dynamic> item = Map<String, dynamic>.from(rawItem);

        final dynamic itemsetId = item["itemset_id"];
        final dynamic approvalId = item["approval_item_id"];

        item["show_item_dropdown"] = false;
        item["is_fresh"] = false;

        final String itemName = item["item_name"]?.toString() ??
            item["name"]?.toString() ??
            item["item"]?["item_name"]?.toString() ??
            "";

        item["item_name"] = itemName;
        item["item"] = itemName;

        item["item_id"] = item["item_id"] ?? item["item"]?["id"];

        item["gross_weight"] = item["gross_weight"]?.toString() ?? "0";
        item["other_weight"] = item["other_weight"]?.toString() ?? "0";
        item["net_weight"] = item["net_weight"]?.toString() ?? "0";

        item["purity"] = item["purity"]?.toString() ??
            item["outward_carat"]?.toString() ??
            "0";

        item["waste"] = item["waste_percent"]?.toString() ??
            item["waste"]?.toString() ??
            "0";

        item["outward_carat"] = item["outward_carat"]?.toString() ?? "0";
        item["net_purity"] = item["net_purity"]?.toString() ?? "0";
        item["fine_weight"] = item["fine_weight"]?.toString() ?? "0";

        item["metal_rate"] = item["metal_rate"]?.toString() ?? "0";
        item["metal_amount"] = item["metal_amount"]?.toString() ?? "0";

        item["labour_rate"] = item["labour_rate"]?.toString() ??
            item["item"]?["labour_rate"]?.toString() ??
            "0";
        item["labour_amount"] = item["labour_amount"]?.toString() ?? "0";

        item["qty"] = item["qty"]?.toString() ?? "1";
        item["remarks"] = item["remarks"]?.toString() ?? "";

        item["other_amount"] = item["other_amount"]?.toString() ?? "0";
        item["total_amount"] = item["total_amount"]?.toString() ?? "0";

        item["manual_metal"] = item["manual_metal"] ?? true;
        item["manual_labour"] = item["manual_labour"] ?? true;

        setController(item, "gross_weight", item["gross_weight"]);
        setController(item, "other_weight", item["other_weight"]);
        setController(item, "net_weight", item["net_weight"]);
        setController(item, "purity", item["purity"]);
        setController(item, "waste", item["waste"]);
        setController(item, "outward_carat", item["outward_carat"]);
        setController(item, "net_purity", item["net_purity"]);
        setController(item, "fine_weight", item["fine_weight"]);
        setController(item, "metal_rate", item["metal_rate"]);
        setController(item, "metal_amount", item["metal_amount"]);
        setController(item, "labour_rate", item["labour_rate"]);
        setController(item, "labour_amount", item["labour_amount"]);
        setController(item, "qty", item["qty"]);
        setController(item, "remarks", item["remarks"]);
        setController(item, "other_amount", item["other_amount"]);
        setController(item, "total_amount", item["total_amount"]);

        calculateItem(item);

        if (!finalItems.any(
              (e) => e["itemset_id"]?.toString() == itemsetId?.toString(),
        )) {
          finalItems.add({
            "itemset_id": itemsetId,
            "approval_item_id": approvalId,
          });
        }

        if (!approvalAddedItems.any(
              (e) => e["approval_item_id"]?.toString() == approvalId?.toString(),
        )) {
          approvalAddedItems.add(item);
        }
      }

      updateFinalItems();
    });
  }

  Future<Set<int>?> showApprovalDialog(List items) async {
    selectedItems.clear();
    List filteredItems = List.from(items);
    TextEditingController approvesearchController = TextEditingController();
    bool showScanner = false;
    return showDialog<Set<int>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
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
                width: MediaQuery.of(context).size.width * 0.92,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// 🔝 HEADER
                    Row(
                      children: [
                        const Text(
                          "Approval Items",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () {
                            setState(() {
                              showScanner = !showScanner;
                            });
                          },
                          borderRadius: BorderRadius.circular(5),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 5,
                              horizontal: 5,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xffE6C58A), Color(0xffC8A96A)],
                              ),
                              borderRadius: BorderRadius.circular(5),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                  const Color(0xffC8A96A).withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.qr_code_scanner,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              "Back",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    /// 🔍 SEARCH FIELD
                    TextField(
                      controller: approvesearchController,
                      onChanged: (value) {
                        setState(() {
                          if (value.isEmpty) {
                            filteredItems = items;
                          } else {
                            filteredItems = items.where((item) {
                              final name =
                                  item["name"]?.toString().toLowerCase() ?? "";
                              final code =
                                  item["code"]?.toString().toLowerCase() ?? "";
                              final huid =
                                  item["HUID"]?.toString().toLowerCase() ?? "";

                              return name.contains(value.toLowerCase()) ||
                                  code.contains(value.toLowerCase()) ||
                                  huid.contains(value.toLowerCase());
                            }).toList();
                          }
                        });
                      },
                      decoration: InputDecoration(
                        hintText: "Search Item",
                        hintStyle: TextStyle(color: Colors.grey.shade600),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.black54,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    /// 🔥 SCANNER
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) {
                        final offsetAnimation = Tween<Offset>(
                          begin: const Offset(0, -1),
                          end: Offset.zero,
                        ).animate(animation);

                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SlideTransition(
                            position: offsetAnimation,
                            child: child,
                          ),
                        );
                      },
                      child: showScanner
                          ? Center(
                        child: Container(
                          key: const ValueKey("scanner"),
                          height: 150,
                          width: 150,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Stack(
                            children: [
                              _buildScannerSection(),
                              _ScannerLineAnimation(),
                            ],
                          ),
                        ),
                      )
                          : const SizedBox(key: ValueKey("empty")),
                    ),

                    /// 🔥 LIST
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];

                          final id = int.tryParse(
                            item["approval_item_id"].toString(),
                          ) ??
                              0;
                          final code = item["code"] ?? "-";
                          final name = item["name"] ?? "-";
                          final gross = item["gross_weight"]?.toString() ?? "-";

                          final isSelected = selectedItems.contains(id);

                          return Stack(
                            children: [
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: isSelected,
                                      activeColor: const Color(0xffC8A96A),
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
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  "Name: $name",
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.black,
                                                  ),
                                                  overflow:
                                                  TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Expanded(
                                                child: Text(
                                                  "Code: $code",
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            "Gross: $gross",
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              /// 🔥 Index Count
                              Positioned(
                                top: 5,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Color(0xffC8A96A),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(5),
                                      bottomRight: Radius.circular(5),
                                    ),
                                  ),
                                  child: Text(
                                    "${index + 1}",
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
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    /// ADD BUTTON
                    InkWell(
                      onTap: () async {
                        FocusManager.instance.primaryFocus?.unfocus();

                        if (selectedItems.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Please select at least one item"),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        final List<dynamic> itemsToAdd = items.where((item) {
                          final int id = int.tryParse(
                            item["approval_item_id"].toString(),
                          ) ??
                              0;

                          return selectedItems.contains(id);
                        }).toList();

                        for (final item in itemsToAdd) {
                          final String? qrCode = item["code"]?.toString() ??
                              item["qr_code"]?.toString();

                          if (qrCode == null || qrCode.trim().isEmpty) {
                            continue;
                          }

                          /// 🔥 scan પહેલાં approval / itemset id યાદ રાખો
                          _rememberScanInfo(
                            qrCode,
                            approvalItemId: item["approval_item_id"],
                            itemsetId: item["itemset_id"],
                          );

                          await scanApiCall(qrCode);
                        }

                        if (!context.mounted) return;

                        Navigator.pop(context, selectedItems);
                      },
                      child: Center(
                        child: Container(
                          width: 100,
                          height: 40,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xffC8A96A), Color(0xffE6C58A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Center(
                            child: Text(
                              "Add",
                              style: TextStyle(
                                color: Colors.black,
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
          },
        );
      },
    );
  }

  Widget _erpRow(String t1, String v1, String t2, String v2) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    t1,
                    style: const TextStyle(fontSize: 12, color: Colors.black),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    v1,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    t2,
                    style: const TextStyle(fontSize: 12, color: Colors.black),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    v2,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black,
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

  Widget approvalItemCard(
      Map<String, dynamic> item,
      int index,
      int totalCount,
      ) {
    bool isExpanded = item["expanded"] ?? false;

    final String itemName =
        item["name"]?.toString() ?? item["item_name"]?.toString() ?? "Item";

    final String qrCode = item["qr_code"]?.toString() ??
        item["itemset"]?["qr_code"]?.toString() ??
        item["code"]?.toString() ??
        item["itemset"]?["barcode"]?.toString() ??
        "-";

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
                    "${totalCount - index}",
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

                const SizedBox(width: 8),

                /// QR CODE
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

                const SizedBox(width: 7),

                /// DELETE
                InkWell(
                  onTap: () async {
                    final approvalId = item["approval_item_id"];
                    final itemId = item["id"];
                    final itemsetId = item["itemset_id"];

                    if (isEditMode && item["is_saved_item"] == true) {
                      final String saleId = widget.userData!["id"].toString();
                      final saleItemsetId = item["itemset_id"].toString();

                      print("🗑️ DELETE SAVED SALE ITEM");
                      print("SALE ID     => $saleId");
                      print("ITEMSET ID  => $saleItemsetId");

                      await deleteSaleItem(
                        saleId: saleId,
                        itemsetId: saleItemsetId,
                      );
                    }

                    setState(() {
                      if (itemsetId != null) {
                        final cartItem = cartItems.firstWhere(
                              (e) =>
                          e["itemset_id"]?.toString() ==
                              itemsetId.toString(),
                          orElse: () => {},
                        );
                        final cartId = cartItem["cart_id"]?.toString() ?? "";
                        if (cartId.isNotEmpty) deleteUser(cartId);

                        cartItems.removeWhere((e) =>
                        e["itemset_id"]?.toString() ==
                            itemsetId.toString());
                        approvalAddedItems.removeWhere((e) =>
                        e["itemset_id"]?.toString() ==
                            itemsetId.toString());
                      } else if (approvalId != null) {
                        approvalAddedItems.removeWhere(
                                (e) => e["approval_item_id"] == approvalId);
                      } else {
                        items.removeWhere(
                                (e) => e["id"] == (itemId ?? itemsetId));
                      }

                      updateFinalItems();
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

          /// HORIZONTAL ITEM DETAILS
          if (!isExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (item["show_item_dropdown"] == true) ...[
                      _labourDropdown(item),
                      const SizedBox(width: 0),
                    ],
                    _miniField("Qty", item, "qty", index),
                    _miniField("Gross", item, "gross_weight", index),
                    _miniField("Other", item, "other_weight", index),
                    _miniField("Net", item, "net_weight", index),
                    _miniField("Purity", item, "purity", index),
                    _miniField("Waste", item, "waste", index),
                    _miniField("Net Purity", item, "net_purity", index),
                    _miniField("Fine", item, "fine_weight", index),
                    _miniField("Metal Rate", item, "metal_rate", index),
                    _miniField("Metal Amount", item, "metal_amount", index),
                    _miniField("Labour Rate", item, "labour_rate", index),
                    _miniField("Labour Amount", item, "labour_amount", index),
                    _miniField("Other Amount", item, "other_amount", index),
                    _miniField("Total Amount", item, "total_amount", index),
                    _miniField("Remarks", item, "remarks", index),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniField(
      String title,
      Map<String, dynamic> item,
      String key,
      int index,
      ) {
    final bool isOtherField = key == "other_amount";
    final bool isMetalRateField = key == "metal_rate";
    final bool isLabourRateField = key == "labour_rate";
    final bool isPurityField = key == "purity";
    final bool isWasteField = key == "waste";
    final bool isRemarksField = key == "remarks";

    final controller = getController(item, key);

    final bool editable = key == "metal_rate"
        ? (item["manual_metal"] ?? true)
        : key == "labour_rate"
        ? (item["manual_labour"] ?? true)
        : isEditableField(key);

    return Container(
      width: isRemarksField ? 140 : 105,
      margin: const EdgeInsets.only(right: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, right: 2, bottom: 4),
            child: Row(
              children: [
                Expanded(
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

                /// ONLY FIRST ROW → "All" button
                if (index == 0 &&
                    (isMetalRateField ||
                        isLabourRateField ||
                        isOtherField ||
                        isPurityField ||
                        isWasteField))
                  InkWell(
                    onTap: () async {
                      await applyRateToAllItems(
                        sourceItem: item,
                        key: key,
                      );
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xffC8A96A),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "All",
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          /// FIELD
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
                  readOnly: key == "metal_rate"
                      ? !(item["manual_metal"] ?? true)
                      : key == "labour_rate"
                      ? !(item["manual_labour"] ?? true)
                      : !isEditableField(key),
                  keyboardType: isRemarksField
                      ? TextInputType.text
                      : const TextInputType.numberWithOptions(decimal: true),
                  enableInteractiveSelection: isEditableField(key),
                  showCursor: isEditableField(key),
                  canRequestFocus: isEditableField(key),
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: editable ? Colors.black : Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  onTap: () {
                    if (isRemarksField) return;

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
                  onEditingComplete: () {
                    if (!isRemarksField && controller.text.isEmpty) {
                      controller.text = "0";
                    }

                    FocusScope.of(context).unfocus();
                  },
                  onChanged: (val) {
                    item[key] = val;

                    if (item["source"] == "sale") {
                      final cartIndex = cartItems.indexWhere(
                            (c) =>
                        c["itemset_id"]?.toString() ==
                            item["itemset_id"]?.toString(),
                      );
                      if (cartIndex != -1) {
                        cartItems[cartIndex][key] = val;
                      }
                    }

                    calculateItem(item);
                    updateFinalItems();
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.only(
                      left: 8,
                      right: (isOtherField ||
                          isMetalRateField ||
                          isLabourRateField)
                          ? 30
                          : 8,
                      top: 9,
                      bottom: 9,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),

                /// OTHER AMOUNT +
                if (isOtherField)
                  Positioned(
                    right: 4,
                    child: InkWell(
                      onTap: () async {
                        FocusManager.instance.primaryFocus?.unfocus();

                        await getreturnDetails(item["id"], item);

                        Future.delayed(const Duration(milliseconds: 100), () {
                          FocusManager.instance.primaryFocus?.unfocus();
                        });

                        controller.text =
                            item["other_amount"]?.toString() ?? "0";

                        calculateItem(item);
                        updateFinalItems();
                        setState(() {});
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

                /// METAL RATE CHECKBOX
                if (isMetalRateField)
                  Positioned(
                    right: 3,
                    child: SizedBox(
                      height: 25,
                      width: 25,
                      child: Transform.scale(
                        scale: 0.78,
                        child: Checkbox(
                          materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                          value: (double.tryParse(
                            controller.text.isEmpty
                                ? "0"
                                : controller.text,
                          ) ??
                              0) >
                              0,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                if ((double.tryParse(
                                  controller.text.isEmpty
                                      ? "0"
                                      : controller.text,
                                ) ??
                                    0) ==
                                    0) {
                                  controller.text = "1";
                                  item["metal_rate"] = "1";
                                }
                              } else {
                                controller.text = "0.00";
                                item["metal_rate"] = "0.00";
                              }

                              updateController(item, "metal_rate");
                              calculateItem(item);
                              updateFinalItems();
                            });
                          },
                        ),
                      ),
                    ),
                  ),

                /// LABOUR RATE CHECKBOX
                if (isLabourRateField)
                  Positioned(
                    right: 3,
                    child: SizedBox(
                      height: 25,
                      width: 25,
                      child: Transform.scale(
                        scale: 0.78,
                        child: Checkbox(
                          materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                          value: (double.tryParse(
                            controller.text.isEmpty
                                ? "0"
                                : controller.text,
                          ) ??
                              0) >
                              0,
                          onChanged: (val) {
                            setState(() {
                              if (val == false) {
                                controller.text = "0.00";
                                item["labour_rate"] = "0.00";
                              } else {
                                if ((double.tryParse(
                                  controller.text.isEmpty
                                      ? "0"
                                      : controller.text,
                                ) ??
                                    0) ==
                                    0) {
                                  controller.clear();
                                }
                              }

                              updateController(item, "labour_rate");
                              calculateItem(item);
                              updateFinalItems();
                            });
                          },
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

  Future<void> searchItemsApi(String keyword) async {
    if (keyword.isEmpty) {
      setState(() {
        searchResults = [];
      });
      return;
    }

    final response = await ApiHelper().getRequest(
      "${ApiConstants.Approval_search}?keyword=$keyword",
      showLoading: false,
    );

    if (response != null && response.statusCode == 200) {
      List allResults = response.data["data"] ?? [];

      Set<String> addedIds = {
        ...items.map((e) => e["id"].toString()),
        ...cartItems.map((e) => e["itemset_id"].toString()),
        ...approvalAddedItems.map((e) => e["itemset_id"].toString()),
      };

      setState(() {
        searchResults = allResults.where((resItem) {
          return !addedIds.contains(resItem["id"].toString());
        }).toList();
      });
    } else {
      print("Search API Failed");
    }
  }

  void addItemToCard(dynamic e) {
    setState(() {
      final itemsetId = e["id"];

      bool isDuplicate = items.any((item) => item["id"] == itemsetId) ||
          approvalAddedItems.any(
                (item) =>
            item["itemset_id"] == itemsetId ||
                item["approval_item_id"] == itemsetId,
          ) ||
          cartItems.any(
                (item) => item["id"] == itemsetId || item["itemset_id"] == itemsetId,
          );

      if (isDuplicate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Item already added to the list"),
            backgroundColor: Colors.orange,
          ),
        );
        searchController.clear();
        searchResults.clear();
        return;
      }

      Map<String, dynamic> newItem = {
        "id": e["id"],
        "itemset_id": e["id"],
        "item_name": e["item"]?["item_name"] ?? "",
        "item_id": e["item"]?["id"],
        "show_item_dropdown": false,
        "huid": e["HUID"] ?? "",
        "qr_code": e["qr_code"] ?? "",
        "gross_weight": e["gross_weight"]?.toString() ?? "0",
        "other_weight": e["other_weight"]?.toString() ?? "0",
        "net_weight": e["net_weight"]?.toString() ?? "0",
        "purity": e["purity"]?.toString() ?? "0",
        "waste": "0",
        "net_purity": e["net_purity"]?.toString() ?? "0",
        "fine_weight": e["fine_weight"]?.toString() ?? "0",
        "metal_rate": e["metal_rate"]?.toString() ?? "0",
        "metal_amount": e["metal_amount"]?.toString() ?? "0",
        "labour_rate": e["item"]?["labour_rate"]?.toString() ?? "0",
        "labour_amount": "0",
        "qty": e["qty"]?.toString() ?? "1",
        "remarks": e["remarks"]?.toString() ?? "",
        "other_amount": e["sale_other"]?.toString() ?? "0",
        "total_amount": e["sale_other"]?.toString() ?? "0",
        "expanded": false,
      };

      setController(newItem, "gross_weight", newItem["gross_weight"]);
      setController(newItem, "other_weight", newItem["other_weight"]);
      setController(newItem, "purity", newItem["purity"]);
      setController(newItem, "labour_rate", newItem["labour_rate"]);
      setController(newItem, "qty", newItem["qty"]);
      setController(newItem, "remarks", newItem["remarks"]);
      setController(newItem, "other_amount", newItem["other_amount"]);
      setController(newItem, "total_amount", newItem["other_amount"]);

      calculateItem(newItem);

      items.add(newItem);

      if (!finalItems.any((item) => item["itemset_id"] == itemsetId)) {
        finalItems.add({"itemset_id": itemsetId});
      }

      updateFinalItems();

      searchController.clear();
      searchResults.clear();
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  bool isProcessing = false;

  String? lastCode;
  bool isBusy = false;

  Widget _buildScannerSection() {
    double scannerSize = MediaQuery.of(context).size.width * 0.4;
    if (MediaQuery.of(context).size.width > 600) scannerSize = 350;

    return Container(
      width: scannerSize,
      height: scannerSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: MobileScanner(
          controller: _scannerController,
          onDetect: (barcodeCapture) async {
            for (final barcode in barcodeCapture.barcodes) {
              final String? code = barcode.rawValue?.trim();

              if (code == null || code.isEmpty) continue;

              if (lastCode == code) continue;

              if (isBusy) return;

              lastCode = code;
              isBusy = true;

              debugPrint("⚡ SCAN: $code");

              try {
                await scanApiCall(code);
              } finally {
                isBusy = false;

                Future.delayed(const Duration(seconds: 2), () {
                  if (lastCode == code) lastCode = null;
                });
              }

              return;
            }
          },
        ),
      ),
    );
  }

  Widget buildUserCard(Map item) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;

    final itemset = item["itemset"] ?? {};
    final itemData = itemset["item"] ?? {};

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: const Color(0xffFAF7F2).withOpacity(0.9),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              statusChip(itemData["metal"]?.toString() ?? "-"),
              const Spacer(),
              Row(
                children: [
                  premiumIconBtn(Icons.edit, Colors.blue, onTap: () {}),
                  SizedBox(width: isTablet ? 10 : 8),
                  premiumIconBtn(
                    Icons.delete,
                    Colors.red,
                    onTap: () {
                      setState(() {
                        _showDeleteDialog(item);
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: isTablet ? 10 : 8),
          Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  itemData["item_name"] ?? "",
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                itemset["qr_code"] ?? "",
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade200, width: 1.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                _erpRow(
                  "Gross",
                  itemset["gross_weight"] ?? "-",
                  "Net",
                  (itemset["net_weight"] == "0.000" ||
                      itemset["net_weight"] == null)
                      ? "-"
                      : itemset["net_weight"],
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                _erpRow(
                  "Purity",
                  itemData["outward_carat"] ?? "-",
                  "Amount",
                  "₹ ${itemset["sale_labour_amount"] ?? 0}",
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
        startColor = const Color(0xff9E9E9E);
        endColor = const Color(0xffCFCFCF);
        label = "Unknown";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [startColor, endColor]),
        borderRadius: BorderRadius.circular(8),
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
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
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
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  void _showDeleteDialog(Map user) {
    showGeneralDialog(
      context: context,
      barrierLabel: "Delete",
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        final screenWidth = MediaQuery.of(context).size.width;

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Center(
            child: Container(
              width: screenWidth * 0.85,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                color: Colors.white.withOpacity(0.1),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xffff4e50), Color(0xfff00000)],
                      ),
                    ),
                    child: const Icon(
                      Icons.delete,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "Delete User?",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Are you sure you want to delete ${user["name"]}?",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 25),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade800,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "Cancel",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xfff00000),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () async {
                            Navigator.pop(context);
                            deleteUser(user["id"].toString());
                          },
                          child: const Text(
                            "Delete",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
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
      transitionBuilder: (context, anim, _, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> deleteUser(String ID) async {
    try {
      final response = await ApiHelper().deleteRequest(
        "${ApiConstants.sale_cart_remove}/$ID",
      );

      if (response?.statusCode == 200) {
        print("✅ Deleted Successfully");
        print("Response: ${response?.data}");

        getCartItems();
      } else {
        print("❌ Delete failed | Status: ${response?.statusCode}");
      }
    } catch (e) {
      print("❌ Delete exception: $e");
    }
  }

  Future<void> deleteSaleItem({
    required String saleId,
    required String itemsetId,
  }) async {
    try {
      final response = await ApiHelper().deleteRequest(
        "/sales/$saleId/items/$itemsetId",
      );

      print("DELETE SALE ITEM RESPONSE => ${response!.data}");
    } catch (e) {
      print("DELETE SALE ITEM ERROR => $e");
    }
  }

  // ============================================================
  // 🔥 SCAN INFO — QR → { approval_item_id, itemset_id }
  // ============================================================
  final Map<String, Map<String, int>> _scanInfoByQr = {};

  /// કયા Approval Person ની pending items load થઈ છે
  String? _scanInfoLoadedFor;

  String _qrKey(String qr) => qr.trim().toLowerCase();

  int? _toPositiveInt(dynamic v) {
    final int? n = int.tryParse(v?.toString() ?? "");
    return (n != null && n > 0) ? n : null;
  }

  /// 🔥 Approval Person select હોય તો એનો id, નહીં તો null
  int? get _approvalPersonId => _toPositiveInt(selectedApprovalUserId);

  /// QR માટે approval / itemset id યાદ રાખો
  void _rememberScanInfo(
      String? qr, {
        dynamic approvalItemId,
        dynamic itemsetId,
      }) {
    if (qr == null || qr.trim().isEmpty) return;

    final Map<String, int> info = _scanInfoByQr[_qrKey(qr)] ?? {};

    final int? aid = _toPositiveInt(approvalItemId);
    final int? isid = _toPositiveInt(itemsetId);

    if (aid != null) info["approval_item_id"] = aid;
    if (isid != null) info["itemset_id"] = isid;

    if (info.isNotEmpty) _scanInfoByQr[_qrKey(qr)] = info;
  }

  /// Customer / Approval Person બદલાય ત્યારે જૂની info હટાવો
  void _clearScanInfo() {
    _scanInfoByQr.clear();
    _scanInfoLoadedFor = null;
  }

  /// 🔥 Camera scan માટે: Approval Person ની pending items → map
  Future<void> _loadApprovalScanInfo() async {
    final int? approvalId = _approvalPersonId;
    if (approvalId == null) return;
    if (_scanInfoLoadedFor == approvalId.toString()) return;

    try {
      final response = await ApiHelper().getRequest(
        "${ApiConstants.label_Approval_list}?approval_customer_id=$approvalId",
        showLoading: false,
      );

      if (response == null || response.statusCode != 200) return;

      final List list = response.data["data"] ?? [];

      for (final item in list) {
        _rememberScanInfo(
          (item["code"] ?? item["qr_code"])?.toString(),
          approvalItemId: item["approval_item_id"],
          itemsetId: item["itemset_id"],
        );
      }

      _scanInfoLoadedFor = approvalId.toString();
      debugPrint("🔥 Approval scan info loaded => ${_scanInfoByQr.length}");
    } catch (e) {
      debugPrint("Approval scan info error => $e");
    }
  }

  // ============================================================
  // 🔥 SCAN API
  // ============================================================
  Future<void> scanApiCall(String code) async {
    final int? customerId = _toPositiveInt(selectedUserId);

    if (customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select Customer first"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    /// DEVICE ID (એક જ વાર)
    if (deviceId == null || deviceId!.trim().isEmpty) {
      try {
        final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

        if (Platform.isAndroid) {
          deviceId = (await deviceInfo.androidInfo).id;
        } else if (Platform.isIOS) {
          deviceId = (await deviceInfo.iosInfo).identifierForVendor ?? "";
        }
      } catch (e) {
        debugPrint("DeviceInfo Error => $e");
      }
    }

    /// Camera scan: map માં ના હોય તો approval items load કરો
    if (!_scanInfoByQr.containsKey(_qrKey(code))) {
      await _loadApprovalScanInfo();
      if (!mounted) return;
    }

    final Map<String, int>? info = _scanInfoByQr[_qrKey(code)];
    final int? approvalItemId = info?["approval_item_id"];
    final int? itemsetId = info?["itemset_id"];
    final int? approvalCustomerId = _approvalPersonId;

    final Map<String, dynamic> body = {
      "qr_code": code,
      "customer_id": customerId,
      if (approvalCustomerId != null) "approval_customer_id": approvalCustomerId,
      if (approvalItemId != null) "approval_item_id": approvalItemId,
      if (itemsetId != null) "itemset_id": itemsetId,
      "device_id": deviceId,
      "voucher_session_id": voucherSessionId,
      "device_entry_id": _generateDeviceEntryId(),
    };

    debugPrint("📤 SCAN => $body");

    final response = await ApiHelper().postRequest(
      ApiConstants.sales_add_to_cart,
      body,
    );

    if (!mounted) return;

    if (response == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Server Response Error"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    debugPrint("📥 SCAN ${response.statusCode} => ${response.data}");

    final data = response.data;

    if (response.statusCode == 200 && data is Map && data["success"] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Item Scan Successfully"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      await getCartItems(customerId: customerId.toString());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (data is Map ? data["message"]?.toString() : null) ?? "Scan Failed",
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  int _cartRequestId = 0;

  Future<void> getCartItems({String? customerId}) async {
    final int requestId = ++_cartRequestId;

    final String? cid = customerId ?? selectedUserId;

    String url = ApiConstants.sales_cart_items;
    if (cid != null && cid.trim().isNotEmpty) {
      url += "${url.contains('?') ? '&' : '?'}customer_id=$cid";
    }

    debugPrint("📤 CART URL => $url");

    final response = await ApiHelper().getRequest(url);

    if (!mounted || requestId != _cartRequestId) return;

    debugPrint("Cart Raw Response: ${response?.data}");

    if (response == null || response.statusCode != 200) {
      setState(() {
        cartItems = [];
        updateFinalItems();
      });
      debugPrint("Cart API Failed");
      return;
    }

    final List resData = response.data["data"] ?? [];

    final Set<String> existingItemsetIds = items
        .map((e) => (e["itemset_id"] ?? e["id"])?.toString())
        .where((id) => id != null && id.trim().isNotEmpty)
        .cast<String>()
        .toSet();

    final List filteredCartData = resData.where((item) {
      final String rowCustomer = item["customer_id"]?.toString() ?? "";
      if (cid != null && rowCustomer.isNotEmpty && rowCustomer != cid) {
        return false;
      }

      final String? cartItemsetId =
      (item["itemset_id"] ?? item["itemset"]?["id"])?.toString();

      if (cartItemsetId == null || cartItemsetId.trim().isEmpty) return true;

      return !existingItemsetIds.contains(cartItemsetId);
    }).toList();

    /// 🔥 Refresh પહેલાં local other-charge values યાદ રાખો
    final Map<String, Map<String, dynamic>> keepLocal = {};
    for (final c in cartItems) {
      final String? key = (c["itemset_id"] ?? c["id"])?.toString();
      if (key == null || c["other_charge_id"] == null) continue;

      keepLocal[key] = {
        "other_charge_id": c["other_charge_id"],
        "other_charge_detail": c["other_charge_detail"],
        "other_amount": c["other_amount"],
      };
    }

    setState(() {
      cartItems = filteredCartData;

      for (var item in cartItems) {
        final itemset = item["itemset"] ?? {};
        final itemData = itemset["item"] ?? {};

        item["cart_id"] = item["id"];
        item["id"] = item["itemset_id"] ?? item["id"];

        final int? cartApprovalId =
        int.tryParse(item["approval_item_id"]?.toString() ?? "");
        item["approval_item_id"] =
        (cartApprovalId != null && cartApprovalId > 0)
            ? cartApprovalId
            : null;

        item["gross_weight"] =
            (item["gross_weight"] ?? itemset["gross_weight"])?.toString() ??
                "0";
        item["other_weight"] =
            (item["other_weight"] ?? itemset["other"])?.toString() ?? "0";
        item["net_weight"] =
            (item["net_weight"] ?? itemset["net_weight"])?.toString() ?? "0";

        item["purity"] =
            (item["purity"] ?? itemData["outward_carat"])?.toString() ?? "0";
        item["waste"] =
            (item["waste_percent"] ?? item["waste"])?.toString() ?? "0";

        item["labour_rate"] =
            (item["labour_rate"] ?? itemset["sale_labour_rate"])?.toString() ??
                "0";
        item["labour_amount"] =
            (item["labour_amount"] ?? itemset["sale_labour_amount"])
                ?.toString() ??
                "0";

        item["metal_rate"] = item["metal_rate"]?.toString() ?? "0";
        item["metal_amount"] = item["metal_amount"]?.toString() ?? "0";

        item["qty"] = item["qty"]?.toString() ?? "1";
        item["remarks"] = item["remarks"]?.toString() ?? "";

        item["other_amount"] =
            (item["other_amount"] ?? itemset["sale_other"])?.toString() ?? "0";
        item["total_amount"] = item["total_amount"]?.toString() ?? "0";

        final String? localKey = item["itemset_id"]?.toString();
        if (localKey != null && keepLocal.containsKey(localKey)) {
          item.addAll(keepLocal[localKey]!);
        }

        item["item_name"] =
        (item["item_name"]?.toString().trim().isNotEmpty == true)
            ? item["item_name"]
            : (itemData["item_name"] ?? "");
        item["qr_code"] = item["qr_code"] ?? itemset["qr_code"] ?? "";
        item["huid"] = item["huid"] ?? item["HUID"] ?? itemset["HUID"] ?? "";

        setController(item, "gross_weight", item["gross_weight"]);
        setController(item, "net_weight", item["net_weight"]);
        setController(item, "other_weight", item["other_weight"]);
        setController(item, "purity", item["purity"]);
        setController(item, "waste", item["waste"]);
        setController(item, "metal_rate", item["metal_rate"]);
        setController(item, "labour_rate", item["labour_rate"]);
        setController(item, "qty", item["qty"]);
        setController(item, "remarks", item["remarks"]);
        setController(item, "other_amount", item["other_amount"].toString());

        calculateItem(item);
      }

      updateFinalItems();
    });

    debugPrint("🛒 Cart Items (customer $cid): ${cartItems.length}");
  }

  void setController(Map<String, dynamic> item, String key, String value) {
    final controller = getController(item, key);
    controller.text = value;
  }

  void calculateItem(Map<String, dynamic> item) {
    double gross =
        double.tryParse(getController(item, "gross_weight").text) ?? 0;

    double other =
        double.tryParse(getController(item, "other_weight").text) ?? 0;

    double net = gross - other;

    double purity = double.tryParse(getController(item, "purity").text) ?? 0;

    double waste = double.tryParse(getController(item, "waste").text) ?? 0;

    double netPurity = purity + waste;

    double fineWeight = net * (netPurity / 100);

    double metalRate =
        double.tryParse(getController(item, "metal_rate").text) ?? 0;

    double labourRate =
        double.tryParse(getController(item, "labour_rate").text) ?? 0;

    double otherAmount =
        double.tryParse(getController(item, "other_amount").text) ?? 0;

    bool isManualMetal = item["manual_metal"] ?? true;

    double metalAmount = !isManualMetal ? 0 : fineWeight * metalRate;

    bool isManualLabour = item["manual_labour"] ?? true;

    double labourAmount = !isManualLabour ? 0 : net * labourRate;

    double totalAmount = metalAmount + labourAmount + otherAmount;

    item["net_weight"] = net.toStringAsFixed(3);
    item["net_purity"] = netPurity.toStringAsFixed(2);
    item["fine_weight"] = fineWeight.toStringAsFixed(3);
    item["metal_amount"] = metalAmount.toStringAsFixed(2);
    item["labour_amount"] = labourAmount.toStringAsFixed(2);
    item["total_amount"] = totalAmount.toStringAsFixed(2);

    updateController(item, "net_weight");
    updateController(item, "net_purity");
    updateController(item, "fine_weight");
    updateController(item, "metal_amount");
    updateController(item, "labour_amount");
    updateController(item, "total_amount");
  }

  void updateController(Map item, String key) {
    final uniqueKey = "${item["itemset_id"] ?? item["id"]}_$key";

    if (controllers.containsKey(uniqueKey)) {
      String newVal = item[key]?.toString() ?? "";

      if (controllers[uniqueKey]!.text != newVal) {
        controllers[uniqueKey]!.text = newVal;
      }
    }
  }

  Map<String, TextEditingController> controllers = {};

  String? get _cartCustomerId {
    final String approval = selectedApprovalUserId?.trim() ?? "";
    if (approval.isNotEmpty && approval != "null") return approval;

    final String customer = selectedUserId?.trim() ?? "";
    if (customer.isNotEmpty && customer != "null") return customer;

    return null;
  }

  TextEditingController getController(Map item, String key) {
    final uniqueKey = "${item["itemset_id"] ?? item["id"]}_$key";

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
      "other_weight",
      "purity",
      "waste",
      "labour_rate",
      "metal_rate",
      "qty",
      "remarks",
    ].contains(key);
  }

  Future<void> getreturnDetails(
      dynamic id,
      Map<String, dynamic> mainItem,
      ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final response = await ApiHelper().getRequest(ApiConstants.other_charge);

    Navigator.pop(context);

    if (response != null && response.statusCode == 200) {
      final data = response.data;

      showOtherChargesPopup(
        mainItem,
        data["data"],
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Failed to load details")));
    }
  }

  void showOtherChargesPopup(
      Map<String, dynamic> item,
      List apiList,
      ) {
    // 1. પહેલાં Apply કરેલી values
    final int? existingChargeId =
    int.tryParse(item["other_charge_id"]?.toString() ?? "");
    final double? existingOtherAmount =
    double.tryParse(item["other_amount"]?.toString() ?? "");

    final Map savedDetail =
    item["other_charge_detail"] is Map ? item["other_charge_detail"] : {};

    // 2. FORMULA MAPPING
    String amtFormula(dynamic f) {
      switch (f?.toString().toLowerCase()) {
        case "per_quantity":
        case "per_qty":
          return "per_qty";
        case "per_weight":
          return "per_weight";
        case "per_qty_weight":
          return "per_qty_weight";
        default:
          return "flat";
      }
    }

    String wtFormula(dynamic f) {
      final v = amtFormula(f);
      return v == "per_qty_weight" ? "flat" : v;
    }

    // 3. API → UI CHARGES
    final List<Map<String, dynamic>> charges =
    apiList.map<Map<String, dynamic>>((e) {
      final int chargeId = int.tryParse(e["id"]?.toString() ?? "") ?? 0;

      final bool isSaved = existingChargeId != null &&
          existingChargeId > 0 &&
          existingChargeId == chargeId;

      String pick(String key, dynamic fallback) =>
          (isSaved && savedDetail[key] != null ? savedDetail[key] : fallback)
              .toString();

      return {
        "id": e["id"],
        "charge": e["name"] ?? "",
        "amount": pick("amount", e["default_amount"] ?? 0),
        "qty": pick("qty", e["quantity_pcs"] ?? 1),
        "weight": pick("weight", e["default_weight"] ?? 0),
        "wt_formula": pick("wt_formula", wtFormula(e["weight_formula"])),
        "amt_formula_type":
        pick("amt_formula_type", amtFormula(e["other_amt_formula"])),
        "total_weight": "0.0",
        "total_amt": "0.00",
        "is_selected": isSaved,
      };
    }).toList();

    // 4. ROW CONTROLLERS
    final Map<int, Map<String, TextEditingController>> rowControllers = {};

    for (int i = 0; i < charges.length; i++) {
      rowControllers[i] = {
        "amount": TextEditingController(text: charges[i]["amount"]),
        "qty": TextEditingController(text: charges[i]["qty"]),
        "weight": TextEditingController(text: charges[i]["weight"]),
      };
    }

    // 5. SINGLE CHARGE CALCULATION
    void calculateSingleCharge(Map<String, dynamic> c) {
      final double amt = double.tryParse(c["amount"]?.toString() ?? "0") ?? 0;
      final double qty = double.tryParse(c["qty"]?.toString() ?? "1") ?? 1;
      final double weight =
          double.tryParse(c["weight"]?.toString() ?? "0") ?? 0;

      final double totalWeight =
      c["wt_formula"] == "per_qty" ? weight * qty : weight;

      c["total_weight"] = totalWeight.toStringAsFixed(2);

      double totalAmt;
      switch (c["amt_formula_type"] ?? "flat") {
        case "per_qty":
          totalAmt = amt * qty;
          break;
        case "per_weight":
          totalAmt = amt * totalWeight;
          break;
        case "per_qty_weight":
          totalAmt = amt * qty * weight;
          break;
        default:
          totalAmt = amt;
      }

      c["total_amt"] = totalAmt.toStringAsFixed(2);
    }

    for (final c in charges) {
      calculateSingleCharge(c);
    }

    // 6. FALLBACK: amount match
    if (!charges.any((c) => c["is_selected"] == true) &&
        existingOtherAmount != null &&
        existingOtherAmount > 0) {
      for (final c in charges) {
        final double t = double.tryParse(c["total_amt"].toString()) ?? 0;
        if ((t - existingOtherAmount).abs() < 0.01) {
          c["is_selected"] = true;
          break;
        }
      }
    }

    double calcTotal() {
      double total = 0;
      for (final c in charges) {
        if (c["is_selected"] == true) {
          total += double.tryParse(c["total_amt"].toString()) ?? 0;
        }
      }
      return total;
    }

    final ValueNotifier<double> totalNotifier = ValueNotifier(calcTotal());

    final int initialIndex =
    charges.indexWhere((c) => c["is_selected"] == true);
    final ValueNotifier<int?> selectedIndexNotifier =
    ValueNotifier(initialIndex == -1 ? null : initialIndex);

    // 7. APPLY
    void applyCharges() {
      Map<String, dynamic>? selected;
      for (final c in charges) {
        if (c["is_selected"] == true) {
          selected = c;
          break;
        }
      }

      final Map<String, dynamic> values = {
        "other_charge_id": selected == null
            ? 0
            : (int.tryParse(selected["id"].toString()) ?? 0),
        "other_charge_detail": selected == null
            ? null
            : {
          "amount": selected["amount"],
          "qty": selected["qty"],
          "weight": selected["weight"],
          "wt_formula": selected["wt_formula"],
          "amt_formula_type": selected["amt_formula_type"],
        },
        "other_amount": totalNotifier.value.toStringAsFixed(2),
      };

      item.addAll(values);

      final String? key = (item["itemset_id"] ?? item["id"])?.toString();
      if (key != null) {
        for (final c in cartItems) {
          if ((c["itemset_id"] ?? c["id"])?.toString() == key) {
            (c as Map).addAll(values);
            break;
          }
        }
      }

      updateController(item, "other_amount");
      calculateItem(item);
      updateFinalItems();
    }

    // SMALL UI HELPERS
    Widget headerCell(String title, double width, {bool left = false}) {
      return SizedBox(
        width: width,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: left ? 8 : 0),
          child: Text(
            title,
            textAlign: left ? TextAlign.left : TextAlign.center,
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    Widget numberField(
        TextEditingController controller, VoidCallback onChanged) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          onChanged: (_) => onChanged(),
          decoration: _premiumChargeInputDecoration(),
        ),
      );
    }

    Widget formulaDropdown({
      required String value,
      required List<DropdownMenuItem<String>> items,
      required ValueChanged<String> onChanged,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: DropdownButtonFormField<String>(
          value: items.any((e) => e.value == value) ? value : "flat",
          isExpanded: true,
          dropdownColor: Colors.white,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.primaryDark,
            size: 17,
          ),
          style: const TextStyle(
            fontSize: 10.5,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
          decoration: _premiumChargeInputDecoration(),
          items: items,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      );
    }

    // DIALOG
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.50),
      builder: (dialogContext) {
        final size = MediaQuery.of(dialogContext).size;
        final bool isTablet = size.width >= 600;

        return Dialog(
          elevation: 0,
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: isTablet ? 30 : 10,
            vertical: 18,
          ),
          child: Container(
            width: isTablet ? 1050 : double.infinity,
            constraints: BoxConstraints(maxHeight: size.height * 0.88),
            decoration: BoxDecoration(
              color: const Color(0xffF5F8FC),
              borderRadius: BorderRadius.circular(14),
              border:
              Border.all(color: AppColors.gradientBlue.withOpacity(0.20)),
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
                  // HEADER
                  Container(
                    width: double.infinity,
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
                            border: Border.all(
                              color: Colors.white.withOpacity(0.18),
                            ),
                          ),
                          child: const Icon(
                            Icons.receipt_long_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Other Charges",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "Manage item charges and calculation",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "${charges.length} Charges",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(dialogContext),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // BODY
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color:
                                  AppColors.gradientBlue.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.tune_rounded,
                                  size: 15,
                                  color: AppColors.gradientBlue,
                                ),
                              ),
                              const SizedBox(width: 7),
                              const Text(
                                "Charge Details",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              const Spacer(),
                              ValueListenableBuilder<int?>(
                                valueListenable: selectedIndexNotifier,
                                builder: (context, selectedIndex, _) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.gradientBlue
                                          .withOpacity(0.07),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      "${selectedIndex != null ? 1 : 0} Selected",
                                      style: const TextStyle(
                                        color: AppColors.primaryDark,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          /// TABLE
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Container(
                              width: 700,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding:
                                    const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      color: AppColors.gradientBlue
                                          .withOpacity(0.08),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(7),
                                        topRight: Radius.circular(7),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        headerCell("Charge", 130, left: true),
                                        headerCell("Amount", 90),
                                        headerCell("Qty", 80),
                                        headerCell("Wt Formula", 120),
                                        headerCell("Amt Formula", 130),
                                        headerCell("Total Amt", 90),
                                        const SizedBox(
                                          width: 45,
                                          child: Center(
                                            child: Icon(
                                              Icons
                                                  .check_circle_outline_rounded,
                                              color: AppColors.primaryDark,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  Divider(height: 1, color: AppColors.border),

                                  SizedBox(
                                    height: 230,
                                    child: ListView.separated(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 5),
                                      itemCount: charges.length,
                                      separatorBuilder: (_, __) => Divider(
                                        height: 1,
                                        color: AppColors.border,
                                      ),
                                      itemBuilder: (context, index) {
                                        final c = charges[index];

                                        return StatefulBuilder(
                                          builder: (context, setStateRow) {
                                            void onFieldChanged() {
                                              c["amount"] =
                                                  rowControllers[index]![
                                                  "amount"]!
                                                      .text;
                                              c["qty"] = rowControllers[index]![
                                              "qty"]!
                                                  .text;
                                              c["weight"] =
                                                  rowControllers[index]![
                                                  "weight"]!
                                                      .text;

                                              calculateSingleCharge(c);
                                              setStateRow(() {});
                                              totalNotifier.value = calcTotal();
                                            }

                                            return ValueListenableBuilder<int?>(
                                              valueListenable:
                                              selectedIndexNotifier,
                                              builder:
                                                  (context, selectedIndex, _) {
                                                final bool selected =
                                                    selectedIndex == index;

                                                return Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 6),
                                                  color: selected
                                                      ? AppColors.gradientBlue
                                                      .withOpacity(0.025)
                                                      : Colors.white,
                                                  child: Row(
                                                    children: [
                                                      SizedBox(
                                                        width: 130,
                                                        child: Padding(
                                                          padding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                            horizontal: 8,
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              Container(
                                                                width: 24,
                                                                height: 24,
                                                                alignment:
                                                                Alignment
                                                                    .center,
                                                                decoration:
                                                                BoxDecoration(
                                                                  color: AppColors
                                                                      .gradientBlue
                                                                      .withOpacity(
                                                                    selected
                                                                        ? 0.12
                                                                        : 0.06,
                                                                  ),
                                                                  borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                      5),
                                                                ),
                                                                child: Text(
                                                                  "${index + 1}",
                                                                  style:
                                                                  const TextStyle(
                                                                    color: AppColors
                                                                        .primaryDark,
                                                                    fontSize: 9,
                                                                    fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  width: 5),
                                                              Expanded(
                                                                child: Text(
                                                                  c["charge"]
                                                                      ?.toString() ??
                                                                      "",
                                                                  maxLines: 1,
                                                                  overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                                  style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                    11,
                                                                    fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                    color: Colors
                                                                        .black87,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width: 90,
                                                        child: numberField(
                                                          rowControllers[
                                                          index]!["amount"]!,
                                                          onFieldChanged,
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width: 80,
                                                        child: numberField(
                                                          rowControllers[
                                                          index]!["qty"]!,
                                                          onFieldChanged,
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width: 120,
                                                        child: formulaDropdown(
                                                          value:
                                                          c["wt_formula"],
                                                          items: const [
                                                            DropdownMenuItem(
                                                              value: "flat",
                                                              child:
                                                              Text("Flat"),
                                                            ),
                                                            DropdownMenuItem(
                                                              value: "per_qty",
                                                              child: Text(
                                                                  "Per Qty"),
                                                            ),
                                                            DropdownMenuItem(
                                                              value:
                                                              "per_weight",
                                                              child: Text(
                                                                  "Per Wt"),
                                                            ),
                                                          ],
                                                          onChanged: (v) {
                                                            c["wt_formula"] = v;
                                                            onFieldChanged();
                                                          },
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width: 130,
                                                        child: formulaDropdown(
                                                          value: c[
                                                          "amt_formula_type"],
                                                          items: const [
                                                            DropdownMenuItem(
                                                              value: "flat",
                                                              child:
                                                              Text("Flat"),
                                                            ),
                                                            DropdownMenuItem(
                                                              value: "per_qty",
                                                              child: Text(
                                                                  "Per Qty"),
                                                            ),
                                                            DropdownMenuItem(
                                                              value:
                                                              "per_weight",
                                                              child: Text(
                                                                  "Per Wt"),
                                                            ),
                                                            DropdownMenuItem(
                                                              value:
                                                              "per_qty_weight",
                                                              child: Text(
                                                                  "Qty × Wt"),
                                                            ),
                                                          ],
                                                          onChanged: (v) {
                                                            c["amt_formula_type"] =
                                                                v;
                                                            onFieldChanged();
                                                          },
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width: 90,
                                                        child: Center(
                                                          child: Container(
                                                            padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                              horizontal: 8,
                                                              vertical: 6,
                                                            ),
                                                            decoration:
                                                            BoxDecoration(
                                                              color: const Color(
                                                                  0xffEAF4FF),
                                                              borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                  5),
                                                              border:
                                                              Border.all(
                                                                color: AppColors
                                                                    .gradientBlue
                                                                    .withOpacity(
                                                                    0.10),
                                                              ),
                                                            ),
                                                            child: Text(
                                                              c["total_amt"] ??
                                                                  "0",
                                                              style:
                                                              const TextStyle(
                                                                fontSize: 11,
                                                                fontWeight:
                                                                FontWeight
                                                                    .w700,
                                                                color: AppColors
                                                                    .primaryDark,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width: 45,
                                                        child: Transform.scale(
                                                          scale: 0.90,
                                                          child: Checkbox(
                                                            value: selected,
                                                            activeColor:
                                                            AppColors
                                                                .gradientBlue,
                                                            shape:
                                                            RoundedRectangleBorder(
                                                              borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                  4),
                                                            ),
                                                            onChanged: (val) {
                                                              final prev =
                                                                  selectedIndexNotifier
                                                                      .value;
                                                              if (prev !=
                                                                  null) {
                                                                charges[prev][
                                                                "is_selected"] =
                                                                false;
                                                              }

                                                              if (val == true) {
                                                                c["is_selected"] =
                                                                true;
                                                                selectedIndexNotifier
                                                                    .value =
                                                                    index;
                                                              } else {
                                                                c["is_selected"] =
                                                                false;
                                                                selectedIndexNotifier
                                                                    .value =
                                                                null;
                                                              }

                                                              totalNotifier
                                                                  .value =
                                                                  calcTotal();
                                                            },
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

                          /// TOTAL SUMMARY
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.gradientBlue.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                AppColors.gradientBlue.withOpacity(0.12),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.gradientBlue
                                        .withOpacity(0.10),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.calculate_outlined,
                                    size: 17,
                                    color: AppColors.gradientBlue,
                                  ),
                                ),
                                const SizedBox(width: 9),
                                const Expanded(
                                  child: Text(
                                    "Selected Charges Total",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                ValueListenableBuilder<double>(
                                  valueListenable: totalNotifier,
                                  builder: (context, total, _) {
                                    return Text(
                                      total.toStringAsFixed(2),
                                      style: const TextStyle(
                                        fontSize: 17,
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

                  // BOTTOM BAR
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: OutlinedButton(
                              onPressed: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                Navigator.pop(dialogContext);
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(7),
                                ),
                              ),
                              child: const Text(
                                "Cancel",
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 42,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(7),
                                onTap: () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  applyCharges();
                                  Navigator.pop(dialogContext);
                                  if (mounted) setState(() {});
                                },
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppColors.primaryDark,
                                        AppColors.gradientBlue,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(7),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.gradientBlue
                                            .withOpacity(0.20),
                                        blurRadius: 7,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline_rounded,
                                        color: Colors.white,
                                        size: 17,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        "Apply Charges",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12.5,
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
        );
      },
    ).then((_) {
      Future.delayed(const Duration(milliseconds: 400), () {
        for (final ctrls in rowControllers.values) {
          for (final c in ctrls.values) {
            c.dispose();
          }
        }
        totalNotifier.dispose();
        selectedIndexNotifier.dispose();
      });
    });
  }

  void printFinalData() {
    List<Map<String, dynamic>> finalData = items.map((item) {
      return {
        "itemset_id": item["id"],
        "gross_weight": getController(item, "gross_weight").text,
        "other_weight": getController(item, "other_weight").text,
        "net_weight": getController(item, "net_weight").text,
        "metal_rate": getController(item, "metal_rate").text,
        "labour_rate": getController(item, "labour_rate").text,
        "other_amount": getController(item, "other_amount").text,
        "metal_amount": item["metal_amount"],
        "labour_amount": item["labour_amount"],
        "total_amount": item["total_amount"],
      };
    }).toList();

    print("🔥 FINAL ARRAY: $finalData");
  }

  void updateFinalItems() {
    finalItems.clear();

    final Set<String> addedKeys = <String>{};

    String latest(Map<String, dynamic> item, String key, {String def = "0"}) {
      try {
        final text = getController(item, key).text.trim();
        if (text.isNotEmpty) return text;
      } catch (_) {}

      final value = item[key]?.toString().trim() ?? "";
      return (value.isEmpty || value == "null") ? def : value;
    }

    double num(Map<String, dynamic> item, String key) =>
        double.tryParse(latest(item, key)) ?? 0;

    int? toId(dynamic v) {
      final id = int.tryParse(v?.toString() ?? "");
      return (id != null && id > 0) ? id : null;
    }

    String? uniqueKey({
      int? itemId,
      int? itemsetId,
      int? approvalItemId,
      String qrCode = "",
      String huid = "",
    }) {
      if (itemsetId != null) return "ITEMSET_$itemsetId";
      if (approvalItemId != null) return "APPROVAL_$approvalItemId";
      if (qrCode.isNotEmpty) return "QR_${qrCode.toLowerCase()}";
      if (huid.isNotEmpty) return "HUID_${huid.toLowerCase()}";
      if (itemId != null) return "ITEM_$itemId";
      return null;
    }

    void addFinal(Map<String, dynamic> item, String source) {
      final int? itemId = toId(item["item_id"] ?? item["selected_item_id"]);
      final int? itemsetId = toId(item["itemset_id"] ?? item["item_set_id"]);
      final int? approvalItemId = toId(item["approval_item_id"]);

      final String qrCode =
      (item["qr_code"] ?? item["code"] ?? "").toString().trim();
      final String huid =
      (item["huid"] ?? item["HUID"] ?? "").toString().trim();

      if (itemId == null &&
          itemsetId == null &&
          approvalItemId == null &&
          qrCode.isEmpty &&
          huid.isEmpty) {
        debugPrint("⚠️ [$source] SKIPPED => કોઈ id / QR / HUID નથી");
        return;
      }

      final String? key = uniqueKey(
        itemId: itemId,
        itemsetId: itemsetId,
        approvalItemId: approvalItemId,
        qrCode: qrCode,
        huid: huid,
      );

      if (key != null) {
        if (addedKeys.contains(key)) {
          debugPrint("🚫 [$source] DUPLICATE SKIPPED => $key");
          return;
        }
        addedKeys.add(key);
      }

      final double otherWeight = num(item, "other_weight");
      final double waste = num(item, "waste");
      final double labourAmount = num(item, "labour_amount");

      final String itemName =
      (item["item_name"]?.toString().trim().isNotEmpty == true)
          ? item["item_name"].toString()
          : (item["name"] ?? item["itemset"]?["item"]?["item_name"] ?? "")
          .toString();

      final String metal = (item["metal"] ??
          item["itemset"]?["item"]?["metal"] ??
          item["itemset"]?["metal"] ??
          "")
          .toString();

      final Map<String, dynamic> finalItem = {
        if (itemId != null) "item_id": itemId,
        if (itemsetId != null) "itemset_id": itemsetId,
        if (approvalItemId != null) "approval_item_id": approvalItemId,
        if (qrCode.isNotEmpty) "qr_code": qrCode,
        if (huid.isNotEmpty) "huid": huid,
        "item_name": itemName,
        "metal": metal,
        "gross_weight": num(item, "gross_weight"),
        "other": otherWeight,
        "other_weight": otherWeight,
        "net_weight": num(item, "net_weight"),
        "purity": num(item, "purity"),
        if (isEditMode) "waste": waste else "waste_percent": waste,
        "outward_carat": num(item, "outward_carat"),
        "net_purity": num(item, "net_purity"),
        "fine_weight": num(item, "fine_weight"),
        "metal_rate": num(item, "metal_rate"),
        "metal_amount": num(item, "metal_amount"),
        "labour_rate": num(item, "labour_rate"),
        "labour_amount": labourAmount,
        "sale_labour_amount":
        double.tryParse(item["sale_labour_amount"]?.toString() ?? "") ??
            labourAmount,
        "other_amount": num(item, "other_amount"),
        "total_amount": num(item, "total_amount"),
        "qty": int.tryParse(latest(item, "qty", def: "1")) ?? 1,
        "remarks": latest(item, "remarks", def: ""),
      };

      finalItems.add(finalItem);
      debugPrint("✅ [$source] ${finalItems.length} => $finalItem");
    }

    for (final e in items) {
      addFinal(Map<String, dynamic>.from(e), "MANUAL");
    }

    for (final e in approvalAddedItems) {
      addFinal(Map<String, dynamic>.from(e), "APPROVAL");
    }

    for (final e in cartItems) {
      addFinal(Map<String, dynamic>.from(e), "CART");
    }

    debugPrint(
      "🔥 FINAL ITEMS => ${finalItems.length} "
          "(manual ${items.length}, approval ${approvalAddedItems.length}, cart ${cartItems.length})",
    );
  }

  double getValue(Map item, String key) {
    final uniqueKey = "${item["id"] ?? item["itemset_id"]}_$key";

    if (controllers.containsKey(uniqueKey)) {
      return double.tryParse(controllers[uniqueKey]!.text) ?? 0;
    } else {
      return double.tryParse(item[key]?.toString() ?? "0") ?? 0;
    }
  }

  Widget buildSummaryRow() {
    final totals = calculateTotals();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isEditMode || uniqueItems.isNotEmpty) {
        final received = double.tryParse(recived_amount_Controller.text) ?? 0;
        final pending = totals["total"]! - received;
        final pendingStr = pending.toStringAsFixed(2);

        if (payment_pending_Controller.text != pendingStr) {
          payment_pending_Controller.text = pendingStr;
        }
      }
    });

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border, width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _summaryBox("Items", "${uniqueItems.length}"),
            _summaryBox("Gross", totals["gross"]!.toStringAsFixed(3)),
            _summaryBox("Other", totals["other"]!.toStringAsFixed(3)),
            _summaryBox("Net", totals["net"]!.toStringAsFixed(3)),
            _summaryBox("Fine", totals["fine"]!.toStringAsFixed(3)),
            _summaryBox("Metal Rate", totals["metalRate"]!.toStringAsFixed(2)),
            _summaryBox("Metal Amt", totals["metal"]!.toStringAsFixed(2)),
            _summaryBox(
                "Labour Rate", totals["labourRate"]!.toStringAsFixed(2)),
            _summaryBox("Labour Amt", totals["labour"]!.toStringAsFixed(2)),
            _summaryBox("Other Amt", totals["otherAmt"]!.toStringAsFixed(2)),
            _summaryBox("Total", totals["total"]!.toStringAsFixed(2)),
          ],
        ),
      ),
    );
  }

  Map<String, double> calculateTotals() {
    double gross = 0;
    double other = 0;
    double net = 0;
    double purity = 0;
    double waste = 0;
    double netPurity = 0;
    double fine = 0;
    double metalRate = 0;
    double metal = 0;
    double labourRate = 0;
    double labour = 0;
    double otherAmt = 0;
    double total = 0;

    for (var item in uniqueItems) {
      gross += double.tryParse(item["gross_weight"]?.toString() ?? "0") ?? 0;
      other += double.tryParse(item["other_weight"]?.toString() ?? "0") ?? 0;
      net += double.tryParse(item["net_weight"]?.toString() ?? "0") ?? 0;
      purity += double.tryParse(item["purity"]?.toString() ?? "0") ?? 0;
      waste += double.tryParse(item["waste"]?.toString() ?? "0") ?? 0;
      netPurity +=
          double.tryParse(item["net_purity"]?.toString() ?? "0") ?? 0;
      fine += double.tryParse(item["fine_weight"]?.toString() ?? "0") ?? 0;
      metalRate +=
          double.tryParse(item["metal_rate"]?.toString() ?? "0") ?? 0;
      metal += double.tryParse(item["metal_amount"]?.toString() ?? "0") ?? 0;
      labourRate +=
          double.tryParse(item["labour_rate"]?.toString() ?? "0") ?? 0;
      labour +=
          double.tryParse(item["labour_amount"]?.toString() ?? "0") ?? 0;
      otherAmt +=
          double.tryParse(item["other_amount"]?.toString() ?? "0") ?? 0;
      total += double.tryParse(item["total_amount"]?.toString() ?? "0") ?? 0;
    }

    return {
      "gross": gross,
      "other": other,
      "net": net,
      "purity": purity,
      "waste": waste,
      "netPurity": netPurity,
      "fine": fine,
      "metalRate": metalRate,
      "metal": metal,
      "labourRate": labourRate,
      "labour": labour,
      "otherAmt": otherAmt,
      "total": total,
    };
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

  Widget _balanceBox({required String title, required String amount}) {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 10, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: const Color(0xff2C3148),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _premiumFieldWrapper({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 1, bottom: 5),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
        ),
        child,
      ],
    );
  }

  InputDecoration _premiumInputDecoration({
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool readOnly = false,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Colors.black38,
        fontSize: 13,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: readOnly ? const Color(0xffF5F5F5) : Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
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
        borderSide: const BorderSide(color: AppColors.gradientBlue, width: 1.2),
      ),
    );
  }

  Widget _premiumReadOnlyBox({
    required String title,
    required String value,
    String? type,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 1, bottom: 5),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                  ),
                ),
              ),
              if (type != null) ...[
                const SizedBox(width: 4),
                Text(
                  type,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: type == "Credit"
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
              ],
            ],
          ),
        ),
        Container(
          width: double.infinity,
          height: 43,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: const Color(0xffF7F7F8),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  String _getSilverUsedFineWt(ItemProvider provider) {
    return provider.silverUsedFineWeight.toStringAsFixed(3);
  }

  String _getSilverBalanceAfterUse(ItemProvider provider) {
    return provider.silverBalanceAfterUse.toStringAsFixed(3);
  }

  Widget _searchResultDropdown() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: isLoading
          ? const SizedBox(
        height: 60,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      )
          : searchResults.isEmpty
          ? const SizedBox(
        height: 55,
        child: Center(
          child: Text(
            "No items found",
            style: TextStyle(color: Colors.black45, fontSize: 12),
          ),
        ),
      )
          : ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: searchResults.length,
        separatorBuilder: (_, __) {
          return Divider(height: 1, color: Colors.grey.shade200);
        },
        itemBuilder: (context, index) {
          final item = searchResults[index];

          final itemName = item["item"]?["item_name"] ?? "Item";
          final huid = item["HUID"] ?? "-";
          final qr = item["qr_code"] ?? "-";

          return InkWell(
            onTap: () async {
              FocusManager.instance.primaryFocus?.unfocus();

              final String? qrCode = item["qr_code"]?.toString();

              if (qrCode == null || qrCode.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("This item has no QR code"),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              /// 🔥 Search API માં item["id"] = itemset id
              _rememberScanInfo(qrCode, itemsetId: item["id"]);

              await scanApiCall(qrCode);

              if (!mounted) return;

              setState(() {
                searchResults.removeWhere(
                      (e) => e["id"]?.toString() == item["id"]?.toString(),
                );
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      size: 17,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          itemName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "HUID: $huid  •  QR: $qr",
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.add_circle_outline_rounded,
                    size: 20,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    recived_amount_Controller.dispose();
    payment_ref_Controller.dispose();
    payment_pending_Controller.dispose();
    remarksController.dispose();
    add_payment_Controller.dispose();
    searchFocusNode.dispose();
    _scannerController.dispose();
    _listFilterController.dispose();
    for (var c in controllers.values) {
      c.dispose();
    }
    _huidTimer?.cancel();
    super.dispose();
  }

  Widget _labourDropdown(Map<String, dynamic> item) {
    final provider = Provider.of<ItemProvider>(context, listen: false);

    final String selectedValue =
    (item["item"] ?? item["item_name"] ?? "").toString();

    Map<String, dynamic>? selectedItemData;

    if (selectedValue.isNotEmpty) {
      for (final rawData in provider.items) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(rawData);

        if ((data["item_name"] ?? "").toString().trim().toLowerCase() ==
            selectedValue.trim().toLowerCase()) {
          selectedItemData = data;
          break;
        }
      }
    }

    final List<Map<String, dynamic>> allItems = provider.items
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();

    return _miniDropdownBox(
      title: "Item Name",
      width: 155,
      text: selectedItemData?["item_name"]?.toString() ?? selectedValue,
      hint: "Select Item",
      onTap: () async {
        final Map<String, dynamic>? selectedItem = await _openSearchSheet(
          title: "Item",
          icon: Icons.category_outlined,
          items: allItems,
          selectedId: selectedItemData?["id"]?.toString(),
          labelOf: (data) => data["item_name"]?.toString() ?? "-",
          subtitleOf: (data) {
            final code = data["item_code"]?.toString() ?? "";
            return (code.isEmpty || code == "null") ? "" : "Code: $code";
          },
          searchOf: (data) => [
            data["item_name"]?.toString() ?? "",
            data["item_code"]?.toString() ?? "",
            data["metal"]?.toString() ?? "",
            data["id"]?.toString() ?? "",
          ].join(" "),
        );

        if (selectedItem == null || !mounted) return;

        final String itemName = selectedItem["item_name"]?.toString() ?? "";
        final String outwardCarat =
            selectedItem["outward_carat"]?.toString() ?? "0";
        final String outwardPurity =
            selectedItem["outward_purity"]?.toString() ?? "0";
        final String labourRate =
            selectedItem["labour_rate"]?.toString() ?? "0";

        setState(() {
          item["item_id"] = selectedItem["id"];
          item["item"] = itemName;
          item["item_name"] = itemName;
          item["company_id"] = selectedItem["company_id"];
          item["item_code"] = selectedItem["item_code"];
          item["metal"] = selectedItem["metal"];

          item["outward_carat"] = selectedItem["outward_carat"];
          item["inward_carat"] = selectedItem["inward_carat"];
          item["outward_purity"] = selectedItem["outward_purity"];
          item["inward_purity"] = selectedItem["inward_purity"];

          item["metal_formula"] = selectedItem["metal_formula"];
          item["issue_type"] = selectedItem["issue_type"];
          item["jobwork_item_type"] = selectedItem["jobwork_item_type"];

          item["labour_type"] = selectedItem["labour_type"];
          item["labour_rate"] = selectedItem["labour_rate"] ?? "0";
          item["labour_unit"] = selectedItem["labour_unit"];

          item["tax_type"] = selectedItem["tax_type"];
          item["hsn"] = selectedItem["hsn"];
          item["sac_code"] = selectedItem["sac_code"];
          item["export_hsn"] = selectedItem["export_hsn"];

          item["auto_load_purity"] = selectedItem["auto_load_purity"];
          item["auto_create_label_purchase"] =
          selectedItem["auto_create_label_purchase"];
          item["auto_create_label_config"] =
          selectedItem["auto_create_label_config"];
          item["reuse"] = selectedItem["reuse"];
          item["numeric_length"] = selectedItem["numeric_length"];
          item["item_group"] = selectedItem["item_group"];
          item["remarks"] = selectedItem["remarks"];

          item["selected_item_data"] = Map<String, dynamic>.from(selectedItem);

          item["purity"] = outwardCarat;
          item["net_purity"] = outwardPurity;

          getController(item, "outward_carat").text = outwardCarat;
          getController(item, "purity").text = outwardCarat;
          getController(item, "net_purity").text = outwardPurity;
          getController(item, "labour_rate").text = labourRate;

          calculateItem(item);
          updateFinalItems();
        });

        debugPrint("SELECTED MASTER ITEM => $selectedItem");
      },
    );
  }

  Map<String, dynamic> createApprovalBlankItemRow() {
    final String tempId = "fresh_${DateTime.now().microsecondsSinceEpoch}";

    final Map<String, dynamic> newItem = {
      "id": tempId,
      "itemset_id": null,
      "approval_item_id": null,
      "item": "",
      "item_name": "",
      "item_id": null,
      "show_item_dropdown": true,
      "is_fresh": true,
      "gross_weight": "0",
      "other_weight": "0",
      "net_weight": "0",
      "purity": "0",
      "waste": "0",
      "outward_carat": "0",
      "net_purity": "0",
      "fine_weight": "0",
      "metal_rate": "0",
      "metal_amount": "0",
      "labour_rate": "0",
      "labour_amount": "0",
      "qty": "1",
      "remarks": "",
      "other_amount": "0",
      "total_amount": "0",
      "expanded": false,
    };

    setController(newItem, "gross_weight", "0");
    setController(newItem, "other_weight", "0");
    setController(newItem, "net_weight", "0");
    setController(newItem, "purity", "0");
    setController(newItem, "waste", "0");
    setController(newItem, "outward_carat", "0");
    setController(newItem, "net_purity", "0");
    setController(newItem, "fine_weight", "0");
    setController(newItem, "metal_rate", "0");
    setController(newItem, "metal_amount", "0");
    setController(newItem, "labour_rate", "0");
    setController(newItem, "labour_amount", "0");
    setController(newItem, "qty", "1");
    setController(newItem, "remarks", "");
    setController(newItem, "other_amount", "0");
    setController(newItem, "total_amount", "0");

    return newItem;
  }

  Map<String, dynamic> createBlankItemRow() {
    final String tempId = "new_${DateTime.now().microsecondsSinceEpoch}";

    final Map<String, dynamic> newItem = {
      "id": tempId,
      "itemset_id": null,
      "item": "",
      "item_name": "",
      "item_id": null,
      "show_item_dropdown": true,
      "is_fresh": true,
      "gross_weight": "0",
      "other_weight": "0",
      "net_weight": "0",
      "purity": "0",
      "waste": "0",
      "outward_carat": "0",
      "net_purity": "0",
      "fine_weight": "0",
      "metal_rate": "0",
      "metal_amount": "0",
      "labour_rate": "0",
      "labour_amount": "0",
      "qty": "1",
      "remarks": "",
      "other_amount": "0",
      "total_amount": "0",
      "expanded": false,
    };

    setController(newItem, "gross_weight", "0");
    setController(newItem, "other_weight", "0");
    setController(newItem, "net_weight", "0");
    setController(newItem, "purity", "0");
    setController(newItem, "waste", "0");
    setController(newItem, "outward_carat", "0");
    setController(newItem, "net_purity", "0");
    setController(newItem, "fine_weight", "0");
    setController(newItem, "metal_rate", "0");
    setController(newItem, "metal_amount", "0");
    setController(newItem, "labour_rate", "0");
    setController(newItem, "labour_amount", "0");
    setController(newItem, "qty", "1");
    setController(newItem, "remarks", "");
    setController(newItem, "other_amount", "0");
    setController(newItem, "total_amount", "0");

    return newItem;
  }

  // ============================================================
  // 🔥 APPLY "ALL" — ફક્ત search થયેલી (દેખાતી) items પર
  // ============================================================
  Future<void> applyRateToAllItems({
    required Map<String, dynamic> sourceItem,
    required String key,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final sourceController = getController(sourceItem, key);
    final String value = sourceController.text.trim().isEmpty
        ? "0"
        : sourceController.text.trim();

    /// ફક્ત હાલ દેખાતી items
    final Set<String> visibleKeys = _visibleItems.map(_rowKey).toSet();

    int updatedCount = 0;

    void applyTo(dynamic item) {
      if (!visibleKeys.contains(_rowKey(item))) return;

      getController(item, key).text = value;
      item[key] = value;

      if (key == "metal_rate") item["manual_metal"] = true;
      if (key == "labour_rate") item["manual_labour"] = true;

      calculateItem(item);
      updatedCount++;
    }

    for (final item in items) {
      applyTo(item);
    }

    for (final item in approvalAddedItems) {
      applyTo(item);
    }

    for (final cartItem in cartItems) {
      applyTo(cartItem);
    }

    updateFinalItems();

    if (!mounted) return;

    setState(() {});

    final bool filtered = _listFilter.trim().isNotEmpty;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  filtered
                      ? "Applied to $updatedCount searched items"
                      : "Applied to all $updatedCount items",
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.all(12),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
  }

  InputDecoration _premiumChargeInputDecoration() {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
      filled: true,
      fillColor: Colors.white,
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
        borderSide: const BorderSide(color: AppColors.gradientBlue, width: 1.3),
      ),
    );
  }

  Widget _premiumChargeField({
    required dynamic initialValue,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: TextFormField(
        initialValue: initialValue?.toString() ?? "",
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        onChanged: onChanged,
        decoration: _premiumChargeInputDecoration(),
      ),
    );
  }

  Widget _buildBalanceBoxes(ItemProvider provider, bool isMobile) {
    final bool useEdit = _useEditBalance;
    final String metalName =
    useEdit ? "Silver" : provider.activeMetalDisplayName;

    double opening;
    if (useEdit) {
      opening = editSilverOpening;
    } else {
      final double b = provider.activeMetalBalance.abs();
      opening = provider.activeMetalBalanceType == "Debit" ? -b : b;
    }

    final double totalFine = calculateTotals()["fine"] ?? 0;
    final double used = useSilverBalance ? totalFine : 0;
    final double after = opening - used;

    final Widget cashBox = _premiumReadOnlyBox(
      title: "Advance Cash Balance",
      type: useEdit ? "Credit" : provider.cashType,
      value:
      (useEdit ? editCashBalance : provider.cashBalance).toStringAsFixed(2),
    );

    final Widget balanceBox = _premiumReadOnlyBox(
      title: useEdit ? "Silver Fine Balance" : provider.activeMetalLabel,
      type: opening >= 0 ? "Credit" : "Debit",
      value: opening.abs().toStringAsFixed(3),
    );

    final Widget usedBox = _premiumReadOnlyBox(
      title: "$metalName Used (Fine Wt)",
      value: useSilverBalance
          ? used.toStringAsFixed(3)
          : "$metalName Used Not Adjusted",
    );

    final Widget afterBox = _premiumReadOnlyBox(
      title: "$metalName Balance After Use",
      type: after >= 0 ? "Credit" : "Debit",
      value: after.abs().toStringAsFixed(3),
    );

    if (!isMobile) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: cashBox),
          const SizedBox(width: 14),
          Expanded(child: balanceBox),
          const SizedBox(width: 14),
          Expanded(child: usedBox),
          const SizedBox(width: 14),
          Expanded(child: afterBox),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: cashBox),
            const SizedBox(width: 8),
            Expanded(child: balanceBox),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: usedBox),
            const SizedBox(width: 8),
            Expanded(child: afterBox),
          ],
        ),
      ],
    );
  }

  Widget _adjustFineBalanceTile() {
    return InkWell(
      onTap: () => setState(() => useSilverBalance = !useSilverBalance),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: useSilverBalance
              ? AppColors.gradientBlue.withOpacity(0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: useSilverBalance ? AppColors.gradientBlue : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: useSilverBalance,
                activeColor: AppColors.gradientBlue,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (v) =>
                    setState(() => useSilverBalance = v ?? false),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Payment adjustment",
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Use available cash and metal credit. Unpriced metal remains payable in grams.",
                    style: TextStyle(fontSize: 10.5, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _generateDeviceEntryId() {
    final String base = deviceId ?? 'unknown-device';
    return "$base-${DateTime.now().microsecondsSinceEpoch}";
  }

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
      height: 55,
      margin: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 15,
            child: Text(
              title,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 36,
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
                    border: Border.all(color: AppColors.border),
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
                    const SizedBox(height: 10),
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: searchCtrl,
                        onChanged: (v) => setSheet(() => query = v),
                        style: const TextStyle(
                            fontSize: 13.5, color: Colors.black),
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
                                              AppColors.primaryDark,
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
                                                overflow:
                                                TextOverflow.ellipsis,
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

  /// ❌ વાળું dropdown — બધા dropdowns માટે એક જ
  Widget _dropdownWithClear({
    required Widget dropdown,
    required bool showClear,
    required VoidCallback onClear,
  }) {
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        dropdown,
        if (showClear)
          Positioned(
            right: 40,
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
          ),
      ],
    );
  }

  /// 🔥 Customer select / clear → Approval Person પણ sync
  void _setCustomer(
      ItemProvider provider,
      Map? customer,
      List approvalCustomers,
      ) {
    /// ❌ CLEAR
    if (customer == null) {
      _cartRequestId++;

      setState(() {
        if (selectedapprovalItem == selectedItem) {
          selectedapprovalItem = null;
          selectedApprovalCompanyId = null;
          selectedApprovalUserId = null;
        }

        selectedItem = null;
        selectedCompanyId = null;
        selectedUserId = null;
        customerChangedByUser = false;

        cartItems = [];
        updateFinalItems();

        _clearScanInfo();
      });

      return;
    }

    final String? id = customer["id"]?.toString();
    if (id == null || id.isEmpty) return;

    Map? matchApproval;
    for (final c in approvalCustomers) {
      if (c["id"]?.toString() == id) {
        matchApproval = c;
        break;
      }
    }

    setState(() {
      selectedItem = id;
      selectedCompanyId = customer["company_id"]?.toString();
      selectedUserId = id;

      customerChangedByUser = true;
      provider.setCustomerAdvance(Map<String, dynamic>.from(customer));

      cartItems = [];
      updateFinalItems();

      if (matchApproval != null) {
        selectedapprovalItem = id;
        selectedApprovalCompanyId = matchApproval["company_id"]?.toString();
        selectedApprovalUserId = id;
      } else {
        selectedapprovalItem = null;
        selectedApprovalCompanyId = null;
        selectedApprovalUserId = null;
      }
      _approvalManuallyCleared = false;

      _clearScanInfo();
    });

    debugPrint("Selected Customer => ${customer["name"]} ($id)");
    debugPrint("Auto Approval Person => ${matchApproval?["name"] ?? "-"}");

    getCartItems(customerId: id);
  }

  /// Approval Person select / clear (user જાતે)
  void _setApprovalPerson(Map? person) {
    setState(() {
      selectedapprovalItem = person?["id"]?.toString();
      selectedApprovalCompanyId = person?["company_id"]?.toString();
      selectedApprovalUserId = person?["id"]?.toString();
      _approvalManuallyCleared = person == null;

      _clearScanInfo();
    });

    debugPrint("Selected Approval Person => ${person?["name"] ?? "-"}");
  }

  /// =========================================================
  /// ✅ SHOW PREVIOUS BILLS — invoice PDF ma juna pending bills
  /// (fakt print mate — customer na outstanding balance par asar nahi)
  /// =========================================================
  Widget _previousBillsTile() {
    return InkWell(
      onTap: () => setState(() => showPreviousBills = !showPreviousBills),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: showPreviousBills
              ? AppColors.gradientBlue.withOpacity(0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color:
            showPreviousBills ? AppColors.gradientBlue : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: showPreviousBills,
                activeColor: AppColors.gradientBlue,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (v) =>
                    setState(() => showPreviousBills = v ?? false),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Include previous pending bills in invoice PDF",
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Leave unchecked to print only this bill. This does not "
                        "change the customer's outstanding balance.",
                    style: TextStyle(fontSize: 10.5, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _paymentModeItems() {
    const modes = ["Cash", "Online", "UPI", "Bank", "Other"];
    return modes
        .map((m) => DropdownMenuItem(
      value: m,
      child: Text(m, style: _blackFieldStyle),
    ))
        .toList();
  }
}

class _ScannerLineAnimation extends StatefulWidget {
  const _ScannerLineAnimation({super.key});

  @override
  State<_ScannerLineAnimation> createState() => _ScannerLineAnimationState();
}

class _ScannerLineAnimationState extends State<_ScannerLineAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<double> animation;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    animation = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Align(
          alignment: Alignment(0, animation.value * 2 - 1),
          child: Container(
            width: double.infinity,
            height: 3,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.greenAccent,
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.greenAccent.withOpacity(0.6),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

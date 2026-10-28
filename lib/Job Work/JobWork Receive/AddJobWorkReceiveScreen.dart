// import 'dart:io';
//
// import 'package:dio/dio.dart';
// import 'package:dropdown_search/dropdown_search.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:open_file/open_file.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// import '../../Api_Constant/ApiConstants.dart';
// import '../../Api_Constant/api_helper.dart';
// import '../../Extra/AppColors.dart';
// import '../../Extra/AppMessage.dart';
// import '../../Extra/PermissionDeniedWidget.dart';
// import '../../Offline Data/OfflineValueSave.dart';
// import '../../Offline Data/offline_api_helper.dart';
//
// class Addjobworkreceivescreen extends StatefulWidget {
//   final Map<String, dynamic> voucher;
//   final List<Map<String, dynamic>> items;
//
//   const Addjobworkreceivescreen({
//     super.key,
//     required this.voucher,
//     required this.items,
//   });
//
//   @override
//   State<Addjobworkreceivescreen> createState() =>
//       _AddjobworkreceivescreenState();
// }
//
// class _AddjobworkreceivescreenState extends State<Addjobworkreceivescreen> {
//   /// ============================================================
//   /// DATA
//   /// ============================================================
//   late Map<String, dynamic> voucher;
//
//   List<Map<String, dynamic>> items = [];
//
//   /// Dropdown mate
//   List<Map<String, dynamic>> itemOptions = [];
//
//   /// Other charges mate
//   List<Map<String, dynamic>> otherCharges = [];
//
//   /// Same worker na vouchers
//   List<Map<String, dynamic>> voucherList = [];
//
//   Map<String, dynamic>? selectedVoucher;
//
//   bool isVoucherDropdownOpen = false;
//   bool isJobworkInfoExpanded = false;
//   bool isSaving = false;
//
//   /// ============================================================
//   /// CONTROLLERS
//   /// ============================================================
//   final TextEditingController voucherSearchController = TextEditingController();
//
//   final Map<String, TextEditingController> jobworkControllers = {};
//
//   /// ============================================================
//   /// PERMISSION
//   /// ============================================================
//   List<String> userPermissions = [];
//
//   final Offlinevaluesave _offlineDraft = Offlinevaluesave();
//
//   /// ============================================================
//   /// INIT
//   /// ============================================================
//   @override
//   void initState() {
//     super.initState();
//
//     voucher = Map<String, dynamic>.from(widget.voucher);
//
//     Future.microtask(() async {
//       await loadPermissions();
//
//       await loadVoucherList(voucher["jobworker_name"]?.toString() ?? "");
//
//       final int voucherId = int.tryParse(voucher["id"]?.toString() ?? "0") ?? 0;
//
//       if (voucherId > 0) {
//         await _loadSelectedVoucher(voucherId);
//       }
//     });
//   }
//
//   /// ============================================================
//   /// DISPOSE
//   /// ============================================================
//   @override
//   void dispose() {
//     voucherSearchController.dispose();
//
//     for (final controller in jobworkControllers.values) {
//       controller.dispose();
//     }
//     jobworkControllers.clear();
//
//     super.dispose();
//   }
//
//   /// ============================================================
//   /// PERMISSION
//   /// ============================================================
//   Future<void> loadPermissions() async {
//     final SharedPreferences prefs = await SharedPreferences.getInstance();
//
//     final List<String> permissions =
//         prefs.getStringList("user_permissions") ?? [];
//
//     if (!mounted) return;
//
//     setState(() => userPermissions = permissions);
//   }
//
//   bool hasPermission(String permissionName) {
//     return userPermissions.contains(permissionName);
//   }
//
//   /// ============================================================
//   /// BUILD
//   /// ============================================================
//   @override
//   Widget build(BuildContext context) {
//     if (!(hasPermission("jobwork-receive-view") ||
//         hasPermission("jobwork-receive-manage"))) {
//       return Scaffold(
//         body: PermissionDeniedWidget(onBack: () => Navigator.pop(context)),
//       );
//     }
//
//     final bool isMobile = MediaQuery.of(context).size.width < 600;
//
//     return PopScope(
//       canPop: false,
//       onPopInvokedWithResult: (didPop, result) {
//         if (didPop) return;
//         Navigator.pop(context, true);
//       },
//       child: Scaffold(
//         backgroundColor: AppColors.white,
//
//         /// ======================================================
//         /// BODY
//         /// ======================================================
//         body: Stack(
//           children: [
//             SingleChildScrollView(
//               physics: const AlwaysScrollableScrollPhysics(),
//               keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
//               padding: const EdgeInsets.only(bottom: 15),
//               child: Column(
//                 children: [
//                   SizedBox(height: MediaQuery.of(context).padding.top + 42),
//
//                   filterWidget(),
//
//                   Container(
//                     margin: const EdgeInsets.only(top: 8),
//                     width: double.infinity,
//                     height: 2,
//                     decoration: BoxDecoration(
//                       gradient: LinearGradient(
//                         colors: [
//                           AppColors.primaryDark.withOpacity(0.1),
//                           AppColors.primaryDark,
//                           AppColors.secondaryDark.withOpacity(0.4),
//                           AppColors.primaryDark.withOpacity(0.1),
//                         ],
//                       ),
//                     ),
//                   ),
//
//                   const SizedBox(height: 5),
//
//                   /// ONLY data["items"] DISPLAY THASE
//                   if (items.isEmpty)
//                     const Padding(
//                       padding: EdgeInsets.all(30),
//                       child: Text(
//                         "No Receive Items Found",
//                         style: TextStyle(color: Colors.black54, fontSize: 13),
//                       ),
//                     )
//                   else
//                     ListView.builder(
//                       shrinkWrap: true,
//                       physics: const NeverScrollableScrollPhysics(),
//                       padding: const EdgeInsets.symmetric(vertical: 5),
//                       itemCount: items.length,
//                       itemBuilder: (context, index) {
//                         final item = items[index];
//
//                         /// 🔥 Stable key → dropdown/field state સાચી row સાથે
//                         return KeyedSubtree(
//                           key: ValueKey("receive_row_${_rowKeyOf(item)}"),
//                           child: jobworkItemCard(item, index),
//                         );
//                       },
//                     ),
//
//                   const SizedBox(height: 20),
//                 ],
//               ),
//             ),
//
//             /// ==================================================
//             /// FIXED APPBAR
//             /// ==================================================
//             Positioned(
//               top: 0,
//               left: 0,
//               right: 0,
//               child: Container(
//                 color: Colors.white,
//                 padding: const EdgeInsets.only(
//                   top: 30,
//                   left: 16,
//                   right: 16,
//                   bottom: 12,
//                 ),
//                 child: Stack(
//                   alignment: Alignment.center,
//                   children: [
//                     const Text(
//                       "Add JobWork Receive",
//                       style: TextStyle(
//                         color: Colors.black,
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//
//                     /// BACK
//                     Align(
//                       alignment: Alignment.centerLeft,
//                       child: InkWell(
//                         onTap: () => Navigator.pop(context),
//                         borderRadius: BorderRadius.circular(8),
//                         child: Container(
//                           padding: EdgeInsets.all(isMobile ? 6 : 8),
//                           decoration: BoxDecoration(
//                             color: AppColors.primaryDark,
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           child: Icon(
//                             Icons.arrow_back,
//                             color: Colors.white,
//                             size: isMobile ? 20 : 24,
//                           ),
//                         ),
//                       ),
//                     ),
//
//                     /// PDF + ADD
//                     Align(
//                       alignment: Alignment.centerRight,
//                       child: Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           pdfBtn(() {
//                             final int id = int.tryParse(
//                               voucher["id"]?.toString() ?? "0",
//                             ) ??
//                                 0;
//                             if (id > 0) openPdf(id);
//                           }),
//                           const SizedBox(width: 8),
//                           InkWell(
//                             onTap: _addBlankReceiveRow,
//                             borderRadius: BorderRadius.circular(8),
//                             child: Container(
//                               padding: EdgeInsets.all(isMobile ? 6 : 8),
//                               decoration: BoxDecoration(
//                                 color: Colors.white,
//                                 borderRadius: BorderRadius.circular(8),
//                                 border: Border.all(color: AppColors.border),
//                                 boxShadow: [
//                                   BoxShadow(
//                                     color: AppColors.shadow,
//                                     blurRadius: 12,
//                                     offset: const Offset(3, 5),
//                                   ),
//                                 ],
//                               ),
//                               child: const Icon(
//                                 Icons.add_rounded,
//                                 size: 18,
//                                 color: AppColors.gradientBlue,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//
//         /// ======================================================
//         /// BOTTOM TOTAL + APPLY
//         /// ======================================================
//         bottomNavigationBar: SafeArea(
//           child: Container(
//             padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               border: Border(top: BorderSide(color: AppColors.border)),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.08),
//                   blurRadius: 8,
//                   offset: const Offset(0, -2),
//                 ),
//               ],
//             ),
//             child: Builder(
//               builder: (context) {
//                 final double issueNet =
//                     double.tryParse(_voucherValue("issue_net_wt_total")) ??
//                         0.0;
//
//                 final double receiveNet =
//                     double.tryParse(_totalOf("net_weight")) ?? 0.0;
//
//                 final double extraWeight =
//                 receiveNet > issueNet ? receiveNet - issueNet : 0.0;
//
//                 return Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     /// TOTALS
//                     SingleChildScrollView(
//                       scrollDirection: Axis.horizontal,
//                       physics: const BouncingScrollPhysics(),
//                       child: Container(
//                         padding: const EdgeInsets.symmetric(vertical: 8),
//                         decoration: BoxDecoration(
//                           color: Colors.grey.shade100,
//                           borderRadius: BorderRadius.circular(6),
//                           border: Border.all(color: AppColors.border),
//                         ),
//                         child: Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             SizedBox(
//                               width: 80,
//                               child: _bottomTotalItem(
//                                 "Issue Net",
//                                 issueNet.toStringAsFixed(3),
//                               ),
//                             ),
//                             _bottomDivider(),
//                             SizedBox(
//                               width: 80,
//                               child: _bottomTotalItem(
//                                 "Gross Wt",
//                                 _totalOf("gross_weight"),
//                               ),
//                             ),
//                             _bottomDivider(),
//                             SizedBox(
//                               width: 80,
//                               child: _bottomTotalItem(
//                                 "Other Wt",
//                                 _totalOf("other"),
//                               ),
//                             ),
//                             _bottomDivider(),
//                             SizedBox(
//                               width: 80,
//                               child: _bottomTotalItem(
//                                 "Net Wt",
//                                 receiveNet.toStringAsFixed(3),
//                               ),
//                             ),
//                             _bottomDivider(),
//                             SizedBox(
//                               width: 80,
//                               child: _bottomTotalItem(
//                                 "Fine Wt",
//                                 _totalOf("fine_weight"),
//                               ),
//                             ),
//                             SizedBox(
//                               width: 80,
//                               child: _bottomTotalItem(
//                                 "Pending Wt",
//                                 _currentPendingWt(),
//                               ),
//                             ),
//                             if (extraWeight > 0) ...[
//                               _bottomDivider(),
//                               SizedBox(
//                                 width: 80,
//                                 child: _bottomTotalItem(
//                                   "Extra Wt",
//                                   extraWeight.toStringAsFixed(3),
//                                 ),
//                               ),
//                             ],
//                           ],
//                         ),
//                       ),
//                     ),
//
//                     const SizedBox(height: 8),
//
//                     /// APPLY BUTTON
//                     InkWell(
//                       onTap: isSaving
//                           ? null
//                           : () async {
//                         FocusManager.instance.primaryFocus?.unfocus();
//
//                         final int voucherId = int.tryParse(
//                           voucher["id"]?.toString() ?? "0",
//                         ) ??
//                             0;
//
//                         if (voucherId == 0) {
//                           AppMessage.error(context, "Invalid voucher.");
//                           return;
//                         }
//
//                         final bool success =
//                         await updateJobworkReceive(voucherId, items);
//
//                         if (!mounted) return;
//
//                         if (success) Navigator.pop(context, true);
//                       },
//                       borderRadius: BorderRadius.circular(8),
//                       child: Container(
//                         width: double.infinity,
//                         padding: const EdgeInsets.symmetric(vertical: 12),
//                         decoration: BoxDecoration(
//                           gradient: LinearGradient(
//                             colors: [
//                               AppColors.primaryDark.withOpacity(0.7),
//                               AppColors.secondaryDark.withOpacity(0.7),
//                             ],
//                           ),
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: Center(
//                           child: isSaving
//                               ? const SizedBox(
//                             width: 18,
//                             height: 18,
//                             child: CircularProgressIndicator(
//                               strokeWidth: 2,
//                               color: Colors.white,
//                             ),
//                           )
//                               : const Text(
//                             "Apply",
//                             style: TextStyle(
//                               fontSize: 14,
//                               fontWeight: FontWeight.bold,
//                               color: Colors.white,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 );
//               },
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   /// ============================================================
//   /// ITEM CARD
//   /// ============================================================
//   Widget jobworkItemCard(Map<String, dynamic> item, int index) {
//     final dynamic rawItem = item["item"];
//
//     String itemName = (item["name"] ??
//         item["item_name"] ??
//         (rawItem is Map ? rawItem["item_name"] : rawItem))
//         ?.toString()
//         .trim() ??
//         "";
//
//     if (itemName.isEmpty || itemName == "null") itemName = "Item";
//
//     final dynamic rawItemset = item["itemset"];
//
//     String qrCode = (item["qr_code"] ??
//         item["code"] ??
//         (rawItemset is Map ? rawItemset["qr_code"] : null) ??
//         "")
//         .toString()
//         .trim();
//
//     if (qrCode == "null") qrCode = "";
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
//           /// HEADER
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
//                     "${index + 1}",
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
//                       const SizedBox(height: 1),
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
//                 /// QR CODE
//                 if (qrCode.isNotEmpty) ...[
//                   const SizedBox(width: 8),
//                   Container(
//                     constraints: const BoxConstraints(maxWidth: 130),
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 8,
//                       vertical: 5,
//                     ),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(5),
//                       border: Border.all(color: AppColors.border),
//                     ),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         const Icon(
//                           Icons.qr_code_2,
//                           size: 14,
//                           color: AppColors.primaryDark,
//                         ),
//                         const SizedBox(width: 4),
//                         Flexible(
//                           child: Text(
//                             qrCode,
//                             overflow: TextOverflow.ellipsis,
//                             style: const TextStyle(
//                               color: Colors.black87,
//                               fontSize: 11,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//
//                 const SizedBox(width: 7),
//
//                 /// DELETE
//                 InkWell(
//                   onTap: () => _deleteRow(item),
//                   borderRadius: BorderRadius.circular(5),
//                   child: Container(
//                     width: 27,
//                     height: 27,
//                     alignment: Alignment.center,
//                     decoration: BoxDecoration(
//                       gradient: const LinearGradient(
//                         colors: [Color(0xffFF8A80), Color(0xffD32F2F)],
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
//           /// FIELDS
//           Container(
//             padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
//             child: SingleChildScrollView(
//               scrollDirection: Axis.horizontal,
//               physics: const BouncingScrollPhysics(),
//               child: Row(
//                 crossAxisAlignment: CrossAxisAlignment.end,
//                 children: [
//                   _itemDropdown(item),
//                   _miniField("Purity", item, "outward_carat"),
//                   _miniField("Gross Wt", item, "gross_weight"),
//                   _miniField("Other Wt", item, "other"),
//                   _miniField("Net Wt", item, "net_weight"),
//                   _miniField("Fine Wt", item, "fine_weight"),
//                   _miniField("Qty Pcs", item, "qty"),
//                   _miniField("Pending Net Wt", item, "pending_net_wt"),
//                   _miniField("Remark", item, "remarks"),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   /// ============================================================
//   /// 🔥 DELETE ROW (index નહીં, item reference થી)
//   /// ============================================================
//   Future<void> _deleteRow(Map<String, dynamic> item) async {
//     FocusManager.instance.primaryFocus?.unfocus();
//
//     final int jobworkIssueId = int.tryParse(
//       voucher["jobwork_issue_id"]?.toString() ??
//           voucher["id"]?.toString() ??
//           "0",
//     ) ??
//         0;
//
//     final int jobworkReceiveItemId = int.tryParse(
//       item["jobwork_receive_item_id"]?.toString() ?? "0",
//     ) ??
//         0;
//
//     void removeLocal() {
//       setState(() => items.remove(item));
//       _disposeRowControllers(item);
//       _saveReceiveDraft();
//     }
//
//     /// NEW / LOCAL ROW → API call નહીં
//     if (jobworkReceiveItemId == 0) {
//       if (!mounted) return;
//       removeLocal();
//       return;
//     }
//
//     /// EXISTING API ROW
//     if (jobworkIssueId == 0) {
//       AppMessage.error(context, "Jobwork Issue ID not found.");
//       return;
//     }
//
//     try {
//       final response = await OfflineApiHelper.instance.deleteRequest(
//         "${ApiConstants.jobwork_receive}/$jobworkIssueId/items/$jobworkReceiveItemId",
//       );
//
//       debugPrint("DELETE STATUS => ${response?.statusCode}");
//       debugPrint("DELETE RESPONSE => ${response?.data}");
//
//       if (!mounted) return;
//
//       if (response?.statusCode == 202) {
//         removeLocal();
//         AppMessage.success(context, "No Internet. Delete saved offline.");
//         return;
//       }
//
//       if (response?.statusCode == 200 ||
//           response?.statusCode == 201 ||
//           response?.statusCode == 204) {
//         removeLocal();
//         AppMessage.success(context, "Item Deleted Successfully");
//         return;
//       }
//
//       AppMessage.error(
//         context,
//         response?.data?["message"]?.toString() ?? "Failed to delete item.",
//       );
//     } catch (e) {
//       debugPrint("❌ DELETE ERROR => $e");
//       if (!mounted) return;
//       AppMessage.error(context, "Failed to delete item.");
//     }
//   }
//
//   void _disposeRowControllers(Map<String, dynamic> item) {
//     final String prefix = "${_rowKeyOf(item)}_";
//     jobworkControllers.removeWhere((k, c) {
//       if (k.startsWith(prefix)) {
//         c.dispose();
//         return true;
//       }
//       return false;
//     });
//   }
//
//   /// ============================================================
//   /// MINI FIELD
//   /// ============================================================
//   Widget _miniField(String title, Map<String, dynamic> item, String key) {
//     final TextEditingController controller = getController(item, key);
//
//     final bool isOther = key == "other";
//
//     /// Manually editable fields
//     final bool editable = [
//       "outward_carat",
//       "gross_weight",
//       "qty",
//       "remarks",
//     ].contains(key);
//
//     final bool textKeyboard = key == "remarks";
//
//     final bool needsCalculation =
//         key == "gross_weight" || key == "outward_carat";
//
//     return Container(
//       width: key == "remarks"
//           ? 180
//           : key == "pending_net_wt"
//           ? 115
//           : 100,
//       margin: const EdgeInsets.only(right: 8),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title,
//             style: const TextStyle(
//               fontSize: 10,
//               fontWeight: FontWeight.w600,
//               color: Colors.black54,
//             ),
//           ),
//           const SizedBox(height: 3),
//           Stack(
//             children: [
//               SizedBox(
//                 height: 35,
//                 child: TextFormField(
//                   controller: controller,
//                   readOnly: !editable,
//                   keyboardType: textKeyboard
//                       ? TextInputType.text
//                       : const TextInputType.numberWithOptions(decimal: true),
//                   textInputAction: TextInputAction.done,
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     fontSize: 12,
//                     fontWeight: FontWeight.w600,
//                     color: editable ? Colors.black : Colors.grey.shade700,
//                   ),
//                   decoration: InputDecoration(
//                     isDense: true,
//                     filled: true,
//                     fillColor: editable ? Colors.white : Colors.grey.shade100,
//                     contentPadding: EdgeInsets.only(
//                       left: 6,
//                       right: isOther ? 30 : 6,
//                       top: 9,
//                       bottom: 9,
//                     ),
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(5),
//                       borderSide: BorderSide(color: AppColors.border),
//                     ),
//                     enabledBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(5),
//                       borderSide: BorderSide(color: AppColors.border),
//                     ),
//                     focusedBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(5),
//                       borderSide: BorderSide(
//                         color: AppColors.primaryDark,
//                         width: 1.5,
//                       ),
//                     ),
//                   ),
//                   onChanged: (value) {
//                     item[key] = value;
//
//                     /// Gross બદલાય ત્યારે live Net / Fine
//                     if (key == "gross_weight") {
//                       final double gross = double.tryParse(value.trim()) ?? 0.0;
//                       final double other = double.tryParse(
//                         item["other"]?.toString() ?? "0",
//                       ) ??
//                           0.0;
//
//                       double net = gross - other;
//                       if (net < 0) net = 0;
//
//                       final String netValue = net.toStringAsFixed(3);
//                       item["net_weight"] = netValue;
//
//                       final netController = getController(item, "net_weight");
//                       if (netController.text != netValue) {
//                         netController.text = netValue;
//                       }
//
//                       final double purity = double.tryParse(
//                         item["outward_carat"]?.toString() ?? "0",
//                       ) ??
//                           0.0;
//
//                       final double fine = net * purity / 100;
//                       item["fine_weight"] = fine.toStringAsFixed(3);
//                       getController(item, "fine_weight").text =
//                           fine.toStringAsFixed(3);
//
//                       if (mounted) setState(() {});
//                     }
//                   },
//                   onFieldSubmitted: (_) {
//                     item[key] = controller.text;
//                     if (needsCalculation) _calculateJobworkReceiveItem(item);
//                     _saveReceiveDraft();
//                   },
//                   onTapOutside: (_) {
//                     item[key] = controller.text;
//                     if (needsCalculation) _calculateJobworkReceiveItem(item);
//                     _saveReceiveDraft();
//                     FocusScope.of(context).unfocus();
//                   },
//                 ),
//               ),
//
//               /// OTHER CHARGE +
//               if (isOther)
//                 Positioned(
//                   right: 2,
//                   top: 6,
//                   child: InkWell(
//                     onTap: () {
//                       FocusManager.instance.primaryFocus?.unfocus();
//                       showOtherChargesPopup(item);
//                     },
//                     borderRadius: BorderRadius.circular(4),
//                     child: Container(
//                       padding: const EdgeInsets.all(4),
//                       decoration: BoxDecoration(
//                         color: const Color(0xffC8A96A),
//                         borderRadius: BorderRadius.circular(4),
//                       ),
//                       child: const Icon(
//                         Icons.add,
//                         size: 14,
//                         color: Colors.white,
//                       ),
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   /// ============================================================
//   /// ITEM DROPDOWN (data["item_options"])
//   /// ============================================================
//   Widget _itemDropdown(Map<String, dynamic> item) {
//     final String selectedValue =
//         item["item_name"]?.toString() ?? item["item"]?.toString() ?? "";
//
//     final List<String> options = itemOptions
//         .map((e) => e["item_name"]?.toString().trim() ?? "")
//         .where((e) => e.isNotEmpty)
//         .toSet()
//         .toList();
//
//     if (selectedValue.isNotEmpty && !options.contains(selectedValue)) {
//       options.insert(0, selectedValue);
//     }
//
//     return Container(
//       width: 155,
//       height: 55,
//       margin: const EdgeInsets.only(right: 8),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             "Item Name",
//             style: TextStyle(
//               fontSize: 10,
//               fontWeight: FontWeight.w600,
//               color: Colors.black54,
//             ),
//           ),
//           const SizedBox(height: 3),
//           Expanded(
//             child: DropdownSearch<String>(
//               key: ValueKey("item_dd_${_rowKeyOf(item)}"),
//               items: options,
//               selectedItem: selectedValue.isNotEmpty ? selectedValue : null,
//
//               /// PREMIUM BOTTOM SHEET
//               popupProps: PopupProps.modalBottomSheet(
//                 showSearchBox: true,
//                 showSelectedItems: true,
//                 constraints: BoxConstraints(
//                   maxHeight: MediaQuery.of(context).size.height * 0.72,
//                 ),
//                 modalBottomSheetProps: ModalBottomSheetProps(
//                   isScrollControlled: true,
//                   backgroundColor: Colors.white,
//                   barrierColor: Colors.black.withOpacity(0.45),
//                   shape: const RoundedRectangleBorder(
//                     borderRadius:
//                     BorderRadius.vertical(top: Radius.circular(22)),
//                   ),
//                 ),
//                 containerBuilder: (ctx, popupWidget) {
//                   return AnimatedPadding(
//                     duration: const Duration(milliseconds: 150),
//                     padding: EdgeInsets.only(
//                       bottom: MediaQuery.of(ctx).viewInsets.bottom,
//                     ),
//                     child: popupWidget,
//                   );
//                 },
//                 title: Builder(
//                   builder: (ctx) => Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       const SizedBox(height: 10),
//                       Container(
//                         width: 42,
//                         height: 4,
//                         decoration: BoxDecoration(
//                           color: Colors.grey.shade300,
//                           borderRadius: BorderRadius.circular(2),
//                         ),
//                       ),
//                       Padding(
//                         padding: const EdgeInsets.fromLTRB(16, 14, 12, 4),
//                         child: Row(
//                           children: [
//                             Container(
//                               width: 42,
//                               height: 42,
//                               decoration: BoxDecoration(
//                                 gradient: LinearGradient(
//                                   colors: [
//                                     AppColors.primaryDark,
//                                     AppColors.secondaryDark,
//                                   ],
//                                   begin: Alignment.topLeft,
//                                   end: Alignment.bottomRight,
//                                 ),
//                                 borderRadius: BorderRadius.circular(12),
//                               ),
//                               child: const Icon(
//                                 Icons.category_outlined,
//                                 color: Colors.white,
//                                 size: 22,
//                               ),
//                             ),
//                             const SizedBox(width: 12),
//                             Expanded(
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   const Text(
//                                     "Select Item",
//                                     style: TextStyle(
//                                       fontSize: 16,
//                                       fontWeight: FontWeight.bold,
//                                       color: Colors.black,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 2),
//                                   Text(
//                                     "${options.length} items available",
//                                     style: TextStyle(
//                                       fontSize: 12,
//                                       color: Colors.grey.shade600,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                             InkWell(
//                               onTap: () => Navigator.pop(ctx),
//                               borderRadius: BorderRadius.circular(20),
//                               child: Container(
//                                 padding: const EdgeInsets.all(6),
//                                 decoration: BoxDecoration(
//                                   color: Colors.grey.shade100,
//                                   shape: BoxShape.circle,
//                                 ),
//                                 child: const Icon(
//                                   Icons.close,
//                                   size: 18,
//                                   color: Colors.black54,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 searchFieldProps: TextFieldProps(
//                   padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
//                   style: const TextStyle(fontSize: 13.5, color: Colors.black),
//                   decoration: InputDecoration(
//                     hintText: "Search item...",
//                     hintStyle: TextStyle(color: Colors.grey.shade500),
//                     prefixIcon: Icon(
//                       Icons.search,
//                       size: 20,
//                       color: AppColors.primaryDark,
//                     ),
//                     isDense: true,
//                     filled: true,
//                     fillColor: Colors.grey.shade100,
//                     contentPadding: const EdgeInsets.symmetric(vertical: 12),
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(12),
//                       borderSide: BorderSide.none,
//                     ),
//                     enabledBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(12),
//                       borderSide: BorderSide.none,
//                     ),
//                     focusedBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(12),
//                       borderSide: BorderSide(
//                         color: AppColors.primaryDark,
//                         width: 1.2,
//                       ),
//                     ),
//                   ),
//                 ),
//                 listViewProps: const ListViewProps(
//                   padding: EdgeInsets.fromLTRB(12, 6, 12, 16),
//                 ),
//                 itemBuilder: (context, String itemName, bool isSelected) {
//                   final String initial =
//                   itemName.isNotEmpty ? itemName[0].toUpperCase() : "?";
//
//                   return Container(
//                     margin: const EdgeInsets.only(bottom: 8),
//                     padding:
//                     const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//                     decoration: BoxDecoration(
//                       color: isSelected
//                           ? AppColors.primaryDark.withOpacity(0.07)
//                           : Colors.white,
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(
//                         color: isSelected
//                             ? AppColors.primaryDark
//                             : AppColors.border,
//                         width: isSelected ? 1.3 : 1,
//                       ),
//                     ),
//                     child: Row(
//                       children: [
//                         Container(
//                           width: 36,
//                           height: 36,
//                           alignment: Alignment.center,
//                           decoration: BoxDecoration(
//                             gradient: isSelected
//                                 ? LinearGradient(colors: [
//                               AppColors.primaryDark,
//                               AppColors.secondaryDark,
//                             ])
//                                 : null,
//                             color: isSelected
//                                 ? null
//                                 : AppColors.primaryDark.withOpacity(0.10),
//                             borderRadius: BorderRadius.circular(10),
//                           ),
//                           child: Text(
//                             initial,
//                             style: TextStyle(
//                               fontSize: 14,
//                               fontWeight: FontWeight.bold,
//                               color: isSelected
//                                   ? Colors.white
//                                   : AppColors.primaryDark,
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: Text(
//                             itemName,
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                             style: TextStyle(
//                               fontSize: 13.5,
//                               color: Colors.black,
//                               fontWeight: isSelected
//                                   ? FontWeight.w700
//                                   : FontWeight.w600,
//                             ),
//                           ),
//                         ),
//                         Icon(
//                           isSelected ? Icons.check_circle : Icons.chevron_right,
//                           size: 20,
//                           color: isSelected
//                               ? AppColors.primaryDark
//                               : Colors.grey.shade400,
//                         ),
//                       ],
//                     ),
//                   );
//                 },
//                 emptyBuilder: (context, searchEntry) => Center(
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(
//                         Icons.search_off_rounded,
//                         size: 48,
//                         color: Colors.grey.shade400,
//                       ),
//                       const SizedBox(height: 8),
//                       const Text(
//                         "No item found",
//                         style: TextStyle(
//                           fontSize: 14,
//                           fontWeight: FontWeight.w600,
//                           color: Colors.black54,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//
//               /// MAIN FIELD
//               dropdownDecoratorProps: DropDownDecoratorProps(
//                 dropdownSearchDecoration: InputDecoration(
//                   isDense: true,
//                   filled: true,
//                   fillColor: Colors.white,
//                   hintText: "Select Item",
//                   hintStyle: const TextStyle(
//                     color: Colors.black54,
//                     fontSize: 12,
//                   ),
//                   contentPadding: const EdgeInsets.symmetric(
//                     horizontal: 8,
//                     vertical: 7,
//                   ),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(5),
//                     borderSide: BorderSide(color: AppColors.border),
//                   ),
//                   enabledBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(5),
//                     borderSide: BorderSide(color: AppColors.border),
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(5),
//                     borderSide: BorderSide(
//                       color: AppColors.primaryDark,
//                       width: 1.2,
//                     ),
//                   ),
//                 ),
//               ),
//
//               dropdownBuilder: (context, selectedItem) {
//                 return Text(
//                   selectedItem ?? "Select Item",
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: const TextStyle(
//                     color: Colors.black,
//                     fontSize: 12,
//                     height: 1.0,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 );
//               },
//
//               onChanged: (value) {
//                 if (value == null) return;
//                 FocusManager.instance.primaryFocus?.unfocus();
//
//                 final Map<String, dynamic> selectedOption =
//                 itemOptions.firstWhere(
//                       (e) => e["item_name"]?.toString().trim() == value.trim(),
//                   orElse: () => <String, dynamic>{},
//                 );
//
//                 if (selectedOption.isEmpty) return;
//
//                 final int itemId = int.tryParse(
//                   selectedOption["item_id"]?.toString() ??
//                       selectedOption["id"]?.toString() ??
//                       "0",
//                 ) ??
//                     0;
//
//                 final String purity =
//                     selectedOption["purity"]?.toString() ?? "0.000";
//
//                 final String issueNetWt =
//                     selectedOption["issue_net_wt"]?.toString() ?? "0.000";
//
//                 setState(() {
//                   item["item_id"] = itemId;
//                   item["item_name"] = value;
//                   item["item"] = value;
//
//                   item["issue_net_wt"] = issueNetWt;
//                   item["outward_carat"] = purity;
//
//                   updateController(item, "issue_net_wt");
//                   updateController(item, "outward_carat");
//
//                   _calculateJobworkReceiveItem(item);
//                 });
//
//                 debugPrint("🔥 ROW ${_rowKeyOf(item)} ITEM => $itemId $value");
//
//                 _saveReceiveDraft();
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   /// ============================================================
//   /// CALCULATION
//   /// Net = Gross - Other
//   /// Fine = Net × Purity / 100
//   /// Pending = Issue Net - Receive Net
//   /// ============================================================
//   void _calculateJobworkReceiveItem(Map<String, dynamic> item) {
//     final double issueNet =
//         double.tryParse(item["issue_net_wt_total"]?.toString() ?? "0") ?? 0.0;
//     final double gross =
//         double.tryParse(item["gross_weight"]?.toString() ?? "0") ?? 0.0;
//     final double other =
//         double.tryParse(item["other"]?.toString() ?? "0") ?? 0.0;
//     final double purity =
//         double.tryParse(item["outward_carat"]?.toString() ?? "0") ?? 0.0;
//
//     double net = gross - other;
//     if (net < 0) net = 0;
//
//     final double fine = net * purity / 100;
//
//     double pending = issueNet - net;
//     if (pending < 0) pending = 0;
//
//     item["net_weight"] = net.toStringAsFixed(3);
//     item["fine_weight"] = fine.toStringAsFixed(3);
//     item["pending_net_wt"] = pending.toStringAsFixed(3);
//
//     updateController(item, "net_weight");
//     updateController(item, "fine_weight");
//     updateController(item, "pending_net_wt");
//   }
//
//   /// ============================================================
//   /// STABLE ROW KEY + CONTROLLER
//   /// ============================================================
//   String _rowKeyOf(Map<String, dynamic> item) {
//     item["_row_key"] ??=
//     "${DateTime.now().microsecondsSinceEpoch}_${identityHashCode(item)}";
//     return item["_row_key"].toString();
//   }
//
//   TextEditingController getController(Map<String, dynamic> item, String key) {
//     final String controllerKey = "${_rowKeyOf(item)}_$key";
//
//     return jobworkControllers.putIfAbsent(
//       controllerKey,
//           () => TextEditingController(text: item[key]?.toString() ?? ""),
//     );
//   }
//
//   void updateController(Map<String, dynamic> item, String key) {
//     final TextEditingController controller = getController(item, key);
//     final String value = item[key]?.toString() ?? "";
//
//     if (controller.text != value) {
//       controller.value = TextEditingValue(
//         text: value,
//         selection: TextSelection.collapsed(offset: value.length),
//       );
//     }
//   }
//
//   /// ============================================================
//   /// OTHER CHARGE POPUP (એક જ select)
//   /// ============================================================
//   void showOtherChargesPopup(Map<String, dynamic> mainItem) {
//     final List existingDetails = mainItem["other_charge_details"] is List
//         ? mainItem["other_charge_details"]
//         : [];
//
//     final int existingChargeId = existingDetails.isNotEmpty
//         ? int.tryParse(
//       existingDetails.first["charge_id"]?.toString() ?? "0",
//     ) ??
//         0
//         : 0;
//
//     final List<Map<String, dynamic>> charges = otherCharges.map((e) {
//       final int id = int.tryParse(e["id"]?.toString() ?? "0") ?? 0;
//
//       Map<String, dynamic>? saved;
//
//       for (final detail in existingDetails) {
//         if (detail is Map &&
//             int.tryParse(detail["charge_id"]?.toString() ?? "0") == id) {
//           saved = Map<String, dynamic>.from(detail);
//           break;
//         }
//       }
//
//       final String wtFormula = _normalizeFormula(
//         saved?["wt_formula"]?.toString() ??
//             e["weight_formula"]?.toString() ??
//             "flat",
//       );
//
//       final String amtFormula = _normalizeFormula(
//         saved?["amt_formula"]?.toString() ??
//             e["other_amt_formula"]?.toString() ??
//             "flat",
//       );
//
//       return {
//         "id": id,
//         "charge": e["name"]?.toString() ?? "",
//         "amount": saved?["amount"]?.toString() ??
//             e["default_amount"]?.toString() ??
//             "0",
//         "qty": saved?["qty"]?.toString() ?? e["quantity_pcs"]?.toString() ?? "1",
//         "weight": saved?["weight"]?.toString() ??
//             e["default_weight"]?.toString() ??
//             "0",
//         "wt_formula": wtFormula,
//         "amt_formula_type": amtFormula,
//         "wt_operation": saved?["wt_operation"]?.toString() ??
//             e["wt_operation"]?.toString() ??
//             "less",
//         "total_weight": "0.000",
//         "total_amt": "0.00",
//         "is_selected": existingChargeId == id,
//       };
//     }).toList();
//
//     showDialog(
//       context: context,
//       builder: (dialogContext) {
//         return Dialog(
//           backgroundColor: const Color(0xffF5F8FC),
//           elevation: 12,
//           shadowColor: const Color(0xff0B2A4A).withOpacity(0.30),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(10),
//           ),
//           insetPadding: const EdgeInsets.symmetric(
//             horizontal: 10,
//             vertical: 20,
//           ),
//           child: StatefulBuilder(
//             builder: (context, setStateDialog) {
//               const Color primaryBlue = Color(0xff1565C0);
//               const Color darkBlue = Color(0xff0D47A1);
//               const Color lightBlue = Color(0xffEAF3FF);
//               const Color borderBlue = Color(0xffB8D4F5);
//               const Color textDark = Color(0xff17324D);
//
//               void calculateCharges() {
//                 for (final c in charges) {
//                   final double amount =
//                       double.tryParse(c["amount"]?.toString() ?? "0") ?? 0;
//                   final double qty =
//                       double.tryParse(c["qty"]?.toString() ?? "1") ?? 1;
//                   final double weight =
//                       double.tryParse(c["weight"]?.toString() ?? "0") ?? 0;
//
//                   final String wtFormula =
//                       c["wt_formula"]?.toString() ?? "flat";
//                   final String amtFormula =
//                       c["amt_formula_type"]?.toString() ?? "flat";
//
//                   double totalWeight = weight;
//                   if (wtFormula == "per_qty" || wtFormula == "per_weight") {
//                     totalWeight = weight * qty;
//                   }
//
//                   double totalAmount = amount;
//                   switch (amtFormula) {
//                     case "per_qty":
//                       totalAmount = amount * qty;
//                       break;
//                     case "per_weight":
//                       totalAmount = amount * totalWeight;
//                       break;
//                     case "per_qty_weight":
//                       totalAmount = amount * qty * weight;
//                       break;
//                   }
//
//                   c["total_weight"] = totalWeight.toStringAsFixed(3);
//                   c["total_amt"] = totalAmount.toStringAsFixed(2);
//                 }
//               }
//
//               calculateCharges();
//
//               Map<String, dynamic>? selectedCharge;
//               for (final c in charges) {
//                 if (c["is_selected"] == true) {
//                   selectedCharge = c;
//                   break;
//                 }
//               }
//
//               final double total = selectedCharge == null
//                   ? 0
//                   : double.tryParse(
//                 selectedCharge["total_amt"]?.toString() ?? "0",
//               ) ??
//                   0;
//
//               InputDecoration fieldDecoration({double vPad = 9}) {
//                 return InputDecoration(
//                   isDense: true,
//                   contentPadding: EdgeInsets.symmetric(
//                     horizontal: 8,
//                     vertical: vPad,
//                   ),
//                   filled: true,
//                   fillColor: Colors.white,
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(7),
//                     borderSide: const BorderSide(color: borderBlue),
//                   ),
//                   enabledBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(7),
//                     borderSide: const BorderSide(color: borderBlue),
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(7),
//                     borderSide: const BorderSide(
//                       color: primaryBlue,
//                       width: 1.5,
//                     ),
//                   ),
//                 );
//               }
//
//               Widget headerCell(String title, double width) {
//                 return SizedBox(
//                   width: width,
//                   child: Padding(
//                     padding: const EdgeInsets.symmetric(horizontal: 5),
//                     child: Text(
//                       title,
//                       textAlign: TextAlign.center,
//                       style: const TextStyle(
//                         fontSize: 12,
//                         fontWeight: FontWeight.w700,
//                         color: Colors.white,
//                       ),
//                     ),
//                   ),
//                 );
//               }
//
//               Widget numField(
//                   Map<String, dynamic> c,
//                   String key,
//                   double width, {
//                     bool decimal = true,
//                   }) {
//                 return SizedBox(
//                   width: width,
//                   child: TextFormField(
//                     initialValue: c[key]?.toString(),
//                     textAlign: TextAlign.center,
//                     style: const TextStyle(
//                       fontSize: 12,
//                       fontWeight: FontWeight.w600,
//                       color: textDark,
//                     ),
//                     keyboardType: decimal
//                         ? const TextInputType.numberWithOptions(decimal: true)
//                         : TextInputType.number,
//                     onChanged: (v) {
//                       c[key] = v;
//                       setStateDialog(() {});
//                     },
//                     decoration: fieldDecoration(),
//                   ),
//                 );
//               }
//
//               Widget formulaDropdown(
//                   Map<String, dynamic> c,
//                   String key,
//                   List<DropdownMenuItem<String>> options,
//                   ) {
//                 return SizedBox(
//                   width: 105,
//                   child: DropdownButtonFormField<String>(
//                     value: c[key],
//                     isExpanded: true,
//                     dropdownColor: Colors.white,
//                     style: const TextStyle(
//                       fontSize: 11,
//                       color: textDark,
//                       fontWeight: FontWeight.w600,
//                     ),
//                     icon: const Icon(
//                       Icons.keyboard_arrow_down,
//                       size: 18,
//                       color: primaryBlue,
//                     ),
//                     decoration: fieldDecoration(vPad: 8),
//                     items: options,
//                     onChanged: (v) {
//                       if (v == null) return;
//                       c[key] = v;
//                       setStateDialog(() {});
//                     },
//                   ),
//                 );
//               }
//
//               return Container(
//                 padding: const EdgeInsets.all(12),
//                 constraints: const BoxConstraints(maxHeight: 600),
//                 decoration: BoxDecoration(
//                   color: const Color(0xffF5F8FC),
//                   borderRadius: BorderRadius.circular(18),
//                 ),
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     /// TOP HEADER
//                     Container(
//                       width: double.infinity,
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 16,
//                         vertical: 13,
//                       ),
//                       decoration: BoxDecoration(
//                         gradient: const LinearGradient(
//                           begin: Alignment.topLeft,
//                           end: Alignment.bottomRight,
//                           colors: [Color(0xff0D47A1), Color(0xff1976D2)],
//                         ),
//                         borderRadius: BorderRadius.circular(12),
//                         boxShadow: [
//                           BoxShadow(
//                             color: const Color(0xff1565C0).withOpacity(0.22),
//                             blurRadius: 8,
//                             offset: const Offset(0, 4),
//                           ),
//                         ],
//                       ),
//                       child: Row(
//                         children: [
//                           Container(
//                             width: 36,
//                             height: 36,
//                             decoration: BoxDecoration(
//                               color: Colors.white.withOpacity(0.15),
//                               borderRadius: BorderRadius.circular(9),
//                             ),
//                             child: const Icon(
//                               Icons.receipt_long_rounded,
//                               color: Colors.white,
//                               size: 21,
//                             ),
//                           ),
//                           const SizedBox(width: 11),
//                           const Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   "Other Charges",
//                                   style: TextStyle(
//                                     fontSize: 17,
//                                     fontWeight: FontWeight.w800,
//                                     color: Colors.white,
//                                   ),
//                                 ),
//                                 SizedBox(height: 2),
//                                 Text(
//                                   "Select and calculate additional charges",
//                                   style: TextStyle(
//                                     fontSize: 11,
//                                     color: Color(0xffDCEBFF),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                           IconButton(
//                             visualDensity: VisualDensity.compact,
//                             onPressed: () => Navigator.pop(dialogContext),
//                             icon: const Icon(
//                               Icons.close_rounded,
//                               color: Colors.white,
//                               size: 21,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//
//                     const SizedBox(height: 12),
//
//                     /// TABLE
//                     Expanded(
//                       child: Container(
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(11),
//                           border: Border.all(color: borderBlue),
//                         ),
//                         child: ClipRRect(
//                           borderRadius: BorderRadius.circular(11),
//                           child: SingleChildScrollView(
//                             scrollDirection: Axis.horizontal,
//                             child: SizedBox(
//                               width: 820,
//                               child: Column(
//                                 children: [
//                                   Container(
//                                     padding:
//                                     const EdgeInsets.symmetric(vertical: 5),
//                                     decoration: const BoxDecoration(
//                                       gradient: LinearGradient(
//                                         colors: [
//                                           Color(0xff0D47A1),
//                                           Color(0xff1976D2),
//                                         ],
//                                       ),
//                                     ),
//                                     child: Row(
//                                       children: [
//                                         headerCell("Charge", 120),
//                                         headerCell("Amount", 90),
//                                         headerCell("Qty", 70),
//                                         headerCell("Weight", 90),
//                                         headerCell("Wt Formula", 110),
//                                         headerCell("Total Wt", 110),
//                                         headerCell("Amt Formula", 110),
//                                         headerCell("Select", 80),
//                                       ],
//                                     ),
//                                   ),
//                                   const SizedBox(height: 5),
//                                   Expanded(
//                                     child: ListView.builder(
//                                       padding: const EdgeInsets.symmetric(
//                                         horizontal: 5,
//                                       ),
//                                       itemCount: charges.length,
//                                       itemBuilder: (context, index) {
//                                         final c = charges[index];
//                                         final bool selected =
//                                             c["is_selected"] == true;
//
//                                         return AnimatedContainer(
//                                           duration:
//                                           const Duration(milliseconds: 150),
//                                           margin:
//                                           const EdgeInsets.only(bottom: 6),
//                                           decoration: BoxDecoration(
//                                             color: selected
//                                                 ? lightBlue
//                                                 : Colors.white,
//                                             borderRadius:
//                                             BorderRadius.circular(8),
//                                             border: Border.all(
//                                               color: selected
//                                                   ? primaryBlue
//                                                   : const Color(0xffE2EAF3),
//                                               width: selected ? 1.2 : 1,
//                                             ),
//                                           ),
//                                           child: Row(
//                                             children: [
//                                               SizedBox(
//                                                 width: 120,
//                                                 child: Padding(
//                                                   padding: const EdgeInsets
//                                                       .symmetric(horizontal: 7),
//                                                   child: Text(
//                                                     c["charge"]?.toString() ??
//                                                         "",
//                                                     maxLines: 2,
//                                                     overflow:
//                                                     TextOverflow.ellipsis,
//                                                     style: TextStyle(
//                                                       fontSize: 12,
//                                                       color: textDark,
//                                                       fontWeight: selected
//                                                           ? FontWeight.w800
//                                                           : FontWeight.w600,
//                                                     ),
//                                                   ),
//                                                 ),
//                                               ),
//                                               numField(c, "amount", 90),
//                                               const SizedBox(width: 5),
//                                               numField(c, "qty", 65,
//                                                   decimal: false),
//                                               const SizedBox(width: 5),
//                                               numField(c, "weight", 85),
//                                               const SizedBox(width: 5),
//                                               formulaDropdown(
//                                                 c,
//                                                 "wt_formula",
//                                                 const [
//                                                   DropdownMenuItem(
//                                                     value: "flat",
//                                                     child: Text("Flat"),
//                                                   ),
//                                                   DropdownMenuItem(
//                                                     value: "per_qty",
//                                                     child: Text("Per Qty"),
//                                                   ),
//                                                   DropdownMenuItem(
//                                                     value: "per_weight",
//                                                     child: Text("Per Wt"),
//                                                   ),
//                                                 ],
//                                               ),
//                                               SizedBox(
//                                                 width: 110,
//                                                 child: Container(
//                                                   margin: const EdgeInsets
//                                                       .symmetric(horizontal: 4),
//                                                   padding: const EdgeInsets
//                                                       .symmetric(vertical: 10),
//                                                   decoration: BoxDecoration(
//                                                     color:
//                                                     const Color(0xffF1F7FF),
//                                                     borderRadius:
//                                                     BorderRadius.circular(7),
//                                                     border: Border.all(
//                                                       color: const Color(
//                                                           0xffD3E5FA),
//                                                     ),
//                                                   ),
//                                                   child: Text(
//                                                     c["total_weight"]
//                                                         ?.toString() ??
//                                                         "0.000",
//                                                     textAlign: TextAlign.center,
//                                                     style: const TextStyle(
//                                                       fontSize: 12,
//                                                       color: darkBlue,
//                                                       fontWeight:
//                                                       FontWeight.w800,
//                                                     ),
//                                                   ),
//                                                 ),
//                                               ),
//                                               formulaDropdown(
//                                                 c,
//                                                 "amt_formula_type",
//                                                 const [
//                                                   DropdownMenuItem(
//                                                     value: "flat",
//                                                     child: Text("Flat"),
//                                                   ),
//                                                   DropdownMenuItem(
//                                                     value: "per_qty",
//                                                     child: Text("Per Qty"),
//                                                   ),
//                                                   DropdownMenuItem(
//                                                     value: "per_weight",
//                                                     child: Text("Per Wt"),
//                                                   ),
//                                                   DropdownMenuItem(
//                                                     value: "per_qty_weight",
//                                                     child: Text("Qty × Wt"),
//                                                   ),
//                                                 ],
//                                               ),
//                                               SizedBox(
//                                                 width: 80,
//                                                 child: Center(
//                                                   child: Checkbox(
//                                                     value: selected,
//                                                     activeColor: primaryBlue,
//                                                     checkColor: Colors.white,
//                                                     shape:
//                                                     RoundedRectangleBorder(
//                                                       borderRadius:
//                                                       BorderRadius.circular(
//                                                           4),
//                                                     ),
//                                                     onChanged: (value) {
//                                                       setStateDialog(() {
//                                                         for (final charge
//                                                         in charges) {
//                                                           charge["is_selected"] =
//                                                           false;
//                                                         }
//                                                         if (value == true) {
//                                                           c["is_selected"] =
//                                                           true;
//                                                         }
//                                                       });
//                                                     },
//                                                   ),
//                                                 ),
//                                               ),
//                                             ],
//                                           ),
//                                         );
//                                       },
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//
//                     const SizedBox(height: 10),
//
//                     /// SELECTED AMOUNT
//                     Container(
//                       width: double.infinity,
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 15,
//                         vertical: 11,
//                       ),
//                       decoration: BoxDecoration(
//                         gradient: const LinearGradient(
//                           colors: [Color(0xffEAF3FF), Color(0xffDDEEFF)],
//                         ),
//                         borderRadius: BorderRadius.circular(10),
//                         border: Border.all(color: borderBlue),
//                       ),
//                       child: Row(
//                         children: [
//                           Container(
//                             padding: const EdgeInsets.all(7),
//                             decoration: BoxDecoration(
//                               color: primaryBlue,
//                               borderRadius: BorderRadius.circular(7),
//                             ),
//                             child: const Icon(
//                               Icons.calculate_rounded,
//                               size: 17,
//                               color: Colors.white,
//                             ),
//                           ),
//                           const SizedBox(width: 10),
//                           const Expanded(
//                             child: Text(
//                               "Selected Amount",
//                               style: TextStyle(
//                                 fontSize: 13,
//                                 fontWeight: FontWeight.w700,
//                                 color: textDark,
//                               ),
//                             ),
//                           ),
//                           Text(
//                             total.toStringAsFixed(2),
//                             style: const TextStyle(
//                               fontSize: 16,
//                               fontWeight: FontWeight.w900,
//                               color: darkBlue,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//
//                     const SizedBox(height: 11),
//
//                     /// APPLY CHARGE
//                     InkWell(
//                       borderRadius: BorderRadius.circular(10),
//                       onTap: () {
//                         Map<String, dynamic>? selected;
//                         for (final c in charges) {
//                           if (c["is_selected"] == true) {
//                             selected = c;
//                             break;
//                           }
//                         }
//
//                         if (selected == null) {
//                           ScaffoldMessenger.of(context).showSnackBar(
//                             SnackBar(
//                               behavior: SnackBarBehavior.floating,
//                               backgroundColor: darkBlue,
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               content: const Row(
//                                 children: [
//                                   Icon(Icons.info_outline, color: Colors.white),
//                                   SizedBox(width: 8),
//                                   Text("Please select charge"),
//                                 ],
//                               ),
//                             ),
//                           );
//                           return;
//                         }
//
//                         calculateCharges();
//
//                         final double selectedWeight = double.tryParse(
//                           selected["total_weight"]?.toString() ?? "0",
//                         ) ??
//                             0;
//
//                         final double selectedAmount = double.tryParse(
//                           selected["total_amt"]?.toString() ?? "0",
//                         ) ??
//                             0;
//
//                         mainItem["other"] = selectedWeight.toStringAsFixed(3);
//                         mainItem["sale_other"] =
//                             selectedAmount.toStringAsFixed(2);
//
//                         mainItem["other_charge_details"] = [
//                           {
//                             "charge_id": selected["id"],
//                             "charge_name": selected["charge"],
//                             "amount": double.tryParse(
//                               selected["amount"]?.toString() ?? "0",
//                             ) ??
//                                 0,
//                             "qty": int.tryParse(
//                               selected["qty"]?.toString() ?? "1",
//                             ) ??
//                                 1,
//                             "wt_formula": selected["wt_formula"],
//                             "amt_formula": selected["amt_formula_type"],
//                             "weight": selectedWeight,
//                             "total": selectedAmount,
//                             "wt_operation": selected["wt_operation"],
//                           },
//                         ];
//
//                         updateController(mainItem, "other");
//                         _calculateJobworkReceiveItem(mainItem);
//                         _saveReceiveDraft();
//
//                         Navigator.pop(dialogContext);
//                         setState(() {});
//                       },
//                       child: Container(
//                         width: double.infinity,
//                         padding: const EdgeInsets.symmetric(vertical: 13),
//                         decoration: BoxDecoration(
//                           gradient: const LinearGradient(
//                             colors: [
//                               Color(0xff0D47A1),
//                               Color(0xff1976D2),
//                               Color(0xff2196F3),
//                             ],
//                           ),
//                           borderRadius: BorderRadius.circular(10),
//                           boxShadow: [
//                             BoxShadow(
//                               color: const Color(0xff1565C0).withOpacity(0.25),
//                               blurRadius: 8,
//                               offset: const Offset(0, 4),
//                             ),
//                           ],
//                         ),
//                         child: const Row(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             Icon(
//                               Icons.check_circle_outline,
//                               size: 19,
//                               color: Colors.white,
//                             ),
//                             SizedBox(width: 8),
//                             Text(
//                               "Apply Charge",
//                               style: TextStyle(
//                                 fontSize: 14,
//                                 fontWeight: FontWeight.w800,
//                                 color: Colors.white,
//                                 letterSpacing: 0.2,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               );
//             },
//           ),
//         );
//       },
//     );
//   }
//
//   String _normalizeFormula(String value) {
//     switch (value.trim().toLowerCase()) {
//       case "per_quantity":
//       case "per qty":
//       case "per_qty":
//         return "per_qty";
//       case "per_weight":
//       case "per wt":
//       case "per_weight_value":
//         return "per_weight";
//       case "per_qty_weight":
//       case "qty × wt":
//         return "per_qty_weight";
//       default:
//         return "flat";
//     }
//   }
//
//   /// ============================================================
//   /// LOAD DETAIL
//   /// data["items"]         → screen list
//   /// data["item_options"]  → dropdown
//   /// data["other_charges"] → popup
//   /// ============================================================
//   Future<void> _loadSelectedVoucher(int id) async {
//     try {
//       final response = await ApiHelper().getRequestWithId(
//         ApiConstants.jobwork_receive,
//         id,
//       );
//
//       debugPrint("JOBWORK RECEIVE DETAIL RESPONSE => ${response?.data}");
//
//       if (response == null ||
//           response.statusCode != 200 ||
//           response.data["success"] != true) {
//         debugPrint("❌ JobWork Receive Detail API Failed");
//         return;
//       }
//
//       final Map<String, dynamic> data =
//       Map<String, dynamic>.from(response.data["data"]);
//
//       /// ITEM OPTIONS
//       final List<Map<String, dynamic>> newItemOptions = [];
//       if (data["item_options"] is List) {
//         for (final raw in data["item_options"]) {
//           if (raw is Map) newItemOptions.add(Map<String, dynamic>.from(raw));
//         }
//       }
//
//       /// OTHER CHARGES
//       final List<Map<String, dynamic>> newOtherCharges = [];
//       if (data["other_charges"] is List) {
//         for (final raw in data["other_charges"]) {
//           if (raw is Map) newOtherCharges.add(Map<String, dynamic>.from(raw));
//         }
//       }
//
//       /// RECEIVE ITEMS
//       final List<Map<String, dynamic>> newItems = [];
//       final dynamic rawItems = data["items"];
//
//       if (rawItems is List && rawItems.isNotEmpty) {
//         for (final raw in rawItems) {
//           if (raw is! Map) continue;
//
//           final Map<String, dynamic> received = Map<String, dynamic>.from(raw);
//
//           final int itemId =
//               int.tryParse(received["item_id"]?.toString() ?? "0") ?? 0;
//
//           /// item_options માંથી issue wt / purity
//           Map<String, dynamic> option = {};
//           for (final op in newItemOptions) {
//             final int optionItemId = int.tryParse(
//               op["item_id"]?.toString() ?? op["id"]?.toString() ?? "0",
//             ) ??
//                 0;
//             if (optionItemId == itemId) {
//               option = op;
//               break;
//             }
//           }
//
//           final String issueNetWt = option["issue_net_wt_total"]?.toString() ??
//               received["issue_net_wt_total"]?.toString() ??
//               "0.000";
//
//           final String purity = option["purity"]?.toString() ??
//               received["purity"]?.toString() ??
//               received["outward_carat"]?.toString() ??
//               "0.000";
//
//           final double receiveNet =
//               double.tryParse(received["receive_net_wt"]?.toString() ?? "0") ??
//                   0.0;
//
//           double pending = (double.tryParse(issueNetWt) ?? 0.0) - receiveNet;
//           if (pending < 0) pending = 0;
//
//           final String itemName = received["item_name"]?.toString() ??
//               option["item_name"]?.toString() ??
//               "";
//
//           newItems.add({
//             "_row_key":
//             "existing_${itemId}_${DateTime.now().microsecondsSinceEpoch}_${newItems.length}",
//
//             /// 🔥 DELETE / UPDATE IDS
//             "jobwork_issue_id":
//             int.tryParse(data["jobwork_issue_id"]?.toString() ?? "0") ?? 0,
//             "jobwork_receive_item_id": int.tryParse(
//               received["jobwork_receive_item_id"]?.toString() ??
//                   received["id"]?.toString() ??
//                   "0",
//             ) ??
//                 0,
//
//             "_is_existing": true,
//             "_original_net_weight": received["receive_net_wt"]?.toString() ??
//                 received["net_weight"]?.toString() ??
//                 "0.000",
//
//             "item_id": itemId,
//             "item_name": itemName,
//             "item": itemName,
//
//             "issue_net_wt": issueNetWt,
//             "outward_carat": purity,
//
//             "gross_weight": received["receive_gross_wt"]?.toString() ??
//                 received["gross_weight"]?.toString() ??
//                 "0.000",
//             "other": received["other_wt"]?.toString() ??
//                 received["other"]?.toString() ??
//                 "0.000",
//             "sale_other": received["other_amt"]?.toString() ??
//                 received["sale_other"]?.toString() ??
//                 "0.00",
//             "net_weight": received["receive_net_wt"]?.toString() ??
//                 received["net_weight"]?.toString() ??
//                 "0.000",
//             "fine_weight": received["receive_fine_wt"]?.toString() ??
//                 received["fine_weight"]?.toString() ??
//                 "0.000",
//             "qty": received["receive_qty_pcs"]?.toString() ??
//                 received["qty"]?.toString() ??
//                 "0",
//
//             "pending_net_wt": pending.toStringAsFixed(3),
//             "remarks": received["remarks"]?.toString() ?? "",
//             "loss_wt": received["loss_wt"]?.toString() ?? "0.000",
//             "other_charge_details": received["other_charge_details"] is List
//                 ? List.from(received["other_charge_details"])
//                 : [],
//           });
//         }
//       }
//
//       /// પહેલી વખત receive → એક blank row
//       if (newItems.isEmpty) {
//         newItems.add(_blankRow());
//       }
//
//       /// OLD CONTROLLERS CLEAR
//       for (final controller in jobworkControllers.values) {
//         controller.dispose();
//       }
//       jobworkControllers.clear();
//
//       if (!mounted) return;
//
//       setState(() {
//         voucher = data;
//         itemOptions = newItemOptions;
//         otherCharges = newOtherCharges;
//         items = newItems;
//         voucherSearchController.text = voucher["voucher_no"]?.toString() ?? "";
//       });
//
//       debugPrint("🔥 ITEM OPTIONS => ${itemOptions.length}");
//       debugPrint("🔥 OTHER CHARGES => ${otherCharges.length}");
//       debugPrint("🔥 DISPLAY ITEMS => ${items.length}");
//     } catch (e, stackTrace) {
//       debugPrint("❌ Jobwork Detail Error => $e");
//       debugPrint("❌ STACK => $stackTrace");
//     }
//   }
//
//   /// ============================================================
//   /// LOAD VOUCHER LIST BY SAME WORKER
//   /// ============================================================
//   Future<void> loadVoucherList(String workerName) async {
//     try {
//       final response = await ApiHelper().getRequest(
//         ApiConstants.jobwork_receive,
//         showLoading: false,
//       );
//
//       if (response?.statusCode != 200 || response?.data["success"] != true) {
//         if (!mounted) return;
//         setState(() => voucherList = []);
//         return;
//       }
//
//       final List data = response?.data["data"] ?? [];
//       final String selectedWorker = workerName.trim().toLowerCase();
//
//       final List<Map<String, dynamic>> filtered = data
//           .whereType<Map>()
//           .map((e) => Map<String, dynamic>.from(e))
//           .where((element) =>
//       (element["jobworker_name"]?.toString().trim().toLowerCase() ??
//           "") ==
//           selectedWorker)
//           .toList();
//
//       if (!mounted) return;
//
//       setState(() {
//         voucherList = filtered;
//         voucherSearchController.text = voucher["voucher_no"]?.toString() ?? "";
//       });
//     } catch (e) {
//       debugPrint("Voucher List Error => $e");
//     }
//   }
//
//   /// ============================================================
//   /// SEARCHABLE VOUCHER
//   /// ============================================================
//   Widget _searchableVoucherDropdown() {
//     final String search = voucherSearchController.text.trim().toLowerCase();
//
//     final List<Map<String, dynamic>> filteredList = voucherList
//         .where((element) =>
//         (element["voucher_no"]?.toString().toLowerCase() ?? "")
//             .contains(search))
//         .toList();
//
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Text(
//           "Voucher",
//           style: TextStyle(
//             fontSize: 11,
//             fontWeight: FontWeight.w600,
//             color: Colors.black87,
//           ),
//         ),
//         const SizedBox(height: 5),
//         TextFormField(
//           controller: voucherSearchController,
//           readOnly: true,
//           style: const TextStyle(fontSize: 12, color: Colors.black),
//           onTap: () {
//             setState(() => isVoucherDropdownOpen = !isVoucherDropdownOpen);
//           },
//           decoration: InputDecoration(
//             hintText: "Select Voucher",
//             prefixIcon: const Icon(Icons.receipt_long, size: 18),
//             suffixIcon: Icon(
//               isVoucherDropdownOpen
//                   ? Icons.keyboard_arrow_up
//                   : Icons.keyboard_arrow_down,
//             ),
//             filled: true,
//             fillColor: Colors.white,
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(5),
//               borderSide: BorderSide(color: AppColors.border),
//             ),
//             enabledBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(5),
//               borderSide: BorderSide(color: AppColors.border),
//             ),
//           ),
//         ),
//         if (isVoucherDropdownOpen)
//           Container(
//             margin: const EdgeInsets.only(top: 3),
//             constraints: const BoxConstraints(maxHeight: 220),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(5),
//               border: Border.all(color: AppColors.border),
//             ),
//             child: filteredList.isEmpty
//                 ? const Padding(
//               padding: EdgeInsets.all(15),
//               child: Center(child: Text("No Voucher Found")),
//             )
//                 : ListView.separated(
//               shrinkWrap: true,
//               itemCount: filteredList.length,
//               separatorBuilder: (_, __) => const Divider(height: 1),
//               itemBuilder: (context, index) {
//                 final item = filteredList[index];
//
//                 return ListTile(
//                   dense: true,
//                   title: Text(item["voucher_no"]?.toString() ?? "-"),
//                   subtitle:
//                   Text(item["jobworker_name"]?.toString() ?? "-"),
//                   trailing: Text(item["voucher_date"]?.toString() ?? ""),
//                   onTap: () async {
//                     final int id =
//                         int.tryParse(item["id"]?.toString() ?? "0") ?? 0;
//
//                     setState(() {
//                       selectedVoucher = item;
//                       voucherSearchController.text =
//                           item["voucher_no"]?.toString() ?? "";
//                       isVoucherDropdownOpen = false;
//                     });
//
//                     if (id > 0) await _loadSelectedVoucher(id);
//                   },
//                 );
//               },
//             ),
//           ),
//       ],
//     );
//   }
//
//   /// ============================================================
//   /// FILTER / DETAILS
//   /// ============================================================
//   Widget filterWidget() {
//     void toggle() =>
//         setState(() => isJobworkInfoExpanded = !isJobworkInfoExpanded);
//
//     return Container(
//       margin: const EdgeInsets.only(top: 5),
//       padding: const EdgeInsets.all(12),
//       child: Column(
//         children: [
//           InkWell(
//             onTap: toggle,
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
//               decoration: BoxDecoration(
//                 color: AppColors.cardBackground,
//                 borderRadius: BorderRadius.circular(6),
//                 border: Border.all(color: AppColors.border),
//               ),
//               child: Row(
//                 children: [
//                   Container(
//                     width: 36,
//                     height: 36,
//                     decoration: BoxDecoration(
//                       color: Colors.blue.withOpacity(0.12),
//                       borderRadius: BorderRadius.circular(6),
//                     ),
//                     child: const Icon(Icons.receipt_long, color: Colors.blue),
//                   ),
//                   const SizedBox(width: 6),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text(
//                           "Jobwork Receive Details",
//                           style: TextStyle(
//                             fontSize: 13,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.black,
//                           ),
//                         ),
//                         const SizedBox(height: 3),
//                         Text(
//                           "Voucher No: ${voucher["voucher_no"]?.toString() ?? "-"}",
//                           style: TextStyle(
//                             fontSize: 11,
//                             color: Colors.grey.shade600,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//
//                   /// ADD
//                   InkWell(
//                     onTap: _addBlankReceiveRow,
//                     borderRadius: BorderRadius.circular(6),
//                     child: Container(
//                       padding: const EdgeInsets.all(5),
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(8),
//                         border: Border.all(color: AppColors.border),
//                         boxShadow: [
//                           BoxShadow(
//                             color: AppColors.shadow,
//                             blurRadius: 12,
//                             offset: const Offset(3, 5),
//                           ),
//                         ],
//                       ),
//                       child: const Icon(
//                         Icons.add_rounded,
//                         size: 18,
//                         color: AppColors.gradientBlue,
//                       ),
//                     ),
//                   ),
//
//                   const SizedBox(width: 5),
//
//                   /// EXPAND
//                   InkWell(
//                     onTap: toggle,
//                     borderRadius: BorderRadius.circular(20),
//                     child: Padding(
//                       padding: const EdgeInsets.all(5),
//                       child: Icon(
//                         isJobworkInfoExpanded
//                             ? Icons.expand_less
//                             : Icons.expand_more,
//                         color: Colors.blue,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           AnimatedCrossFade(
//             firstChild: const SizedBox.shrink(),
//             secondChild: Padding(
//               padding: const EdgeInsets.only(top: 10),
//               child: Column(
//                 children: [
//                   _searchableVoucherDropdown(),
//                   const SizedBox(height: 10),
//                   _infoRow(
//                     _infoCard(
//                       title: "Receive Date",
//                       value: voucher["receive_date"]?.toString() ?? "-",
//                       icon: Icons.calendar_month,
//                       color: Colors.blue,
//                     ),
//                     _infoCard(
//                       title: "Jobworker",
//                       value: voucher["jobworker_name"]?.toString() ?? "-",
//                       icon: Icons.person,
//                       color: Colors.orange,
//                     ),
//                   ),
//                   _infoRow(
//                     _infoCard(
//                       title: "Production Step",
//                       value:
//                       voucher["production_step_name"]?.toString() ?? "-",
//                       icon: Icons.settings,
//                       color: Colors.green,
//                     ),
//                     _infoCard(
//                       title: "Voucher Date",
//                       value: voucher["voucher_date"]?.toString() ?? "-",
//                       icon: Icons.calendar_today,
//                       color: Colors.purple,
//                     ),
//                   ),
//                   _infoRow(
//                     _infoCard(
//                       title: "Issue Net Wt",
//                       value:
//                       voucher["issue_net_wt_total"]?.toString() ?? "0.000",
//                       icon: Icons.scale,
//                       color: Colors.blue,
//                     ),
//                     _infoCard(
//                       title: "Receive Net Wt",
//                       value: voucher["receive_net_wt_total"]?.toString() ??
//                           "0.000",
//                       icon: Icons.inventory_2,
//                       color: Colors.orange,
//                     ),
//                   ),
//                   _infoRow(
//                     _infoCard(
//                       title: "Pending Net Wt",
//                       value: voucher["pending_net_wt_total"]?.toString() ??
//                           "0.000",
//                       icon: Icons.pending_actions,
//                       color: Colors.red,
//                     ),
//                     _infoCard(
//                       title: "Voucher No",
//                       value: voucher["voucher_no"]?.toString() ?? "-",
//                       icon: Icons.receipt_long,
//                       color: Colors.purple,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             crossFadeState: isJobworkInfoExpanded
//                 ? CrossFadeState.showSecond
//                 : CrossFadeState.showFirst,
//             duration: const Duration(milliseconds: 200),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _infoRow(Widget left, Widget right) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 8),
//       child: Row(
//         children: [
//           Expanded(child: left),
//           const SizedBox(width: 8),
//           Expanded(child: right),
//         ],
//       ),
//     );
//   }
//
//   Widget _infoCard({
//     required String title,
//     required String value,
//     required IconData icon,
//     required Color color,
//   }) {
//     return Container(
//       padding: const EdgeInsets.all(10),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: Colors.grey.shade300),
//       ),
//       child: Row(
//         children: [
//           CircleAvatar(
//             radius: 18,
//             backgroundColor: color.withOpacity(0.12),
//             child: Icon(icon, color: color, size: 18),
//           ),
//           const SizedBox(width: 10),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   title,
//                   style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
//                 ),
//                 const SizedBox(height: 3),
//                 Text(
//                   value,
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: const TextStyle(
//                     fontSize: 13,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.black,
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
//   /// ============================================================
//   /// 🔥 SAVE API — બધી rows જાય
//   /// ============================================================
//   Future<bool> updateJobworkReceive(
//       int voucherId,
//       List<Map<String, dynamic>> items,
//       ) async {
//     final List<Map<String, dynamic>> requestItems = [];
//
//     int rowNo = 0;
//
//     for (final item in items) {
//       rowNo++;
//
//       final int itemId = int.tryParse(item["item_id"]?.toString() ?? "0") ?? 0;
//
//       final double gross =
//           double.tryParse(item["gross_weight"]?.toString() ?? "0") ?? 0;
//       final double otherWt =
//           double.tryParse(item["other"]?.toString() ?? "0") ?? 0;
//       final double otherAmt =
//           double.tryParse(item["sale_other"]?.toString() ?? "0") ?? 0;
//       final double net =
//           double.tryParse(item["net_weight"]?.toString() ?? "0") ?? 0;
//       final double fine =
//           double.tryParse(item["fine_weight"]?.toString() ?? "0") ?? 0;
//       final int qty = int.tryParse(item["qty"]?.toString() ?? "0") ?? 0;
//
//       /// 🔥 સાવ ખાલી row → skip
//       final bool isBlankRow = itemId == 0 && gross <= 0 && qty <= 0;
//       if (isBlankRow) continue;
//
//       /// 🔥 Data ભર્યો છે પણ Item નથી → error (ચૂપચાપ skip નહીં)
//       if (itemId == 0) {
//         if (mounted) {
//           AppMessage.error(context, "Please select Item in row $rowNo.");
//         }
//         return false;
//       }
//       /// 🔥 Item select છે પણ weight નથી → error
//       if (gross <= 0) {
//         if (mounted) {
//           AppMessage.error(context, "Please enter Gross Wt in row $rowNo.");
//         }
//         return false;
//       }
//
//       final List<Map<String, dynamic>> chargeDetails = [];
//
//       if (item["other_charge_details"] is List) {
//         for (final raw in item["other_charge_details"]) {
//           if (raw is! Map) continue;
//
//           chargeDetails.add({
//             "charge_id": int.tryParse(raw["charge_id"]?.toString() ?? "0") ?? 0,
//             "charge_name": raw["charge_name"]?.toString() ?? "",
//             "amount": double.tryParse(raw["amount"]?.toString() ?? "0") ?? 0,
//             "qty": int.tryParse(raw["qty"]?.toString() ?? "1") ?? 1,
//             "wt_formula": raw["wt_formula"]?.toString() ?? "flat",
//             "amt_formula": raw["amt_formula"]?.toString() ?? "flat",
//             "weight": double.tryParse(raw["weight"]?.toString() ?? "0") ?? 0,
//             "total": double.tryParse(raw["total"]?.toString() ?? "0") ?? 0,
//             "wt_operation": raw["wt_operation"]?.toString() ?? "less",
//           });
//         }
//       }
//
//       /// 🔥 Existing row નું id (નવી row માં 0 → મોકલવું નહીં)
//       final int receiveItemId =
//           int.tryParse(item["jobwork_receive_item_id"]?.toString() ?? "0") ?? 0;
//
//       requestItems.add({
//         if (receiveItemId > 0) "id": receiveItemId,
//         if (receiveItemId > 0) "jobwork_receive_item_id": receiveItemId,
//         "item_id": itemId,
//         "receive_gross_wt": double.parse(gross.toStringAsFixed(3)),
//         "other_wt": double.parse(otherWt.toStringAsFixed(3)),
//         "other_amt": double.parse(otherAmt.toStringAsFixed(2)),
//         "other_charge_details": chargeDetails,
//         "receive_net_wt": double.parse(net.toStringAsFixed(3)),
//         "receive_fine_wt": double.parse(fine.toStringAsFixed(3)),
//         "receive_qty_pcs": qty,
//         "remarks": item["remarks"]?.toString().trim().isNotEmpty == true
//             ? item["remarks"].toString().trim()
//             : null,
//       });
//     }
//
//     if (requestItems.isEmpty) {
//       if (mounted) AppMessage.error(context, "Please add at least one item.");
//       return false;
//     }
//
//     debugPrint("🔥 ROWS ON SCREEN => ${items.length}");
//     debugPrint("🔥 ITEMS SENDING  => ${requestItems.length}");
//
//     /// dd-MM-yyyy → yyyy-MM-dd
//     String receiveDate = voucher["receive_date"]?.toString() ?? "";
//     try {
//       final DateTime parsed = DateFormat("dd-MM-yyyy").parseStrict(receiveDate);
//       receiveDate = DateFormat("yyyy-MM-dd").format(parsed);
//     } catch (_) {}
//
//     final Map<String, dynamic> body = {
//       "receive_date": receiveDate,
//       "remarks": voucher["remarks"]?.toString() ?? "",
//       "items": requestItems,
//     };
//
//     debugPrint("JOBWORK RECEIVE BODY => $body");
//
//     setState(() => isSaving = true);
//
//     try {
//       final response = await OfflineApiHelper.instance.putRequest(
//         "${ApiConstants.jobwork_receive}/$voucherId",
//         body,
//       );
//
//       debugPrint("JOBWORK RECEIVE RESPONSE => ${response?.data}");
//
//       if (!mounted) return false;
//
//       if (response == null) {
//         AppMessage.error(context, "No response from server.");
//         return false;
//       }
//
//       if (response.statusCode == 202) {
//         AppMessage.success(context, "No Internet. Saved offline.");
//         return true;
//       }
//
//       final data = response.data;
//
//       if ((response.statusCode == 200 || response.statusCode == 201) &&
//           data is Map &&
//           data["success"] == true) {
//         AppMessage.success(
//           context,
//           data["message"] ?? "JobWork Receive Saved Successfully",
//         );
//         return true;
//       }
//
//       /// VALIDATION / OTHER ERROR
//       String msg = "Failed to save JobWork Receive";
//       if (data is Map) {
//         if (data["errors"] is Map) {
//           msg = (data["errors"] as Map)
//               .values
//               .map((v) => v is List ? v.first.toString() : v.toString())
//               .join("\n");
//         } else if (data["message"] != null) {
//           msg = data["message"].toString();
//         }
//       }
//       AppMessage.error(context, msg);
//       return false;
//     } catch (e) {
//       debugPrint("SAVE ERROR => $e");
//       if (mounted) AppMessage.error(context, "Failed to save JobWork Receive");
//       return false;
//     } finally {
//       if (mounted) setState(() => isSaving = false);
//     }
//   }
//
//   /// ============================================================
//   /// DRAFT
//   /// ============================================================
//   void _saveReceiveDraft() {
//     final int id = int.tryParse(voucher["id"]?.toString() ?? "0") ?? 0;
//     if (id == 0) return;
//     _offlineDraft.saveCastingDraft(id, items);
//   }
//
//   /// ============================================================
//   /// TOTAL
//   /// ============================================================
//   String _totalOf(String key) {
//     return items
//         .fold<double>(
//       0,
//           (sum, item) =>
//       sum + (double.tryParse(item[key]?.toString() ?? "0") ?? 0),
//     )
//         .toStringAsFixed(3);
//   }
//
//   Widget _bottomTotalItem(String title, String value) {
//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Text(
//           title,
//           maxLines: 1,
//           overflow: TextOverflow.ellipsis,
//           textAlign: TextAlign.center,
//           style: const TextStyle(
//             fontSize: 10,
//             fontWeight: FontWeight.w600,
//             color: Colors.black54,
//           ),
//         ),
//         const SizedBox(height: 4),
//         Text(
//           value,
//           style: const TextStyle(
//             fontSize: 12,
//             fontWeight: FontWeight.bold,
//             color: Colors.black,
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _bottomDivider() {
//     return Container(width: 1, height: 35, color: Colors.grey.shade300);
//   }
//
//   /// ============================================================
//   /// PDF
//   /// ============================================================
//   Widget pdfBtn(VoidCallback onTap) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(5),
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//         decoration: BoxDecoration(
//           gradient: const LinearGradient(
//             colors: [Color(0xffE57373), Color(0xffD32F2F)],
//           ),
//           borderRadius: BorderRadius.circular(5),
//         ),
//         child: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 16),
//       ),
//     );
//   }
//
//   Future<void> openPdf(int id) async {
//     /// TODO: JobWork Receive નો PDF constant હોય તો અહીં બદલો
//     final response = await ApiHelper().getRequestWithId(
//       ApiConstants.casting_receive_pdf,
//       id,
//       responseType: ResponseType.bytes,
//     );
//
//     if (response != null && response.statusCode == 200) {
//       final Directory dir = await getTemporaryDirectory();
//       final File file = File("${dir.path}/JobWorkReceive_$id.pdf");
//       await file.writeAsBytes(response.data);
//       OpenFile.open(file.path);
//     } else {
//       if (mounted) AppMessage.error(context, "PDF download failed");
//     }
//   }
//
//   /// ============================================================
//   /// BLANK ROW
//   /// ============================================================
//   Map<String, dynamic> _blankRow() {
//     return {
//       "_row_key": "new_${DateTime.now().microsecondsSinceEpoch}_${items.length}",
//       "jobwork_issue_id": null,
//       "jobwork_receive_item_id": null,
//       "_is_existing": false,
//       "item_id": null,
//       "item_name": "",
//       "item": "",
//       "issue_net_wt": "0.000",
//       "outward_carat": "0.000",
//       "gross_weight": "0.000",
//       "other": "0.000",
//       "sale_other": "0.00",
//       "net_weight": "0.000",
//       "fine_weight": "0.000",
//       "qty": "0",
//       "pending_net_wt": "0.000",
//       "remarks": "",
//       "loss_wt": "0.000",
//       "other_charge_details": <Map<String, dynamic>>[],
//     };
//   }
//
//   void _addBlankReceiveRow() {
//     final FocusNode? currentFocus = FocusManager.instance.primaryFocus;
//
//     setState(() => items.add(_blankRow()));
//
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (!mounted) return;
//       if (currentFocus != null && currentFocus.canRequestFocus) {
//         currentFocus.requestFocus();
//       }
//     });
//
//     _saveReceiveDraft();
//   }
//
//   String _voucherValue(String key) {
//     final double value =
//         double.tryParse(voucher[key]?.toString() ?? "0") ?? 0.0;
//     return value.toStringAsFixed(3);
//   }
//
//   /// ============================================================
//   /// PENDING = API pending - (નવી rows નું net + જૂની rows નો ફેરફાર)
//   /// ============================================================
//   String _currentPendingWt() {
//     final double apiPending =
//         double.tryParse(voucher["pending_net_wt_total"]?.toString() ?? "0") ??
//             0.0;
//
//     double adjustment = 0.0;
//
//     for (final item in items) {
//       final double currentNet =
//           double.tryParse(item["net_weight"]?.toString() ?? "0") ?? 0.0;
//
//       if (item["_is_existing"] == true) {
//         final double originalNet = double.tryParse(
//           item["_original_net_weight"]?.toString() ?? "0",
//         ) ??
//             0.0;
//         adjustment += currentNet - originalNet;
//       } else {
//         adjustment += currentNet;
//       }
//     }
//
//     double pending = apiPending - adjustment;
//     if (pending < 0) pending = 0;
//
//     return pending.toStringAsFixed(3);
//   }
// }


//================================================  New Code 1/10/26 =======================================================



import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pecifician_sysytem/Job%20Work/Job%20Work%20Issue/Create_jobWork_Issue.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Api_Constant/ApiConstants.dart';
import '../../Api_Constant/api_helper.dart';
import '../../Extra/AppColors.dart';
import '../../Extra/AppMessage.dart';
import '../../Extra/PermissionDeniedWidget.dart';
import '../../Offline Data/OfflineValueSave.dart';
import '../../Offline Data/offline_api_helper.dart';

class Addjobworkreceivescreen extends StatefulWidget {
  final Map<String, dynamic> voucher;
  final List<Map<String, dynamic>> items;

  const Addjobworkreceivescreen({
    super.key,
    required this.voucher,
    required this.items,
  });

  @override
  State<Addjobworkreceivescreen> createState() =>
      _AddjobworkreceivescreenState();
}

class _AddjobworkreceivescreenState extends State<Addjobworkreceivescreen> {
  /// ============================================================
  /// DATA
  /// ============================================================
  late Map<String, dynamic> voucher;

  List<Map<String, dynamic>> items = [];

  /// Dropdown mate
  List<Map<String, dynamic>> itemOptions = [];

  /// Other charges mate
  List<Map<String, dynamic>> otherCharges = [];

  /// Same worker na vouchers
  List<Map<String, dynamic>> voucherList = [];

  Map<String, dynamic>? selectedVoucher;

  bool isVoucherDropdownOpen = false;
  bool isJobworkInfoExpanded = false;
  bool isSaving = false;

  /// 🔥 Issue screen ખૂલતી હોય ત્યારે બીજી વાર tap ના થાય
  bool _openingIssue = false;

  /// ============================================================
  /// CONTROLLERS
  /// ============================================================
  final TextEditingController voucherSearchController = TextEditingController();

  final Map<String, TextEditingController> jobworkControllers = {};

  /// ============================================================
  /// PERMISSION
  /// ============================================================
  List<String> userPermissions = [];

  final Offlinevaluesave _offlineDraft = Offlinevaluesave();

  /// ============================================================
  /// INIT
  /// ============================================================
  @override
  void initState() {
    super.initState();

    voucher = Map<String, dynamic>.from(widget.voucher);

    Future.microtask(() async {
      await loadPermissions();

      await loadVoucherList(voucher["jobworker_name"]?.toString() ?? "");

      final int voucherId = int.tryParse(voucher["id"]?.toString() ?? "0") ?? 0;

      if (voucherId > 0) {
        await _loadSelectedVoucher(voucherId);
      }
    });
  }

  /// ============================================================
  /// DISPOSE
  /// ============================================================
  @override
  void dispose() {
    voucherSearchController.dispose();

    for (final controller in jobworkControllers.values) {
      controller.dispose();
    }
    jobworkControllers.clear();

    super.dispose();
  }

  /// ============================================================
  /// PERMISSION
  /// ============================================================
  Future<void> loadPermissions() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final List<String> permissions =
        prefs.getStringList("user_permissions") ?? [];

    if (!mounted) return;

    setState(() => userPermissions = permissions);
  }

  bool hasPermission(String permissionName) {
    return userPermissions.contains(permissionName);
  }

  /// ============================================================
  /// BUILD
  /// ============================================================
  @override
  Widget build(BuildContext context) {
    if (!(hasPermission("jobwork-receive-view") ||
        hasPermission("jobwork-receive-manage"))) {
      return Scaffold(
        body: PermissionDeniedWidget(onBack: () => Navigator.pop(context)),
      );
    }

    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, true);
      },
      child: Scaffold(
        backgroundColor: AppColors.white,

        /// ======================================================
        /// BODY
        /// ======================================================
        body: Stack(
          children: [
            SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
              padding: const EdgeInsets.only(bottom: 15),
              child: Column(
                children: [
                  SizedBox(height: MediaQuery.of(context).padding.top + 42),

                  filterWidget(),

                  Container(
                    margin: const EdgeInsets.only(top: 8),
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
                    ),
                  ),

                  const SizedBox(height: 5),

                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(30),
                      child: Text(
                        "No Receive Items Found",
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];

                        return KeyedSubtree(
                          key: ValueKey("receive_row_${_rowKeyOf(item)}"),
                          child: jobworkItemCard(item, index),
                        );
                      },
                    ),

                  const SizedBox(height: 20),
                ],
              ),
            ),

            /// ==================================================
            /// FIXED APPBAR
            /// ==================================================
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
                  bottom: 12,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Text(
                      "Add JobWork Receive",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    /// BACK
                    Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: EdgeInsets.all(isMobile ? 6 : 8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: isMobile ? 20 : 24,
                          ),
                        ),
                      ),
                    ),

                    /// PDF + ADD
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          /// 🔥 ISSUED ITEMS POPUP

                          pdfBtn(() {
                            final int id = int.tryParse(
                              voucher["id"]?.toString() ?? "0",
                            ) ??
                                0;
                            if (id > 0) openPdf(id);
                          }),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: _addBlankReceiveRow,
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
                              child: const Icon(
                                Icons.add_rounded,
                                size: 18,
                                color: AppColors.gradientBlue,
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
          ],
        ),

        /// ======================================================
        /// BOTTOM TOTAL + EXTRA → ISSUE + APPLY
        /// ======================================================
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
            child: Builder(
              builder: (context) {
                final double issueNet =
                    double.tryParse(_voucherValue("issue_net_wt_total")) ??
                        0.0;

                final double receiveNet =
                    double.tryParse(_totalOf("net_weight")) ?? 0.0;

                final double extraWeight =
                receiveNet > issueNet ? receiveNet - issueNet : 0.0;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    /// TOTALS
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 80,
                              child: _bottomTotalItem(
                                "Issue Net",
                                issueNet.toStringAsFixed(3),
                              ),
                            ),
                            _bottomDivider(),
                            SizedBox(
                              width: 80,
                              child: _bottomTotalItem(
                                "Gross Wt",
                                _totalOf("gross_weight"),
                              ),
                            ),
                            _bottomDivider(),
                            SizedBox(
                              width: 80,
                              child: _bottomTotalItem(
                                "Other Wt",
                                _totalOf("other"),
                              ),
                            ),
                            _bottomDivider(),
                            SizedBox(
                              width: 80,
                              child: _bottomTotalItem(
                                "Net Wt",
                                receiveNet.toStringAsFixed(3),
                              ),
                            ),
                            _bottomDivider(),
                            SizedBox(
                              width: 80,
                              child: _bottomTotalItem(
                                "Fine Wt",
                                _totalOf("fine_weight"),
                              ),
                            ),
                            _bottomDivider(),
                            SizedBox(
                              width: 80,
                              child: _bottomTotalItem(
                                "Pending Wt",
                                _currentPendingWt(),
                              ),
                            ),
                            if (extraWeight > 0) ...[
                              _bottomDivider(),
                              SizedBox(
                                width: 80,
                                child: _bottomTotalItem(
                                  "Extra Wt",
                                  extraWeight.toStringAsFixed(3),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    /// 🔥 EXTRA WEIGHT → ADD TO ISSUE
                    if (extraWeight > 0) ...[
                      InkWell(
                        onTap: () => _openIssueForExtra(extraWeight),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.add_circle_outline_rounded,
                                color: Colors.orange,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  "Extra ${extraWeight.toStringAsFixed(3)} g — Add to Issue",
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    /// APPLY BUTTON
                    InkWell(
                      onTap: isSaving
                          ? null
                          : () async {
                        FocusManager.instance.primaryFocus?.unfocus();

                        final int voucherId = int.tryParse(
                          voucher["id"]?.toString() ?? "0",
                        ) ??
                            0;

                        if (voucherId == 0) {
                          AppMessage.error(context, "Invalid voucher.");
                          return;
                        }

                        final bool success =
                        await updateJobworkReceive(voucherId, items);

                        if (!mounted) return;

                        if (success) Navigator.pop(context, true);
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
                          child: isSaving
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
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// ============================================================
  /// ITEM CARD
  /// ============================================================
  Widget jobworkItemCard(Map<String, dynamic> item, int index) {
    final dynamic rawItem = item["item"];

    String itemName = (item["name"] ??
        item["item_name"] ??
        (rawItem is Map ? rawItem["item_name"] : rawItem))
        ?.toString()
        .trim() ??
        "";

    if (itemName.isEmpty || itemName == "null") itemName = "Item";

    final dynamic rawItemset = item["itemset"];

    String qrCode = (item["qr_code"] ??
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

                /// DELETE
                InkWell(
                  onTap: () => _deleteRow(item),
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

          /// FIELDS
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _itemDropdown(item),
                  _miniField("Purity", item, "outward_carat"),
                  _miniField("Gross Wt", item, "gross_weight"),
                  _miniField("Other Wt", item, "other"),
                  _miniField("Net Wt", item, "net_weight"),
                  _miniField("Fine Wt", item, "fine_weight"),
                  _miniField("Qty Pcs", item, "qty"),
                  _miniField("Pending Net Wt", item, "pending_net_wt"),
                  _miniField("Remark", item, "remarks"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ============================================================
  /// DELETE ROW (item reference થી)
  /// ============================================================
  Future<void> _deleteRow(Map<String, dynamic> item) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final int jobworkIssueId = int.tryParse(
      voucher["jobwork_issue_id"]?.toString() ??
          voucher["id"]?.toString() ??
          "0",
    ) ??
        0;

    final int jobworkReceiveItemId = int.tryParse(
      item["jobwork_receive_item_id"]?.toString() ?? "0",
    ) ??
        0;

    void removeLocal() {
      setState(() => items.remove(item));
      _disposeRowControllers(item);
      _saveReceiveDraft();
    }

    /// NEW / LOCAL ROW → API call નહીં
    if (jobworkReceiveItemId == 0) {
      if (!mounted) return;
      removeLocal();
      return;
    }

    if (jobworkIssueId == 0) {
      AppMessage.error(context, "Jobwork Issue ID not found.");
      return;
    }

    try {
      final response = await OfflineApiHelper.instance.deleteRequest(
        "${ApiConstants.jobwork_receive}/$jobworkIssueId/items/$jobworkReceiveItemId",
      );

      debugPrint("DELETE STATUS => ${response?.statusCode}");
      debugPrint("DELETE RESPONSE => ${response?.data}");

      if (!mounted) return;

      if (response?.statusCode == 202) {
        removeLocal();
        AppMessage.success(context, "No Internet. Delete saved offline.");
        return;
      }

      if (response?.statusCode == 200 ||
          response?.statusCode == 201 ||
          response?.statusCode == 204) {
        removeLocal();
        AppMessage.success(context, "Item Deleted Successfully");
        return;
      }

      AppMessage.error(
        context,
        response?.data?["message"]?.toString() ?? "Failed to delete item.",
      );
    } catch (e) {
      debugPrint("❌ DELETE ERROR => $e");
      if (!mounted) return;
      AppMessage.error(context, "Failed to delete item.");
    }
  }

  void _disposeRowControllers(Map<String, dynamic> item) {
    final String prefix = "${_rowKeyOf(item)}_";
    jobworkControllers.removeWhere((k, c) {
      if (k.startsWith(prefix)) {
        c.dispose();
        return true;
      }
      return false;
    });
  }

  /// ============================================================
  /// MINI FIELD
  /// ============================================================
  Widget _miniField(String title, Map<String, dynamic> item, String key) {
    final TextEditingController controller = getController(item, key);

    final bool isOther = key == "other";

    final bool editable = [
      "outward_carat",
      "gross_weight",
      "qty",
      "remarks",
    ].contains(key);

    final bool textKeyboard = key == "remarks";

    final bool needsCalculation =
        key == "gross_weight" || key == "outward_carat";

    return Container(
      width: key == "remarks"
          ? 180
          : key == "pending_net_wt"
          ? 115
          : 100,
      margin: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 3),
          Stack(
            children: [
              SizedBox(
                height: 35,
                child: TextFormField(
                  controller: controller,
                  readOnly: !editable,
                  keyboardType: textKeyboard
                      ? TextInputType.text
                      : const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: editable ? Colors.black : Colors.grey.shade700,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: editable ? Colors.white : Colors.grey.shade100,
                    contentPadding: EdgeInsets.only(
                      left: 6,
                      right: isOther ? 30 : 6,
                      top: 9,
                      bottom: 9,
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
                  onChanged: (value) {
                    item[key] = value;

                    /// Gross બદલાય ત્યારે live Net / Fine
                    if (key == "gross_weight") {
                      final double gross = double.tryParse(value.trim()) ?? 0.0;
                      final double other = double.tryParse(
                        item["other"]?.toString() ?? "0",
                      ) ??
                          0.0;

                      double net = gross - other;
                      if (net < 0) net = 0;

                      final String netValue = net.toStringAsFixed(3);
                      item["net_weight"] = netValue;

                      final netController = getController(item, "net_weight");
                      if (netController.text != netValue) {
                        netController.text = netValue;
                      }

                      final double purity = double.tryParse(
                        item["outward_carat"]?.toString() ?? "0",
                      ) ??
                          0.0;

                      final double fine = net * purity / 100;
                      item["fine_weight"] = fine.toStringAsFixed(3);
                      getController(item, "fine_weight").text =
                          fine.toStringAsFixed(3);

                      if (mounted) setState(() {});
                    }
                  },
                  onFieldSubmitted: (_) {
                    item[key] = controller.text;
                    if (needsCalculation) _calculateJobworkReceiveItem(item);
                    _saveReceiveDraft();
                  },
                  onTapOutside: (_) {
                    item[key] = controller.text;
                    if (needsCalculation) _calculateJobworkReceiveItem(item);
                    _saveReceiveDraft();
                    FocusScope.of(context).unfocus();
                  },
                ),
              ),

              /// OTHER CHARGE +
              if (isOther)
                Positioned(
                  right: 2,
                  top: 6,
                  child: InkWell(
                    onTap: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      showOtherChargesPopup(item);
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.all(4),
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
        ],
      ),
    );
  }

  /// ============================================================
  /// ITEM DROPDOWN (data["item_options"])
  /// ============================================================
  Widget _itemDropdown(Map<String, dynamic> item) {
    final String selectedValue =
        item["item_name"]?.toString() ?? item["item"]?.toString() ?? "";

    final List<String> options = itemOptions
        .map((e) => e["item_name"]?.toString().trim() ?? "")
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

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
          const Text(
            "Item Name",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: DropdownSearch<String>(
              key: ValueKey("item_dd_${_rowKeyOf(item)}"),
              items: options,
              selectedItem: selectedValue.isNotEmpty ? selectedValue : null,
              popupProps: PopupProps.modalBottomSheet(
                showSearchBox: true,
                showSelectedItems: true,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.72,
                ),
                modalBottomSheetProps: ModalBottomSheetProps(
                  isScrollControlled: true,
                  backgroundColor: Colors.white,
                  barrierColor: Colors.black.withOpacity(0.45),
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.vertical(top: Radius.circular(22)),
                  ),
                ),
                containerBuilder: (ctx, popupWidget) {
                  return AnimatedPadding(
                    duration: const Duration(milliseconds: 150),
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(ctx).viewInsets.bottom,
                    ),
                    child: popupWidget,
                  );
                },
                title: Builder(
                  builder: (ctx) => Column(
                    mainAxisSize: MainAxisSize.min,
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
                        padding: const EdgeInsets.fromLTRB(16, 14, 12, 4),
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
                              child: const Icon(
                                Icons.category_outlined,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Select Item",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "${options.length} items available",
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
                    ],
                  ),
                ),
                searchFieldProps: TextFieldProps(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  style: const TextStyle(fontSize: 13.5, color: Colors.black),
                  decoration: InputDecoration(
                    hintText: "Search item...",
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 20,
                      color: AppColors.primaryDark,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                      borderSide: BorderSide(
                        color: AppColors.primaryDark,
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
                listViewProps: const ListViewProps(
                  padding: EdgeInsets.fromLTRB(12, 6, 12, 16),
                ),
                itemBuilder: (context, String itemName, bool isSelected) {
                  final String initial =
                  itemName.isNotEmpty ? itemName[0].toUpperCase() : "?";

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryDark.withOpacity(0.07)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryDark
                            : AppColors.border,
                        width: isSelected ? 1.3 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(colors: [
                              AppColors.primaryDark,
                              AppColors.secondaryDark,
                            ])
                                : null,
                            color: isSelected
                                ? null
                                : AppColors.primaryDark.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            initial,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.primaryDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            itemName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: Colors.black,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          isSelected ? Icons.check_circle : Icons.chevron_right,
                          size: 20,
                          color: isSelected
                              ? AppColors.primaryDark
                              : Colors.grey.shade400,
                        ),
                      ],
                    ),
                  );
                },
                emptyBuilder: (context, searchEntry) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "No item found",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              dropdownDecoratorProps: DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  hintText: "Select Item",
                  hintStyle: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
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
                      width: 1.2,
                    ),
                  ),
                ),
              ),
              dropdownBuilder: (context, selectedItem) {
                return Text(
                  selectedItem ?? "Select Item",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    height: 1.0,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
              onChanged: (value) {
                if (value == null) return;
                FocusManager.instance.primaryFocus?.unfocus();

                final Map<String, dynamic> selectedOption =
                itemOptions.firstWhere(
                      (e) => e["item_name"]?.toString().trim() == value.trim(),
                  orElse: () => <String, dynamic>{},
                );

                if (selectedOption.isEmpty) return;

                final int itemId = int.tryParse(
                  selectedOption["item_id"]?.toString() ??
                      selectedOption["id"]?.toString() ??
                      "0",
                ) ??
                    0;

                final String purity =
                    selectedOption["purity"]?.toString() ?? "0.000";

                final String issueNetWt =
                (selectedOption["issue_net_wt_total"] ??
                    selectedOption["issue_net_wt"] ??
                    "0.000")
                    .toString();

                setState(() {
                  item["item_id"] = itemId;
                  item["item_name"] = value;
                  item["item"] = value;

                  item["issue_net_wt"] = issueNetWt;
                  item["issue_net_wt_total"] = issueNetWt;
                  item["outward_carat"] = purity;

                  updateController(item, "issue_net_wt");
                  updateController(item, "outward_carat");

                  _calculateJobworkReceiveItem(item);
                });

                debugPrint("🔥 ROW ${_rowKeyOf(item)} ITEM => $itemId $value");

                _saveReceiveDraft();
              },
            ),
          ),
        ],
      ),
    );
  }

  /// ============================================================
  /// CALCULATION
  /// Net = Gross - Other
  /// Fine = Net × Purity / 100
  /// Pending = Issue Net - Receive Net
  /// ============================================================
  void _calculateJobworkReceiveItem(Map<String, dynamic> item) {
    final double issueNet =
        double.tryParse(item["issue_net_wt_total"]?.toString() ?? "0") ?? 0.0;
    final double gross =
        double.tryParse(item["gross_weight"]?.toString() ?? "0") ?? 0.0;
    final double other =
        double.tryParse(item["other"]?.toString() ?? "0") ?? 0.0;
    final double purity =
        double.tryParse(item["outward_carat"]?.toString() ?? "0") ?? 0.0;

    double net = gross - other;
    if (net < 0) net = 0;

    final double fine = net * purity / 100;

    double pending = issueNet - net;
    if (pending < 0) pending = 0;

    item["net_weight"] = net.toStringAsFixed(3);
    item["fine_weight"] = fine.toStringAsFixed(3);
    item["pending_net_wt"] = pending.toStringAsFixed(3);

    updateController(item, "net_weight");
    updateController(item, "fine_weight");
    updateController(item, "pending_net_wt");
  }

  /// ============================================================
  /// STABLE ROW KEY + CONTROLLER
  /// ============================================================
  String _rowKeyOf(Map<String, dynamic> item) {
    item["_row_key"] ??=
    "${DateTime.now().microsecondsSinceEpoch}_${identityHashCode(item)}";
    return item["_row_key"].toString();
  }

  TextEditingController getController(Map<String, dynamic> item, String key) {
    final String controllerKey = "${_rowKeyOf(item)}_$key";

    return jobworkControllers.putIfAbsent(
      controllerKey,
          () => TextEditingController(text: item[key]?.toString() ?? ""),
    );
  }

  void updateController(Map<String, dynamic> item, String key) {
    final TextEditingController controller = getController(item, key);
    final String value = item[key]?.toString() ?? "";

    if (controller.text != value) {
      controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  /// ============================================================
  /// OTHER CHARGE POPUP (એક જ select)
  /// ============================================================
  void showOtherChargesPopup(Map<String, dynamic> mainItem) {
    final List existingDetails = mainItem["other_charge_details"] is List
        ? mainItem["other_charge_details"]
        : [];

    final int existingChargeId = existingDetails.isNotEmpty
        ? int.tryParse(
      existingDetails.first["charge_id"]?.toString() ?? "0",
    ) ??
        0
        : 0;

    final List<Map<String, dynamic>> charges = otherCharges.map((e) {
      final int id = int.tryParse(e["id"]?.toString() ?? "0") ?? 0;

      Map<String, dynamic>? saved;

      for (final detail in existingDetails) {
        if (detail is Map &&
            int.tryParse(detail["charge_id"]?.toString() ?? "0") == id) {
          saved = Map<String, dynamic>.from(detail);
          break;
        }
      }

      final String wtFormula = _normalizeFormula(
        saved?["wt_formula"]?.toString() ??
            e["weight_formula"]?.toString() ??
            "flat",
      );

      final String amtFormula = _normalizeFormula(
        saved?["amt_formula"]?.toString() ??
            e["other_amt_formula"]?.toString() ??
            "flat",
      );

      return {
        "id": id,
        "charge": e["name"]?.toString() ?? "",
        "amount": saved?["amount"]?.toString() ??
            e["default_amount"]?.toString() ??
            "0",
        "qty":
        saved?["qty"]?.toString() ?? e["quantity_pcs"]?.toString() ?? "1",
        "weight": saved?["weight"]?.toString() ??
            e["default_weight"]?.toString() ??
            "0",
        "wt_formula": wtFormula,
        "amt_formula_type": amtFormula,
        "wt_operation": saved?["wt_operation"]?.toString() ??
            e["wt_operation"]?.toString() ??
            "less",
        "total_weight": "0.000",
        "total_amt": "0.00",
        "is_selected": existingChargeId == id,
      };
    }).toList();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xffF5F8FC),
          elevation: 12,
          shadowColor: const Color(0xff0B2A4A).withOpacity(0.30),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 20,
          ),
          child: StatefulBuilder(
            builder: (context, setStateDialog) {
              const Color primaryBlue = Color(0xff1565C0);
              const Color darkBlue = Color(0xff0D47A1);
              const Color lightBlue = Color(0xffEAF3FF);
              const Color borderBlue = Color(0xffB8D4F5);
              const Color textDark = Color(0xff17324D);

              void calculateCharges() {
                for (final c in charges) {
                  final double amount =
                      double.tryParse(c["amount"]?.toString() ?? "0") ?? 0;
                  final double qty =
                      double.tryParse(c["qty"]?.toString() ?? "1") ?? 1;
                  final double weight =
                      double.tryParse(c["weight"]?.toString() ?? "0") ?? 0;

                  final String wtFormula =
                      c["wt_formula"]?.toString() ?? "flat";
                  final String amtFormula =
                      c["amt_formula_type"]?.toString() ?? "flat";

                  double totalWeight = weight;
                  if (wtFormula == "per_qty" || wtFormula == "per_weight") {
                    totalWeight = weight * qty;
                  }

                  double totalAmount = amount;
                  switch (amtFormula) {
                    case "per_qty":
                      totalAmount = amount * qty;
                      break;
                    case "per_weight":
                      totalAmount = amount * totalWeight;
                      break;
                    case "per_qty_weight":
                      totalAmount = amount * qty * weight;
                      break;
                  }

                  c["total_weight"] = totalWeight.toStringAsFixed(3);
                  c["total_amt"] = totalAmount.toStringAsFixed(2);
                }
              }

              calculateCharges();

              Map<String, dynamic>? selectedCharge;
              for (final c in charges) {
                if (c["is_selected"] == true) {
                  selectedCharge = c;
                  break;
                }
              }

              final double total = selectedCharge == null
                  ? 0
                  : double.tryParse(
                selectedCharge["total_amt"]?.toString() ?? "0",
              ) ??
                  0;

              InputDecoration fieldDecoration({double vPad = 9}) {
                return InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: vPad,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: const BorderSide(color: borderBlue),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: const BorderSide(color: borderBlue),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: const BorderSide(
                      color: primaryBlue,
                      width: 1.5,
                    ),
                  ),
                );
              }

              Widget headerCell(String title, double width) {
                return SizedBox(
                  width: width,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              }

              Widget numField(
                  Map<String, dynamic> c,
                  String key,
                  double width, {
                    bool decimal = true,
                  }) {
                return SizedBox(
                  width: width,
                  child: TextFormField(
                    initialValue: c[key]?.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textDark,
                    ),
                    keyboardType: decimal
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.number,
                    onChanged: (v) {
                      c[key] = v;
                      setStateDialog(() {});
                    },
                    decoration: fieldDecoration(),
                  ),
                );
              }

              Widget formulaDropdown(
                  Map<String, dynamic> c,
                  String key,
                  List<DropdownMenuItem<String>> options,
                  ) {
                return SizedBox(
                  width: 105,
                  child: DropdownButtonFormField<String>(
                    value: c[key],
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    style: const TextStyle(
                      fontSize: 11,
                      color: textDark,
                      fontWeight: FontWeight.w600,
                    ),
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: primaryBlue,
                    ),
                    decoration: fieldDecoration(vPad: 8),
                    items: options,
                    onChanged: (v) {
                      if (v == null) return;
                      c[key] = v;
                      setStateDialog(() {});
                    },
                  ),
                );
              }

              return Container(
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(maxHeight: 600),
                decoration: BoxDecoration(
                  color: const Color(0xffF5F8FC),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    /// TOP HEADER
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xff0D47A1), Color(0xff1976D2)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xff1565C0).withOpacity(0.22),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              color: Colors.white,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 11),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Other Charges",
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "Select and calculate additional charges",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xffDCEBFF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 21,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    /// TABLE
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: borderBlue),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: 820,
                              child: Column(
                                children: [
                                  Container(
                                    padding:
                                    const EdgeInsets.symmetric(vertical: 5),
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xff0D47A1),
                                          Color(0xff1976D2),
                                        ],
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        headerCell("Charge", 120),
                                        headerCell("Amount", 90),
                                        headerCell("Qty", 70),
                                        headerCell("Weight", 90),
                                        headerCell("Wt Formula", 110),
                                        headerCell("Total Wt", 110),
                                        headerCell("Amt Formula", 110),
                                        headerCell("Select", 80),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Expanded(
                                    child: ListView.builder(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                      ),
                                      itemCount: charges.length,
                                      itemBuilder: (context, index) {
                                        final c = charges[index];
                                        final bool selected =
                                            c["is_selected"] == true;

                                        return AnimatedContainer(
                                          duration:
                                          const Duration(milliseconds: 150),
                                          margin:
                                          const EdgeInsets.only(bottom: 6),
                                          decoration: BoxDecoration(
                                            color: selected
                                                ? lightBlue
                                                : Colors.white,
                                            borderRadius:
                                            BorderRadius.circular(8),
                                            border: Border.all(
                                              color: selected
                                                  ? primaryBlue
                                                  : const Color(0xffE2EAF3),
                                              width: selected ? 1.2 : 1,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 120,
                                                child: Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(horizontal: 7),
                                                  child: Text(
                                                    c["charge"]?.toString() ??
                                                        "",
                                                    maxLines: 2,
                                                    overflow:
                                                    TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: textDark,
                                                      fontWeight: selected
                                                          ? FontWeight.w800
                                                          : FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              numField(c, "amount", 90),
                                              const SizedBox(width: 5),
                                              numField(c, "qty", 65,
                                                  decimal: false),
                                              const SizedBox(width: 5),
                                              numField(c, "weight", 85),
                                              const SizedBox(width: 5),
                                              formulaDropdown(
                                                c,
                                                "wt_formula",
                                                const [
                                                  DropdownMenuItem(
                                                    value: "flat",
                                                    child: Text("Flat"),
                                                  ),
                                                  DropdownMenuItem(
                                                    value: "per_qty",
                                                    child: Text("Per Qty"),
                                                  ),
                                                  DropdownMenuItem(
                                                    value: "per_weight",
                                                    child: Text("Per Wt"),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(
                                                width: 110,
                                                child: Container(
                                                  margin: const EdgeInsets
                                                      .symmetric(horizontal: 4),
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 10),
                                                  decoration: BoxDecoration(
                                                    color:
                                                    const Color(0xffF1F7FF),
                                                    borderRadius:
                                                    BorderRadius.circular(
                                                        7),
                                                    border: Border.all(
                                                      color: const Color(
                                                          0xffD3E5FA),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    c["total_weight"]
                                                        ?.toString() ??
                                                        "0.000",
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: darkBlue,
                                                      fontWeight:
                                                      FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              formulaDropdown(
                                                c,
                                                "amt_formula_type",
                                                const [
                                                  DropdownMenuItem(
                                                    value: "flat",
                                                    child: Text("Flat"),
                                                  ),
                                                  DropdownMenuItem(
                                                    value: "per_qty",
                                                    child: Text("Per Qty"),
                                                  ),
                                                  DropdownMenuItem(
                                                    value: "per_weight",
                                                    child: Text("Per Wt"),
                                                  ),
                                                  DropdownMenuItem(
                                                    value: "per_qty_weight",
                                                    child: Text("Qty × Wt"),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(
                                                width: 80,
                                                child: Center(
                                                  child: Checkbox(
                                                    value: selected,
                                                    activeColor: primaryBlue,
                                                    checkColor: Colors.white,
                                                    shape:
                                                    RoundedRectangleBorder(
                                                      borderRadius:
                                                      BorderRadius.circular(
                                                          4),
                                                    ),
                                                    onChanged: (value) {
                                                      setStateDialog(() {
                                                        for (final charge
                                                        in charges) {
                                                          charge["is_selected"] =
                                                          false;
                                                        }
                                                        if (value == true) {
                                                          c["is_selected"] =
                                                          true;
                                                        }
                                                      });
                                                    },
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
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    /// SELECTED AMOUNT
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xffEAF3FF), Color(0xffDDEEFF)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderBlue),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: primaryBlue,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Icon(
                              Icons.calculate_rounded,
                              size: 17,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              "Selected Amount",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: textDark,
                              ),
                            ),
                          ),
                          Text(
                            total.toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: darkBlue,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 11),

                    /// APPLY CHARGE
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        Map<String, dynamic>? selected;
                        for (final c in charges) {
                          if (c["is_selected"] == true) {
                            selected = c;
                            break;
                          }
                        }

                        if (selected == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: darkBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              content: const Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text("Please select charge"),
                                ],
                              ),
                            ),
                          );
                          return;
                        }

                        calculateCharges();

                        final double selectedWeight = double.tryParse(
                          selected["total_weight"]?.toString() ?? "0",
                        ) ??
                            0;

                        final double selectedAmount = double.tryParse(
                          selected["total_amt"]?.toString() ?? "0",
                        ) ??
                            0;

                        mainItem["other"] = selectedWeight.toStringAsFixed(3);
                        mainItem["sale_other"] =
                            selectedAmount.toStringAsFixed(2);

                        mainItem["other_charge_details"] = [
                          {
                            "charge_id": selected["id"],
                            "charge_name": selected["charge"],
                            "amount": double.tryParse(
                              selected["amount"]?.toString() ?? "0",
                            ) ??
                                0,
                            "qty": int.tryParse(
                              selected["qty"]?.toString() ?? "1",
                            ) ??
                                1,
                            "wt_formula": selected["wt_formula"],
                            "amt_formula": selected["amt_formula_type"],
                            "weight": selectedWeight,
                            "total": selectedAmount,
                            "wt_operation": selected["wt_operation"],
                          },
                        ];

                        updateController(mainItem, "other");
                        _calculateJobworkReceiveItem(mainItem);
                        _saveReceiveDraft();

                        Navigator.pop(dialogContext);
                        setState(() {});
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xff0D47A1),
                              Color(0xff1976D2),
                              Color(0xff2196F3),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xff1565C0).withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 19,
                              color: Colors.white,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "Apply Charge",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _normalizeFormula(String value) {
    switch (value.trim().toLowerCase()) {
      case "per_quantity":
      case "per qty":
      case "per_qty":
        return "per_qty";
      case "per_weight":
      case "per wt":
      case "per_weight_value":
        return "per_weight";
      case "per_qty_weight":
      case "qty × wt":
        return "per_qty_weight";
      default:
        return "flat";
    }
  }

  /// ============================================================
  /// 🔥 ISSUED ITEMS POPUP
  /// Issue માં શું ગયું હતું એ બતાવે; "Receive" દબાવો એટલે
  /// pending weight સાથે receive row આપોઆપ ભરાઈ જાય.
  /// ============================================================
  bool _loadingIssue = false;

  int _issueIdOfVoucher() {
    return int.tryParse(
      voucher["jobwork_issue_id"]?.toString() ??
          voucher["id"]?.toString() ??
          "0",
    ) ??
        0;
  }

  double _num(dynamic v) => double.tryParse(v?.toString() ?? "0") ?? 0.0;

  /// Issue rows + દરેક row નું received / pending (screen ની rows પ્રમાણે)
  List<Map<String, dynamic>> _issueRowsWithPending(
      List<Map<String, dynamic>> issueRows,
      ) {
    /// Screen પર દરેક item નું કુલ received net
    final Map<int, double> receivedByItem = {};

    for (final r in items) {
      final int itemId = int.tryParse(r["item_id"]?.toString() ?? "0") ?? 0;
      if (itemId == 0) continue;
      receivedByItem[itemId] =
          (receivedByItem[itemId] ?? 0) + _num(r["net_weight"]);
    }

    /// એક જ item ની બે issue rows હોય તો received ક્રમમાં વહેંચો
    return issueRows.map((row) {
      final int itemId = int.tryParse(row["item_id"]?.toString() ?? "0") ?? 0;
      final double net = _num(row["net_wt"]);

      final double available = receivedByItem[itemId] ?? 0;
      final double used = available >= net ? net : available;

      receivedByItem[itemId] = available - used;

      return {
        ...row,
        "_received": used,
        "_pending": (net - used) < 0.0005 ? 0.0 : net - used,
      };
    }).toList();
  }

  Future<void> _showIssuedItemsPopup() async {
    if (_loadingIssue) return;

    final int issueId = _issueIdOfVoucher();

    if (issueId == 0) {
      AppMessage.error(context, "Jobwork Issue ID not found.");
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    _loadingIssue = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    List<Map<String, dynamic>> issueRows = [];
    String issueVoucherNo = "";
    bool ok = false;

    try {
      final response = await ApiHelper().getRequestWithId(
        ApiConstants.Update_jobwork_issues,
        issueId,
      );

      debugPrint("ISSUE DETAIL (popup) => ${response?.data}");

      if (response != null &&
          response.statusCode == 200 &&
          response.data is Map &&
          response.data["data"] is Map) {
        final Map data = response.data["data"];

        issueVoucherNo = data["voucher_no"]?.toString() ?? "";

        if (data["items"] is List) {
          for (final raw in data["items"]) {
            if (raw is! Map) continue;

            final Map<String, dynamic> e = Map<String, dynamic>.from(raw);

            final String name = (e["item"] is Map
                ? e["item"]["item_name"]
                : e["item_name"])
                ?.toString() ??
                "-";

            issueRows.add({
              "item_id": e["item_id"],
              "item_name": name,
              "purity": e["purity"]?.toString() ?? "0",
              "gross_wt": e["gross_wt"]?.toString() ?? "0",
              "other_wt": e["other_wt"]?.toString() ?? "0",
              "net_wt": e["net_wt"]?.toString() ?? "0",
              "fine_wt": e["fine_wt"]?.toString() ?? "0",
              "qty_pcs": e["qty_pcs"]?.toString() ?? "0",
            });
          }
        }

        ok = true;
      }
    } catch (e) {
      debugPrint("❌ Issue popup error => $e");
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _loadingIssue = false;
    }

    if (!mounted) return;

    if (!ok) {
      AppMessage.error(context, "Unable to load issued items");
      return;
    }

    if (issueRows.isEmpty) {
      AppMessage.error(context, "No issued items found");
      return;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final rows = _issueRowsWithPending(issueRows);

            final double totalIssue =
            rows.fold(0.0, (sum, r) => sum + _num(r["net_wt"]));
            final double totalReceived =
            rows.fold(0.0, (sum, r) => sum + (r["_received"] as double));
            final double totalPending =
            rows.fold(0.0, (sum, r) => sum + (r["_pending"] as double));

            final Size size = MediaQuery.of(context).size;

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 24,
              ),
              backgroundColor: Colors.transparent,
              child: Container(
                width: size.width > 600 ? 560 : double.infinity,
                constraints: BoxConstraints(maxHeight: size.height * 0.85),
                decoration: BoxDecoration(
                  color: const Color(0xffF5F8FC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /// HEADER
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryDark,
                              AppColors.gradientBlue,
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Icon(
                                Icons.outbox_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Issued Items",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    issueVoucherNo.isNotEmpty
                                        ? "Voucher: $issueVoucherNo"
                                        : "Tap Receive to fill a receive row",
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                      /// LIST
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                          itemCount: rows.length,
                          itemBuilder: (context, index) {
                            final r = rows[index];
                            final double pending = r["_pending"] as double;
                            final bool done = pending <= 0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: done
                                      ? Colors.green.withOpacity(0.45)
                                      : AppColors.border,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  /// NAME + PURITY + BUTTON
                                  Row(
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
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
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              r["item_name"].toString(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            Text(
                                              "Purity ${r["purity"]}",
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      done
                                          ? Container(
                                        padding:
                                        const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green
                                              .withOpacity(0.10),
                                          borderRadius:
                                          BorderRadius.circular(7),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_circle_rounded,
                                              size: 15,
                                              color: Colors.green,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              "Received",
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: Colors.green,
                                                fontWeight:
                                                FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                          : InkWell(
                                        onTap: () {
                                          _receiveFromIssue(r, pending);
                                          setStateDialog(() {});
                                        },
                                        borderRadius:
                                        BorderRadius.circular(7),
                                        child: Container(
                                          padding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 7,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient:
                                            const LinearGradient(
                                              colors: [
                                                AppColors.primaryDark,
                                                AppColors.gradientBlue,
                                              ],
                                            ),
                                            borderRadius:
                                            BorderRadius.circular(7),
                                          ),
                                          child: const Row(
                                            mainAxisSize:
                                            MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons
                                                    .move_to_inbox_rounded,
                                                size: 15,
                                                color: Colors.white,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                "Receive",
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  color: Colors.white,
                                                  fontWeight:
                                                  FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 8),

                                  /// WEIGHTS
                                  Container(
                                    padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xffF7F9FC),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: Row(
                                      children: [
                                        _issueStat("Gross", r["gross_wt"]),
                                        _issueStat("Other", r["other_wt"]),
                                        _issueStat("Net", r["net_wt"]),
                                        _issueStat("Qty", r["qty_pcs"],
                                            decimals: 0),
                                        _issueStat(
                                          "Received",
                                          r["_received"],
                                          color: Colors.green.shade700,
                                        ),
                                        _issueStat(
                                          "Pending",
                                          pending,
                                          color: done
                                              ? Colors.green.shade700
                                              : Colors.red.shade600,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      /// FOOTER
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                _issueStat("Issue Net", totalIssue),
                                _issueStat(
                                  "Received",
                                  totalReceived,
                                  color: Colors.green.shade700,
                                ),
                                _issueStat(
                                  "Pending",
                                  totalPending,
                                  color: totalPending > 0
                                      ? Colors.red.shade600
                                      : Colors.green.shade700,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 42,
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                            color: AppColors.border),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: const Text(
                                        "Close",
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w700,
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
                                        onTap: totalPending <= 0
                                            ? null
                                            : () {
                                          for (final r in rows) {
                                            final double p =
                                            r["_pending"] as double;
                                            if (p > 0) {
                                              _receiveFromIssue(r, p);
                                            }
                                          }
                                          Navigator.pop(dialogContext);
                                          AppMessage.success(
                                            this.context,
                                            "Pending items added. Check weights and tap Apply.",
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Ink(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: totalPending <= 0
                                                  ? [
                                                Colors.grey.shade400,
                                                Colors.grey.shade400,
                                              ]
                                                  : const [
                                                AppColors.primaryDark,
                                                AppColors.gradientBlue,
                                              ],
                                            ),
                                            borderRadius:
                                            BorderRadius.circular(8),
                                          ),
                                          child: const Row(
                                            mainAxisAlignment:
                                            MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.done_all_rounded,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                              SizedBox(width: 6),
                                              Text(
                                                "Receive All Pending",
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
                                    ),
                                  ),
                                ),
                              ],
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
      },
    );
  }

  /// Popup ની અંદર એક નાનું label + value
  Widget _issueStat(
      String title,
      dynamic value, {
        int decimals = 3,
        Color? color,
      }) {
    final double v = _num(value);

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            v.toStringAsFixed(decimals),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color: color ?? Colors.black87,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  /// ============================================================
  /// 🔥 ISSUE ROW → RECEIVE ROW
  /// Pending net જેટલું gross ભરે; ખાલી row હોય તો એ જ વાપરે
  /// ============================================================
  void _receiveFromIssue(Map<String, dynamic> issueRow, double pendingNet) {
    final int itemId =
        int.tryParse(issueRow["item_id"]?.toString() ?? "0") ?? 0;

    if (itemId == 0 || pendingNet <= 0) return;

    /// આખા item નું issue net (item_options માંથી), ના મળે તો આ row નું
    String issueNetTotal = issueRow["net_wt"]?.toString() ?? "0.000";

    for (final op in itemOptions) {
      final int opId = int.tryParse(
        op["item_id"]?.toString() ?? op["id"]?.toString() ?? "0",
      ) ??
          0;

      if (opId == itemId) {
        issueNetTotal = (op["issue_net_wt_total"] ??
            op["issue_net_wt"] ??
            issueNetTotal)
            .toString();
        break;
      }
    }

    /// ખાલી row (item વગરની અને weight વગરની) હોય તો એ ભરો
    Map<String, dynamic>? target;

    for (final r in items) {
      final int rid = int.tryParse(r["item_id"]?.toString() ?? "0") ?? 0;
      if (rid == 0 && _num(r["gross_weight"]) <= 0) {
        target = r;
        break;
      }
    }

    final bool isNew = target == null;
    final Map<String, dynamic> row = target ?? _blankRow();

    final String name = issueRow["item_name"]?.toString() ?? "";

    row["item_id"] = itemId;
    row["item_name"] = name;
    row["item"] = name;
    row["outward_carat"] = issueRow["purity"]?.toString() ?? "0.000";
    row["issue_net_wt"] = issueNetTotal;
    row["issue_net_wt_total"] = issueNetTotal;
    row["gross_weight"] = pendingNet.toStringAsFixed(3);
    row["other"] = "0.000";
    row["qty"] = issueRow["qty_pcs"]?.toString() ?? "0";

    _calculateJobworkReceiveItem(row);

    for (final key in [
      "outward_carat",
      "gross_weight",
      "other",
      "qty",
      "issue_net_wt",
    ]) {
      updateController(row, key);
    }

    setState(() {
      if (isNew) items.add(row);
    });

    _saveReceiveDraft();

    debugPrint("📥 RECEIVE FROM ISSUE => $name | $pendingNet");
  }

  /// ============================================================
  /// 🔥 EXTRA WEIGHT → ISSUE SCREEN
  /// Issue edit ખોલો, ત્યાં નવી row ઉમેરીને Update કરો,
  /// પાછા આવીએ ત્યારે receive rows રાખીને issue ના આંકડા refresh.
  /// ============================================================
  Future<void> _openIssueForExtra(double extraWeight) async {
    if (_openingIssue) return;

    final int issueId = int.tryParse(
      voucher["jobwork_issue_id"]?.toString() ??
          voucher["id"]?.toString() ??
          "0",
    ) ??
        0;

    if (issueId == 0) {
      AppMessage.error(context, "Jobwork Issue ID not found.");
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    /// Receive માં ભરેલું ગુમાય નહીં
    _saveReceiveDraft();

    _openingIssue = true;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateJobworkIssue(
          userData: {"id": issueId},
          extraWeight: extraWeight,
        ),
      ),
    );

    _openingIssue = false;

    if (!mounted || result != true) return;

    final int voucherId = int.tryParse(voucher["id"]?.toString() ?? "0") ?? 0;

    if (voucherId > 0) {
      await _refreshVoucherKeepRows(voucherId);
    }

    if (!mounted) return;

    AppMessage.success(
      context,
      "Issue updated. Please check weights and tap Apply.",
    );
  }

  /// ============================================================
  /// 🔥 VOUCHER REFRESH — receive rows એમ જ રાખો
  /// ફક્ત voucher totals, item options (issue wt) અને
  /// other charges નવા લાવો.
  /// ============================================================
  Future<void> _refreshVoucherKeepRows(int id) async {
    try {
      final response = await ApiHelper().getRequestWithId(
        ApiConstants.jobwork_receive,
        id,
      );

      if (response == null ||
          response.statusCode != 200 ||
          response.data["success"] != true) {
        if (mounted) AppMessage.error(context, "Unable to refresh voucher");
        return;
      }

      final Map<String, dynamic> data =
      Map<String, dynamic>.from(response.data["data"]);

      final List<Map<String, dynamic>> newItemOptions = [];
      if (data["item_options"] is List) {
        for (final raw in data["item_options"]) {
          if (raw is Map) newItemOptions.add(Map<String, dynamic>.from(raw));
        }
      }

      final List<Map<String, dynamic>> newOtherCharges = [];
      if (data["other_charges"] is List) {
        for (final raw in data["other_charges"]) {
          if (raw is Map) newOtherCharges.add(Map<String, dynamic>.from(raw));
        }
      }

      if (!mounted) return;

      setState(() {
        voucher = data;
        itemOptions = newItemOptions;
        otherCharges = newOtherCharges;

        /// દરેક row માટે issue weight નવું (દા.ત. હવે Dokiya issue માં છે)
        for (final item in items) {
          final int itemId =
              int.tryParse(item["item_id"]?.toString() ?? "0") ?? 0;

          if (itemId == 0) continue;

          Map<String, dynamic> option = {};

          for (final op in newItemOptions) {
            final int opId = int.tryParse(
              op["item_id"]?.toString() ?? op["id"]?.toString() ?? "0",
            ) ??
                0;

            if (opId == itemId) {
              option = op;
              break;
            }
          }

          if (option.isEmpty) continue;

          final String issueNet = (option["issue_net_wt_total"] ??
              option["issue_net_wt"] ??
              item["issue_net_wt"] ??
              "0.000")
              .toString();

          item["issue_net_wt"] = issueNet;
          item["issue_net_wt_total"] = issueNet;

          /// Purity ખાલી / 0 હોય તો issue માંથી
          final double purity =
              double.tryParse(item["outward_carat"]?.toString() ?? "0") ?? 0;

          if (purity <= 0 && option["purity"] != null) {
            item["outward_carat"] = option["purity"].toString();
            updateController(item, "outward_carat");
          }

          updateController(item, "issue_net_wt");

          _calculateJobworkReceiveItem(item);
        }
      });

      _saveReceiveDraft();

      debugPrint("🔄 VOUCHER REFRESHED (rows kept) => ${items.length}");
    } catch (e) {
      debugPrint("❌ Voucher refresh error => $e");
      if (mounted) AppMessage.error(context, "Unable to refresh voucher");
    }
  }

  /// ============================================================
  /// LOAD DETAIL
  /// data["items"]         → screen list
  /// data["item_options"]  → dropdown
  /// data["other_charges"] → popup
  /// ============================================================
  Future<void> _loadSelectedVoucher(int id) async {
    try {
      final response = await ApiHelper().getRequestWithId(
        ApiConstants.jobwork_receive,
        id,
      );

      debugPrint("JOBWORK RECEIVE DETAIL RESPONSE => ${response?.data}");

      if (response == null ||
          response.statusCode != 200 ||
          response.data["success"] != true) {
        debugPrint("❌ JobWork Receive Detail API Failed");
        return;
      }

      final Map<String, dynamic> data =
      Map<String, dynamic>.from(response.data["data"]);

      /// ITEM OPTIONS
      final List<Map<String, dynamic>> newItemOptions = [];
      if (data["item_options"] is List) {
        for (final raw in data["item_options"]) {
          if (raw is Map) newItemOptions.add(Map<String, dynamic>.from(raw));
        }
      }

      /// OTHER CHARGES
      final List<Map<String, dynamic>> newOtherCharges = [];
      if (data["other_charges"] is List) {
        for (final raw in data["other_charges"]) {
          if (raw is Map) newOtherCharges.add(Map<String, dynamic>.from(raw));
        }
      }

      /// RECEIVE ITEMS
      final List<Map<String, dynamic>> newItems = [];
      final dynamic rawItems = data["items"];

      if (rawItems is List && rawItems.isNotEmpty) {
        for (final raw in rawItems) {
          if (raw is! Map) continue;

          final Map<String, dynamic> received = Map<String, dynamic>.from(raw);

          final int itemId =
              int.tryParse(received["item_id"]?.toString() ?? "0") ?? 0;

          Map<String, dynamic> option = {};
          for (final op in newItemOptions) {
            final int optionItemId = int.tryParse(
              op["item_id"]?.toString() ?? op["id"]?.toString() ?? "0",
            ) ??
                0;
            if (optionItemId == itemId) {
              option = op;
              break;
            }
          }

          final String issueNetWt = option["issue_net_wt_total"]?.toString() ??
              received["issue_net_wt_total"]?.toString() ??
              "0.000";

          final String purity = option["purity"]?.toString() ??
              received["purity"]?.toString() ??
              received["outward_carat"]?.toString() ??
              "0.000";

          final double receiveNet =
              double.tryParse(received["receive_net_wt"]?.toString() ?? "0") ??
                  0.0;

          double pending = (double.tryParse(issueNetWt) ?? 0.0) - receiveNet;
          if (pending < 0) pending = 0;

          final String itemName = received["item_name"]?.toString() ??
              option["item_name"]?.toString() ??
              "";

          newItems.add({
            "_row_key":
            "existing_${itemId}_${DateTime.now().microsecondsSinceEpoch}_${newItems.length}",

            /// DELETE / UPDATE IDS
            "jobwork_issue_id":
            int.tryParse(data["jobwork_issue_id"]?.toString() ?? "0") ?? 0,
            "jobwork_receive_item_id": int.tryParse(
              received["jobwork_receive_item_id"]?.toString() ??
                  received["id"]?.toString() ??
                  "0",
            ) ??
                0,

            "_is_existing": true,
            "_original_net_weight": received["receive_net_wt"]?.toString() ??
                received["net_weight"]?.toString() ??
                "0.000",

            "item_id": itemId,
            "item_name": itemName,
            "item": itemName,

            "issue_net_wt": issueNetWt,

            /// 🔥 FIX: row નું pending આ key પરથી ગણાય છે
            "issue_net_wt_total": issueNetWt,

            "outward_carat": purity,

            "gross_weight": received["receive_gross_wt"]?.toString() ??
                received["gross_weight"]?.toString() ??
                "0.000",
            "other": received["other_wt"]?.toString() ??
                received["other"]?.toString() ??
                "0.000",
            "sale_other": received["other_amt"]?.toString() ??
                received["sale_other"]?.toString() ??
                "0.00",
            "net_weight": received["receive_net_wt"]?.toString() ??
                received["net_weight"]?.toString() ??
                "0.000",
            "fine_weight": received["receive_fine_wt"]?.toString() ??
                received["fine_weight"]?.toString() ??
                "0.000",
            "qty": received["receive_qty_pcs"]?.toString() ??
                received["qty"]?.toString() ??
                "0",

            "pending_net_wt": pending.toStringAsFixed(3),
            "remarks": received["remarks"]?.toString() ?? "",
            "loss_wt": received["loss_wt"]?.toString() ?? "0.000",
            "other_charge_details": received["other_charge_details"] is List
                ? List.from(received["other_charge_details"])
                : [],
          });
        }
      }

      /// પહેલી વખત receive → એક blank row
      if (newItems.isEmpty) {
        newItems.add(_blankRow());
      }

      /// OLD CONTROLLERS CLEAR
      for (final controller in jobworkControllers.values) {
        controller.dispose();
      }
      jobworkControllers.clear();

      if (!mounted) return;

      setState(() {
        voucher = data;
        itemOptions = newItemOptions;
        otherCharges = newOtherCharges;
        items = newItems;
        voucherSearchController.text = voucher["voucher_no"]?.toString() ?? "";
      });

      debugPrint("🔥 ITEM OPTIONS => ${itemOptions.length}");
      debugPrint("🔥 OTHER CHARGES => ${otherCharges.length}");
      debugPrint("🔥 DISPLAY ITEMS => ${items.length}");
    } catch (e, stackTrace) {
      debugPrint("❌ Jobwork Detail Error => $e");
      debugPrint("❌ STACK => $stackTrace");
    }
  }

  /// ============================================================
  /// LOAD VOUCHER LIST BY SAME WORKER
  /// ============================================================
  Future<void> loadVoucherList(String workerName) async {
    try {
      final response = await ApiHelper().getRequest(
        ApiConstants.jobwork_receive,
        showLoading: false,
      );

      if (response?.statusCode != 200 || response?.data["success"] != true) {
        if (!mounted) return;
        setState(() => voucherList = []);
        return;
      }

      final List data = response?.data["data"] ?? [];
      final String selectedWorker = workerName.trim().toLowerCase();

      final List<Map<String, dynamic>> filtered = data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((element) =>
      (element["jobworker_name"]?.toString().trim().toLowerCase() ??
          "") ==
          selectedWorker)
          .toList();

      if (!mounted) return;

      setState(() {
        voucherList = filtered;
        voucherSearchController.text = voucher["voucher_no"]?.toString() ?? "";
      });
    } catch (e) {
      debugPrint("Voucher List Error => $e");
    }
  }

  /// ============================================================
  /// SEARCHABLE VOUCHER
  /// ============================================================
  Widget _searchableVoucherDropdown() {
    final String search = voucherSearchController.text.trim().toLowerCase();

    final List<Map<String, dynamic>> filteredList = voucherList
        .where((element) =>
        (element["voucher_no"]?.toString().toLowerCase() ?? "")
            .contains(search))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Voucher",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: voucherSearchController,
          readOnly: true,
          style: const TextStyle(fontSize: 12, color: Colors.black),
          onTap: () {
            setState(() => isVoucherDropdownOpen = !isVoucherDropdownOpen);
          },
          decoration: InputDecoration(
            hintText: "Select Voucher",
            prefixIcon: const Icon(Icons.receipt_long, size: 18),
            suffixIcon: Icon(
              isVoucherDropdownOpen
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
            ),
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
          ),
        ),
        if (isVoucherDropdownOpen)
          Container(
            margin: const EdgeInsets.only(top: 3),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: AppColors.border),
            ),
            child: filteredList.isEmpty
                ? const Padding(
              padding: EdgeInsets.all(15),
              child: Center(child: Text("No Voucher Found")),
            )
                : ListView.separated(
              shrinkWrap: true,
              itemCount: filteredList.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = filteredList[index];

                return ListTile(
                  dense: true,
                  title: Text(item["voucher_no"]?.toString() ?? "-"),
                  subtitle:
                  Text(item["jobworker_name"]?.toString() ?? "-"),
                  trailing: Text(item["voucher_date"]?.toString() ?? ""),
                  onTap: () async {
                    final int id =
                        int.tryParse(item["id"]?.toString() ?? "0") ?? 0;

                    setState(() {
                      selectedVoucher = item;
                      voucherSearchController.text =
                          item["voucher_no"]?.toString() ?? "";
                      isVoucherDropdownOpen = false;
                    });

                    if (id > 0) await _loadSelectedVoucher(id);
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  /// ============================================================
  /// FILTER / DETAILS
  /// ============================================================
  Widget filterWidget() {
    void toggle() =>
        setState(() => isJobworkInfoExpanded = !isJobworkInfoExpanded);

    return Container(
      margin: const EdgeInsets.only(top: 5),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          InkWell(
            onTap: toggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.receipt_long, color: Colors.blue),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Jobwork Receive Details",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "Voucher No: ${voucher["voucher_no"]?.toString() ?? "-"}",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: _showIssuedItemsPopup,
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.primaryDark,
                            AppColors.gradientBlue,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.outbox_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            "Issue",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  InkWell(
                    onTap: toggle,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Icon(
                        isJobworkInfoExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                children: [
                  _searchableVoucherDropdown(),
                  const SizedBox(height: 10),
                  _infoRow(
                    _infoCard(
                      title: "Receive Date",
                      value: voucher["receive_date"]?.toString() ?? "-",
                      icon: Icons.calendar_month,
                      color: Colors.blue,
                    ),
                    _infoCard(
                      title: "Jobworker",
                      value: voucher["jobworker_name"]?.toString() ?? "-",
                      icon: Icons.person,
                      color: Colors.orange,
                    ),
                  ),
                  _infoRow(
                    _infoCard(
                      title: "Production Step",
                      value:
                      voucher["production_step_name"]?.toString() ?? "-",
                      icon: Icons.settings,
                      color: Colors.green,
                    ),
                    _infoCard(
                      title: "Voucher Date",
                      value: voucher["voucher_date"]?.toString() ?? "-",
                      icon: Icons.calendar_today,
                      color: Colors.purple,
                    ),
                  ),
                  _infoRow(
                    _infoCard(
                      title: "Issue Net Wt",
                      value:
                      voucher["issue_net_wt_total"]?.toString() ?? "0.000",
                      icon: Icons.scale,
                      color: Colors.blue,
                    ),
                    _infoCard(
                      title: "Receive Net Wt",
                      value: voucher["receive_net_wt_total"]?.toString() ??
                          "0.000",
                      icon: Icons.inventory_2,
                      color: Colors.orange,
                    ),
                  ),
                  _infoRow(
                    _infoCard(
                      title: "Pending Net Wt",
                      value: voucher["pending_net_wt_total"]?.toString() ??
                          "0.000",
                      icon: Icons.pending_actions,
                      color: Colors.red,
                    ),
                    _infoCard(
                      title: "Voucher No",
                      value: voucher["voucher_no"]?.toString() ?? "-",
                      icon: Icons.receipt_long,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: isJobworkInfoExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(Widget left, Widget right) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: left),
          const SizedBox(width: 8),
          Expanded(child: right),
        ],
      ),
    );
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

  /// ============================================================
  /// SAVE API — બધી rows જાય
  /// ============================================================
  Future<bool> updateJobworkReceive(
      int voucherId,
      List<Map<String, dynamic>> items,
      ) async {
    final List<Map<String, dynamic>> requestItems = [];

    int rowNo = 0;

    for (final item in items) {
      rowNo++;

      final int itemId = int.tryParse(item["item_id"]?.toString() ?? "0") ?? 0;

      final double gross =
          double.tryParse(item["gross_weight"]?.toString() ?? "0") ?? 0;
      final double otherWt =
          double.tryParse(item["other"]?.toString() ?? "0") ?? 0;
      final double otherAmt =
          double.tryParse(item["sale_other"]?.toString() ?? "0") ?? 0;
      final double net =
          double.tryParse(item["net_weight"]?.toString() ?? "0") ?? 0;
      final double fine =
          double.tryParse(item["fine_weight"]?.toString() ?? "0") ?? 0;
      final int qty = int.tryParse(item["qty"]?.toString() ?? "0") ?? 0;

      /// સાવ ખાલી row → skip
      final bool isBlankRow = itemId == 0 && gross <= 0 && qty <= 0;
      if (isBlankRow) continue;

      if (itemId == 0) {
        if (mounted) {
          AppMessage.error(context, "Please select Item in row $rowNo.");
        }
        return false;
      }

      if (gross <= 0) {
        if (mounted) {
          AppMessage.error(context, "Please enter Gross Wt in row $rowNo.");
        }
        return false;
      }

      final List<Map<String, dynamic>> chargeDetails = [];

      if (item["other_charge_details"] is List) {
        for (final raw in item["other_charge_details"]) {
          if (raw is! Map) continue;

          chargeDetails.add({
            "charge_id": int.tryParse(raw["charge_id"]?.toString() ?? "0") ?? 0,
            "charge_name": raw["charge_name"]?.toString() ?? "",
            "amount": double.tryParse(raw["amount"]?.toString() ?? "0") ?? 0,
            "qty": int.tryParse(raw["qty"]?.toString() ?? "1") ?? 1,
            "wt_formula": raw["wt_formula"]?.toString() ?? "flat",
            "amt_formula": raw["amt_formula"]?.toString() ?? "flat",
            "weight": double.tryParse(raw["weight"]?.toString() ?? "0") ?? 0,
            "total": double.tryParse(raw["total"]?.toString() ?? "0") ?? 0,
            "wt_operation": raw["wt_operation"]?.toString() ?? "less",
          });
        }
      }

      final int receiveItemId =
          int.tryParse(item["jobwork_receive_item_id"]?.toString() ?? "0") ?? 0;

      requestItems.add({
        if (receiveItemId > 0) "id": receiveItemId,
        if (receiveItemId > 0) "jobwork_receive_item_id": receiveItemId,
        "item_id": itemId,
        "receive_gross_wt": double.parse(gross.toStringAsFixed(3)),
        "other_wt": double.parse(otherWt.toStringAsFixed(3)),
        "other_amt": double.parse(otherAmt.toStringAsFixed(2)),
        "other_charge_details": chargeDetails,
        "receive_net_wt": double.parse(net.toStringAsFixed(3)),
        "receive_fine_wt": double.parse(fine.toStringAsFixed(3)),
        "receive_qty_pcs": qty,
        "remarks": item["remarks"]?.toString().trim().isNotEmpty == true
            ? item["remarks"].toString().trim()
            : null,
      });
    }

    if (requestItems.isEmpty) {
      if (mounted) AppMessage.error(context, "Please add at least one item.");
      return false;
    }

    debugPrint("🔥 ROWS ON SCREEN => ${items.length}");
    debugPrint("🔥 ITEMS SENDING  => ${requestItems.length}");

    /// dd-MM-yyyy → yyyy-MM-dd
    String receiveDate = voucher["receive_date"]?.toString() ?? "";
    try {
      final DateTime parsed = DateFormat("dd-MM-yyyy").parseStrict(receiveDate);
      receiveDate = DateFormat("yyyy-MM-dd").format(parsed);
    } catch (_) {}

    final Map<String, dynamic> body = {
      "receive_date": receiveDate,
      "remarks": voucher["remarks"]?.toString() ?? "",
      "items": requestItems,
    };

    debugPrint("JOBWORK RECEIVE BODY => $body");

    setState(() => isSaving = true);

    try {
      final response = await OfflineApiHelper.instance.putRequest(
        "${ApiConstants.jobwork_receive}/$voucherId",
        body,
      );

      debugPrint("JOBWORK RECEIVE RESPONSE => ${response?.data}");

      if (!mounted) return false;

      if (response == null) {
        AppMessage.error(context, "No response from server.");
        return false;
      }

      if (response.statusCode == 202) {
        AppMessage.success(context, "No Internet. Saved offline.");
        return true;
      }

      final data = response.data;

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          data is Map &&
          data["success"] == true) {
        AppMessage.success(
          context,
          data["message"] ?? "JobWork Receive Saved Successfully",
        );
        return true;
      }

      String msg = "Failed to save JobWork Receive";
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
      debugPrint("SAVE ERROR => $e");
      if (mounted) AppMessage.error(context, "Failed to save JobWork Receive");
      return false;
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  /// ============================================================
  /// DRAFT
  /// ============================================================
  void _saveReceiveDraft() {
    final int id = int.tryParse(voucher["id"]?.toString() ?? "0") ?? 0;
    if (id == 0) return;
    _offlineDraft.saveCastingDraft(id, items);
  }

  /// ============================================================
  /// TOTAL
  /// ============================================================
  String _totalOf(String key) {
    return items
        .fold<double>(
      0,
          (sum, item) =>
      sum + (double.tryParse(item[key]?.toString() ?? "0") ?? 0),
    )
        .toStringAsFixed(3);
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

  /// ============================================================
  /// PDF
  /// ============================================================
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
        child: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 16),
      ),
    );
  }

  Future<void> openPdf(int id) async {
    /// TODO: JobWork Receive નો PDF constant હોય તો અહીં બદલો
    final response = await ApiHelper().getRequestWithId(
      ApiConstants.casting_receive_pdf,
      id,
      responseType: ResponseType.bytes,
    );

    if (response != null && response.statusCode == 200) {
      final Directory dir = await getTemporaryDirectory();
      final File file = File("${dir.path}/JobWorkReceive_$id.pdf");
      await file.writeAsBytes(response.data);
      OpenFile.open(file.path);
    } else {
      if (mounted) AppMessage.error(context, "PDF download failed");
    }
  }

  /// ============================================================
  /// BLANK ROW
  /// ============================================================
  Map<String, dynamic> _blankRow() {
    return {
      "_row_key": "new_${DateTime.now().microsecondsSinceEpoch}_${items.length}",
      "jobwork_issue_id": null,
      "jobwork_receive_item_id": null,
      "_is_existing": false,
      "item_id": null,
      "item_name": "",
      "item": "",
      "issue_net_wt": "0.000",
      "issue_net_wt_total": "0.000",
      "outward_carat": "0.000",
      "gross_weight": "0.000",
      "other": "0.000",
      "sale_other": "0.00",
      "net_weight": "0.000",
      "fine_weight": "0.000",
      "qty": "0",
      "pending_net_wt": "0.000",
      "remarks": "",
      "loss_wt": "0.000",
      "other_charge_details": <Map<String, dynamic>>[],
    };
  }

  void _addBlankReceiveRow() {
    final FocusNode? currentFocus = FocusManager.instance.primaryFocus;

    setState(() => items.add(_blankRow()));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (currentFocus != null && currentFocus.canRequestFocus) {
        currentFocus.requestFocus();
      }
    });

    _saveReceiveDraft();
  }

  String _voucherValue(String key) {
    final double value =
        double.tryParse(voucher[key]?.toString() ?? "0") ?? 0.0;
    return value.toStringAsFixed(3);
  }

  /// ============================================================
  /// PENDING = API pending - (નવી rows નું net + જૂની rows નો ફેરફાર)
  /// ============================================================
  String _currentPendingWt() {
    final double apiPending =
        double.tryParse(voucher["pending_net_wt_total"]?.toString() ?? "0") ??
            0.0;

    double adjustment = 0.0;

    for (final item in items) {
      final double currentNet =
          double.tryParse(item["net_weight"]?.toString() ?? "0") ?? 0.0;

      if (item["_is_existing"] == true) {
        final double originalNet = double.tryParse(
          item["_original_net_weight"]?.toString() ?? "0",
        ) ??
            0.0;
        adjustment += currentNet - originalNet;
      } else {
        adjustment += currentNet;
      }
    }

    double pending = apiPending - adjustment;
    if (pending < 0) pending = 0;

    return pending.toStringAsFixed(3);
  }
}

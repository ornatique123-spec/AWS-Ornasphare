// import 'dart:async';
// import 'dart:io';
// import 'dart:ui';
// import 'package:dio/dio.dart';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:pecifician_sysytem/Item_Mangement/Item/ItemScreen.dart';
// import 'package:pecifician_sysytem/Item_Mangement/Label/CreateLabelScreen.dart';
// import 'package:pecifician_sysytem/Item_Mangement/Label_Items/label_item_screen.dart';
// import 'package:pecifician_sysytem/User/CreteUserScreen.dart';
// import 'package:provider/provider.dart';
// import '../../Api_Constant/ApiConstants.dart';
// import '../../Api_Constant/api_helper.dart';
// import '../../Extra/AppColors.dart';
// import '../../Extra/AppMessage.dart';
// import '../../Extra/ItemProvider.dart';
// import '../../Extra/PremiumSearchableDropdown.dart';
// import '../../Offline Data/offline_api_helper.dart';
//
// class CreateLabelScreen extends StatefulWidget {
//   const CreateLabelScreen({super.key});
//
//   @override
//   State<CreateLabelScreen> createState() => CreateLabelScreenState();
// }
//
// class CreateLabelScreenState extends State<CreateLabelScreen> {
//   final TextEditingController Carat_Controller = TextEditingController();
//   final TextEditingController purity_Controller = TextEditingController();
//   List userlist = [];
//   String? selectedItem;
//   String? imageId;
//   List<Map<String, dynamic>> tableRows = [];
//   Timer? _huidTimer;
//   int apiRowCount = 0;
//   List searchResults = [];
//
//   List<Map<String, dynamic>> items = [];
//   List<Map<String, dynamic>> allItems = [];
//   Timer? _grossTimer;
//   Map<String, Timer> rowTimers = {};
//   Map<String, dynamic>? selectedItemData;
//   String selectedItemName = "";
//   String selectedItemCode = "";
//
//   Set<String> triggerFields = {
//     "gross_weight",
//     "other_weight",
//     "net_weight",
//     "sale_labour_formula",
//     "metal_rate",
//     "metal_amount",
//     "labour_rate",
//     "labour_amount",
//     "sale_other",
//     "supplier_person",
//     "size",
//     "huid",
//     "total_amount",
//   };
//
//   Map<String, dynamic> _defaultItem() {
//     return {
//       "id": DateTime.now().microsecondsSinceEpoch.toString(),
//
//       "gross_weight": "",
//       "other": "",
//       "net_weight": "",
//       "sale_labour_formula": "",
//       "metal_rate": "",
//       "metal_amount": "",
//       "sale_labour_rate": "",
//       "sale_labour_amount": "",
//       "sale_other": "",
//       "supplier_person": "",
//       "size": "",
//       "huid": "",
//       "total_amount": "",
//     };
//   }
//   Map<String, FocusNode> focusNodes = {}; // ✅ ADD THIS
//   FocusNode getFocusNode(Map item, String key) {
//     final uniqueKey = "${item["id"]}_$key";
//     if (!focusNodes.containsKey(uniqueKey)) {
//       focusNodes[uniqueKey] = FocusNode();
//     }
//     return focusNodes[uniqueKey]!;
//   }
//   @override
//   void initState() {
//     super.initState();
//     Future.microtask(() {
//       Provider.of<ItemProvider>(context, listen: false).loadItems();
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     final height = size.height;
//     final width = size.width;
//     final isMobile = width < 600;
//     return Scaffold(
//       //resizeToAvoidBottomInset: false,
//       backgroundColor: AppColors.white,
//       body: Stack(
//         children: [
//
//           Column(
//             children: [
//               SizedBox(height: MediaQuery.of(context).padding.top + 40),
//
//               Expanded(
//                 child: SingleChildScrollView(
//                   physics: const BouncingScrollPhysics(),
//                   child: Column(
//                     children: [
//                       filterWidget(),
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
//                       searchResults.isEmpty
//                           ? const Padding(
//                         padding: EdgeInsets.only(top: 50),
//                         child: Center(
//                           child: Text(
//                             "No Data Found",
//                             style: TextStyle(
//                               fontSize: 16,
//                               fontWeight: FontWeight.w500,
//                               color: Colors.grey,
//                             ),
//                           ),
//                         ),
//                       )
//                           :ListView.builder(
//                         padding: EdgeInsets.fromLTRB(
//                           12,
//                           10,
//                           12,
//                           12,
//                         ),
//                         shrinkWrap: true, // 🔥 Important
//                         physics: const NeverScrollableScrollPhysics(), // 🔥 Important
//                         itemCount: searchResults.length,
//                         itemBuilder: (context, index) {
//                           return approvalItemCard(
//                             searchResults[index],
//                             index,
//                           );
//                         },
//                       ),
//
//                       // 🔥 Save button જેટલી height નું space
//                       const SizedBox(height: 80),
//                     ],
//                   ),
//                 ),
//               ),
//
//               /// SUMMARY BOX
//               buildSummaryRow(),
//
//               /// SAVE BUTTON
//               Container(
//                 color: Colors.transparent,
//                 child: InkWell(
//                   onTap: () async {
//                     await savefinalizeBulkItems();
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
//                       child: const Center(
//                         child: Text(
//                           "Save Label Item",
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
//               ),
//             ],
//           ),
//
//
//
//
//           // AppBar
//           Positioned(
//             top: 0,
//             left: 0,
//             right: 0,
//             child: Container(
//               padding: const EdgeInsets.only(
//                 top: 30,
//                 left: 16,
//                 right: 16,
//                 bottom: 16,
//               ),
//               child: Stack(
//                 alignment: Alignment.center,
//                 children: [
//                   const Text(
//                     "Create Label Item",
//                     style: TextStyle(
//                       color: Colors.black,
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   /// ✅ LEFT BACK ICON
//                   Align(
//                     alignment: Alignment.centerLeft,
//                     child: InkWell(
//                       onTap: () => Navigator.pop(context, true),
//                       child: Container(
//                         padding: EdgeInsets.all(isMobile ? 6 : 8),
//                         decoration: BoxDecoration(
//                           color:AppColors.primaryDark,
//                           borderRadius: BorderRadius.circular(8),
//                           border: Border.all(color: Colors.grey.shade300),
//                         ),
//                         child: Icon(
//                           Icons.arrow_back,
//                           color: Colors.white,
//                           size: isMobile ? 20 : 24,
//                         ),
//                       ),
//                     ),
//                   ),
//
//                   /// RIGHT NOTIFICATION ICON
//                   // Align(
//                   //   alignment: Alignment.centerRight,
//                   //
//                   //   child: Container(
//                   //     padding: EdgeInsets.all(isMobile ? 6 : 8),
//                   //
//                   //     decoration: BoxDecoration(
//                   //       color: Colors.white,
//                   //
//                   //       borderRadius: BorderRadius.circular(8),
//                   //
//                   //       boxShadow: [
//                   //         BoxShadow(
//                   //           color: AppColors.shadow,
//                   //
//                   //           blurRadius: 20,
//                   //
//                   //           offset: const Offset(5, 10),
//                   //         ),
//                   //       ],
//                   //     ),
//                   //
//                   //     child: Stack(
//                   //       clipBehavior: Clip.none,
//                   //
//                   //       children: [
//                   //         Icon(
//                   //           Icons.notifications_none,
//                   //
//                   //           size: isMobile ? 22 : 24,
//                   //
//                   //           color: Colors.red,
//                   //         ),
//                   //
//                   //         Positioned(
//                   //           right: -2,
//                   //
//                   //           top: -2,
//                   //
//                   //           child: Container(
//                   //             height: 8,
//                   //
//                   //             width: 8,
//                   //
//                   //             decoration: const BoxDecoration(
//                   //               color: Colors.red,
//                   //
//                   //               shape: BoxShape.circle,
//                   //             ),
//                   //           ),
//                   //         ),
//                   //       ],
//                   //     ),
//                   //   ),
//                   // ),
//                 ],
//               ),
//             ),
//           ),
//
//         ],
//       ),
//
//     );
//   }
//
//   // ... (Other functions loadItemDetails, filterWidget, etc. remain the same)
//
//   Future<void> saveBulkItems() async {
//     if (selectedItem == null) return;
//     List<Map<String, dynamic>> rows = [];
//     for (int i = apiRowCount; i < searchResults.length; i++) {
//       var row = searchResults[i];
//
//       rows.add({
//         "temp_id": row["id"], // ⭐ IMPORTANT (mapping key)
//
//         "gross_weight":
//             double.tryParse((row["gross_weight"] ?? "").toString()) ?? 0,
//         "other_weight":
//             double.tryParse((row["other_weight"] ?? "").toString()) ?? 0,
//         "net_weight":
//             double.tryParse((row["net_weight"] ?? "").toString()) ?? 0,
//
//         "sale_labour_formula": (row["sale_labour_formula"] ?? "").toString(),
//
//         "metal_rate":
//             double.tryParse((row["metal_rate"] ?? "").toString()) ?? 0,
//         "metal_amount":
//             double.tryParse((row["metal_amount"] ?? "").toString()) ?? 0,
//
//         "labour_rate":
//             double.tryParse((row["sale_labour_rate"] ?? "").toString()) ?? 0,
//         "labour_amount":
//             double.tryParse((row["sale_labour_amount"] ?? "").toString()) ?? 0,
//
//         "sale_other":
//             double.tryParse((row["sale_other"] ?? "").toString()) ?? 0,
//
//         "supplier_person": (row["supplier_person"] ?? "").toString(),
//
//         "size": int.tryParse((row["size"] ?? "").toString()) ?? 0,
//
//         "HUID": (row["huid"] ?? "").toString(),
//
//         "total_amount":
//             double.tryParse((row["total_amount"] ?? "").toString()) ?? 0,
//       });
//     }
//
//     Map<String, dynamic> body = {
//       "item_id": int.parse(selectedItem!),
//       "rows": rows,
//     };
//
//     print("📤 REQUEST BODY: $body");
//
//     try {
//       final response = await ApiHelper().postRequest(
//         ApiConstants.multiple_items_label_configs,
//         body,
//         showLoading: false,
//       );
//
//       if (response != null && response.statusCode == 200) {
//         final List responseRows = response.data["data"];
//
//         // 🔥 SYNC BACKEND IDS WITH FRONTEND
//         setState(() {
//           for (int i = 0; i < responseRows.length; i++) {
//             final backendRow = responseRows[i];
//             final tempId = backendRow["temp_id"];
//
//             int index = searchResults.indexWhere(
//                   (row) => row["id"]?.toString() == tempId?.toString(),
//             );
//
//             if (index != -1) {
//               final oldRow = Map<String, dynamic>.from(searchResults[index]);
//
//               // 🔥 IMPORTANT: local UI id (controllers/focusNodes key) preserve karo
//               final String localId = oldRow["id"].toString();
//
//               final newRow = Map<String, dynamic>.from(backendRow);
//               newRow["id"] = localId;                     // local id j rakho (UI keys tutya nahi)
//               newRow["backend_id"] = backendRow["id"];     // real backend row id store karo
//
//               // 🔥 IMAGE URLS — aa j missing hatu
//               newRow["image_upload_url"] = backendRow["image_upload_url"];
//               newRow["image_show_url"]   = backendRow["image_show_url"];
//               newRow["image_delete_url"] = backendRow["image_delete_url"];
//               newRow["image_url"]        = backendRow["image_url"];
//
//               newRow["temp_id"] = tempId;
//
//               searchResults[index] = {...oldRow, ...newRow};
//             }
//           }
//         });
//
//         //await savefinalizeBulkItems();
//
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("Multiple rows saved successfully")),
//         );
//       } else {
//         final String message =
//             response?.data?["message"]?.toString() ??
//                 "Failed to Save Data";
//
//         AppMessage.error(
//           context,
//           message,
//         );
//       }
//     } catch (e) {
//       print("❌ ERROR: $e");
//
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text("Something went wrong")));
//     }
//   }
//
//   Future<void> savefinalizeBulkItems() async {
//     if (selectedItem == null) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text("Please select item")));
//       return;
//     }
//
//     Map<String, dynamic> body = {"item_id": int.parse(selectedItem!)};
//
//     print("📤 REQUEST BODY: $body");
//
//     final response = await OfflineApiHelper.instance.postRequest(
//       ApiConstants.finalize_items_label_configs,
//       body,
//     );
//
//     if (response != null && response.statusCode == 200 ||
//         response!.statusCode == 202) {
//
//       if (response.statusCode == 202) {
//         AppMessage.success(
//           context,
//           "No Internet. Update saved offline.",
//         );
//       }
//
//       Navigator.pushAndRemoveUntil(
//         context,
//         MaterialPageRoute(
//           builder: (_) => const label_item_screen(),
//         ),
//             (route) => route.isFirst,
//       );
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text("Saved successfully")));
//     } else {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text("Failed to Save Data")));
//     }
//   }
//
//   Future<void> loadItemDetails(String itemId) async {
//     Map<String, dynamic> body = {"item_id": int.parse(selectedItem!)};
//
//     print("📤 REQUEST BODY: $body");
//
//     final response = await ApiHelper().postRequest(
//       ApiConstants.Create_label_item_list,
//       body,
//     );
//
//     List categories = [];
//
//     if (response != null && response.statusCode == 200) {
//       final data = response.data;
//
//       /// ✅ CHECK: data null OR empty
//       if (data["data"] != null && data["data"].isNotEmpty) {
//         categories = data["data"];
//       } else {
//         /// 🔥 DEFAULT ITEM (WHEN NULL / EMPTY)
//         categories = [_defaultItem()];
//       }
//     } else {
//       /// 🔥 API ERROR CASE
//       categories = [_defaultItem()];
//     }
//
//     setState(() {
//       tableRows.clear();
//       searchResults = categories;
//     });
//   }
//
//   Widget filterWidget() {
//     final screenHeight = MediaQuery.of(context).size.height;
//     final screenWidth = MediaQuery.of(context).size.width;
//     final width = MediaQuery.of(context).size.width;
//
//     final isTablet = width >= 600;
//     return Container(
//       margin: const EdgeInsets.fromLTRB(10, 5, 10, 0),
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: AppColors.cardBackground,
//         borderRadius: BorderRadius.circular(5),
//         border: Border.all(color: AppColors.border),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 8,
//             offset: const Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           /// 🔍 SEARCH FIELD
//           SizedBox(
//             width: double.infinity,
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 0),
//               // decoration: BoxDecoration(
//               //   color:AppColors.background,
//               //   border: Border.all(color: AppColors.border,width: 1.5),
//               //   borderRadius: BorderRadius.circular(5),
//               // ),
//               child: Consumer<ItemProvider>(
//                 builder: (context, provider, child) {
//                   /// provider.items List<dynamic> hoy to Map list ma convert
//                   final List<Map<String, dynamic>> itemList =
//                   provider.items
//                       .map<Map<String, dynamic>>(
//                         (e) => Map<String, dynamic>.from(e),
//                   )
//                       .toList();
//
//                   /// CURRENT SELECTED ITEM
//                   Map<String, dynamic>? currentItem;
//
//                   if (selectedItem != null) {
//                     for (final item in itemList) {
//                       if (item["id"]?.toString() ==
//                           selectedItem.toString()) {
//                         currentItem = item;
//                         break;
//                       }
//                     }
//                   }
//
//                   return PremiumItemSearchDropdown(
//                     label: "",
//                     hint: "Select Item",
//
//                     /// IMPORTANT
//                     items: itemList,
//
//                     value: currentItem,
//
//                     requiredField: true,
//                     width: double.infinity,
//
//                     onChanged: (item) async {
//                       if (item == null) return;
//
//                       final String value =
//                           item["id"]?.toString() ?? "";
//
//                       if (value.isEmpty) return;
//
//                       setState(() {
//                         /// ITEM ID
//                         selectedItem = value;
//
//                         /// FULL ITEM
//                         selectedItemData = item;
//
//                         /// ITEM NAME
//                         selectedItemName =
//                             item["item_name"]?.toString() ??
//                                 item["name"]?.toString() ??
//                                 "";
//
//                         /// ITEM CODE
//                         selectedItemCode =
//                             item["item_code"]?.toString() ??
//                                 item["code"]?.toString() ??
//                                 "";
//
//                         /// CARAT
//                         Carat_Controller.text =
//                             item["inward_carat"]?.toString() ?? "";
//
//                         /// PURITY
//                         purity_Controller.text =
//                             item["inward_purity"]?.toString() ?? "";
//                       });
//
//                       await loadItemDetails(value);
//                     },
//                   );
//                 },
//               )
//             ),
//           ),
//
//           const SizedBox(height: 5),
//
//           Row(
//             children: [
//               Expanded(
//                 child: _buildTextField(
//                   context,
//                   "Carat",
//                   controller: Carat_Controller,
//                 ),
//               ),
//               const SizedBox(width: 10),
//               Expanded(
//                 child: _buildTextField(
//                   context,
//                   "Purity",
//                   controller: purity_Controller,
//                 ),
//               ),
//             ],
//           ),
//
//           const SizedBox(height: 8),
//
//           /// 🔥 BUTTONS
//           Row(
//             children: [
//
//               /// SHOW
//               Expanded(
//                 child: InkWell(
//                   onTap: () {
//                     // applyDateFilter(); // 🔥 CALL HERE
//                     print("Apply Filter");
//                   },
//                   borderRadius: BorderRadius.circular(8),
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(vertical: 10),
//                     decoration: BoxDecoration(
//                       gradient: LinearGradient(
//                         colors: [
//                           AppColors.primaryDark.withOpacity(0.7),
//                           AppColors.secondaryDark.withOpacity(0.7),
//                         ],
//                       ),
//                       borderRadius: BorderRadius.circular(5),
//                     ),
//                     child: const Center(
//                       child: Text(
//                         "Show",
//                         style: TextStyle(
//                           fontWeight: FontWeight.bold,
//                           color: Colors.white,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//
//               const SizedBox(width: 10),
//
//               /// CLEAR
//               Expanded(
//                 child: InkWell(
//                   onTap: () {
//                     // searchController.clear();
//                     // fromDateController.clear();
//                     // toDateController.clear();
//                     //
//                     // setState(() {
//                     //   userlist = allUsers; // reset list
//                     // });
//                   },
//
//                   borderRadius: BorderRadius.circular(8),
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(vertical: 10),
//                     decoration: BoxDecoration(
//                       color: Colors.grey.shade200,
//                       borderRadius: BorderRadius.circular(5),
//                       border: Border.all(color:AppColors.border),
//                     ),
//                     child: const Center(
//                       child: Text(
//                         "Clear",
//                         style: TextStyle(
//                           fontWeight: FontWeight.bold,
//                           color: Colors.black,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           )
//         ],
//       ),
//     );
//   }
//
//   Widget _buildTextField(
//       BuildContext context,
//       String label, {
//         String? hint,
//         TextEditingController? controller,
//       }) {
//     final width = MediaQuery.of(context).size.width;
//     final isTablet = width > 700;
//     final isDesktop = width >= 1000;
//
//     double fontSize = isDesktop
//         ? 16
//         : isTablet
//         ? 14
//         : 13;
//
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//
//         /// 🔹 LABEL (VISIBLE)
//         Padding(
//           padding: const EdgeInsets.only(left: 2.0),
//           child: Text(
//             label,
//             style: TextStyle(
//               fontSize: fontSize,
//               fontWeight: FontWeight.w600,
//               color: Colors.black,
//             ),
//           ),
//         ),
//
//         SizedBox(height: isTablet ? 6 : 5),
//
//         /// 🔹 TEXTFIELD
//         Container(
//           padding: EdgeInsets.symmetric(
//             horizontal: isTablet ? 14 : 10,
//             vertical: isTablet ? 4 : 2,
//           ),
//           decoration: BoxDecoration(
//             color:AppColors.background,
//             border: Border.all(color: AppColors.border,width: 1.5),
//             borderRadius: BorderRadius.circular(6),
//           ),
//
//           child: TextField(
//             controller: controller,
//             style: TextStyle(fontSize: fontSize, color: Colors.black),
//
//             decoration: InputDecoration(
//               hintText: hint ?? "Enter $label",
//               hintStyle: TextStyle(
//                 color: Colors.grey.shade600,
//                 fontSize: fontSize,
//               ),
//               border: InputBorder.none,
//               isDense: true,
//               contentPadding: const EdgeInsets.symmetric(vertical: 10),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget approvalItemCard(
//       Map<String, dynamic> item,
//       int index,
//       ) {
//     final bool isExpanded = item["expanded"] ?? false;
//
//     final String itemName =
//     item["item_name"]?.toString().trim().isNotEmpty == true
//         ? item["item_name"].toString()
//         : selectedItemName.isNotEmpty
//         ? selectedItemName
//         : "Item";
//
//     final String itemCode =
//     item["item_code"]?.toString().trim().isNotEmpty == true
//         ? item["item_code"].toString()
//         : item["code"]?.toString().trim().isNotEmpty == true
//         ? item["code"].toString()
//         : selectedItemCode.isNotEmpty
//         ? selectedItemCode
//         : "-";
//
//     return Container(
//       key: ValueKey(
//         item["itemset_id"] ??
//             item["id"] ??
//             index,
//       ),
//       margin: const EdgeInsets.symmetric(
//         horizontal: 8,
//         vertical: 5,
//       ),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(5),
//         border: Border.all(
//           color: AppColors.border,
//         ),
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
//             padding: const EdgeInsets.symmetric(
//               horizontal: 10,
//               vertical: 7,
//             ),
//             decoration: BoxDecoration(
//               color: AppColors.primaryDark.withOpacity(0.10),
//               borderRadius: const BorderRadius.only(
//                 topLeft: Radius.circular(5),
//                 topRight: Radius.circular(5),
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
//                     "${searchResults.length - index}",
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
//                         maxLines: 1,
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
//                   constraints: const BoxConstraints(
//                     maxWidth: 130,
//                   ),
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 8,
//                     vertical: 5,
//                   ),
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(5),
//                     border: Border.all(
//                       color: AppColors.border,
//                     ),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       const Icon(
//                         Icons.qr_code_2,
//                         size: 14,
//                         color: AppColors.primaryDark,
//                       ),
//                       const SizedBox(width: 4),
//                       Flexible(
//                         child: Text(
//                           itemCode,
//                           maxLines: 1,
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
//                 /// =====================================================
//                 /// DELETE
//                 /// EXACT SAME FUNCTIONALITY AS OLD CODE
//                 /// =====================================================
//                 InkWell(
//                   onTap: () {
//                     setState(() {
//                       searchResults.removeAt(index);
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
//                         begin: Alignment.topLeft,
//                         end: Alignment.bottomRight,
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
//           /// COLLAPSED FIELDS
//           /// EXISTING FIELDS + EXISTING FUNCTIONALITY
//           /// =========================================================
//           if (!isExpanded)
//             Container(
//               padding: const EdgeInsets.fromLTRB(
//                 10,
//                 8,
//                 10,
//                 9,
//               ),
//               child: SingleChildScrollView(
//                 scrollDirection: Axis.horizontal,
//                 physics: const BouncingScrollPhysics(),
//                 keyboardDismissBehavior:
//                 ScrollViewKeyboardDismissBehavior.manual,
//                 child: Row(
//                   crossAxisAlignment: CrossAxisAlignment.end,
//                   children: [
//                     _miniField(
//                       "Gross",
//                       item,
//                       "gross_weight",
//                     ),
//
//                     _miniField(
//                       "Other Wt",
//                       item,
//                       "other_weight",
//                     ),
//
//                     _miniField(
//                       "Net",
//                       item,
//                       "net_weight",
//                     ),
//
//                     _miniField(
//                       "Labour Formula",
//                       item,
//                       "sale_labour_formula",
//                     ),
//
//                     _miniField(
//                       "Metal Rate",
//                       item,
//                       "metal_rate",
//                     ),
//
//                     _miniField(
//                       "Metal Amount",
//                       item,
//                       "metal_amount",
//                     ),
//
//                     _miniField(
//                       "Labor Rate",
//                       item,
//                       "sale_labour_rate",
//                     ),
//
//                     _miniField(
//                       "Labour Amount",
//                       item,
//                       "sale_labour_amount",
//                     ),
//
//                     _miniField(
//                       "Sale Other",
//                       item,
//                       "sale_other",
//                     ),
//
//                     _miniField(
//                       "Supplier Person",
//                       item,
//                       "supplier_person",
//                     ),
//
//                     _miniField(
//                       "Size",
//                       item,
//                       "size",
//                     ),
//
//                     _miniField(
//                       "HUID",
//                       item,
//                       "huid",
//                     ),
//                     _imageUploadField(item),   // 🔥 NEW — sauthi pehla, so it's easy to spot
//                   ],
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _miniField(
//       String title,
//       Map<String, dynamic> item,
//       String key,
//       ) {
//     /// =========================================================
//     /// EXISTING KEYS / FUNCTIONALITY SAME
//     /// =========================================================
//     final bool isOtherField = key == "other_weight";
//     final bool isMetalRateField = key == "metal_rate";
//     final bool isLabourRateField = key == "sale_labour_rate";
//
//     final controller = getController(item, key);
//
//     /// =========================================================
//     /// LABOUR FORMULA → EXISTING DROPDOWN
//     /// =========================================================
//     if (key == "sale_labour_formula") {
//       return _labourDropdown(item);
//     }
//
//     final bool editable = isEditableField(key);
//     final bool canEdit = isEditableField(key);
//
//     return Container(
//       width: 105,
//       margin: const EdgeInsets.only(
//         right: 7,
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           /// =====================================================
//           /// TITLE
//           /// =====================================================
//           Padding(
//             padding: const EdgeInsets.only(
//               left: 2,
//               bottom: 4,
//             ),
//             child: Text(
//               title,
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//               style: const TextStyle(
//                 fontSize: 10,
//                 color: Colors.black54,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           ),
//
//           /// =====================================================
//           /// FIELD CONTAINER
//           /// =====================================================
//           Container(
//             height: 36,
//             decoration: BoxDecoration(
//               color: editable
//                   ? Colors.white
//                   : Colors.grey.shade50,
//               borderRadius: BorderRadius.circular(5),
//               border: Border.all(
//                 color: AppColors.border,
//               ),
//             ),
//             child: Stack(
//               alignment: Alignment.centerRight,
//               children: [
//                 /// =================================================
//                 /// TEXT FIELD
//                 /// =================================================
//                 TextFormField(
//                   controller: controller,
//
//                   /// EXISTING FOCUS LOGIC
//                   focusNode: getFocusNode(
//                     item,
//                     key,
//                   ),
//
//                   readOnly: !canEdit,
//
//                   keyboardType:
//                   const TextInputType.numberWithOptions(
//                     decimal: true,
//                   ),
//
//                   textInputAction: TextInputAction.done,
//
//                   enableInteractiveSelection: canEdit,
//                   showCursor: canEdit,
//                   canRequestFocus: canEdit,
//
//                   textAlign: TextAlign.left,
//
//                   style: TextStyle(
//                     color: editable
//                         ? Colors.black
//                         : Colors.black54,
//                     fontSize: 12,
//                     fontWeight: FontWeight.w600,
//                   ),
//
//                   /// =================================================
//                   /// ON TAP - UI/UX LIKE NEW DESIGN
//                   /// =================================================
//                   onTap: () {
//                     if (!canEdit) {
//                       return;
//                     }
//
//                     if (controller.text == "0" ||
//                         controller.text == "0.0" ||
//                         controller.text == "0.00" ||
//                         controller.text == "0.000") {
//                       controller.clear();
//                     } else {
//                       controller.selection = TextSelection(
//                         baseOffset: 0,
//                         extentOffset: controller.text.length,
//                       );
//                     }
//                   },
//
//                   /// =================================================
//                   /// EXISTING CALCULATION + TIMER LOGIC
//                   /// =================================================
//                   // onChanged: (val) {
//                   //   item[key] = val;
//                   //
//                   //   calculateItem(item);
//                   //
//                   //   setState(() {});
//                   //
//                   //   if (triggerFields.contains(key)) {
//                   //     final rowId = item["id"];
//                   //
//                   //     /// Cancel previous timer
//                   //     rowTimers[rowId]?.cancel();
//                   //
//                   //     rowTimers[rowId.toString()] = Timer(
//                   //       const Duration(seconds: 2),
//                   //           () async {
//                   //         /// Existing bulk save
//                   //         await saveBulkItems();
//                   //
//                   //         /// Existing new blank item
//                   //         final newItem = _defaultItem();
//                   //
//                   //         if (!mounted) return;
//                   //
//                   //         setState(() {
//                   //           searchResults.insert(
//                   //             0,
//                   //             newItem,
//                   //           );
//                   //         });
//                   //       },
//                   //     );
//                   //   }
//                   // },
//
//                   onChanged: (val) {
//                     // ============================================================
//                     // UPDATE CURRENT ROW
//                     // ============================================================
//                     item[key] = val;
//
//                     // ============================================================
//                     // CALCULATE CURRENT ROW
//                     // ============================================================
//                     calculateItem(item);
//
//                     if (mounted) {
//                       setState(() {});
//                     }
//
//                     // ============================================================
//                     // AUTO SAVE ONLY FOR TRIGGER FIELDS
//                     // ============================================================
//                     if (triggerFields.contains(key)) {
//                       // 🔥 ALWAYS STRING KEY
//                       final String rowId = item["id"]?.toString() ?? "";
//
//                       if (rowId.isEmpty) {
//                         debugPrint("⚠️ ROW ID EMPTY - AUTO SAVE SKIPPED");
//                         return;
//                       }
//
//                       final String timerKey = "${rowId}_$key";
//
//                       // 🔥 SAME KEY CANCEL
//                       rowTimers[timerKey]?.cancel();
//
//                       debugPrint(
//                         "⏳ TIMER RESET => row=$rowId field=$key",
//                       );
//
//                       rowTimers[timerKey] = Timer(
//                         const Duration(seconds: 2),
//                             () async {
//                           // Remove completed timer
//                           rowTimers.remove(timerKey);
//
//                           if (!mounted) return;
//
//                           debugPrint(
//                             "🔥 AUTO SAVE => row=$rowId field=$key",
//                           );
//
//                           // ========================================================
//                           // SAVE
//                           // ========================================================
//                           await saveBulkItems();
//
//                           if (!mounted) return;
//
//                           // ========================================================
//                           // ADD ONLY ONE BLANK ROW
//                           // ========================================================
//
//                           final bool blankRowAlreadyExists =
//                           searchResults.any((row) {
//                             return _isBlankRow(row);
//                           });
//
//                           if (!blankRowAlreadyExists) {
//                             final newItem = _defaultItem();
//
//                             setState(() {
//                               searchResults.insert(
//                                 0,
//                                 newItem,
//                               );
//                             });
//
//                             debugPrint(
//                               "➕ NEW BLANK ROW ADDED => ${newItem["id"]}",
//                             );
//                           } else {
//                             debugPrint(
//                               "ℹ️ BLANK ROW ALREADY EXISTS - NOT ADDED",
//                             );
//                           }
//                         },
//                       );
//                     }
//                   },
//
//                   decoration: InputDecoration(
//                     isDense: true,
//                     contentPadding: EdgeInsets.only(
//                       left: 8,
//
//                       /// Button / checkbox mate space
//                       right: (isOtherField ||
//                           isMetalRateField ||
//                           isLabourRateField)
//                           ? 30
//                           : 8,
//
//                       top: 9,
//                       bottom: 9,
//                     ),
//                     border: InputBorder.none,
//                     enabledBorder: InputBorder.none,
//                     focusedBorder: InputBorder.none,
//                   ),
//                 ),
//
//                 /// =================================================
//                 /// OTHER WEIGHT + BUTTON
//                 /// EXISTING getreturnDetails FUNCTIONALITY SAME
//                 /// =================================================
//                 if (isOtherField)
//                   Positioned(
//                     right: 4,
//                     child: InkWell(
//                       onTap: () async {
//                         FocusManager.instance.primaryFocus
//                             ?.unfocus();
//
//                         /// EXISTING FUNCTION
//                         await getreturnDetails(
//                           item["id"],
//                           item,
//                         );
//
//                         /// EXISTING FOCUS FIX
//                         Future.delayed(
//                           const Duration(
//                             milliseconds: 100,
//                           ),
//                               () {
//                             FocusManager.instance.primaryFocus
//                                 ?.unfocus();
//                           },
//                         );
//
//                         /// EXISTING CONTROLLER UPDATE
//                         controller.text =
//                             item["other_amount"]?.toString() ??
//                                 "0";
//
//                         calculateItem(item);
//
//                         setState(() {});
//                       },
//                       borderRadius: BorderRadius.circular(4),
//                       child: Container(
//                         width: 22,
//                         height: 22,
//                         alignment: Alignment.center,
//                         decoration: BoxDecoration(
//                           color: const Color(
//                             0xffC8A96A,
//                           ),
//                           borderRadius:
//                           BorderRadius.circular(4),
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
//                 /// =================================================
//                 /// METAL RATE CHECKBOX
//                 /// EXISTING FUNCTIONALITY SAME
//                 /// =================================================
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
//                           value: (double.tryParse(
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
//                                 /// ON
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
//                                 /// OFF
//                                 controller.text = "0.00";
//
//                                 item["metal_rate"] = "0.00";
//                               }
//
//                               /// EXISTING FUNCTION
//                               updateController(
//                                 item,
//                                 "metal_rate",
//                               );
//
//                               /// EXISTING CALCULATION
//                               calculateItem(item);
//                             });
//                           },
//                         ),
//                       ),
//                     ),
//                   ),
//
//                 /// =================================================
//                 /// SALE LABOUR RATE CHECKBOX
//                 /// KEY SAME = sale_labour_rate
//                 /// =================================================
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
//                           value: (double.tryParse(
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
//                                 /// OFF
//                                 controller.text = "0.00";
//
//                                 item["sale_labour_rate"] =
//                                 "0.00";
//                               } else {
//                                 /// ON
//                                 if ((double.tryParse(
//                                   controller.text.isEmpty
//                                       ? "0"
//                                       : controller.text,
//                                 ) ??
//                                     0) ==
//                                     0) {
//                                   /// Tamari OLD functionality:
//                                   /// empty rakhshe, user rate enter karse
//                                   controller.clear();
//
//                                   item["sale_labour_rate"] = "";
//                                 }
//                               }
//
//                               /// IMPORTANT:
//                               /// sale_labour_rate j update karvanu
//                               updateController(
//                                 item,
//                                 "sale_labour_rate",
//                               );
//
//                               /// EXISTING CALCULATION
//                               calculateItem(item);
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
//   Future<void> getApprovalDetails(
//     dynamic id,
//     Map<String, dynamic> mainItem,
//   ) async {
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
//   void showOtherChargesPopup(Map<String, dynamic> item, List apiList) {
//     /// ============================================================
//     /// 🔥 EXISTING SELECTION (Previous "Apply" thi save thayel)
//     /// Priority: other_charge_id (sachu match) > sale_other amount (fallback)
//     /// ============================================================
//     final int? existingChargeId = int.tryParse(
//       item["other_charge_id"]?.toString() ?? "",
//     );
//
//     final double existingAmount = double.tryParse(
//       item["sale_other"]?.toString() ?? "0",
//     ) ??
//         0;
//
//     bool alreadyMatched = false;
//
//     // ============================================================
//     // API DATA -> POPUP DATA
//     // ============================================================
//     final List<Map<String, dynamic>> charges = apiList.map<Map<String, dynamic>>((e) {
//       final String weightFormula =
//       (e["weight_formula"] ?? "").toString().trim().toLowerCase();
//
//       String wtFormula = "flat";
//
//       if (weightFormula == "per_quantity" ||
//           weightFormula == "per qty" ||
//           weightFormula == "per_qty") {
//         wtFormula = "per_qty";
//       } else if (weightFormula == "per_weight" ||
//           weightFormula == "per weight" ||
//           weightFormula == "per_wt") {
//         wtFormula = "per_weight";
//       }
//
//       final int chargeId = int.tryParse(e["id"]?.toString() ?? "") ?? 0;
//       final double defaultAmount =
//           double.tryParse(e["default_amount"]?.toString() ?? "0") ?? 0;
//
//       bool isSelected = false;
//
//       if (!alreadyMatched) {
//         if (existingChargeId != null && existingChargeId == chargeId) {
//           isSelected = true;
//           alreadyMatched = true;
//         } else if (existingChargeId == null &&
//             existingAmount > 0 &&
//             defaultAmount == existingAmount) {
//           isSelected = true;
//           alreadyMatched = true;
//         }
//       }
//
//       return {
//         "id": e["id"],
//         "charge": (e["name"] ?? "").toString(),
//         "amount": (e["default_amount"] ?? 0).toString(),
//         "qty": (e["quantity_pcs"] ?? 1).toString(),
//         "weight": (e["default_weight"] ?? 0).toString(),
//         "wt_formula": wtFormula,
//         "amt_formula_type": "flat",
//         "amt_formula": "",
//         "total_weight": "0.00",
//         "total_amt": "0.00",
//         "is_selected": isSelected,
//       };
//     }).toList();
//
//     /// ============================================================
//     /// 🔥 PERSISTENT CONTROLLERS
//     /// ============================================================
//     final Map<int, Map<String, TextEditingController>> rowControllers = {};
//
//     for (int i = 0; i < charges.length; i++) {
//       rowControllers[i] = {
//         "amount": TextEditingController(text: charges[i]["amount"]?.toString() ?? "0"),
//         "qty": TextEditingController(text: charges[i]["qty"]?.toString() ?? "1"),
//         "weight": TextEditingController(text: charges[i]["weight"]?.toString() ?? "0"),
//       };
//     }
//
//     void disposeControllers() {
//       for (final ctrls in rowControllers.values) {
//         for (final c in ctrls.values) {
//           c.dispose();
//         }
//       }
//     }
//
//     /// ============================================================
//     /// 🔥 SINGLE-ROW CALCULATION
//     /// ============================================================
//     void calculateSingleCharge(Map<String, dynamic> c) {
//       final double amt = double.tryParse(c["amount"]?.toString() ?? "0") ?? 0;
//       final double qty = double.tryParse(c["qty"]?.toString() ?? "1") ?? 1;
//       final double weight = double.tryParse(c["weight"]?.toString() ?? "0") ?? 0;
//
//       final String amtFormula = c["amt_formula_type"]?.toString() ?? "flat";
//       final String wtFormula = c["wt_formula"]?.toString() ?? "flat";
//
//       double totalAmt = 0;
//       double totalWeight = 0;
//
//       switch (wtFormula) {
//         case "per_qty":
//           totalWeight = weight * qty;
//           break;
//         default:
//           totalWeight = weight;
//       }
//
//       c["total_weight"] = totalWeight.toStringAsFixed(2);
//
//       switch (amtFormula) {
//         case "per_qty":
//           totalAmt = amt * qty;
//           c["amt_formula"] = "$amt × $qty";
//           break;
//         case "per_weight":
//           totalAmt = amt * totalWeight;
//           c["amt_formula"] = "$amt × $totalWeight";
//           break;
//         case "per_qty_weight":
//           totalAmt = amt * qty * weight;
//           c["amt_formula"] = "$amt × $qty × $weight";
//           break;
//         default:
//           totalAmt = amt;
//           c["amt_formula"] = "$amt";
//       }
//
//       c["total_amt"] = totalAmt.toStringAsFixed(2);
//     }
//
//     for (final c in charges) {
//       calculateSingleCharge(c);
//     }
//
//     double calcTotal() {
//       double total = 0;
//       for (final c in charges) {
//         if (c["is_selected"] == true) {
//           total += double.tryParse(c["total_amt"]?.toString() ?? "0") ?? 0;
//         }
//       }
//       return total;
//     }
//
//     int? initialSelectedIndex() {
//       for (int i = 0; i < charges.length; i++) {
//         if (charges[i]["is_selected"] == true) return i;
//       }
//       return null;
//     }
//
//     final ValueNotifier<double> totalNotifier = ValueNotifier<double>(calcTotal());
//     final ValueNotifier<int?> selectedIndexNotifier =
//     ValueNotifier<int?>(initialSelectedIndex());
//
//     // ============================================================
//     // SHOW DIALOG — PREMIUM UI
//     // ============================================================
//     showDialog(
//       context: context,
//       barrierColor: Colors.black.withOpacity(0.50),
//       builder: (dialogContext) {
//         final Size screenSize = MediaQuery.of(dialogContext).size;
//         final bool isTablet = screenSize.width >= 600;
//
//         InputDecoration inputDecoration() {
//           return InputDecoration(
//             isDense: true,
//             contentPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
//             filled: true,
//             fillColor: Colors.white,
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(6),
//               borderSide: const BorderSide(color: AppColors.border),
//             ),
//             enabledBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(6),
//               borderSide: const BorderSide(color: AppColors.border),
//             ),
//             focusedBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(6),
//               borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.4),
//             ),
//           );
//         }
//
//         Widget headerCell(String title, double width, {bool left = false}) {
//           return SizedBox(
//             width: width,
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 5),
//               child: Text(
//                 title,
//                 textAlign: left ? TextAlign.left : TextAlign.center,
//                 style: const TextStyle(
//                   color: AppColors.primaryDark,
//                   fontSize: 10.5,
//                   fontWeight: FontWeight.w700,
//                 ),
//               ),
//             ),
//           );
//         }
//
//         return Dialog(
//           elevation: 0,
//           backgroundColor: Colors.transparent,
//           insetPadding: EdgeInsets.symmetric(
//             horizontal: isTablet ? 30 : 12,
//             vertical: 18,
//           ),
//           child: Container(
//             width: isTablet ? 1050 : double.infinity,
//             constraints: BoxConstraints(maxHeight: screenSize.height * 0.88),
//             decoration: BoxDecoration(
//               color: AppColors.background,
//               borderRadius: BorderRadius.circular(15),
//               border: Border.all(color: AppColors.primaryDark.withOpacity(0.14)),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.20),
//                   blurRadius: 28,
//                   offset: const Offset(0, 10),
//                 ),
//               ],
//             ),
//             child: ClipRRect(
//               borderRadius: BorderRadius.circular(15),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   // ===========================================
//                   // BLUE HEADER
//                   // ===========================================
//                   Container(
//                     width: double.infinity,
//                     padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
//                             color: Colors.white.withOpacity(0.14),
//                             borderRadius: BorderRadius.circular(9),
//                             border: Border.all(color: Colors.white.withOpacity(0.18)),
//                           ),
//                           child: const Icon(Icons.receipt_long_outlined, color: Colors.white, size: 20),
//                         ),
//                         const SizedBox(width: 10),
//                         const Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text("Other Charges",
//                                   style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
//                               SizedBox(height: 2),
//                               Text("Manage additional item charges",
//                                   style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
//                             ],
//                           ),
//                         ),
//                         Container(
//                           padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
//                           decoration: BoxDecoration(
//                             color: Colors.white.withOpacity(0.13),
//                             borderRadius: BorderRadius.circular(20),
//                           ),
//                           child: Text("${charges.length} Charges",
//                               style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
//                         ),
//                         const SizedBox(width: 8),
//                         InkWell(
//                           borderRadius: BorderRadius.circular(8),
//                           onTap: () {
//                             FocusManager.instance.primaryFocus?.unfocus();
//                             disposeControllers();
//                             Navigator.pop(dialogContext);
//                           },
//                           child: Container(
//                             width: 36,
//                             height: 36,
//                             alignment: Alignment.center,
//                             decoration: BoxDecoration(
//                               color: Colors.white.withOpacity(0.13),
//                               borderRadius: BorderRadius.circular(8),
//                             ),
//                             child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//
//                   // ===========================================
//                   // BODY
//                   // ===========================================
//                   Flexible(
//                     child: SingleChildScrollView(
//                       padding: const EdgeInsets.all(12),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           // ===================================
//                           // SECTION TITLE
//                           // ===================================
//                           Row(
//                             children: [
//                               Container(
//                                 width: 29,
//                                 height: 29,
//                                 alignment: Alignment.center,
//                                 decoration: BoxDecoration(
//                                   color: AppColors.iconBg,
//                                   borderRadius: BorderRadius.circular(7),
//                                 ),
//                                 child: const Icon(Icons.tune_rounded, size: 16, color: AppColors.primaryDark),
//                               ),
//                               const SizedBox(width: 8),
//                               const Text("Charge Details",
//                                   style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
//                               const Spacer(),
//                               ValueListenableBuilder<int?>(
//                                 valueListenable: selectedIndexNotifier,
//                                 builder: (context, selectedIndex, _) {
//                                   return Container(
//                                     padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
//                                     decoration: BoxDecoration(
//                                       color: AppColors.iconBg,
//                                       borderRadius: BorderRadius.circular(20),
//                                       border: Border.all(color: AppColors.border),
//                                     ),
//                                     child: Row(
//                                       mainAxisSize: MainAxisSize.min,
//                                       children: [
//                                         const Icon(Icons.check_circle_outline_rounded, size: 13, color: AppColors.primaryDark),
//                                         const SizedBox(width: 4),
//                                         Text(
//                                           "${selectedIndex != null ? 1 : 0} Selected",
//                                           style: const TextStyle(
//                                               color: AppColors.primaryDark, fontSize: 9.5, fontWeight: FontWeight.w600),
//                                         ),
//                                       ],
//                                     ),
//                                   );
//                                 },
//                               ),
//                             ],
//                           ),
//
//                           const SizedBox(height: 9),
//
//                           // ===================================
//                           // TABLE
//                           // ===================================
//                           SingleChildScrollView(
//                             scrollDirection: Axis.horizontal,
//                             keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
//                             child: Container(
//                               width: 900,
//                               decoration: BoxDecoration(
//                                 color: Colors.white,
//                                 borderRadius: BorderRadius.circular(9),
//                                 border: Border.all(color: AppColors.border),
//                                 boxShadow: [
//                                   BoxShadow(
//                                     color: AppColors.shadow,
//                                     blurRadius: 8,
//                                     offset: const Offset(0, 2),
//                                   ),
//                                 ],
//                               ),
//                               child: Column(
//                                 children: [
//                                   // ===========================
//                                   // TABLE HEADER
//                                   // ===========================
//                                   Container(
//                                     height: 42,
//                                     padding: const EdgeInsets.symmetric(horizontal: 4),
//                                     decoration: BoxDecoration(
//                                       color: AppColors.iconBg,
//                                       borderRadius: const BorderRadius.only(
//                                         topLeft: Radius.circular(8),
//                                         topRight: Radius.circular(8),
//                                       ),
//                                     ),
//                                     child: Row(
//                                       children: [
//                                         headerCell("Charge", 110, left: true),
//                                         headerCell("Amount", 90),
//                                         headerCell("Qty", 70),
//                                         headerCell("Weight", 90),
//                                         headerCell("Wt Formula", 105),
//                                         headerCell("Total Wt", 90),
//                                         headerCell("Amt Formula", 115),
//                                         headerCell("Total Amt", 105),
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
//                                   Divider(height: 1, thickness: 1, color: AppColors.border),
//
//                                   // ===========================
//                                   // CHARGE LIST
//                                   // ===========================
//                                   SizedBox(
//                                     height: 230,
//                                     child: charges.isEmpty
//                                         ? const Center(
//                                       child: Text(
//                                         "No charges available",
//                                         style: TextStyle(
//                                           color: AppColors.textSecondary,
//                                           fontSize: 12,
//                                           fontWeight: FontWeight.w600,
//                                         ),
//                                       ),
//                                     )
//                                         : ListView.separated(
//                                       keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
//                                       padding: const EdgeInsets.symmetric(vertical: 5),
//                                       itemCount: charges.length,
//                                       separatorBuilder: (context, index) {
//                                         return Divider(height: 1, color: AppColors.border);
//                                       },
//                                       itemBuilder: (context, index) {
//                                         final c = charges[index];
//
//                                         return StatefulBuilder(
//                                           builder: (context, setStateRow) {
//                                             void onFieldChanged() {
//                                               c["amount"] = rowControllers[index]!["amount"]!.text;
//                                               c["qty"] = rowControllers[index]!["qty"]!.text;
//                                               c["weight"] = rowControllers[index]!["weight"]!.text;
//
//                                               calculateSingleCharge(c);
//
//                                               setStateRow(() {});
//
//                                               totalNotifier.value = calcTotal();
//                                             }
//
//                                             return ValueListenableBuilder<int?>(
//                                               valueListenable: selectedIndexNotifier,
//                                               builder: (context, selectedIndex, _) {
//                                                 final bool selected = selectedIndex == index;
//
//                                                 return AnimatedContainer(
//                                                   duration: const Duration(milliseconds: 150),
//                                                   padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
//                                                   decoration: BoxDecoration(
//                                                     color: selected
//                                                         ? AppColors.primaryDark.withOpacity(0.035)
//                                                         : Colors.white,
//                                                     border: Border(
//                                                       left: BorderSide(
//                                                         color: selected ? AppColors.primaryDark : Colors.transparent,
//                                                         width: 3,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                   child: Row(
//                                                     children: [
//                                                       // CHARGE
//                                                       SizedBox(
//                                                         width: 110,
//                                                         child: Padding(
//                                                           padding: const EdgeInsets.symmetric(horizontal: 5),
//                                                           child: Row(
//                                                             children: [
//                                                               Container(
//                                                                 width: 24,
//                                                                 height: 24,
//                                                                 alignment: Alignment.center,
//                                                                 decoration: BoxDecoration(
//                                                                   color: selected
//                                                                       ? AppColors.primaryDark.withOpacity(0.12)
//                                                                       : AppColors.iconBg,
//                                                                   borderRadius: BorderRadius.circular(6),
//                                                                 ),
//                                                                 child: Text(
//                                                                   "${index + 1}",
//                                                                   style: const TextStyle(
//                                                                     color: AppColors.primaryDark,
//                                                                     fontSize: 9,
//                                                                     fontWeight: FontWeight.w700,
//                                                                   ),
//                                                                 ),
//                                                               ),
//                                                               const SizedBox(width: 5),
//                                                               Expanded(
//                                                                 child: Text(
//                                                                   c["charge"]?.toString() ?? "",
//                                                                   maxLines: 1,
//                                                                   overflow: TextOverflow.ellipsis,
//                                                                   style: TextStyle(
//                                                                     fontSize: 10.5,
//                                                                     fontWeight:
//                                                                     selected ? FontWeight.w700 : FontWeight.w600,
//                                                                     color: AppColors.textPrimary,
//                                                                   ),
//                                                                 ),
//                                                               ),
//                                                             ],
//                                                           ),
//                                                         ),
//                                                       ),
//
//                                                       // AMOUNT
//                                                       SizedBox(
//                                                         width: 90,
//                                                         child: Padding(
//                                                           padding: const EdgeInsets.symmetric(horizontal: 3),
//                                                           child: TextFormField(
//                                                             controller: rowControllers[index]!["amount"],
//                                                             style: const TextStyle(
//                                                               fontSize: 11,
//                                                               fontWeight: FontWeight.w600,
//                                                               color: AppColors.textPrimary,
//                                                             ),
//                                                             textAlign: TextAlign.center,
//                                                             keyboardType:
//                                                             const TextInputType.numberWithOptions(decimal: true),
//                                                             decoration: inputDecoration(),
//                                                             onChanged: (_) => onFieldChanged(),
//                                                           ),
//                                                         ),
//                                                       ),
//
//                                                       // QTY
//                                                       SizedBox(
//                                                         width: 70,
//                                                         child: Padding(
//                                                           padding: const EdgeInsets.symmetric(horizontal: 3),
//                                                           child: TextFormField(
//                                                             controller: rowControllers[index]!["qty"],
//                                                             style: const TextStyle(
//                                                               fontSize: 11,
//                                                               fontWeight: FontWeight.w600,
//                                                               color: AppColors.textPrimary,
//                                                             ),
//                                                             textAlign: TextAlign.center,
//                                                             keyboardType:
//                                                             const TextInputType.numberWithOptions(decimal: true),
//                                                             decoration: inputDecoration(),
//                                                             onChanged: (_) => onFieldChanged(),
//                                                           ),
//                                                         ),
//                                                       ),
//
//                                                       // WEIGHT
//                                                       SizedBox(
//                                                         width: 90,
//                                                         child: Padding(
//                                                           padding: const EdgeInsets.symmetric(horizontal: 3),
//                                                           child: TextFormField(
//                                                             controller: rowControllers[index]!["weight"],
//                                                             style: const TextStyle(
//                                                               fontSize: 11,
//                                                               fontWeight: FontWeight.w600,
//                                                               color: AppColors.textPrimary,
//                                                             ),
//                                                             textAlign: TextAlign.center,
//                                                             keyboardType:
//                                                             const TextInputType.numberWithOptions(decimal: true),
//                                                             decoration: inputDecoration(),
//                                                             onChanged: (_) => onFieldChanged(),
//                                                           ),
//                                                         ),
//                                                       ),
//
//                                                       // WT FORMULA
//                                                       SizedBox(
//                                                         width: 105,
//                                                         child: Padding(
//                                                           padding: const EdgeInsets.symmetric(horizontal: 3),
//                                                           child: DropdownButtonFormField<String>(
//                                                             value: c["wt_formula"],
//                                                             isExpanded: true,
//                                                             dropdownColor: Colors.white,
//                                                             icon: const Icon(
//                                                               Icons.keyboard_arrow_down_rounded,
//                                                               color: AppColors.primaryDark,
//                                                               size: 17,
//                                                             ),
//                                                             style: const TextStyle(
//                                                               fontSize: 10,
//                                                               color: AppColors.textPrimary,
//                                                               fontWeight: FontWeight.w600,
//                                                             ),
//                                                             decoration: inputDecoration(),
//                                                             items: const [
//                                                               DropdownMenuItem(value: "flat", child: Text("Flat")),
//                                                               DropdownMenuItem(value: "per_qty", child: Text("Per Qty")),
//                                                               DropdownMenuItem(value: "per_weight", child: Text("Per Wt")),
//                                                             ],
//                                                             onChanged: (v) {
//                                                               if (v == null) return;
//                                                               c["wt_formula"] = v;
//                                                               onFieldChanged();
//                                                             },
//                                                           ),
//                                                         ),
//                                                       ),
//
//                                                       // TOTAL WEIGHT
//                                                       SizedBox(
//                                                         width: 90,
//                                                         child: Center(
//                                                           child: Text(
//                                                             c["total_weight"]?.toString() ?? "0.00",
//                                                             textAlign: TextAlign.center,
//                                                             style: const TextStyle(
//                                                               fontSize: 10.5,
//                                                               fontWeight: FontWeight.w700,
//                                                               color: AppColors.textPrimary,
//                                                             ),
//                                                           ),
//                                                         ),
//                                                       ),
//
//                                                       // AMOUNT FORMULA
//                                                       SizedBox(
//                                                         width: 115,
//                                                         child: Padding(
//                                                           padding: const EdgeInsets.symmetric(horizontal: 3),
//                                                           child: DropdownButtonFormField<String>(
//                                                             value: c["amt_formula_type"] ?? "flat",
//                                                             isExpanded: true,
//                                                             dropdownColor: Colors.white,
//                                                             icon: const Icon(
//                                                               Icons.keyboard_arrow_down_rounded,
//                                                               color: AppColors.primaryDark,
//                                                               size: 17,
//                                                             ),
//                                                             style: const TextStyle(
//                                                               fontSize: 9.8,
//                                                               color: AppColors.textPrimary,
//                                                               fontWeight: FontWeight.w600,
//                                                             ),
//                                                             decoration: inputDecoration(),
//                                                             items: const [
//                                                               DropdownMenuItem(value: "flat", child: Text("Flat")),
//                                                               DropdownMenuItem(value: "per_qty", child: Text("Per Qty")),
//                                                               DropdownMenuItem(value: "per_weight", child: Text("Per Wt")),
//                                                               DropdownMenuItem(
//                                                                   value: "per_qty_weight", child: Text("Qty × Wt")),
//                                                             ],
//                                                             onChanged: (v) {
//                                                               if (v == null) return;
//                                                               c["amt_formula_type"] = v;
//                                                               onFieldChanged();
//                                                             },
//                                                           ),
//                                                         ),
//                                                       ),
//
//                                                       // TOTAL AMOUNT
//                                                       SizedBox(
//                                                         width: 105,
//                                                         child: Center(
//                                                           child: Container(
//                                                             constraints: const BoxConstraints(minWidth: 70),
//                                                             padding:
//                                                             const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
//                                                             decoration: BoxDecoration(
//                                                               color: const Color(0xFFEAF1FF),
//                                                               borderRadius: BorderRadius.circular(6),
//                                                               border: Border.all(
//                                                                 color: AppColors.primaryDark.withOpacity(0.12),
//                                                               ),
//                                                             ),
//                                                             child: Text(
//                                                               c["total_amt"]?.toString() ?? "0.00",
//                                                               textAlign: TextAlign.center,
//                                                               style: const TextStyle(
//                                                                 fontSize: 10.5,
//                                                                 fontWeight: FontWeight.w800,
//                                                                 color: AppColors.primaryDark,
//                                                               ),
//                                                             ),
//                                                           ),
//                                                         ),
//                                                       ),
//
//                                                       // CHECKBOX (SINGLE-SELECT)
//                                                       SizedBox(
//                                                         width: 45,
//                                                         child: Center(
//                                                           child: Transform.scale(
//                                                             scale: 0.88,
//                                                             child: Checkbox(
//                                                               value: selected,
//                                                               activeColor: AppColors.primaryDark,
//                                                               checkColor: Colors.white,
//                                                               side: const BorderSide(
//                                                                 color: AppColors.primaryDark,
//                                                                 width: 1.3,
//                                                               ),
//                                                               shape: RoundedRectangleBorder(
//                                                                 borderRadius: BorderRadius.circular(4),
//                                                               ),
//                                                               onChanged: (val) {
//                                                                 /// 🔥 SINGLE SELECT
//                                                                 if (selectedIndexNotifier.value != null) {
//                                                                   charges[selectedIndexNotifier.value!]
//                                                                   ["is_selected"] = false;
//                                                                 }
//
//                                                                 if (val == true) {
//                                                                   c["is_selected"] = true;
//                                                                   selectedIndexNotifier.value = index;
//                                                                 } else {
//                                                                   c["is_selected"] = false;
//                                                                   selectedIndexNotifier.value = null;
//                                                                 }
//
//                                                                 totalNotifier.value = calcTotal();
//                                                               },
//                                                             ),
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
//                           // ===================================
//                           // TOTAL SUMMARY
//                           // ===================================
//                           Container(
//                             width: double.infinity,
//                             padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
//                             decoration: BoxDecoration(
//                               gradient: const LinearGradient(
//                                 colors: [Color(0xFFF3F7FF), Color(0xFFEAF1FF)],
//                               ),
//                               borderRadius: BorderRadius.circular(9),
//                               border: Border.all(color: AppColors.border),
//                             ),
//                             child: Row(
//                               children: [
//                                 Container(
//                                   width: 34,
//                                   height: 34,
//                                   alignment: Alignment.center,
//                                   decoration: const BoxDecoration(
//                                     color: Colors.white,
//                                     shape: BoxShape.circle,
//                                   ),
//                                   child: const Icon(Icons.calculate_outlined, size: 18, color: AppColors.primaryDark),
//                                 ),
//                                 const SizedBox(width: 9),
//                                 Expanded(
//                                   child: Column(
//                                     crossAxisAlignment: CrossAxisAlignment.start,
//                                     children: [
//                                       const Text(
//                                         "Selected Charges Total",
//                                         style: TextStyle(
//                                           fontSize: 10.5,
//                                           color: AppColors.textSecondary,
//                                           fontWeight: FontWeight.w500,
//                                         ),
//                                       ),
//                                       const SizedBox(height: 2),
//                                       ValueListenableBuilder<int?>(
//                                         valueListenable: selectedIndexNotifier,
//                                         builder: (context, selectedIndex, _) {
//                                           return Text(
//                                             "${selectedIndex != null ? 1 : 0} of ${charges.length} charges selected",
//                                             style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary),
//                                           );
//                                         },
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                                 ValueListenableBuilder<double>(
//                                   valueListenable: totalNotifier,
//                                   builder: (context, total, _) {
//                                     return Text(
//                                       total.toStringAsFixed(2),
//                                       style: const TextStyle(
//                                         fontSize: 18,
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
//                   // ===========================================
//                   // BOTTOM ACTION BAR
//                   // ===========================================
//                   Container(
//                     width: double.infinity,
//                     padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
//                     decoration: const BoxDecoration(
//                       color: Colors.white,
//                       border: Border(top: BorderSide(color: AppColors.border)),
//                     ),
//                     child: Row(
//                       children: [
//                         // CANCEL
//                         Expanded(
//                           child: SizedBox(
//                             height: 42,
//                             child: OutlinedButton(
//                               onPressed: () {
//                                 FocusManager.instance.primaryFocus?.unfocus();
//                                 disposeControllers();
//                                 Navigator.pop(dialogContext);
//                               },
//                               style: OutlinedButton.styleFrom(
//                                 backgroundColor: Colors.white,
//                                 side: const BorderSide(color: AppColors.border),
//                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
//                               ),
//                               child: const Text(
//                                 "Cancel",
//                                 style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
//                               ),
//                             ),
//                           ),
//                         ),
//
//                         const SizedBox(width: 10),
//
//                         // APPLY — 🔥 FUNCTIONALITY EXACT SAME AS BEFORE
//                         Expanded(
//                           flex: 2,
//                           child: SizedBox(
//                             height: 42,
//                             child: Material(
//                               color: Colors.transparent,
//                               child: InkWell(
//                                 borderRadius: BorderRadius.circular(7),
//                                 onTap: () {
//                                   double selectedTotal = 0;
//                                   double selectedWeight = 0;
//                                   int selectedChargeId = 0;
//
//                                   for (final c in charges) {
//                                     if (c["is_selected"] == true) {
//                                       selectedTotal += double.tryParse(c["total_amt"] ?? "0") ?? 0;
//                                       selectedWeight += double.tryParse(c["weight"] ?? "0") ?? 0;
//                                       selectedChargeId = int.tryParse(c["id"].toString()) ?? 0;
//                                     }
//                                   }
//
//                                   /// 🔥 1. SET SALE OTHER (amount)
//                                   item["sale_other"] = selectedTotal.toStringAsFixed(2);
//
//                                   /// 🔥 2. SET OTHER WEIGHT
//                                   item["other_weight"] = selectedWeight.toStringAsFixed(3);
//
//                                   /// 🔥 3. SAVE SELECTED CHARGE ID
//                                   item["other_charge_id"] = selectedChargeId;
//
//                                   /// 🔥 4. UPDATE CONTROLLERS
//                                   updateController(item, "sale_other");
//                                   updateController(item, "other_weight");
//
//                                   /// 🔥 5. RECALCULATE
//                                   calculateItem(item);
//
//                                   FocusManager.instance.primaryFocus?.unfocus();
//
//                                   disposeControllers();
//
//                                   Navigator.pop(dialogContext);
//                                   saveBulkItems();
//                                   setState(() {});
//                                 },
//                                 child: Ink(
//                                   decoration: BoxDecoration(
//                                     gradient: const LinearGradient(
//                                       colors: [AppColors.primaryDark, AppColors.gradientBlue],
//                                       begin: Alignment.centerLeft,
//                                       end: Alignment.centerRight,
//                                     ),
//                                     borderRadius: BorderRadius.circular(7),
//                                     boxShadow: [
//                                       BoxShadow(
//                                         color: AppColors.primaryDark.withOpacity(0.22),
//                                         blurRadius: 8,
//                                         offset: const Offset(0, 3),
//                                       ),
//                                     ],
//                                   ),
//                                   child: const Row(
//                                     mainAxisAlignment: MainAxisAlignment.center,
//                                     children: [
//                                       Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 17),
//                                       SizedBox(width: 6),
//                                       Text(
//                                         "Apply Charges",
//                                         style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
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
//     );
//   }
//
//   void calculateItem(Map<String, dynamic> item) {
//     double gross =
//         double.tryParse(getController(item, "gross_weight").text) ?? 0;
//
//     double other = double.tryParse(getController(item, "other_weight").text) ?? 0;
//
//     double net = gross - other;
//
//     double metalRate =
//         double.tryParse(getController(item, "metal_rate").text) ?? 0;
//
//     double labourRate =
//         double.tryParse(getController(item, "sale_labour_rate").text) ?? 0;
//
//     double otherAmount =
//         double.tryParse(getController(item, "sale_other").text) ?? 0;
//
//     /// 🔥 METAL (same)
//     double metalAmount = net * metalRate;
//
//     /// 🔥 LABOUR FORMULA BASED
//     String formula = item["sale_labour_formula"] ?? "Per Net Weight";
//
//     double labourAmount = net * labourRate;
//
//     double fineWeight =
//         double.tryParse(getController(item, "fine_weight").text) ?? 0;
//
//     double qty = 1; // 🔥 jo qty field hoy to replace karo
//
//     if (formula == "Per Net Weight") {
//       labourAmount = net * labourRate;
//     } else if (formula == "Per Fine Weight") {
//       labourAmount = fineWeight * labourRate;
//     } else if (formula == "Per Qty") {
//       labourAmount = qty * labourRate;
//     } else if (formula == "Per Gross weight") {
//       labourAmount = gross * labourRate;
//     } else if (formula == "Flat") {
//       labourAmount = labourRate;
//     }
//
//     /// 🔥 TOTAL
//     double totalAmount = metalAmount + labourAmount + otherAmount;
//
//     /// 🔥 UPDATE ITEM
//     item["net_weight"] = net.toStringAsFixed(3);
//     item["metal_amount"] = metalAmount.toStringAsFixed(2);
//     item["sale_labour_amount"] = labourAmount.toStringAsFixed(2);
//     item["total_amount"] = totalAmount.toStringAsFixed(2);
//
//     /// 🔥 UPDATE UI
//     updateController(item, "net_weight");
//     updateController(item, "metal_amount");
//     updateController(item, "sale_labour_amount");
//     updateController(item, "total_amount");
//   }
//
//   void updateController(Map item, String key) {
//     String uniqueKey = "${item["id"]}_$key";
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
//   TextEditingController getController(Map item, String key) {
//     final uniqueKey = "${item["id"]}_$key";
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
//       "other",
//       "sale_labour_rate",
//       "metal_rate",
//       //"other_amount"
//     ].contains(key);
//   }
//
//   Future<void> getreturnDetails(
//     dynamic id,
//     Map<String, dynamic> mainItem,
//   ) async {
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
//   Widget _labourDropdown(Map<String, dynamic> item) {
//     List<String> options = [
//       "Per Net Weight",
//       "Per Fine Weight",
//       "Per Qty",
//       "Per Gross weight",
//       "Flat",
//     ];
//
//     return Container(
//       width: 150,
//       margin: const EdgeInsets.only(right: 8),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             "Labour Formula",
//             style: TextStyle(fontSize: 11, color: Colors.black54),
//           ),
//           const SizedBox(height: 4),
//
//           DropdownButtonFormField<String>(
//             value: options.contains(item["sale_labour_formula"])
//                 ? item["sale_labour_formula"]
//                 : "Per Net Weight",
//
//             icon: const Icon(
//               Icons.keyboard_arrow_down, // 🔥 dropdown arrow
//               color: Colors.black, // 🔥 black arrow
//             ),
//
//             dropdownColor: Colors.white, // 🔥 dropdown background
//
//             style: const TextStyle(
//               color: Colors.black, // 🔥 selected text color
//               fontSize: 13,
//             ),
//
//             items: options.map((e) {
//               return DropdownMenuItem(
//                 value: e,
//                 child: Text(
//                   e,
//                   style: const TextStyle(
//                     color: Colors.black,
//                   ), // 🔥 list text black
//                 ),
//               );
//             }).toList(),
//
//             onChanged: (val) {
//               item["sale_labour_formula"] = val ?? "Per Net Weight";
//
//               calculateItem(item); // 🔥 IMPORTANT
//               // updateFinalItems();
//
//               setState(() {}); // 🔥 MUST
//             },
//
//             decoration: InputDecoration(
//               isDense: true,
//               contentPadding: const EdgeInsets.symmetric(
//                 horizontal: 2,
//                 vertical: 5,
//               ),
//
//               filled: true,
//               fillColor: Colors.white,
//
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(6),
//                 borderSide: BorderSide(color: Colors.white),
//               ),
//
//               enabledBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(6),
//                 borderSide: BorderSide(color: Colors.white),
//               ),
//
//               focusedBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(6),
//                 borderSide: BorderSide(color: Colors.white),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget buildSummaryRow() {
//     final totals = calculateTotals();
//
//     // ✅ Total Amount → Pending Amount controller માં set કરો
//
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
//       decoration: BoxDecoration(
//         color:AppColors.background,
//         border: Border.all(color: AppColors.border,width: 1.5),
//         borderRadius: BorderRadius.circular(6),
//       ),
//       child: SingleChildScrollView(
//         scrollDirection: Axis.horizontal,
//         child: Row(
//           children: [
//             _summaryBox("Items", "${searchResults.length}"),
//             _summaryBox("Gross", totals["gross"]!.toStringAsFixed(3)),
//             _summaryBox("Other", totals["other"]!.toStringAsFixed(3)),
//             _summaryBox("Net", totals["net"]!.toStringAsFixed(3)),
//
//             _summaryBox("Purity", totals["purity"]!.toStringAsFixed(2)),
//             _summaryBox("Waste", totals["waste"]!.toStringAsFixed(2)),
//             _summaryBox("Net Purity", totals["netPurity"]!.toStringAsFixed(2)),
//
//             _summaryBox("Fine", totals["fine"]!.toStringAsFixed(3)),
//
//             _summaryBox("Metal Rate", totals["metalRate"]!.toStringAsFixed(2)),
//             _summaryBox("Metal Amt", totals["metal"]!.toStringAsFixed(2)),
//
//             _summaryBox(
//               "Labour Rate",
//               totals["sale_labour_rate"]!.toStringAsFixed(2),
//             ),
//             _summaryBox("Labour Amt", totals["sale_labour_amount"]!.toStringAsFixed(2)),
//
//             _summaryBox("Other Amt", totals["otherAmt"]!.toStringAsFixed(2)),
//             _summaryBox("Total", totals["total"]!.toStringAsFixed(2)),
//           ],
//         ),
//       ),
//     );
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
//     for (var item in searchResults) {
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
//           double.tryParse(item["sale_labour_rate"]?.toString() ?? "0") ?? 0;
//       labour += double.tryParse(item["sale_labour_amount"]?.toString() ?? "0") ?? 0;
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
//       // 🔥 Change Here
//       "sale_labour_rate": labourRate,
//       "sale_labour_amount": labour,
//       "otherAmt": otherAmt,
//       "total": total,
//     };
//   }
//
//   bool _isBlankRow(Map<String, dynamic> row) {
//     final double gross =
//         double.tryParse(
//           row["gross_weight"]?.toString() ?? "",
//         ) ??
//             0;
//
//     final double other =
//         double.tryParse(
//           row["other_weight"]?.toString() ?? "",
//         ) ??
//             0;
//
//     final double metalRate =
//         double.tryParse(
//           row["metal_rate"]?.toString() ?? "",
//         ) ??
//             0;
//
//     final double labourRate =
//         double.tryParse(
//           row["sale_labour_rate"]?.toString() ?? "",
//         ) ??
//             0;
//
//     final double saleOther =
//         double.tryParse(
//           row["sale_other"]?.toString() ?? "",
//         ) ??
//             0;
//
//     final String supplier =
//         row["supplier_person"]?.toString().trim() ?? "";
//
//     final String huid =
//         row["huid"]?.toString().trim() ?? "";
//
//     final String size =
//         row["size"]?.toString().trim() ?? "";
//
//     return gross == 0 &&
//         other == 0 &&
//         metalRate == 0 &&
//         labourRate == 0 &&
//         saleOther == 0 &&
//         supplier.isEmpty &&
//         huid.isEmpty &&
//         (size.isEmpty || size == "0");
//   }
//
//   Widget _imageUploadField(Map<String, dynamic> item) {
//     // 🔥 API response ma "image_url" hoy to e j use karo, nahi to local path
//     final String? imageUrl   = item["image_url"]?.toString();
//     final String? localPath  = item["item_image"]?.toString();
//
//     // Jo server URL hoy to e, nahi to local preview path
//     final String? displayPath =
//     (imageUrl != null && imageUrl.trim().isNotEmpty)
//         ? imageUrl
//         : (localPath != null && localPath.trim().isNotEmpty)
//         ? localPath
//         : null;
//
//     final bool hasImage = displayPath != null;
//
//     final String heroTag = "item_image_${item["id"]}";
//
//     final String itemNameForPreview =
//     item["item_name"]?.toString().trim().isNotEmpty == true
//         ? item["item_name"].toString()
//         : selectedItemName.isNotEmpty
//         ? selectedItemName
//         : "Item";
//
//     final String qrCodeForPreview =
//     item["item_code"]?.toString().trim().isNotEmpty == true
//         ? item["item_code"].toString()
//         : selectedItemCode;
//
//     return Container(
//       width: 44,
//       margin: const EdgeInsets.only(right: 7),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // TITLE
//           const Padding(
//             padding: EdgeInsets.only(left: 2, bottom: 4),
//             child: Text(
//               "Image",
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//               style: TextStyle(
//                 fontSize: 10,
//                 color: Colors.black54,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           ),
//
//           // IMAGE BUTTON
//           GestureDetector(
//             // 🔥 SINGLE TAP → image pick/change
//             onTap: () async {
//               FocusManager.instance.primaryFocus?.unfocus();
//               await _pickItemImage(item);
//             },
//
//             // 🔥 DOUBLE TAP → full screen preview (image hoy tyare j)
//             onDoubleTap: hasImage
//                 ? () {
//               FocusManager.instance.primaryFocus?.unfocus();
//               _openPremiumImagePreview(
//                 imageUrl: displayPath!,
//                 itemName: itemNameForPreview,
//                 qrCode: qrCodeForPreview,
//                 heroTag: heroTag,
//               );
//             }
//                 : null,
//
//             child: Container(
//               height: 36,
//               width: 36,
//               clipBehavior: Clip.antiAlias,
//               decoration: BoxDecoration(
//                 color: Colors.grey.shade50,
//                 borderRadius: BorderRadius.circular(5),
//                 border: Border.all(color: AppColors.border),
//               ),
//               child: hasImage
//                   ? Hero(
//                 tag: heroTag,
//                 child: Stack(
//                   fit: StackFit.expand,
//                   children: [
//                     // 🔥 Server URL hoy to NetworkImage, local hoy to FileImage
//                     Image(
//                       image: displayPath!.startsWith("http")
//                           ? NetworkImage(displayPath) as ImageProvider
//                           : FileImage(File(displayPath)),
//                       fit: BoxFit.cover,
//                       errorBuilder: (_, __, ___) => const Center(
//                         child: Icon(
//                           Icons.broken_image_outlined,
//                           size: 16,
//                           color: Colors.black45,
//                         ),
//                       ),
//                     ),
//
//                     // EDIT BADGE
//                     Positioned(
//                       right: 1,
//                       bottom: 1,
//                       child: Container(
//                         padding: const EdgeInsets.all(2),
//                         decoration: const BoxDecoration(
//                           color: Color(0xffC8A96A),
//                           shape: BoxShape.circle,
//                         ),
//                         child: const Icon(
//                           Icons.edit,
//                           size: 9,
//                           color: Colors.white,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               )
//                   : const Center(
//                 child: Icon(
//                   Icons.camera_alt_outlined,
//                   size: 16,
//                   color: Colors.black45,
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
//   /// 🔥 IMAGE PICKER — gallery/camera choose karvanu
//   /// =========================================================
//   Future<void> _pickItemImage(Map<String, dynamic> item) async {
//     final ImageSource? source = await showModalBottomSheet<ImageSource>(
//       context: context,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
//       ),
//       builder: (ctx) {
//         return SafeArea(
//           child: Wrap(
//             children: [
//               ListTile(
//                 leading: const Icon(Icons.photo_camera_outlined),
//                 title: const Text("Camera"),
//                 onTap: () => Navigator.pop(ctx, ImageSource.camera),
//               ),
//               ListTile(
//                 leading: const Icon(Icons.photo_library_outlined),
//                 title: const Text("Gallery"),
//                 onTap: () => Navigator.pop(ctx, ImageSource.gallery),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//
//     if (source == null) return;
//
//     final ImagePicker picker = ImagePicker();
//     final XFile? picked = await picker.pickImage(
//       source: source,
//       imageQuality: 75,
//     );
//
//     if (picked == null) return;
//
//     final File imageFile = File(picked.path);
//
//     /// 🔥 Local preview tatkal batavva mate (upload thai tya sudhi)
//     item["item_image"] = picked.path;
//     if (mounted) setState(() {});
//
//     /// 🔥 API CALL — tamara existing pattern pramane
//     await _uploadItemImage(item, imageFile);
//   }
//
//   /// =========================================================
//   /// 🔥 UPLOAD IMAGE API
//   /// POST -> https://ornasphere.com/api/item-sets/upload-image
//   /// Fields: image (file), item_id, gross_weight, other, net_weight
//   /// =========================================================
//   Future<void> _uploadItemImage(
//       Map<String, dynamic> item,
//       File imageFile,
//       ) async {
//     try {
//       FocusManager.instance.primaryFocus?.unfocus();
//
//       // 🔥 Jo item ma already image_upload_url hoy to e use karo
//       // nahi to selected item thi banavo
//       String uploadUrl = item["image_upload_url"]?.toString() ?? "";
//
//       if (uploadUrl.isEmpty) {
//         if (selectedItem == null || selectedItem!.isEmpty) {
//           AppMessage.error(context, "Please select item first");
//           return;
//         }
//         final int itemId = int.tryParse(selectedItem!) ?? 0;
//         if (itemId <= 0) {
//           AppMessage.error(context, "Invalid item ID");
//           return;
//         }
//         uploadUrl = ApiConstants.itemSetUploadImage;
//       }
//
//       final String fileName = imageFile.path.split("/").last;
//
//       final FormData formData = FormData.fromMap({
//         "image": await MultipartFile.fromFile(
//           imageFile.path,
//           filename: fileName,
//         ),
//         "item_id": selectedItem ?? "",
//         "gross_weight":
//         double.tryParse(item["gross_weight"]?.toString() ?? "0").toString(),
//         "other":
//         double.tryParse(item["other_weight"]?.toString() ?? "0").toString(),
//         "net_weight":
//         double.tryParse(item["net_weight"]?.toString() ?? "0").toString(),
//       });
//
//       debugPrint("📤 UPLOAD URL => $uploadUrl");
//       debugPrint("📤 FILE => ${imageFile.path}");
//
//       final response = await ApiHelper().postRequest(uploadUrl, formData);
//
//       debugPrint("📥 UPLOAD RESPONSE => ${response?.data}");
//
//       if (!mounted) return;
//
//       if (response != null &&
//           (response.statusCode == 200 || response.statusCode == 201)) {
//
//         // 🔥 Response ma image_url, image_upload_url, image_show_url badhu set karo
//         final responseData = response.data?["data"];
//         if (responseData != null) {
//           item["image_url"]        = responseData["image_url"]?.toString() ?? "";
//           item["image_upload_url"] = responseData["image_upload_url"]?.toString() ?? "";
//           item["image_show_url"]   = responseData["image_show_url"]?.toString() ?? "";
//           // Local path hatu e hata rakho (fallback mate)
//           item["item_image"]       = item["image_url"];
//         }
//
//         AppMessage.success(
//           context,
//           response.data?["message"] ?? "Image uploaded successfully",
//         );
//
//         if (mounted) setState(() {});
//       } else {
//         AppMessage.error(
//           context,
//           response?.data?["message"] ?? "Image upload failed",
//         );
//       }
//     } catch (e) {
//       debugPrint("❌ IMAGE UPLOAD ERROR => $e");
//       if (!mounted) return;
//       AppMessage.error(context, "Image upload failed");
//     }
//   }
//
//   void _openPremiumImagePreview({
//     required String imageUrl,
//     required String itemName,
//     required String qrCode,
//     required String heroTag,
//   }) {
//     showGeneralDialog(
//       context: context,
//
//       barrierDismissible: true,
//       barrierLabel: "Image Preview",
//
//       barrierColor: Colors.black.withOpacity(0.92),
//
//       transitionDuration: const Duration(
//         milliseconds: 280,
//       ),
//
//       pageBuilder: (
//           context,
//           animation,
//           secondaryAnimation,
//           ) {
//         return Material(
//           color: Colors.transparent,
//           child: SafeArea(
//             child: Stack(
//               children: [
//                 /// =============================================
//                 /// FULL IMAGE
//                 /// =============================================
//                 Positioned.fill(
//                   child: Center(
//                     child: Hero(
//                       tag: heroTag,
//                       child: InteractiveViewer(
//                         minScale: 0.8,
//                         maxScale: 5.0,
//                         panEnabled: true,
//                         scaleEnabled: true,
//                         child: Image.network(
//                           imageUrl,
//                           width: double.infinity,
//                           height: double.infinity,
//                           fit: BoxFit.contain,
//
//                           loadingBuilder: (
//                               context,
//                               child,
//                               loadingProgress,
//                               ) {
//                             if (loadingProgress == null) {
//                               return child;
//                             }
//
//                             return const Center(
//                               child: CircularProgressIndicator(
//                                 color: Colors.white,
//                                 strokeWidth: 2.5,
//                               ),
//                             );
//                           },
//
//                           errorBuilder: (
//                               context,
//                               error,
//                               stackTrace,
//                               ) {
//                             return const Center(
//                               child: Column(
//                                 mainAxisSize: MainAxisSize.min,
//                                 children: [
//                                   Icon(
//                                     Icons.broken_image_outlined,
//                                     size: 55,
//                                     color: Colors.white54,
//                                   ),
//                                   SizedBox(height: 10),
//                                   Text(
//                                     "Unable to load image",
//                                     style: TextStyle(
//                                       color: Colors.white70,
//                                       fontSize: 14,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             );
//                           },
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//
//                 /// =============================================
//                 /// TOP BAR
//                 /// =============================================
//                 Positioned(
//                   top: 12,
//                   left: 14,
//                   right: 14,
//                   child: Row(
//                     children: [
//                       /// Item details
//                       Expanded(
//                         child: Container(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 14,
//                             vertical: 10,
//                           ),
//                           decoration: BoxDecoration(
//                             color: Colors.black.withOpacity(0.45),
//                             borderRadius: BorderRadius.circular(12),
//                             border: Border.all(
//                               color: Colors.white.withOpacity(0.12),
//                             ),
//                           ),
//                           child: Column(
//                             crossAxisAlignment:
//                             CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 itemName.isEmpty
//                                     ? "Item Image"
//                                     : itemName,
//                                 maxLines: 1,
//                                 overflow:
//                                 TextOverflow.ellipsis,
//                                 style: const TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 15,
//                                   fontWeight: FontWeight.w700,
//                                 ),
//                               ),
//
//                               if (qrCode.isNotEmpty) ...[
//                                 const SizedBox(height: 3),
//
//                                 Text(
//                                   "Label: $qrCode",
//                                   maxLines: 1,
//                                   overflow:
//                                   TextOverflow.ellipsis,
//                                   style: TextStyle(
//                                     color: Colors.white
//                                         .withOpacity(0.65),
//                                     fontSize: 11,
//                                   ),
//                                 ),
//                               ],
//                             ],
//                           ),
//                         ),
//                       ),
//
//                       const SizedBox(width: 10),
//
//                       /// CLOSE
//                       InkWell(
//                         onTap: () {
//                           Navigator.pop(context);
//                         },
//                         borderRadius:
//                         BorderRadius.circular(50),
//                         child: Container(
//                           width: 44,
//                           height: 44,
//                           decoration: BoxDecoration(
//                             color: Colors.black.withOpacity(0.45),
//                             shape: BoxShape.circle,
//                             border: Border.all(
//                               color: Colors.white.withOpacity(0.15),
//                             ),
//                           ),
//                           child: const Icon(
//                             Icons.close_rounded,
//                             color: Colors.white,
//                             size: 24,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//
//                 /// =============================================
//                 /// BOTTOM HINT
//                 /// =============================================
//                 Positioned(
//                   left: 0,
//                   right: 0,
//                   bottom: 20,
//                   child: Center(
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 14,
//                         vertical: 8,
//                       ),
//                       decoration: BoxDecoration(
//                         color: Colors.black.withOpacity(0.45),
//                         borderRadius: BorderRadius.circular(20),
//                         border: Border.all(
//                           color: Colors.white.withOpacity(0.10),
//                         ),
//                       ),
//                       child: const Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           Icon(
//                             Icons.pinch_outlined,
//                             color: Colors.white70,
//                             size: 16,
//                           ),
//
//                           SizedBox(width: 6),
//
//                           Text(
//                             "Pinch to zoom",
//                             style: TextStyle(
//                               color: Colors.white70,
//                               fontSize: 11,
//                               fontWeight: FontWeight.w500,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//
//       /// =====================================================
//       /// PREMIUM OPEN ANIMATION
//       /// =====================================================
//       transitionBuilder: (
//           context,
//           animation,
//           secondaryAnimation,
//           child,
//           ) {
//         final curvedAnimation = CurvedAnimation(
//           parent: animation,
//           curve: Curves.easeOutCubic,
//           reverseCurve: Curves.easeInCubic,
//         );
//
//         return FadeTransition(
//           opacity: curvedAnimation,
//           child: ScaleTransition(
//             scale: Tween<double>(
//               begin: 0.94,
//               end: 1.0,
//             ).animate(curvedAnimation),
//             child: child,
//           ),
//         );
//       },
//     );
//   }
//
//   /// =========================================================
//   /// 🔥 FETCH ITEM IMAGE + OPEN PREVIEW
//   /// GET -> https://ornasphere.com/api/itemsets_image/{item_id}
//   /// =========================================================
//   Future<void> _fetchAndPreviewItemImage(Map<String, dynamic> item) async {
//     /// 🔥 FIX: selectedItem NAHI — upload response no id vaparvanu
//     final String? imageId = item["id"]?.toString();
//
//     // if (imageId == null || imageId.trim().isEmpty) {
//     //   AppMessage.error(context, "Please upload an image first");
//     //   return;
//     // }
//
//     /// LOADER
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => const Center(child: CircularProgressIndicator()),
//     );
//
//     final response = await ApiHelper().getRequest(
//       "${ApiConstants.itemSetImage}/$imageId", // 🔥 TODO: ApiConstants ma add karjo
//     );
//
//     if (!mounted) return;
//     Navigator.pop(context); // 🔥 LOADER CLOSE
//
//     if (response != null && response.statusCode == 200) {
//       final data = response.data;
//
//       /// 🔥 TODO: response structure pramane key adjust karjo
//       final String? imageUrl = data["data"]?["image_url"]?.toString() ??
//           data["data"]?["image"]?.toString() ??
//           data["image_url"]?.toString() ??
//           data["url"]?.toString();
//
//       if (imageUrl == null || imageUrl.trim().isEmpty) {
//         AppMessage.error(context, "No image found for this item");
//         return;
//       }
//
//       final String itemNameForPreview =
//       item["item_name"]?.toString().trim().isNotEmpty == true
//           ? item["item_name"].toString()
//           : selectedItemName.isNotEmpty
//           ? selectedItemName
//           : "Item";
//
//       final String qrCodeForPreview =
//       item["item_code"]?.toString().trim().isNotEmpty == true
//           ? item["item_code"].toString()
//           : item["code"]?.toString().trim().isNotEmpty == true
//           ? item["code"].toString()
//           : selectedItemCode;
//
//       //labelSearchFocusNode.unfocus();
//       FocusManager.instance.primaryFocus?.unfocus();
//
//       _openPremiumImagePreview(
//         imageUrl: imageUrl,
//         itemName: itemNameForPreview,
//         qrCode: qrCodeForPreview,
//         heroTag: "item_image_${item["id"]}",
//       );
//     } else {
//       AppMessage.error(
//         context,
//         response?.data?["message"] ?? "Failed to load image",
//       );
//     }
//   }
// }


import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pecifician_sysytem/Item_Mangement/Item/ItemScreen.dart';
import 'package:pecifician_sysytem/Item_Mangement/Label/CreateLabelScreen.dart';
import 'package:pecifician_sysytem/Item_Mangement/Label_Items/label_item_screen.dart';
import 'package:pecifician_sysytem/User/CreteUserScreen.dart';
import 'package:provider/provider.dart';
import '../../Api_Constant/ApiConstants.dart';
import '../../Api_Constant/api_helper.dart';
import '../../Extra/AppColors.dart';
import '../../Extra/AppMessage.dart';
import '../../Extra/ItemProvider.dart';
import '../../Extra/PremiumSearchableDropdown.dart';
import '../../Offline Data/offline_api_helper.dart';

class CreateLabelScreen extends StatefulWidget {
  const CreateLabelScreen({super.key});

  @override
  State<CreateLabelScreen> createState() => CreateLabelScreenState();
}

class CreateLabelScreenState extends State<CreateLabelScreen> {
  final TextEditingController Carat_Controller = TextEditingController();
  final TextEditingController purity_Controller = TextEditingController();
  List userlist = [];
  String? selectedItem;
  String? imageId;
  List<Map<String, dynamic>> tableRows = [];
  Timer? _huidTimer;
  int apiRowCount = 0;
  List searchResults = [];

  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> allItems = [];
  Timer? _grossTimer;
  Map<String, Timer> rowTimers = {};
  Map<String, dynamic>? selectedItemData;
  String selectedItemName = "";
  String selectedItemCode = "";
  bool _isSaving = false;
  Set<String> triggerFields = {
    "gross_weight",
    "other_weight",
    "net_weight",
    "sale_labour_formula",
    "metal_rate",
    "metal_amount",
    "labour_rate",
    "labour_amount",
    "sale_other",
    "supplier_person",
    "size",
    "huid",
    "total_amount",
  };

  Map<String, dynamic> _defaultItem() {
    return {
      "id": DateTime.now().microsecondsSinceEpoch.toString(),

      "gross_weight": "",
      "other": "",
      "net_weight": "",
      "sale_labour_formula": "",
      "metal_rate": "",
      "metal_amount": "",
      "sale_labour_rate": "",
      "sale_labour_amount": "",
      "sale_other": "",
      "supplier_person": "",
      "size": "",
      "huid": "",
      "total_amount": "",
    };
  }
  Map<String, FocusNode> focusNodes = {}; // ✅ ADD THIS
  FocusNode getFocusNode(Map item, String key) {
    final uniqueKey = "${item["id"]}_$key";
    if (!focusNodes.containsKey(uniqueKey)) {
      focusNodes[uniqueKey] = FocusNode();
    }
    return focusNodes[uniqueKey]!;
  }
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<ItemProvider>(context, listen: false).loadItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final height = size.height;
    final width = size.width;
    final isMobile = width < 600;
    return Scaffold(
      //resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.white,
      body: Stack(
        children: [

          Column(
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top + 40),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
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

                      searchResults.isEmpty
                          ? const Padding(
                        padding: EdgeInsets.only(top: 50),
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
                          :ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          12,
                          10,
                          12,
                          12,
                        ),
                        shrinkWrap: true, // 🔥 Important
                        physics: const NeverScrollableScrollPhysics(), // 🔥 Important
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          return approvalItemCard(
                            searchResults[index],
                            index,
                          );
                        },
                      ),

                      // 🔥 Save button જેટલી height નું space
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),

              /// SUMMARY BOX
              buildSummaryRow(),

              /// SAVE BUTTON
              Container(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isSaving ? null : savefinalizeBulkItems,
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
                      child: const Center(
                        child: Text(
                          "Save Label Item",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // AppBar
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
                  const Text(
                    "Create Label Item",
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
                      onTap: () => Navigator.pop(context, true),
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
                ],
              ),
            ),
          ),

        ],
      ),

    );
  }

  // ... (Other functions loadItemDetails, filterWidget, etc. remain the same)

  Future<void> saveBulkItems() async {
    if (selectedItem == null) return;
    List<Map<String, dynamic>> rows = [];
    for (int i = apiRowCount; i < searchResults.length; i++) {
      var row = searchResults[i];

      rows.add({
        "temp_id": row["id"], // ⭐ IMPORTANT (mapping key)

        "gross_weight":
        double.tryParse((row["gross_weight"] ?? "").toString()) ?? 0,

        // 🔥 OTHER WEIGHT — sent to API as-is
        "other_weight":
        double.tryParse((row["other_weight"] ?? "").toString()) ?? 0,

        "net_weight":
        double.tryParse((row["net_weight"] ?? "").toString()) ?? 0,

        "sale_labour_formula": (row["sale_labour_formula"] ?? "").toString(),

        "metal_rate":
        double.tryParse((row["metal_rate"] ?? "").toString()) ?? 0,
        "metal_amount":
        double.tryParse((row["metal_amount"] ?? "").toString()) ?? 0,

        "labour_rate":
        double.tryParse((row["sale_labour_rate"] ?? "").toString()) ?? 0,
        "labour_amount":
        double.tryParse((row["sale_labour_amount"] ?? "").toString()) ?? 0,

        // 🔥 OTHER AMOUNT (sale_other) — sent to API as-is
        "sale_other":
        double.tryParse((row["sale_other"] ?? "").toString()) ?? 0,

        "supplier_person": (row["supplier_person"] ?? "").toString(),

        "size": int.tryParse((row["size"] ?? "").toString()) ?? 0,

        "HUID": (row["huid"] ?? "").toString(),

        "total_amount":
        double.tryParse((row["total_amount"] ?? "").toString()) ?? 0,
      });
    }

    Map<String, dynamic> body = {
      "item_id": int.parse(selectedItem!),
      "rows": rows,
    };

    print("📤 REQUEST BODY: $body");

    try {
      final response = await ApiHelper().postRequest(
        ApiConstants.multiple_items_label_configs,
        body,
        showLoading: false,
      );

      if (response != null && response.statusCode == 200) {
        final List responseRows = response.data["data"];

        // 🔥 SYNC BACKEND IDS WITH FRONTEND
        setState(() {
          for (int i = 0; i < responseRows.length; i++) {
            final backendRow = responseRows[i];
            final tempId = backendRow["temp_id"];

            int index = searchResults.indexWhere(
                  (row) => row["id"]?.toString() == tempId?.toString(),
            );

            if (index != -1) {
              final oldRow = Map<String, dynamic>.from(searchResults[index]);

              // 🔥 IMPORTANT: local UI id (controllers/focusNodes key) preserve karo
              final String localId = oldRow["id"].toString();

              final newRow = Map<String, dynamic>.from(backendRow);
              newRow["id"] = localId;                     // local id j rakho (UI keys tutya nahi)
              newRow["backend_id"] = backendRow["id"];     // real backend row id store karo

              // 🔥 IMAGE URLS — aa j missing hatu
              newRow["image_upload_url"] = backendRow["image_upload_url"];
              newRow["image_show_url"]   = backendRow["image_show_url"];
              newRow["image_delete_url"] = backendRow["image_delete_url"];
              newRow["image_url"]        = backendRow["image_url"];

              newRow["temp_id"] = tempId;

              searchResults[index] = {...oldRow, ...newRow};
            }
          }
        });

        //await savefinalizeBulkItems();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Multiple rows saved successfully")),
        );
      } else {
        final String message =
            response?.data?["message"]?.toString() ??
                "Failed to Save Data";

        AppMessage.error(
          context,
          message,
        );
      }
    } catch (e) {
      print("❌ ERROR: $e");

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Something went wrong")));
    }
  }

  Future<void> savefinalizeBulkItems() async {
    /// 🔥 પહેલેથી call ચાલુ હોય તો બીજી વાર નહીં
    if (_isSaving) return;

    if (selectedItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select item")),
      );
      return;
    }

    final int? itemId = int.tryParse(selectedItem!);
    if (itemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid item")),
      );
      return;
    }

    setState(() => _isSaving = true);

    final Map<String, dynamic> body = {"item_id": itemId};
    debugPrint("📤 REQUEST BODY: $body");

    try {
      final response = await OfflineApiHelper.instance.postRequest(
        ApiConstants.finalize_items_label_configs,
        body,
      );

      if (!mounted) return;

      final int? status = response?.statusCode;

      if (status == 200 || status == 202) {
        if (status == 202) {
          AppMessage.success(context, "No Internet. Update saved offline.");
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Saved successfully")),
          );
        }

        /// Success → screen બદલાય છે, એટલે button disable જ રહેવા દો
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const label_item_screen()),
              (route) => route.isFirst,
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to Save Data")),
      );
      setState(() => _isSaving = false);
    } catch (e) {
      debugPrint("❌ Finalize Error => $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to Save Data")),
      );
      setState(() => _isSaving = false);
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
          SizedBox(
            width: double.infinity,
            child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: Consumer<ItemProvider>(
                  builder: (context, provider, child) {
                    final List<Map<String, dynamic>> itemList = provider.items
                        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
                        .toList();

                    Map<String, dynamic>? currentItem;

                    if (selectedItem != null) {
                      for (final item in itemList) {
                        if (item["id"]?.toString() == selectedItem.toString()) {
                          currentItem = item;
                          break;
                        }
                      }
                    }

                    return Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        PremiumItemSearchDropdown(
                          label: "",
                          hint: "Select Item",
                          items: itemList,
                          value: currentItem,
                          requiredField: true,
                          width: double.infinity,
                          onChanged: (item) => _setItem(item),
                        ),

                        /// ❌ CLEAR — item select હોય ત્યારે જ
                        if (currentItem != null)
                          Positioned(
                            right: 40, // 🔥 arrow થી અંતર — જરૂર મુજબ 32–48 કરો
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  _setItem(null);
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
                  },
                ),
            ),
          ),

          const SizedBox(height: 5),

          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  context,
                  "Carat",
                  controller: Carat_Controller,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTextField(
                  context,
                  "Purity",
                  controller: purity_Controller,
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
                  onTap: () {},
                  borderRadius: BorderRadius.circular(8),
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

  Widget _buildTextField(
      BuildContext context,
      String label, {
        String? hint,
        TextEditingController? controller,
      }) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width > 700;
    final isDesktop = width >= 1000;

    double fontSize = isDesktop
        ? 16
        : isTablet
        ? 14
        : 13;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2.0),
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ),

        SizedBox(height: isTablet ? 6 : 5),

        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 14 : 10,
            vertical: isTablet ? 4 : 2,
          ),
          decoration: BoxDecoration(
            color:AppColors.background,
            border: Border.all(color: AppColors.border,width: 1.5),
            borderRadius: BorderRadius.circular(6),
          ),

          child: TextField(
            controller: controller,
            style: TextStyle(fontSize: fontSize, color: Colors.black),

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

  Widget approvalItemCard(
      Map<String, dynamic> item,
      int index,
      ) {
    final bool isExpanded = item["expanded"] ?? false;

    final String itemName =
    item["item_name"]?.toString().trim().isNotEmpty == true
        ? item["item_name"].toString()
        : selectedItemName.isNotEmpty
        ? selectedItemName
        : "Item";

    final String itemCode =
    item["item_code"]?.toString().trim().isNotEmpty == true
        ? item["item_code"].toString()
        : item["code"]?.toString().trim().isNotEmpty == true
        ? item["code"].toString()
        : selectedItemCode.isNotEmpty
        ? selectedItemCode
        : "-";

    return Container(
      key: ValueKey(
        item["itemset_id"] ??
            item["id"] ??
            index,
      ),
      margin: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: AppColors.border,
        ),
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
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.gradientBlue,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    "${searchResults.length - index}",
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

                Container(
                  constraints: const BoxConstraints(
                    maxWidth: 130,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: AppColors.border,
                    ),
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
                          itemCode,
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

                InkWell(
                  onTap: () {
                    setState(() {
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
                        colors: [
                          Color(0xffFF8A80),
                          Color(0xffD32F2F),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
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

          if (!isExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(
                10,
                8,
                10,
                9,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.manual,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _miniField(
                      "Gross",
                      item,
                      "gross_weight",
                    ),

                    _miniField(
                      "Other Wt",
                      item,
                      "other_weight",
                    ),

                    _miniField(
                      "Net",
                      item,
                      "net_weight",
                    ),

                    _miniField(
                      "Labour Formula",
                      item,
                      "sale_labour_formula",
                    ),

                    _miniField(
                      "Metal Rate",
                      item,
                      "metal_rate",
                    ),

                    _miniField(
                      "Metal Amount",
                      item,
                      "metal_amount",
                    ),

                    _miniField(
                      "Labor Rate",
                      item,
                      "sale_labour_rate",
                    ),

                    _miniField(
                      "Labour Amount",
                      item,
                      "sale_labour_amount",
                    ),

                    _miniField(
                      "Sale Other",
                      item,
                      "sale_other",
                    ),

                    _miniField(
                      "Supplier Person",
                      item,
                      "supplier_person",
                    ),

                    _miniField(
                      "Size",
                      item,
                      "size",
                    ),

                    _miniField(
                      "HUID",
                      item,
                      "huid",
                    ),
                    _imageUploadField(item),
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
      ) {
    final bool isOtherField = key == "other_weight";
    final bool isMetalRateField = key == "metal_rate";
    final bool isLabourRateField = key == "sale_labour_rate";

    final controller = getController(item, key);

    if (key == "sale_labour_formula") {
      return _labourDropdown(item);
    }

    final bool editable = isEditableField(key);
    final bool canEdit = isEditableField(key);

    return Container(
      width: 105,
      margin: const EdgeInsets.only(
        right: 7,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: 2,
              bottom: 4,
            ),
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

          Container(
            height: 36,
            decoration: BoxDecoration(
              color: editable
                  ? Colors.white
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: AppColors.border,
              ),
            ),
            child: Stack(
              alignment: Alignment.centerRight,
              children: [
                TextFormField(
                  controller: controller,
                  focusNode: getFocusNode(
                    item,
                    key,
                  ),

                  readOnly: !canEdit,

                  keyboardType:
                  const TextInputType.numberWithOptions(
                    decimal: true,
                  ),

                  textInputAction: TextInputAction.done,

                  enableInteractiveSelection: canEdit,
                  showCursor: canEdit,
                  canRequestFocus: canEdit,

                  textAlign: TextAlign.left,

                  style: TextStyle(
                    color: editable
                        ? Colors.black
                        : Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),

                  onTap: () {
                    if (!canEdit) {
                      return;
                    }

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

                  onChanged: (val) {
                    // ============================================================
                    // UPDATE CURRENT ROW
                    // ============================================================
                    item[key] = val;

                    // ============================================================
                    // CALCULATE CURRENT ROW
                    // ============================================================
                    calculateItem(item);

                    if (mounted) {
                      setState(() {});
                    }

                    // ============================================================
                    // AUTO SAVE ONLY FOR TRIGGER FIELDS
                    // ============================================================
                    if (triggerFields.contains(key)) {
                      final String rowId = item["id"]?.toString() ?? "";

                      if (rowId.isEmpty) {
                        debugPrint("⚠️ ROW ID EMPTY - AUTO SAVE SKIPPED");
                        return;
                      }

                      final String timerKey = "${rowId}_$key";

                      rowTimers[timerKey]?.cancel();

                      debugPrint(
                        "⏳ TIMER RESET => row=$rowId field=$key",
                      );

                      rowTimers[timerKey] = Timer(
                        const Duration(seconds: 2),
                            () async {
                          rowTimers.remove(timerKey);

                          if (!mounted) return;

                          debugPrint(
                            "🔥 AUTO SAVE => row=$rowId field=$key",
                          );

                          await saveBulkItems();

                          if (!mounted) return;

                          final bool blankRowAlreadyExists =
                          searchResults.any((row) {
                            return _isBlankRow(row);
                          });

                          if (!blankRowAlreadyExists) {
                            final newItem = _defaultItem();

                            setState(() {
                              searchResults.insert(
                                0,
                                newItem,
                              );
                            });

                            debugPrint(
                              "➕ NEW BLANK ROW ADDED => ${newItem["id"]}",
                            );
                          } else {
                            debugPrint(
                              "ℹ️ BLANK ROW ALREADY EXISTS - NOT ADDED",
                            );
                          }
                        },
                      );
                    }
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

                /// =================================================
                /// OTHER WEIGHT + BUTTON
                /// =================================================
                if (isOtherField)
                  Positioned(
                    right: 4,
                    child: InkWell(
                      onTap: () async {
                        FocusManager.instance.primaryFocus
                            ?.unfocus();

                        await getreturnDetails(
                          item["id"],
                          item,
                        );

                        Future.delayed(
                          const Duration(
                            milliseconds: 100,
                          ),
                              () {
                            FocusManager.instance.primaryFocus
                                ?.unfocus();
                          },
                        );

                        /// 🔥 FIX: Apply Charges popup sets
                        /// item["other_weight"] (not "other_amount",
                        /// which is never set for this screen). Reading
                        /// the wrong key here was resetting the field
                        /// back to "0" right after the popup applied
                        /// the correct value — that's why it looked
                        /// like "other weight doesn't save".
                        controller.text =
                            item["other_weight"]?.toString() ??
                                "0";

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
                          color: const Color(
                            0xffC8A96A,
                          ),
                          borderRadius:
                          BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

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

                              updateController(
                                item,
                                "metal_rate",
                              );

                              calculateItem(item);
                            });
                          },
                        ),
                      ),
                    ),
                  ),

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

                                item["sale_labour_rate"] =
                                "0.00";
                              } else {
                                if ((double.tryParse(
                                  controller.text.isEmpty
                                      ? "0"
                                      : controller.text,
                                ) ??
                                    0) ==
                                    0) {
                                  controller.clear();

                                  item["sale_labour_rate"] = "";
                                }
                              }

                              updateController(
                                item,
                                "sale_labour_rate",
                              );

                              calculateItem(item);
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

  Future<void> getApprovalDetails(
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

      final item = data["data"] is List ? data["data"][0] : data["data"];

      showOtherChargesPopup(
        mainItem,
        data["data"],
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to load details")));
    }
  }

  void showOtherChargesPopup(Map<String, dynamic> item, List apiList) {
    final int? existingChargeId = int.tryParse(
      item["other_charge_id"]?.toString() ?? "",
    );

    final double existingAmount = double.tryParse(
      item["sale_other"]?.toString() ?? "0",
    ) ??
        0;

    bool alreadyMatched = false;

    final List<Map<String, dynamic>> charges = apiList.map<Map<String, dynamic>>((e) {
      final String weightFormula =
      (e["weight_formula"] ?? "").toString().trim().toLowerCase();

      String wtFormula = "flat";

      if (weightFormula == "per_quantity" ||
          weightFormula == "per qty" ||
          weightFormula == "per_qty") {
        wtFormula = "per_qty";
      } else if (weightFormula == "per_weight" ||
          weightFormula == "per weight" ||
          weightFormula == "per_wt") {
        wtFormula = "per_weight";
      }

      final int chargeId = int.tryParse(e["id"]?.toString() ?? "") ?? 0;
      final double defaultAmount =
          double.tryParse(e["default_amount"]?.toString() ?? "0") ?? 0;

      bool isSelected = false;

      if (!alreadyMatched) {
        if (existingChargeId != null && existingChargeId == chargeId) {
          isSelected = true;
          alreadyMatched = true;
        } else if (existingChargeId == null &&
            existingAmount > 0 &&
            defaultAmount == existingAmount) {
          isSelected = true;
          alreadyMatched = true;
        }
      }

      return {
        "id": e["id"],
        "charge": (e["name"] ?? "").toString(),
        "amount": (e["default_amount"] ?? 0).toString(),
        "qty": (e["quantity_pcs"] ?? 1).toString(),
        "weight": (e["default_weight"] ?? 0).toString(),
        "wt_formula": wtFormula,
        "amt_formula_type": "flat",
        "amt_formula": "",
        "total_weight": "0.00",
        "total_amt": "0.00",
        "is_selected": isSelected,
      };
    }).toList();

    final Map<int, Map<String, TextEditingController>> rowControllers = {};

    for (int i = 0; i < charges.length; i++) {
      rowControllers[i] = {
        "amount": TextEditingController(text: charges[i]["amount"]?.toString() ?? "0"),
        "qty": TextEditingController(text: charges[i]["qty"]?.toString() ?? "1"),
        "weight": TextEditingController(text: charges[i]["weight"]?.toString() ?? "0"),
      };
    }

    void disposeControllers() {
      for (final ctrls in rowControllers.values) {
        for (final c in ctrls.values) {
          c.dispose();
        }
      }
    }

    void calculateSingleCharge(Map<String, dynamic> c) {
      final double amt = double.tryParse(c["amount"]?.toString() ?? "0") ?? 0;
      final double qty = double.tryParse(c["qty"]?.toString() ?? "1") ?? 1;
      final double weight = double.tryParse(c["weight"]?.toString() ?? "0") ?? 0;

      final String amtFormula = c["amt_formula_type"]?.toString() ?? "flat";
      final String wtFormula = c["wt_formula"]?.toString() ?? "flat";

      double totalAmt = 0;
      double totalWeight = 0;

      switch (wtFormula) {
        case "per_qty":
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

    int? initialSelectedIndex() {
      for (int i = 0; i < charges.length; i++) {
        if (charges[i]["is_selected"] == true) return i;
      }
      return null;
    }

    final ValueNotifier<double> totalNotifier = ValueNotifier<double>(calcTotal());
    final ValueNotifier<int?> selectedIndexNotifier =
    ValueNotifier<int?>(initialSelectedIndex());

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.50),
      builder: (dialogContext) {
        final Size screenSize = MediaQuery.of(dialogContext).size;
        final bool isTablet = screenSize.width >= 600;

        InputDecoration inputDecoration() {
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
              borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.4),
            ),
          );
        }

        Widget headerCell(String title, double width, {bool left = false}) {
          return SizedBox(
            width: width,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text(
                title,
                textAlign: left ? TextAlign.left : TextAlign.center,
                style: const TextStyle(
                  color: AppColors.primaryDark,
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
              color: AppColors.background,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppColors.primaryDark.withOpacity(0.14)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.20),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                            color: Colors.white.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(9),
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
                              Text("Manage additional item charges",
                                  style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.13),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text("${charges.length} Charges",
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            // 🔥 FIX: pop first, dispose controllers on the
                            // NEXT frame. Disposing controllers still
                            // attached to widgets in the same frame as
                            // Navigator.pop() races with the Overlay/
                            // InheritedElement teardown and can trigger
                            // Flutter's "_dependents.isEmpty" assertion.
                            Navigator.pop(dialogContext);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              disposeControllers();
                            });
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.13),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 29,
                                height: 29,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.iconBg,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: const Icon(Icons.tune_rounded, size: 16, color: AppColors.primaryDark),
                              ),
                              const SizedBox(width: 8),
                              const Text("Charge Details",
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                              const Spacer(),
                              ValueListenableBuilder<int?>(
                                valueListenable: selectedIndexNotifier,
                                builder: (context, selectedIndex, _) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.iconBg,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check_circle_outline_rounded, size: 13, color: AppColors.primaryDark),
                                        const SizedBox(width: 4),
                                        Text(
                                          "${selectedIndex != null ? 1 : 0} Selected",
                                          style: const TextStyle(
                                              color: AppColors.primaryDark, fontSize: 9.5, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 9),

                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
                            child: Container(
                              width: 900,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: AppColors.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.shadow,
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    height: 42,
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.iconBg,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(8),
                                        topRight: Radius.circular(8),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        headerCell("Charge", 110, left: true),
                                        headerCell("Amount", 90),
                                        headerCell("Qty", 70),
                                        headerCell("Weight", 90),
                                        headerCell("Wt Formula", 105),
                                        headerCell("Total Wt", 90),
                                        headerCell("Amt Formula", 115),
                                        headerCell("Total Amt", 105),
                                        const SizedBox(
                                          width: 45,
                                          child: Center(
                                            child: Icon(
                                              Icons.check_circle_outline_rounded,
                                              color: AppColors.primaryDark,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  Divider(height: 1, thickness: 1, color: AppColors.border),

                                  SizedBox(
                                    height: 230,
                                    child: charges.isEmpty
                                        ? const Center(
                                      child: Text(
                                        "No charges available",
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    )
                                        : ListView.separated(
                                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
                                      padding: const EdgeInsets.symmetric(vertical: 5),
                                      itemCount: charges.length,
                                      separatorBuilder: (context, index) {
                                        return Divider(height: 1, color: AppColors.border);
                                      },
                                      itemBuilder: (context, index) {
                                        final c = charges[index];

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
                                                        ? AppColors.primaryDark.withOpacity(0.035)
                                                        : Colors.white,
                                                    border: Border(
                                                      left: BorderSide(
                                                        color: selected ? AppColors.primaryDark : Colors.transparent,
                                                        width: 3,
                                                      ),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      SizedBox(
                                                        width: 110,
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
                                                                      ? AppColors.primaryDark.withOpacity(0.12)
                                                                      : AppColors.iconBg,
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
                                                                    color: AppColors.textPrimary,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),

                                                      SizedBox(
                                                        width: 90,
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 3),
                                                          child: TextFormField(
                                                            controller: rowControllers[index]!["amount"],
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w600,
                                                              color: AppColors.textPrimary,
                                                            ),
                                                            textAlign: TextAlign.center,
                                                            keyboardType:
                                                            const TextInputType.numberWithOptions(decimal: true),
                                                            decoration: inputDecoration(),
                                                            onChanged: (_) => onFieldChanged(),
                                                          ),
                                                        ),
                                                      ),

                                                      SizedBox(
                                                        width: 70,
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 3),
                                                          child: TextFormField(
                                                            controller: rowControllers[index]!["qty"],
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w600,
                                                              color: AppColors.textPrimary,
                                                            ),
                                                            textAlign: TextAlign.center,
                                                            keyboardType:
                                                            const TextInputType.numberWithOptions(decimal: true),
                                                            decoration: inputDecoration(),
                                                            onChanged: (_) => onFieldChanged(),
                                                          ),
                                                        ),
                                                      ),

                                                      SizedBox(
                                                        width: 90,
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 3),
                                                          child: TextFormField(
                                                            controller: rowControllers[index]!["weight"],
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w600,
                                                              color: AppColors.textPrimary,
                                                            ),
                                                            textAlign: TextAlign.center,
                                                            keyboardType:
                                                            const TextInputType.numberWithOptions(decimal: true),
                                                            decoration: inputDecoration(),
                                                            onChanged: (_) => onFieldChanged(),
                                                          ),
                                                        ),
                                                      ),

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
                                                              color: AppColors.primaryDark,
                                                              size: 17,
                                                            ),
                                                            style: const TextStyle(
                                                              fontSize: 10,
                                                              color: AppColors.textPrimary,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                            decoration: inputDecoration(),
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

                                                      SizedBox(
                                                        width: 90,
                                                        child: Center(
                                                          child: Text(
                                                            c["total_weight"]?.toString() ?? "0.00",
                                                            textAlign: TextAlign.center,
                                                            style: const TextStyle(
                                                              fontSize: 10.5,
                                                              fontWeight: FontWeight.w700,
                                                              color: AppColors.textPrimary,
                                                            ),
                                                          ),
                                                        ),
                                                      ),

                                                      SizedBox(
                                                        width: 115,
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 3),
                                                          child: DropdownButtonFormField<String>(
                                                            value: c["amt_formula_type"] ?? "flat",
                                                            isExpanded: true,
                                                            dropdownColor: Colors.white,
                                                            icon: const Icon(
                                                              Icons.keyboard_arrow_down_rounded,
                                                              color: AppColors.primaryDark,
                                                              size: 17,
                                                            ),
                                                            style: const TextStyle(
                                                              fontSize: 9.8,
                                                              color: AppColors.textPrimary,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                            decoration: inputDecoration(),
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

                                                      SizedBox(
                                                        width: 105,
                                                        child: Center(
                                                          child: Container(
                                                            constraints: const BoxConstraints(minWidth: 70),
                                                            padding:
                                                            const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                                                            decoration: BoxDecoration(
                                                              color: const Color(0xFFEAF1FF),
                                                              borderRadius: BorderRadius.circular(6),
                                                              border: Border.all(
                                                                color: AppColors.primaryDark.withOpacity(0.12),
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

                                                      SizedBox(
                                                        width: 45,
                                                        child: Center(
                                                          child: Transform.scale(
                                                            scale: 0.88,
                                                            child: Checkbox(
                                                              value: selected,
                                                              activeColor: AppColors.primaryDark,
                                                              checkColor: Colors.white,
                                                              side: const BorderSide(
                                                                color: AppColors.primaryDark,
                                                                width: 1.3,
                                                              ),
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              onChanged: (val) {
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

                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF3F7FF), Color(0xFFEAF1FF)],
                              ),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: AppColors.border),
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
                                  child: const Icon(Icons.calculate_outlined, size: 18, color: AppColors.primaryDark),
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
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      ValueListenableBuilder<int?>(
                                        valueListenable: selectedIndexNotifier,
                                        builder: (context, selectedIndex, _) {
                                          return Text(
                                            "${selectedIndex != null ? 1 : 0} of ${charges.length} charges selected",
                                            style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary),
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

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
                    decoration: const BoxDecoration(
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
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  disposeControllers();
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                side: const BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                              ),
                              child: const Text(
                                "Cancel",
                                style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        // APPLY
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 42,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(7),
                                onTap: () async {
                                  double selectedTotal = 0;
                                  double selectedWeight = 0;
                                  int selectedChargeId = 0;

                                  // 🔥 FIX: defensive .toString() before parsing —
                                  // matches the pattern used everywhere else in
                                  // this file (calculateSingleCharge etc.) instead
                                  // of relying on implicit dynamic → String casts.
                                  for (final c in charges) {
                                    if (c["is_selected"] == true) {
                                      selectedTotal += double.tryParse(
                                        (c["total_amt"] ?? "0").toString(),
                                      ) ??
                                          0;
                                      selectedWeight += double.tryParse(
                                        (c["weight"] ?? "0").toString(),
                                      ) ??
                                          0;
                                      selectedChargeId =
                                          int.tryParse((c["id"] ?? "0").toString()) ??
                                              0;
                                    }
                                  }

                                  /// 🔥 1. SET SALE OTHER (amount)
                                  item["sale_other"] = selectedTotal.toStringAsFixed(2);

                                  /// 🔥 2. SET OTHER WEIGHT
                                  item["other_weight"] = selectedWeight.toStringAsFixed(3);

                                  /// 🔥 3. SAVE SELECTED CHARGE ID
                                  item["other_charge_id"] = selectedChargeId;

                                  /// 🔥 4. UPDATE CONTROLLERS
                                  updateController(item, "sale_other");
                                  updateController(item, "other_weight");

                                  /// 🔥 5. RECALCULATE
                                  calculateItem(item);

                                  FocusManager.instance.primaryFocus?.unfocus();

                                  /// 🔥 FIX: "_dependents.isEmpty is not true"
                                  /// crash — this happened because we were
                                  /// disposing the dialog's TextEditingControllers
                                  /// AND calling setState() on the parent in the
                                  /// SAME synchronous frame as Navigator.pop().
                                  /// That races with Flutter's Overlay/
                                  /// InheritedElement teardown for the dialog's
                                  /// route. Fix: pop first, then defer both the
                                  /// controller disposal and the parent setState
                                  /// to the NEXT frame via addPostFrameCallback.
                                  Navigator.pop(dialogContext);

                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    disposeControllers();
                                    if (mounted) {
                                      setState(() {});
                                    }
                                  });

                                  /// 🔥 FIX: await + try/catch — pehla fire-and-
                                  /// forget hatu (no await), etle koi error thay
                                  /// to unhandled exception tarike UI par aavti
                                  /// hati, ane bulk save complete thava pehla j
                                  /// UI aagad vadhi jatu hatu.
                                  try {
                                    await saveBulkItems();
                                  } catch (e) {
                                    debugPrint(
                                      "❌ APPLY CHARGES SAVE ERROR => $e",
                                    );
                                    if (mounted) {
                                      AppMessage.error(
                                        context,
                                        "Failed to save other charge",
                                      );
                                    }
                                  }
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
                                        color: AppColors.primaryDark.withOpacity(0.22),
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
    double gross =
        double.tryParse(getController(item, "gross_weight").text) ?? 0;

    double other = double.tryParse(getController(item, "other_weight").text) ?? 0;

    double net = gross - other;

    double metalRate =
        double.tryParse(getController(item, "metal_rate").text) ?? 0;

    double labourRate =
        double.tryParse(getController(item, "sale_labour_rate").text) ?? 0;

    double otherAmount =
        double.tryParse(getController(item, "sale_other").text) ?? 0;

    double metalAmount = net * metalRate;

    String formula = item["sale_labour_formula"] ?? "Per Net Weight";

    double labourAmount = net * labourRate;

    double fineWeight =
        double.tryParse(getController(item, "fine_weight").text) ?? 0;

    double qty = 1;

    if (formula == "Per Net Weight") {
      labourAmount = net * labourRate;
    } else if (formula == "Per Fine Weight") {
      labourAmount = fineWeight * labourRate;
    } else if (formula == "Per Qty") {
      labourAmount = qty * labourRate;
    } else if (formula == "Per Gross weight") {
      labourAmount = gross * labourRate;
    } else if (formula == "Flat") {
      labourAmount = labourRate;
    }

    double totalAmount = metalAmount + labourAmount + otherAmount;

    item["net_weight"] = net.toStringAsFixed(3);
    item["metal_amount"] = metalAmount.toStringAsFixed(2);
    item["sale_labour_amount"] = labourAmount.toStringAsFixed(2);
    item["total_amount"] = totalAmount.toStringAsFixed(2);

    updateController(item, "net_weight");
    updateController(item, "metal_amount");
    updateController(item, "sale_labour_amount");
    updateController(item, "total_amount");
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
      "sale_labour_rate",
      "metal_rate",
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

      final item = data["data"] is List ? data["data"][0] : data["data"];

      showOtherChargesPopup(
        mainItem,
        data["data"],
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to load details")));
    }
  }

  Widget _labourDropdown(Map<String, dynamic> item) {
    List<String> options = [
      "Per Net Weight",
      "Per Fine Weight",
      "Per Qty",
      "Per Gross weight",
      "Flat",
    ];

    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Labour Formula",
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 4),

          DropdownButtonFormField<String>(
            value: options.contains(item["sale_labour_formula"])
                ? item["sale_labour_formula"]
                : "Per Net Weight",

            icon: const Icon(
              Icons.keyboard_arrow_down,
              color: Colors.black,
            ),

            dropdownColor: Colors.white,

            style: const TextStyle(
              color: Colors.black,
              fontSize: 13,
            ),

            items: options.map((e) {
              return DropdownMenuItem(
                value: e,
                child: Text(
                  e,
                  style: const TextStyle(
                    color: Colors.black,
                  ),
                ),
              );
            }).toList(),

            onChanged: (val) {
              item["sale_labour_formula"] = val ?? "Per Net Weight";

              calculateItem(item);

              setState(() {});
            },

            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 2,
                vertical: 5,
              ),

              filled: true,
              fillColor: Colors.white,

              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.white),
              ),

              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.white),
              ),

              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSummaryRow() {
    final totals = calculateTotals();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color:AppColors.background,
        border: Border.all(color: AppColors.border,width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _summaryBox("Items", "${searchResults.length}"),
            _summaryBox("Gross", totals["gross"]!.toStringAsFixed(3)),
            _summaryBox("Other", totals["other"]!.toStringAsFixed(3)),
            _summaryBox("Net", totals["net"]!.toStringAsFixed(3)),

            _summaryBox("Purity", totals["purity"]!.toStringAsFixed(2)),
            _summaryBox("Waste", totals["waste"]!.toStringAsFixed(2)),
            _summaryBox("Net Purity", totals["netPurity"]!.toStringAsFixed(2)),

            _summaryBox("Fine", totals["fine"]!.toStringAsFixed(3)),

            _summaryBox("Metal Rate", totals["metalRate"]!.toStringAsFixed(2)),
            _summaryBox("Metal Amt", totals["metal"]!.toStringAsFixed(2)),

            _summaryBox(
              "Labour Rate",
              totals["sale_labour_rate"]!.toStringAsFixed(2),
            ),
            _summaryBox("Labour Amt", totals["sale_labour_amount"]!.toStringAsFixed(2)),

            _summaryBox("Other Amt", totals["otherAmt"]!.toStringAsFixed(2)),
            _summaryBox("Total", totals["total"]!.toStringAsFixed(2)),
          ],
        ),
      ),
    );
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

    for (var item in searchResults) {
      gross += double.tryParse(item["gross_weight"]?.toString() ?? "0") ?? 0;
      other += double.tryParse(item["other_weight"]?.toString() ?? "0") ?? 0;
      net += double.tryParse(item["net_weight"]?.toString() ?? "0") ?? 0;

      purity += double.tryParse(item["purity"]?.toString() ?? "0") ?? 0;
      waste += double.tryParse(item["waste"]?.toString() ?? "0") ?? 0;
      netPurity += double.tryParse(item["net_purity"]?.toString() ?? "0") ?? 0;

      fine += double.tryParse(item["fine_weight"]?.toString() ?? "0") ?? 0;
      metalRate += double.tryParse(item["metal_rate"]?.toString() ?? "0") ?? 0;

      metal += double.tryParse(item["metal_amount"]?.toString() ?? "0") ?? 0;

      labourRate +=
          double.tryParse(item["sale_labour_rate"]?.toString() ?? "0") ?? 0;
      labour += double.tryParse(item["sale_labour_amount"]?.toString() ?? "0") ?? 0;

      otherAmt += double.tryParse(item["other_amount"]?.toString() ?? "0") ?? 0;
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
      "sale_labour_rate": labourRate,
      "sale_labour_amount": labour,
      "otherAmt": otherAmt,
      "total": total,
    };
  }

  bool _isBlankRow(Map<String, dynamic> row) {
    final double gross =
        double.tryParse(
          row["gross_weight"]?.toString() ?? "",
        ) ??
            0;

    final double other =
        double.tryParse(
          row["other_weight"]?.toString() ?? "",
        ) ??
            0;

    final double metalRate =
        double.tryParse(
          row["metal_rate"]?.toString() ?? "",
        ) ??
            0;

    final double labourRate =
        double.tryParse(
          row["sale_labour_rate"]?.toString() ?? "",
        ) ??
            0;

    final double saleOther =
        double.tryParse(
          row["sale_other"]?.toString() ?? "",
        ) ??
            0;

    final String supplier =
        row["supplier_person"]?.toString().trim() ?? "";

    final String huid =
        row["huid"]?.toString().trim() ?? "";

    final String size =
        row["size"]?.toString().trim() ?? "";

    return gross == 0 &&
        other == 0 &&
        metalRate == 0 &&
        labourRate == 0 &&
        saleOther == 0 &&
        supplier.isEmpty &&
        huid.isEmpty &&
        (size.isEmpty || size == "0");
  }

  Widget _imageUploadField(Map<String, dynamic> item) {
    final String? imageUrl   = item["image_url"]?.toString();
    final String? localPath  = item["item_image"]?.toString();

    final String? displayPath =
    (imageUrl != null && imageUrl.trim().isNotEmpty)
        ? imageUrl
        : (localPath != null && localPath.trim().isNotEmpty)
        ? localPath
        : null;

    final bool hasImage = displayPath != null;

    final String heroTag = "item_image_${item["id"]}";

    final String itemNameForPreview =
    item["item_name"]?.toString().trim().isNotEmpty == true
        ? item["item_name"].toString()
        : selectedItemName.isNotEmpty
        ? selectedItemName
        : "Item";

    final String qrCodeForPreview =
    item["item_code"]?.toString().trim().isNotEmpty == true
        ? item["item_code"].toString()
        : selectedItemCode;

    return Container(
      width: 44,
      margin: const EdgeInsets.only(right: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 2, bottom: 4),
            child: Text(
              "Image",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          GestureDetector(
            onTap: () async {
              FocusManager.instance.primaryFocus?.unfocus();
              await _pickItemImage(item);
            },

            onDoubleTap: hasImage
                ? () {
              FocusManager.instance.primaryFocus?.unfocus();
              _openPremiumImagePreview(
                imageUrl: displayPath!,
                itemName: itemNameForPreview,
                qrCode: qrCodeForPreview,
                heroTag: heroTag,
              );
            }
                : null,

            child: Container(
              height: 36,
              width: 36,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: AppColors.border),
              ),
              child: hasImage
                  ? Hero(
                tag: heroTag,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image(
                      image: displayPath!.startsWith("http")
                          ? NetworkImage(displayPath) as ImageProvider
                          : FileImage(File(displayPath)),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 16,
                          color: Colors.black45,
                        ),
                      ),
                    ),

                    Positioned(
                      right: 1,
                      bottom: 1,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xffC8A96A),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 9,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              )
                  : const Center(
                child: Icon(
                  Icons.camera_alt_outlined,
                  size: 16,
                  color: Colors.black45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickItemImage(Map<String, dynamic> item) async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text("Camera"),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text("Gallery"),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    final ImagePicker picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: source,
      imageQuality: 75,
    );

    if (picked == null) return;

    final File imageFile = File(picked.path);

    item["item_image"] = picked.path;
    if (mounted) setState(() {});

    await _uploadItemImage(item, imageFile);
  }

  Future<void> _uploadItemImage(
      Map<String, dynamic> item,
      File imageFile,
      ) async {
    try {
      FocusManager.instance.primaryFocus?.unfocus();

      String uploadUrl = item["image_upload_url"]?.toString() ?? "";

      if (uploadUrl.isEmpty) {
        if (selectedItem == null || selectedItem!.isEmpty) {
          AppMessage.error(context, "Please select item first");
          return;
        }
        final int itemId = int.tryParse(selectedItem!) ?? 0;
        if (itemId <= 0) {
          AppMessage.error(context, "Invalid item ID");
          return;
        }
        uploadUrl = ApiConstants.itemSetUploadImage;
      }

      final String fileName = imageFile.path.split("/").last;

      final FormData formData = FormData.fromMap({
        "image": await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
        "item_id": selectedItem ?? "",
        "gross_weight":
        double.tryParse(item["gross_weight"]?.toString() ?? "0").toString(),
        "other":
        double.tryParse(item["other_weight"]?.toString() ?? "0").toString(),
        "net_weight":
        double.tryParse(item["net_weight"]?.toString() ?? "0").toString(),
      });

      debugPrint("📤 UPLOAD URL => $uploadUrl");
      debugPrint("📤 FILE => ${imageFile.path}");

      final response = await ApiHelper().postRequest(uploadUrl, formData);

      debugPrint("📥 UPLOAD RESPONSE => ${response?.data}");

      if (!mounted) return;

      if (response != null &&
          (response.statusCode == 200 || response.statusCode == 201)) {

        final responseData = response.data?["data"];
        if (responseData != null) {
          item["image_url"]        = responseData["image_url"]?.toString() ?? "";
          item["image_upload_url"] = responseData["image_upload_url"]?.toString() ?? "";
          item["image_show_url"]   = responseData["image_show_url"]?.toString() ?? "";
          item["item_image"]       = item["image_url"];
        }

        AppMessage.success(
          context,
          response.data?["message"] ?? "Image uploaded successfully",
        );

        if (mounted) setState(() {});
      } else {
        AppMessage.error(
          context,
          response?.data?["message"] ?? "Image upload failed",
        );
      }
    } catch (e) {
      debugPrint("❌ IMAGE UPLOAD ERROR => $e");
      if (!mounted) return;
      AppMessage.error(context, "Image upload failed");
    }
  }

  void _openPremiumImagePreview({
    required String imageUrl,
    required String itemName,
    required String qrCode,
    required String heroTag,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Image Preview",
      barrierColor: Colors.black.withOpacity(0.92),
      transitionDuration: const Duration(
        milliseconds: 280,
      ),
      pageBuilder: (
          context,
          animation,
          secondaryAnimation,
          ) {
        return Material(
          color: Colors.transparent,
          child: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Center(
                    child: Hero(
                      tag: heroTag,
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 5.0,
                        panEnabled: true,
                        scaleEnabled: true,
                        child: Image.network(
                          imageUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.contain,
                          loadingBuilder: (
                              context,
                              child,
                              loadingProgress,
                              ) {
                            if (loadingProgress == null) {
                              return child;
                            }
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            );
                          },
                          errorBuilder: (
                              context,
                              error,
                              stackTrace,
                              ) {
                            return const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.broken_image_outlined,
                                    size: 55,
                                    color: Colors.white54,
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    "Unable to load image",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                Positioned(
                  top: 12,
                  left: 14,
                  right: 14,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.12),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                itemName.isEmpty
                                    ? "Item Image"
                                    : itemName,
                                maxLines: 1,
                                overflow:
                                TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),

                              if (qrCode.isNotEmpty) ...[
                                const SizedBox(height: 3),

                                Text(
                                  "Label: $qrCode",
                                  maxLines: 1,
                                  overflow:
                                  TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white
                                        .withOpacity(0.65),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        borderRadius:
                        BorderRadius.circular(50),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.15),
                            ),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 20,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.10),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.pinch_outlined,
                            color: Colors.white70,
                            size: 16,
                          ),

                          SizedBox(width: 6),

                          Text(
                            "Pinch to zoom",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
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
      },
      transitionBuilder: (
          context,
          animation,
          secondaryAnimation,
          child,
          ) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curvedAnimation,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.94,
              end: 1.0,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _fetchAndPreviewItemImage(Map<String, dynamic> item) async {
    final String? imageId = item["id"]?.toString();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final response = await ApiHelper().getRequest(
      "${ApiConstants.itemSetImage}/$imageId",
    );

    if (!mounted) return;
    Navigator.pop(context);

    if (response != null && response.statusCode == 200) {
      final data = response.data;

      final String? imageUrl = data["data"]?["image_url"]?.toString() ??
          data["data"]?["image"]?.toString() ??
          data["image_url"]?.toString() ??
          data["url"]?.toString();

      if (imageUrl == null || imageUrl.trim().isEmpty) {
        AppMessage.error(context, "No image found for this item");
        return;
      }

      final String itemNameForPreview =
      item["item_name"]?.toString().trim().isNotEmpty == true
          ? item["item_name"].toString()
          : selectedItemName.isNotEmpty
          ? selectedItemName
          : "Item";

      final String qrCodeForPreview =
      item["item_code"]?.toString().trim().isNotEmpty == true
          ? item["item_code"].toString()
          : item["code"]?.toString().trim().isNotEmpty == true
          ? item["code"].toString()
          : selectedItemCode;

      FocusManager.instance.primaryFocus?.unfocus();

      _openPremiumImagePreview(
        imageUrl: imageUrl,
        itemName: itemNameForPreview,
        qrCode: qrCodeForPreview,
        heroTag: "item_image_${item["id"]}",
      );
    } else {
      AppMessage.error(
        context,
        response?.data?["message"] ?? "Failed to load image",
      );
    }
  }

  /// 🔥 Item select / clear
  Future<void> _setItem(Map<String, dynamic>? item) async {
    /// ❌ CLEAR
    if (item == null) {
      setState(() {
        selectedItem = null;
        selectedItemData = null;
        selectedItemName = "";
        selectedItemCode = "";

        Carat_Controller.clear();
        purity_Controller.clear();

        /// loadItemDetails() એ જે rows ભરી હોય એ પણ સાફ કરો
        /// (તમારી screen માં આ variables હોય તો જ રાખજો)
        // tableRows.clear();
        // apiRowCount = 0;
      });

      debugPrint("ITEM CLEARED");
      return;
    }

    /// ✅ SELECT
    final String value = item["id"]?.toString() ?? "";
    if (value.isEmpty) return;

    setState(() {
      selectedItem = value;
      selectedItemData = item;

      selectedItemName =
          item["item_name"]?.toString() ?? item["name"]?.toString() ?? "";

      selectedItemCode =
          item["item_code"]?.toString() ?? item["code"]?.toString() ?? "";

      Carat_Controller.text = item["inward_carat"]?.toString() ?? "";
      purity_Controller.text = item["inward_purity"]?.toString() ?? "";
    });

    await loadItemDetails(value);
  }
}
